#include <jni.h>

/* JVM */
JNIEnv* jniEnv(JavaVM* jvm);

/* Finding classes and methods */
jclass findClass(JNIEnv* e, const char* java_class);
jmethodID findMethod(JNIEnv* e, jclass java_class, const char* method_name, const char* sig);
jmethodID findStaticMethod(JNIEnv* e, jclass java_class, const char* method_name, const char* sig);

/* invoking methods */
jobject callObjectMethod(JNIEnv* e, jobject obj, jmethodID, jvalue* args);
void callVoidMethod(JNIEnv* e, jobject obj, jmethodID, jvalue* args);
jobject callStaticObjectMethod(JNIEnv* e, jclass java_class, jmethodID method, jvalue* args);
void callStaticVoidMethod (JNIEnv* e, jclass java_class, jmethodID method, jvalue* args);
long callLongMethod (JNIEnv* e, jobject obj, jmethodID method, jvalue* args);

/* Creating Java values */
jobject newObject(JNIEnv* e, jclass java_class, const char* sig, const jvalue* args);
jstring newString(JNIEnv* e, const char* str);
jintArray newIntArray(JNIEnv* e, size_t size, int* data);
jbyteArray newByteArray(JNIEnv* e, size_t size, jbyte* data);

/* Converting Java values to Haskell ones */
size_t jstringLen(JNIEnv* e, jstring s);
const char* jstringChars(JNIEnv* e, jstring s);

void checkForExc(JNIEnv* e);
