#include <stdio.h>
#include <stdlib.h>
#include "HsFFI.h"
#include "Closure_stub.h"
#include "SparkLDA_stub.h"
#include "HaskellRTS.h"

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
	JavaVM *jvm;
	(*env)->GetJavaVM(env, &jvm);
	// Detach thread?
	sparkMain(jvm);
}

JNIEXPORT void JNICALL Java_HaskellRTS_hask_1end
  (JNIEnv* env, jclass c)
{
    hs_exit();
}
