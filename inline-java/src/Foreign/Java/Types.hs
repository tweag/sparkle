{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TemplateHaskell #-}

module Foreign.Java.Types where

import Data.ByteString (ByteString)
import Data.Int
import Data.Map (fromList)
import Data.Text (Text)
import Data.Vector.Storable.Mutable (IOVector)
import Data.Word
import Foreign.C (CChar)
import Foreign.Ptr
import Foreign.Storable (Storable(..))
import Language.C.Types
import Language.C.Inline.Context

-- | A JVM instance.
newtype JVM = JVM_ (Ptr JVM)
  deriving (Eq, Show, Storable)

-- | The thread-local JNI context. Do not share this object between threads.
newtype JNIEnv = JNIEnv_ (Ptr JNIEnv)
  deriving (Eq, Show, Storable)

-- | A thread-local reference to a field of an object.
newtype JFieldID = JFieldID_ (Ptr JFieldID)
  deriving (Eq, Show, Storable)

-- | A thread-local reference to a method of an object.
newtype JMethodID = JMethodID_ (Ptr JMethodID)
  deriving (Eq, Show, Storable)

-- | Type indexed Java Objects.
newtype J a = J (Ptr (J a))
  deriving (Eq, Show, Storable)

-- | Any object can be cast to @Object@.
upcast :: J a -> J Object
upcast (J x) = J (castPtr x)

-- | Unsafe type cast. Should only be used to downcast.
unsafeCast :: J a -> J b
unsafeCast (J x) = J (castPtr x)

-- | A union type for uniformly passing arguments to methods.
data JValue
  = JBoolean Word8
  | JByte CChar
  | JChar Word16
  | JShort Int8
  | JInt Int32
  | JLong Int64
  | JFloat Float
  | JDouble Double
  | forall a. JObject (J a)

-- Needs to be standalone due to existential.
deriving instance Show JValue

instance Eq JValue where
  (JBoolean x) == (JBoolean y) = x == y
  (JByte x) == (JByte y) = x == y
  (JChar x) == (JChar y) = x == y
  (JShort x) == (JShort y) = x == y
  (JInt x) == (JInt y) = x == y
  (JLong x) == (JLong y) = x == y
  (JFloat x) == (JFloat y) = x == y
  (JDouble x) == (JDouble y) = x == y
  (JObject (J x)) == (JObject (J y)) = castPtr x == castPtr y
  _ == _ = False

instance Storable JValue where
  sizeOf _ = 8
  alignment _ = 8

  poke p (JBoolean x) = poke (castPtr p) x
  poke p (JByte x) = poke (castPtr p) x
  poke p (JChar x) = poke (castPtr p) x
  poke p (JShort x) = poke (castPtr p) x
  poke p (JInt x) = poke (castPtr p) x
  poke p (JLong x) = poke (castPtr p) x
  poke p (JFloat x) = poke (castPtr p) x
  poke p (JDouble x) = poke (castPtr p) x
  poke p (JObject x) = poke (castPtr p) x

  peek _ = error "Storable JValue: undefined peek"

data Object
data Class
data Throwable

type JObject = J Object
type JClass = J Class
type JString = J Text
type JArray a = J (IOVector a)
type JObjectArray = J (IOVector JObject)
type JBooleanArray = J (IOVector Bool)
-- type JByteArray = J (IOVector CChar)
type JByteArray = J ByteString
type JCharArray = J (IOVector Word16)
type JShortArray = J (IOVector Int16)
type JIntArray = J (IOVector Int32)
type JLongArray = J (IOVector Int64)
type JFloatArray = J (IOVector Float)
type JDoubleArray = J (IOVector Double)
type JThrowable = J Throwable

jniCtx :: Context
jniCtx = mempty { ctxTypesTable = fromList tytab }
  where
    tytab =
      [ -- Primitive types
        (TypeName "jboolean", [t| Word8 |])
      , (TypeName "jbyte", [t| CChar |])
      , (TypeName "jchar", [t| Word16 |])
      , (TypeName "jshort", [t| Int16 |])
      , (TypeName "jint", [t| Int32 |])
      , (TypeName "jlong", [t| Int64 |])
      , (TypeName "jfloat", [t| Float |])
      , (TypeName "jdouble", [t| Double |])
      -- Reference types
      , (TypeName "jobject", [t| J Object |])
      , (TypeName "jclass", [t| JClass |])
      , (TypeName "jstring", [t| JString |])
      , (TypeName "jarray", [t| JObject |])
      , (TypeName "jobjectArray", [t| JObjectArray |])
      , (TypeName "jbooleanArray", [t| JBooleanArray |])
      , (TypeName "jbyteArray", [t| JByteArray |])
      , (TypeName "jcharArray", [t| JCharArray |])
      , (TypeName "jshortArray", [t| JShortArray |])
      , (TypeName "jintArray", [t| JIntArray |])
      , (TypeName "jlongArray", [t| JLongArray |])
      , (TypeName "jfloatArray", [t| JFloatArray |])
      , (TypeName "jdoubleArray", [t| JDoubleArray |])
      , (TypeName "jthrowable", [t| J Throwable |])
      -- Internal types
      , (TypeName "JavaVM", [t| JVM |])
      , (TypeName "JNIEnv", [t| JNIEnv |])
      , (TypeName "jfieldID", [t| JFieldID |])
      , (TypeName "jmethodID", [t| JMethodID |])
      , (TypeName "jsize", [t| Int32 |])
      , (TypeName "jvalue", [t| JValue |])
      ]
