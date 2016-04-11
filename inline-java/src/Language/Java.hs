-- | High-level helper functions for interacting with Java objects, mapping them
-- to Haskell values and vice versa. The 'Reify' and 'Reflect' classes together
-- are to Java what "Foreign.Storable" is to C: they provide a means to
-- marshall/unmarshall Java objects from/into Haskell data types.

{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DefaultSignatures #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE UndecidableInstances #-}

module Language.Java
  ( Coercible(..)
  , new
  , call
  , callStatic
  , Type(..)
  , Uncurry
  , Interp
  , Reify(..)
  , Reflect(..)
  , Sing
  , sing
  ) where

import Control.Distributed.Closure
import Control.Distributed.Closure.TH
import Control.Monad ((<=<), forM, forM_)
import Data.Char (chr, ord)
import qualified Data.Coerce as Coerce
import Data.Int
import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Unsafe as BS
import Data.Singletons (SingI(..), fromSing)
import qualified Data.Text.Foreign as Text
import Data.Text (Text)
import qualified Data.Vector.Storable as Vector
import Data.Vector.Storable (Vector)
import qualified Data.Vector.Storable.Mutable as MVector
import Data.Vector.Storable.Mutable (IOVector)
import Foreign (FunPtr, Ptr, Storable, newForeignPtr, withForeignPtr)
import Foreign.C (CChar)
import Foreign.JNI
import GHC.TypeLits (KnownSymbol, Symbol)

-- | Tag data types that can be coerced in O(1) time without copy to a Java
-- object or primitive type (i.e. have the same representation) by declaring an
-- instance of this type class for that data type.
class SingI ty => Coercible a (ty :: JType) | a -> ty where
  coerce :: a -> JValue
  unsafeUncoerce :: JValue -> a

  default coerce
    :: Coerce.Coercible a (J ty)
    => a
    -> JValue
  coerce x = JObject (Coerce.coerce x :: J ty)

  default unsafeUncoerce
    :: Coerce.Coercible (J ty) a
    => JValue
    -> a
  unsafeUncoerce (JObject obj) = Coerce.coerce (unsafeCast obj :: J ty)
  unsafeUncoerce _ =
      error "Cannot unsafeUncoerce: object expected but value of primitive type found."

-- | The identity instance.
instance SingI ty => Coercible (J ty) ty

instance Coercible Bool ('Prim "boolean") where
  coerce x = JBoolean (fromIntegral (fromEnum x))
  unsafeUncoerce (JBoolean x) = toEnum (fromIntegral x)
  unsafeUncoerce _ = error "unsafeUncoerce: value doesn't match target type."
instance Coercible CChar ('Prim "byte") where
  coerce = JByte
  unsafeUncoerce (JByte x) = x
  unsafeUncoerce _ = error "unsafeUncoerce: value doesn't match target type."
instance Coercible Char ('Prim "char") where
  coerce x = JChar (fromIntegral (ord x))
  unsafeUncoerce (JChar x) = chr (fromIntegral x)
  unsafeUncoerce _ = error "unsafeUncoerce: value doesn't match target type."
instance Coercible Int8 ('Prim "short") where
  coerce = JShort
  unsafeUncoerce (JShort x) = x
  unsafeUncoerce _ = error "unsafeUncoerce: value doesn't match target type."
instance Coercible Int32 ('Prim "int") where
  coerce = JInt
  unsafeUncoerce (JInt x) = x
  unsafeUncoerce _ = error "unsafeUncoerce: value doesn't match target type."
instance Coercible Int64 ('Prim "long") where
  coerce = JLong
  unsafeUncoerce (JLong x) = x
  unsafeUncoerce _ = error "unsafeUncoerce: value doesn't match target type."
instance Coercible Float ('Prim "float") where
  coerce = JFloat
  unsafeUncoerce (JFloat x) = x
  unsafeUncoerce _ = error "unsafeUncoerce: value doesn't match target type."
instance Coercible Double ('Prim "double") where
  coerce = JDouble
  unsafeUncoerce (JDouble x) = x
  unsafeUncoerce _ = error "unsafeUncoerce: value doesn't match target type."
instance Coercible () 'Void where
  coerce = error "Void value undefined."
  unsafeUncoerce _ = ()

-- | NULL terminate byte strings, because those that were not created from
-- statically allocated literals aren't guaranteed to be.
nullTerminate :: ByteString -> ByteString
nullTerminate = (`BS.snoc` '\0')

-- | FindClass() special cases class names: in that case it doesn't want
-- a full signature, just the class name.
signatureStrip :: ByteString -> ByteString
signatureStrip sig | Just ('L', cls) <- BS.uncons sig = BS.init cls
signatureStrip sig = sig

new
  :: forall a sym.
     ( Coerce.Coercible a (J ('Class sym))
     , Coercible a ('Class sym)
     , KnownSymbol sym
     )
  => [JValue]
  -> IO a
new args = do
    let argsings = map jtypeOf args
        voidsing = sing :: Sing 'Void
    klass <- findClass (nullTerminate (signatureStrip (signature (sing :: Sing ('Class sym)))))
    Coerce.coerce <$> newObject klass (nullTerminate (methodSignature argsings voidsing)) args

call
  :: forall a b ty1 ty2. (Coercible a ty1, Coercible b ty2, Coerce.Coercible a (J ty1))
  => a
  -> ByteString
  -> [JValue]
  -> IO b
call obj mname args = do
    let argsings = map jtypeOf args
        retsing = sing :: Sing ty2
    klass <- findClass (nullTerminate (signatureStrip (signature (sing :: Sing ty1))))
    method <- getMethodID klass mname (nullTerminate (methodSignature argsings retsing))
    case retsing of
      SPrim "boolean" -> unsafeUncoerce . coerce <$> callBooleanMethod obj method args
      SPrim "byte" -> unsafeUncoerce . coerce <$> callByteMethod obj method args
      SPrim "char" -> error "call: unimplemented"
      SPrim "short" -> error "call: unimplemented"
      SPrim "int" -> unsafeUncoerce . coerce <$> callIntMethod obj method args
      SPrim "long" -> unsafeUncoerce . coerce <$> callLongMethod obj method args
      SPrim "float" -> error "call: unimplemented"
      SPrim "double" -> unsafeUncoerce . coerce <$> callDoubleMethod obj method args
      SVoid -> do
        callVoidMethod obj method args
        -- Anything uncoerces to the void type.
        return (unsafeUncoerce undefined)
      _ -> unsafeUncoerce . coerce <$> callObjectMethod obj method args

callStatic :: forall a ty sym. Coercible a ty => Sing (sym :: Symbol) -> ByteString -> [JValue] -> IO a
callStatic cname mname args = do
    let argsings = map jtypeOf args
        retsing = sing :: Sing ty
    klass <- findClass (nullTerminate (BS.pack (map subst (fromSing cname))))
    method <- getStaticMethodID klass mname (nullTerminate (methodSignature argsings retsing))
    case retsing of
      SPrim "boolean" -> error "callStatic: unimplemented"
      SPrim "byte" -> error "callStatic: unimplemented"
      SPrim "char" -> error "callStatic: unimplemented"
      SPrim "short" -> error "callStatic: unimplemented"
      SPrim "int" -> error "callStatic: unimplemented"
      SPrim "long" -> error "callStatic: unimplemented"
      SPrim "float" -> error "callStatic: unimplemented"
      SPrim "double" -> error "callStatic: unimplemented"
      SVoid -> do
        callStaticVoidMethod klass method args
        -- Anything uncoerces to the void type.
        return (unsafeUncoerce undefined)
      _ -> unsafeUncoerce . coerce <$> callStaticObjectMethod klass method args
  where
    subst '.' = '/'
    subst x = x

-- | Classifies Java types according to whether they are base types (data) or
-- higher-order types (objects representing functions).
data Type a
  = Fun [Type a] (Type a) -- ^ Pure function
  | Act [Type a] (Type a) -- ^ IO action
  | Proc [Type a]         -- ^ Procedure (i.e void returning action)
  | Base a                -- ^ Any first-order type.

-- | Haskell functions are curried, but Java functions are not. This type family
-- maps Haskell types to an uncurried (non-inductive) type representation,
-- useful to select the right 'Reify' / 'Reflect' instance without overlap.
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

-- | Map a Haskell type to the symbolic representation of a Java type.
type family Interp (a :: k) :: JType
type instance Interp ('Base a) = Interp a

-- | Extract a concrete Haskell value from the space of Java objects. That is to
-- say, map a Java object to a Haskell value.
class (Interp (Uncurry a) ~ ty, SingI ty) => Reify a ty where
  reify :: J ty -> IO a

-- | Inject a concrete Haskell value into the space of Java objects. That is to
-- say, map a Haskell value to a Java object.
class (Interp (Uncurry a) ~ ty, SingI ty) => Reflect a ty where
  reflect :: a -> IO (J ty)

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
reflectMVector newfun fill mv = do
    let (fptr, n) = MVector.unsafeToForeignPtr0 mv
    jobj <- newfun (fromIntegral n)
    withForeignPtr fptr $ fill jobj 0 (fromIntegral n)
    return jobj

withStatic [d|
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
        callBooleanMethod jobj method []

  instance Reflect Bool ('Class "java.lang.Boolean") where
    reflect x = new [JBoolean (fromIntegral (fromEnum x))]

  type instance Interp Int = 'Class "java.lang.Integer"

  instance Reify Int ('Class "java.lang.Integer") where
    reify jobj = do
        klass <- findClass "java/lang/Integer"
        method <- getMethodID klass "longValue" "()L"
        fromIntegral <$> callLongMethod jobj method []

  instance Reflect Int ('Class "java.lang.Integer") where
    reflect x = new [JInt (fromIntegral x)]

  type instance Interp Double = 'Class "java.lang.Double"

  instance Reify Double ('Class "java.lang.Double") where
    reify jobj = do
        klass <- findClass "java/lang/Double"
        method <- getMethodID klass "doubleValue" "()D"
        callDoubleMethod jobj method []

  instance Reflect Double ('Class "java.lang.Double") where
    reflect x = new [JDouble x]

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

  instance Reify a ty => Reify [a] ('Array ty) where
    reify jobj = do
        n <- getArrayLength jobj
        forM [0..n-1] $ \i -> do
          x <- getObjectArrayElement jobj i
          reify x

  instance Reflect a ty => Reflect [a] ('Array ty) where
    reflect xs = do
      let n = fromIntegral (length xs)
      klass <- findClass "java/lang/Object"
      array <- newObjectArray n klass
      forM_ (zip [0..n-1] xs) $ \(i, x) -> do
        setObjectArrayElement array i =<< reflect x
      return (unsafeCast array)
  |]
