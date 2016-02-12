module Foreign.Java.Internal where

import Foreign.C
import Foreign.Java.Types
import Foreign.Ptr

foreign import ccall unsafe jniEnv
  :: JVM
  -> IO JNIEnv

foreign import ccall unsafe findClass
  :: JNIEnv
  -> CString
  -> IO JClass

foreign import ccall unsafe newObject
  :: JNIEnv
  -> JClass
  -> CString
  -> Ptr JValue
  -> IO JObject

foreign import ccall unsafe findMethod
  :: JNIEnv
  -> JClass
  -> CString
  -> CString
  -> IO JMethodID

foreign import ccall unsafe findStaticMethod
  :: JNIEnv
  -> JClass
  -> CString
  -> CString
  -> IO JMethodID

foreign import ccall unsafe callObjectMethod
  :: JNIEnv
  -> JObject
  -> JMethodID
  -> Ptr JValue
  -> IO JObject

foreign import ccall safe callStaticObjectMethod
  :: JNIEnv
  -> JClass
  -> JMethodID
  -> Ptr JValue
  -> IO JObject

foreign import ccall safe callStaticVoidMethod
  :: JNIEnv
  -> JClass
  -> JMethodID
  -> Ptr JValue
  -> IO ()

foreign import ccall safe callVoidMethod
  :: JNIEnv
  -> JObject
  -> JMethodID
  -> Ptr JValue
  -> IO ()

foreign import ccall safe callLongMethod
  :: JNIEnv
  -> JObject
  -> JMethodID
  -> Ptr JValue
  -> IO CLong

foreign import ccall unsafe newIntArray
  :: JNIEnv
  -> CSize
  -> Ptr CInt
  -> IO JIntArray

foreign import ccall unsafe newDoubleArray
  :: JNIEnv
  -> CSize
  -> Ptr CDouble
  -> IO JDoubleArray

foreign import ccall unsafe newByteArray
  :: JNIEnv
  -> CSize
  -> Ptr CChar
  -> IO JByteArray

foreign import ccall unsafe newObjectArray
  :: JNIEnv
  -> CSize
  -> JClass
  -> Ptr JObject
  -> IO JObjectArray

foreign import ccall unsafe newString
  :: JNIEnv
  -> Ptr CChar
  -> IO JString

foreign import ccall unsafe jstringLen
  :: JNIEnv
  -> JString
  -> IO CSize

foreign import ccall unsafe jstringChars
  :: JNIEnv
  -> JString
  -> IO (Ptr CChar)

foreign import ccall unsafe "checkForExc" checkForException
  :: JNIEnv
  -> IO ()
