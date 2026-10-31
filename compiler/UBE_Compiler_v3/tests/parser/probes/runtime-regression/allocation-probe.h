#include <stdlib.h>
void* runtime_regression_malloc(size_t);
void* runtime_regression_calloc(size_t,size_t);
void* runtime_regression_realloc(void*,size_t);
void runtime_regression_free(void*);
#define malloc runtime_regression_malloc
#define calloc runtime_regression_calloc
#define realloc runtime_regression_realloc
#define free runtime_regression_free
