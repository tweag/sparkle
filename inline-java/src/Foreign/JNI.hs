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
--
-- The 'String' type in this module is the type of JNI strings. See "Foreign.JNI.String".
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE CPP #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE ViewPatterns #-}

{-# OPTIONS_GHC -fno-warn-name-shadowing #-}

module Foreign.JNI
  ( -- * JNI functions
    -- ** VM creation
    withJVM
    -- ** Class loading
  , defineClass
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
  , callCharMethod
  , callShortMethod
  , callByteMethod
  , callDoubleMethod
  , callFloatMethod
  , callVoidMethod
  , callStaticObjectMethod
  , callStaticVoidMethod
  , callStaticBooleanMethod
  , callStaticIntMethod
  , callStaticLongMethod
  , callStaticCharMethod
  , callStaticShortMethod
  , callStaticByteMethod
  , callStaticDoubleMethod
  , callStaticFloatMethod
    -- ** Object construction
  , newObject
  , newString
  , newObjectArray
  , newBooleanArray
  , newByteArray
  , newCharArray
  , newShortArray
  , newIntArray
  , newLongArray
  , newFloatArray
  , newDoubleArray
    -- ** Array manipulation
  , getArrayLength
  , getStringLength
  , getBooleanArrayElements
  , getByteArrayElements
  , getCharArrayElements
  , getShortArrayElements
  , getIntArrayElements
  , getLongArrayElements
  , getFloatArrayElements
  , getDoubleArrayElements
  , getStringChars
  , setBooleanArrayRegion
  , setByteArrayRegion
  , setCharArrayRegion
  , setShortArrayRegion
  , setIntArrayRegion
  , setLongArrayRegion
  , setFloatArrayRegion
  , setDoubleArrayRegion
  , releaseBooleanArrayElements
  , releaseByteArrayElements
  , releaseCharArrayElements
  , releaseShortArrayElements
  , releaseIntArrayElements
  , releaseLongArrayElements
  , releaseFloatArrayElements
  , releaseDoubleArrayElements
  , releaseStringChars
  , getObjectArrayElement
  , setObjectArrayElement
  ) where

import Control.Exception (Exception, bracket, finally, throwIO)
import Control.Monad (unless)
import Data.Coerce
import Data.Int
import Data.IORef (IORef, newIORef, readIORef)
import Data.Word
import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import Data.Monoid ((<>))
import Data.Typeable (Typeable)
import Data.TLS.PThread
import Foreign.C (CChar)
import Foreign.JNI.Types
import qualified Foreign.JNI.String as JNI
import Foreign.Marshal.Array
import Foreign.Ptr (Ptr, nullPtr)
import qualified Language.C.Inline as C
import qualified Language.C.Inline.Unsafe as CU
import System.IO.Unsafe (unsafePerformIO)
import Prelude hiding (String)

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

useAsCStrings :: [ByteString] -> ([Ptr CChar] -> IO a) -> IO a
useAsCStrings strs m =
  foldr (\str k cstrs -> BS.useAsCString str $ \cstr -> k (cstr:cstrs)) m strs []

-- | Create a new JVM, with the given arguments. /Can only be called once/. Best
-- practice: use it to wrap your @main@ function.
withJVM :: [ByteString] -> IO a -> IO a
withJVM options action =
    bracket ini fini (const action)
  where
    ini = do
      useAsCStrings options $ \cstrs -> do
        withArray cstrs $ \(coptions :: Ptr (Ptr CChar)) -> do
          let n = fromIntegral (length cstrs) :: C.CInt
          [C.block| JavaVM * {
            JavaVM *jvm;
            JNIEnv *env;
            JavaVMInitArgs vm_args;
            JavaVMOption *options = malloc(sizeof(JavaVMOption) * $(int n));
            for(int i = 0; i < $(int n); i++)
                    options[0].optionString = $(char **coptions)[i];
            vm_args.version = JNI_VERSION_1_6;
            vm_args.nOptions = $(int n);
            vm_args.options = options;
            vm_args.ignoreUnrecognized = 0;
            JNI_CreateJavaVM(&jvm, (void**)&env, &vm_args);
            free(options);
            return jvm; } |]
    fini jvm = [C.block| void { (*$(JavaVM *jvm))->DestroyJavaVM($(JavaVM *jvm)); } |]

defineClass
  :: Coercible o (J ('Class "java.lang.ClassLoader"))
  => JNI.String -- ^ Class name
  -> o          -- ^ Loader
  -> ByteString -- ^ Bytecode buffer
  -> IO JClass
defineClass name (coerce -> upcast -> loader) buf = withJNIEnv $ \env ->
    throwIfException env $
    JNI.withString name $ \namep ->
    [CU.exp| jclass {
      (*$(JNIEnv *env))->DefineClass($(JNIEnv *env),
                                     $(char *namep),
                                     $(jobject loader),
                                     $bs-ptr:buf,
                                     $bs-len:buf) } |]

findClass
  :: JNI.String -- ^ Class name
  -> IO JClass
findClass name = withJNIEnv $ \env ->
    throwIfException env $
    JNI.withString name $ \namep ->
    [CU.exp| jclass { (*$(JNIEnv *env))->FindClass($(JNIEnv *env), $(char *namep)) } |]

newObject :: JClass -> JNI.String -> [JValue] -> IO JObject
newObject cls sig args = withJNIEnv $ \env ->
    throwIfException env $
    withArray args $ \cargs -> do
      constr <- getMethodID cls "<init>" sig
      [CU.exp| jobject {
        (*$(JNIEnv *env))->NewObjectA($(JNIEnv *env),
                                      $(jclass cls),
                                      $(jmethodID constr),
                                      $(jvalue *cargs)) } |]

getFieldID
  :: JClass -- ^ A class object as returned by 'findClass'
  -> JNI.String -- ^ Field name
  -> JNI.String -- ^ JNI signature
  -> IO JFieldID
getFieldID cls fieldname sig = withJNIEnv $ \env ->
    throwIfException env $
    JNI.withString fieldname $ \fieldnamep ->
    JNI.withString sig $ \sigp ->
    [CU.exp| jfieldID {
      (*$(JNIEnv *env))->GetFieldID($(JNIEnv *env),
                                    $(jclass cls),
                                    $(char *fieldnamep),
                                    $(char *sigp)) } |]

getObjectField
  :: Coercible o (J a)
  => o -- ^ Any object of any class
  -> JFieldID
  -> IO JObject
getObjectField (coerce -> upcast -> obj) field = withJNIEnv $ \env ->
    throwIfException env $
    [CU.exp| jobject {
      (*$(JNIEnv *env))->GetObjectField($(JNIEnv *env),
                                        $(jobject obj),
                                        $(jfieldID field)) } |]

getMethodID
  :: JClass -- ^ A class object as returned by 'findClass'
  -> JNI.String -- ^ Field name
  -> JNI.String -- ^ JNI signature
  -> IO JMethodID
getMethodID cls methodname sig = withJNIEnv $ \env ->
    throwIfException env $
    JNI.withString methodname $ \methodnamep ->
    JNI.withString sig $ \sigp ->
    [CU.exp| jmethodID {
      (*$(JNIEnv *env))->GetMethodID($(JNIEnv *env),
                                     $(jclass cls),
                                     $(char *methodnamep),
                                     $(char *sigp)) } |]

getStaticMethodID
  :: JClass -- ^ A class object as returned by 'findClass'
  -> JNI.String -- ^ Field name
  -> JNI.String -- ^ JNI signature
  -> IO JMethodID
getStaticMethodID cls methodname sig = withJNIEnv $ \env ->
    throwIfException env $
    JNI.withString methodname $ \methodnamep ->
    JNI.withString sig $ \sigp ->
    [CU.exp| jmethodID {
      (*$(JNIEnv *env))->GetStaticMethodID($(JNIEnv *env),
                                           $(jclass cls),
                                           $(char *methodnamep),
                                           $(char *sigp)) } |]

-- Modern CPP does have ## for concatenating strings, but we use the hacky /**/
-- comment syntax for string concatenation. This is because GHC passes
-- the -traditional flag to the preprocessor by default, which turns off several
-- modern CPP features.

#define CALL_METHOD(name, hs_rettype, c_rettype) \
call/**/name/**/Method :: Coercible o (J a) => o -> JMethodID -> [JValue] -> IO hs_rettype; \
call/**/name/**/Method (coerce -> upcast -> obj) method args = withJNIEnv $ \env -> \
    throwIfException env $ \
    withArray args $ \cargs -> \
    [C.exp| c_rettype { \
      (*$(JNIEnv *env))->Call/**/name/**/MethodA($(JNIEnv *env), \
                                               $(jobject obj), \
                                               $(jmethodID method), \
                                               $(jvalue *cargs)) } |]

CALL_METHOD(Void, (), void)
CALL_METHOD(Object, JObject, jobject)
callBooleanMethod :: Coercible o (J a) => o -> JMethodID -> [JValue] -> IO Bool
callBooleanMethod x y z =
    let CALL_METHOD(Boolean, Word8, jboolean)
    in toEnum . fromIntegral <$> callBooleanMethod x y z
CALL_METHOD(Byte, CChar, jbyte)
CALL_METHOD(Char, Word16, jchar)
CALL_METHOD(Short, Int16, jshort)
CALL_METHOD(Int, Int32, jint)
CALL_METHOD(Long, Int64, jlong)
CALL_METHOD(Float, Float, jfloat)
CALL_METHOD(Double, Double, jdouble)

#define CALL_STATIC_METHOD(name, hs_rettype, c_rettype) \
callStatic/**/name/**/Method :: JClass -> JMethodID -> [JValue] -> IO hs_rettype; \
callStatic/**/name/**/Method cls method args = withJNIEnv $ \env -> \
    throwIfException env $ \
    withArray args $ \cargs -> \
    [C.exp| c_rettype { \
      (*$(JNIEnv *env))->CallStatic/**/name/**/MethodA($(JNIEnv *env), \
                                                       $(jclass cls), \
                                                       $(jmethodID method), \
                                                       $(jvalue *cargs)) } |]

CALL_STATIC_METHOD(Void, (), void)
CALL_STATIC_METHOD(Object, JObject, jobject)
callStaticBooleanMethod :: JClass -> JMethodID -> [JValue] -> IO Bool
callStaticBooleanMethod x y z =
    let CALL_STATIC_METHOD(Boolean, Word8, jboolean)
    in toEnum . fromIntegral <$> callStaticBooleanMethod x y z
CALL_STATIC_METHOD(Byte, CChar, jbyte)
CALL_STATIC_METHOD(Char, Word16, jchar)
CALL_STATIC_METHOD(Short, Int16, jshort)
CALL_STATIC_METHOD(Int, Int32, jint)
CALL_STATIC_METHOD(Long, Int64, jlong)
CALL_STATIC_METHOD(Float, Float, jfloat)
CALL_STATIC_METHOD(Double, Double, jdouble)

newObjectArray :: Int32 -> JClass -> IO JObjectArray
newObjectArray sz cls = withJNIEnv $ \env ->
    throwIfException env $
    [CU.exp| jobjectArray {
      (*$(JNIEnv *env))->NewObjectArray($(JNIEnv *env),
                                        $(jsize sz),
                                        $(jclass cls),
                                        NULL) } |]

#define NEW_ARRAY(name, c_rettype) \
new/**/name/**/Array :: Int32 -> IO J/**/name/**/Array; \
new/**/name/**/Array sz = withJNIEnv $ \env -> \
    throwIfException env $ \
    [CU.exp| c_rettype/**/Array { \
      (*$(JNIEnv *env))->New/**/name/**/Array($(JNIEnv *env), \
                                              $(jsize sz)) } |]

NEW_ARRAY(Boolean, jboolean)
NEW_ARRAY(Byte, jbyte)
NEW_ARRAY(Char, jchar)
NEW_ARRAY(Short, jshort)
NEW_ARRAY(Int, jint)
NEW_ARRAY(Long, jlong)
NEW_ARRAY(Float, jfloat)
NEW_ARRAY(Double, jdouble)

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

#define GET_ARRAY_ELEMENTS(name, hs_rettype, c_rettype) \
get/**/name/**/ArrayElements :: J/**/name/**/Array -> IO (Ptr hs_rettype); \
get/**/name/**/ArrayElements (upcast -> array) = withJNIEnv $ \env -> \
    throwIfNull $ \
    [CU.exp| c_rettype* { \
      (*$(JNIEnv *env))->GetIntArrayElements($(JNIEnv *env), \
                                             $(jobject array), \
                                             NULL) } |]

GET_ARRAY_ELEMENTS(Boolean, Word8, jboolean)
GET_ARRAY_ELEMENTS(Byte, CChar, jbyte)
GET_ARRAY_ELEMENTS(Char, Word16, jchar)
GET_ARRAY_ELEMENTS(Short, Int16, jshort)
GET_ARRAY_ELEMENTS(Int, Int32, jint)
GET_ARRAY_ELEMENTS(Long, Int64, jlong)
GET_ARRAY_ELEMENTS(Float, Float, jfloat)
GET_ARRAY_ELEMENTS(Double, Double, jdouble)

getStringChars :: JString -> IO (Ptr Word16)
getStringChars jstr = withJNIEnv $ \env ->
    throwIfNull $
    [CU.exp| const jchar* {
      (*$(JNIEnv *env))->GetStringChars($(JNIEnv *env),
                                        $(jstring jstr),
                                        NULL) } |]

#define SET_ARRAY_REGION(name, hs_argtype, c_argtype) \
set/**/name/**/ArrayRegion :: J/**/name/**/Array -> Int32 -> Int32 -> Ptr hs_argtype -> IO (); \
set/**/name/**/ArrayRegion array start len buf = withJNIEnv $ \env -> \
    throwIfException env $ \
    [CU.exp| void { \
      (*$(JNIEnv *env))->SetIntArrayRegion($(JNIEnv *env), \
                                            $(c_argtype/**/Array array), \
                                            $(jsize start), \
                                            $(jsize len), \
                                            $(c_argtype *buf)) } |]

SET_ARRAY_REGION(Boolean, Word8, jboolean)
SET_ARRAY_REGION(Byte, CChar, jbyte)
SET_ARRAY_REGION(Char, Word16, jchar)
SET_ARRAY_REGION(Short, Int16, jshort)
SET_ARRAY_REGION(Int, Int32, jint)
SET_ARRAY_REGION(Long, Int64, jlong)
SET_ARRAY_REGION(Float, Float, jfloat)
SET_ARRAY_REGION(Double, Double, jdouble)

#define RELEASE_ARRAY_ELEMENTS(name, hs_argtype, c_argtype) \
release/**/name/**/ArrayElements :: J/**/name/**/Array -> Ptr hs_argtype -> IO (); \
release/**/name/**/ArrayElements (upcast -> array) xs = withJNIEnv $ \env -> \
    [CU.exp| void { \
      (*$(JNIEnv *env))->Release/**/name/**/ArrayElements($(JNIEnv *env), \
                                                          $(jobject array), \
                                                          $(c_argtype *xs), \
                                                          JNI_ABORT) } |]

RELEASE_ARRAY_ELEMENTS(Boolean, Word8, jboolean)
RELEASE_ARRAY_ELEMENTS(Byte, CChar, jbyte)
RELEASE_ARRAY_ELEMENTS(Char, Word16, jchar)
RELEASE_ARRAY_ELEMENTS(Short, Int16, jshort)
RELEASE_ARRAY_ELEMENTS(Int, Int32, jint)
RELEASE_ARRAY_ELEMENTS(Long, Int64, jlong)
RELEASE_ARRAY_ELEMENTS(Float, Float, jfloat)
RELEASE_ARRAY_ELEMENTS(Double, Double, jdouble)

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
