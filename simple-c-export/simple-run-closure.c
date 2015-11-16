#include <stdio.h>
#include <stdlib.h>
#include "HsFFI.h"
#include "Spark_stub.h"

HsBool hask_init(void){
    int argc = 0;
    char *argv[] = { NULL } ; // { "+RTS", "-A1G", "-H1G", NULL };
    char **pargv = argv;

    // Initialize Haskell runtime
    hs_init(&argc, &pargv);

    // do any other initialization here and
    // return false if there was a problem
    return HS_BOOL_TRUE;
}

void hask_end(void){
    hs_exit();
}

char* read_from_file(const char *filename, long* szOut)
{
    long size = 0;
    FILE *file = fopen(filename, "r");

    if(!file) {
        fputs("File error.\n", stderr);
        return NULL;
    }

    fseek(file, 0, SEEK_END);
    size = ftell(file);
    rewind(file);

    char *result = (char *) malloc(size);
    if(!result) {
        fputs("Memory error.\n", stderr);
        return NULL;
    }

    if(fread(result, 1, size, file) != size) {
        fputs("Read error.\n", stderr);
        return NULL;
    }

    fclose(file);
    *szOut = size;
    return result;
}

int main(int argc, char** argv)
{
    if(argc < 2) {
        fputs("Need 2 arguments.\n", stderr);
        return -1;
    }

    long* closSize = (long *) malloc(sizeof(long));
    long* argSize  = (long *) malloc(sizeof(long));

    char* clos = read_from_file(argv[1], closSize);
    char* arg  = read_from_file(argv[2], argSize);
    if(!clos || !arg) return -1;

    char* res;
    size_t* resSize;

    /* DEBUGGING
    printf("Closure size: %ld\n", *closSize);
    printf("Argument size: %ld\n", *argSize);
    fflush(stdout);
    */

    hask_init();
    invokeC(clos, *closSize, arg, *argSize, res, resSize);
    fputs(res, stdout);
    hask_end();

    free(clos); free(closSize);
    free(arg); free(argSize);
    free(res); free(resSize);

    return 0;
}
           
