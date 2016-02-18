#include <HsFFI.h>
#include "io_tweag_sparkle_Sparkle.h"

JNIEXPORT void JNICALL Java_io_tweag_sparkle_Sparkle_initializeHaskellRTS
  (JNIEnv * env, jclass klass)
{
	int argc = 0;
	char *argv[] = { NULL } ; // or e.g { "+RTS", "-A1G", "-H1G", NULL };
	char **pargv = argv;

	hs_init(&argc, &pargv);
}

JNIEXPORT void JNICALL Java_io_tweag_sparkle_Sparkle_finalizeHaskellRTS
  (JNIEnv * env, jclass klass)
{
	hs_exit();
}
