#include <jni.h>
#include <stdio.h>
#include "HaskellRTS.h"
#include "SparkClasses.h"

jobject newSparkConf_(JNIEnv* env, const char* appname);
jobject newSparkContext_(JNIEnv* env, jobject sparkConf);
jobject parallelize_(JNIEnv* env, jobject sparkContext, jint* data, size_t data_length);
void    collect_(JNIEnv* env, jobject rdd, int** buf, size_t* len);

jobject newSparkConf(const char* appname)
{
	JNIEnv* env;
        int envStat = (*jvm)->GetEnv(jvm, (void**)&env, JNI_VERSION_1_6);
	if(envStat == JNI_EDETACHED)
	{
		(*jvm)->AttachCurrentThread(jvm, (void**)&env, NULL);
	}
	return newSparkConf_(env, appname);
}

jobject newSparkConf_(JNIEnv* env, const char* appname)
{
	jclass spark_conf_class;
	jmethodID spark_conf_constr;
	jmethodID spark_conf_set_appname;
	jobject conf;
	jstring jappname;

	spark_conf_class =
		(*env)->FindClass(env, "org/apache/spark/SparkConf");

	spark_conf_constr =
		(*env)->GetMethodID(env, spark_conf_class, "<init>", "()V");

	spark_conf_set_appname =
		(*env)->GetMethodID(env, spark_conf_class, "setAppName", "(Ljava/lang/String;)Lorg/apache/spark/SparkConf;");

	conf = (*env)->NewObject(env, spark_conf_class, spark_conf_constr);

	jappname = (*env)->NewStringUTF(env, appname);

	(*env)->CallObjectMethod(env, conf, spark_conf_set_appname, jappname);
	return conf;
}

jobject newSparkContext(jobject sparkConf)
{
        JNIEnv* env;
        int envStat = (*jvm)->GetEnv(jvm, (void**)&env, JNI_VERSION_1_6);
        if(envStat == JNI_EDETACHED)
	{
		(*jvm)->AttachCurrentThread(jvm, (void**)&env, NULL);
	}
        return newSparkContext_(env, sparkConf);
}

jobject newSparkContext_(JNIEnv* env, jobject sparkConf)
{
	jclass spark_context_class;
	jmethodID spark_context_constr;
	jobject spark_ctx;

	spark_context_class = (*env)->FindClass(env, "org/apache/spark/api/java/JavaSparkContext");

	spark_context_constr = (*env)->GetMethodID(env, spark_context_class, "<init>", "(Lorg/apache/spark/SparkConf;)V");

	spark_ctx = (*env)->NewObject(env, spark_context_class, spark_context_constr, sparkConf);

	if(spark_ctx == NULL)
	  printf("!! sparkle: newly created spark context is NULL\n");

	return spark_ctx;
}

jobject parallelize(jobject sparkContext, jint* data, size_t data_length)
{
        JNIEnv* env;
        int envStat = (*jvm)->GetEnv(jvm, (void**)&env, JNI_VERSION_1_6);
        if(envStat == JNI_EDETACHED)
	{
		(*jvm)->AttachCurrentThread(jvm, (void**)&env, NULL);
	}
        return parallelize_(env, sparkContext, data, data_length);
}

jobject parallelize_(JNIEnv* env, jobject sparkContext, jint* data, size_t data_length)
{
  jclass spark_helper_class;
  jmethodID spark_helper_parallelize;
  jobject resultRDD;

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
  int envStat = (*jvm)->GetEnv(jvm, (void**)&env, JNI_VERSION_1_6);
  if(envStat == JNI_EDETACHED)
  {
    (*jvm)->AttachCurrentThread(jvm, (void**)&env, NULL);
  }
  collect_(env, rdd, buf, len);
}

void collect_(JNIEnv* env, jobject rdd, int** buf, size_t* len)
{
  jclass spark_helper_class;
  jmethodID spark_helper_collect;

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
