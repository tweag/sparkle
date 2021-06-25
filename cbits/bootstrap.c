#include <HsFFI.h>
#include <setjmp.h>
#include "io_tweag_sparkle_Sparkle.h"
#include <stdlib.h>  // For malloc, free
#include <string.h>  // For memcpy
#include "Rts.h"

extern HsPtr sparkle_apply(HsPtr a1, HsPtr a2);
extern void sparkle_hs_init();
extern void sparkle_hs_fini();

extern int ioTweagSparkleMain();

// Enumeration describing the status of the GHC RTS in the current process.
typedef enum
  { RTS_DOWN		/* GHC's RTS has not been initialized yet */
  , RTS_UP_DRIVER	/* GHC's RTS has been initialized through invokeMain
					 * and we therefore are running in a spark driver process
					 */
  , RTS_UP_EXECUTOR /* GHC's RTS has been initialized through initializeHaskellRTS
					 * and we therefore are running in a spark executor process
					 */
  } rts_status_t;

// The RTS is down initially but can be brought up by invokeMain
// or initializeHaskellRTS.
static rts_status_t rts_status = RTS_DOWN;

// Converts an array of strings (java.lang.String[]) to a buffer
// of null-terminated C strings.
//
// Returns the length of the array or -1 if there are failures.
jsize c_strings_of_string_array(JNIEnv* env, jobjectArray stringArr, char** cstrings[])
{
	int success = 1;
	jsize numStrs = 0;

	// Obtain jargc, the number of argument strings, from `jstringArr`.
	const jsize jargc = (*env)->GetArrayLength(env, stringArr);
	if ((*env)->ExceptionOccurred(env)) {
		return -1;
	}

	// Allocate enough room for C representation of the Java strings
	// to be stored in our own array.
	*cstrings = malloc(jargc * sizeof(char*));
	if (!(*cstrings)) {
		return -1;
	}

	for (jsize i = 0; i < jargc; i++) {
		// Obtain a representation of the Java string in the array.
		jstring jstr = (*env)->GetObjectArrayElement(env, stringArr, i);
		if ((*env)->ExceptionOccurred(env) || !jstr) {
			success = 0;
			break;
		}

		// Obtain a C-string representation of the Java string.
		const char* str = (*env)->GetStringUTFChars(env, jstr, 0);
		if ((*env)->ExceptionOccurred(env) || !str) {
			success = 0;
			break;
		}
		// Allocate our own space for the string, and copy it.
		const jsize strLen = (*env)->GetStringUTFLength(env, jstr);
		char * myStr = malloc(strLen + 1);
		if (!myStr) {
			success = 0;
			break;
		}
		numStrs++;
		memcpy(myStr, str, strLen);
		myStr[strLen] = 0;

		// Deallocate the JNI's C-string representation.
		(*env)->ReleaseStringUTFChars(env, jstr, str);
		if ((*env)->ExceptionOccurred(env)) {
			success = 0;
			break;
		}

		// Deallocate the now unused local reference, `jstr`.
		(*env)->DeleteLocalRef(env, jstr);
		if ((*env)->ExceptionOccurred(env)) {
			success = 0;
			break;
		}

		(*cstrings)[i] = myStr;
	}

	if (!success) {
		while (numStrs > 0) {
			// Free resources allocated above: new_argv entries with index in
			// range 1..numStrs.
			free((*cstrings)[1 + numStrs--]);
		}
		return -1;
	}

	return jargc;
}

// This functions puts prog_name and all the strings from cargs in a single
// NULL-terminated buffer of C strings ready to be passed to hs_init_with_rtsopts.
//
// Returns the length of the buffer without including the terminating NULL, or
// -1 if there is a failure.
jsize prepare_hs_args
	( JNIEnv* env, char* prog_name, char** hs_argv[], jsize cargs_sz, char* cargs[])
{
	// We need room for the program name and the terminating NULL
	*hs_argv = malloc((cargs_sz + 2) * sizeof(char*));
	if(!(*hs_argv)) {
			return -1;
	}

	// Start with the program name.
	(*hs_argv)[0] = prog_name;

	// Then copy the content of cargs
	memcpy(*hs_argv + 1, cargs, cargs_sz * sizeof(char*));

	// `argv` always has a NULL pointer in its argc-th position. We allocated
	// enough positions in hs_argv for this, in the malloc(), above.
	(*hs_argv)[cargs_sz+1] = NULL;

	return cargs_sz+1;
}

// Initialize the RTS on the executors
//
// This function is a no-op when executed on the drivers, as invokeMain will set
// rts_status to RTS_UP_DRIVER before this functions is executed. See the
// comments in Sparkle.java.
//
// Termination of the RTS for the executors is currently an open problem, there
// is therefore no matching 'hs_exit' call for the
// hs_init_with_rtsopts performed below at the moment.
JNIEXPORT void JNICALL Java_io_tweag_sparkle_Sparkle_initializeHaskellRTS
  (JNIEnv * env, jclass klass, jobjectArray jargs)
{
	if(rts_status == RTS_DOWN) {

		char** cargs;
		jsize jargc = c_strings_of_string_array(env, jargs, &cargs);
		if(jargc < 0)
			return;

		char** hs_argv;
		jsize hs_argc = prepare_hs_args(env, "sparkle-worker", &hs_argv, jargc, cargs);
		if(hs_argc < 0)
			goto cleanup_initializeHaskellRTS;

		hs_init(&hs_argc, &hs_argv);
		if (!rtsSupportsBoundThreads())
			(*env)->FatalError(env,"Sparkle.initializeHaskellRTS: Haskell RTS is not threaded.");

		if ((*env)->ExceptionOccurred(env))
			return;

		rts_status = RTS_UP_EXECUTOR;

		// Deallocate resources from above.
		free(hs_argv);
cleanup_initializeHaskellRTS:
		for (jsize i = 0; i < jargc; i++)
			free(cargs[i]);
		free(cargs);
	}
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
	 * invokeMain(), because we don't want the RTS to call exit() -
	 * we'd like to give Spark a chance to perform whatever
	 * cleanup it needs. */
	if(!rc) longjmp(bootstrap_env, 0);
}

int do_main (JNIEnv * env, int argc, char *argv[] )
{
	hs_init_with_rtsopts(&argc, &argv);
	rts_status = RTS_UP_DRIVER;

	sparkle_hs_init();
	if ((*env)->ExceptionOccurred(env))
		return -1;

    ioTweagSparkleMain();

	sparkle_hs_fini();

	// Shutdown the RTS but do not terminate the process
	hs_exit();

	return 0;
}

JNIEXPORT void JNICALL Java_io_tweag_sparkle_SparkMain_invokeMain
(JNIEnv * env, jclass klass, jobjectArray jargs)
{

	// We should never run this function with a GHC RTS already up and running.
	// This should never happen, so let's error out loudly if that's ever the case.
	if (rts_status != RTS_DOWN)
		(*env)->FatalError(env,"SparkMain.invokeMain: Haskell RTS is already initialized.");

	/* Set a control prompt just before calling main. If main()
	 * calls longjmp(), then the exit code of the call to main()
	 * below must have been zero, so just return without further
	 * ceremony.
	 */
	exitFn = bypass_exit;
	if(setjmp(bootstrap_env)) return;

	char** cargs;
	jsize jargc = c_strings_of_string_array(env, jargs, &cargs);
	if(jargc < 0)
		return;

	char** hs_argv;
	jsize hs_argc = prepare_hs_args(env, "sparkle-worker", &hs_argv, jargc, cargs);
	if(hs_argc < 0)
		goto cleanup_cargs;

	rts_status = RTS_UP_DRIVER;

	// Call the Haskell main() function.
	do_main(env, hs_argc, hs_argv);

	// Deallocate resources from above.
	free(hs_argv);
cleanup_cargs:
	for (jsize i = 0; i < jargc; i++)
		free(cargs[i]);
	free(cargs);
}
