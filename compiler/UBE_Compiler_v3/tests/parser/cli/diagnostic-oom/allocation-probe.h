/* Redirect only production-runtime allocator calls, leaving the driver intact. */
#include <stdlib.h>
void* diagnostic_malloc(size_t);
void* diagnostic_calloc(size_t,size_t);
void* diagnostic_realloc(void*,size_t);
void diagnostic_free(void*);
#define malloc diagnostic_malloc
#define calloc diagnostic_calloc
#define realloc diagnostic_realloc
#define free diagnostic_free
