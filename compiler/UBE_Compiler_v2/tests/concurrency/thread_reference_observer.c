/* C supplies independent assertions/faults; every worker is the intact UBE Sub. */
#include <windows.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
static void* observed_calloc(size_t count, size_t width);
static void observed_free(void* value);
static void observed_copy(size_t bytes);
static BOOL observed_yield(void);
#define calloc observed_calloc
#define free observed_free
#define SwitchToThread observed_yield
#define UBE_VALUE_OBSERVE_COPY(bytes) observed_copy(bytes)
#include "../../../../runtime/bootstrap_runtime.c"
#undef calloc
#undef free
#undef SwitchToThread

extern int64_t probe_start_owner(void* owner);
extern void probe_make_owner(int32_t length, void** output);
extern int32_t probe_copy_owner(void* owner);
extern int64_t probe_start_fraction(void* owner, double fraction);
extern const struct ube_value_layout* probe_reference_layout(void);

struct byte_owner { struct ube_array* data; int32_t count; void* link; int64_t worker_id; int32_t trace; double fraction; };
_Static_assert(offsetof(struct byte_owner, count) == 8, "independent Count ABI");
_Static_assert(offsetof(struct byte_owner, worker_id) == 24, "independent worker ID ABI");
static DWORD main_native_id;
static volatile LONG tracking, deny_all, deny_worker, denied_worker_allocations;
static volatile LONG capture_attempts, capture_live, record_attempts, record_live;
static volatile LONG worker_yields, worker_error_mismatch;
static volatile LONG64 copied_bytes, capture_payload_bytes;
static void* volatile capture_slots[16];
static void* volatile record_slots[16];

/* Fixed observation storage cannot allocate or become an independent scheduler. */
static void retain_observed(void* volatile* slots, void* value, volatile LONG* live) {
    for (size_t index = 0; index < 16; ++index) {
        if (InterlockedCompareExchangePointer(&slots[index], value, NULL) == NULL) {
            InterlockedIncrement(live);
            return;
        }
    }
    fputs("FAIL observer storage exhausted\n", stderr);
}

static void* observed_calloc(size_t count, size_t width) {
    const size_t bytes = count * width;
    const int observe = InterlockedCompareExchange(&tracking, 0, 0) != 0;
    const int capture = observe && count == 1 &&
        (bytes == sizeof(struct ube_thread_capture) ||
         bytes == sizeof(struct ube_thread_capture) + 8 ||
         bytes == sizeof(struct ube_thread_capture) + 40);
    const int record = observe && count == 1 && bytes == sizeof(struct ube_thread_record);
    if (capture) InterlockedIncrement(&capture_attempts);
    if (record) InterlockedIncrement(&record_attempts);
    if (observe && InterlockedCompareExchange(&deny_all, 0, 0)) return NULL;
    if (observe && GetCurrentThreadId() != main_native_id &&
        InterlockedCompareExchange(&deny_worker, 0, 0)) {
        InterlockedIncrement(&denied_worker_allocations);
        return NULL;
    }
    void* result = calloc(count, width);
    if (result != NULL && capture) {
        retain_observed(capture_slots, result, &capture_live);
        InterlockedExchangeAdd64(&capture_payload_bytes, (LONG64)(bytes - sizeof(struct ube_thread_capture)));
    }
    if (result != NULL && record) retain_observed(record_slots, result, &record_live);
    return result;
}

static void observed_free(void* value) {
    if (value != NULL) {
        for (size_t index = 0; index < 16; ++index) {
            if (InterlockedCompareExchangePointer(&capture_slots[index], NULL, value) == value) InterlockedDecrement(&capture_live);
            if (InterlockedCompareExchangePointer(&record_slots[index], NULL, value) == value) InterlockedDecrement(&record_live);
        }
    }
    free(value);
}

static void observed_copy(size_t bytes) { InterlockedExchangeAdd64(&copied_bytes, (LONG64)bytes); }

/* Observe actual worker-local Err at the real scheduling primitive. */
static BOOL observed_yield(void) {
    if (GetCurrentThreadId() != main_native_id) {
        InterlockedIncrement(&worker_yields);
        if (ube_err_number() != 91) InterlockedIncrement(&worker_error_mismatch);
    }
    return SwitchToThread();
}

static int require(int condition, const char* label) {
    if (condition) return 1;
    fprintf(stderr, "FAIL UBE thread observer: %s (Err=%d)\n", label, ube_err_number());
    return 0;
}

/* Completion publication precedes the last native record release by a few
   instructions; observe actual release rather than assume the thread vanished. */
static int drained(void) {
    const ULONGLONG deadline = GetTickCount64() + 5000;
    while (InterlockedCompareExchange(&record_live, 0, 0) != 0 && GetTickCount64() < deadline) Sleep(1);
    return require(record_live == 0 && capture_live == 0, "native record/capture ownership drained");
}

static int stop_and_wait(int64_t id, struct byte_owner* owner) {
    uint8_t requested = 0, completed = 0;
    if (!require(ube_thread_try_request_stop(id, &requested) && requested, "fresh cooperative stop") ||
        !require(ube_thread_try_wait(id, 5000, &completed) && completed, "fresh completed wait") ||
        !require(__atomic_load_n(&owner->count, __ATOMIC_SEQ_CST) == 97, "actual UBE completion output")) return 0;
    return drained();
}

/* Execute growing inputs, real admission failures and real root registrations. */
int main(void) {
    main_native_id = GetCurrentThreadId();
    int64_t main_id = 0;
    if (!require(ube_thread_try_current_id(&main_id) && main_id > 0, "main identity")) return 1;
    tracking = 1;
    void* value = NULL;
    struct ube_gc_root root = {0};
    const struct ube_value_layout* layout = probe_reference_layout();
    if (!require(ube_value_root_enter(&root, &value, layout), "source owner root")) return 1;
    DWORD baseline_handles = 0;
    if (!require(GetProcessHandleCount(GetCurrentProcess(), &baseline_handles), "initialized substrate handle observation")) return 1;
    const int32_t lengths[] = {1, 64, 1024, 16384};
    for (size_t row = 0; row < sizeof(lengths)/sizeof(lengths[0]); ++row) {
        probe_make_owner(lengths[row], &value);
        struct byte_owner* owner = value;
        if (!require(owner != NULL && owner->data != NULL, "actual UBE growing owner")) return 1;
        copied_bytes = 0; capture_payload_bytes = 0;
        ube_err_set(77, "seed", "observer");
        const int64_t id = probe_start_owner(owner);
        if (!require(id > main_id && ube_err_number() == 77, "real checked UBE CallNew/TLS isolation")) return 1;
        uint8_t completed = 1, alive = 0;
        if (!require(ube_thread_try_wait(id, 0, &completed) && !completed && ube_err_number() == 77, "fresh timeout preserves Err") ||
            !require(ube_thread_try_is_alive(id, &alive) && alive, "fresh liveness")) return 1;
        const ULONGLONG deadline = GetTickCount64() + 5000;
        while (__atomic_load_n(&owner->count, __ATOMIC_SEQ_CST) != 89 && GetTickCount64() < deadline) Sleep(1);
        if (!require(owner->worker_id == id && owner->count == 89, "actual UBE worker identity/output")) return 1;
        /* Only the worker/capture owns the object during this collection. */
        (void)ube_gc_root_leave(&root); value = NULL;
        (void)ube_gc_collect();
        value = owner;
        if (!require(ube_value_root_enter(&root, &value, layout), "restore observer root after worker-only lifetime")) return 1;
        ube_err_set(7, "stale equal number", "observer");
        const uint64_t revision = ube_current_error_state()->revision;
        ube_thread_test_fail_waits(1); completed = 0xa5;
        if (!require(!ube_thread_try_wait(id, 0, &completed) && completed == 0xa5 &&
                     ube_err_number() == 7 && ube_current_error_state()->revision != revision,
                     "wait admission failure is fresh even when Err.Number is unchanged")) return 1;
        if (!stop_and_wait(id, owner)) return 1;
        if (!require(copied_bytes == 0 && capture_payload_bytes == 8, "observed zero payload copy and one eight-byte reference capture")) return 1;
        if (!require(owner->data->data[0] == 7 && (lengths[row] == 1 || owner->data->data[lengths[row]-1] == 11), "original payload preserved")) return 1;
        copied_bytes = 0;
        if (!require(probe_copy_owner(owner) == 7 && copied_bytes == lengths[row], "real UBE ByVal-copy positive observer control")) return 1;
        printf("PASS UBE capture length=%d payload-copy=0 capture-bytes=8 positive-copy=%lld\n", lengths[row], (long long)copied_bytes);
    }
    struct byte_owner* owner = value;
    const int64_t expected_wide = (INT64_C(1) << 40) + 81;
    owner->worker_id = expected_wide;
    capture_payload_bytes = 0;
    uint8_t fraction_completed = 0;
    const int64_t fraction_id = probe_start_fraction(owner, 3.5);
    if (!require(fraction_id > 0 && ube_thread_try_wait(fraction_id, 5000, &fraction_completed) && fraction_completed &&
                 owner->fraction == 3.5 && owner->worker_id == expected_wide && owner->count == 45 && capture_payload_bytes == 40,
                 "actual mixed-width UBE capture preserves nonzero Double and high LongLong bits") || !drained()) return 1;
    const size_t baseline_roots = ube_gc_root_count;
    owner->count = 75;
    int64_t before_id = ube_thread_high_water;
    deny_all = 1; ube_err_set(77, "seed", "observer");
    int64_t denied = probe_start_owner(owner);
    deny_all = 0;
    if (!require(denied == 0 && ube_err_number() == 7 && owner->count == 75 &&
                 ube_thread_high_water == before_id && ube_gc_root_count == baseline_roots,
                 "persistent actual allocation denial has no user body/ID/root leak") || !drained()) return 1;
    ube_thread_test_fail_starts(1); ube_err_set(77, "seed", "observer");
    if (!require(probe_start_owner(owner) == 0 && ube_err_number() == 7 && owner->count == 75 &&
                 ube_thread_high_water == before_id && ube_gc_root_count == baseline_roots,
                 "native start failure consumes capture without issuing an ID") || !drained()) return 1;
    deny_worker = 1; ube_err_set(77, "seed", "observer");
    denied = probe_start_owner(owner); deny_worker = 0;
    if (!require(denied == 0 && ube_err_number() == 7 && owner->count == 75 && denied_worker_allocations > 0 &&
                 ube_thread_high_water == before_id && ube_gc_root_count == baseline_roots,
                 "actual worker TLS allocation denial rejects admission and drains capture") || !drained()) return 1;
    uint8_t output = 0xa5;
    if (!require(!ube_thread_try_wait(0, 0, &output) && output == 0xa5 && ube_err_number() == 5, "invalid ID output preservation") ||
        !require(!ube_thread_try_wait(main_id, 0, &output) && output == 0xa5, "self-wait rejects") ||
        !require(!ube_thread_try_wait(before_id, -2, &output) && output == 0xa5, "invalid timeout rejects")) return 1;

    const size_t pressure_count = UBE_GC_MAX_ROOTS - baseline_roots;
    struct ube_gc_root* pressure = calloc(pressure_count, sizeof(*pressure));
    void* neutral = NULL;
    if (!require(pressure != NULL, "pressure storage")) return 1;
    for (size_t index=0; index<pressure_count; ++index) if (!ube_gc_root_enter(&pressure[index], &neutral)) return 1;
    size_t first_success = SIZE_MAX;
    int witnessed_worker_root_rejection = 0;
    for (size_t available=0; available<=48; ++available) {
        if (available) (void)ube_gc_root_leave(&pressure[pressure_count-available]);
        owner->count = 75;
        const LONG records_before = record_attempts;
        ube_err_set(77, "seed", "observer");
        const int64_t id = probe_start_owner(owner);
        if (id == 0) {
            if (record_attempts > records_before) witnessed_worker_root_rejection = 1;
            if (!require(ube_err_number() == 7 && owner->count == 75 && ube_thread_high_water == before_id,
                         "root denial rejects actual UBE body and ID" ) || !drained()) return 1;
        } else {
            if (!stop_and_wait(id, owner)) return 1;
            first_success = available;
            break;
        }
    }
    if (!require(first_success != SIZE_MAX && witnessed_worker_root_rejection, "creator/capture and actual worker root admission boundaries witnessed")) return 1;
    for (size_t index=pressure_count-first_success; index>0; --index) (void)ube_gc_root_leave(&pressure[index-1]);
    free(pressure);
    if (!require(ube_gc_root_count == baseline_roots && worker_yields > 0 && worker_error_mismatch == 0,
                 "all procedure roots cleaned and actual worker Err remains isolated")) return 1;
    (void)ube_gc_root_leave(&root); value = NULL; (void)ube_gc_collect();
    DWORD final_handles = 0;
    GetProcessHandleCount(GetCurrentProcess(), &final_handles);
    if (!require(ube_gc_root_count == 0 && ube_gc_live_allocation_bytes() == 0 && capture_live == 0 && record_live == 0,
                 "zero residual test roots/payload/captures/records") ||
        !require(final_handles == baseline_handles, "zero residual native handles")) return 1;
    printf("PASS UBE thread failures/TLS/cancellation/root admission; first successful capacity=%zu; handles=%lu\n", first_success, (unsigned long)final_handles);
    return 0;
}
