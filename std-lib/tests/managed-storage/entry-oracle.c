/* Test-only adapter. The complete UBE entry/procedure bodies remain unchanged. */
#include <stdint.h>
#include <stdio.h>
#include <stddef.h>

extern int32_t managed_value_entry(int32_t, char**);
extern void ube_err_set(int32_t, const char*, const char*);
extern int32_t ube_err_number(void), ube_gc_collect(void);
extern size_t ube_gc_live_allocation_bytes(void);
#ifdef CHECK_LAYOUT
extern uint64_t managed_value_size(void), managed_value_alignment(void);
#endif

int main(int argc, char** argv) {
    (void)ube_gc_collect();
    const size_t before = ube_gc_live_allocation_bytes();
    ube_err_set(77, "existing error", "managed UBE test");
#ifdef CHECK_LAYOUT
    if (managed_value_size() != EXPECTED_SIZE ||
        managed_value_alignment() != EXPECTED_ALIGNMENT) {
        fputs("managed layout differs\n", stderr); return 2;
    }
    printf("layout:%llu:%llu\n", (unsigned long long)managed_value_size(),
        (unsigned long long)managed_value_alignment());
#endif
    const int32_t result = managed_value_entry(argc, argv);
    if (result != 0) return result;
    if (ube_err_number() != 77) { fputs("managed UBE changed stale Err\n", stderr); return 3; }
    (void)ube_gc_collect();
    if (ube_gc_live_allocation_bytes() != before) {
        fputs("managed UBE retained dead storage\n", stderr); return 4;
    }
    puts("err:77 dead-bytes:0");
    return 0;
}
