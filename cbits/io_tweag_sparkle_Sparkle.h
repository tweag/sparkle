#ifndef _Included_io_tweag_sparkle_Sparkle
#define _Included_io_tweag_sparkle_Sparkle

/* C/C++ header file for Java class io_tweag_sparkle_Sparkle */

#include <jni.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Class:     io_tweag_sparkle_Sparkle
 * Method:    initializeHaskellRTS
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_io_tweag_sparkle_Sparkle_initializeHaskellRTS
  (JNIEnv *, jclass);

/*
 * Class:     io_tweag_sparkle_Sparkle
 * Method:    apply
 * Signature: ([B[Ljava/lang/Object;)Ljava/lang/Object;
 */
JNIEXPORT jobject JNICALL Java_io_tweag_sparkle_Sparkle_apply
  (JNIEnv *, jclass, jbyteArray, jobjectArray);

#ifdef __cplusplus
}
#endif
#endif
