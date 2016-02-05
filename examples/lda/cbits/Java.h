#include <jni.h>

/* Finding classes and methods */
jclass findClass(const char* java_class);
jmethodID findMethod(jclass java_class, const char* method_name, const char* sig);
jmethodID findStaticMethod(jclass java_class, const char* method_name, const char* sig);

/* invoking methods */
jobject callObjectMethod(jobject obj, jmethodID, jvalue* args);
void callVoidMethod(jobject obj, jmethodID, jvalue* args);
jobject callStaticObjectMethod(jclass java_class, jmethodID method, jvalue* args);
void callStaticVoidMethod (jclass java_class, jmethodID method, jvalue* args);

/* Creating Java values */
jobject newObject(jclass java_class, const char* sig, const jvalue* args);
jstring newString(const char* str);
jintArray newIntArray(size_t size, int* data);
jbyteArray newByteArray(size_t size, jbyte* data);

void checkForExc();

/* Spark functions */
// TODO: get rid of this
void      collect(jobject rdd, int** buf, size_t* len);
