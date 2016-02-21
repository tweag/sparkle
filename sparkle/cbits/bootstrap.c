#include <HsFFI.h>
#include "io_tweag_sparkle_Sparkle.h"

JavaVM *sparkle_jvm;

JNIEXPORT void JNICALL Java_io_tweag_sparkle_Sparkle_bootstrap
  (JNIEnv * env, jclass klass)
{
	int argc = 0;
	char *argv[] = { NULL } ; /* or e.g { "+RTS", "-A1G", "-H1G", NULL }; */
	char **pargv = argv;

	/* Store the current JVM in a global. The current JNI spec
	 * (2016) supports only one JVM per address space anyways. */
	(*env)->GetJavaVM(env, &sparkle_jvm);
	main(argc, &pargv);
}
