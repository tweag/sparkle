#include <stdio.h>
#include <stdlib.h>
#include "HsFFI.h"
#include "Spark_stub.h"
#include "HelloInvoke.h"

HsBool hask_init() __attribute__((constructor));
void   hask_end()  __attribute__((destructor));

HsBool hask_init()
{
    int argc = 0;
    char *argv[] = { NULL } ; // { "+RTS", "-A1G", "-H1G", NULL };
    char **pargv = argv;

    // Initialize Haskell runtime
    hs_init(&argc, &pargv);

    return HS_BOOL_TRUE;
}

void hask_end()
{
    hs_exit();
}

void invokeHS
  ( char* clos, long closSize
  , char* arg, long argSize
  , char** res, long* resSize
  )
{
    /* No need for hask_init()/hask_end(), as they're performed whenever
       the library is loaded.
    */

    // call the Haskell function from Spark.hs
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
