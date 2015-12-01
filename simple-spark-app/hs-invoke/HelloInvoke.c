#include <stdio.h>
#include <stdlib.h>
#include "HsFFI.h"
#include "Spark_stub.h"
#include "HelloInvoke.h"

JNIEXPORT void JNICALL Java_HelloInvoke_hask_1init
  (JNIEnv* env, jobject obj)
{
    int argc = 0;
    char *argv[] = { NULL } ; // or e.g { "+RTS", "-A1G", "-H1G", NULL };
    char **pargv = argv;

    hs_init(&argc, &pargv);
}

JNIEXPORT void JNICALL Java_HelloInvoke_hask_1end
  (JNIEnv* env, jobject obj)
{
    hs_exit();
}

void invokeHS
  ( char* clos, long closSize
  , char* arg, long argSize
  , char** res, long* resSize
  )
{
    // call the Haskell function 'invokeC' from Spark.hs
    invokeC(clos, closSize, arg, argSize, res, resSize);
}

// TODO: add some error checks
JNIEXPORT jbyteArray JNICALL Java_HelloInvoke_invokeHS
  ( JNIEnv* env, jobject obj
  , jbyteArray clos, jint closSize
  , jbyteArray arg, jint argSize
  )
{
    jboolean isCopyClos, isCopyArg;
    jbyte* closPtr = (*env)->GetByteArrayElements(env, clos, &isCopyClos);
    jbyte* argPtr  = (*env)->GetByteArrayElements(env, arg, &isCopyArg);

    jbyte* res = NULL;
    size_t resSize;

    // jbyte = char, so we can go ahead and call invokeHS
    invokeHS(closPtr, closSize, argPtr, argSize, &res, &resSize);

    jbyteArray retArray = (*env)->NewByteArray(env, resSize);
    (*env)->SetByteArrayRegion(env, retArray, 0, resSize, res);

    return retArray;
}
