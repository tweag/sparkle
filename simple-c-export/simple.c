#include <stdio.h>
#include <stdlib.h>
#include "HsFFI.h"
#include "Spark_stub.h"

HsBool hask_init(void){
    int argc = 0;
    char *argv[] = { NULL }; // { "+RTS", "-A32m", NULL };
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

char* read_from_file(const char *filename)
{
    long int size = 0;
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
    return result;
}

int main(int argc, char** argv)
{
    if(argc < 2) {
        fputs("Need 2 arguments.\n", stderr);
        return -1;
    }

    char* clos = read_from_file(argv[1]);
    char* arg  = read_from_file(argv[2]);
    if(!clos || !arg) return -1;

    char* res;

    hask_init();
    res = invokeC(clos, arg);
    fputs(res, stdout);
    hask_end();

    free(clos); free(arg); free(res);

    return 0;
}
           
