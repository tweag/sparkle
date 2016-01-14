#include <jni.h>
#include <stdio.h>
#include "HaskellRTS.h"
#include "SparkClasses.h"

jobject newSparkConf_(JNIEnv* env, const char* appname);
jobject newSparkContext_(JNIEnv* env, jobject sparkConf);
jobject parallelize_(JNIEnv* env, jobject sparkContext, int* data, size_t data_length); 

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

	spark_context_class = (*env)->FindClass(env, "org/apache/spark/SparkContext");

	spark_context_constr = (*env)->GetMethodID(env, spark_context_class, "<init>", "(Lorg/apache/spark/SparkConf;)V");

	spark_ctx = (*env)->NewObject(env, spark_context_class, spark_context_constr, sparkConf);

	return spark_ctx;
}

jobject parallelize(jobject sparkContext, int* data, size_t data_length)
{
        JNIEnv* env;
        int envStat = (*jvm)->GetEnv(jvm, (void**)&env, JNI_VERSION_1_6);
        if(envStat == JNI_EDETACHED)
	{
		(*jvm)->AttachCurrentThread(jvm, (void**)&env, NULL);
	}
        return parallelize_(env, sparkContext, data, data_length);
}

jobject parallelize_(JNIEnv* env, jobject sparkContext, int* data, size_t data_length)
{
  jclass spark_helper_class;
  jmethodID spark_context_parallelize;
  jobject resultRDD;

  // printf("Reached parallelize_");
  spark_helper_class = (*env)->FindClass(env, "Helper");
  // printf("Class found");
  spark_context_parallelize =
    (*env)->GetStaticMethodID(env, spark_helper_class, "parallelize", "(Lorg/apache/spark/api/java/JavaSparkContext;[I)Lorg/apache/spark/api/java/JavaRDD;");

  int i = 0;
  for(; i < data_length; i++)
    printf("%d\n", data[i]);

  // printf("After GetStaticMethodID");
  jintArray finalData = (*env)->NewIntArray(env, data_length);
  (*env)->SetIntArrayRegion(env, finalData, 0, data_length, data);
  printf("Right before CallStaticObjectMethod\n");
  resultRDD = (*env)->CallStaticObjectMethod(env, spark_helper_class, spark_context_parallelize, finalData);
  printf("CallStaticObjectMethod returned\n");
  return resultRDD;
}
