#include <HsFFI.h>
#include <pthread.h>
#include "io_tweag_sparkle_Sparkle.h"

extern HsPtr sparkle_apply(HsPtr a1, HsPtr a2);
extern int main(int argc, char *argv[]);

JavaVM *sparkle_jvm;

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
		/* Store the current JVM in a global. The current JNI spec
		 * (2016) supports only one JVM per address space anyways. */
		(*env)->GetJavaVM(env, &sparkle_jvm);
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

JNIEXPORT void JNICALL Java_io_tweag_sparkle_Sparkle_bootstrap
  (JNIEnv * env, jclass klass)
{
	int argc = 0;
	char *argv[] = { NULL };
	char **pargv = argv;

	/* Don't init RTS before calling main(), because RTS can be
	 * initialized only once. */
	sparkle_init(env, 0);
	main(argc, pargv);
}
