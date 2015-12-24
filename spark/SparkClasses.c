#include <jni.h>
#include <stdio.h>
#include "HaskellRTS.h"
#include "SparkClasses.h"

jobject newSparkConf_(JNIEnv* env, const char* appname);
jobject newSparkContext_(JNIEnv* env, jobject sparkConf);

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

// data JObject_
// type JObject = Ptr JObject_

// newtype JObject = JObject (Ptr JObject)ǧ
