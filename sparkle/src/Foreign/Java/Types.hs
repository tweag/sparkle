{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

module Foreign.Java.Types where

import Data.Int
import Data.Map (fromList)
import Data.Word
import Foreign.C (CChar)
import Foreign.Ptr
import Foreign.Storable (Storable(..))
import Language.C.Types
import Language.C.Inline.Context

newtype JVM = JVM_ (Ptr JVM)
  deriving (Eq, Show, Storable)

newtype JNIEnv = JNIEnv_ (Ptr JNIEnv)
  deriving (Eq, Show, Storable)

newtype JFieldID = JFieldID_ (Ptr JFieldID)
  deriving (Eq, Show, Storable)

newtype JMethodID = JMethodID_ (Ptr JMethodID)
  deriving (Eq, Show, Storable)

newtype JObject = JObject_ (Ptr JObject)
  deriving (Eq, Show, Storable)

data JValue
  = JObject JObject
  | JInt CInt
  | JByte CChar
  | JDouble CDouble
  | JBoolean CUChar
  | JLong CLong

instance Storable JValue where
  sizeOf _ = 8
  alignment _ = 8

  poke p (JObject x)  = poke (castPtr p) x
  poke p (JInt i)     = poke (castPtr p) i
  poke p (JByte b)    = poke (castPtr p) b
  poke p (JDouble d)  = poke (castPtr p) d
  poke p (JBoolean b) = poke (castPtr p) b
  poke p (JLong l)    = poke (castPtr p) l

  peek _ = error "Storable JValue: undefined peek"

type JClass = JObject
type JString = JObject
type JArray = JObject
type JObjectArray = JObject
type JBooleanArray = JObject
type JByteArray = JObject
type JCharArray = JObject
type JShortArray = JObject
type JIntArray = JObject
type JLongArray = JObject
type JFloatArray = JObject
type JDoubleArray = JObject
type JThrowable = JObject

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
      , (TypeName "jclass", [t| JObject |])
      , (TypeName "jstring", [t| JObject |])
      , (TypeName "jarray", [t| JObject |])
      , (TypeName "jobjectArray", [t| JObject |])
      , (TypeName "jbooleanArray", [t| JObject |])
      , (TypeName "jbyteArray", [t| JObject |])
      , (TypeName "jcharArray", [t| JObject |])
      , (TypeName "jshortArray", [t| JObject |])
      , (TypeName "jintArray", [t| JObject |])
      , (TypeName "jlongArray", [t| JObject |])
      , (TypeName "jfloatArray", [t| JObject |])
      , (TypeName "jdoubleArray", [t| JObject |])
      , (TypeName "jthrowable", [t| JObject |])
      -- Internal types
      , (TypeName "JVM", [t| JVM |])
      , (TypeName "JNIEnv", [t| JNIEnv |])
      , (TypeName "jfieldID", [t| JFieldID |])
      , (TypeName "jmethodID", [t| JMethodID |])
      , (TypeName "jsize", [t| Int32 |])
      , (TypeName "jvalue", [t| JValue |])
      ]
