#include <jni.h>
#include <stdio.h>
#include "Java.h"

JNIEnv* jniEnv(JavaVM* jvm)
{
  JNIEnv* env;
  int envStat = (*jvm)->GetEnv(jvm, (void**)&env, JNI_VERSION_1_6);
  if(envStat == JNI_EDETACHED)
    (*jvm)->AttachCurrentThread(jvm, (void**)& env, NULL);
  return env;
}

jclass findClass(JNIEnv* env, const char* java_class)
{
  jclass class = (*env)->FindClass(env, java_class);
  if(!class)
  {
    printf("!! sparkle: Couldn't find Java class %s\n", java_class);
    return NULL;
  }
  return class;
}

jmethodID findMethod(JNIEnv* env, jclass java_class, const char* method_name, const char* sig)
{
  jmethodID mid = (*env)->GetMethodID(env, java_class, method_name, sig);
  if(!mid)
  {
    printf("!! sparkle: Couldn't find method %s with signature %s", method_name, sig);
    return NULL;
  }
  return mid;
}

jmethodID findStaticMethod(JNIEnv* env, jclass java_class, const char* method_name, const char* sig)
{
  jmethodID mid = (*env)->GetStaticMethodID(env, java_class, method_name, sig);
  if(!mid)
  {
    printf("!! sparkle: Couldn't find static method %s with signature %s", method_name, sig);
    return NULL;
  }
  return mid;
}

jobject callObjectMethod(JNIEnv* env, jobject obj, jmethodID method, jvalue* args)
{
  jobject res = (*env)->CallObjectMethodA(env, obj, method, args);
  /*
  if(!res)
  {
    printf("!! sparkle: callObjectMethod returned NULL\n");
    return NULL;
  }
  */

  return res;
}

void callVoidMethod(JNIEnv* env, jclass java_class, jmethodID method, jvalue* args)
{
  (*env)->CallVoidMethodA(env, java_class, method, args);
}

jobject callStaticObjectMethod(JNIEnv* env, jclass java_class, jmethodID method, jvalue* args)
{
  jobject res = (*env)->CallStaticObjectMethodA(env, java_class, method, args);
  /*
  if(!res)
  {
    printf("!! sparkle: callStaticObjectMethod returned NULL\n");
    return NULL;
  }
  */

  return res;
}

void callStaticVoidMethod(JNIEnv* env, jclass java_class, jmethodID method, jvalue* args)
{
  (*env)->CallStaticVoidMethodA(env, java_class, method, args);
}

long callLongMethod(JNIEnv* env, jobject obj, jmethodID method, jvalue* args)
{
  return (*env)->CallLongMethodA(env, obj, method, args);
}

jobject newObject(JNIEnv* env, jclass java_class, const char* sig, const jvalue* args)
{
  jmethodID constr;
  jobject obj;

  constr = findMethod(env, java_class, "<init>", sig);

  obj = (*env)->NewObjectA(env, java_class, constr, args);
  if(!obj)
  {
    printf("!! sparkle: Constructor with signature %s failed\n", sig);
    return NULL;
  }

  return obj;
}

jstring newString(JNIEnv* env, const char* str)
{
  return (*env)->NewStringUTF(env, str);
}

jintArray newIntArray(JNIEnv* env, size_t size, int* data)
{
  jintArray arr = (*env)->NewIntArray(env, size);
  if(!arr)
  {
    printf("!! sparkle: jintArray of size %zd cannot be allocated", size);
    return NULL;
  }

  (*env)->SetIntArrayRegion(env, arr, 0, size, data);
  return arr;
}

jbyteArray newByteArray(JNIEnv* env, size_t size, jbyte* data)
{
  jbyteArray arr = (*env)->NewByteArray(env, size);
  if(!arr)
  {
    printf("!! sparkle: jbyteArray of size %zd cannot be allocated", size);
    return NULL;
  }

  (*env)->SetByteArrayRegion(env, arr, 0, size, data);
  return arr;
}

jdoubleArray newDoubleArray(JNIEnv* env, size_t size, jdouble* data)
{
  jdoubleArray arr = (*env)->NewByteArray(env, size);
  if(!arr)
  {
    printf("!! sparkle: jdoubleArray of size %zd cannot be allocated", size);
    return NULL;
  }

  (*env)->SetDoubleArrayRegion(env, arr, 0, size, data);
  return arr;
}

jobjectArray newObjectArray(JNIEnv* env, size_t size, jclass cls, jobject* data)
{
  size_t i = 0;
  jobjectArray arr = (*env)->NewObjectArray(env, size, cls, NULL);
  if(!arr)
  {
    printf("!! sparkle: jobjectArray of size %zd cannot be allocated", size);
    return NULL;
  }
  for(; i < size; i++)
    (*env)->SetObjectArrayElement(env, arr, i, data[i]);

  return arr;
}

size_t jstringLen(JNIEnv* env, jstring s)
{
  return (*env)->GetStringUTFLength(env, s);
}

const char* jstringChars(JNIEnv* env, jstring s)
{
  return (*env)->GetStringUTFChars(env, s, NULL);
}

void checkForExc(JNIEnv* env)
{
  jthrowable exc = (*env)->ExceptionOccurred(env);
  if(exc)
  {
    (*env)->ExceptionDescribe(env);
    (*env)->ExceptionClear(env);
  }
}

// TODO: get rid of this
void collect(JNIEnv* env, jobject rdd, int** buf, size_t* len)
{
  jclass spark_helper_class = findClass(env, "Helper");
  jmethodID spark_helper_collect =
    findStaticMethod(env, spark_helper_class, "collect", "(Lorg/apache/spark/api/java/JavaRDD;)[I");
  jvalue arg;
  arg.l = rdd;
  jintArray elements = callStaticObjectMethod(env, spark_helper_class, spark_helper_collect, &arg);
  if(elements == NULL)
  {
    printf("!! sparkle: collect() returned NULL\n");
    jthrowable exc;
    exc = (*env)->ExceptionOccurred(env);
    if(exc)
    {
      (*env)->ExceptionDescribe(env);
      (*env)->ExceptionClear(env);
      return;
    }
  }

  *len = (*env)->GetArrayLength(env, elements);

  int* finalArr = (int*) malloc((*len) * sizeof(int));
  finalArr = (*env)->GetIntArrayElements(env, elements, NULL);

  *buf = finalArr;
}
