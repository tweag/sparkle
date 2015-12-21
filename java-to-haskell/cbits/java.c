#include <stdio.h>
#include <jni.h>

JNIEnv* create_vm(JavaVM **jvm)
{
  JNIEnv* env;
  JavaVMInitArgs args;
  JavaVMOption options;
  args.version = JNI_VERSION_1_6;
  args.nOptions = 1;
  options.optionString = "-Djava.class.path=./";
  args.options = &options;
  args.ignoreUnrecognized = 0;

  int rv;
  rv = JNI_CreateJavaVM(jvm, (void**)&env, &args);

  if (rv < 0 || !env)
    printf("Unable to Launch JVM %d\n",rv);
  else
    printf("JVM launched\n");

  return env;
  }

void invoke_class(JNIEnv* env)
{
    jclass hello_class;
    jmethodID f_method;
    hello_class = (*env)->FindClass(env, "Hello");
    f_method = (*env)->GetStaticMethodID(env, hello_class, "f", "()V");
    (*env)->CallStaticVoidMethod(env, hello_class, f_method, NULL);
}

int run()
{
    JavaVM *jvm;
    JNIEnv *env;
    env = create_vm(&jvm);
    if(env == NULL)
    {
      return 1;
    }
    invoke_class(env);
    return 0;
}
