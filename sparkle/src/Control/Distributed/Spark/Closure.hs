{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StaticPointers #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-} -- For Closure instances

module Control.Distributed.Spark.Closure where

import Control.Distributed.Closure
import Control.Distributed.Closure.TH
import Control.Applicative ((<|>))
import Control.Monad ((<=<), forM, forM_)
import Data.Binary (encode, decode)
import Data.Int
import Data.Maybe (fromJust)
import Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as LBS
import qualified Data.ByteString as BS
import qualified Data.ByteString.Unsafe as BS
import qualified Data.Text.Foreign as Text
import Data.Text (Text)
import Data.Typeable (Typeable, (:~:)(..), eqT, typeOf)
import qualified Data.Vector.Storable as Vector
import Data.Vector.Storable (Vector)
import qualified Data.Vector.Storable.Mutable as MVector
import Data.Vector.Storable.Mutable (IOVector)
import Foreign (FunPtr, Ptr, Storable, newForeignPtr, withForeignPtr)
import Foreign.JNI

data Type a
  = Fun [Type a] (Type a) -- ^ Pure function
  | Act [Type a] (Type a) -- ^ IO action
  | Proc [Type a]         -- ^ Procedure (i.e void returning action)
  | Base a                -- ^ Any first-order type.

type family Uncurry (a :: *) :: Type * where
  Uncurry (Closure (a -> b -> c -> d -> IO ())) = 'Proc '[Uncurry a, Uncurry b, Uncurry c, Uncurry d]
  Uncurry (Closure (a -> b -> c -> IO ())) = 'Proc '[Uncurry a, Uncurry b, Uncurry c]
  Uncurry (Closure (a -> b -> IO ())) = 'Proc '[Uncurry a, Uncurry b]
  Uncurry (Closure (a -> IO ())) = 'Proc '[Uncurry a]
  Uncurry (IO ()) = 'Proc '[]
  Uncurry (Closure (a -> b -> c -> d -> IO e)) = 'Act '[Uncurry a, Uncurry b, Uncurry c, Uncurry d] (Uncurry e)
  Uncurry (Closure (a -> b -> c -> IO d)) = 'Act '[Uncurry a, Uncurry b, Uncurry c] (Uncurry d)
  Uncurry (Closure (a -> b -> IO c)) = 'Act '[Uncurry a, Uncurry b] (Uncurry c)
  Uncurry (Closure (a -> IO b)) = 'Act '[Uncurry a] (Uncurry b)
  Uncurry (Closure (IO a)) = 'Act '[] (Uncurry a)
  Uncurry (Closure (a -> b -> c -> d -> e)) = 'Fun '[Uncurry a, Uncurry b, Uncurry c, Uncurry d] (Uncurry e)
  Uncurry (Closure (a -> b -> c -> d)) = 'Fun '[Uncurry a, Uncurry b, Uncurry c] (Uncurry d)
  Uncurry (Closure (a -> b -> c)) = 'Fun '[Uncurry a, Uncurry b] (Uncurry c)
  Uncurry (Closure (a -> b)) = 'Fun '[Uncurry a] (Uncurry b)
  Uncurry a = 'Base a

type family Interp (a :: k) :: JType
type instance Interp ('Base a) = Interp a

class (Interp (Uncurry a) ~ ty, Typeable a) => Reify a ty where
  reify :: J ty -> IO a

class (Interp (Uncurry a) ~ ty, Typeable a) => Reflect a ty where
  reflect :: a -> IO (J ty)

apply
  :: JByteArray
  -> JObjectArray
  -> IO JObject
apply bytes args = do
    bs <- reify bytes
    let f = unclosure (bs2clos bs) :: JObjectArray -> IO JObject
    f args

foreign export ccall "sparkle_apply" apply
  :: JByteArray
  -> JObjectArray
  -> IO JObject

type instance Interp ('Fun '[a] b) =
  'Class "io.tweag.sparkle.function.HaskellFunction" <> [Interp a, Interp b]

-- Needs UndecidableInstances
instance ( ty1 ~ Interp (Uncurry a)
         , ty2 ~ Interp (Uncurry b)
         , ty ~ Interp (Uncurry (Closure (a -> b)))
         , ty ~ ('Class "io.tweag.sparkle.function.HaskellFunction" <> [ty1, ty2])
         , Reflect a ty1
         , Reify b ty2
         ) =>
         Reify (Closure (a -> b)) ty where
  reify jobj = do
      klass <- findClass "io/tweag/sparkle/function/HaskellFunction"
      field <- getFieldID klass "clos" "[B"
      jpayload <- getObjectField jobj field
      payload <- reify (unsafeCast jpayload)
      return (bs2clos payload)

-- Needs UndecidableInstances
instance ( ty1 ~ Interp (Uncurry a)
         , ty2 ~ Interp (Uncurry b)
         , ty ~ Interp (Uncurry (Closure (a -> b)))
         , ty ~ ('Class "io.tweag.sparkle.function.HaskellFunction" <> [ty1, ty2])
         , Reify a ty1
         , Reflect b ty2
         ) =>
         Reflect (Closure (a -> b)) ty where
  reflect f = do
      klass <- findClass "io/tweag/sparkle/function/HaskellFunction"
      jpayload <- reflect (clos2bs (fromJust wrap))
      fmap unsafeCast $ newObject klass "([B)V" [JObject jpayload]
    where
      -- TODO this type dispatch is a gross temporary hack! For until we get the
      -- instance commented out below to work.
      wrap :: Maybe (Closure (JObjectArray -> IO JObject))
      wrap =
        fmap (\Refl -> $(cstatic 'closFun1) `cap` $(cstatic 'dict1) `cap` f) (eqT :: Maybe ((a, b) :~: (Int, Int))) <|>
        fmap (\Refl -> $(cstatic 'closFun1) `cap` $(cstatic 'dict2) `cap` f) (eqT :: Maybe ((a, b) :~: (Bool, Bool))) <|>
        fmap (\Refl -> $(cstatic 'closFun1) `cap` $(cstatic 'dict3) `cap` f) (eqT :: Maybe ((a, b) :~: (ByteString, ByteString))) <|>
        fmap (\Refl -> $(cstatic 'closFun1) `cap` $(cstatic 'dict4) `cap` f) (eqT :: Maybe ((a, b) :~: (Text, Text))) <|>
        fmap (\Refl -> $(cstatic 'closFun1) `cap` $(cstatic 'dict5) `cap` f) (eqT :: Maybe ((a, b) :~: (Text, Bool))) <|>
        error ("Due to TEMPORARY HACK - No static function from " ++
               show (typeOf (undefined :: a)) ++
               " to " ++
               show (typeOf (undefined :: b)))

-- XXX Floating to top-level due to a limitation of -XStaticPointers.
--
-- See https://ghc.haskell.org/trac/ghc/ticket/11656.

dict1 :: Dict (Reify Int ('Class "java.lang.Integer"), Reflect Int ('Class "java.lang.Integer"))
dict2 :: Dict (Reify Bool ('Class  "java.lang.Boolean"), Reflect Bool ('Class  "java.lang.Boolean"))
dict3 :: Dict (Reify ByteString ('Array ('Prim "byte")), Reflect ByteString ('Array ('Prim "byte")))
dict4 :: Dict (Reify Text ('Class  "java.lang.String"), Reflect Text ('Class  "java.lang.String"))
dict5 :: Dict (Reify Text ('Class  "java.lang.String"), Reflect Bool ('Class  "java.lang.Boolean"))
dict1 = Dict
dict2 = Dict
dict3 = Dict
dict4 = Dict
dict5 = Dict

closFun1
  :: forall a b ty1 ty2.
     Dict (Reify a ty1, Reflect b ty2)
  -> (a -> b)
  -> JObjectArray
  -> IO JObject
closFun1 Dict f args =
    fmap upcast . refl =<< return . f =<< reif . unsafeCast =<< getObjectArrayElement args 0
  where
    reif = reify :: J ty1 -> IO a
    refl = reflect :: b -> IO (J ty2)

-- instance (Uncurry (Closure (a -> b)) ~ Fun '[a'] b', Reflect a a', Reify b b') =>
--          Reify (Closure (a -> b)) (Fun '[a'] b') where
--   reify jobj = do
--       klass <- findClass "io/tweag/sparkle/function/Function"
--       field <- getFieldID klass "clos" "[B"
--       jpayload <- getObjectField jobj field
--       payload <- reify jpayload
--       return (bs2clos payload)
--   reifyDict =
--       cmapDict `cap` reifyDictFun1 `cap` (cpairDict `cap` reflectDict `cap` reifyDict)
--
-- reifyDictFun1 :: (Reflect a a', Reify b b') :- Reify (Closure (a -> b)) (Fun '[a'] b')
-- reifyDictFun1 = Sub

type instance Interp ByteString = 'Array ('Prim "byte")

instance Reify ByteString ('Array ('Prim "byte")) where
  reify jobj = do
      n <- getArrayLength (unsafeCast jobj)
      bytes <- getByteArrayElements jobj
      -- TODO could use unsafePackCStringLen instead and avoid a copy if we knew
      -- that been handed an (immutable) copy via JNI isCopy ref.
      bs <- BS.packCStringLen (bytes, fromIntegral n)
      releaseByteArrayElements jobj bytes
      return bs

instance Reflect ByteString ('Array ('Prim "byte")) where
  reflect bs = BS.unsafeUseAsCStringLen bs $ \(content, n) -> do
      arr <- newByteArray (fromIntegral n)
      setByteArrayRegion arr 0 (fromIntegral n) content
      return arr

type instance Interp Bool = 'Class "java.lang.Boolean"

instance Reify Bool ('Class "java.lang.Boolean") where
  reify jobj = do
      klass <- findClass "java/lang/Boolean"
      method <- getMethodID klass "booleanValue" "()Z"
      toEnum . fromIntegral <$> callBooleanMethod jobj method []

instance Reflect Bool ('Class "java.lang.Boolean") where
  reflect x = do
      klass <- findClass "java/lang/Boolean"
      fmap unsafeCast $
        newObject klass "(Z)V" [JBoolean (fromIntegral (fromEnum x))]

type instance Interp Int = 'Class "java.lang.Integer"

instance Reify Int ('Class "java.lang.Integer") where
  reify jobj = do
      klass <- findClass "java/lang/Integer"
      method <- getMethodID klass "longValue" "()L"
      fromIntegral <$> callLongMethod jobj method []

instance Reflect Int ('Class "java.lang.Integer") where
  reflect x = do
      klass <- findClass "java/lang/Integer"
      fmap unsafeCast $
        newObject klass "(L)V" [JInt (fromIntegral x)]

type instance Interp Double = 'Class "java.lang.Double"

instance Reify Double ('Class "java.lang.Double") where
  reify jobj = do
      klass <- findClass "java/lang/Double"
      method <- getMethodID klass "doubleValue" "()D"
      callDoubleMethod jobj method []

instance Reflect Double ('Class "java.lang.Double") where
  reflect x = do
      klass <- findClass "java/lang/Double"
      fmap unsafeCast $ newObject klass "(D)V" [JDouble x]

type instance Interp Text = 'Class "java.lang.String"

instance Reify Text ('Class "java.lang.String") where
  reify jobj = do
      sz <- getStringLength jobj
      cs <- getStringChars jobj
      txt <- Text.fromPtr cs (fromIntegral sz)
      releaseStringChars jobj cs
      return txt

instance Reflect Text ('Class "java.lang.String") where
  reflect x =
      Text.useAsPtr x $ \ptr len ->
        newString ptr (fromIntegral len)

type instance Interp (IOVector Int32) = 'Array ('Prim "int")

instance Reify (IOVector Int32) ('Array ('Prim "int")) where
  reify = reifyMVector (getIntArrayElements) (releaseIntArrayElements)

instance Reflect (IOVector Int32) ('Array ('Prim "int")) where
  reflect = reflectMVector (newIntArray) (setIntArrayRegion)

type instance Interp (Vector Int32) = 'Array ('Prim "int")

instance Reify (Vector Int32) ('Array ('Prim "int")) where
  reify = Vector.freeze <=< reify

instance Reflect (Vector Int32) ('Array ('Prim "int")) where
  reflect = reflect <=< Vector.thaw

type instance Interp [a] = 'Array (Interp (Uncurry a))

instance (Reify a ty) => Reify [a] ('Array ty) where
  reify jobj = do
      n <- getArrayLength jobj
      forM [0..n-1] $ \i -> do
        x <- getObjectArrayElement jobj i
        reify x

instance (Reflect a ty) => Reflect [a] ('Array ty) where
  reflect xs = do
    let n = fromIntegral (length xs)
    klass <- findClass "java/lang/Object"
    array <- newObjectArray n klass
    forM_ (zip [0..n-1] xs) $ \(i, x) -> do
      setObjectArrayElement array i =<< reflect x
    return (unsafeCast array)

foreign import ccall "wrapper" wrapFinalizer
  :: (Ptr a -> IO ())
  -> IO (FunPtr (Ptr a -> IO ()))

reifyMVector
  :: Storable a
  => (JArray ty -> IO (Ptr a))
  -> (JArray ty -> Ptr a -> IO ())
  -> JArray ty
  -> IO (IOVector a)
reifyMVector mk finalize jobj = do
    n <- getArrayLength jobj
    ptr <- mk jobj
    ffinalize <- wrapFinalizer (finalize jobj)
    fptr <- newForeignPtr ffinalize ptr
    return (MVector.unsafeFromForeignPtr0 fptr (fromIntegral n))

reflectMVector
  :: Storable a
  => (Int32 -> IO (JArray ty))
  -> (JArray ty -> Int32 -> Int32 -> Ptr a -> IO ())
  -> IOVector a
  -> IO (JArray ty)
reflectMVector new fill mv = do
    let (fptr, n) = MVector.unsafeToForeignPtr0 mv
    jobj <- new (fromIntegral n)
    withForeignPtr fptr $ fill jobj 0 (fromIntegral n)
    return jobj

clos2bs :: Typeable a => Closure a -> ByteString
clos2bs = LBS.toStrict . encode

bs2clos :: Typeable a => ByteString -> Closure a
bs2clos = decode . LBS.fromStrict
