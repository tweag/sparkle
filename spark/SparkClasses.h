#include <jni.h>

jobject newSparkContext(jobject sparkConf);
jobject newSparkConf(const char* appname);
jobject parallelize(jobject sparkContext, int* data, size_t data_length);
