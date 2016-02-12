module Foreign.Java
  ( JVM
  , JNIEnv
  , JObject
  , JClass
  , JMethodID
  , JString
  , JIntArray
  , JByteArray
  , JDoubleArray
  , JObjectArray
  , JValue(..)
  , findClass
  , newObject
  , findMethod
  , findStaticMethod
  , callObjectMethod
  , callVoidMethod
  , callStaticObjectMethod
  , callStaticVoidMethod
  , callLongMethod
  , newIntArray
  , newDoubleArray
  , newByteArray
  , newObjectArray
  , newString
  , fromJString
  ) where

import Foreign.C
import qualified Foreign.Java.Internal as C       -- Low-level bindings.
import Foreign.Java.Types
import Foreign.Marshal.Array

findClass :: JNIEnv -> String -> IO JClass
findClass env s = withCString s (C.findClass env)

newObject :: JNIEnv -> JClass -> String -> [JValue] -> IO JObject
newObject env cls sig args =
  withCString sig $ \csig ->
  withArray args $ \cargs ->
  C.newObject env cls csig cargs

findMethod :: JNIEnv -> JClass -> String -> String -> IO JMethodID
findMethod env cls methodname sig =
  withCString methodname $ \cmethodname ->
  withCString sig $ \csig ->
  C.findMethod env cls cmethodname csig

findStaticMethod :: JNIEnv -> JClass -> String -> String -> IO JMethodID
findStaticMethod env cls methodname sig =
  withCString methodname $ \cmethodname ->
  withCString sig $ \csig ->
  C.findStaticMethod env cls cmethodname csig

callObjectMethod :: JNIEnv -> JObject -> JMethodID -> [JValue] -> IO JObject
callObjectMethod env obj method args =
  withArray args $ \cargs ->
  C.callObjectMethod env obj method cargs

callVoidMethod :: JNIEnv -> JObject -> JMethodID -> [JValue] -> IO ()
callVoidMethod env obj method args =
  withArray args $ \cargs ->
  C.callVoidMethod env obj method cargs

callStaticObjectMethod :: JNIEnv -> JClass -> JMethodID -> [JValue] -> IO JObject
callStaticObjectMethod env cls method args =
  withArray args $ \cargs ->
  C.callStaticObjectMethod env cls method cargs

callStaticVoidMethod :: JNIEnv -> JClass -> JMethodID -> [JValue] -> IO ()
callStaticVoidMethod env cls method args =
  withArray args $ \cargs ->
  C.callStaticVoidMethod env cls method cargs

callLongMethod :: JNIEnv -> JObject -> JMethodID -> [JValue] -> IO CLong
callLongMethod env obj method args =
  withArray args $ \cargs ->
  C.callLongMethod env obj method cargs

newIntArray :: JNIEnv -> CSize -> [CInt] -> IO JIntArray
newIntArray env sz xs =
  withArray xs $ \cxs ->
  C.newIntArray env sz cxs

newDoubleArray :: JNIEnv -> CSize -> [CDouble] -> IO JDoubleArray
newDoubleArray env sz xs =
  withArray xs $ \cxs ->
  C.newDoubleArray env sz cxs

newByteArray :: JNIEnv -> CSize -> [CChar] -> IO JByteArray
newByteArray env sz xs =
  withArray xs $ \cxs ->
  C.newByteArray env sz cxs

newObjectArray :: JNIEnv -> CSize -> JClass -> [JObject] -> IO JObjectArray
newObjectArray env sz cls xs =
  withArray xs $ \cxs ->
  C.newObjectArray env sz cls cxs

newString :: JNIEnv -> String -> IO JString
newString env s = withCString s (C.newString env)

fromJString :: JNIEnv -> JString -> IO String
fromJString env str = do
  sz <- C.jstringLen env str
  cs <- C.jstringChars env str
  peekCStringLen (cs, fromIntegral sz)
