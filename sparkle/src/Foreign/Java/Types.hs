{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module Foreign.Java.Types where

import Foreign.C
import Foreign.Ptr
import Foreign.Storable (Storable(..))

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

type JClass = JObject
type JString = JObject
type JIntArray = JObject
type JByteArray = JObject
type JDoubleArray = JObject
type JObjectArray = JObject

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
