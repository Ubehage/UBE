/* Test-only allocation observation/failure injection in repository runtime. */
#include <stdlib.h>
void* probe_malloc(size_t);
void* probe_calloc(size_t, size_t);
void* probe_realloc(void*, size_t);
void probe_free(void*);
#define malloc probe_malloc
#define calloc probe_calloc
#define realloc probe_realloc
#define free probe_free
