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
    findMethod(spark_conf_class, "setAppName", "(Ljava/lang/String;)Lorg/apache/spark/SparkConf;");

  conf = newObject(spark_conf_class, "()V", NULL);
  jappname = newString(appname);

  (*env)->CallObjectMethod(env, conf, spark_conf_set_appname, jappname);

  return conf;
}

jobject newSparkContext(jobject sparkConf)
{
  jobject spark_ctx =
    newObject(findClass("org/apache/spark/api/java/JavaSparkContext"), "(Lorg/apache/spark/SparkConf;)V", &sparkConf);

  return spark_ctx;
}

jobject parallelize(jobject sparkContext, jint* data, size_t data_length)
{
  JNIEnv* env;
  jclass spark_helper_class;
  jmethodID spark_helper_parallelize;
  jobject resultRDD;

  env = jniEnv();

  spark_helper_class = findClass("Helper");
  
  spark_helper_parallelize =
    findStaticMethod(env, spark_helper_class, "parallelize", "(Lorg/apache/spark/api/java/JavaSparkContext;[I)Lorg/apache/spark/api/java/JavaRDD;");
  
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

  spark_helper_class = findClass("Helper");

  spark_helper_collect =
    findStaticMethod(spark_helper_class, "collect", "(Lorg/apache/spark/api/java/JavaRDD;)[I");

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

  spark_helper_class = findClass("Helper");

  spark_helper_map =
    findStaticMethod(spark_helper_class, "map", "(Lorg/apache/spark/api/java/JavaRDD;[B)Lorg/apache/spark/api/java/JavaRDD;");

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
