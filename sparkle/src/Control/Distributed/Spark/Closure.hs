{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StaticPointers #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}

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
import qualified Data.Text.Encoding as Text
import qualified Data.Text.Foreign as Text
import Data.Text (Text)
import Data.Typeable (Typeable, (:~:)(..), eqT, typeOf)
import qualified Data.Vector.Storable as Vector
import Data.Vector.Storable (Vector)
import qualified Data.Vector.Storable.Mutable as MVector
import Data.Vector.Storable.Mutable (IOVector)
import Foreign (FunPtr, Ptr, Storable, newForeignPtr, withForeignPtr)
import Foreign.Java

data Type a
  = Fun [Type a] (Type a) -- ^ Pure function
  | Act [Type a] (Type a) -- ^ IO action
  | Proc [Type a]         -- ^ Procedure (i.e void returning action)
  | Base a                -- ^ Any first-order type.

type family Uncurry a where
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

class (Uncurry a ~ b, Typeable a, Typeable b) => Reify a b where
  reify :: JObject -> IO a

class (Uncurry a ~ b, Typeable a, Typeable b) => Reflect a b where
  reflect :: a -> IO JObject

apply
  :: JNIEnv
  -> JClass
  -> JByteArray
  -> JObjectArray
  -> IO JObject
apply _ _ bytes args = do
    bs <- reify bytes
    let f = unclosure (bs2clos bs) :: JObjectArray -> IO JObject
    f args

foreign export ccall "Java_io_tweag_sparkle_Sparkle_apply" apply
  :: JNIEnv
  -> JClass
  -> JByteArray
  -> JObjectArray
  -> IO JObject

-- XXX GHC wouldn't be able to use the more natural
--
-- (Uncurry a ~ a', Uncurry b ~ b')
--
-- constraint, because it doesn't know that Uncurry is injective.
instance (Uncurry (Closure (a -> b)) ~ 'Fun '[a'] b', Reflect a a', Reify b b') =>
         Reify (Closure (a -> b)) ('Fun '[a'] b') where
  reify jobj = do
      klass <- findClass "io/tweag/sparkle/function/HaskellFunction"
      field <- getFieldID klass "clos" "[B"
      jpayload <- getObjectField jobj field
      payload <- reify jpayload
      return (bs2clos payload)

instance (Uncurry (Closure (a -> b)) ~ 'Fun '[a'] b', Reify a a', Reflect b b') =>
         Reflect (Closure (a -> b)) ('Fun '[a'] b') where
  reflect f = do
      klass <- findClass "io/tweag/sparkle/function/HaskellFunction"
      jpayload <- reflect (clos2bs (fromJust wrap))
      newObject klass "([B)V" [JObject jpayload]
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
        error ("No static function from " ++
               show (typeOf (undefined :: a)) ++
               " to " ++
               show (typeOf (undefined :: b)))

-- Floating to top-level due to a limitation of -XStaticPointers.
--
-- TODO file bug report.

dict1 :: Dict (Reify Int ('Base Int), Reflect Int ('Base Int))
dict2 :: Dict (Reify Bool ('Base Bool), Reflect Bool ('Base Bool))
dict3 :: Dict (Reify ByteString ('Base ByteString), Reflect ByteString ('Base ByteString))
dict4 :: Dict (Reify Text ('Base Text), Reflect Text ('Base Text))
dict5 :: Dict (Reify Text ('Base Text), Reflect Bool ('Base Bool))
dict1 = Dict
dict2 = Dict
dict3 = Dict
dict4 = Dict
dict5 = Dict

closFun1 :: Dict (Reify a a', Reflect b b') -> (a -> b) -> JObjectArray -> IO JObject
closFun1 Dict f args =
    reflect =<< return . f =<< reify =<< getObjectArrayElement args 0

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

instance Reify ByteString ('Base ByteString) where
  reify jobj = do
      n <- getArrayLength jobj
      bytes <- getByteArrayElements jobj
      -- TODO could use unsafePackCStringLen instead and avoid a copy if we knew
      -- that been handed an (immutable) copy via JNI isCopy ref.
      bs <- BS.packCStringLen (bytes, fromIntegral n)
      releaseByteArrayElements jobj bytes
      return bs

instance Reflect ByteString ('Base ByteString) where
  reflect bs = BS.unsafeUseAsCStringLen bs $ \(content, n) -> do
      arr <- newByteArray (fromIntegral n)
      setByteArrayRegion arr 0 (fromIntegral n) content
      return arr

instance Reify Bool ('Base Bool) where
  reify jobj = do
      klass <- findClass "java/lang/Boolean"
      method <- getMethodID klass "booleanValue" "()Z"
      toEnum . fromIntegral <$> callBooleanMethod jobj method []

instance Reflect Bool ('Base Bool) where
  reflect x = do
      klass <- findClass "java/lang/Boolean"
      newObject klass "(Z)V" [JBoolean (fromIntegral (fromEnum x))]

instance Reify Int ('Base Int) where
  reify jobj = do
      klass <- findClass "java/lang/Integer"
      method <- getMethodID klass "longValue" "()L"
      fromIntegral <$> callLongMethod jobj method []

instance Reflect Int ('Base Int) where
  reflect x = do
      klass <- findClass "java/lang/Integer"
      newObject klass "(L)V" [JInt (fromIntegral x)]

instance Reify Double ('Base Double) where
  reify jobj = do
      klass <- findClass "java/lang/Double"
      method <- getMethodID klass "doubleValue" "()D"
      callDoubleMethod jobj method []

instance Reflect Double ('Base Double) where
  reflect x = do
      klass <- findClass "java/lang/Double"
      newObject klass "(D)V" [JDouble x]

instance Reify Text ('Base Text) where
  reify jobj = do
      -- TODO go via getString instead of getStringUTF, since text also uses
      -- UTF-16 internally.
      sz <- getStringUTFLength jobj
      cs <- getStringUTFChars jobj
      txt <- Text.decodeUtf8 <$> BS.unsafePackCStringLen (cs, fromIntegral sz)
      releaseStringUTFChars jobj cs
      return txt

instance Reflect Text ('Base Text) where
  reflect x =
      Text.useAsPtr x $ \ptr len ->
        newString ptr (fromIntegral len)

instance Reify (IOVector Int32) ('Base (IOVector Int32)) where
  reify = reifyMVector (getIntArrayElements) (releaseIntArrayElements)

instance Reflect (IOVector Int32) ('Base (IOVector Int32)) where
  reflect = reflectMVector (newIntArray) (setIntArrayRegion)

instance Reify (Vector Int32) ('Base (Vector Int32)) where
  reify = Vector.freeze <=< reify

instance Reflect (Vector Int32) ('Base (Vector Int32)) where
  reflect = reflect <=< Vector.thaw

instance Reify a (Uncurry a) => Reify [a] ('Base [a]) where
  reify jobj = do
      n <- getArrayLength jobj
      forM [0..n-1] $ \i -> do
        x <- getObjectArrayElement jobj i
        reify x

instance Reflect a (Uncurry a) => Reflect [a] ('Base [a]) where
  reflect xs = do
    let n = fromIntegral (length xs)
    klass <- findClass "java/lang/Object"
    array <- newObjectArray n klass
    forM_ (zip [0..n-1] xs) $ \(i, x) -> do
      setObjectArrayElement array i =<< reflect x
    return array

foreign import ccall "wrapper" wrapFinalizer
  :: (Ptr a -> IO ())
  -> IO (FunPtr (Ptr a -> IO ()))

reifyMVector
  :: Storable a
  => (JArray -> IO (Ptr a))
  -> (JArray -> Ptr a -> IO ())
  -> JArray
  -> IO (IOVector a)
reifyMVector mk finalize jobj = do
    n <- getArrayLength jobj
    ptr <- mk jobj
    ffinalize <- wrapFinalizer (finalize jobj)
    fptr <- newForeignPtr ffinalize ptr
    return (MVector.unsafeFromForeignPtr0 fptr (fromIntegral n))

reflectMVector
  :: Storable a
  => (Int32 -> IO JArray)
  -> (JArray -> Int32 -> Int32 -> Ptr a -> IO ())
  -> IOVector a
  -> IO JArray
reflectMVector new fill mv = do
    let (fptr, n) = MVector.unsafeToForeignPtr0 mv
    jobj <- new (fromIntegral n)
    withForeignPtr fptr $ fill jobj 0 (fromIntegral n)
    return jobj

clos2bs :: Typeable a => Closure a -> ByteString
clos2bs = LBS.toStrict . encode

bs2clos :: Typeable a => ByteString -> Closure a
bs2clos = decode . LBS.fromStrict
