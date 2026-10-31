/* Test-only interception of repository runtime calls, never CRT startup. */
#include <stdlib.h>
void* probe_malloc(size_t);
void* probe_calloc(size_t, size_t);
void* probe_realloc(void*, size_t);
#define malloc probe_malloc
#define calloc probe_calloc
#define realloc probe_realloc
