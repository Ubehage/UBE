#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef void (*ube_gc_finalizer)(void* value);

struct ube_gc_layout {
    size_t size;
    size_t slot_count;
    const size_t* slot_offsets;
    ube_gc_finalizer finalizer;
};

struct root_storage {
    void* next;
    void** slot;
    size_t slot_count;
    const size_t* slot_offsets;
};

struct node {
    struct node* next;
    int32_t value;
};

void* ube_gc_allocate(const struct ube_gc_layout* layout);
int32_t ube_gc_collect(void);
int32_t ube_gc_root_enter(void* root_storage, void** slot);
int32_t ube_gc_root_leave(void* root_storage);
int32_t ube_gc_write_barrier(void* owner, void** slot, void* value);
size_t ube_gc_root_storage_size(void);
size_t ube_gc_live_allocation_bytes(void);
int32_t ube_gc_publish(void* value);
int32_t ube_gc_pin(void* value);
int32_t ube_gc_unpin(void* value);
void ube_gc_test_fail_next_allocations(uint32_t count);
void ube_gc_test_set_threshold(size_t threshold);
void ube_gc_test_fail_next_trace_allocations(uint32_t count);
void* ube_object_allocate(const struct ube_gc_layout* layout);
uint64_t ube_object_lease_acquire(void* object);
void* ube_object_lease_resolve(uint64_t handle);
int32_t ube_object_lease_release(uint64_t handle);
int32_t ube_object_invalidate(void* object);
void* ube_variant_empty(void);
void* ube_variant_null(void);
void* ube_variant_from_long(int32_t value);
void* ube_variant_from_integer(int32_t tag, int64_t value);
void* ube_variant_from_floating(int32_t tag, double value);
void* ube_variant_copy(const void* value);
int32_t ube_variant_tag(const void* value);
int32_t ube_variant_get_long(const void* value, int32_t* result);
int32_t ube_variant_get_longlong(const void* value, int64_t* result);
int32_t ube_variant_get_boolean(const void* value, int32_t* result);
int32_t ube_variant_get_double(const void* value, double* result);
int32_t ube_fixed_string_assign(unsigned char* destination, size_t width,
                                const char* source);
int32_t ube_fixed_string_compare(const unsigned char* left,
                                 const unsigned char* right, size_t width);
int32_t ube_checked_string_to_long(const char* value, int32_t* result);
char* ube_string_concat_managed(const char* left, const char* right);

static int finalizer_calls;
static int resurrection_status = 1;
static void* resurrection_slot;

static void count_finalizer(void* value) {
    finalizer_calls += 1;
    resurrection_status = ube_gc_write_barrier(NULL, &resurrection_slot, value);
}

int main(int argc, char** argv) {
    static const size_t node_slots[] = { offsetof(struct node, next) };
    static const struct ube_gc_layout node_layout = {
        sizeof(struct node), 1, node_slots, NULL
    };
    static const struct ube_gc_layout final_layout = {
        sizeof(int32_t), 0, NULL, count_finalizer
    };
    if (argc == 2 && strcmp(argv[1], "--trace-fatal") == 0) {
        if (ube_object_allocate(&node_layout) == NULL) return 61;
        ube_gc_test_fail_next_trace_allocations(1);
        (void)ube_gc_collect();
        return 62;
    }
    if (ube_gc_root_storage_size() != sizeof(struct root_storage)) return 10;

    struct node* first = ube_gc_allocate(&node_layout);
    struct node* second = ube_gc_allocate(&node_layout);
    if (first == NULL || second == NULL) return 11;
    first->value = 41;
    second->value = 42;
    if (!ube_gc_write_barrier(first, (void**)&first->next, second)) return 12;
    if (!ube_gc_write_barrier(second, (void**)&second->next, first)) return 13;

    struct root_storage root = {0};
    if (!ube_gc_root_enter(&root, (void**)&first)) return 14;
    if (ube_gc_collect() != 0) return 15;
    if (first->next == NULL || first->next->value != 42) return 16;
    if (!ube_gc_root_leave(&root)) return 17;
    first = NULL;
    second = NULL;
    if (ube_gc_collect() != 1) return 18;
    if (ube_gc_live_allocation_bytes() != 0) return 19;

    if (ube_gc_allocate(&final_layout) == NULL) return 20;
    if (ube_gc_collect() != 1 || finalizer_calls != 1 || resurrection_status != 0 || resurrection_slot != NULL) return 21;
    if (ube_gc_collect() != 1 || finalizer_calls != 1) return 22;
    if (ube_gc_collect() != 0 || finalizer_calls != 1) return 23;
    if (ube_gc_live_allocation_bytes() != 0) return 24;

    void* leased = ube_object_allocate(&final_layout);
    if (leased == NULL) return 25;
    const uint64_t first_lease = ube_object_lease_acquire(leased);
    const uint64_t second_lease = ube_object_lease_acquire(leased);
    if (first_lease == 0 || second_lease == 0 || first_lease == second_lease) return 26;
    if (ube_object_lease_resolve(first_lease) != leased ||
        ube_object_lease_resolve(second_lease) != leased) return 27;
    if (!ube_object_lease_release(first_lease) ||
        ube_object_lease_release(first_lease) != 0) return 28;
    leased = ube_object_lease_resolve(second_lease);
    if (leased == NULL || ube_gc_collect() != 0) return 29;
    if (!ube_object_invalidate(leased)) return 30;
    if (ube_object_lease_resolve(second_lease) != NULL ||
        ube_object_lease_release(second_lease) != 0) return 31;
    leased = NULL;
    if (ube_gc_collect() != 1 || finalizer_calls != 2) return 32;
    if (ube_gc_collect() != 1 || finalizer_calls != 2) return 33;
    if (ube_gc_live_allocation_bytes() != 0) return 34;

    void* variant = ube_variant_from_long(-2147483647);
    struct root_storage variant_root = {0};
    int32_t converted = 0;
    if (variant == NULL || !ube_gc_root_enter(&variant_root, &variant)) return 35;
    if (ube_variant_tag(variant) != 2 ||
        !ube_variant_get_long(variant, &converted) || converted != -2147483647) return 36;
    void* copied_variant = ube_variant_copy(variant);
    struct root_storage copied_root = {0};
    if (copied_variant == NULL || copied_variant == variant ||
        !ube_gc_root_enter(&copied_root, &copied_variant)) return 37;
    if (ube_gc_collect() != 0 || !ube_variant_get_long(copied_variant, &converted)) return 38;
    if (!ube_gc_root_leave(&copied_root) || !ube_gc_root_leave(&variant_root)) return 39;
    copied_variant = NULL;
    variant = NULL;
    if (ube_gc_collect() != 1 || ube_gc_live_allocation_bytes() != 0) return 40;

    int64_t converted_wide = 0;
    double converted_double = 0.0;
    void* boolean_variant = ube_variant_from_integer(6, -1);
    void* byte_variant = ube_variant_from_integer(7, 255);
    void* double_variant = ube_variant_from_floating(10, 12.5);
    struct root_storage boolean_root = {0};
    struct root_storage byte_root = {0};
    struct root_storage double_root = {0};
    if (boolean_variant == NULL || byte_variant == NULL || double_variant == NULL ||
        !ube_gc_root_enter(&boolean_root, &boolean_variant) ||
        !ube_gc_root_enter(&byte_root, &byte_variant) ||
        !ube_gc_root_enter(&double_root, &double_variant)) return 52;
    if (ube_variant_tag(boolean_variant) != 6 ||
        !ube_variant_get_boolean(boolean_variant, &converted) || converted != -1 ||
        ube_variant_tag(byte_variant) != 7 ||
        !ube_variant_get_longlong(byte_variant, &converted_wide) || converted_wide != 255 ||
        ube_variant_tag(double_variant) != 10 ||
        !ube_variant_get_double(double_variant, &converted_double) ||
        converted_double != 12.5) return 53;
    if (!ube_gc_root_leave(&double_root) || !ube_gc_root_leave(&byte_root) ||
        !ube_gc_root_leave(&boolean_root)) return 54;
    boolean_variant = NULL;
    byte_variant = NULL;
    double_variant = NULL;
    if (ube_gc_collect() != 1 || ube_gc_live_allocation_bytes() != 0) return 55;

    unsigned char fixed_left[5];
    unsigned char fixed_right[5];
    if (!ube_fixed_string_assign(fixed_left, sizeof(fixed_left), "abc") ||
        !ube_fixed_string_assign(fixed_right, sizeof(fixed_right), "abcdef")) return 41;
    if (fixed_left[3] != ' ' || fixed_left[4] != ' ' || fixed_right[4] != 'e' ||
        ube_fixed_string_compare(fixed_left, fixed_left, sizeof(fixed_left)) != 0) return 42;
    if (!ube_checked_string_to_long(" -2147483648 ", &converted) || converted != INT32_MIN ||
        ube_checked_string_to_long("2147483648", &converted) != 0 ||
        ube_checked_string_to_long("12x", &converted) != 0) return 43;
    void* empty_variant = ube_variant_empty();
    void* null_variant = ube_variant_null();
    if (empty_variant == NULL || null_variant == NULL ||
        !ube_gc_publish(empty_variant) || !ube_gc_publish(null_variant)) return 44;
    empty_variant = NULL;
    null_variant = NULL;
    if (ube_gc_collect() != 1 || ube_gc_live_allocation_bytes() != 0) return 45;

    void* pinned = ube_gc_allocate(&node_layout);
    if (pinned == NULL || !ube_gc_pin(pinned) || ube_gc_collect() != 0) return 46;
    if (!ube_gc_unpin(pinned) || ube_gc_unpin(pinned) != 0) return 47;
    pinned = NULL;
    if (ube_gc_collect() != 1 || ube_gc_live_allocation_bytes() != 0) return 48;

    ube_gc_test_fail_next_allocations(1);
    void* retried = ube_gc_allocate(&node_layout);
    if (retried == NULL) return 49;
    retried = NULL;
    if (ube_gc_collect() != 1) return 50;
    ube_gc_test_fail_next_allocations(2);
    if (ube_gc_allocate(&node_layout) != NULL) return 51;
    ube_gc_test_fail_next_allocations(2);
    if (ube_string_concat_managed("managed", " failure") != NULL) return 56;

    if (ube_gc_allocate(&node_layout) == NULL) return 57;
    ube_gc_test_set_threshold(1);
    if (ube_gc_allocate(&node_layout) == NULL) return 58;
    if (ube_gc_live_allocation_bytes() != sizeof(struct node)) return 59;
    if (ube_gc_collect() != 1 || ube_gc_live_allocation_bytes() != 0) return 60;

    puts("gc probe passed");
    return 0;
}
