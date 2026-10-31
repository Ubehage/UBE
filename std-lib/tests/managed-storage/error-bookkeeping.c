/* First error publication on a fresh process thread. Only the separately
   compiled runtime is remapped through allocation-probe.h; CRT startup and
   this fixture's allocator implementations continue using the real CRT. */
#include <inttypes.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern void ube_err_set(int32_t, const char*, const char*);
extern int32_t ube_err_number(void);

static int fail_calloc;
static size_t failed_callocs;

void* probe_malloc(size_t size) { return malloc(size); }
void* probe_calloc(size_t count, size_t size) {
    if (fail_calloc) {
        ++failed_callocs;
        return NULL;
    }
    return calloc(count, size);
}
void* probe_realloc(void* value, size_t size) { return realloc(value, size); }
void probe_free(void* value) { free(value); }
void probe_value_copy(size_t size) { (void)size; }

int main(int argc, char** argv) {
    const int normal = argc == 2 && strcmp(argv[1], "normal") == 0;
    if (argc > 2 || (argc == 2 && !normal)) return 2;

    /* No UBE call precedes activation. The maintained runtime must use a native
       fixed thread-local error record, without allocating the larger FLS state.
       This flag cannot affect executable/CRT startup or the diagnostic sink. */
    fail_calloc = !normal;
    ube_err_set(7, "synthetic recoverable allocation failure", "error bookkeeping probe");
    fail_calloc = 0;
    if (ube_err_number() != 7 || failed_callocs != 0) return 3;
    printf("returned Err:%" PRId32 " failed-calloc:%zu\n", ube_err_number(), failed_callocs);
    return 0;
}
