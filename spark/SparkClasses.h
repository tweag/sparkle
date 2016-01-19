#include <jni.h>

JNIEnv* jniEnv();

jclass  findClass(const char* java_class);
jobject newObject(const char* java_class, const char* sig, const jvalue* args);
jstring newString(const char* str);

jobject newSparkContext(jobject sparkConf);
jobject newSparkConf(const char* appname);
jobject parallelize(jobject sparkContext, jint* data, size_t data_length);
void    collect(jobject rdd, int** buf, size_t* len);
jobject rddmap(jobject rdd, char* clos, long closSize);
