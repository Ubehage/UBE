#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

struct owned_result { void* data; int32_t marker; };
extern void managed_initialize_input(void**), managed_mutate_input(void**);
extern int32_t managed_inspect_copy(void**), managed_first_byte(void**);
extern void managed_array_result(void**, void**), managed_record_result(struct owned_result*, struct owned_result*);
extern void managed_initialize_record(struct owned_result*);
extern uint64_t managed_result_size(void), managed_result_alignment(void);
extern void ube_err_set(int32_t, const char*, const char*);
extern int32_t ube_err_number(void), ube_gc_collect(void);
extern size_t ube_gc_root_storage_size(void), ube_gc_live_allocation_bytes(void);
extern int32_t ube_gc_root_enter(void*, void**), ube_gc_root_leave(void*);
extern void ube_gc_test_fail_next_allocations(uint32_t);

static void seed_error(void) { ube_err_set(77, "existing error", "managed initialization test"); }
static int no_new_payload(size_t baseline) {
    (void)ube_gc_collect();
    return ube_gc_live_allocation_bytes() == baseline;
}

int main(void) {
    void* source = NULL;
    void* array = NULL;
    struct owned_result record = {NULL, 0};
    struct owned_result record_source = {NULL, 0};
    void* roots[4] = {NULL, NULL, NULL, NULL};
    void** slots[4] = {&source, &array, &record.data, &record_source.data};
    if (managed_result_size() != sizeof(record) || managed_result_alignment() != _Alignof(struct owned_result)) return 2;
    const size_t initial = ube_gc_live_allocation_bytes();
    for (int index = 0; index < 4; ++index) {
        roots[index] = calloc(1, ube_gc_root_storage_size());
        if (!roots[index] || !ube_gc_root_enter(roots[index], slots[index])) return 3;
    }
    seed_error();
    managed_initialize_input(&source);
    managed_initialize_record(&record_source);
    if (!source || ube_err_number() != 77) return 4;
    if (!record_source.data || record_source.marker != 123 || managed_first_byte(&record_source.data) != 65) return 4;
    (void)ube_gc_collect();
    size_t baseline = ube_gc_live_allocation_bytes();
    ube_gc_test_fail_next_allocations(2);
    if (managed_inspect_copy(&source) != 0 || ube_err_number() != 7 ||
        managed_first_byte(&source) != 65 || !no_new_payload(baseline)) return 5;
    puts("byval-failure result:0 source:65 err:7 unpublished-bytes:0");
    seed_error();
    ube_gc_test_fail_next_allocations(1);
    if (managed_inspect_copy(&source) != 123 || ube_err_number() != 77 ||
        managed_first_byte(&source) != 65 || !no_new_payload(baseline)) return 6;
    puts("byval-retry result:123 source:65 err:77 dead-copy-bytes:0");
    ube_gc_test_fail_next_allocations(2);
    managed_array_result(&source, &array);
    if (array != NULL || ube_err_number() != 7 || managed_first_byte(&source) != 65 ||
        !no_new_payload(baseline)) return 7;
    puts("array-result-failure empty:1 source:65 err:7 unpublished-bytes:0");
    seed_error();
    ube_gc_test_fail_next_allocations(1);
    managed_array_result(&source, &array);
    if (!array || array == source || ube_err_number() != 77) return 8;
    managed_mutate_input(&source);
    if (managed_first_byte(&source) != 66 || managed_first_byte(&array) != 65) return 9;
    puts("array-result-retry source:66 result:65 err:77");
    (void)ube_gc_collect();
    baseline = ube_gc_live_allocation_bytes();
    ube_gc_test_fail_next_allocations(2);
    managed_record_result(&record_source, &record);
    if (record.data != NULL || record.marker != 0 || ube_err_number() != 7 ||
        record_source.marker != 123 || managed_first_byte(&record_source.data) != 65 || !no_new_payload(baseline)) {
        fprintf(stderr, "failed record result published-data:%d marker:%d err:%d source:%d live:%llu baseline:%llu\n",
            record.data != NULL, record.marker, ube_err_number(), managed_first_byte(&record_source.data),
            (unsigned long long)ube_gc_live_allocation_bytes(), (unsigned long long)baseline);
        return 10;
    }
    puts("record-result-failure empty:1 marker:0 source:65 err:7 unpublished-bytes:0");
    seed_error();
    ube_gc_test_fail_next_allocations(1);
    managed_record_result(&record_source, &record);
    if (!record.data || record.data == record_source.data || record.marker != 123 ||
        managed_first_byte(&record.data) != 65 || ube_err_number() != 77) return 11;
    puts("record-result-retry first:65 marker:123 err:77");
    for (int index = 3; index >= 0; --index) {
        if (!ube_gc_root_leave(roots[index])) return 12;
        free(roots[index]);
    }
    if (!no_new_payload(initial)) return 13;
    puts("dead-bytes:0");
    return 0;
}
