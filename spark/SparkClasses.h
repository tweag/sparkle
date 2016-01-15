#include <jni.h>

jobject newSparkContext(jobject sparkConf);
jobject newSparkConf(const char* appname);
jobject parallelize(jobject sparkContext, jint* data, size_t data_length);
void    collect(jobject rdd, int** buf, size_t* len);
