/* Independent assertions around intact compiled UBE reference procedures. */
#include "../../../../runtime/bootstrap_runtime.c"

extern void probe_create(void** output);
extern void probe_allocate(void** output);
extern int32_t probe_read_count(void* owner);
extern const struct ube_value_layout* probe_reference_layout(void);

static int check(int condition, const char* label) {
    if (condition) return 1;
    fprintf(stderr, "FAIL reference observer: %s\n", label);
    return 0;
}

/* Fill real root registrations and release them through the actual runtime. */
int main(void) {
    const struct ube_value_layout* layout = probe_reference_layout();
    void* owner = NULL;
    struct ube_gc_root owner_root = {0};
    if (!check(layout->size == 8 && layout->kind == 3 && layout->root_count == 1,
               "shared-reference ABI") ||
        !check(ube_value_root_enter(&owner_root, &owner, layout), "caller root")) return 1;
    ube_err_set(77, "seed", "observer");
    probe_create(&owner);
    if (!check(owner != NULL && probe_read_count(owner) == 53, "actual UBE create/read") ||
        !check(ube_err_number() == 77, "success preserves Err")) return 1;
    (void)ube_gc_collect();
    if (!check(probe_read_count(owner) == 53, "caller retains result across collection")) return 1;
    void* original = owner;

    ube_gc_test_fail_next_allocations(UINT32_MAX);
    probe_allocate(&owner);
    if (!check(owner == NULL && ube_err_number() == 7, "persistent allocation denial returns Nothing/Err7")) return 1;
    ube_gc_test_fail_next_allocations(0);
    (void)ube_gc_collect();
    if (!check(ube_gc_live_allocation_bytes() == 0, "old identity collected after neutral replacement")) return 1;

    ube_err_set(77, "seed", "observer");
    if (!check(probe_read_count(NULL) == 0 && ube_err_number() == 91,
               "neutral access returns controlled value and fresh error")) return 1;
    probe_create(&owner);
    if (!check(owner != NULL && probe_read_count(owner) == 53, "recovery after failure")) return 1;
    original = owner;

    const size_t baseline = ube_gc_root_count;
    const size_t count = UBE_GC_MAX_ROOTS - baseline;
    struct ube_gc_root* pressure = calloc(count, sizeof(*pressure));
    void* neutral = NULL;
    if (!check(pressure != NULL, "test pressure storage")) return 1;
    for (size_t index = 0; index < count; ++index) {
        if (!check(ube_gc_root_enter(&pressure[index], &neutral), "real root pressure admission")) return 1;
    }
    size_t first_success = SIZE_MAX;
    for (size_t remaining = 0; remaining <= 24; ++remaining) {
        if (remaining != 0) (void)ube_gc_root_leave(&pressure[count - remaining]);
        ube_err_set(77, "seed", "observer");
        probe_create(&owner);
        if (owner != original) {
            if (!check(owner != NULL && probe_read_count(owner) == 53 && ube_err_number() == 77,
                       "success after enough actual roots are available")) return 1;
            first_success = remaining;
            break;
        }
        if (!check(ube_err_number() == 7, "root denial leaves old result and fresh Err7")) return 1;
    }
    if (!check(first_success != SIZE_MAX && first_success > 0, "root boundary witnessed")) return 1;
    for (size_t index = count - first_success; index > 0; --index) (void)ube_gc_root_leave(&pressure[index - 1]);
    free(pressure);
    if (!check(ube_gc_root_count == baseline, "procedure/pressure roots reclaimed")) return 1;
    (void)ube_gc_root_leave(&owner_root);
    owner = NULL;
    (void)ube_gc_collect();
    if (!check(ube_gc_root_count == 0 && ube_gc_live_allocation_bytes() == 0,
               "zero residual roots and payload")) return 1;
    printf("PASS reference observer; first successful root capacity=%zu\n", first_success);
    return 0;
}
