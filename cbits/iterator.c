#include <HsFFI.h>
#include <jni.h>

#ifdef __cplusplus
extern "C" {
#endif

extern HsPtr sparkle_iterator_next(HsInt64 fun, HsPtr this);

JNIEXPORT jobject JNICALL Java_io_tweag_sparkle_HaskellIterator_iteratorNext
  (JNIEnv * env, jobject this, jlong fun)
{
    return sparkle_iterator_next(fun, this);
}

JNIEXPORT void JNICALL Java_io_tweag_sparkle_HaskellIterator_freeStablePtr
  (JNIEnv * env, jclass klass, jlong fun)
{
    hs_free_stable_ptr((HsStablePtr)fun);
}

#ifdef __cplusplus
}
#endif
