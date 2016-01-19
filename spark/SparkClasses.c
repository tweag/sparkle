#include <jni.h>
#include <stdio.h>
#include "HaskellRTS.h"
#include "JVM.h"
#include "SparkClasses.h"

JNIEnv* jniEnv()
{
  JNIEnv* env;
  int envStat = (*jvm)->GetEnv(jvm, (void**)&env, JNI_VERSION_1_6);
  if(envStat == JNI_EDETACHED)
    (*jvm)->AttachCurrentThread(jvm, (void**)& env, NULL);
  return env;
}

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

jobject newObject(const char* java_class, const char* sig, const jvalue* args)
{
  JNIEnv* env = jniEnv();
  jclass class_ref;
  jmethodID constr;
  jobject obj;

  class_ref = findClass(java_class);

  constr = (*env)->GetMethodID(env, class_ref, "<init>", sig);
  if(!constr)
  {
    printf("!! sparkle: Couldn't find constructor with signature %s in class %s\n", sig, java_class);
    return NULL;
  }

  obj = (*env)->NewObjectA(env, class_ref, constr, args);
  if(!obj)
  {
    printf("!! sparkle: Constructor for class %s with signature %s failed\n", java_class, sig);
    return NULL;
  }

  return obj;
}

jstring newString(const char* str)
{
  JNIEnv* env = jniEnv();
  return (*env)->NewStringUTF(env, str);
}

jobject newSparkConf(const char* appname)
{
  JNIEnv* env;
  jclass spark_conf_class;
  jmethodID spark_conf_set_appname;
  jobject conf;
  jstring jappname;

  env = jniEnv();

  spark_conf_class = findClass("org/apache/spark/SparkConf");

  spark_conf_set_appname =
    (*env)->GetMethodID(env, spark_conf_class, "setAppName", "(Ljava/lang/String;)Lorg/apache/spark/SparkConf;");

  conf = newObject("org/apache/spark/SparkConf", "()V", NULL);
  jappname = newString(appname);

  (*env)->CallObjectMethod(env, conf, spark_conf_set_appname, jappname);

  return conf;
}

jobject newSparkContext(jobject sparkConf)
{
  jobject spark_ctx =
    newObject("org/apache/spark/api/java/JavaSparkContext", "(Lorg/apache/spark/SparkConf;)V", &sparkConf);

  return spark_ctx;
}

jobject parallelize(jobject sparkContext, jint* data, size_t data_length)
{
  JNIEnv* env;
  jclass spark_helper_class;
  jmethodID spark_helper_parallelize;
  jobject resultRDD;

  env = jniEnv();

  spark_helper_class = (*env)->FindClass(env, "Helper");
  if(!spark_helper_class)
  {
    printf("!! sparkle: Couldn't find Helper class\n");
    return NULL;
  }
  
  spark_helper_parallelize =
    (*env)->GetStaticMethodID(env, spark_helper_class, "parallelize", "(Lorg/apache/spark/api/java/JavaSparkContext;[I)Lorg/apache/spark/api/java/JavaRDD;");

  if(!spark_helper_parallelize)
  {
    printf("!! sparkle: Couldn't find method Helper.parallelize\n");
    return NULL;
  }
  
  jintArray finalData = (*env)->NewIntArray(env, data_length);

  if(finalData == NULL)
  {
    printf("!! sparkle: jintArray could not be allocated\n");
    return NULL;
  }
  
  (*env)->SetIntArrayRegion(env, finalData, 0, data_length, data);

  resultRDD = (*env)->CallStaticObjectMethod(env, spark_helper_class, spark_helper_parallelize, sparkContext, finalData);
  if(resultRDD == NULL)
  { 
    printf("!! sparkle: parallelize() returned NULL\n");
    jthrowable exc;
    exc = (*env)->ExceptionOccurred(env);
    if(exc)
    {
      (*env)->ExceptionDescribe(env);
      (*env)->ExceptionClear(env);
      return NULL;
    }
  }

  return resultRDD;
}

void collect(jobject rdd, int** buf, size_t* len)
{
  JNIEnv* env;
  jclass spark_helper_class;
  jmethodID spark_helper_collect;

  env = jniEnv();

  spark_helper_class = (*env)->FindClass(env, "Helper");
  if(!spark_helper_class)
  {
    printf("!! sparkle: Couldn't find Helper class\n");
    return;
  }

  spark_helper_collect =
    (*env)->GetStaticMethodID(env, spark_helper_class, "collect", "(Lorg/apache/spark/api/java/JavaRDD;)[I");

  if(!spark_helper_collect)
  {
    printf("!! sparkle: Couldn't find method Helper.collect\n");
    return;
  }

  jintArray elements;

  elements = (*env)->CallStaticObjectMethod(env, spark_helper_class, spark_helper_collect, rdd);
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

jobject rddmap(jobject rdd, char* clos, long closSize)
{
  JNIEnv* env = jniEnv();
  jbyteArray closArr = (*env)->NewByteArray(env, closSize);
  (*env)->SetByteArrayRegion(env, closArr, 0, closSize, clos);

  jclass spark_helper_class;
  jmethodID spark_helper_map;
  jobject resultRDD;

  spark_helper_class = (*env)->FindClass(env, "Helper");
  if(!spark_helper_class)
  {
    printf("!! sparkle: Couldn't find Helper class\n");
    return NULL;
  }

  spark_helper_map =
    (*env)->GetStaticMethodID(env, spark_helper_class, "map", "(Lorg/apache/spark/api/java/JavaRDD;[B)Lorg/apache/spark/api/java/JavaRDD;");

  if(!spark_helper_map)
  {
    printf("!! sparkle: Couldn't find method Helper.map\n");
    return NULL;
  }

  resultRDD = (*env)->CallStaticObjectMethod(env, spark_helper_class, spark_helper_map, rdd, closArr);
  if(resultRDD == NULL)
  {
    printf("!! sparkle: map() returned NULL\n");
    jthrowable exc;
    exc = (*env)->ExceptionOccurred(env);
    if(exc)
    {
      (*env)->ExceptionDescribe(env);
      (*env)->ExceptionClear(env);
      return NULL;
    }
  }

  return resultRDD;
}
