#include <HsFFI.h>
#include <pthread.h>
#include <setjmp.h>
#include "io_tweag_sparkle_Sparkle.h"

extern HsPtr sparkle_apply(HsPtr a1, HsPtr a2);
extern int main(int argc, char *argv[]);

pthread_spinlock_t sparkle_init_lock;
static int sparkle_initialized;

__attribute__((constructor)) void sparkle_init_lock_constructor()
{
	pthread_spin_init(&sparkle_init_lock, 0);
}

/* Ensure that global variables are initialized. */
static void sparkle_init(JNIEnv *env, int init_rts)
{
	int argc = 0;
	char *argv[] = { NULL }; /* or e.g { "+RTS", "-A1G", "-H1G", NULL }; */
	char **pargv = argv;

	pthread_spin_lock(&sparkle_init_lock);
	if(!sparkle_initialized) {
		if(init_rts)
			hs_init(&argc, &pargv);
		sparkle_initialized = 1;
	}
	pthread_spin_unlock(&sparkle_init_lock);
}

JNIEXPORT jobject JNICALL Java_io_tweag_sparkle_Sparkle_apply
  (JNIEnv * env, jclass klass, jbyteArray bytes, jobjectArray args)
{
	sparkle_init(env, 1);
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
	int argc = 0;
	char *argv[] = { NULL };
	char **pargv = argv;

	/* Don't init RTS before calling main(), because RTS can be
	 * initialized only once. */
	sparkle_init(env, 0);

	exitFn = bypass_exit;
	/* Set a control prompt just before calling main. If main()
	 * calls longjmp(), then the exit code of the call to main()
	 * below must have been zero, so just return without further
	 * ceremony.
	 */
	if(setjmp(bootstrap_env)) return;
	main(argc, pargv);
}
