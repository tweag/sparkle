{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PolyKinds #-}        -- For J a
{-# LANGUAGE RoleAnnotations #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE ViewPatterns #-}

module Foreign.JNI.Types where

import Data.Coerce
import Data.Int
import Data.Map (fromList)
import Data.Word
import Foreign.C (CChar)
import Foreign.Ptr
import Foreign.Storable (Storable(..))
import GHC.TypeLits (Symbol)
import Language.C.Types (TypeSpecifier(TypeName))
import Language.C.Inline.Context (Context(..))

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

-- | Not part of JNI. Kind of Java object type indexes.
data JType
  = Class Symbol                               -- ^ Class name
  | Iface Symbol                               -- ^ Interface name
  | Prim Symbol                                -- ^ Primitive type
  | Array JType                                -- ^ Array type
  | Generic JType [JType]                      -- ^ Parameterized (generic) type

-- | Shorthand for parametized Java types.
type a <> g = 'Generic a g

-- | Type indexed Java Objects.
newtype J (a :: JType) = J (Ptr (J a))
  deriving (Eq, Show, Storable)

type role J nominal

-- | Any object can be cast to @Object@.
upcast :: J a -> JObject
upcast = unsafeCast

-- | Unsafe type cast. Should only be used to downcast.
unsafeCast :: J a -> J b
unsafeCast (J x) = J (castPtr x)

-- | Parameterize the type of an object, making its type a /generic type/.
generic :: J a -> J (a <> g)
generic = unsafeCast

-- | Get the base type of a generic type.
unsafeUngeneric :: J (a <> g) -> J a
unsafeUngeneric = unsafeCast

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
  | forall a o. Coercible o (J a) => JObject o

instance Show JValue where
  show (JBoolean x) = "JBoolean " ++ show x
  show (JByte x) = "JByte " ++ show x
  show (JChar x) = "JChar " ++ show x
  show (JShort x) = "JShort " ++ show x
  show (JInt x) = "JInt " ++ show x
  show (JLong x) = "JLong " ++ show x
  show (JFloat x) = "JFloat " ++ show x
  show (JDouble x) = "JDouble " ++ show x
  show (JObject x) = "JObject " ++ show (coerce x :: J a)

instance Eq JValue where
  (JBoolean x) == (JBoolean y) = x == y
  (JByte x) == (JByte y) = x == y
  (JChar x) == (JChar y) = x == y
  (JShort x) == (JShort y) = x == y
  (JInt x) == (JInt y) = x == y
  (JLong x) == (JLong y) = x == y
  (JFloat x) == (JFloat y) = x == y
  (JDouble x) == (JDouble y) = x == y
  (JObject (coerce -> J x)) == (JObject (coerce -> J y)) = castPtr x == castPtr y
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
  poke p (JObject x) = poke (castPtr p :: Ptr (J a)) (coerce x)

  peek _ = error "Storable JValue: undefined peek"

type JObject = J ('Class "java.lang.Object")
type JClass = J ('Class "java.lang.Class")
type JString = J ('Class "java.lang.String")
type JThrowable = J ('Class "java.lang.Throwable")
type JArray a = J ('Array a)
type JObjectArray = JArray ('Class "java.lang.Object")
type JBooleanArray = JArray ('Prim "boolean")
type JByteArray = JArray ('Prim "byte")
type JCharArray = JArray ('Prim "char")
type JShortArray = JArray ('Prim "short")
type JIntArray = JArray ('Prim "int")
type JLongArray = JArray ('Prim "long")
type JFloatArray = JArray ('Prim "float")
type JDoubleArray = JArray ('Prim "double")

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
      , (TypeName "jobject", [t| JObject |])
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
      , (TypeName "jthrowable", [t| JThrowable |])
      -- Internal types
      , (TypeName "JavaVM", [t| JVM |])
      , (TypeName "JNIEnv", [t| JNIEnv |])
      , (TypeName "jfieldID", [t| JFieldID |])
      , (TypeName "jmethodID", [t| JMethodID |])
      , (TypeName "jsize", [t| Int32 |])
      , (TypeName "jvalue", [t| JValue |])
      ]
