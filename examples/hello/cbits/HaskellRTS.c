#include <stdio.h>
#include <stdlib.h>
#include "HsFFI.h"
#include "Closure_stub.h"
#include "HelloSpark_stub.h"
#include "HaskellRTS.h"
#include "Java.h"

JNIEXPORT void JNICALL Java_HaskellRTS_hask_1init
  (JNIEnv* env, jclass c)
{
    int argc = 0;
    char *argv[] = { NULL } ; // or e.g { "+RTS", "-A1G", "-H1G", NULL };
    char **pargv = argv;

    hs_init(&argc, &pargv);
}

JNIEXPORT void JNICALL Java_HaskellRTS_sparkMain
  (JNIEnv* env, jclass c)
{
    JavaVM* jvm;
    (*env)->GetJavaVM(env, &jvm);
    // Detach thread?
    sparkMain(jvm);
}

JNIEXPORT void JNICALL Java_HaskellRTS_hask_1end
  (JNIEnv* env, jclass c)
{
    hs_exit();
}

JNIEXPORT jboolean JNICALL Java_HaskellRTS_invoke
  (JNIEnv* env, jclass haskellrts_class, jbyteArray clos, jstring arg)
{
  long len = (long) (*env)->GetArrayLength(env, clos);

  char* closBuf = (char *) malloc(len * sizeof(char));
  closBuf = (*env)->GetByteArrayElements(env, clos, NULL);

  long argLen = jstringLen(env, arg);
  char* str = jstringChars(env, arg);
  HsBool p = invokeC(closBuf, len, str, argLen);

  if(p == HS_BOOL_TRUE)
    return JNI_TRUE;
  else
    return JNI_FALSE;
}
