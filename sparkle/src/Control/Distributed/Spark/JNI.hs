{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

module Control.Distributed.Spark.JNI where

import Data.Map (fromList)
import Foreign.C
import Foreign.Marshal.Array
import Foreign.Ptr
import Foreign.Storable
import Language.C.Inline.Context
import Language.C.Types

newtype JVM = JVM (Ptr JVM)
  deriving (Eq, Show, Storable)

newtype JNIEnv = JNIEnv (Ptr JNIEnv)
  deriving (Eq, Show, Storable)

newtype JObject = JObject (Ptr JObject)
  deriving (Eq, Show, Storable)

newtype JClass = JClass (Ptr JClass)
  deriving (Eq, Show, Storable)

newtype JMethodID = JMethodID (Ptr JMethodID)
  deriving (Eq, Show, Storable)

type JString = JObject
type JIntArray = JObject
type JByteArray = JObject
type JDoubleArray = JObject
type JObjectArray = JObject

data JValue
  = JObj JObject
  | JInt CInt
  | JByte CChar
  | JDouble CDouble
  | JBoolean CUChar
  | JLong CLong

instance Storable JValue where
  sizeOf _ = 8
  alignment _ = 8

  poke p (JObj o)     = poke (castPtr p) o
  poke p (JInt i)     = poke (castPtr p) i
  poke p (JByte b)    = poke (castPtr p) b
  poke p (JDouble d)  = poke (castPtr p) d
  poke p (JBoolean b) = poke (castPtr p) b
  poke p (JLong l)    = poke (castPtr p) l

  peek _ = error "Storable JValue: undefined peek"

foreign import ccall unsafe "jniEnv" jniEnv :: JVM -> IO JNIEnv
foreign import ccall unsafe "findClass" findClass' :: JNIEnv -> CString -> IO JClass
foreign import ccall unsafe "newObject" newObject' :: JNIEnv -> JClass -> CString -> Ptr JValue -> IO JObject
foreign import ccall unsafe "findMethod" findMethod' :: JNIEnv -> JClass -> CString -> CString -> IO JMethodID
foreign import ccall unsafe "findStaticMethod" findStaticMethod' :: JNIEnv -> JClass -> CString -> CString -> IO JMethodID
foreign import ccall unsafe "callObjectMethod" callObjectMethod' :: JNIEnv -> JObject -> JMethodID -> Ptr JValue -> IO JObject
foreign import ccall unsafe "callStaticObjectMethod" callStaticObjectMethod' :: JNIEnv -> JClass -> JMethodID -> Ptr JValue -> IO JObject
foreign import ccall unsafe "callStaticVoidMethod" callStaticVoidMethod' :: JNIEnv -> JClass -> JMethodID -> Ptr JValue -> IO ()
foreign import ccall unsafe "callVoidMethod" callVoidMethod' :: JNIEnv -> JObject -> JMethodID -> Ptr JValue -> IO ()
foreign import ccall safe "callLongMethod" callLongMethod' :: JNIEnv -> JObject -> JMethodID -> Ptr JValue -> IO CLong
foreign import ccall unsafe "newIntArray" newIntArray' :: JNIEnv -> CSize -> Ptr CInt -> IO JIntArray
foreign import ccall unsafe "newDoubleArray" newDoubleArray' :: JNIEnv -> CSize -> Ptr CDouble -> IO JDoubleArray
foreign import ccall unsafe "newByteArray" newByteArray' :: JNIEnv -> CSize -> Ptr CChar -> IO JByteArray
foreign import ccall unsafe "newObjectArray" newObjectArray' :: JNIEnv -> CSize -> JClass -> Ptr JObject -> IO JObjectArray
foreign import ccall unsafe "newString" newString' :: JNIEnv -> Ptr CChar -> IO JString
foreign import ccall unsafe "jstringLen" jstringLen :: JNIEnv -> JString -> IO CSize
foreign import ccall unsafe "jstringChars" jstringChars :: JNIEnv -> JString -> IO (Ptr CChar)
foreign import ccall unsafe "checkForExc" checkForException :: JNIEnv -> IO ()

findClass :: JNIEnv -> String -> IO JClass
findClass env s = withCString s (findClass' env)

newObject :: JNIEnv -> JClass -> String -> [JValue] -> IO JObject
newObject env cls sig args =
  withCString sig $ \csig ->
  withArray args $ \cargs ->
  newObject' env cls csig cargs

findMethod :: JNIEnv -> JClass -> String -> String -> IO JMethodID
findMethod env cls methodname sig =
  withCString methodname $ \cmethodname ->
  withCString sig $ \csig ->
  findMethod' env cls cmethodname csig

findStaticMethod :: JNIEnv -> JClass -> String -> String -> IO JMethodID
findStaticMethod env cls methodname sig =
  withCString methodname $ \cmethodname ->
  withCString sig $ \csig ->
  findStaticMethod' env cls cmethodname csig

callObjectMethod :: JNIEnv -> JObject -> JMethodID -> [JValue] -> IO JObject
callObjectMethod env obj method args =
  withArray args $ \cargs ->
  callObjectMethod' env obj method cargs

callVoidMethod :: JNIEnv -> JObject -> JMethodID -> [JValue] -> IO ()
callVoidMethod env obj method args =
  withArray args $ \cargs ->
  callVoidMethod' env obj method cargs

callStaticObjectMethod :: JNIEnv -> JClass -> JMethodID -> [JValue] -> IO JObject
callStaticObjectMethod env cls method args =
  withArray args $ \cargs ->
  callStaticObjectMethod' env cls method cargs

callStaticVoidMethod :: JNIEnv -> JClass -> JMethodID -> [JValue] -> IO ()
callStaticVoidMethod env cls method args =
  withArray args $ \cargs ->
  callStaticVoidMethod' env cls method cargs

callLongMethod :: JNIEnv -> JObject -> JMethodID -> [JValue] -> IO CLong
callLongMethod env obj method args =
  withArray args $ \cargs ->
  callLongMethod' env obj method cargs

newIntArray :: JNIEnv -> CSize -> [CInt] -> IO JIntArray
newIntArray env sz xs =
  withArray xs $ \cxs ->
  newIntArray' env sz cxs

newDoubleArray :: JNIEnv -> CSize -> [CDouble] -> IO JDoubleArray
newDoubleArray env sz xs =
  withArray xs $ \cxs ->
  newDoubleArray' env sz cxs

newByteArray :: JNIEnv -> CSize -> [CChar] -> IO JByteArray
newByteArray env sz xs =
  withArray xs $ \cxs ->
  newByteArray' env sz cxs

newObjectArray :: JNIEnv -> CSize -> JClass -> [JObject] -> IO JObjectArray
newObjectArray env sz cls xs =
  withArray xs $ \cxs ->
  newObjectArray' env sz cls cxs

newString :: JNIEnv -> String -> IO JString
newString env s = withCString s (newString' env)

fromJString :: JNIEnv -> JString -> IO String
fromJString env str = do
  sz <- jstringLen env str
  cs <- jstringChars env str
  peekCStringLen (cs, fromIntegral sz)

jniCtx :: Context
jniCtx = mempty { ctxTypesTable = fromList tytab }
  where
    tytab =
      [ (TypeName "jobject", [t| JObject |])
      , (TypeName "JNIEnv", [t| JNIEnv |])
      ]
