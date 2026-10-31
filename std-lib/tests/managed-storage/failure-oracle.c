#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>

extern void managed_initialize(void**, void**), managed_copy(void**, void**);
extern int32_t managed_grow(void**);
extern void managed_observe(void**, void**), managed_mutate(void**), managed_growth(void**);
extern void ube_err_set(int32_t, const char*, const char*);
extern int32_t ube_err_number(void), ube_gc_collect(void);
extern size_t ube_gc_root_storage_size(void), ube_gc_live_allocation_bytes(void);
extern int32_t ube_gc_root_enter(void*, void**), ube_gc_root_leave(void*);
extern void ube_gc_test_fail_next_allocations(uint32_t);

static void seed_error(void) { ube_err_set(77, "existing error", "managed UBE failure test"); }
static int check_error(int expected) {
    if (ube_err_number() != expected) { fputs("unexpected managed failure Err\n", stderr); return 0; }
    return 1;
}

int main(void) {
    void *source = NULL, *destination = NULL;
    void* source_root = calloc(1, ube_gc_root_storage_size());
    void* destination_root = calloc(1, ube_gc_root_storage_size());
    if (!source_root || !destination_root) { free(source_root); free(destination_root); return 2; }
    const size_t before = ube_gc_live_allocation_bytes();
    if (!ube_gc_root_enter(source_root, &source) || !ube_gc_root_enter(destination_root, &destination)) return 3;
    seed_error();
    managed_initialize(&source, &destination);
    if (!check_error(77)) return 4;
    ube_gc_test_fail_next_allocations(2);
    managed_copy(&source, &destination);
    if (!check_error(7)) return 5;
    puts("copy-failure err:7");
    managed_observe(&source, &destination);
    seed_error();
    ube_gc_test_fail_next_allocations(1);
    managed_copy(&source, &destination);
    if (!check_error(77)) return 6;
    puts("copy-retry err:77");
    managed_mutate(&source);
    managed_observe(&source, &destination);
    ube_gc_test_fail_next_allocations(2);
    if (managed_grow(&destination) || !check_error(7)) return 7;
    puts("grow-failure status:0 err:7");
    managed_observe(&source, &destination);
    seed_error();
    ube_gc_test_fail_next_allocations(1);
    if (!managed_grow(&destination) || !check_error(77)) return 8;
    puts("grow-retry status:1 err:77");
    managed_growth(&destination);
    if (!ube_gc_root_leave(destination_root) || !ube_gc_root_leave(source_root)) return 9;
    free(destination_root); free(source_root);
    (void)ube_gc_collect();
    if (ube_gc_live_allocation_bytes() != before) { fputs("failed value operation retained storage\n", stderr); return 10; }
    puts("dead-bytes:0");
    return 0;
}
