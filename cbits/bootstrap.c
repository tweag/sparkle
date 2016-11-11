#include <HsFFI.h>
#include <setjmp.h>
#include "io_tweag_sparkle_Sparkle.h"

extern HsPtr sparkle_apply(HsPtr a1, HsPtr a2);
extern int main(int argc, char *argv[]);

static int argc = 0;
static char* argv[] = { NULL }; /* or e.g { "+RTS", "-A1G", "-H1G", NULL }; */

JNIEXPORT void JNICALL Java_io_tweag_sparkle_Sparkle_initializeHaskellRTS
  (JNIEnv * env, jclass klass)
{
	char** pargv = argv;
	hs_init(&argc, &pargv);
}

JNIEXPORT jobject JNICALL Java_io_tweag_sparkle_Sparkle_apply
  (JNIEnv * env, jclass klass, jbyteArray bytes, jobjectArray args)
{
	return sparkle_apply(bytes, args);
}

static jmp_buf bootstrap_env;

/* A global callback defined in the GHC RTS. */
extern void (*exitFn)(int);

static void bypass_exit(int rc)
{
	/* If the exit code is 0, then jump the control flow back to
	 * bootstrap(), because we don't want the RTS to call exit() -
	 * we'd like to give Spark a chance to perform whatever
	 * cleanup it needs. */
	if(!rc) longjmp(bootstrap_env, 0);
}

JNIEXPORT void JNICALL Java_io_tweag_sparkle_Sparkle_bootstrap
  (JNIEnv * env, jclass klass)
{
	exitFn = bypass_exit;
	/* Set a control prompt just before calling main. If main()
	 * calls longjmp(), then the exit code of the call to main()
	 * below must have been zero, so just return without further
	 * ceremony.
	 */
	if(setjmp(bootstrap_env)) return;
	main(argc, argv);
}
