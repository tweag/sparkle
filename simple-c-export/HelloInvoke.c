 #include <stdio.h>
 #include "HelloInvoke.h"

 JNIEXPORT void JNICALL
 Java_HelloInvoke_invokeC(JNIEnv *env, jobject obj)
 {
     printf("Hello!\n");
     return;
 }
