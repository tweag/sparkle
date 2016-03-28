-- | Low-level bindings to the Java Native Interface (JNI).
--
-- Read the
-- <https://docs.oracle.com/javase/8/docs/technotes/guides/jni/spec/jniTOC.html JNI spec>
-- for authoritative documentation as to what each of the functions in
-- this module does. The names of the bindings in this module were chosen to
-- match the names of the functions in the JNI spec.
--
-- All bindings in this module access the JNI via a thread-local variable of
-- type @JNIEnv *@. If the current OS thread has not yet been "attached" to the
-- JVM, it is attached implicitly upon the first call to one of these bindings
-- in the current thread.

{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE ViewPatterns #-}

module Foreign.JNI
  ( -- * Java types
    JType(..)
  , type (<>)
    -- * JNI types
  , J(..)
  , upcast
  , unsafeCast
  , JVM(..)
  , JNIEnv(..)
  , JMethodID(..)
  , JFieldID(..)
  , JValue(..)
    -- * JNI defined object types
  , JObject
  , JClass
  , JString
  , JArray
  , JObjectArray
  , JBooleanArray
  , JByteArray
  , JCharArray
  , JShortArray
  , JIntArray
  , JLongArray
  , JFloatArray
  , JDoubleArray
  , JThrowable
    -- * JNI functions
    -- ** Query functions
  , findClass
  , getFieldID
  , getObjectField
  , getMethodID
  , getStaticMethodID
    -- ** Method invocation
  , callObjectMethod
  , callBooleanMethod
  , callIntMethod
  , callLongMethod
  , callByteMethod
  , callDoubleMethod
  , callVoidMethod
  , callStaticObjectMethod
  , callStaticVoidMethod
    -- ** Object construction
  , newObject
  , newIntArray
  , newDoubleArray
  , newByteArray
  , newObjectArray
  , newString
    -- ** Array manipulation
  , getArrayLength
  , getStringLength
  , getIntArrayElements
  , getByteArrayElements
  , getDoubleArrayElements
  , getStringChars
  , setIntArrayRegion
  , setByteArrayRegion
  , setDoubleArrayRegion
  , releaseIntArrayElements
  , releaseByteArrayElements
  , releaseStringChars
  , getObjectArrayElement
  , setObjectArrayElement
  ) where

import Control.Exception (Exception, finally, throwIO)
import Control.Monad (unless)
import Data.Coerce
import Data.Int
import Data.IORef (IORef, newIORef, readIORef)
import Data.Word
import Data.ByteString (ByteString)
import Data.Monoid ((<>))
import Data.Typeable (Typeable)
import Data.TLS.PThread
import Foreign.C (CChar)
import Foreign.JNI.Types
import Foreign.Marshal.Array
import Foreign.Ptr (Ptr, nullPtr)
import qualified Language.C.Inline as C
import qualified Language.C.Inline.Unsafe as CU
import System.IO.Unsafe (unsafePerformIO)

C.context (C.baseCtx <> C.bsCtx <> jniCtx)

C.include "<jni.h>"
C.include "<errno.h>"
C.include "<stdlib.h>"

data JavaException = JavaException JThrowable
  deriving (Show, Typeable)

instance Exception JavaException

-- | Thrown when @Get<PrimitiveType>ArrayElements@ returns a null pointer,
-- because it wanted to copy the array contents but couldn't. In this case the
-- JVM doesn't throw OutOfMemory according to the JNI spec.
data ArrayCopyFailed = ArrayCopyFailed
  deriving (Show, Typeable)

instance Exception ArrayCopyFailed

-- | Map Java exceptions to Haskell exceptions.
throwIfException :: Ptr JNIEnv -> IO a -> IO a
throwIfException env m = m `finally` do
    J excptr <- [CU.exp| jthrowable { (*$(JNIEnv *env))->ExceptionOccurred($(JNIEnv *env)) } |]
    unless (excptr == nullPtr) $ do
      [CU.exp| void { (*$(JNIEnv *env))->ExceptionDescribe($(JNIEnv *env)) } |]
      [CU.exp| void { (*$(JNIEnv *env))->ExceptionClear($(JNIEnv *env)) } |]
      throwIO $ JavaException (J excptr)

-- | Check whether a pointer is null.
throwIfNull :: IO (Ptr a) -> IO (Ptr a)
throwIfNull m = do
    ptr <- m
    if ptr == nullPtr
    then throwIO ArrayCopyFailed
    else return ptr

-- | A global mutable cell holding the TLS variable, whose content is set once
-- for each thread.
envTlsRef :: IORef (TLS (Ptr JNIEnv))
{-# NOINLINE envTlsRef #-}
envTlsRef = unsafePerformIO $ do
    -- It doesn't matter if this computation ends up running twice, say because
    -- of lazy blackholing.
    !tls <- mkTLS $ [C.block| JNIEnv* {
      jsize num_jvms;
      JavaVM *jvm;
      /* Assume there's at most one JVM. The current JNI spec (2016) says only
       * one JVM per process is supported anyways. */
      JNI_GetCreatedJavaVMs(&jvm, 1, &num_jvms);
      JNIEnv *env;

      if(!num_jvms) {
              fprintf(stderr, "No JVM has been initialized yet.\n");
              exit(EFAULT);
      }

      /* Attach as daemon to match GHC's usual semantics for threads, which are
       * daemonic.
       */
      (*jvm)->AttachCurrentThreadAsDaemon(jvm, (void**)&env, NULL);
      return env; } |]
    newIORef tls

-- | Run an action against the appropriate 'JNIEnv'.
--
-- Each OS thread has its own 'JNIEnv', which this function gives access to.
--
-- TODO check whether this call is only safe from a (bound) thread.
withJNIEnv :: (Ptr JNIEnv -> IO a) -> IO a
withJNIEnv f = f =<< getTLS =<< readIORef envTlsRef

findClass :: ByteString -> IO JClass
findClass name = withJNIEnv $ \env ->
    throwIfException env $
    [C.exp| jclass { (*$(JNIEnv *env))->FindClass($(JNIEnv *env), $bs-ptr:name) } |]

newObject :: JClass -> ByteString -> [JValue] -> IO JObject
newObject cls sig args = withJNIEnv $ \env ->
    throwIfException env $
    withArray args $ \cargs -> do
      constr <- getMethodID cls "<init>" sig
      [CU.exp| jobject {
        (*$(JNIEnv *env))->NewObjectA($(JNIEnv *env),
                                      $(jclass cls),
                                      $(jmethodID constr),
                                      $(jvalue *cargs)) } |]

getFieldID :: JClass -> ByteString -> ByteString -> IO JFieldID
getFieldID cls fieldname sig = withJNIEnv $ \env ->
    throwIfException env $
    [CU.exp| jfieldID {
      (*$(JNIEnv *env))->GetFieldID($(JNIEnv *env),
                                    $(jclass cls),
                                    $bs-ptr:fieldname,
                                    $bs-ptr:sig) } |]

getObjectField :: Coercible o (J a) => o -> JFieldID -> IO JObject
getObjectField (coerce -> upcast -> obj) field = withJNIEnv $ \env ->
    throwIfException env $
    [CU.exp| jobject {
      (*$(JNIEnv *env))->GetObjectField($(JNIEnv *env),
                                        $(jobject obj),
                                        $(jfieldID field)) } |]

getMethodID :: JClass -> ByteString -> ByteString -> IO JMethodID
getMethodID cls methodname sig = withJNIEnv $ \env ->
    throwIfException env $
    [CU.exp| jmethodID {
      (*$(JNIEnv *env))->GetMethodID($(JNIEnv *env),
                                     $(jclass cls),
                                     $bs-ptr:methodname,
                                     $bs-ptr:sig) } |]

getStaticMethodID :: JClass -> ByteString -> ByteString -> IO JMethodID
getStaticMethodID cls methodname sig = withJNIEnv $ \env ->
    throwIfException env $
    [CU.exp| jmethodID {
      (*$(JNIEnv *env))->GetStaticMethodID($(JNIEnv *env),
                                           $(jclass cls),
                                           $bs-ptr:methodname,
                                           $bs-ptr:sig) } |]

callObjectMethod :: Coercible o (J a) => o -> JMethodID -> [JValue] -> IO JObject
callObjectMethod (coerce -> upcast -> obj) method args = withJNIEnv $ \env ->
    throwIfException env $
    withArray args $ \cargs ->
    [C.exp| jobject {
      (*$(JNIEnv *env))->CallObjectMethodA($(JNIEnv *env),
                                           $(jobject obj),
                                           $(jmethodID method),
                                           $(jvalue *cargs)) } |]

callBooleanMethod :: Coercible o (J a) => o -> JMethodID -> [JValue] -> IO Word8
callBooleanMethod (coerce -> upcast -> obj) method args = withJNIEnv $ \env ->
    throwIfException env $
    withArray args $ \cargs ->
    [C.exp| jboolean {
      (*$(JNIEnv *env))->CallBooleanMethodA($(JNIEnv *env),
                                         $(jobject obj),
                                         $(jmethodID method),
                                         $(jvalue *cargs)) } |]

callIntMethod :: Coercible o (J a) => o -> JMethodID -> [JValue] -> IO Int32
callIntMethod (coerce -> upcast -> obj) method args = withJNIEnv $ \env ->
    throwIfException env $
    withArray args $ \cargs ->
    [C.exp| jint {
      (*$(JNIEnv *env))->CallIntMethodA($(JNIEnv *env),
                                        $(jobject obj),
                                        $(jmethodID method),
                                        $(jvalue *cargs)) } |]

callLongMethod :: Coercible o (J a) => o -> JMethodID -> [JValue] -> IO Int64
callLongMethod (coerce -> upcast -> obj) method args = withJNIEnv $ \env ->
    throwIfException env $
    withArray args $ \cargs ->
    [C.exp| jlong {
      (*$(JNIEnv *env))->CallLongMethodA($(JNIEnv *env),
                                         $(jobject obj),
                                         $(jmethodID method),
                                         $(jvalue *cargs)) } |]

callByteMethod :: Coercible o (J a) => o -> JMethodID -> [JValue] -> IO CChar
callByteMethod (coerce -> upcast -> obj) method args = withJNIEnv $ \env ->
    throwIfException env $
    withArray args $ \cargs ->
    [C.exp| jbyte {
      (*$(JNIEnv *env))->CallByteMethodA($(JNIEnv *env),
                                         $(jobject obj),
                                         $(jmethodID method),
                                         $(jvalue *cargs)) } |]

callDoubleMethod :: Coercible o (J a) => o -> JMethodID -> [JValue] -> IO Double
callDoubleMethod (coerce -> upcast -> obj) method args = withJNIEnv $ \env ->
    throwIfException env $
    withArray args $ \cargs ->
    [C.exp| jdouble {
      (*$(JNIEnv *env))->CallDoubleMethodA($(JNIEnv *env),
                                           $(jobject obj),
                                           $(jmethodID method),
                                           $(jvalue *cargs)) } |]

callVoidMethod :: Coercible o (J a) => o -> JMethodID -> [JValue] -> IO ()
callVoidMethod (coerce -> upcast -> obj) method args = withJNIEnv $ \env ->
    throwIfException env $
    withArray args $ \cargs ->
    [C.exp| void {
      (*$(JNIEnv *env))->CallVoidMethodA($(JNIEnv *env),
                                         $(jobject obj),
                                         $(jmethodID method),
                                         $(jvalue *cargs)) } |]

callStaticObjectMethod :: JClass -> JMethodID -> [JValue] -> IO JObject
callStaticObjectMethod cls method args = withJNIEnv $ \env ->
    throwIfException env $
    withArray args $ \cargs ->
    [C.exp| jobject {
      (*$(JNIEnv *env))->CallStaticObjectMethodA($(JNIEnv *env),
                                                 $(jclass cls),
                                                 $(jmethodID method),
                                                 $(jvalue *cargs)) } |]

callStaticVoidMethod :: JClass -> JMethodID -> [JValue] -> IO ()
callStaticVoidMethod cls method args = withJNIEnv $ \env ->
    throwIfException env $
    withArray args $ \cargs ->
    [C.exp| void {
      (*$(JNIEnv *env))->CallStaticVoidMethodA($(JNIEnv *env),
                                               $(jclass cls),
                                               $(jmethodID method),
                                               $(jvalue *cargs)) } |]

newIntArray :: Int32 -> IO JIntArray
newIntArray sz = withJNIEnv $ \env ->
    throwIfException env $
    [CU.exp| jintArray {
      (*$(JNIEnv *env))->NewIntArray($(JNIEnv *env),
                                     $(jsize sz)) } |]

newByteArray :: Int32 -> IO JByteArray
newByteArray sz = withJNIEnv $ \env ->
    throwIfException env $
    [CU.exp| jbyteArray {
      (*$(JNIEnv *env))->NewByteArray($(JNIEnv *env),
                                      $(jsize sz)) } |]

newDoubleArray :: Int32 -> IO JDoubleArray
newDoubleArray sz = withJNIEnv $ \env ->
    throwIfException env $
    [CU.exp| jdoubleArray {
      (*$(JNIEnv *env))->NewDoubleArray($(JNIEnv *env),
                                        $(jsize sz)) } |]

newObjectArray :: Int32 -> JClass -> IO JObjectArray
newObjectArray sz cls = withJNIEnv $ \env ->
    throwIfException env $
    [CU.exp| jobjectArray {
      (*$(JNIEnv *env))->NewObjectArray($(JNIEnv *env),
                                        $(jsize sz),
                                        $(jclass cls),
                                        NULL) } |]

newString :: Ptr Word16 -> Int32 -> IO JString
newString ptr len = withJNIEnv $ \env ->
    throwIfException env $
    [CU.exp| jstring {
      (*$(JNIEnv *env))->NewString($(JNIEnv *env),
                                   $(jchar *ptr),
                                   $(jsize len)) } |]

getArrayLength :: Coercible o (JArray a) => o -> IO Int32
getArrayLength (coerce -> upcast -> array) = withJNIEnv $ \env ->
    [C.exp| jsize {
      (*$(JNIEnv *env))->GetArrayLength($(JNIEnv *env),
                                        $(jarray array)) } |]

getStringLength :: JString -> IO Int32
getStringLength jstr = withJNIEnv $ \env ->
    [CU.exp| jsize {
      (*$(JNIEnv *env))->GetStringLength($(JNIEnv *env),
                                         $(jstring jstr)) } |]

getIntArrayElements :: JIntArray -> IO (Ptr Int32)
getIntArrayElements array = withJNIEnv $ \env ->
    throwIfNull $
    [CU.exp| jint* {
      (*$(JNIEnv *env))->GetIntArrayElements($(JNIEnv *env),
                                             $(jintArray array),
                                             NULL) } |]

getByteArrayElements :: JByteArray -> IO (Ptr CChar)
getByteArrayElements array = withJNIEnv $ \env ->
    throwIfNull $
    [CU.exp| jbyte* {
      (*$(JNIEnv *env))->GetByteArrayElements($(JNIEnv *env),
                                              $(jbyteArray array),
                                              NULL) } |]

getDoubleArrayElements :: JDoubleArray -> IO (Ptr Double)
getDoubleArrayElements array = withJNIEnv $ \env ->
    throwIfNull $
    [CU.exp| jdouble* {
      (*$(JNIEnv *env))->GetDoubleArrayElements($(JNIEnv *env),
                                                $(jdoubleArray array),
                                                NULL) } |]

getStringChars :: JString -> IO (Ptr Word16)
getStringChars jstr = withJNIEnv $ \env ->
    throwIfNull $
    [CU.exp| const jchar* {
      (*$(JNIEnv *env))->GetStringChars($(JNIEnv *env),
                                        $(jstring jstr),
                                        NULL) } |]

setIntArrayRegion :: JIntArray -> Int32 -> Int32 -> Ptr Int32 -> IO ()
setIntArrayRegion array start len buf = withJNIEnv $ \env ->
    throwIfException env $
    [CU.exp| void {
      (*$(JNIEnv *env))->SetIntArrayRegion($(JNIEnv *env),
                                            $(jintArray array),
                                            $(jsize start),
                                            $(jsize len),
                                            $(jint *buf)) } |]

setByteArrayRegion :: JByteArray -> Int32 -> Int32 -> Ptr CChar -> IO ()
setByteArrayRegion array start len buf = withJNIEnv $ \env ->
    throwIfException env $
    [CU.exp| void {
      (*$(JNIEnv *env))->SetByteArrayRegion($(JNIEnv *env),
                                            $(jbyteArray array),
                                            $(jsize start),
                                            $(jsize len),
                                            $(jbyte *buf)) } |]

setDoubleArrayRegion :: JDoubleArray -> Int32 -> Int32 -> Ptr Double -> IO ()
setDoubleArrayRegion array start len buf = withJNIEnv $ \env ->
    throwIfException env $
    [CU.exp| void {
      (*$(JNIEnv *env))->SetDoubleArrayRegion($(JNIEnv *env),
                                            $(jdoubleArray array),
                                            $(jsize start),
                                            $(jsize len),
                                            $(jdouble *buf)) } |]

releaseIntArrayElements :: JIntArray -> Ptr Int32 -> IO ()
releaseIntArrayElements array xs = withJNIEnv $ \env ->
    [CU.exp| void {
      (*$(JNIEnv *env))->ReleaseIntArrayElements($(JNIEnv *env),
                                                 $(jintArray array),
                                                 $(jint *xs),
                                                 JNI_ABORT) } |]

releaseByteArrayElements :: JByteArray -> Ptr CChar -> IO ()
releaseByteArrayElements array xs = withJNIEnv $ \env ->
    [CU.exp| void {
      (*$(JNIEnv *env))->ReleaseByteArrayElements($(JNIEnv *env),
                                                  $(jbyteArray array),
                                                  $(jbyte *xs),
                                                  JNI_ABORT) } |]

releaseStringChars :: JString -> Ptr Word16 -> IO ()
releaseStringChars jstr chars = withJNIEnv $ \env ->
    [CU.exp| void {
      (*$(JNIEnv *env))->ReleaseStringChars($(JNIEnv *env),
                                            $(jstring jstr),
                                            $(jchar *chars)) } |]

getObjectArrayElement :: Coercible o (JArray a) => o -> Int32 -> IO (J a)
getObjectArrayElement (coerce -> upcast -> array) i = withJNIEnv $ \env -> unsafeCast <$>
    [C.exp| jobject {
      (*$(JNIEnv *env))->GetObjectArrayElement($(JNIEnv *env),
                                               $(jarray array),
                                               $(jsize i)) } |]

setObjectArrayElement :: Coercible o (J a) => JObjectArray -> Int32 -> o -> IO ()
setObjectArrayElement array i (coerce -> upcast -> x) = withJNIEnv $ \env ->
    [C.exp| void {
      (*$(JNIEnv *env))->SetObjectArrayElement($(JNIEnv *env),
                                               $(jobjectArray array),
                                               $(jsize i),
                                               $(jobject x)); } |]
