#include <stdio.h>
#include <stdlib.h>
#include "HsFFI.h"
#include "Spark_stub.h"
#include "HelloInvoke.h"

HsBool hask_init(void){
    int argc = 0;
    char *argv[] = { NULL } ; // { "+RTS", "-A1G", "-H1G", NULL };
    char **pargv = argv;

    // Initialize Haskell runtime
    hs_init(&argc, &pargv);

    // do any other initialization here and
    // return false if there was a problem
    return HS_BOOL_TRUE;
}

void hask_end(void){
    hs_exit();
}

void invokeHS
  ( char* clos, long closSize
  , char* arg, long argSize
  , char** res, long* resSize
  )
{
    hask_init();
    // call the Haskell function from Spark.hs
    invokeC(clos, closSize, arg, argSize, res, resSize);
    hask_end();
}

JNIEXPORT jbyteArray JNICALL Java_HelloInvoke_invokeHS
  ( JNIEnv* env, jobject obj
  , jbyteArray clos, jint closSize
  , jbyteArray arg, jint argSize
  )
{
    jboolean isCopyClos, isCopyArg;
    jbyte* closPtr = (*env)->GetByteArrayElements(env, clos, &isCopyClos);
    jbyte* argPtr  = (*env)->GetByteArrayElements(env, arg, &isCopyArg);

    jbyte** res = (jbyte**) malloc(sizeof(jbyte*));
    size_t* resSize = (size_t *) malloc(sizeof(size_t));

    // jbyte = char, so we can go ahead and call invokeHS
    invokeHS(closPtr, closSize, argPtr, argSize, res, resSize);

    jbyteArray retArray = (*env)->NewByteArray(env, *resSize);
    (*env)->SetByteArrayRegion(env, retArray, 0, *resSize, *res);
}
