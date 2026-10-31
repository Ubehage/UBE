#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

extern size_t ube_gc_root_storage_size(void);
extern int32_t ube_gc_root_enter(void*, void**);
extern int32_t ube_gc_root_leave(void*);
extern int32_t ube_err_number(void);
extern void ube_err_set(int32_t, const char*, const char*);
extern void ube_err_clear(void);
extern bool diagnostic_try(int32_t*);
extern int32_t diagnostic_call_main(void);
extern int32_t diagnostic_entry(int32_t, void*);

int main(void) {
    int32_t failure = 0;
    ube_err_set(19, "stale error", "entry admission probe");
    assert(diagnostic_try(&failure));
    assert(failure == 9 && ube_err_number() == 19);
    assert(diagnostic_call_main() == 42);
    assert(ube_err_number() == 19);
    assert(diagnostic_entry(0, NULL) == EXPECTED_ENTRY);
    assert(ube_err_number() == 19);

    /* This is the real existing root limit, with runtime-provided root stride.
       No root-registration primitive is mocked or rewritten. */
    const size_t capacity = 1048576;
    const size_t stride = ube_gc_root_storage_size();
    assert(stride != 0 && stride <= SIZE_MAX / capacity);
    unsigned char* roots = calloc(capacity, stride);
    assert(roots != NULL);
    void* neutral = NULL;
    size_t count = 0;
    while (count < capacity) {
        assert(ube_gc_root_enter(roots + count * stride, &neutral));
        ++count;
    }
    ube_err_clear();
    failure = 41;
    assert(!diagnostic_try(&failure));
    assert(failure == 41 && ube_err_number() == 7);
    ube_err_set(19, "stale error", "entry admission probe");
    assert(diagnostic_entry(0, NULL) == 70);
    assert(ube_err_number() == 7);

    /* First local root can enter; second fails. The partially admitted first
       root must be released, and the fresh entry status must remain false. */
    --count;
    assert(ube_gc_root_leave(roots + count * stride));
    ube_err_set(19, "stale error", "entry admission probe");
    assert(diagnostic_entry(0, NULL) == 70);
    assert(ube_err_number() == 7);
    assert(ube_gc_root_enter(roots + count * stride, &neutral));
    ++count;
    while (count != 0) {
        --count;
        assert(ube_gc_root_leave(roots + count * stride));
    }
    free(roots);
    ube_err_set(19, "stale error", "entry admission probe");
    assert(diagnostic_entry(0, NULL) == EXPECTED_ENTRY);
    assert(ube_err_number() == 19);
    puts("entry admission probe passed");
    return 0;
}
