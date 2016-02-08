#include <jni.h>
#include <stdio.h>
#include "HaskellRTS.h"
#include "JVM.h"
#include "Java.h"

jclass findClass(const char* java_class)
{
  JNIEnv* env = jniEnv();
  jclass class = (*env)->FindClass(env, java_class);
  if(!class)
  {
    printf("!! sparkle: Couldn't find Java class %s\n", java_class);
    return NULL;
  }
  return class;
}

jmethodID findMethod(jclass java_class, const char* method_name, const char* sig)
{
  JNIEnv* env = jniEnv();
  jmethodID mid = (*env)->GetMethodID(env, java_class, method_name, sig);
  if(!mid)
  {
    printf("!! sparkle: Couldn't find method %s with signature %s", method_name, sig);
    return NULL;
  }
  return mid;
}

jmethodID findStaticMethod(jclass java_class, const char* method_name, const char* sig)
{
  JNIEnv* env = jniEnv();
  jmethodID mid = (*env)->GetStaticMethodID(env, java_class, method_name, sig);
  if(!mid)
  {
    printf("!! sparkle: Couldn't find static method %s with signature %s", method_name, sig);
    return NULL;
  }
  return mid;
}

jobject callObjectMethod(jobject obj, jmethodID method, jvalue* args)
{
  JNIEnv* env = jniEnv();
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

void callVoidMethod(jclass java_class, jmethodID method, jvalue* args)
{
  JNIEnv* env = jniEnv();
  (*env)->CallVoidMethodA(env, java_class, method, args);
}

jobject callStaticObjectMethod(jclass java_class, jmethodID method, jvalue* args)
{
  JNIEnv* env = jniEnv();
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

void callStaticVoidMethod(jclass java_class, jmethodID method, jvalue* args)
{
  JNIEnv* env = jniEnv();
  (*env)->CallStaticVoidMethodA(env, java_class, method, args);
}

jobject newObject(jclass java_class, const char* sig, const jvalue* args)
{
  JNIEnv* env = jniEnv();
  jmethodID constr;
  jobject obj;

  constr = findMethod(java_class, "<init>", sig);

  obj = (*env)->NewObjectA(env, java_class, constr, args);
  if(!obj)
  {
    printf("!! sparkle: Constructor with signature %s failed\n", sig);
    return NULL;
  }

  return obj;
}

jstring newString(const char* str)
{
  JNIEnv* env = jniEnv();
  return (*env)->NewStringUTF(env, str);
}

jintArray newIntArray(size_t size, int* data)
{
  JNIEnv* env = jniEnv();
  jintArray arr = (*env)->NewIntArray(env, size);
  if(!arr)
  {
    printf("!! sparkle: jintArray of size %zd cannot be allocated", size);
    return NULL;
  }

  (*env)->SetIntArrayRegion(env, arr, 0, size, data);
  return arr;
}

jbyteArray newByteArray(size_t size, jbyte* data)
{
  JNIEnv* env = jniEnv();
  jbyteArray arr = (*env)->NewByteArray(env, size);
  if(!arr)
  {
    printf("!! sparkle: jbyteArray of size %zd cannot be allocated", size);
    return NULL;
  }

  (*env)->SetByteArrayRegion(env, arr, 0, size, data);
  return arr;
}

jdoubleArray newDoubleArray(size_t size, jdouble* data)
{
  JNIEnv* env = jniEnv();
  jdoubleArray arr = (*env)->NewByteArray(env, size);
  if(!arr)
  {
    printf("!! sparkle: jdoubleArray of size %zd cannot be allocated", size);
    return NULL;
  }

  (*env)->SetDoubleArrayRegion(env, arr, 0, size, data);
  return arr;
}

jobjectArray newObjectArray(size_t size, jclass cls, jobject* data)
{
  size_t i = 0;
  JNIEnv* env = jniEnv();
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

size_t jstringLen(jstring s)
{
  JNIEnv* env = jniEnv();
  return (*env)->GetStringUTFLength(env, s);
}

const char* jstringChars(jstring s)
{
  JNIEnv* env = jniEnv();
  return (*env)->GetStringUTFChars(env, s, NULL);
}

void checkForExc()
{
  JNIEnv* env = jniEnv();
  jthrowable exc = (*env)->ExceptionOccurred(env);
  if(exc)
  {
    (*env)->ExceptionDescribe(env);
    (*env)->ExceptionClear(env);
  }
}

// TODO: get rid of this
void collect(jobject rdd, int** buf, size_t* len)
{
  JNIEnv* env = jniEnv();
  jclass spark_helper_class = findClass("Helper");
  jmethodID spark_helper_collect =
    findStaticMethod(spark_helper_class, "collect", "(Lorg/apache/spark/api/java/JavaRDD;)[I");
  jvalue arg;
  arg.l = rdd;
  jintArray elements = callStaticObjectMethod(spark_helper_class, spark_helper_collect, &arg);
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
