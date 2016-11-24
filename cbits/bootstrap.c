#include <HsFFI.h>
#include <setjmp.h>
#include "io_tweag_sparkle_Sparkle.h"

extern HsPtr sparkle_apply(HsPtr a1, HsPtr a2);

// main is provided when linking an executable. But sparkle is sometimes
// loaded dynamically when no main symbol is provided. Typically, ghc
// could load it when building code which uses ANN pragmas or template
// haskell.
//
// Because of this we make main a weak symbol. The man page of nm [1]
// says:
//
//   When a weak undefined symbol is linked and the symbol is not
//   defined, the value of the symbol is determined in a system-specific
//   manner without error.
//
// [1] https://linux.die.net/man/1/nm
// [2] https://gcc.gnu.org/onlinedocs/gcc/Common-Function-Attributes.html#index-g_t_0040code_007bweak_007d-function-attribute-3369
extern int main(int argc, char *argv[]) __attribute__((weak));

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
