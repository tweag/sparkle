#include <stdio.h>
#include <stdlib.h>
#include "HsFFI.h"
// #include "Closure_stub.h"
#include "SparkLDA_stub.h"
#include "HaskellRTS.h"
#include "JVM.h"

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
	(*env)->GetJavaVM(env, &jvm);
	// Detach thread?
	sparkMain();
}

JNIEXPORT void JNICALL Java_HaskellRTS_hask_1end
  (JNIEnv* env, jclass c)
{
    hs_exit();
}

JNIEXPORT jint JNICALL Java_HaskellRTS_invoke
  (JNIEnv* env, jclass haskellrts_class, jbyteArray clos, jint arg)
{
  long len = (long) (*env)->GetArrayLength(env, clos);

  char* closBuf = (char *) malloc(len * sizeof(char));
  closBuf = (*env)->GetByteArrayElements(env, clos, NULL);

  jint res = invokeC(closBuf, len, arg);
  return res;
}
