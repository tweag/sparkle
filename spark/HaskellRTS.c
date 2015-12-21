#include <stdio.h>
#include <stdlib.h>
#include "HsFFI.h"
#include "Spark_stub.h"
#include "HaskellRTS.h"

JavaVM* jvm;

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
	sparkMain();
}

JNIEXPORT void JNICALL Java_HaskellRTS_hask_1end
  (JNIEnv* env, jclass c)
{
    hs_exit();
}
