#include <HsFFI.h>
#include <setjmp.h>
#include "io_tweag_sparkle_Sparkle.h"
#include <stdlib.h>  // For malloc, free
#include <string.h>  // For memcpy

#ifdef __cplusplus
extern "C" {
#endif

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

static int sparkle_argc = 1;
static char** sparkle_argv = (char*[]){ "sparkle-worker", NULL };
// static int sparkle_argc = 4;
// static char* sparkle_argv[] =
//     (char*[]){ "sparkle-dummy", "+RTS", "-A1G", "-H1G", NULL };

JNIEXPORT void JNICALL Java_io_tweag_sparkle_Sparkle_initializeHaskellRTS
  (JNIEnv * env, jclass klass)
{
	// TODO: accept values for argc, argv via Java properties.
	hs_init(&sparkle_argc, &sparkle_argv);
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

JNIEXPORT void JNICALL Java_io_tweag_sparkle_SparkMain_invokeMain
(JNIEnv * env, jclass klass, jobjectArray stringArr)
{
	/* Set a control prompt just before calling main. If main()
	 * calls longjmp(), then the exit code of the call to main()
	 * below must have been zero, so just return without further
	 * ceremony.
	 */
	exitFn = bypass_exit;
	if(setjmp(bootstrap_env)) return;

	// Obtain jargc, the number of argument strings, from `stringArr`.
	const jsize jargc = (*env)->GetArrayLength(env, stringArr);
	if ((*env)->ExceptionOccurred(env)) {
		return;
	}

	// Allocate memory for `argv`. It requires (jargc + sparkle_argc + 1)
	// pointers in it. The '+ 1' is for the extra NULL pointer that is
	// required by `argv` arrays.
	char** new_argv = malloc((jargc + sparkle_argc + 1) * sizeof(char*));
	if (!new_argv) {
		return;
	}

	// Retain the 0th value (program name) from the existing argv.
	new_argv[0] = sparkle_argv[0];

	int success = 1;
	jsize numStrs = 0;
	for (jsize i = 1; i <= jargc; i++) {

		// Obtain a representation of the Java string in the array.
		jstring jstr = (*env)->GetObjectArrayElement(env, stringArr, i - 1);
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

		new_argv[i] = myStr;
	}

	if (!success) {
		while (numStrs > 0) {
			// Free resources allocated above: new_argv entries with index in
			// range 1..numStrs.
			free(new_argv[1 + numStrs--]);
		}
		free(new_argv);
		return;
	}

	// Put the remaining sparkle_argv elements into new_argv.
	for (jsize i = 1; i < sparkle_argc; i++) {
		new_argv[jargc + i] = sparkle_argv[i];
	}

	// Make sure that Haskell code finds these new values for argc, argv.
	sparkle_argc += jargc;
	sparkle_argv = new_argv;

	// `argv` always has a NULL pointer in its argc-th position. We allocated
	// enough positions in new_argv for this, in the malloc(), above.
	new_argv[sparkle_argc] = NULL;

	// Call the Haskell main() function.
	main(sparkle_argc, sparkle_argv);

	// Deallocate resources from above.
	for (jsize i = 1; i <= jargc; i++) {
		free(new_argv[i]);
	}
	free(new_argv);
}

#ifdef __cplusplus
}
#endif
