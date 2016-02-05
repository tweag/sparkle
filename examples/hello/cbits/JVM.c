#include "JVM.h"

JNIEnv* jniEnv()
{
  JNIEnv* env;
  int envStat = (*jvm)->GetEnv(jvm, (void**)&env, JNI_VERSION_1_6);
  if(envStat == JNI_EDETACHED)
    (*jvm)->AttachCurrentThread(jvm, (void**)& env, NULL);
  return env;
}
