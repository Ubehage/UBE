#include <inttypes.h>
#include <limits.h>
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <psapi.h>
#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "value_storage.h"

/* A test harness may observe executed payload leaf copies. Production builds
   have no counter, call, or evaluated argument on this path. */
#ifdef UBE_VALUE_OBSERVE_COPY
#define UBE_VALUE_COPY_OBSERVED 1
#define UBE_VALUE_PAYLOAD(value) , value
#define UBE_VALUE_OBSERVE_LEAF(bytes, condition) do { if (condition) UBE_VALUE_OBSERVE_COPY(bytes); } while (0)
#else
#define UBE_VALUE_COPY_OBSERVED 0
#define UBE_VALUE_PAYLOAD(value)
#define UBE_VALUE_OBSERVE_LEAF(bytes, condition) ((void)0)
#define UBE_VALUE_OBSERVE_COPY(size) ((void)0)
#endif

struct ube_string_allocation {
    struct ube_string_allocation* next;
    char data[];
};

struct ube_legacy_allocation {
    struct ube_legacy_allocation* next;
    unsigned char data[];
};

struct ube_array {
    int32_t lower;
    int32_t upper;
    size_t element_size;
    unsigned char data[];
};

enum ube_variant_tag {
    UBE_VARIANT_EMPTY = 0,
    UBE_VARIANT_NULL = 1,
    UBE_VARIANT_LONG = 2,
    UBE_VARIANT_LONGLONG = 3,
    UBE_VARIANT_STRING = 4,
    UBE_VARIANT_OBJECT = 5,
    UBE_VARIANT_BOOLEAN = 6,
    UBE_VARIANT_BYTE = 7,
    UBE_VARIANT_INTEGER = 8,
    UBE_VARIANT_SINGLE = 9,
    UBE_VARIANT_DOUBLE = 10,
    UBE_VARIANT_CURRENCY = 11,
    UBE_VARIANT_DATE = 12,
    UBE_VARIANT_INTPTR = 13,
    UBE_VARIANT_UINTPTR = 14,
    UBE_VARIANT_CUSTOM = 15,
    UBE_VARIANT_ARRAY = 16,
    UBE_VARIANT_DECIMAL = 17
};

struct ube_variant {
    int32_t tag;
    int32_t reserved;
    int64_t scalar;
    double floating;
    void* reference;
};

typedef void (*ube_gc_finalizer)(void* value);

struct ube_gc_layout {
    size_t size;
    size_t slot_count;
    const size_t* slot_offsets;
    ube_gc_finalizer finalizer;
};

struct ube_gc_header {
    struct ube_gc_header* next;
    struct ube_gc_header* hash_next;
    const struct ube_gc_layout* layout;
    size_t payload_size;
    uint64_t magic;
    unsigned char marked;
    unsigned char finalized;
    unsigned char finalizing;
    unsigned char owns_layout;
    unsigned char pending_publication;
    uint32_t pin_count;
    CRITICAL_SECTION monitor;
    unsigned char monitor_initialized;
    const struct ube_value_layout* element_layout;
    size_t element_count;
    struct ube_gc_header* transaction_next;
    _Alignas(max_align_t) unsigned char data[];
};

struct ube_gc_root {
    struct ube_gc_root* next;
    void** slot;
    size_t slot_count;
    const size_t* slot_offsets;
};

#define UBE_GC_MAGIC UINT64_C(0x55424547434F424A)
#define UBE_GC_INITIAL_THRESHOLD (256u * 1024u * 1024u)
#define UBE_GC_HASH_BUCKETS 131072u
#define UBE_GC_MAX_ROOTS 1048576u
#define UBE_OBJECT_MAX_LEASES 1048576u

struct ube_object_lease {
    void* object;
    uint32_t generation;
    uint32_t leases;
};

struct ube_component_state {
    struct ube_component_state* next;
    void* object;
    int32_t kind;
    int32_t state;
    uint32_t active_calls;
    uint64_t load_error_revision;
};

struct ube_component_parent {
    struct ube_component_parent* next;
    void* child;
    void* parent;
};

struct ube_default_form_slot {
    struct ube_default_form_slot* next;
    void** slot;
    int tombstone;
};

typedef void (*ube_event_callback)(void* receiver, void* arguments);

struct ube_event_subscription {
    struct ube_event_subscription* next;
    void* source;
    void* receiver;
    int64_t field_id;
    int64_t event_id;
    uint64_t generation;
    uint64_t order;
    ube_event_callback callback;
};

struct ube_event_snapshot {
    void* source;
    void* receiver;
    int64_t field_id;
    int64_t event_id;
    uint64_t generation;
    uint64_t order;
    ube_event_callback callback;
};

struct ube_library_diagnostic_slot {
    struct ube_library_diagnostic_slot* next;
    DWORD thread_id;
    char text[512];
};

static struct ube_gc_header* ube_gc_allocations;
static struct ube_gc_header* ube_gc_allocation_hash[UBE_GC_HASH_BUCKETS];
static struct ube_gc_root* ube_gc_roots;
static size_t ube_gc_live_bytes;
static size_t ube_gc_threshold = UBE_GC_INITIAL_THRESHOLD;
static size_t ube_gc_root_count;
static int ube_gc_collecting;
static int ube_gc_shutdown;
static int ube_gc_cleanup_registered;
static uint32_t ube_gc_test_allocation_failures;
static uint32_t ube_gc_test_trace_failures;
static size_t ube_library_active_calls;
static int ube_library_accepting_calls = 1;
static struct ube_library_diagnostic_slot* ube_library_diagnostics;
static int ube_library_initialized;
static void (*ube_library_terminator)(void);
static struct ube_object_lease* ube_object_leases;
static size_t ube_object_lease_count;
static size_t ube_object_lease_capacity;
static struct ube_component_state* ube_components;
static struct ube_component_parent* ube_component_parents;
static size_t ube_active_event_sources;
static HANDLE ube_component_sources_done;
static struct ube_default_form_slot* ube_default_form_slots;
static struct ube_event_subscription* ube_event_subscriptions;
static uint64_t ube_event_generation;
static uint64_t ube_event_order;
static uint32_t ube_event_test_snapshot_failures;
static INIT_ONCE ube_event_lock_once = INIT_ONCE_STATIC_INIT;
static CRITICAL_SECTION ube_event_lock;
static INIT_ONCE ube_gc_lock_once = INIT_ONCE_STATIC_INIT;
static CRITICAL_SECTION ube_gc_lock;
static INIT_ONCE ube_thread_lock_once = INIT_ONCE_STATIC_INIT;
static CRITICAL_SECTION ube_thread_lock;
static void ube_gc_release_all(void);
static char* ube_allocate_string_managed(size_t length);
int32_t ube_gc_pin(void* value);
int32_t ube_gc_unpin(void* value);
static void ube_gc_enter_lock(void);
static void ube_gc_leave_lock(void);

/* Each native thread admitted to UBE owns an independent recoverable-error
   record. Fixed buffers keep error publication allocation-free, including on
   low-memory paths. */
struct ube_error_state {
    int32_t number;
    uint64_t revision;
    char description[512];
    char source[256];
};

/* The maintained Windows runtime is compiled with native TLS by Clang.
   First-error publication must not require allocation of the larger FLS
   record used for monitors, events and thread registration. */
static _Thread_local struct ube_error_state ube_thread_error;

static struct ube_error_state* ube_current_error_state(void) {
    return &ube_thread_error;
}

#define UBE_MONITOR_TRACKING_CAPACITY 256u

/* Monitor ownership is tracked per native thread so structured error
   handling can temporarily release locks while a handler runs. */
struct ube_monitor_tracking {
    void* object;
    uint32_t held_count;
    uint32_t released_for_error;
};

struct ube_thread_record;
struct ube_thread_local_state {
#ifdef UBE_FILE_TESTING
    int32_t file_test_mode;
    void (*file_before_read)(void*);
    void* file_before_read_context;
#endif
    int64_t thread_id;
    struct ube_thread_record* thread_record;
    uint32_t event_depth;
    struct ube_monitor_tracking monitors[UBE_MONITOR_TRACKING_CAPACITY];
};

static INIT_ONCE ube_tls_once = INIT_ONCE_STATIC_INIT;
static DWORD ube_tls_index = FLS_OUT_OF_INDEXES;

static VOID CALLBACK ube_tls_release(PVOID value) {
    free(value);
}

static BOOL CALLBACK ube_tls_initialize(PINIT_ONCE once, PVOID parameter,
                                        PVOID* context) {
    (void)once;
    (void)parameter;
    (void)context;
    ube_tls_index = FlsAlloc(ube_tls_release);
    return ube_tls_index != FLS_OUT_OF_INDEXES;
}

static struct ube_thread_local_state* ube_tls_get(int create) {
    if (!InitOnceExecuteOnce(&ube_tls_once, ube_tls_initialize, NULL, NULL)) {
        return NULL;
    }
    struct ube_thread_local_state* state = FlsGetValue(ube_tls_index);
    if (state == NULL && create) {
        state = calloc(1, sizeof(*state));
        if (state == NULL || !FlsSetValue(ube_tls_index, state)) {
            free(state);
            return NULL;
        }
    }
    return state;
}

/* Copies bounded diagnostic text without depending on locale or allocation. */
static void ube_error_copy_text(char* destination, size_t capacity,
                                const char* source) {
    if (capacity == 0u) return;
    if (source == NULL) source = "";
    const size_t length = strlen(source);
    const size_t copied = length < capacity - 1u ? length : capacity - 1u;
    memcpy(destination, source, copied);
    destination[copied] = '\0';
}

/* Records a recoverable failure in the calling thread without clearing any
   other thread's state. */
void ube_err_set(int32_t number, const char* description, const char* source) {
    struct ube_error_state* state = ube_current_error_state();
    ++state->revision;
    if (state->revision == 0) ++state->revision;
    state->number = number;
    ube_error_copy_text(state->description, sizeof(state->description), description);
    ube_error_copy_text(state->source, sizeof(state->source), source);
}

/* Returns the calling thread's current UBE error number. */
int32_t ube_err_number(void) {
    return ube_current_error_state()->number;
}

/* Explicitly clears the calling thread's error record. Successful operations
   deliberately do not call this function. */
void ube_err_clear(void) {
    struct ube_error_state* state = ube_current_error_state();
    uint64_t revision = state->revision + 1u;
    if (revision == 0) revision = 1u;
    memset(state, 0, sizeof(*state));
    state->revision = revision;
}

/* Event recursion is admitted before generated dispatch enters user code so a
   recursive event cycle becomes an ordinary recoverable error before native
   stack exhaustion. */
int32_t ube_event_enter(void) {
    struct ube_thread_local_state* state = ube_tls_get(1);
    if (state == NULL) {
        ube_err_set(7, "event recursion state allocation failed", "UBE.Events");
        return 0;
    }
    if (state->event_depth >= 128u) {
        ube_err_set(28, "event recursion limit exceeded", "UBE.Events");
        return 0;
    }
    ++state->event_depth;
    return 1;
}

void ube_event_leave(void) {
    struct ube_thread_local_state* state = ube_tls_get(0);
    if (state != NULL && state->event_depth != 0u) --state->event_depth;
}

static BOOL CALLBACK ube_event_initialize_lock(PINIT_ONCE once, PVOID parameter,
                                                PVOID* context) {
    (void)once;
    (void)parameter;
    (void)context;
    InitializeCriticalSection(&ube_event_lock);
    return TRUE;
}

static int ube_event_enter_lock(void) {
    if (!InitOnceExecuteOnce(&ube_event_lock_once, ube_event_initialize_lock,
                             NULL, NULL)) {
        ube_err_set(7, "event registry initialization failed", "UBE.Events");
        return 0;
    }
    EnterCriticalSection(&ube_event_lock);
    return 1;
}

static void ube_event_leave_lock(void) {
    LeaveCriticalSection(&ube_event_lock);
}

/* Called with the event lock held. The event->collector lock order is shared
   by connect and dispatch; component unload never holds the collector lock
   while acquiring the event lock. */
static int ube_event_component_identity_allowed(void* value) {
    if (value == NULL) return 1;
    int allowed = 1;
    ube_gc_enter_lock();
    for (struct ube_component_state* item = ube_components;
         item != NULL; item = item->next) {
        if (item->object == value) {
            allowed = item->state != 3;
            break;
        }
    }
    ube_gc_leave_lock();
    return allowed;
}

void ube_event_disconnect(void* receiver, int64_t field_id) {
    if (!ube_event_enter_lock()) return;
    struct ube_event_subscription** link = &ube_event_subscriptions;
    struct ube_event_subscription* removed = NULL;
    while (*link != NULL) {
        struct ube_event_subscription* item = *link;
        if (item->receiver == receiver && item->field_id == field_id) {
            *link = item->next;
            item->next = removed;
            removed = item;
        } else {
            link = &item->next;
        }
    }
    ube_event_leave_lock();
    while (removed != NULL) {
        struct ube_event_subscription* next = removed->next;
        if (removed->receiver != NULL) (void)ube_gc_unpin(removed->receiver);
        free(removed);
        removed = next;
    }
}

static void ube_event_disconnect_identity(void* identity) {
    if (identity == NULL || !ube_event_enter_lock()) return;
    struct ube_event_subscription** link = &ube_event_subscriptions;
    struct ube_event_subscription* removed = NULL;
    while (*link != NULL) {
        struct ube_event_subscription* item = *link;
        if (item->source == identity || item->receiver == identity) {
            *link = item->next;
            item->next = removed;
            removed = item;
        } else {
            link = &item->next;
        }
    }
    ube_event_leave_lock();
    while (removed != NULL) {
        struct ube_event_subscription* next = removed->next;
        if (removed->receiver != NULL) (void)ube_gc_unpin(removed->receiver);
        free(removed);
        removed = next;
    }
}

int32_t ube_event_connect(void* receiver, int64_t field_id, void* source,
                          int64_t event_id, ube_event_callback callback) {
    if (source == NULL || callback == NULL) return 1;
    struct ube_event_subscription* item = calloc(1, sizeof(*item));
    if (item == NULL) {
        ube_err_set(7, "event subscription allocation failed", "UBE.Events");
        return 0;
    }
    if (receiver != NULL && !ube_gc_pin(receiver)) {
        free(item);
        ube_err_set(91, "event receiver is not live", "UBE.Events");
        return 0;
    }
    if (!ube_event_enter_lock()) {
        if (receiver != NULL) (void)ube_gc_unpin(receiver);
        free(item);
        return 0;
    }
    if (!ube_event_component_identity_allowed(source) ||
        !ube_event_component_identity_allowed(receiver)) {
        ube_event_leave_lock();
        if (receiver != NULL) (void)ube_gc_unpin(receiver);
        free(item);
        ube_err_set(91, "event endpoint is unloading", "UBE.Events");
        return 0;
    }
    if (ube_event_generation == UINT64_MAX || ube_event_order == UINT64_MAX) {
        ube_event_leave_lock();
        if (receiver != NULL) (void)ube_gc_unpin(receiver);
        free(item);
        ube_err_set(7, "event subscription identity capacity exhausted", "UBE.Events");
        return 0;
    }
    item->source = source;
    item->receiver = receiver;
    item->field_id = field_id;
    item->event_id = event_id;
    item->callback = callback;
    item->generation = ++ube_event_generation;
    item->order = ++ube_event_order;
    item->next = ube_event_subscriptions;
    ube_event_subscriptions = item;
    ube_event_leave_lock();
    return 1;
}

static int ube_event_snapshot_compare(const void* left, const void* right) {
    const struct ube_event_snapshot* a = left;
    const struct ube_event_snapshot* b = right;
    return a->order < b->order ? -1 : a->order > b->order ? 1 : 0;
}

int32_t ube_event_dispatch(void* source, int64_t event_id, void* arguments) {
    if (source == NULL) return 1;
    if (!ube_event_enter()) return 0;
    if (!ube_gc_pin(source)) {
        ube_event_leave();
        ube_err_set(91, "event source is not live", "UBE.Events");
        return 0;
    }
    if (!ube_event_enter_lock()) {
        (void)ube_gc_unpin(source);
        ube_event_leave();
        return 0;
    }
    if (!ube_event_component_identity_allowed(source)) {
        ube_event_leave_lock();
        (void)ube_gc_unpin(source);
        ube_event_leave();
        ube_err_set(91, "event source is unloading", "UBE.Events");
        return 0;
    }
    size_t count = 0;
    for (struct ube_event_subscription* item = ube_event_subscriptions;
         item != NULL; item = item->next) {
        if (item->source == source && item->event_id == event_id) ++count;
    }
    const int inject_snapshot_failure = count != 0 &&
        ube_event_test_snapshot_failures != 0;
    if (inject_snapshot_failure) --ube_event_test_snapshot_failures;
    struct ube_event_snapshot* snapshot = count == 0 || inject_snapshot_failure
        ? NULL : calloc(count, sizeof(*snapshot));
    if (count != 0 && snapshot == NULL) {
        ube_event_leave_lock();
        (void)ube_gc_unpin(source);
        ube_event_leave();
        ube_err_set(7, "event dispatch snapshot allocation failed", "UBE.Events");
        return 0;
    }
    size_t index = 0;
    for (struct ube_event_subscription* item = ube_event_subscriptions;
         item != NULL; item = item->next) {
        if (item->source == source && item->event_id == event_id) {
            snapshot[index].source = item->source;
            snapshot[index].receiver = item->receiver;
            snapshot[index].field_id = item->field_id;
            snapshot[index].event_id = item->event_id;
            snapshot[index].generation = item->generation;
            snapshot[index].order = item->order;
            snapshot[index].callback = item->callback;
            ++index;
        }
    }
    ube_event_leave_lock();
    if (count > 1) qsort(snapshot, count, sizeof(*snapshot), ube_event_snapshot_compare);
    int dispatch_ok = 1;
    for (index = 0; index < count; ++index) {
        int active = 0;
        if (!ube_event_enter_lock()) {
            dispatch_ok = 0;
            break;
        }
        for (struct ube_event_subscription* item = ube_event_subscriptions;
             item != NULL; item = item->next) {
            if (item->generation == snapshot[index].generation &&
                item->source == snapshot[index].source &&
                item->receiver == snapshot[index].receiver &&
                item->field_id == snapshot[index].field_id &&
                item->event_id == snapshot[index].event_id) {
                active = snapshot[index].receiver == NULL ||
                    ube_gc_pin(snapshot[index].receiver);
                break;
            }
        }
        ube_event_leave_lock();
        if (active) {
            snapshot[index].callback(snapshot[index].receiver, arguments);
            if (snapshot[index].receiver != NULL) {
                (void)ube_gc_unpin(snapshot[index].receiver);
            }
        }
    }
    free(snapshot);
    (void)ube_gc_unpin(source);
    ube_event_leave();
    return dispatch_ok;
}

void ube_event_test_fail_snapshots(uint32_t count) {
    if (!ube_event_enter_lock()) return;
    ube_event_test_snapshot_failures = count;
    ube_event_leave_lock();
}

/* Returns an independently managed copy of the current error description. */
void* ube_err_description(void) {
    const char* description = ube_current_error_state()->description;
    const size_t length = strlen(description);
    char* result = ube_allocate_string_managed(length);
    if (result == NULL) return NULL;
    memcpy(result, description, length + 1u);
    return result;
}

/* Returns an independently managed copy of the current error source. */
void* ube_err_source(void) {
    const char* source = ube_current_error_state()->source;
    const size_t length = strlen(source);
    char* result = ube_allocate_string_managed(length);
    if (result == NULL) return NULL;
    memcpy(result, source, length + 1u);
    return result;
}

/* The executable carries its own native-thread registry. Completed records are
   discarded immediately; the monotonically increasing high-water mark is
   enough to distinguish an issued/completed identifier from an invalid one. */
typedef void (*ube_thread_entry)(void* capture);
typedef void (*ube_thread_capture_destructor)(void* capture);
typedef void (*ube_dispatch_callback)(void* context);
typedef int32_t (*ube_dispatch_adapter)(int64_t target_thread_id,
                                        ube_dispatch_callback callback,
                                        void* context);

struct ube_thread_record {
    struct ube_thread_record* next;
    int64_t id;
    HANDLE completed;
    HANDLE stop_requested;
    ube_thread_entry entry;
    ube_thread_capture_destructor destroy_capture;
    void* capture;
    int is_worker;
    int64_t dispatch_wait_target;
};

static struct ube_thread_record* ube_threads;
static int64_t ube_thread_high_water;
static int ube_thread_accepting = 1;
static uint32_t ube_thread_test_start_failures;
static uint32_t ube_thread_test_wait_failures;
static uint32_t ube_dispatch_test_admission_failures;
static ube_dispatch_adapter ube_platform_dispatch_adapter;
static HANDLE ube_thread_workers_done;
static BOOL CALLBACK ube_thread_initialize_lock(PINIT_ONCE once, PVOID parameter,
                                                 PVOID* context) {
    (void)once;
    (void)parameter;
    (void)context;
    InitializeCriticalSection(&ube_thread_lock);
    ube_thread_workers_done = CreateEventA(NULL, TRUE, TRUE, NULL);
    if (ube_thread_workers_done == NULL) {
        DeleteCriticalSection(&ube_thread_lock);
        return FALSE;
    }
    return TRUE;
}

static int ube_thread_enter_lock(void) {
    if (!InitOnceExecuteOnce(&ube_thread_lock_once, ube_thread_initialize_lock,
                             NULL, NULL)) {
        ube_err_set(7, "thread registry initialization failed", "UBECore.Threads");
        return 0;
    }
    EnterCriticalSection(&ube_thread_lock);
    return 1;
}

static void ube_thread_leave_lock(void) {
    LeaveCriticalSection(&ube_thread_lock);
}

static struct ube_thread_record* ube_thread_find_locked(int64_t id) {
    struct ube_thread_record* record = ube_threads;
    while (record != NULL) {
        if (record->id == id) return record;
        record = record->next;
    }
    return NULL;
}

static void ube_thread_signal_if_idle_locked(void) {
    struct ube_thread_record* record = ube_threads;
    while (record != NULL) {
        if (record->is_worker) return;
        record = record->next;
    }
    SetEvent(ube_thread_workers_done);
}

static DWORD WINAPI ube_thread_worker(LPVOID raw_record) {
    struct ube_thread_record* record = raw_record;
    struct ube_thread_local_state* state = ube_tls_get(1);
    if (state == NULL) {
        if (record->destroy_capture != NULL) {
            record->destroy_capture(record->capture);
        }
        record->capture = NULL;
        if (ube_thread_enter_lock()) {
            struct ube_thread_record** link = &ube_threads;
            while (*link != NULL && *link != record) link = &(*link)->next;
            if (*link == record) *link = record->next;
            SetEvent(record->completed);
            ube_thread_signal_if_idle_locked();
            ube_thread_leave_lock();
            CloseHandle(record->stop_requested);
            CloseHandle(record->completed);
            free(record);
        } else {
            /* A registry-lock initialization failure is unrecoverable for this
               worker, but retaining the record is safer than leaving a live
               list entry that points at freed memory. */
            SetEvent(record->completed);
        }
        return 0;
    }
    state->thread_id = record->id;
    state->thread_record = record;
    record->entry(record->capture);
    if (record->destroy_capture != NULL) {
        record->destroy_capture(record->capture);
    }
    record->capture = NULL;
    ube_err_clear();

    if (ube_thread_enter_lock()) {
        struct ube_thread_record** link = &ube_threads;
        while (*link != NULL && *link != record) link = &(*link)->next;
        if (*link == record) *link = record->next;
        SetEvent(record->completed);
        ube_thread_signal_if_idle_locked();
        ube_thread_leave_lock();
        state->thread_record = NULL;
        CloseHandle(record->stop_requested);
        CloseHandle(record->completed);
        free(record);
    } else {
        /* Preserve the registry node if it could not be detached. */
        SetEvent(record->completed);
    }
    return 0;
}

/* Starts a native worker after its complete ByVal capture has been published.
   The compiler supplies a typed thunk and an optional capture destructor. */
int64_t ube_thread_start(ube_thread_entry entry, void* capture,
                         ube_thread_capture_destructor destroy_capture) {
    if (entry == NULL) {
        if (destroy_capture != NULL) destroy_capture(capture);
        ube_err_set(5, "CallNew target is invalid", "UBECore.Threads");
        return 0;
    }
    struct ube_thread_record* record = calloc(1, sizeof(*record));
    if (record == NULL) {
        if (destroy_capture != NULL) destroy_capture(capture);
        ube_err_set(7, "thread record allocation failed", "UBECore.Threads");
        return 0;
    }
    record->completed = CreateEventA(NULL, TRUE, FALSE, NULL);
    record->stop_requested = CreateEventA(NULL, TRUE, FALSE, NULL);
    record->entry = entry;
    record->destroy_capture = destroy_capture;
    record->capture = capture;
    record->is_worker = 1;
    if (record->completed == NULL || record->stop_requested == NULL) {
        if (record->completed != NULL) CloseHandle(record->completed);
        if (record->stop_requested != NULL) CloseHandle(record->stop_requested);
        free(record);
        if (destroy_capture != NULL) destroy_capture(capture);
        ube_err_set(7, "thread event allocation failed", "UBECore.Threads");
        return 0;
    }
    if (!ube_thread_enter_lock()) {
        CloseHandle(record->completed);
        CloseHandle(record->stop_requested);
        free(record);
        if (destroy_capture != NULL) destroy_capture(capture);
        return 0;
    }
    if (!ube_thread_accepting || ube_thread_high_water == INT64_MAX) {
        ube_thread_leave_lock();
        CloseHandle(record->completed);
        CloseHandle(record->stop_requested);
        free(record);
        if (destroy_capture != NULL) destroy_capture(capture);
        ube_err_set(7, "thread creation is closed", "UBECore.Threads");
        return 0;
    }
    record->id = ++ube_thread_high_water;
    record->next = ube_threads;
    ube_threads = record;
    ResetEvent(ube_thread_workers_done);
    const int inject_failure = ube_thread_test_start_failures != 0;
    if (inject_failure) --ube_thread_test_start_failures;
    HANDLE native_thread = inject_failure
        ? NULL : CreateThread(NULL, 0, ube_thread_worker, record, 0, NULL);
    if (native_thread == NULL) {
        ube_threads = record->next;
        ube_thread_signal_if_idle_locked();
        ube_thread_leave_lock();
        CloseHandle(record->completed);
        CloseHandle(record->stop_requested);
        free(record);
        if (destroy_capture != NULL) destroy_capture(capture);
        ube_err_set(7, "native thread creation failed", "UBECore.Threads");
        return 0;
    }
    const int64_t issued_id = record->id;
    CloseHandle(native_thread);
    ube_thread_leave_lock();
    return issued_id;
}

int64_t ube_thread_current_id(void) {
    struct ube_thread_local_state* state = ube_tls_get(1);
    if (state == NULL) return 0;
    if (state->thread_id == 0 && ube_thread_enter_lock()) {
        struct ube_thread_record* record = calloc(1, sizeof(*record));
        if (record != NULL && ube_thread_high_water < INT64_MAX) {
            record->completed = CreateEventA(NULL, TRUE, FALSE, NULL);
            record->stop_requested = CreateEventA(NULL, TRUE, FALSE, NULL);
            if (record->completed != NULL && record->stop_requested != NULL) {
                record->id = ++ube_thread_high_water;
                record->next = ube_threads;
                ube_threads = record;
                state->thread_id = record->id;
                state->thread_record = record;
            } else {
                if (record->completed != NULL) CloseHandle(record->completed);
                if (record->stop_requested != NULL) CloseHandle(record->stop_requested);
                free(record);
            }
        } else {
            free(record);
        }
        ube_thread_leave_lock();
        if (state->thread_id == 0) {
            ube_err_set(7, "current thread registration failed", "UBECore.Threads");
        }
    }
    return state->thread_id;
}

bool ube_thread_is_alive(int64_t id) {
    if (id <= 0 || !ube_thread_enter_lock()) {
        if (id <= 0) ube_err_set(5, "thread identifier was never issued", "UBECore.Threads");
        return 0;
    }
    const int found = ube_thread_find_locked(id) != NULL;
    const int issued = id <= ube_thread_high_water;
    ube_thread_leave_lock();
    if (!issued) ube_err_set(5, "thread identifier was never issued", "UBECore.Threads");
    return found ? 1 : 0;
}

int32_t ube_thread_request_stop(int64_t id) {
    if (id <= 0 || !ube_thread_enter_lock()) {
        if (id <= 0) ube_err_set(5, "thread identifier was never issued", "UBECore.Threads");
        return 0;
    }
    struct ube_thread_record* record = ube_thread_find_locked(id);
    const int issued = id <= ube_thread_high_water;
    int32_t result = 0;
    if (record != NULL) result = SetEvent(record->stop_requested) ? 1 : 0;
    ube_thread_leave_lock();
    if (!issued) ube_err_set(5, "thread identifier was never issued", "UBECore.Threads");
    else if (record != NULL && !result) ube_err_set(7, "stop request failed", "UBECore.Threads");
    return result;
}

bool ube_thread_stop_requested(void) {
    struct ube_thread_local_state* state = ube_tls_get(0);
    struct ube_thread_record* record = state != NULL ? state->thread_record : NULL;
    if (record == NULL) return 0;
    return WaitForSingleObject(record->stop_requested, 0) == WAIT_OBJECT_0 ? 1 : 0;
}

int32_t ube_thread_wait(int64_t id, int64_t timeout_milliseconds) {
    if (id <= 0) {
        ube_err_set(5, "thread identifier was never issued", "UBECore.Threads");
        return 0;
    }
    struct ube_thread_local_state* state = ube_tls_get(0);
    if (state != NULL && id == state->thread_id && id != 0) {
        ube_err_set(5, "a thread cannot wait for itself", "UBECore.Threads");
        return 0;
    }
    if (timeout_milliseconds < -1 || timeout_milliseconds > UINT32_MAX) {
        ube_err_set(5, "thread wait timeout is invalid", "UBECore.Threads");
        return 0;
    }
    if (!ube_thread_enter_lock()) return 0;
    struct ube_thread_record* target = ube_thread_find_locked(id);
    const int issued = id <= ube_thread_high_water;
    HANDLE completed_copy = NULL;
    const int inject_wait_failure = target != NULL &&
        ube_thread_test_wait_failures != 0;
    if (inject_wait_failure) --ube_thread_test_wait_failures;
    if (target != NULL && !inject_wait_failure) {
        DuplicateHandle(GetCurrentProcess(), target->completed,
                        GetCurrentProcess(), &completed_copy, SYNCHRONIZE,
                        FALSE, 0);
    }
    ube_thread_leave_lock();
    if (!issued) {
        ube_err_set(5, "thread identifier was never issued", "UBECore.Threads");
        return 0;
    }
    if (target == NULL) return 1;
    if (completed_copy == NULL) {
        ube_err_set(7, "thread wait registration failed", "UBECore.Threads");
        return 0;
    }
    HANDLE waits[2] = { completed_copy, NULL };
    DWORD wait_count = 1;
    if (state != NULL && state->thread_record != NULL) {
        waits[1] = state->thread_record->stop_requested;
        wait_count = 2;
    }
    const DWORD timeout = timeout_milliseconds < 0
        ? INFINITE : (DWORD)timeout_milliseconds;
    const DWORD wait_result = WaitForMultipleObjects(wait_count, waits, FALSE, timeout);
    CloseHandle(completed_copy);
    if (wait_result == WAIT_OBJECT_0) return 1;
    if (wait_result == WAIT_TIMEOUT || (wait_count == 2 && wait_result == WAIT_OBJECT_0 + 1)) return 0;
    ube_err_set(7, "thread wait failed", "UBECore.Threads");
    return 0;
}

void ube_thread_yield(void) {
    SwitchToThread();
}

/* Installs the framework-owned UI dispatcher adapter. The adapter is invoked
   without any UBE registry/collector lock held and must synchronously execute
   the callback on target_thread_id before returning success. */
void ube_dispatch_install_adapter(ube_dispatch_adapter adapter) {
    if (!ube_thread_enter_lock()) return;
    ube_platform_dispatch_adapter = adapter;
    ube_thread_leave_lock();
}

int32_t ube_dispatch_invoke(int64_t target_thread_id,
                            ube_dispatch_callback callback, void* context) {
    if (target_thread_id <= 0 || callback == NULL) {
        ube_err_set(5, "dispatcher target or callback is invalid", "UBE.Dispatcher");
        return 0;
    }
    const int64_t current_thread_id = ube_thread_current_id();
    if (current_thread_id == 0) return 0;
    if (current_thread_id == target_thread_id) {
        callback(context);
        return 1;
    }
    if (!ube_thread_enter_lock()) return 0;
    struct ube_thread_record* current =
        ube_thread_find_locked(current_thread_id);
    struct ube_thread_record* target =
        ube_thread_find_locked(target_thread_id);
    const int inject_failure = ube_dispatch_test_admission_failures != 0;
    if (inject_failure) --ube_dispatch_test_admission_failures;
    if (current == NULL || target == NULL || inject_failure) {
        ube_thread_leave_lock();
        ube_err_set(inject_failure ? 7 : 91,
                    inject_failure ? "dispatcher admission failed" :
                        "dispatcher thread is not live",
                    "UBE.Dispatcher");
        return 0;
    }
    if (target->dispatch_wait_target == current_thread_id) {
        ube_thread_leave_lock();
        ube_err_set(5, "direct dispatcher wait cycle detected", "UBE.Dispatcher");
        return 0;
    }
    ube_dispatch_adapter adapter = ube_platform_dispatch_adapter;
    if (adapter == NULL) {
        ube_thread_leave_lock();
        ube_err_set(91, "platform dispatcher is not installed", "UBE.Dispatcher");
        return 0;
    }
    current->dispatch_wait_target = target_thread_id;
    ube_thread_leave_lock();

    const int32_t result = adapter(target_thread_id, callback, context);

    if (ube_thread_enter_lock()) {
        current = ube_thread_find_locked(current_thread_id);
        if (current != NULL && current->dispatch_wait_target == target_thread_id) {
            current->dispatch_wait_target = 0;
        }
        ube_thread_leave_lock();
    }
    if (!result) {
        ube_err_set(7, "platform dispatcher rejected the callback", "UBE.Dispatcher");
        return 0;
    }
    return 1;
}

void ube_thread_test_fail_starts(uint32_t count) {
    if (!ube_thread_enter_lock()) return;
    ube_thread_test_start_failures = count;
    ube_thread_leave_lock();
}

void ube_thread_test_fail_waits(uint32_t count) {
    if (!ube_thread_enter_lock()) return;
    ube_thread_test_wait_failures = count;
    ube_thread_leave_lock();
}

void ube_dispatch_test_fail_admissions(uint32_t count) {
    if (!ube_thread_enter_lock()) return;
    ube_dispatch_test_admission_failures = count;
    ube_thread_leave_lock();
}

int32_t ube_dispatch_test_set_wait_target(int64_t thread_id,
                                          int64_t target_thread_id) {
    if (!ube_thread_enter_lock()) return 0;
    struct ube_thread_record* record = ube_thread_find_locked(thread_id);
    if (record != NULL) record->dispatch_wait_target = target_thread_id;
    ube_thread_leave_lock();
    return record != NULL ? 1 : 0;
}

void ube_thread_close_admission(void) {
    if (!ube_thread_enter_lock()) return;
    ube_thread_accepting = 0;
    ube_thread_leave_lock();
}

void ube_thread_program_wait(void) {
    for (;;) {
        if (!ube_thread_enter_lock()) return;
        int found_worker = 0;
        struct ube_thread_record* record = ube_threads;
        while (record != NULL) {
            if (record->is_worker) {
                found_worker = 1;
                break;
            }
            record = record->next;
        }
        ube_thread_leave_lock();

        ube_gc_enter_lock();
        const int found_event_source = ube_active_event_sources != 0;
        HANDLE sources_done = ube_component_sources_done;
        ube_gc_leave_lock();

        if (!found_worker && !found_event_source) {
            if (!ube_thread_enter_lock()) return;
            ube_thread_accepting = 0;
            ube_thread_leave_lock();
            return;
        }
        HANDLE waits[2];
        DWORD wait_count = 0;
        if (found_worker) waits[wait_count++] = ube_thread_workers_done;
        if (found_event_source && sources_done != NULL) {
            waits[wait_count++] = sources_done;
        }
        if (wait_count == 0 ||
            WaitForMultipleObjects(wait_count, waits, FALSE, INFINITE) == WAIT_FAILED) {
            ube_err_set(7, "program shutdown wait failed", "UBECore.Threads");
            fputs("UBE thread support: program shutdown wait failed\n", stderr);
            return;
        }
    }
}

static BOOL CALLBACK ube_gc_initialize_lock(PINIT_ONCE once, PVOID parameter,
                                             PVOID* context) {
    (void)once;
    (void)parameter;
    (void)context;
    InitializeCriticalSection(&ube_gc_lock);
    ube_component_sources_done = CreateEventA(NULL, TRUE, TRUE, NULL);
    if (ube_component_sources_done == NULL) {
        DeleteCriticalSection(&ube_gc_lock);
        return FALSE;
    }
    return TRUE;
}

static void ube_gc_enter_lock(void) {
    if (!InitOnceExecuteOnce(&ube_gc_lock_once, ube_gc_initialize_lock, NULL, NULL)) {
        fputs("UBE managed support: could not initialize collector lock\n", stderr);
        ExitProcess(70);
    }
    EnterCriticalSection(&ube_gc_lock);
}

static void ube_gc_leave_lock(void) {
    LeaveCriticalSection(&ube_gc_lock);
}

static struct ube_library_diagnostic_slot* ube_library_diagnostic_slot_for_current_thread(
    int create) {
    const DWORD thread_id = GetCurrentThreadId();
    struct ube_library_diagnostic_slot* slot = ube_library_diagnostics;
    while (slot != NULL) {
        if (slot->thread_id == thread_id) return slot;
        slot = slot->next;
    }
    if (!create) return NULL;
    slot = calloc(1, sizeof(*slot));
    if (slot == NULL) return NULL;
    slot->thread_id = thread_id;
    slot->next = ube_library_diagnostics;
    ube_library_diagnostics = slot;
    return slot;
}

static void ube_library_release_diagnostics(void) {
    while (ube_library_diagnostics != NULL) {
        struct ube_library_diagnostic_slot* slot = ube_library_diagnostics;
        ube_library_diagnostics = slot->next;
        free(slot);
    }
}

static void ube_library_set_diagnostic_text(const char* message) {
    ube_gc_enter_lock();
    if (message == NULL) message = "";
    struct ube_library_diagnostic_slot* slot =
        ube_library_diagnostic_slot_for_current_thread(1);
    if (slot == NULL) {
        ube_gc_leave_lock();
        return;
    }
    const size_t length = strlen(message);
    const size_t copied = length < sizeof(slot->text) - 1
        ? length : sizeof(slot->text) - 1;
    memcpy(slot->text, message, copied);
    slot->text[copied] = '\0';
    ube_gc_leave_lock();
}

int32_t ube_library_call_enter(void) {
    ube_gc_enter_lock();
    if (!ube_library_accepting_calls || ube_gc_shutdown ||
        ube_library_active_calls == SIZE_MAX) {
        if (!ube_gc_shutdown) {
            struct ube_library_diagnostic_slot* slot =
                ube_library_diagnostic_slot_for_current_thread(1);
            if (slot != NULL) {
                const char* message = "library is shutting down";
                const size_t length = strlen(message);
                const size_t copied = length < sizeof(slot->text) - 1
                    ? length : sizeof(slot->text) - 1;
                memcpy(slot->text, message, copied);
                slot->text[copied] = '\0';
            }
        }
        ube_gc_leave_lock();
        return 0;
    }
    ube_library_active_calls += 1;
    struct ube_library_diagnostic_slot* slot =
        ube_library_diagnostic_slot_for_current_thread(1);
    if (slot != NULL) slot->text[0] = '\0';
    ube_gc_leave_lock();
    return 1;
}

void ube_library_call_leave(void) {
    ube_gc_enter_lock();
    if (ube_library_active_calls != 0) ube_library_active_calls -= 1;
    ube_gc_leave_lock();
}

void ube_library_set_diagnostic(const char* message) {
    ube_library_set_diagnostic_text(message);
}

int32_t ube_library_initialize_once(void (*initializer)(void),
                                    void (*terminator)(void)) {
    ube_gc_enter_lock();
    if (ube_gc_shutdown || !ube_library_accepting_calls) {
        ube_gc_leave_lock();
        return 0;
    }
    if (!ube_library_initialized) {
        if (initializer != NULL) initializer();
        ube_library_terminator = terminator;
        ube_library_initialized = 1;
    }
    ube_gc_leave_lock();
    return 1;
}

__declspec(dllexport) int32_t ube_library_copy_diagnostic(
    char* buffer, uint64_t capacity, uint64_t* required) {
    ube_gc_enter_lock();
    struct ube_library_diagnostic_slot* slot =
        ube_library_diagnostic_slot_for_current_thread(0);
    const char* diagnostic = slot == NULL ?
        (ube_gc_shutdown ? "library is shut down" : "") : slot->text;
    const size_t length = strlen(diagnostic);
    if (required == NULL) {
        ube_gc_leave_lock();
        return 1;
    }
    *required = (uint64_t)length + 1u;
    if (buffer == NULL) {
        const int32_t status = capacity == 0 ? 0 : 1;
        ube_gc_leave_lock();
        return status;
    }
    if (capacity < (uint64_t)length + 1u) {
        ube_gc_leave_lock();
        return 1;
    }
    memcpy(buffer, diagnostic, length + 1);
    ube_gc_leave_lock();
    return 0;
}

static struct ube_string_allocation* ube_string_allocations;
static int ube_string_cleanup_registered;
static struct ube_legacy_allocation* ube_legacy_allocations;
static int ube_legacy_cleanup_registered;
static int ube_argument_count;
static char** ube_arguments;

static size_t ube_gc_hash_value(const void* value) {
    uintptr_t bits = (uintptr_t)value;
    bits ^= bits >> 17;
    bits ^= bits >> 9;
    return (size_t)(bits & (UBE_GC_HASH_BUCKETS - 1u));
}

static struct ube_gc_header* ube_gc_header_from_value(void* value) {
    if (value == NULL) return NULL;
    for (struct ube_gc_header* header = ube_gc_allocation_hash[ube_gc_hash_value(value)];
         header != NULL; header = header->hash_next) {
        if (header->magic == UBE_GC_MAGIC && (void*)header->data == value) {
            return header;
        }
    }
    return NULL;
}

static void ube_gc_hash_insert(struct ube_gc_header* header) {
    const size_t bucket = ube_gc_hash_value(header->data);
    header->hash_next = ube_gc_allocation_hash[bucket];
    ube_gc_allocation_hash[bucket] = header;
}

static void ube_gc_hash_remove(struct ube_gc_header* header) {
    const size_t bucket = ube_gc_hash_value(header->data);
    struct ube_gc_header** link = &ube_gc_allocation_hash[bucket];
    while (*link != NULL) {
        if (*link == header) {
            *link = header->hash_next;
            header->hash_next = NULL;
            return;
        }
        link = &(*link)->hash_next;
    }
}

static int ube_gc_grow_worklist(struct ube_gc_header*** items,
                                size_t* capacity, size_t required) {
    if (required <= *capacity) return 1;
    size_t next = *capacity == 0 ? 64 : *capacity;
    while (next < required) {
        if (next > SIZE_MAX / 2) return 0;
        next *= 2;
    }
    if (next > SIZE_MAX / sizeof(**items)) return 0;
    if (ube_gc_test_trace_failures != 0) {
        ube_gc_test_trace_failures -= 1;
        return 0;
    }
    void* resized = realloc(*items, next * sizeof(**items));
    if (resized == NULL) return 0;
    *items = resized;
    *capacity = next;
    return 1;
}

static int ube_gc_push_value(void* value, struct ube_gc_header*** items,
                             size_t* count, size_t* capacity) {
    struct ube_gc_header* header = ube_gc_header_from_value(value);
    if (header == NULL || header->marked) return 1;
    if (!ube_gc_grow_worklist(items, capacity, *count + 1)) return 0;
    header->marked = 1;
    (*items)[*count] = header;
    *count += 1;
    return 1;
}

static int ube_gc_mark_roots(void) {
    struct ube_gc_header** work = NULL;
    size_t count = 0;
    size_t capacity = 0;
    for (struct ube_gc_header* header = ube_gc_allocations;
         header != NULL; header = header->next) {
        if ((header->pending_publication || header->pin_count != 0) &&
            !ube_gc_push_value(header->data, &work, &count, &capacity)) {
            free(work);
            return 0;
        }
    }
    for (struct ube_gc_root* root = ube_gc_roots; root != NULL; root = root->next) {
        if (root->slot != NULL) {
            if (root->slot_count <= 1 && root->slot_offsets == NULL) {
                if (!ube_gc_push_value(__atomic_load_n(root->slot, __ATOMIC_SEQ_CST), &work, &count, &capacity)) {
                    free(work);
                    return 0;
                }
            } else {
                const unsigned char* base = (const unsigned char*)root->slot;
                for (size_t index = 0; index < root->slot_count; ++index) {
                    void* child = NULL;
                    child = __atomic_load_n((void* const*)(base + root->slot_offsets[index]), __ATOMIC_SEQ_CST);
                    if (!ube_gc_push_value(child, &work, &count, &capacity)) {
                        free(work);
                        return 0;
                    }
                }
            }
        }
    }
    for (size_t index = 0; index < ube_object_lease_count; ++index) {
        if (ube_object_leases[index].leases != 0 &&
            !ube_gc_push_value(ube_object_leases[index].object, &work, &count, &capacity)) {
            free(work);
            return 0;
        }
    }
    while (count != 0) {
        struct ube_gc_header* header = work[--count];
        if (header->element_layout != NULL) {
            const struct ube_value_layout* element = header->element_layout;
            for (size_t item = 0; item < header->element_count; ++item) {
                for (size_t slot = 0; slot < element->root_count; ++slot) {
                    const size_t offset = sizeof(struct ube_array) + item * element->size + element->root_offsets[slot];
                    if (offset > header->payload_size || header->payload_size - offset < sizeof(void*)) {
                        free(work);
                        return 0;
                    }
                    void* const* reference = __builtin_assume_aligned(header->data + offset, sizeof(void*));
                    void* child = __atomic_load_n(reference, __ATOMIC_SEQ_CST);
                    if (!ube_gc_push_value(child, &work, &count, &capacity)) {
                        free(work);
                        return 0;
                    }
                }
            }
        }
        const struct ube_gc_layout* layout = header->layout;
        if (layout == NULL) continue;
        for (size_t index = 0; index < layout->slot_count; ++index) {
            const size_t offset = layout->slot_offsets[index];
            if (offset > layout->size || layout->size - offset < sizeof(void*)) {
                free(work);
                return 0;
            }
            void* child = NULL;
            memcpy(&child, header->data + offset, sizeof(child));
            if (!ube_gc_push_value(child, &work, &count, &capacity)) {
                free(work);
                return 0;
            }
        }
    }
    free(work);
    return 1;
}

/* An incomplete mark pass cannot justify either finalization or sweeping.
   Automatic allocation recovery is opportunistic and preserves the caller's
   error record; an explicitly requested collection reports its fresh failure. */
static int32_t ube_gc_collect_internal(int report_failure) {
    ube_gc_enter_lock();
    if (ube_gc_collecting) {
        ube_gc_leave_lock();
        return 0;
    }
    ube_gc_collecting = 1;
    for (struct ube_gc_header* item = ube_gc_allocations; item != NULL; item = item->next) {
        item->marked = 0;
    }
    if (!ube_gc_mark_roots()) {
        for (struct ube_gc_header* item = ube_gc_allocations; item != NULL; item = item->next) {
            item->marked = 0;
        }
        ube_gc_collecting = 0;
        ube_gc_leave_lock();
        if (report_failure) {
            ube_err_set(7, "insufficient bookkeeping memory while tracing", "UBE.Memory");
        }
        return 0;
    }

    int32_t performed = 0;
    for (struct ube_gc_header* item = ube_gc_allocations; item != NULL; item = item->next) {
        if (!item->marked && !item->finalized && item->layout != NULL &&
            item->layout->finalizer != NULL) {
            item->finalizing = 1;
            item->layout->finalizer(item->data);
            item->finalizing = 0;
            item->finalized = 1;
            item->marked = 1;
            performed = 1;
        }
    }

    struct ube_gc_header** link = &ube_gc_allocations;
    while (*link != NULL) {
        struct ube_gc_header* item = *link;
        if (!item->marked && (item->layout == NULL || item->layout->finalizer == NULL || item->finalized)) {
            *link = item->next;
            if (item->payload_size <= ube_gc_live_bytes) {
                ube_gc_live_bytes -= item->payload_size;
            }
            ube_gc_hash_remove(item);
            item->magic = 0;
            if (item->monitor_initialized) DeleteCriticalSection(&item->monitor);
            if (item->owns_layout) free((void*)item->layout);
            free(item);
            performed = 1;
        } else {
            link = &item->next;
        }
    }
    size_t next_threshold = ube_gc_live_bytes > SIZE_MAX / 2
        ? SIZE_MAX : ube_gc_live_bytes * 2;
    if (next_threshold < UBE_GC_INITIAL_THRESHOLD) next_threshold = UBE_GC_INITIAL_THRESHOLD;
    ube_gc_threshold = next_threshold;
    ube_gc_collecting = 0;
    ube_gc_leave_lock();
    return performed;
}

int32_t ube_gc_collect(void) {
    return ube_gc_collect_internal(1);
}

int32_t ube_gc_safe_point(void) {
    ube_gc_enter_lock();
    const int should_collect = !ube_gc_collecting && !ube_gc_shutdown &&
        ube_gc_live_bytes >= ube_gc_threshold;
    ube_gc_leave_lock();
    if (!should_collect) return 0;
    return ube_gc_collect_internal(0);
}

void* ube_gc_allocate(const struct ube_gc_layout* layout) {
    if (layout == NULL || layout->size > SIZE_MAX - sizeof(struct ube_gc_header)) return NULL;
    ube_gc_enter_lock();
    if (!ube_gc_cleanup_registered) {
        if (atexit(ube_gc_release_all) != 0) {
            ube_gc_leave_lock();
            return NULL;
        }
        ube_gc_cleanup_registered = 1;
    }
    if (!ube_gc_collecting && (ube_gc_live_bytes > ube_gc_threshold ||
        layout->size > ube_gc_threshold - ube_gc_live_bytes)) {
        (void)ube_gc_collect_internal(0);
    }
    struct ube_gc_header* header = NULL;
    if (ube_gc_test_allocation_failures != 0) {
        ube_gc_test_allocation_failures -= 1;
    } else {
        header = calloc(1, sizeof(*header) + layout->size);
    }
    if (header == NULL) {
        (void)ube_gc_collect_internal(0);
        if (ube_gc_test_allocation_failures != 0) {
            ube_gc_test_allocation_failures -= 1;
        } else {
            header = calloc(1, sizeof(*header) + layout->size);
        }
        if (header == NULL) {
            ube_gc_leave_lock();
            return NULL;
        }
    }
    header->next = ube_gc_allocations;
    header->layout = layout;
    header->payload_size = layout->size;
    header->magic = UBE_GC_MAGIC;
    InitializeCriticalSection(&header->monitor);
    header->monitor_initialized = 1;
    ube_gc_allocations = header;
    ube_gc_hash_insert(header);
    ube_gc_live_bytes += layout->size;
    ube_gc_leave_lock();
    return header->data;
}

void* ube_gc_allocate_into(const struct ube_gc_layout* layout, void** slot) {
    if (slot == NULL) return NULL;
    ube_gc_enter_lock();
    void* value = ube_gc_allocate(layout);
    if (value != NULL) *slot = value;
    ube_gc_leave_lock();
    return value;
}

static void* ube_gc_allocate_pending(const struct ube_gc_layout* layout) {
    ube_gc_enter_lock();
    void* value = ube_gc_allocate(layout);
    struct ube_gc_header* header = ube_gc_header_from_value(value);
    if (header != NULL) header->pending_publication = 1;
    ube_gc_leave_lock();
    return value;
}

static void* ube_gc_allocate_untraced_pending(size_t size) {
    if (size > SIZE_MAX - sizeof(struct ube_gc_header)) return NULL;
    ube_gc_enter_lock();
    if (!ube_gc_cleanup_registered) {
        if (atexit(ube_gc_release_all) != 0) {
            ube_gc_leave_lock();
            return NULL;
        }
        ube_gc_cleanup_registered = 1;
    }
    if (!ube_gc_collecting && (ube_gc_live_bytes > ube_gc_threshold ||
        size > ube_gc_threshold - ube_gc_live_bytes)) {
        (void)ube_gc_collect_internal(0);
    }
    struct ube_gc_header* header = NULL;
    if (ube_gc_test_allocation_failures != 0) {
        ube_gc_test_allocation_failures -= 1;
    } else {
        header = calloc(1, sizeof(*header) + size);
    }
    if (header == NULL) {
        (void)ube_gc_collect_internal(0);
        if (ube_gc_test_allocation_failures != 0) {
            ube_gc_test_allocation_failures -= 1;
        } else {
            header = calloc(1, sizeof(*header) + size);
        }
        if (header == NULL) {
            ube_gc_leave_lock();
            return NULL;
        }
    }
    header->next = ube_gc_allocations;
    header->layout = NULL;
    header->payload_size = size;
    header->magic = UBE_GC_MAGIC;
    header->pending_publication = 1;
    InitializeCriticalSection(&header->monitor);
    header->monitor_initialized = 1;
    ube_gc_allocations = header;
    ube_gc_hash_insert(header);
    ube_gc_live_bytes += size;
    ube_gc_leave_lock();
    return header->data;
}

static void* ube_gc_allocate_dynamic(size_t size, size_t slot_count,
                                     const size_t* slot_offsets) {
    if (slot_count > (SIZE_MAX - sizeof(struct ube_gc_layout)) / sizeof(size_t)) {
        return NULL;
    }
    const size_t layout_size = sizeof(struct ube_gc_layout) + slot_count * sizeof(size_t);
    struct ube_gc_layout* layout = malloc(layout_size);
    if (layout == NULL) return NULL;
    size_t* copied_offsets = (size_t*)(layout + 1);
    if (slot_count != 0) memcpy(copied_offsets, slot_offsets, slot_count * sizeof(size_t));
    layout->size = size;
    layout->slot_count = slot_count;
    layout->slot_offsets = slot_count == 0 ? NULL : copied_offsets;
    layout->finalizer = NULL;
    void* value = ube_gc_allocate(layout);
    if (value == NULL) {
        free(layout);
        return NULL;
    }
    struct ube_gc_header* header = ube_gc_header_from_value(value);
    if (header == NULL) {
        free(layout);
        return NULL;
    }
    header->owns_layout = 1;
    return value;
}

int32_t ube_gc_publish(void* value) {
    if (value == NULL) return 1;
    ube_gc_enter_lock();
    struct ube_gc_header* header = ube_gc_header_from_value(value);
    if (header == NULL) {
        ube_gc_leave_lock();
        return 0;
    }
    header->pending_publication = 0;
    ube_gc_leave_lock();
    return 1;
}

int32_t ube_gc_pin(void* value) {
    if (value == NULL) return 0;
    ube_gc_enter_lock();
    struct ube_gc_header* header = ube_gc_header_from_value(value);
    if (header == NULL || header->pin_count == UINT32_MAX || header->finalizing) {
        ube_gc_leave_lock();
        return 0;
    }
    header->pending_publication = 0;
    header->pin_count += 1;
    ube_gc_leave_lock();
    return 1;
}

int32_t ube_gc_unpin(void* value) {
    if (value == NULL) return 0;
    ube_gc_enter_lock();
    struct ube_gc_header* header = ube_gc_header_from_value(value);
    if (header == NULL || header->pin_count == 0) {
        ube_gc_leave_lock();
        return 0;
    }
    header->pin_count -= 1;
    ube_gc_leave_lock();
    return 1;
}

int32_t ube_component_begin_load(void* value, int32_t kind) {
    if (value == NULL) {
        ube_err_set(91, "Load target is Nothing", "UBE.Components");
        return 0;
    }
    ube_gc_enter_lock();
    struct ube_gc_header* header = ube_gc_header_from_value(value);
    if (header == NULL) {
        ube_gc_leave_lock();
        ube_err_set(91, "Load target is not a live managed component", "UBE.Components");
        return 0;
    }
    struct ube_component_state* item = ube_components;
    while (item != NULL && item->object != value) item = item->next;
    if (item != NULL) {
        const int32_t result = item->state == 2 ? 2 : 0;
        ube_gc_leave_lock();
        if (result == 0) {
            ube_err_set(91, "component is loading or unloading", "UBE.Components");
        }
        return result;
    }
    if (kind == 52) {
        struct ube_component_parent* parent_link = ube_component_parents;
        while (parent_link != NULL && parent_link->child != value) {
            parent_link = parent_link->next;
        }
        struct ube_component_state* parent_state = ube_components;
        while (parent_link != NULL && parent_state != NULL &&
               parent_state->object != parent_link->parent) {
            parent_state = parent_state->next;
        }
        if (parent_link == NULL || parent_state == NULL ||
            parent_state->state != 2) {
            ube_gc_leave_lock();
            ube_err_set(91, "control has no loaded parent context", "UBE.Components");
            return 0;
        }
    }
    item = calloc(1, sizeof(*item));
    if (item == NULL || header->pin_count == UINT32_MAX) {
        free(item);
        ube_gc_leave_lock();
        ube_err_set(7, "component load bookkeeping failed", "UBE.Components");
        return 0;
    }
    ++header->pin_count;
    item->object = value;
    item->kind = kind;
    item->state = 1;
    item->load_error_revision = ube_current_error_state()->revision;
    item->next = ube_components;
    ube_components = item;
    ube_gc_leave_lock();
    return 1;
}

/* Framework/designer adapter used before loading a control identity. */
int32_t ube_component_attach_parent(void* child, void* parent) {
    if (child == NULL || parent == NULL) {
        ube_err_set(91, "control parent context is invalid", "UBE.Components");
        return 0;
    }
    ube_gc_enter_lock();
    if (ube_gc_header_from_value(child) == NULL ||
        ube_gc_header_from_value(parent) == NULL) {
        ube_gc_leave_lock();
        ube_err_set(91, "control parent context is not live", "UBE.Components");
        return 0;
    }
    struct ube_component_parent* item = ube_component_parents;
    while (item != NULL && item->child != child) item = item->next;
    if (item == NULL) {
        item = calloc(1u, sizeof(*item));
        if (item == NULL) {
            ube_gc_leave_lock();
            ube_err_set(7, "control parent bookkeeping failed", "UBE.Components");
            return 0;
        }
        item->child = child;
        item->next = ube_component_parents;
        ube_component_parents = item;
    }
    item->parent = parent;
    ube_gc_leave_lock();
    return 1;
}

int32_t ube_component_finish_load(void* value, int32_t succeeded) {
    int32_t result = 0;
    ube_gc_enter_lock();
    struct ube_component_state** link = &ube_components;
    while (*link != NULL && (*link)->object != value) link = &(*link)->next;
    if (*link != NULL && (*link)->state == 1) {
        const struct ube_error_state* error = ube_current_error_state();
        const int hook_failed = succeeded &&
            error->revision != (*link)->load_error_revision && error->number != 0;
        if (succeeded && !hook_failed) {
            (*link)->state = 2;
            if (ube_active_event_sources == 0 &&
                ube_component_sources_done != NULL) {
                ResetEvent(ube_component_sources_done);
            }
            ++ube_active_event_sources;
            result = 1;
        } else {
            struct ube_component_state* removed = *link;
            *link = removed->next;
            struct ube_gc_header* header = ube_gc_header_from_value(value);
            if (header != NULL && header->pin_count != 0) --header->pin_count;
            free(removed);
        }
    }
    ube_gc_leave_lock();
    return result;
}

static void ube_component_clear_aliases_locked(void* value) {
    struct ube_component_parent** parent_link = &ube_component_parents;
    while (*parent_link != NULL) {
        if ((*parent_link)->child == value || (*parent_link)->parent == value) {
            struct ube_component_parent* removed = *parent_link;
            *parent_link = removed->next;
            free(removed);
        } else {
            parent_link = &(*parent_link)->next;
        }
    }
    for (struct ube_default_form_slot* item = ube_default_form_slots;
         item != NULL; item = item->next) {
        if (item->slot != NULL && *item->slot == value) item->tombstone = 1;
    }
    for (struct ube_gc_root* root = ube_gc_roots; root != NULL; root = root->next) {
        if (root->slot == NULL) continue;
        if (root->slot_count <= 1 && root->slot_offsets == NULL) {
            if (*root->slot == value) *root->slot = NULL;
        } else {
            unsigned char* base = (unsigned char*)root->slot;
            for (size_t index = 0; index < root->slot_count; ++index) {
                void** slot = (void**)(base + root->slot_offsets[index]);
                if (*slot == value) *slot = NULL;
            }
        }
    }
    for (struct ube_gc_header* header = ube_gc_allocations;
         header != NULL; header = header->next) {
        if (header->layout == NULL) continue;
        for (size_t index = 0; index < header->layout->slot_count; ++index) {
            void** slot = (void**)(header->data + header->layout->slot_offsets[index]);
            if (*slot == value) *slot = NULL;
        }
    }
    for (size_t index = 0; index < ube_object_lease_count; ++index) {
        if (ube_object_leases[index].object == value) {
            ube_object_leases[index].object = NULL;
            ube_object_leases[index].leases = 0;
            ++ube_object_leases[index].generation;
            if (ube_object_leases[index].generation == 0) {
                ube_object_leases[index].generation = 1;
            }
        }
    }
}

static void ube_component_finalize_unload_locked(
    struct ube_component_state** link) {
    struct ube_component_state* removed = *link;
    void* value = removed->object;
    *link = removed->next;
    if (ube_active_event_sources != 0) {
        --ube_active_event_sources;
        if (ube_active_event_sources == 0 &&
            ube_component_sources_done != NULL) {
            SetEvent(ube_component_sources_done);
        }
    }
    struct ube_gc_header* header = ube_gc_header_from_value(value);
    if (header != NULL && header->pin_count != 0) --header->pin_count;
    ube_component_clear_aliases_locked(value);
    free(removed);
}

int32_t ube_component_enter_call(void* value) {
    if (value == NULL) {
        ube_err_set(91, "component call target is Nothing", "UBE.Components");
        return 0;
    }
    int32_t admitted = 0;
    ube_gc_enter_lock();
    struct ube_component_state* item = ube_components;
    while (item != NULL && item->object != value) item = item->next;
    if (item != NULL && item->state == 2 && item->active_calls != UINT32_MAX) {
        ++item->active_calls;
        admitted = 1;
    }
    ube_gc_leave_lock();
    if (!admitted) {
        ube_err_set(91, "component is not accepting procedure calls", "UBE.Components");
    }
    return admitted;
}

void ube_component_leave_call(void* value) {
    if (value == NULL) return;
    ube_gc_enter_lock();
    struct ube_component_state** link = &ube_components;
    while (*link != NULL && (*link)->object != value) link = &(*link)->next;
    if (*link != NULL && (*link)->active_calls != 0) {
        --(*link)->active_calls;
        if ((*link)->state == 3 && (*link)->active_calls == 0) {
            ube_component_finalize_unload_locked(link);
        }
    }
    ube_gc_leave_lock();
}

int32_t ube_component_accept_unload(void* value) {
    if (value == NULL) return 1;
    ube_gc_enter_lock();
    struct ube_component_state** link = &ube_components;
    while (*link != NULL && (*link)->object != value) link = &(*link)->next;
    if (*link == NULL || (*link)->state != 2) {
        ube_gc_leave_lock();
        return 1;
    }
    (*link)->state = 3;
    ube_gc_leave_lock();
    ube_event_disconnect_identity(value);
    ube_gc_enter_lock();
    link = &ube_components;
    while (*link != NULL && (*link)->object != value) link = &(*link)->next;
    if (*link != NULL && (*link)->state == 3 && (*link)->active_calls == 0) {
        ube_component_finalize_unload_locked(link);
    }
    ube_gc_leave_lock();
    return 1;
}

/* Acquires the reentrant synchronization identity carried by a managed
   object. Pinning before the potentially blocking host call prevents the
   collector from reclaiming either an owner or a waiter. */
static struct ube_monitor_tracking* ube_monitor_tracking_find(
    struct ube_thread_local_state* state, void* value, int create) {
    struct ube_monitor_tracking* available = NULL;
    if (state == NULL || value == NULL) return NULL;
    for (size_t index = 0u; index < UBE_MONITOR_TRACKING_CAPACITY; ++index) {
        struct ube_monitor_tracking* entry = &state->monitors[index];
        if (entry->object == value) return entry;
        if (available == NULL && entry->object == NULL &&
            entry->held_count == 0u && entry->released_for_error == 0u) {
            available = entry;
        }
    }
    if (create && available != NULL) available->object = value;
    return create ? available : NULL;
}

static CRITICAL_SECTION* ube_monitor_for_object(void* value) {
    CRITICAL_SECTION* monitor = NULL;
    ube_gc_enter_lock();
    struct ube_gc_header* header = ube_gc_header_from_value(value);
    if (header != NULL && header->monitor_initialized) {
        monitor = &header->monitor;
    }
    ube_gc_leave_lock();
    return monitor;
}

static void ube_monitor_tracking_clear_if_unused(
    struct ube_monitor_tracking* entry) {
    if (entry != NULL && entry->held_count == 0u &&
        entry->released_for_error == 0u) {
        entry->object = NULL;
    }
}

int32_t ube_monitor_enter(void* value) {
    if (value == NULL) {
        ube_err_set(91, "SyncLock object is Nothing", "UBE.SyncLock");
        return 0;
    }
    struct ube_thread_local_state* state = ube_tls_get(1);
    struct ube_monitor_tracking* tracking =
        ube_monitor_tracking_find(state, value, 1);
    if (tracking == NULL || tracking->held_count == UINT32_MAX) {
        ube_err_set(7, "SyncLock ownership capacity exhausted", "UBE.SyncLock");
        return 0;
    }
    if (!ube_gc_pin(value)) {
        ube_monitor_tracking_clear_if_unused(tracking);
        ube_err_set(91, "SyncLock object is invalid", "UBE.SyncLock");
        return 0;
    }
    CRITICAL_SECTION* monitor = ube_monitor_for_object(value);
    if (monitor == NULL) {
        (void)ube_gc_unpin(value);
        ube_monitor_tracking_clear_if_unused(tracking);
        ube_err_set(91, "SyncLock object is invalid", "UBE.SyncLock");
        return 0;
    }
    EnterCriticalSection(monitor);
    tracking->held_count += 1u;
    return 1;
}

/* Releases one reentrant monitor level and the matching collector pin. */
void ube_monitor_exit(void* value) {
    if (value == NULL) return;
    struct ube_monitor_tracking* tracking =
        ube_monitor_tracking_find(ube_tls_get(0), value, 0);
    if (tracking == NULL) return;
    if (tracking->held_count > 0u) {
        CRITICAL_SECTION* monitor = ube_monitor_for_object(value);
        if (monitor == NULL) return;
        tracking->held_count -= 1u;
        LeaveCriticalSection(monitor);
        (void)ube_gc_unpin(value);
    } else if (tracking->released_for_error > 0u) {
        tracking->released_for_error -= 1u;
    }
    ube_monitor_tracking_clear_if_unused(tracking);
}

/* Temporarily releases one compiler-owned monitor level before transferring
   control to an On Error handler. */
void ube_monitor_error_release(void* value) {
    if (value == NULL) return;
    struct ube_monitor_tracking* tracking =
        ube_monitor_tracking_find(ube_tls_get(0), value, 0);
    if (tracking == NULL || tracking->held_count == 0u ||
        tracking->released_for_error == UINT32_MAX) return;
    CRITICAL_SECTION* monitor = ube_monitor_for_object(value);
    if (monitor == NULL) return;
    tracking->held_count -= 1u;
    tracking->released_for_error += 1u;
    LeaveCriticalSection(monitor);
    (void)ube_gc_unpin(value);
}

/* Reacquires one monitor level when Resume or Resume Next returns to the
   protected statement. Resume <label> deliberately abandons released levels. */
void ube_monitor_error_resume(void* value) {
    if (value == NULL) return;
    struct ube_monitor_tracking* tracking =
        ube_monitor_tracking_find(ube_tls_get(0), value, 0);
    if (tracking == NULL || tracking->released_for_error == 0u ||
        tracking->held_count == UINT32_MAX) return;
    if (!ube_gc_pin(value)) {
        ube_err_set(91, "SyncLock object is invalid", "UBE.SyncLock");
        return;
    }
    CRITICAL_SECTION* monitor = ube_monitor_for_object(value);
    if (monitor == NULL) {
        (void)ube_gc_unpin(value);
        ube_err_set(91, "SyncLock object is invalid", "UBE.SyncLock");
        return;
    }
    EnterCriticalSection(monitor);
    tracking->released_for_error -= 1u;
    tracking->held_count += 1u;
}

/* Releases a monitor recorded in compiler-owned cleanup storage and clears the
   slot so converging return/error paths cannot release it twice. */
void ube_monitor_exit_storage(void** slot) {
    if (slot == NULL || *slot == NULL) return;
    void* value = *slot;
    *slot = NULL;
    ube_monitor_exit(value);
}

typedef struct ube_atomic_i32_state {
    volatile LONG value;
} ube_atomic_i32_state;

typedef struct ube_atomic_i64_state {
    volatile LONG64 value;
} ube_atomic_i64_state;

int64_t ube_atomic_i32_create(int32_t initial_value) {
    ube_atomic_i32_state* state = (ube_atomic_i32_state*)calloc(1u, sizeof(*state));
    if (state == NULL) {
        ube_err_set(7, NULL, NULL);
        return 0;
    }
    InterlockedExchange(&state->value, (LONG)initial_value);
    return (int64_t)(intptr_t)state;
}

void ube_atomic_i32_destroy(int64_t handle) {
    if (handle != 0) free((void*)(intptr_t)handle);
}

int32_t ube_atomic_i32_load(int64_t handle) {
    ube_atomic_i32_state* state = (ube_atomic_i32_state*)(intptr_t)handle;
    if (state == NULL) {
        ube_err_set(91, NULL, NULL);
        return 0;
    }
    return (int32_t)InterlockedCompareExchange(&state->value, 0, 0);
}

int32_t ube_atomic_i32_store(int64_t handle, int32_t value) {
    ube_atomic_i32_state* state = (ube_atomic_i32_state*)(intptr_t)handle;
    if (state == NULL) {
        ube_err_set(91, NULL, NULL);
        return 0;
    }
    InterlockedExchange(&state->value, (LONG)value);
    return 1;
}

int32_t ube_atomic_i32_exchange(int64_t handle, int32_t value) {
    ube_atomic_i32_state* state = (ube_atomic_i32_state*)(intptr_t)handle;
    if (state == NULL) {
        ube_err_set(91, NULL, NULL);
        return 0;
    }
    return (int32_t)InterlockedExchange(&state->value, (LONG)value);
}

int32_t ube_atomic_i32_compare_exchange(int64_t handle, int32_t expected, int32_t replacement) {
    ube_atomic_i32_state* state = (ube_atomic_i32_state*)(intptr_t)handle;
    if (state == NULL) {
        ube_err_set(91, NULL, NULL);
        return 0;
    }
    return (int32_t)InterlockedCompareExchange(&state->value, (LONG)replacement, (LONG)expected);
}

int32_t ube_atomic_i32_add(int64_t handle, int32_t delta) {
    ube_atomic_i32_state* state = (ube_atomic_i32_state*)(intptr_t)handle;
    if (state == NULL) {
        ube_err_set(91, NULL, NULL);
        return 0;
    }
    return (int32_t)(InterlockedExchangeAdd(&state->value, (LONG)delta) + delta);
}

int64_t ube_atomic_i64_create(int64_t initial_value) {
    ube_atomic_i64_state* state = (ube_atomic_i64_state*)calloc(1u, sizeof(*state));
    if (state == NULL) {
        ube_err_set(7, NULL, NULL);
        return 0;
    }
    InterlockedExchange64(&state->value, (LONG64)initial_value);
    return (int64_t)(intptr_t)state;
}

void ube_atomic_i64_destroy(int64_t handle) {
    if (handle != 0) free((void*)(intptr_t)handle);
}

int64_t ube_atomic_i64_load(int64_t handle) {
    ube_atomic_i64_state* state = (ube_atomic_i64_state*)(intptr_t)handle;
    if (state == NULL) {
        ube_err_set(91, NULL, NULL);
        return 0;
    }
    return (int64_t)InterlockedCompareExchange64(&state->value, 0, 0);
}

int32_t ube_atomic_i64_store(int64_t handle, int64_t value) {
    ube_atomic_i64_state* state = (ube_atomic_i64_state*)(intptr_t)handle;
    if (state == NULL) {
        ube_err_set(91, NULL, NULL);
        return 0;
    }
    InterlockedExchange64(&state->value, (LONG64)value);
    return 1;
}

int64_t ube_atomic_i64_exchange(int64_t handle, int64_t value) {
    ube_atomic_i64_state* state = (ube_atomic_i64_state*)(intptr_t)handle;
    if (state == NULL) {
        ube_err_set(91, NULL, NULL);
        return 0;
    }
    return (int64_t)InterlockedExchange64(&state->value, (LONG64)value);
}

int64_t ube_atomic_i64_compare_exchange(int64_t handle, int64_t expected, int64_t replacement) {
    ube_atomic_i64_state* state = (ube_atomic_i64_state*)(intptr_t)handle;
    if (state == NULL) {
        ube_err_set(91, NULL, NULL);
        return 0;
    }
    return (int64_t)InterlockedCompareExchange64(&state->value, (LONG64)replacement, (LONG64)expected);
}

int64_t ube_atomic_i64_add(int64_t handle, int64_t delta) {
    ube_atomic_i64_state* state = (ube_atomic_i64_state*)(intptr_t)handle;
    if (state == NULL) {
        ube_err_set(91, NULL, NULL);
        return 0;
    }
    return (int64_t)(InterlockedExchangeAdd64(&state->value, (LONG64)delta) + delta);
}

struct ube_thread_event_state {
    CRITICAL_SECTION lock;
    HANDLE signal;
    HANDLE shutdown;
    HANDLE drained;
    LONG active_waiters;
    int unloading;
};

static HANDLE ube_current_stop_event(void) {
    struct ube_thread_local_state* state = ube_tls_get(0);
    return state != NULL && state->thread_record != NULL
        ? state->thread_record->stop_requested : NULL;
}

int64_t ube_thread_event_create(int32_t manual_reset, int32_t initially_signaled) {
    struct ube_thread_event_state* state = calloc(1u, sizeof(*state));
    if (state == NULL) {
        ube_err_set(7, "thread event allocation failed", "UBECore.ThreadEvent");
        return 0;
    }
    InitializeCriticalSection(&state->lock);
    state->signal = CreateEventA(NULL, manual_reset != 0, initially_signaled != 0, NULL);
    state->shutdown = CreateEventA(NULL, TRUE, FALSE, NULL);
    state->drained = CreateEventA(NULL, TRUE, TRUE, NULL);
    if (state->signal == NULL || state->shutdown == NULL || state->drained == NULL) {
        if (state->signal != NULL) CloseHandle(state->signal);
        if (state->shutdown != NULL) CloseHandle(state->shutdown);
        if (state->drained != NULL) CloseHandle(state->drained);
        DeleteCriticalSection(&state->lock);
        free(state);
        ube_err_set(7, "thread event creation failed", "UBECore.ThreadEvent");
        return 0;
    }
    return (int64_t)(intptr_t)state;
}

void ube_thread_event_destroy(int64_t handle) {
    struct ube_thread_event_state* state = (struct ube_thread_event_state*)(intptr_t)handle;
    if (state == NULL) return;
    EnterCriticalSection(&state->lock);
    state->unloading = 1;
    SetEvent(state->shutdown);
    const LONG waiters = state->active_waiters;
    LeaveCriticalSection(&state->lock);
    if (waiters > 0) WaitForSingleObject(state->drained, INFINITE);
    CloseHandle(state->signal);
    CloseHandle(state->shutdown);
    CloseHandle(state->drained);
    DeleteCriticalSection(&state->lock);
    free(state);
}

int32_t ube_thread_event_set(int64_t handle) {
    struct ube_thread_event_state* state = (struct ube_thread_event_state*)(intptr_t)handle;
    if (state == NULL) {
        ube_err_set(91, "thread event is not loaded", "UBECore.ThreadEvent");
        return 0;
    }
    EnterCriticalSection(&state->lock);
    const int allowed = !state->unloading;
    const int32_t result = allowed && SetEvent(state->signal) ? 1 : 0;
    LeaveCriticalSection(&state->lock);
    if (!allowed) ube_err_set(91, "thread event is unloading", "UBECore.ThreadEvent");
    else if (!result) ube_err_set(7, "thread event signal failed", "UBECore.ThreadEvent");
    return result;
}

int32_t ube_thread_event_reset(int64_t handle) {
    struct ube_thread_event_state* state = (struct ube_thread_event_state*)(intptr_t)handle;
    if (state == NULL) {
        ube_err_set(91, "thread event is not loaded", "UBECore.ThreadEvent");
        return 0;
    }
    EnterCriticalSection(&state->lock);
    const int allowed = !state->unloading;
    const int32_t result = allowed && ResetEvent(state->signal) ? 1 : 0;
    LeaveCriticalSection(&state->lock);
    if (!allowed) ube_err_set(91, "thread event is unloading", "UBECore.ThreadEvent");
    else if (!result) ube_err_set(7, "thread event reset failed", "UBECore.ThreadEvent");
    return result;
}

int32_t ube_thread_event_wait(int64_t handle, int64_t timeout_milliseconds) {
    struct ube_thread_event_state* state = (struct ube_thread_event_state*)(intptr_t)handle;
    if (state == NULL) {
        ube_err_set(91, "thread event is not loaded", "UBECore.ThreadEvent");
        return 0;
    }
    if (timeout_milliseconds < -1 || timeout_milliseconds > UINT32_MAX) {
        ube_err_set(5, "thread event timeout is invalid", "UBECore.ThreadEvent");
        return 0;
    }
    EnterCriticalSection(&state->lock);
    if (state->unloading) {
        LeaveCriticalSection(&state->lock);
        ube_err_set(91, "thread event is unloading", "UBECore.ThreadEvent");
        return 0;
    }
    if (state->active_waiters == 0) ResetEvent(state->drained);
    state->active_waiters += 1;
    LeaveCriticalSection(&state->lock);
    HANDLE waits[3] = { state->signal, state->shutdown, ube_current_stop_event() };
    const DWORD wait_count = waits[2] != NULL ? 3u : 2u;
    const DWORD timeout = timeout_milliseconds < 0 ? INFINITE : (DWORD)timeout_milliseconds;
    const DWORD wait_result = WaitForMultipleObjects(wait_count, waits, FALSE, timeout);
    EnterCriticalSection(&state->lock);
    state->active_waiters -= 1;
    if (state->active_waiters == 0) SetEvent(state->drained);
    LeaveCriticalSection(&state->lock);
    if (wait_result == WAIT_OBJECT_0) return 1;
    if (wait_result == WAIT_TIMEOUT || (wait_count == 3u && wait_result == WAIT_OBJECT_0 + 2)) return 0;
    if (wait_result == WAIT_OBJECT_0 + 1) {
        ube_err_set(91, "thread event was unloaded while waiting", "UBECore.ThreadEvent");
        return 0;
    }
    ube_err_set(7, "thread event wait failed", "UBECore.ThreadEvent");
    return 0;
}

struct ube_semaphore_waiter {
    struct ube_semaphore_waiter* next;
    HANDLE ready;
    int granted;
};

struct ube_semaphore_state {
    CRITICAL_SECTION lock;
    int64_t count;
    int64_t maximum;
    struct ube_semaphore_waiter* first;
    struct ube_semaphore_waiter* last;
    HANDLE drained;
    LONG active_waiters;
    int unloading;
};

int64_t ube_semaphore_create(int64_t initial_count, int64_t maximum_count) {
    if (initial_count < 0 || maximum_count <= 0 || initial_count > maximum_count) {
        ube_err_set(5, "semaphore bounds are invalid", "UBECore.Semaphore");
        return 0;
    }
    struct ube_semaphore_state* state = calloc(1u, sizeof(*state));
    if (state == NULL) {
        ube_err_set(7, "semaphore allocation failed", "UBECore.Semaphore");
        return 0;
    }
    InitializeCriticalSection(&state->lock);
    state->drained = CreateEventA(NULL, TRUE, TRUE, NULL);
    if (state->drained == NULL) {
        DeleteCriticalSection(&state->lock);
        free(state);
        ube_err_set(7, "semaphore creation failed", "UBECore.Semaphore");
        return 0;
    }
    state->count = initial_count;
    state->maximum = maximum_count;
    return (int64_t)(intptr_t)state;
}

void ube_semaphore_destroy(int64_t handle) {
    struct ube_semaphore_state* state = (struct ube_semaphore_state*)(intptr_t)handle;
    if (state == NULL) return;
    EnterCriticalSection(&state->lock);
    state->unloading = 1;
    struct ube_semaphore_waiter* waiter = state->first;
    while (waiter != NULL) {
        SetEvent(waiter->ready);
        waiter = waiter->next;
    }
    const LONG waiters = state->active_waiters;
    LeaveCriticalSection(&state->lock);
    if (waiters > 0) WaitForSingleObject(state->drained, INFINITE);
    CloseHandle(state->drained);
    DeleteCriticalSection(&state->lock);
    free(state);
}

static void ube_semaphore_remove_waiter(struct ube_semaphore_state* state,
                                        struct ube_semaphore_waiter* sought) {
    struct ube_semaphore_waiter** link = &state->first;
    while (*link != NULL) {
        if (*link == sought) {
            *link = sought->next;
            if (state->last == sought) {
                state->last = NULL;
                struct ube_semaphore_waiter* tail = state->first;
                while (tail != NULL && tail->next != NULL) tail = tail->next;
                state->last = tail;
            }
            sought->next = NULL;
            return;
        }
        link = &(*link)->next;
    }
}

int32_t ube_semaphore_wait(int64_t handle, int64_t timeout_milliseconds) {
    struct ube_semaphore_state* state = (struct ube_semaphore_state*)(intptr_t)handle;
    if (state == NULL) {
        ube_err_set(91, "semaphore is not loaded", "UBECore.Semaphore");
        return 0;
    }
    if (timeout_milliseconds < -1 || timeout_milliseconds > UINT32_MAX) {
        ube_err_set(5, "semaphore timeout is invalid", "UBECore.Semaphore");
        return 0;
    }
    struct ube_semaphore_waiter waiter = { 0 };
    waiter.ready = CreateEventA(NULL, FALSE, FALSE, NULL);
    if (waiter.ready == NULL) {
        ube_err_set(7, "semaphore waiter allocation failed", "UBECore.Semaphore");
        return 0;
    }
    EnterCriticalSection(&state->lock);
    if (state->unloading) {
        LeaveCriticalSection(&state->lock);
        CloseHandle(waiter.ready);
        ube_err_set(91, "semaphore is unloading", "UBECore.Semaphore");
        return 0;
    }
    if (state->count > 0 && state->first == NULL) {
        state->count -= 1;
        LeaveCriticalSection(&state->lock);
        CloseHandle(waiter.ready);
        return 1;
    }
    if (state->last == NULL) state->first = &waiter;
    else state->last->next = &waiter;
    state->last = &waiter;
    if (state->active_waiters == 0) ResetEvent(state->drained);
    state->active_waiters += 1;
    LeaveCriticalSection(&state->lock);
    HANDLE waits[2] = { waiter.ready, ube_current_stop_event() };
    const DWORD wait_count = waits[1] != NULL ? 2u : 1u;
    const DWORD timeout = timeout_milliseconds < 0 ? INFINITE : (DWORD)timeout_milliseconds;
    const DWORD wait_result = WaitForMultipleObjects(wait_count, waits, FALSE, timeout);
    EnterCriticalSection(&state->lock);
    const int granted = waiter.granted;
    const int unloading = state->unloading;
    if (!granted) ube_semaphore_remove_waiter(state, &waiter);
    state->active_waiters -= 1;
    if (state->active_waiters == 0) SetEvent(state->drained);
    LeaveCriticalSection(&state->lock);
    CloseHandle(waiter.ready);
    if (granted) return 1;
    if (unloading) {
        ube_err_set(91, "semaphore was unloaded while waiting", "UBECore.Semaphore");
        return 0;
    }
    if (wait_result == WAIT_TIMEOUT || (wait_count == 2u && wait_result == WAIT_OBJECT_0 + 1)) return 0;
    ube_err_set(7, "semaphore wait failed", "UBECore.Semaphore");
    return 0;
}

int32_t ube_semaphore_release(int64_t handle, int64_t release_count) {
    struct ube_semaphore_state* state = (struct ube_semaphore_state*)(intptr_t)handle;
    if (state == NULL) {
        ube_err_set(91, "semaphore is not loaded", "UBECore.Semaphore");
        return 0;
    }
    if (release_count <= 0) {
        ube_err_set(5, "semaphore release count must be positive", "UBECore.Semaphore");
        return 0;
    }
    EnterCriticalSection(&state->lock);
    if (state->unloading) {
        LeaveCriticalSection(&state->lock);
        ube_err_set(91, "semaphore is unloading", "UBECore.Semaphore");
        return 0;
    }
    int64_t queued = 0;
    struct ube_semaphore_waiter* scan = state->first;
    while (scan != NULL && queued < release_count) {
        queued += 1;
        scan = scan->next;
    }
    const int64_t remaining = release_count - queued;
    if (remaining > state->maximum - state->count) {
        LeaveCriticalSection(&state->lock);
        ube_err_set(5, "semaphore release exceeds its maximum", "UBECore.Semaphore");
        return 0;
    }
    int64_t granted = 0;
    while (granted < queued && state->first != NULL) {
        struct ube_semaphore_waiter* waiter = state->first;
        state->first = waiter->next;
        if (state->first == NULL) state->last = NULL;
        waiter->next = NULL;
        waiter->granted = 1;
        SetEvent(waiter->ready);
        granted += 1;
    }
    state->count += remaining;
    LeaveCriticalSection(&state->lock);
    return 1;
}

int32_t ube_semaphore_test_waiter_count(int64_t handle) {
    struct ube_semaphore_state* state = (struct ube_semaphore_state*)(intptr_t)handle;
    if (state == NULL) return -1;
    EnterCriticalSection(&state->lock);
    int32_t count = 0;
    struct ube_semaphore_waiter* waiter = state->first;
    while (waiter != NULL) {
        count += 1;
        waiter = waiter->next;
    }
    LeaveCriticalSection(&state->lock);
    return count;
}

struct ube_message_item {
    struct ube_message_item* next;
    void* value;
    struct ube_gc_root root;
};

struct ube_message_waiter {
    struct ube_message_waiter* next;
    HANDLE ready;
    int granted;
};

struct ube_message_queue_state {
    CRITICAL_SECTION lock;
    struct ube_message_item* first_item;
    struct ube_message_item* last_item;
    struct ube_message_waiter* first_waiter;
    struct ube_message_waiter* last_waiter;
    HANDLE drained;
    LONG active_waiters;
    int unloading;
};

/* These managed-value helpers are defined later in this bootstrap adapter. */
int32_t ube_gc_root_enter(void* root_storage, void** slot);
int32_t ube_gc_root_leave(void* root_storage);
int32_t ube_gc_publish(void* value);
int32_t ube_gc_write_barrier(void* owner, void** slot, void* value);
void* ube_variant_copy(const void* value);

struct ube_atomic_object_state {
    CRITICAL_SECTION lock;
    void* value;
    struct ube_gc_root root;
};

int64_t ube_atomic_object_create(void) {
    struct ube_atomic_object_state* state = calloc(1u, sizeof(*state));
    if (state == NULL) {
        ube_err_set(7, "atomic object allocation failed", "UBECore.AtomicObject");
        return 0;
    }
    InitializeCriticalSection(&state->lock);
    if (!ube_gc_root_enter(&state->root, &state->value)) {
        DeleteCriticalSection(&state->lock);
        free(state);
        ube_err_set(7, "atomic object root registration failed", "UBECore.AtomicObject");
        return 0;
    }
    return (int64_t)(intptr_t)state;
}

void ube_atomic_object_destroy(int64_t handle) {
    struct ube_atomic_object_state* state = (struct ube_atomic_object_state*)(intptr_t)handle;
    if (state == NULL) return;
    ube_gc_root_leave(&state->root);
    DeleteCriticalSection(&state->lock);
    free(state);
}

int32_t ube_atomic_object_load(int64_t handle, void** destination) {
    struct ube_atomic_object_state* state = (struct ube_atomic_object_state*)(intptr_t)handle;
    if (state == NULL || destination == NULL) {
        ube_err_set(91, "atomic object or destination is not available", "UBECore.AtomicObject");
        return 0;
    }
    EnterCriticalSection(&state->lock);
    const int32_t result = ube_gc_write_barrier(NULL, destination, state->value);
    LeaveCriticalSection(&state->lock);
    if (!result) ube_err_set(7, "atomic object load failed", "UBECore.AtomicObject");
    return result;
}

int32_t ube_atomic_object_store(int64_t handle, void* value) {
    struct ube_atomic_object_state* state = (struct ube_atomic_object_state*)(intptr_t)handle;
    if (state == NULL) {
        ube_err_set(91, "atomic object is not loaded", "UBECore.AtomicObject");
        return 0;
    }
    EnterCriticalSection(&state->lock);
    const int32_t result = ube_gc_write_barrier(NULL, &state->value, value);
    LeaveCriticalSection(&state->lock);
    if (!result) ube_err_set(7, "atomic object store failed", "UBECore.AtomicObject");
    return result;
}

int32_t ube_atomic_object_exchange(int64_t handle, void* value, void** observed) {
    struct ube_atomic_object_state* state = (struct ube_atomic_object_state*)(intptr_t)handle;
    if (state == NULL || observed == NULL) {
        ube_err_set(91, "atomic object or destination is not available", "UBECore.AtomicObject");
        return 0;
    }
    EnterCriticalSection(&state->lock);
    int32_t result = ube_gc_write_barrier(NULL, observed, state->value);
    if (result) result = ube_gc_write_barrier(NULL, &state->value, value);
    LeaveCriticalSection(&state->lock);
    if (!result) ube_err_set(7, "atomic object exchange failed", "UBECore.AtomicObject");
    return result;
}

int32_t ube_atomic_object_compare_exchange(int64_t handle, void* expected,
                                           void* replacement, void** observed) {
    struct ube_atomic_object_state* state = (struct ube_atomic_object_state*)(intptr_t)handle;
    if (state == NULL || observed == NULL) {
        ube_err_set(91, "atomic object or destination is not available", "UBECore.AtomicObject");
        return 0;
    }
    EnterCriticalSection(&state->lock);
    int32_t result = ube_gc_write_barrier(NULL, observed, state->value);
    if (result && state->value == expected)
        result = ube_gc_write_barrier(NULL, &state->value, replacement);
    LeaveCriticalSection(&state->lock);
    if (!result) ube_err_set(7, "atomic object comparison failed", "UBECore.AtomicObject");
    return result;
}

int64_t ube_message_queue_create(void) {
    struct ube_message_queue_state* state = calloc(1u, sizeof(*state));
    if (state == NULL) {
        ube_err_set(7, "message queue allocation failed", "UBECore.MessageQueue");
        return 0;
    }
    InitializeCriticalSection(&state->lock);
    state->drained = CreateEventA(NULL, TRUE, TRUE, NULL);
    if (state->drained == NULL) {
        DeleteCriticalSection(&state->lock);
        free(state);
        ube_err_set(7, "message queue creation failed", "UBECore.MessageQueue");
        return 0;
    }
    return (int64_t)(intptr_t)state;
}

void ube_message_queue_destroy(int64_t handle) {
    struct ube_message_queue_state* state = (struct ube_message_queue_state*)(intptr_t)handle;
    if (state == NULL) return;
    EnterCriticalSection(&state->lock);
    state->unloading = 1;
    struct ube_message_waiter* waiter = state->first_waiter;
    while (waiter != NULL) {
        SetEvent(waiter->ready);
        waiter = waiter->next;
    }
    const LONG waiters = state->active_waiters;
    LeaveCriticalSection(&state->lock);
    if (waiters > 0) WaitForSingleObject(state->drained, INFINITE);
    struct ube_message_item* item = state->first_item;
    while (item != NULL) {
        struct ube_message_item* next = item->next;
        ube_gc_root_leave(&item->root);
        free(item);
        item = next;
    }
    CloseHandle(state->drained);
    DeleteCriticalSection(&state->lock);
    free(state);
}

int32_t ube_message_queue_enqueue(int64_t handle, void* value) {
    struct ube_message_queue_state* state = (struct ube_message_queue_state*)(intptr_t)handle;
    if (state == NULL) {
        ube_err_set(91, "message queue is not loaded", "UBECore.MessageQueue");
        return 0;
    }
    void* copied = ube_variant_copy(value);
    if (copied == NULL) {
        ube_err_set(7, "message copy failed", "UBECore.MessageQueue");
        return 0;
    }
    struct ube_message_item* item = calloc(1u, sizeof(*item));
    if (item == NULL || !ube_gc_root_enter(&item->root, &item->value)) {
        free(item);
        ube_err_set(7, "message queue item allocation failed", "UBECore.MessageQueue");
        return 0;
    }
    item->value = copied;
    ube_gc_publish(copied);
    EnterCriticalSection(&state->lock);
    if (state->unloading) {
        LeaveCriticalSection(&state->lock);
        ube_gc_root_leave(&item->root);
        free(item);
        ube_err_set(91, "message queue is unloading", "UBECore.MessageQueue");
        return 0;
    }
    if (state->last_item == NULL) state->first_item = item;
    else state->last_item->next = item;
    state->last_item = item;
    if (state->first_waiter != NULL) {
        struct ube_message_waiter* selected = state->first_waiter;
        state->first_waiter = selected->next;
        if (state->first_waiter == NULL) state->last_waiter = NULL;
        selected->next = NULL;
        selected->granted = 1;
        SetEvent(selected->ready);
    }
    LeaveCriticalSection(&state->lock);
    return 1;
}

static void ube_message_queue_remove_waiter(struct ube_message_queue_state* state,
                                             struct ube_message_waiter* sought) {
    struct ube_message_waiter** link = &state->first_waiter;
    while (*link != NULL) {
        if (*link == sought) {
            *link = sought->next;
            if (state->last_waiter == sought) {
                state->last_waiter = NULL;
                struct ube_message_waiter* tail = state->first_waiter;
                while (tail != NULL && tail->next != NULL) tail = tail->next;
                state->last_waiter = tail;
            }
            sought->next = NULL;
            return;
        }
        link = &(*link)->next;
    }
}

int32_t ube_message_queue_dequeue(int64_t handle, void** destination,
                                  int64_t timeout_milliseconds) {
    struct ube_message_queue_state* state = (struct ube_message_queue_state*)(intptr_t)handle;
    if (state == NULL || destination == NULL) {
        ube_err_set(91, "message queue or destination is not available", "UBECore.MessageQueue");
        return 0;
    }
    if (timeout_milliseconds < -1 || timeout_milliseconds > UINT32_MAX) {
        ube_err_set(5, "message queue timeout is invalid", "UBECore.MessageQueue");
        return 0;
    }
    struct ube_message_waiter waiter = { 0 };
    waiter.ready = CreateEventA(NULL, FALSE, FALSE, NULL);
    if (waiter.ready == NULL) {
        ube_err_set(7, "message queue waiter allocation failed", "UBECore.MessageQueue");
        return 0;
    }
    struct ube_message_item* item = NULL;
    EnterCriticalSection(&state->lock);
    if (state->unloading) {
        LeaveCriticalSection(&state->lock);
        CloseHandle(waiter.ready);
        ube_err_set(91, "message queue is unloading", "UBECore.MessageQueue");
        return 0;
    }
    if (state->first_item != NULL && state->first_waiter == NULL) {
        item = state->first_item;
        state->first_item = item->next;
        if (state->first_item == NULL) state->last_item = NULL;
        item->next = NULL;
        LeaveCriticalSection(&state->lock);
    } else {
        if (state->last_waiter == NULL) state->first_waiter = &waiter;
        else state->last_waiter->next = &waiter;
        state->last_waiter = &waiter;
        if (state->active_waiters == 0) ResetEvent(state->drained);
        state->active_waiters += 1;
        LeaveCriticalSection(&state->lock);
        HANDLE waits[2] = { waiter.ready, ube_current_stop_event() };
        const DWORD wait_count = waits[1] != NULL ? 2u : 1u;
        const DWORD timeout = timeout_milliseconds < 0 ? INFINITE : (DWORD)timeout_milliseconds;
        const DWORD wait_result = WaitForMultipleObjects(wait_count, waits, FALSE, timeout);
        EnterCriticalSection(&state->lock);
        const int granted = waiter.granted;
        const int unloading = state->unloading;
        if (!granted) ube_message_queue_remove_waiter(state, &waiter);
        if (granted && state->first_item != NULL) {
            item = state->first_item;
            state->first_item = item->next;
            if (state->first_item == NULL) state->last_item = NULL;
            item->next = NULL;
        }
        state->active_waiters -= 1;
        if (state->active_waiters == 0) SetEvent(state->drained);
        LeaveCriticalSection(&state->lock);
        CloseHandle(waiter.ready);
        if (item == NULL) {
            if (unloading) ube_err_set(91, "message queue was unloaded while waiting", "UBECore.MessageQueue");
            else if (wait_result != WAIT_TIMEOUT && !(wait_count == 2u && wait_result == WAIT_OBJECT_0 + 1))
                ube_err_set(7, "message queue wait failed", "UBECore.MessageQueue");
            return 0;
        }
    }
    if (!ube_gc_write_barrier(NULL, destination, item->value)) {
        ube_gc_root_leave(&item->root);
        free(item);
        ube_err_set(7, "message destination update failed", "UBECore.MessageQueue");
        return 0;
    }
    ube_gc_root_leave(&item->root);
    free(item);
    return 1;
}

void ube_gc_test_fail_next_allocations(uint32_t count) {
    ube_gc_enter_lock();
    ube_gc_test_allocation_failures = count;
    ube_gc_leave_lock();
}

void ube_gc_test_set_threshold(size_t threshold) {
    ube_gc_enter_lock();
    ube_gc_threshold = threshold == 0 ? 1 : threshold;
    ube_gc_leave_lock();
}

void ube_gc_test_fail_next_trace_allocations(uint32_t count) {
    ube_gc_enter_lock();
    ube_gc_test_trace_failures = count;
    ube_gc_leave_lock();
}

int32_t ube_gc_root_enter(void* root_storage, void** slot) {
    ube_gc_enter_lock();
    if (root_storage == NULL || slot == NULL || ube_gc_shutdown ||
        ube_gc_root_count >= UBE_GC_MAX_ROOTS) {
        ube_gc_leave_lock();
        return 0;
    }
    struct ube_gc_root* root = root_storage;
    root->slot = slot;
    root->slot_count = 1;
    root->slot_offsets = NULL;
    struct ube_gc_header* rooted_header = ube_gc_header_from_value(*slot);
    if (rooted_header != NULL) rooted_header->pending_publication = 0;
    root->next = ube_gc_roots;
    ube_gc_roots = root;
    ube_gc_root_count += 1;
    ube_gc_leave_lock();
    return 1;
}

int32_t ube_gc_root_enter_layout(void* root_storage, void* base,
                                 size_t slot_count, const size_t* slot_offsets) {
    if (root_storage == NULL || base == NULL || slot_count == 0 ||
        slot_offsets == NULL) return 0;
    ube_gc_enter_lock();
    if (ube_gc_shutdown || ube_gc_root_count >= UBE_GC_MAX_ROOTS) {
        ube_gc_leave_lock();
        return 0;
    }
    struct ube_gc_root* root = root_storage;
    root->slot = (void**)base;
    root->slot_count = slot_count;
    root->slot_offsets = slot_offsets;
    root->next = ube_gc_roots;
    ube_gc_roots = root;
    ube_gc_root_count += 1;
    ube_gc_leave_lock();
    return 1;
}

int32_t ube_gc_root_leave(void* root_storage) {
    if (root_storage == NULL) return 0;
    ube_gc_enter_lock();
    struct ube_gc_root* sought = root_storage;
    struct ube_gc_root** link = &ube_gc_roots;
    while (*link != NULL) {
        if (*link == sought) {
            *link = sought->next;
            sought->next = NULL;
            sought->slot = NULL;
            sought->slot_count = 0;
            sought->slot_offsets = NULL;
            ube_gc_root_count -= 1;
            ube_gc_leave_lock();
            return 1;
        }
        link = &(*link)->next;
    }
    ube_gc_leave_lock();
    return 0;
}

struct ube_thread_capture {
    struct ube_gc_root root;
    int rooted;
    max_align_t alignment;
    unsigned char data[];
};

/* Allocates a compiler-described ByVal capture and publishes every managed
   slot as one aggregate root before a worker can become visible. */
void* ube_thread_capture_allocate(size_t size, size_t slot_count,
                                  const size_t* slot_offsets) {
    if (size > SIZE_MAX - sizeof(struct ube_thread_capture)) {
        ube_err_set(7, "thread capture is too large", "UBECore.Threads");
        return NULL;
    }
    struct ube_thread_capture* capture =
        calloc(1, sizeof(*capture) + size);
    if (capture == NULL) {
        ube_err_set(7, "thread capture allocation failed", "UBECore.Threads");
        return NULL;
    }
    if (slot_count != 0) {
        if (!ube_gc_root_enter_layout(&capture->root, capture->data,
                                      slot_count, slot_offsets)) {
            free(capture);
            ube_err_set(7, "thread capture root registration failed", "UBECore.Threads");
            return NULL;
        }
        capture->rooted = 1;
    }
    return capture->data;
}

/* Releases the aggregate roots and storage after the worker returns, or when
   native thread creation fails after ownership has transferred. */
void ube_thread_capture_destroy(void* data) {
    if (data == NULL) return;
    struct ube_thread_capture* capture =
        (struct ube_thread_capture*)((unsigned char*)data -
            offsetof(struct ube_thread_capture, data));
    if (capture->rooted) (void)ube_gc_root_leave(&capture->root);
    free(capture);
}

int32_t ube_gc_write_barrier(void* owner, void** slot, void* value) {
    if (slot == NULL) return 0;
    ube_gc_enter_lock();
    struct ube_gc_header* owner_header = ube_gc_header_from_value(owner);
    struct ube_gc_header* value_header = ube_gc_header_from_value(value);
    if (owner != NULL && owner_header == NULL) {
        ube_gc_leave_lock();
        return 0;
    }
    if ((owner_header != NULL && owner_header->finalizing) ||
        (value_header != NULL && value_header->finalizing)) {
        ube_gc_leave_lock();
        return 0;
    }
    __atomic_store_n(slot, value, __ATOMIC_SEQ_CST);
    if (value_header != NULL) value_header->pending_publication = 0;
    ube_gc_leave_lock();
    return 1;
}

void* ube_object_allocate(const struct ube_gc_layout* layout) {
    return ube_gc_allocate_pending(layout);
}

void* ube_object_lazy_ensure(void** slot, const struct ube_gc_layout* layout,
                             void (*initializer)(void*)) {
    if (slot == NULL || layout == NULL) return NULL;
    ube_gc_enter_lock();
    if (*slot == NULL) {
        void* object = ube_gc_allocate(layout);
        if (object == NULL) {
            ube_gc_leave_lock();
            return NULL;
        }
        *slot = object;
        if (initializer != NULL) initializer(object);
    }
    void* result = *slot;
    ube_gc_leave_lock();
    return result;
}

void* ube_default_form_ensure(void** slot, const struct ube_gc_layout* layout,
                              void (*initializer)(void*), int32_t explicit_load) {
    if (slot == NULL || layout == NULL) return NULL;
    ube_gc_enter_lock();
    struct ube_default_form_slot* item = ube_default_form_slots;
    while (item != NULL && item->slot != slot) item = item->next;
    if (item == NULL) {
        item = calloc(1, sizeof(*item));
        if (item == NULL) {
            ube_gc_leave_lock();
            ube_err_set(7, "default form bookkeeping allocation failed", "UBE.Components");
            return NULL;
        }
        item->slot = slot;
        item->next = ube_default_form_slots;
        ube_default_form_slots = item;
    }
    if (item->tombstone && !explicit_load) {
        ube_gc_leave_lock();
        return NULL;
    }
    if (explicit_load) item->tombstone = 0;
    void* result = ube_object_lazy_ensure(slot, layout, initializer);
    ube_gc_leave_lock();
    return result;
}

int64_t ube_object_type_id(const void* object) {
    int64_t type_id = 0;
    if (object != NULL) {
        memcpy(&type_id, object, sizeof(type_id));
    }
    return type_id;
}

void* ube_recursive_value_ensure(void** slot, const struct ube_gc_layout* layout) {
    if (slot == NULL || layout == NULL) return NULL;
    ube_gc_enter_lock();
    if (*slot == NULL) {
        if (ube_gc_allocate_into(layout, slot) == NULL) {
            ube_gc_leave_lock();
            return NULL;
        }
    }
    void* result = *slot;
    ube_gc_leave_lock();
    return result;
}

struct ube_value_copy_item {
    void* destination;
    const void* source;
};

int32_t ube_value_copy_recursive(void* destination, const void* source,
                                 const struct ube_gc_layout* layout,
                                 size_t recursive_slot_count,
                                 const size_t* recursive_slot_offsets) {
    if (destination == NULL || source == NULL || layout == NULL ||
        (recursive_slot_count != 0 && recursive_slot_offsets == NULL)) return 0;
    ube_gc_enter_lock();
    size_t count = 1;
    size_t capacity = 16;
    struct ube_value_copy_item* work = malloc(capacity * sizeof(*work));
    if (work == NULL) {
        ube_gc_leave_lock();
        return 0;
    }
    work[0].destination = destination;
    work[0].source = source;
    size_t cursor = 0;
    while (cursor < count) {
        void* current_destination = work[cursor].destination;
        const void* current_source = work[cursor].source;
        cursor += 1;
        memcpy(current_destination, current_source, layout->size);
        for (size_t index = 0; index < recursive_slot_count; ++index) {
            const size_t offset = recursive_slot_offsets[index];
            if (offset > layout->size || sizeof(void*) > layout->size - offset) {
                free(work);
                ube_gc_leave_lock();
                return 0;
            }
            void* child_source = *(void* const*)((const unsigned char*)current_source + offset);
            void** child_destination = (void**)((unsigned char*)current_destination + offset);
            *child_destination = NULL;
            if (child_source == NULL) continue;
            void* child_copy = ube_gc_allocate(layout);
            if (child_copy == NULL) {
                free(work);
                ube_gc_leave_lock();
                return 0;
            }
            *child_destination = child_copy;
            if (count == capacity) {
                if (capacity > SIZE_MAX / 2 || capacity * 2 > SIZE_MAX / sizeof(*work)) {
                    free(work);
                    ube_gc_leave_lock();
                    return 0;
                }
                capacity *= 2;
                void* resized = realloc(work, capacity * sizeof(*work));
                if (resized == NULL) {
                    free(work);
                    ube_gc_leave_lock();
                    return 0;
                }
                work = resized;
            }
            work[count].destination = child_copy;
            work[count].source = child_source;
            count += 1;
        }
    }
    free(work);
    ube_gc_leave_lock();
    return 1;
}

uint64_t ube_object_lease_acquire(void* object) {
    if (object == NULL) return 0;
    ube_gc_enter_lock();
    if (ube_gc_header_from_value(object) == NULL || ube_gc_shutdown) {
        ube_gc_leave_lock();
        return 0;
    }
    size_t index = 0;
    while (index < ube_object_lease_count && ube_object_leases[index].leases != 0) ++index;
    if (index == ube_object_lease_count) {
        if (ube_object_lease_count >= UBE_OBJECT_MAX_LEASES) {
            ube_gc_leave_lock();
            return 0;
        }
        if (ube_object_lease_count == ube_object_lease_capacity) {
            size_t next = ube_object_lease_capacity == 0 ? 64 : ube_object_lease_capacity * 2;
            if (next > UBE_OBJECT_MAX_LEASES) next = UBE_OBJECT_MAX_LEASES;
            void* resized = realloc(ube_object_leases, next * sizeof(*ube_object_leases));
            if (resized == NULL) {
                ube_gc_leave_lock();
                return 0;
            }
            ube_object_leases = resized;
            memset(ube_object_leases + ube_object_lease_capacity, 0,
                   (next - ube_object_lease_capacity) * sizeof(*ube_object_leases));
            ube_object_lease_capacity = next;
        }
        ube_object_lease_count += 1;
    }
    struct ube_object_lease* lease = &ube_object_leases[index];
    lease->generation += 1;
    if (lease->generation == 0) lease->generation = 1;
    lease->object = object;
    struct ube_gc_header* object_header = ube_gc_header_from_value(object);
    if (object_header != NULL) object_header->pending_publication = 0;
    lease->leases = 1;
    uint64_t handle = ((uint64_t)lease->generation << 32) | (uint64_t)(index + 1);
    ube_gc_leave_lock();
    return handle;
}

void* ube_object_lease_resolve(uint64_t handle) {
    const uint32_t encoded_index = (uint32_t)handle;
    const uint32_t generation = (uint32_t)(handle >> 32);
    if (encoded_index == 0 || generation == 0) return NULL;
    ube_gc_enter_lock();
    const size_t index = (size_t)encoded_index - 1;
    void* result = NULL;
    if (index < ube_object_lease_count && ube_object_leases[index].leases != 0 &&
        ube_object_leases[index].generation == generation) {
        result = ube_object_leases[index].object;
    }
    ube_gc_leave_lock();
    return result;
}

int32_t ube_object_lease_release(uint64_t handle) {
    const uint32_t encoded_index = (uint32_t)handle;
    const uint32_t generation = (uint32_t)(handle >> 32);
    if (encoded_index == 0 || generation == 0) return 0;
    ube_gc_enter_lock();
    const size_t index = (size_t)encoded_index - 1;
    if (index >= ube_object_lease_count || ube_object_leases[index].leases == 0 ||
        ube_object_leases[index].generation != generation) {
        ube_gc_leave_lock();
        return 0;
    }
    ube_object_leases[index].leases = 0;
    ube_object_leases[index].object = NULL;
    ube_gc_leave_lock();
    return 1;
}

int32_t ube_object_invalidate(void* object) {
    if (object == NULL) return 0;
    ube_gc_enter_lock();
    int32_t changed = 0;
    for (size_t index = 0; index < ube_object_lease_count; ++index) {
        if (ube_object_leases[index].leases != 0 &&
            ube_object_leases[index].object == object) {
            ube_object_leases[index].leases = 0;
            ube_object_leases[index].object = NULL;
            changed = 1;
        }
    }
    ube_gc_leave_lock();
    return changed;
}

__declspec(dllexport) int32_t ube_library_release_handle(uint64_t handle) {
    /* Release is deliberately idempotent at the foreign boundary. */
    (void)ube_object_lease_release(handle);
    return 0;
}

__declspec(dllexport) int32_t ube_library_copy_handle(uint64_t handle,
                                                       uint64_t* copied) {
    if (copied == NULL) {
        ube_library_set_diagnostic_text("handle copy requires an output pointer");
        return 1;
    }
    void* object = ube_object_lease_resolve(handle);
    if (object == NULL) {
        *copied = 0;
        ube_library_set_diagnostic_text("handle is stale or unloaded");
        return 2;
    }
    *copied = ube_object_lease_acquire(object);
    if (*copied == 0) {
        ube_library_set_diagnostic_text("could not acquire an independent handle lease");
        return 4;
    }
    return 0;
}

static const size_t ube_variant_slots[] = { offsetof(struct ube_variant, reference) };
static const struct ube_gc_layout ube_variant_layout = {
    sizeof(struct ube_variant), 1, ube_variant_slots, NULL
};

static struct ube_variant* ube_variant_allocate(int32_t tag) {
    struct ube_variant* result = ube_gc_allocate_pending(&ube_variant_layout);
    if (result == NULL) return NULL;
    result->tag = tag;
    return result;
}

void* ube_variant_empty(void) {
    return ube_variant_allocate(UBE_VARIANT_EMPTY);
}

void* ube_variant_null(void) {
    return ube_variant_allocate(UBE_VARIANT_NULL);
}

void* ube_variant_from_long(int32_t value) {
    struct ube_variant* result = ube_variant_allocate(UBE_VARIANT_LONG);
    if (result != NULL) result->scalar = value;
    return result;
}

void* ube_variant_from_integer(int32_t tag, int64_t value) {
    if (tag != UBE_VARIANT_BOOLEAN && tag != UBE_VARIANT_BYTE &&
        tag != UBE_VARIANT_INTEGER && tag != UBE_VARIANT_LONG &&
        tag != UBE_VARIANT_LONGLONG && tag != UBE_VARIANT_CURRENCY &&
        tag != UBE_VARIANT_INTPTR && tag != UBE_VARIANT_UINTPTR) return NULL;
    struct ube_variant* result = ube_variant_allocate(tag);
    if (result != NULL) result->scalar = value;
    return result;
}

void* ube_variant_from_floating(int32_t tag, double value) {
    if (tag != UBE_VARIANT_SINGLE && tag != UBE_VARIANT_DOUBLE &&
        tag != UBE_VARIANT_DATE) return NULL;
    struct ube_variant* result = ube_variant_allocate(tag);
    if (result != NULL) result->floating = value;
    return result;
}

void* ube_variant_from_longlong(int64_t value) {
    struct ube_variant* result = ube_variant_allocate(UBE_VARIANT_LONGLONG);
    if (result != NULL) result->scalar = value;
    return result;
}

void* ube_variant_from_reference(int32_t tag, void* value) {
    if (tag != UBE_VARIANT_STRING && tag != UBE_VARIANT_OBJECT &&
        tag != UBE_VARIANT_CUSTOM && tag != UBE_VARIANT_ARRAY &&
        tag != UBE_VARIANT_DECIMAL) return NULL;
    struct ube_variant* result = ube_variant_allocate(tag);
    if (result == NULL) return NULL;
    if (value != NULL) {
        if (!ube_gc_write_barrier(result, &result->reference, value)) return NULL;
    } else {
        result->reference = value;
    }
    return result;
}

void* ube_variant_copy(const void* value) {
    if (value == NULL) return NULL;
    const struct ube_variant* source = value;
    struct ube_variant* result = ube_variant_allocate(source->tag);
    if (result == NULL) return NULL;
    result->scalar = source->scalar;
    result->floating = source->floating;
    if (source->reference != NULL) {
        if (!ube_gc_write_barrier(result, &result->reference, source->reference)) return NULL;
    } else {
        result->reference = source->reference;
    }
    return result;
}

int32_t ube_variant_tag(const void* value) {
    return value == NULL ? UBE_VARIANT_EMPTY : ((const struct ube_variant*)value)->tag;
}

int32_t ube_variant_get_long(const void* value, int32_t* result) {
    if (result == NULL || value == NULL) return 0;
    const struct ube_variant* variant = value;
    if (variant->tag == UBE_VARIANT_EMPTY) {
        *result = 0;
        return 1;
    }
    if (variant->tag != UBE_VARIANT_BOOLEAN && variant->tag != UBE_VARIANT_BYTE &&
        variant->tag != UBE_VARIANT_INTEGER && variant->tag != UBE_VARIANT_LONG &&
        variant->tag != UBE_VARIANT_LONGLONG && variant->tag != UBE_VARIANT_INTPTR &&
        variant->tag != UBE_VARIANT_UINTPTR) return 0;
    if (variant->scalar < INT32_MIN || variant->scalar > INT32_MAX) return 0;
    *result = (int32_t)variant->scalar;
    return 1;
}

int32_t ube_variant_get_longlong(const void* value, int64_t* result) {
    if (result == NULL || value == NULL) return 0;
    const struct ube_variant* variant = value;
    if (variant->tag == UBE_VARIANT_EMPTY) {
        *result = 0;
        return 1;
    }
    if (variant->tag != UBE_VARIANT_BOOLEAN && variant->tag != UBE_VARIANT_BYTE &&
        variant->tag != UBE_VARIANT_INTEGER && variant->tag != UBE_VARIANT_LONG &&
        variant->tag != UBE_VARIANT_LONGLONG && variant->tag != UBE_VARIANT_INTPTR &&
        variant->tag != UBE_VARIANT_UINTPTR && variant->tag != UBE_VARIANT_CURRENCY) return 0;
    *result = variant->scalar;
    return 1;
}

int32_t ube_variant_get_boolean(const void* value, int32_t* result) {
    if (result == NULL || value == NULL) return 0;
    const struct ube_variant* variant = value;
    if (variant->tag == UBE_VARIANT_EMPTY) {
        *result = 0;
        return 1;
    }
    if (variant->tag == UBE_VARIANT_SINGLE || variant->tag == UBE_VARIANT_DOUBLE) {
        if (variant->floating != variant->floating ||
            variant->floating > 1.7976931348623157e308 ||
            variant->floating < -1.7976931348623157e308) return 0;
        *result = variant->floating == 0.0 ? 0 : -1;
        return 1;
    }
    int64_t numeric = 0;
    if (!ube_variant_get_longlong(value, &numeric)) return 0;
    *result = numeric == 0 ? 0 : -1;
    return 1;
}

int32_t ube_variant_get_double(const void* value, double* result) {
    if (result == NULL || value == NULL) return 0;
    const struct ube_variant* variant = value;
    if (variant->tag == UBE_VARIANT_EMPTY) {
        *result = 0.0;
        return 1;
    }
    if (variant->tag == UBE_VARIANT_SINGLE || variant->tag == UBE_VARIANT_DOUBLE) {
        *result = variant->floating;
        return 1;
    }
    if (variant->tag == UBE_VARIANT_DATE) return 0;
    int64_t numeric = 0;
    if (!ube_variant_get_longlong(value, &numeric)) return 0;
    *result = variant->tag == UBE_VARIANT_CURRENCY
        ? (double)numeric / 10000.0 : (double)numeric;
    return 1;
}

int32_t ube_variant_get_reference(const void* value, int32_t expected_tag,
                                  void** result) {
    if (result == NULL || value == NULL) return 0;
    const struct ube_variant* variant = value;
    if (variant->tag == UBE_VARIANT_EMPTY) {
        *result = NULL;
        return 1;
    }
    if (variant->tag != expected_tag) return 0;
    *result = variant->reference;
    return 1;
}

int32_t ube_fixed_string_assign(unsigned char* destination, size_t width,
                                const char* source) {
    if (destination == NULL || (source == NULL && width != 0)) return 0;
    const size_t source_length = source == NULL ? 0 : strlen(source);
    const size_t copy_length = source_length < width ? source_length : width;
    if (copy_length != 0) memcpy(destination, source, copy_length);
    if (copy_length < width) memset(destination + copy_length, ' ', width - copy_length);
    return 1;
}

int32_t ube_fixed_string_compare(const unsigned char* left,
                                 const unsigned char* right, size_t width) {
    if (left == NULL || right == NULL) return 0;
    const int compared = memcmp(left, right, width);
    return compared < 0 ? -1 : compared > 0 ? 1 : 0;
}

char* ube_fixed_string_copy_managed(const char* source, size_t width) {
    char* result = ube_allocate_string_managed(width);
    if (result == NULL) return NULL;
    const size_t source_length = source == NULL ? 0 : strlen(source);
    const size_t copy_length = source_length < width ? source_length : width;
    if (copy_length != 0) memcpy(result, source, copy_length);
    if (copy_length < width) memset(result + copy_length, ' ', width - copy_length);
    result[width] = '\0';
    return result;
}

int32_t ube_checked_string_to_long(const char* value, int32_t* result) {
    if (value == NULL || result == NULL) {
        ube_err_set(13, "String-to-Long conversion received an invalid value", "conversion");
        return 0;
    }
    const unsigned char* cursor = (const unsigned char*)value;
    while (*cursor == ' ' || *cursor == '\t') ++cursor;
    int negative = 0;
    if (*cursor == '-' || *cursor == '+') {
        negative = *cursor == '-';
        ++cursor;
    }
    if (*cursor < '0' || *cursor > '9') {
        ube_err_set(13, "String is not a complete Long value", "conversion");
        return 0;
    }
    uint64_t magnitude = 0;
    while (*cursor >= '0' && *cursor <= '9') {
        const uint32_t digit = (uint32_t)(*cursor - '0');
        const uint64_t limit = negative ? UINT64_C(2147483648) : UINT64_C(2147483647);
        if (magnitude > (limit - digit) / 10) {
            ube_err_set(6, "String-to-Long conversion overflow", "conversion");
            return 0;
        }
        magnitude = magnitude * 10 + digit;
        ++cursor;
    }
    while (*cursor == ' ' || *cursor == '\t') ++cursor;
    if (*cursor != '\0') {
        ube_err_set(13, "String is not a complete Long value", "conversion");
        return 0;
    }
    *result = negative ? (magnitude == UINT64_C(2147483648) ? INT32_MIN : -(int32_t)magnitude)
                       : (int32_t)magnitude;
    return 1;
}

size_t ube_gc_root_storage_size(void) {
    return sizeof(struct ube_gc_root);
}

size_t ube_gc_live_allocation_bytes(void) {
    ube_gc_enter_lock();
    const size_t result = ube_gc_live_bytes;
    ube_gc_leave_lock();
    return result;
}

static void ube_gc_release_all(void) {
    ube_gc_enter_lock();
    ube_gc_shutdown = 1;
    ube_gc_roots = NULL;
    ube_gc_root_count = 0;
    while (ube_gc_allocations != NULL) {
        struct ube_gc_header* item = ube_gc_allocations;
        ube_gc_allocations = item->next;
        if (!item->finalized && item->layout != NULL && item->layout->finalizer != NULL) {
            item->finalizing = 1;
            item->layout->finalizer(item->data);
            item->finalized = 1;
        }
        ube_gc_hash_remove(item);
        item->magic = 0;
        if (item->monitor_initialized) DeleteCriticalSection(&item->monitor);
        if (item->owns_layout) free((void*)item->layout);
        free(item);
    }
    ube_gc_live_bytes = 0;
    free(ube_object_leases);
    ube_object_leases = NULL;
    ube_object_lease_count = 0;
    ube_object_lease_capacity = 0;
    ube_gc_leave_lock();
}

__declspec(dllexport) int32_t ube_library_shutdown(void) {
    ube_gc_enter_lock();
    if (!ube_library_accepting_calls && ube_gc_shutdown) {
        ube_gc_leave_lock();
        return 0;
    }
    ube_library_accepting_calls = 0;
    while (ube_library_active_calls != 0) {
        ube_gc_leave_lock();
        Sleep(0);
        ube_gc_enter_lock();
    }
    if (ube_library_initialized && ube_library_terminator != NULL) {
        ube_library_terminator();
        ube_library_terminator = NULL;
        ube_library_initialized = 0;
    }
    ube_gc_release_all();
    ube_library_release_diagnostics();
    ube_gc_leave_lock();
    return 0;
}

static void ube_release_strings(void) {
    while (ube_string_allocations != NULL) {
        struct ube_string_allocation* allocation = ube_string_allocations;
        ube_string_allocations = allocation->next;
        free(allocation);
    }
}

static char* ube_allocate_string(size_t length) {
    if (!ube_string_cleanup_registered) {
        if (atexit(ube_release_strings) != 0) {
            fputs("UBE runtime: could not register string cleanup\n", stderr);
            exit(70);
        }
        ube_string_cleanup_registered = 1;
    }
    if (length > SIZE_MAX - sizeof(struct ube_string_allocation) - 1) {
        fputs("UBE runtime: string size overflow\n", stderr);
        exit(70);
    }
    struct ube_string_allocation* allocation =
        malloc(sizeof(*allocation) + length + 1);
    if (allocation == NULL) {
        fputs("UBE runtime: out of memory while allocating a string\n", stderr);
        exit(70);
    }
    allocation->next = ube_string_allocations;
    ube_string_allocations = allocation;
    return allocation->data;
}

static char* ube_allocate_string_managed(size_t length) {
    if (length == SIZE_MAX) return NULL;
    return ube_gc_allocate_untraced_pending(length + 1);
}

static void ube_release_legacy_allocations(void) {
    while (ube_legacy_allocations != NULL) {
        struct ube_legacy_allocation* allocation = ube_legacy_allocations;
        ube_legacy_allocations = allocation->next;
        free(allocation);
    }
}

static void* ube_allocate_legacy(size_t size) {
    if (!ube_legacy_cleanup_registered) {
        if (atexit(ube_release_legacy_allocations) != 0) return NULL;
        ube_legacy_cleanup_registered = 1;
    }
    if (size > SIZE_MAX - sizeof(struct ube_legacy_allocation)) return NULL;
    struct ube_legacy_allocation* allocation = calloc(1, sizeof(*allocation) + size);
    if (allocation == NULL) return NULL;
    allocation->next = ube_legacy_allocations;
    ube_legacy_allocations = allocation;
    return allocation->data;
}

static void ube_release_legacy(void* value) {
    struct ube_legacy_allocation** link = &ube_legacy_allocations;
    while (*link != NULL) {
        struct ube_legacy_allocation* allocation = *link;
        if ((void*)allocation->data == value) {
            *link = allocation->next;
            free(allocation);
            return;
        }
        link = &allocation->next;
    }
}

void ube_array_release(void* value) {
    if (ube_gc_header_from_value(value) == NULL) ube_release_legacy(value);
}

void* ube_array_redim(void* old_value, int32_t lower, int32_t upper,
                      size_t element_size, int preserve) {
    if (upper < lower || element_size == 0) {
        fputs("UBE runtime: invalid dynamic array bounds\n", stderr);
        exit(65);
    }
    const uint64_t count = (uint64_t)((int64_t)upper - (int64_t)lower + 1);
    if (count > (SIZE_MAX - sizeof(struct ube_array)) / element_size) {
        fputs("UBE runtime: dynamic array size overflow\n", stderr);
        exit(70);
    }
    struct ube_array* result = ube_allocate_legacy(
        sizeof(*result) + (size_t)count * element_size);
    if (result == NULL) {
        fputs("UBE runtime: out of memory while allocating a bootstrap array\n", stderr);
        exit(70);
    }
    result->lower = lower;
    result->upper = upper;
    result->element_size = element_size;
    if (preserve && old_value != NULL) {
        const struct ube_array* old = old_value;
        const int32_t copy_lower = lower > old->lower ? lower : old->lower;
        const int32_t copy_upper = upper < old->upper ? upper : old->upper;
        if (copy_upper >= copy_lower) {
            const size_t copy_count = (size_t)((int64_t)copy_upper - copy_lower + 1);
            memcpy(result->data + (size_t)(copy_lower - lower) * element_size,
                   old->data + (size_t)(copy_lower - old->lower) * element_size,
                   copy_count * element_size);
        }
    }
    ube_release_legacy(old_value);
    return result;
}

void* ube_array_redim_managed(void** slot, int32_t lower, int32_t upper,
                              size_t element_size, int preserve,
                              size_t element_slot_count, const size_t* element_slot_offsets) {
    if (slot == NULL) return NULL;
    ube_gc_enter_lock();
    void* old_value = *slot;
    if (upper < lower || element_size == 0) {
        fputs("UBE runtime: invalid dynamic array bounds\n", stderr);
        exit(65);
    }
    const uint64_t count = (uint64_t)((int64_t)upper - (int64_t)lower + 1);
    if (count > (SIZE_MAX - sizeof(struct ube_array)) / element_size) {
        fputs("UBE runtime: dynamic array size overflow\n", stderr);
        exit(70);
    }
    const size_t payload_size = sizeof(struct ube_array) + (size_t)count * element_size;
    if (count != 0 && element_slot_count > SIZE_MAX / (size_t)count) {
        ube_gc_leave_lock();
        fputs("UBE runtime: dynamic array tracing metadata overflow\n", stderr);
        exit(70);
    }
    const size_t total_slots = (size_t)count * element_slot_count;
    size_t* offsets = NULL;
    if (total_slots != 0) {
        offsets = malloc(total_slots * sizeof(size_t));
        if (offsets == NULL) {
            ube_gc_leave_lock();
            fputs("UBE runtime: out of memory while describing an array\n", stderr);
            exit(70);
        }
        size_t output = 0;
        for (size_t element = 0; element < (size_t)count; ++element) {
            for (size_t child = 0; child < element_slot_count; ++child) {
                const size_t child_offset = element_slot_offsets == NULL ? 0 : element_slot_offsets[child];
                offsets[output++] = offsetof(struct ube_array, data) +
                    element * element_size + child_offset;
            }
        }
    }
    struct ube_array* result = ube_gc_allocate_dynamic(payload_size, total_slots, offsets);
    free(offsets);
    if (result == NULL) {
        fputs("UBE runtime: out of memory while allocating an array\n", stderr);
        exit(70);
    }
    result->lower = lower;
    result->upper = upper;
    result->element_size = element_size;
    if (preserve && old_value != NULL) {
        const struct ube_array* old = old_value;
        if (old->element_size != element_size) {
            fputs("UBE runtime: ReDim Preserve element type mismatch\n", stderr);
            exit(70);
        }
        const int32_t copy_lower = lower > old->lower ? lower : old->lower;
        const int32_t copy_upper = upper < old->upper ? upper : old->upper;
        if (copy_lower <= copy_upper) {
            const size_t copy_count = (size_t)((int64_t)copy_upper - copy_lower + 1);
            memcpy(result->data + (size_t)(copy_lower - lower) * element_size,
                   old->data + (size_t)(copy_lower - old->lower) * element_size,
                   copy_count * element_size);
        }
    }
    *slot = result;
    ube_gc_leave_lock();
    return result;
}

void* ube_array_copy_managed(const void* value,
                             const struct ube_gc_layout* element_layout,
                             size_t recursive_slot_count,
                             const size_t* recursive_slot_offsets) {
    if (value == NULL) return NULL;
    ube_gc_enter_lock();
    struct ube_gc_header* source_header = ube_gc_header_from_value((void*)value);
    const struct ube_array* source = value;
    if (source_header == NULL || source_header->layout == NULL ||
        source_header->payload_size < sizeof(*source)) {
        ube_gc_leave_lock();
        return NULL;
    }
    struct ube_array* result = ube_gc_allocate_dynamic(
        source_header->payload_size, source_header->layout->slot_count,
        source_header->layout->slot_offsets);
    if (result == NULL) {
        ube_gc_leave_lock();
        return NULL;
    }
    memcpy(result, source, source_header->payload_size);
    if (element_layout != NULL && recursive_slot_count != 0) {
        const size_t count = (size_t)((int64_t)source->upper - source->lower + 1);
        for (size_t index = 0; index < count; ++index) {
            void* destination_element = result->data + index * source->element_size;
            const void* source_element = source->data + index * source->element_size;
            if (!ube_value_copy_recursive(destination_element, source_element,
                                          element_layout, recursive_slot_count,
                                          recursive_slot_offsets)) {
                ube_gc_leave_lock();
                return NULL;
            }
        }
    }
    ube_gc_leave_lock();
    return result;
}

void* ube_array_element(void* value, int32_t index) {
    if (value == NULL) {
        fputs("UBE runtime: dynamic array has not been dimensioned\n", stderr);
        exit(65);
    }
    struct ube_array* array = value;
    if (index < array->lower || index > array->upper) {
        fprintf(stderr, "UBE runtime: array index out of range: %" PRId32 "\n", index);
        exit(65);
    }
    return array->data + (size_t)(index - array->lower) * array->element_size;
}

int32_t ube_array_lbound(const void* value) {
    if (value == NULL) {
        fputs("UBE runtime: dynamic array has not been dimensioned\n", stderr);
        exit(65);
    }
    return ((const struct ube_array*)value)->lower;
}

int32_t ube_array_ubound(const void* value) {
    if (value == NULL) {
        fputs("UBE runtime: dynamic array has not been dimensioned\n", stderr);
        exit(65);
    }
    return ((const struct ube_array*)value)->upper;
}

/* Managed value primitives. The compiler supplies exact target layouts; no
   source type names or library algorithms are recognized here. */
#define UBE_VALUE_MAX_COPY_FRAMES 65536u
struct ube_value_transaction { struct ube_gc_header* allocations; };
struct ube_value_copy_range {
    unsigned char* destination;
    const unsigned char* source;
    const struct ube_value_layout* layout;
    size_t count;
#if UBE_VALUE_COPY_OBSERVED
    int payload;
#endif
};
struct ube_value_copy_work {
    struct ube_value_copy_range local[64];
    struct ube_value_copy_range* frames;
    size_t capacity;
};
static void ube_value_work_init(struct ube_value_copy_work* work) {
    work->frames = work->local;
    work->capacity = 64;
}
static void ube_value_work_release(struct ube_value_copy_work* work) {
    if (work->frames != work->local) free(work->frames);
}

static void* ube_value_allocate_workspace(size_t size) {
    void* result = calloc(1, size == 0 ? 1 : size);
    if (result == NULL) {
        (void)ube_gc_collect_internal(0);
        result = calloc(1, size == 0 ? 1 : size);
    }
    if (result == NULL) ube_err_set(7, "value-copy workspace allocation failed", "value storage");
    return result;
}

static void ube_value_finish_transaction(struct ube_value_transaction* transaction, int commit) {
    while (transaction->allocations != NULL) {
        struct ube_gc_header* item = transaction->allocations;
        transaction->allocations = item->transaction_next;
        item->transaction_next = NULL;
        if (commit) {
            item->pending_publication = 0;
        } else {
            struct ube_gc_header** link = &ube_gc_allocations;
            while (*link != NULL && *link != item) link = &(*link)->next;
            if (*link == item) *link = item->next;
            ube_gc_hash_remove(item);
            ube_gc_live_bytes -= item->payload_size;
            item->magic = 0;
            if (item->monitor_initialized) DeleteCriticalSection(&item->monitor);
            free(item);
        }
    }
}

static struct ube_array* ube_value_allocate_array(int32_t lower, int32_t upper,
        const struct ube_value_layout* element, struct ube_value_transaction* transaction) {
    if (element == NULL || element->size == 0 || upper < lower) {
        ube_err_set(9, "invalid array bounds or element layout", "value storage");
        return NULL;
    }
    const uint64_t count = (uint64_t)((int64_t)upper - lower + 1);
    if (count > (SIZE_MAX - sizeof(struct ube_array)) / element->size) {
        ube_err_set(6, "array storage size overflow", "value storage");
        return NULL;
    }
    struct ube_array* result = ube_gc_allocate_untraced_pending(
        sizeof(*result) + (size_t)count * element->size);
    if (result == NULL) {
        ube_err_set(7, "array storage allocation failed", "value storage");
        return NULL;
    }
    result->lower = lower;
    result->upper = upper;
    result->element_size = element->size;
    struct ube_gc_header* header = ube_gc_header_from_value(result);
    header->element_layout = element;
    header->element_count = (size_t)count;
    header->transaction_next = transaction->allocations;
    transaction->allocations = header;
    return result;
}

static int ube_value_copy_scalar(void* destination, const void* source, size_t size) {
    switch (size) {
    case 1: __atomic_store_n((uint8_t*)destination, __atomic_load_n((const uint8_t*)source, __ATOMIC_SEQ_CST), __ATOMIC_SEQ_CST); return 1;
    case 2: __atomic_store_n((uint16_t*)destination, __atomic_load_n((const uint16_t*)source, __ATOMIC_SEQ_CST), __ATOMIC_SEQ_CST); return 1;
    case 4: __atomic_store_n((uint32_t*)destination, __atomic_load_n((const uint32_t*)source, __ATOMIC_SEQ_CST), __ATOMIC_SEQ_CST); return 1;
    case 8: __atomic_store_n((uint64_t*)destination, __atomic_load_n((const uint64_t*)source, __ATOMIC_SEQ_CST), __ATOMIC_SEQ_CST); return 1;
    default: ube_err_set(5, "unsupported scalar layout", "value storage"); return 0;
    }
}

/* Iterative ranges bound workspace by value nesting, not array length. Newly
   allocated storage remains pending until the complete value is published. */
static int ube_value_walk(void* destination, const void* source,
        const struct ube_value_layout* layout, size_t count, int independent,
        struct ube_value_transaction* transaction, struct ube_value_copy_work* workspace
        UBE_VALUE_PAYLOAD(int payload)) {
    struct ube_value_copy_range* work = workspace->frames;
    size_t capacity = workspace->capacity, depth = 1;
    work[0] = (struct ube_value_copy_range){ destination, source, layout, count UBE_VALUE_PAYLOAD(payload) };
    int success = 1;
    while (depth != 0 && success) {
        struct ube_value_copy_range* frame = &work[depth - 1];
        if (frame->count == 0) { --depth; continue; }
        unsigned char* to = frame->destination;
        const unsigned char* from = frame->source;
        const struct ube_value_layout* type = frame->layout;
#if UBE_VALUE_COPY_OBSERVED
        const int payload_copy = frame->payload;
#endif
        if (type == NULL || type->size == 0) goto invalid_layout;
        frame->destination += type->size;
        frame->source += type->size;
        --frame->count;
        size_t children = 0;
        const struct ube_value_field* fields = NULL;
        if (type->kind == 0) {
            if (independent < 0) {
                if (type->size != 1 && type->size != 2 && type->size != 4 && type->size != 8) goto invalid_layout;
                continue;
            }
            success = ube_value_copy_scalar(to, from, type->size);
            UBE_VALUE_OBSERVE_LEAF(type->size, success && payload_copy);
            continue;
        }
        if (type->kind == 3 || (type->kind == 1 && independent <= 0)) {
            if (type->size != sizeof(void*)) goto invalid_layout;
            if (independent < 0) continue;
            success = ube_value_copy_scalar(to, from, sizeof(void*));
            UBE_VALUE_OBSERVE_LEAF(sizeof(void*), success && payload_copy);
            continue;
        }
        if (type->kind == 1) {
            if (type->size != sizeof(void*) || type->field_count != 1 || type->fields == NULL) goto invalid_layout;
            const struct ube_array* old = __atomic_load_n((struct ube_array* const*)from, __ATOMIC_SEQ_CST);
            if (old == NULL) { __atomic_store_n((void**)to, NULL, __ATOMIC_SEQ_CST); continue; }
            const struct ube_value_layout* element = type->fields[0].layout;
            if (element == NULL || old->element_size != element->size) goto invalid_layout;
            if (depth == capacity) {
                if (capacity >= UBE_VALUE_MAX_COPY_FRAMES) {
                    ube_err_set(7, "value-copy nesting limit exceeded", "value storage");
                    success = 0;
                    break;
                }
                struct ube_value_copy_range* grown = ube_value_allocate_workspace(capacity * 2 * sizeof(*grown));
                if (grown == NULL) { success = 0; break; }
                memcpy(grown, work, depth * sizeof(*grown));
                if (work != workspace->local) free(work);
                work = grown;
                capacity *= 2;
            }
            struct ube_array* copy = ube_value_allocate_array(old->lower, old->upper, element, transaction);
            if (copy == NULL) { success = 0; break; }
            __atomic_store_n((void**)to, copy, __ATOMIC_SEQ_CST);
            /* One range describes every element, even for very large arrays. */
            work[depth++] = (struct ube_value_copy_range){copy->data, old->data, element,
                (size_t)((int64_t)old->upper - old->lower + 1) UBE_VALUE_PAYLOAD(1)};
            continue;
        } else if (type->kind == 2 && type->field_count >= 0 && type->fields != NULL) {
            children = (size_t)type->field_count;
            fields = type->fields;
        } else goto invalid_layout;
        if (children > UBE_VALUE_MAX_COPY_FRAMES - depth) {
            ube_err_set(7, "value-copy nesting limit exceeded", "value storage");
            success = 0;
            break;
        }
        if (depth + children > capacity) {
            size_t next = capacity;
            while (next < depth + children) next *= 2;
            struct ube_value_copy_range* grown = ube_value_allocate_workspace(next * sizeof(*grown));
            if (grown == NULL) { success = 0; break; }
            memcpy(grown, work, depth * sizeof(*grown));
            if (work != workspace->local) free(work);
            work = grown;
            capacity = next;
        }
        if (fields == NULL) continue;
        for (size_t field = 0; field < children; ++field) {
            const struct ube_value_layout* child = fields[field].layout;
            if (child == NULL || fields[field].offset > type->size || child->size > type->size - fields[field].offset) goto invalid_layout;
            work[depth++] = (struct ube_value_copy_range){to + fields[field].offset,
                from + fields[field].offset, child, 1 UBE_VALUE_PAYLOAD(payload_copy)};
        }
    }
    workspace->frames = work;
    workspace->capacity = capacity;
    return success;
invalid_layout:
    workspace->frames = work;
    workspace->capacity = capacity;
    ube_err_set(5, "invalid value-copy layout", "value storage");
    return 0;
}

int32_t ube_value_root_enter(void* root, void* value, const struct ube_value_layout* layout) {
    if (layout == NULL || value == NULL) { ube_err_set(5, "invalid value root", "value storage"); return 0; }
    if (layout->root_count == 0) return 1;
    if (!ube_gc_root_enter_layout(root, value, layout->root_count, layout->root_offsets)) {
        ube_err_set(7, "value root capacity exhausted", "value storage");
        return 0;
    }
    return 1;
}

int32_t ube_value_snapshot(void* destination, const void* source, const struct ube_value_layout* layout) {
    if (destination == NULL || source == NULL || layout == NULL) { ube_err_set(5, "invalid value snapshot", "value storage"); return 0; }
    /* Rootless values contain only atomic scalars and process-lifetime legacy
       String references. Independent decoder/value work needs no GC lock. */
    if (layout->root_count != 0) ube_gc_enter_lock();
    struct ube_value_copy_work work;
    ube_value_work_init(&work);
    /* Metadata is immutable. A no-read pass validates every inline leaf and
       reserves all workspace before the first destination store. */
    int result = ube_value_walk(destination, source, layout, 1, -1, NULL, &work UBE_VALUE_PAYLOAD(0));
    if (result) result = ube_value_walk(destination, source, layout, 1, 0, NULL, &work UBE_VALUE_PAYLOAD(0));
    ube_value_work_release(&work);
    if (layout->root_count != 0) ube_gc_leave_lock();
    return result;
}

/* Only compiler-private temporaries/fallbacks may be cleared this way. Managed
   roots remain registered while their slots become neutral under the GC lock. */
void ube_value_zero(void* destination, const struct ube_value_layout* layout) {
    if (destination == NULL || layout == NULL) return;
    if (layout->root_count != 0) ube_gc_enter_lock();
    memset(destination, 0, layout->size);
    if (layout->root_count != 0) ube_gc_leave_lock();
}

int32_t ube_value_read(void* private_destination, const void* source,
        const struct ube_value_layout* layout) {
    const int32_t success = ube_value_snapshot(private_destination, source, layout);
    if (!success) ube_value_zero(private_destination, layout);
    return success;
}

int32_t ube_value_assign(void* destination, const void* source, const struct ube_value_layout* layout) {
    if (destination == NULL || source == NULL || layout == NULL) { ube_err_set(5, "invalid value assignment", "value storage"); return 0; }
    if (destination == source) return 1;
    if (layout->root_count == 0) return ube_value_snapshot(destination, source, layout);
    ube_gc_enter_lock();
    struct ube_gc_root source_root = {0}, destination_root = {0};
    int success = ube_value_root_enter(&source_root, (void*)source, layout) &&
        ube_value_root_enter(&destination_root, destination, layout);
    if (success) {
        int neutral = 1;
        for (size_t slot = 0; slot < layout->root_count; ++slot) {
            if (__atomic_load_n((void* const*)((const unsigned char*)source + layout->root_offsets[slot]), __ATOMIC_SEQ_CST) != NULL) {
                neutral = 0;
                break;
            }
        }
        if (neutral) {
            success = ube_value_snapshot(destination, source, layout);
            (void)ube_gc_root_leave(&destination_root);
            (void)ube_gc_root_leave(&source_root);
            ube_gc_leave_lock();
            return success;
        }
    }
    struct ube_value_transaction transaction = {0};
    struct ube_value_copy_work work;
    ube_value_work_init(&work);
    void* prepared = success ? ube_value_allocate_workspace(layout->size) : NULL;
    if (prepared == NULL) success = 0;
    if (success) success = ube_value_walk(prepared, source, layout, 1, 1, &transaction, &work UBE_VALUE_PAYLOAD(0));
    /* Publication traverses a subset of the already validated layout using the
       same workspace, so no allocation occurs after destination writes begin. */
    if (success) success = ube_value_walk(destination, prepared, layout, 1, 0, NULL, &work UBE_VALUE_PAYLOAD(0));
    ube_value_finish_transaction(&transaction, success);
    free(prepared);
    ube_value_work_release(&work);
    (void)ube_gc_root_leave(&destination_root);
    (void)ube_gc_root_leave(&source_root);
    ube_gc_leave_lock();
    return success;
}

int32_t ube_value_try_redim(void** slot, int32_t lower, int32_t upper,
        const struct ube_value_layout* element, int32_t preserve) {
    if (slot == NULL || element == NULL) { ube_err_set(5, "invalid array destination", "value storage"); return 0; }
    ube_gc_enter_lock();
    struct ube_gc_root old_root = {0};
    if (!ube_gc_root_enter(&old_root, slot)) {
        ube_err_set(7, "array root capacity exhausted", "value storage");
        ube_gc_leave_lock();
        return 0;
    }
    const struct ube_array* old = __atomic_load_n((struct ube_array* const*)slot, __ATOMIC_SEQ_CST);
    struct ube_value_transaction transaction = {0};
    struct ube_value_copy_work work;
    ube_value_work_init(&work);
    struct ube_array* result = ube_value_allocate_array(lower, upper, element, &transaction);
    int success = result != NULL;
    if (success && preserve && old != NULL) {
        if (old->element_size != element->size) {
            ube_err_set(5, "array element layout mismatch", "value storage");
            success = 0;
        } else {
            const int32_t begin = lower > old->lower ? lower : old->lower;
            const int32_t end = upper < old->upper ? upper : old->upper;
            if (begin <= end) success = ube_value_walk(
                result->data + (size_t)((int64_t)begin - lower) * element->size,
                old->data + (size_t)((int64_t)begin - old->lower) * element->size,
                element, (size_t)((int64_t)end - begin + 1), 1, &transaction, &work UBE_VALUE_PAYLOAD(1));
        }
    }
    if (success) __atomic_store_n(slot, result, __ATOMIC_SEQ_CST);
    ube_value_finish_transaction(&transaction, success);
    ube_value_work_release(&work);
    (void)ube_gc_root_leave(&old_root);
    ube_gc_leave_lock();
    return success;
}

int32_t ube_value_try_resize(void** slot, int32_t count,
        const struct ube_value_layout* element, int32_t preserve) {
    if (count < 0 || slot == NULL || element == NULL) { ube_err_set(5, "invalid array length", "value storage"); return 0; }
    if (count != 0) return ube_value_try_redim(slot, 0, count - 1, element, preserve);
    ube_gc_enter_lock();
    __atomic_store_n(slot, NULL, __ATOMIC_SEQ_CST);
    ube_gc_leave_lock();
    return 1;
}

/* The caller roots keep_alive and fallback for the complete ByRef call scope.
   An array replacement cannot invalidate an already borrowed element address. */
void* ube_value_array_element(void* const* slot, int32_t index, void** keep_alive,
        void* fallback, const struct ube_value_layout* element) {
    if (slot == NULL || keep_alive == NULL || fallback == NULL || element == NULL) {
        ube_err_set(5, "invalid array element request", "value storage");
        return NULL;
    }
    ube_gc_enter_lock();
    const struct ube_array* value = __atomic_load_n((struct ube_array* const*)slot, __ATOMIC_SEQ_CST);
    __atomic_store_n(keep_alive, (void*)value, __ATOMIC_SEQ_CST);
    void* result = fallback;
    if (value != NULL && index >= value->lower && index <= value->upper && value->element_size == element->size) {
        result = (unsigned char*)value->data + (size_t)((int64_t)index - value->lower) * value->element_size;
    } else {
        memset(fallback, 0, element->size);
        ube_err_set(9, "array index outside its bounds", "value storage");
    }
    ube_gc_leave_lock();
    return result;
}

int32_t ube_value_array_length(void* const* slot) {
    if (slot == NULL) { ube_err_set(5, "invalid array reference", "value storage"); return 0; }
    ube_gc_enter_lock();
    const struct ube_array* value = __atomic_load_n((struct ube_array* const*)slot, __ATOMIC_SEQ_CST);
    const int64_t count = value == NULL ? 0 : (int64_t)value->upper - value->lower + 1;
    ube_gc_leave_lock();
    if (count < 0 || count > INT32_MAX) { ube_err_set(6, "array length overflow", "value storage"); return 0; }
    return (int32_t)count;
}

/* Compiler-only zero-based Byte payload spans. All validation precedes stores;
   valid calls require no allocation or traversal metadata, even under OOM. */
int32_t ube_value_copy_bytes(void* const* source, int32_t source_start,
        void* const* destination, int32_t destination_start, int32_t count) {
    if (source == NULL || destination == NULL || count < 0) {
        ube_err_set(5, "invalid byte copy request", "value storage");
        return 0;
    }
    ube_gc_enter_lock();
    const struct ube_array* from = __atomic_load_n((struct ube_array* const*)source, __ATOMIC_SEQ_CST);
    struct ube_array* to = __atomic_load_n((struct ube_array* const*)destination, __ATOMIC_SEQ_CST);
    if ((from != NULL && from->element_size != 1) || (to != NULL && to->element_size != 1)) {
        ube_gc_leave_lock();
        ube_err_set(5, "byte copy requires Byte array storage", "value storage");
        return 0;
    }
    const int64_t source_length = from == NULL ? 0 : (int64_t)from->upper - from->lower + 1;
    const int64_t destination_length = to == NULL ? 0 : (int64_t)to->upper - to->lower + 1;
    if (source_start < 0 || destination_start < 0 || source_start > source_length ||
        destination_start > destination_length || count > source_length - source_start ||
        count > destination_length - destination_start) {
        ube_gc_leave_lock();
        ube_err_set(9, "byte copy span outside array bounds", "value storage");
        return 0;
    }
    if (from == to && destination_start > source_start) {
        for (int32_t remaining = count; remaining != 0; --remaining) {
            const size_t item = (size_t)remaining - 1;
            const uint8_t value = __atomic_load_n(from->data + (size_t)source_start + item, __ATOMIC_SEQ_CST);
            __atomic_store_n(to->data + (size_t)destination_start + item, value, __ATOMIC_SEQ_CST);
            UBE_VALUE_OBSERVE_COPY(1);
        }
    } else {
        for (int32_t item = 0; item < count; ++item) {
            const uint8_t value = __atomic_load_n(from->data + (size_t)source_start + (size_t)item, __ATOMIC_SEQ_CST);
            __atomic_store_n(to->data + (size_t)destination_start + (size_t)item, value, __ATOMIC_SEQ_CST);
            UBE_VALUE_OBSERVE_COPY(1);
        }
    }
    ube_gc_leave_lock();
    return 1;
}

/* The initial host is Windows. OS entry and external-resource ownership stay
   in the platform library; portable file progress/growth policy is UBE. */
#include "../std-lib/src/win-lib/file_primitives.c"

static char* ube_string_array_join_impl(void** value_reference, int32_t count,
                                        int managed) {
    if (count < 0) {
        fputs("UBE runtime: string join count cannot be negative\n", stderr);
        exit(65);
    }
    if (count == 0) {
        char* empty = managed ? ube_allocate_string_managed(0) : ube_allocate_string(0);
        if (empty == NULL) return NULL;
        empty[0] = '\0';
        return empty;
    }
    if (value_reference == NULL || *value_reference == NULL) {
        fputs("UBE runtime: string join array has not been dimensioned\n", stderr);
        exit(65);
    }

    const struct ube_array* array = *value_reference;
    const int64_t available = (int64_t)array->upper - array->lower + 1;
    if (array->element_size != sizeof(char*) || available < count) {
        fputs("UBE runtime: string join count exceeds the array bounds\n", stderr);
        exit(65);
    }

    const char* const* values = (const char* const*)array->data;
    size_t total = 0;
    for (int32_t index = 0; index < count; ++index) {
        const size_t length = values[index] != NULL ? strlen(values[index]) : 0;
        if (length > SIZE_MAX - total) {
            if (managed) return NULL;
            fputs("UBE runtime: joined string size overflow\n", stderr);
            exit(70);
        }
        total += length;
    }

    char* result = managed ? ube_allocate_string_managed(total) : ube_allocate_string(total);
    if (result == NULL) return NULL;
    size_t offset = 0;
    for (int32_t index = 0; index < count; ++index) {
        const char* value = values[index] != NULL ? values[index] : "";
        const size_t length = strlen(value);
        memcpy(result + offset, value, length);
        offset += length;
    }
    result[offset] = '\0';
    return result;
}

char* ube_string_array_join(void** value_reference, int32_t count) {
    return ube_string_array_join_impl(value_reference, count, 0);
}

char* ube_string_array_join_managed(void** value_reference, int32_t count) {
    return ube_string_array_join_impl(value_reference, count, 1);
}

void ube_print_i32(int32_t value) {
    printf("%" PRId32, value);
}

void ube_print_i64(int64_t value) {
    printf("%" PRId64, value);
}

void ube_print_f64(double value) {
    printf("%.17g", value);
}

void ube_print_string(const char* value) {
    fputs(value != NULL ? value : "", stdout);
}

void ube_print_newline(void) {
    fputc('\n', stdout);
    fflush(stdout);
}

void ube_invalid_for_step(void) {
    fputs("UBE runtime: For Step cannot be zero\n", stderr);
    exit(65);
}

static int32_t ube_integer_error(int32_t number, const char* operation) {
    ube_err_set(number, operation, "integer arithmetic");
    return 0;
}

/* Compiler-generated narrowing: preserve signedness, avoid LLVM poison and
   publish recoverable overflow without clearing an earlier Err on success. */
int64_t ube_checked_narrow_i64(int64_t value, int32_t bits, int32_t is_unsigned) {
    int64_t minimum = 0;
    int64_t maximum = 0;
    if (bits == 8 && is_unsigned == 1) {
        maximum = UINT8_MAX;
    } else if (bits == 16 && is_unsigned == 0) {
        minimum = INT16_MIN;
        maximum = INT16_MAX;
    } else if (bits == 32 && is_unsigned == 0) {
        minimum = INT32_MIN;
        maximum = INT32_MAX;
    } else {
        ube_err_set(5, "invalid integer representation", "integer conversion");
        return 0;
    }
    if (value < minimum || value > maximum) {
        ube_err_set(6, "integer conversion overflow", "integer conversion");
        return 0;
    }
    return value;
}

int32_t ube_checked_add_i32(int32_t left, int32_t right) {
    const int64_t result = (int64_t)left + right;
    if (result < INT32_MIN || result > INT32_MAX) return ube_integer_error(6, "addition overflow");
    return (int32_t)result;
}

int32_t ube_checked_sub_i32(int32_t left, int32_t right) {
    const int64_t result = (int64_t)left - right;
    if (result < INT32_MIN || result > INT32_MAX) return ube_integer_error(6, "subtraction overflow");
    return (int32_t)result;
}

int32_t ube_checked_mul_i32(int32_t left, int32_t right) {
    const int64_t result = (int64_t)left * right;
    if (result < INT32_MIN || result > INT32_MAX) return ube_integer_error(6, "multiplication overflow");
    return (int32_t)result;
}

int32_t ube_checked_div_i32(int32_t left, int32_t right) {
    if (right == 0) return ube_integer_error(11, "division by zero");
    if (left == INT32_MIN && right == -1) return ube_integer_error(6, "division overflow");
    return left / right;
}

int32_t ube_checked_mod_i32(int32_t left, int32_t right) {
    if (right == 0) return ube_integer_error(11, "remainder division by zero");
    if (left == INT32_MIN && right == -1) return 0;
    return left % right;
}

int32_t ube_checked_neg_i32(int32_t value) {
    if (value == INT32_MIN) return ube_integer_error(6, "negation overflow");
    return -value;
}

static char* ube_string_concat_impl(const char* left, const char* right,
                                    int managed) {
    if (left == NULL) left = "";
    if (right == NULL) right = "";
    const size_t left_length = strlen(left);
    const size_t right_length = strlen(right);
    if (right_length > SIZE_MAX - left_length) {
        if (managed) return NULL;
        fputs("UBE runtime: string size overflow\n", stderr);
        exit(70);
    }
    char* result = managed ? ube_allocate_string_managed(left_length + right_length)
                           : ube_allocate_string(left_length + right_length);
    if (result == NULL) return NULL;
    memcpy(result, left, left_length);
    memcpy(result + left_length, right, right_length + 1);
    return result;
}

char* ube_string_concat(const char* left, const char* right) {
    return ube_string_concat_impl(left, right, 0);
}

char* ube_string_concat_managed(const char* left, const char* right) {
    return ube_string_concat_impl(left, right, 1);
}

int32_t ube_string_compare(const char* left, const char* right) {
    if (left == NULL) left = "";
    if (right == NULL) right = "";
    const int comparison = strcmp(left, right);
    return comparison < 0 ? -1 : comparison > 0 ? 1 : 0;
}

static int ube_managed_string_length(const char* value, size_t* length) {
    if (value == NULL || length == NULL) return 0;
    ube_gc_enter_lock();
    struct ube_gc_header* header = ube_gc_header_from_value((void*)value);
    const int found = header != NULL && header->payload_size > 0 &&
        value[header->payload_size - 1u] == '\0';
    if (found) *length = header->payload_size - 1u;
    ube_gc_leave_lock();
    return found;
}

int32_t ube_string_length(const char* value) {
    size_t length = 0;
    if (value != NULL && !ube_managed_string_length(value, &length)) {
        length = strlen(value);
    }
    if (length > INT32_MAX) {
        fputs("UBE runtime: string is too long for a Long length\n", stderr);
        exit(70);
    }
    return (int32_t)length;
}

int32_t ube_string_byte_at(const char* value, int32_t index) {
    size_t length = 0;
    if (value != NULL && !ube_managed_string_length(value, &length)) {
        length = strlen(value);
    }
    if (index < 0 || (size_t)index >= length) {
        fprintf(stderr, "UBE runtime: string byte index out of range: %" PRId32 "\n", index);
        exit(65);
    }
    return (int32_t)(unsigned char)value[index];
}

static char* ube_string_slice_impl(const char* value, int32_t start,
                                   int32_t length, int managed) {
    if (value == NULL) value = "";
    const size_t source_length = strlen(value);
    if (start < 0 || length < 0 || (size_t)start > source_length ||
        (size_t)length > source_length - (size_t)start) {
        fputs("UBE runtime: string slice is out of range\n", stderr);
        exit(65);
    }
    char* result = managed ? ube_allocate_string_managed((size_t)length)
                           : ube_allocate_string((size_t)length);
    if (result == NULL) return NULL;
    memcpy(result, value + start, (size_t)length);
    result[length] = '\0';
    return result;
}

char* ube_string_slice(const char* value, int32_t start, int32_t length) {
    return ube_string_slice_impl(value, start, length, 0);
}

char* ube_string_slice_managed(const char* value, int32_t start, int32_t length) {
    return ube_string_slice_impl(value, start, length, 1);
}

int32_t ube_string_index_of(const char* value, const char* needle, int32_t start) {
    if (value == NULL) value = "";
    if (needle == NULL) needle = "";
    const size_t value_length = strlen(value);
    if (start < 0 || (size_t)start > value_length) {
        fprintf(stderr, "UBE runtime: string search start is out of range: %" PRId32 "\n", start);
        exit(65);
    }
    const char* found = strstr(value + start, needle);
    if (found == NULL) return -1;
    const size_t index = (size_t)(found - value);
    if (index > INT32_MAX) {
        fputs("UBE runtime: string search result exceeds Long range\n", stderr);
        exit(70);
    }
    return (int32_t)index;
}

static char* ube_string_from_byte_impl(int32_t value, int managed) {
    if (value < 1 || value > 255) {
        fprintf(stderr, "UBE runtime: byte value is outside 1..255: %" PRId32 "\n", value);
        exit(65);
    }
    char* result = managed ? ube_allocate_string_managed(1) : ube_allocate_string(1);
    if (result == NULL) return NULL;
    result[0] = (char)(unsigned char)value;
    result[1] = '\0';
    return result;
}

char* ube_string_from_byte(int32_t value) {
    return ube_string_from_byte_impl(value, 0);
}

char* ube_string_from_byte_managed(int32_t value) {
    return ube_string_from_byte_impl(value, 1);
}

static char* ube_long_to_string_impl(int32_t value, int managed) {
    char buffer[32];
    const int length = snprintf(buffer, sizeof(buffer), "%" PRId32, value);
    if (length < 0 || (size_t)length >= sizeof(buffer)) {
        fputs("UBE runtime: failed to format Long value\n", stderr);
        exit(70);
    }
    char* result = managed ? ube_allocate_string_managed((size_t)length)
                           : ube_allocate_string((size_t)length);
    if (result == NULL) return NULL;
    memcpy(result, buffer, (size_t)length + 1);
    return result;
}

char* ube_long_to_string(int32_t value) {
    return ube_long_to_string_impl(value, 0);
}

char* ube_long_to_string_managed(int32_t value) {
    return ube_long_to_string_impl(value, 1);
}

void ube_runtime_set_args(int32_t count, char** values) {
    ube_argument_count = count;
    ube_arguments = values;
}

int32_t ube_command_argument_count(void) {
    return ube_argument_count > 0 ? ube_argument_count - 1 : 0;
}

char* ube_command_argument(int32_t index) {
    if (index < 0 || index >= ube_command_argument_count() || ube_arguments == NULL) {
        fprintf(stderr, "UBE runtime: command argument index out of range: %" PRId32 "\n", index);
        exit(64);
    }
    return ube_arguments[index + 1];
}

char* ube_command_argument_managed(int32_t index) {
    const char* value = ube_command_argument(index);
    const size_t length = strlen(value);
    char* result = ube_allocate_string_managed(length);
    if (result == NULL) return NULL;
    memcpy(result, value, length + 1);
    return result;
}

static char* ube_read_all_text_impl(const char* path, int managed) {
    if (path == NULL) {
        fputs("UBE runtime: cannot read a null path\n", stderr);
        exit(66);
    }
    FILE* file = fopen(path, "rb");
    if (file == NULL) {
        fprintf(stderr, "UBE runtime: cannot open for reading: %s\n", path);
        exit(66);
    }
    if (fseek(file, 0, SEEK_END) != 0) {
        fprintf(stderr, "UBE runtime: cannot seek while reading: %s\n", path);
        fclose(file);
        exit(66);
    }
    const long end = ftell(file);
    if (end < 0 || fseek(file, 0, SEEK_SET) != 0) {
        fprintf(stderr, "UBE runtime: cannot determine file size: %s\n", path);
        fclose(file);
        exit(66);
    }
    char* result = managed ? ube_allocate_string_managed((size_t)end)
                           : ube_allocate_string((size_t)end);
    if (result == NULL) {
        fclose(file);
        return NULL;
    }
    const size_t read = fread(result, 1, (size_t)end, file);
    if (read != (size_t)end) {
        fprintf(stderr, "UBE runtime: failed while reading: %s\n", path);
        fclose(file);
        exit(66);
    }
    if (memchr(result, '\0', read) != NULL) {
        fprintf(stderr, "UBE runtime: text file contains an embedded NUL byte: %s\n", path);
        fclose(file);
        exit(66);
    }
    if (fclose(file) != 0) {
        fprintf(stderr, "UBE runtime: failed while reading: %s\n", path);
        exit(66);
    }
    result[read] = '\0';
    return result;
}

char* ube_read_all_text(const char* path) {
    return ube_read_all_text_impl(path, 0);
}

char* ube_read_all_text_managed(const char* path) {
    return ube_read_all_text_impl(path, 1);
}

/* RP8 resource validation is kept in the compiler substrate because source
   strings are text values and must never be used as an unbounded binary-file
   transport. The UBE-Resource 1 format is little-endian and canonical:
   8-byte magic, entry count, directory byte count, then sorted directory
   records followed by contiguous payloads. */
struct ube_sha256_state {
    uint32_t words[8];
    uint64_t bit_count;
    unsigned char block[64];
    size_t used;
};

static uint32_t ube_sha256_rotr(uint32_t value, unsigned count) {
    return (value >> count) | (value << (32u - count));
}

static void ube_sha256_transform(struct ube_sha256_state* state,
                                 const unsigned char block[64]) {
    static const uint32_t constants[64] = {
        0x428a2f98u,0x71374491u,0xb5c0fbcfu,0xe9b5dba5u,0x3956c25bu,0x59f111f1u,0x923f82a4u,0xab1c5ed5u,
        0xd807aa98u,0x12835b01u,0x243185beu,0x550c7dc3u,0x72be5d74u,0x80deb1feu,0x9bdc06a7u,0xc19bf174u,
        0xe49b69c1u,0xefbe4786u,0x0fc19dc6u,0x240ca1ccu,0x2de92c6fu,0x4a7484aau,0x5cb0a9dcu,0x76f988dau,
        0x983e5152u,0xa831c66du,0xb00327c8u,0xbf597fc7u,0xc6e00bf3u,0xd5a79147u,0x06ca6351u,0x14292967u,
        0x27b70a85u,0x2e1b2138u,0x4d2c6dfcu,0x53380d13u,0x650a7354u,0x766a0abbu,0x81c2c92eu,0x92722c85u,
        0xa2bfe8a1u,0xa81a664bu,0xc24b8b70u,0xc76c51a3u,0xd192e819u,0xd6990624u,0xf40e3585u,0x106aa070u,
        0x19a4c116u,0x1e376c08u,0x2748774cu,0x34b0bcb5u,0x391c0cb3u,0x4ed8aa4au,0x5b9cca4fu,0x682e6ff3u,
        0x748f82eeu,0x78a5636fu,0x84c87814u,0x8cc70208u,0x90befffau,0xa4506cebu,0xbef9a3f7u,0xc67178f2u
    };
    uint32_t schedule[64];
    for (size_t index = 0; index < 16; ++index) {
        schedule[index] = ((uint32_t)block[index * 4] << 24) |
            ((uint32_t)block[index * 4 + 1] << 16) |
            ((uint32_t)block[index * 4 + 2] << 8) | block[index * 4 + 3];
    }
    for (size_t index = 16; index < 64; ++index) {
        const uint32_t s0 = ube_sha256_rotr(schedule[index - 15], 7) ^
            ube_sha256_rotr(schedule[index - 15], 18) ^ (schedule[index - 15] >> 3);
        const uint32_t s1 = ube_sha256_rotr(schedule[index - 2], 17) ^
            ube_sha256_rotr(schedule[index - 2], 19) ^ (schedule[index - 2] >> 10);
        schedule[index] = schedule[index - 16] + s0 + schedule[index - 7] + s1;
    }
    uint32_t a=state->words[0], b=state->words[1], c=state->words[2], d=state->words[3];
    uint32_t e=state->words[4], f=state->words[5], g=state->words[6], h=state->words[7];
    for (size_t index = 0; index < 64; ++index) {
        const uint32_t s1 = ube_sha256_rotr(e, 6) ^ ube_sha256_rotr(e, 11) ^ ube_sha256_rotr(e, 25);
        const uint32_t choose = (e & f) ^ ((~e) & g);
        const uint32_t temporary1 = h + s1 + choose + constants[index] + schedule[index];
        const uint32_t s0 = ube_sha256_rotr(a, 2) ^ ube_sha256_rotr(a, 13) ^ ube_sha256_rotr(a, 22);
        const uint32_t majority = (a & b) ^ (a & c) ^ (b & c);
        const uint32_t temporary2 = s0 + majority;
        h=g; g=f; f=e; e=d+temporary1; d=c; c=b; b=a; a=temporary1+temporary2;
    }
    state->words[0]+=a; state->words[1]+=b; state->words[2]+=c; state->words[3]+=d;
    state->words[4]+=e; state->words[5]+=f; state->words[6]+=g; state->words[7]+=h;
}

static void ube_sha256_update(struct ube_sha256_state* state,
                              const unsigned char* data, size_t length) {
    while (length != 0) {
        size_t take = 64u - state->used;
        if (take > length) take = length;
        memcpy(state->block + state->used, data, take);
        state->used += take;
        state->bit_count += (uint64_t)take * 8u;
        data += take;
        length -= take;
        if (state->used == 64u) {
            ube_sha256_transform(state, state->block);
            state->used = 0;
        }
    }
}

static void ube_sha256(const unsigned char* data, size_t length,
                       unsigned char digest[32]) {
    struct ube_sha256_state state = {
        {0x6a09e667u,0xbb67ae85u,0x3c6ef372u,0xa54ff53au,
         0x510e527fu,0x9b05688cu,0x1f83d9abu,0x5be0cd19u}, 0, {0}, 0
    };
    ube_sha256_update(&state, data, length);
    const uint64_t bits = state.bit_count;
    state.block[state.used++] = 0x80u;
    if (state.used > 56u) {
        while (state.used < 64u) state.block[state.used++] = 0;
        ube_sha256_transform(&state, state.block);
        state.used = 0;
    }
    while (state.used < 56u) state.block[state.used++] = 0;
    for (size_t index = 0; index < 8; ++index)
        state.block[56u + index] = (unsigned char)(bits >> (56u - index * 8u));
    ube_sha256_transform(&state, state.block);
    for (size_t index = 0; index < 8; ++index) {
        digest[index * 4] = (unsigned char)(state.words[index] >> 24);
        digest[index * 4 + 1] = (unsigned char)(state.words[index] >> 16);
        digest[index * 4 + 2] = (unsigned char)(state.words[index] >> 8);
        digest[index * 4 + 3] = (unsigned char)state.words[index];
    }
}

static uint16_t ube_read_u16_le(const unsigned char* value) {
    return (uint16_t)((uint16_t)value[0] | ((uint16_t)value[1] << 8));
}

static uint32_t ube_read_u32_le(const unsigned char* value) {
    return (uint32_t)value[0] | ((uint32_t)value[1] << 8) |
        ((uint32_t)value[2] << 16) | ((uint32_t)value[3] << 24);
}

static uint64_t ube_read_u64_le(const unsigned char* value) {
    uint64_t result = 0;
    for (size_t index = 0; index < 8; ++index)
        result |= (uint64_t)value[index] << (index * 8u);
    return result;
}

static int32_t ube_compiler_validate_container(const char* path,
                                                const unsigned char magic[8]) {
    enum { UBE_RESOURCE_LIMIT = 67108864, UBE_RESOURCE_ENTRY_LIMIT = 1024 };
    if (path == NULL) return 1;
    FILE* file = fopen(path, "rb");
    if (file == NULL) return 2;
    int status = 3;
    unsigned char* bytes = NULL;
    if (fseek(file, 0, SEEK_END) != 0) goto done;
    const long measured = ftell(file);
    if (measured < 16 || measured > UBE_RESOURCE_LIMIT || fseek(file, 0, SEEK_SET) != 0) goto done;
    const size_t size = (size_t)measured;
    bytes = malloc(size);
    if (bytes == NULL) { status = 4; goto done; }
    if (fread(bytes, 1, size, file) != size) goto done;
    if (memcmp(bytes, magic, 8) != 0) goto done;
    const uint32_t count = ube_read_u32_le(bytes + 8);
    const uint32_t directory_size = ube_read_u32_le(bytes + 12);
    if (count == 0 || count > UBE_RESOURCE_ENTRY_LIMIT ||
        directory_size > size - 16u) goto done;
    size_t cursor = 16u;
    const size_t directory_end = cursor + directory_size;
    size_t payload_cursor = directory_end;
    const unsigned char* previous_name = NULL;
    uint16_t previous_name_length = 0;
    for (uint32_t entry = 0; entry < count; ++entry) {
        if (directory_end - cursor < 84u) goto done;
        const uint16_t name_length = ube_read_u16_le(bytes + cursor);
        const uint16_t flags = ube_read_u16_le(bytes + cursor + 2u);
        const uint64_t offset = ube_read_u64_le(bytes + cursor + 4u);
        const uint64_t length = ube_read_u64_le(bytes + cursor + 12u);
        const unsigned char* expected_hash = bytes + cursor + 20u;
        const unsigned char* name = bytes + cursor + 84u;
        if (name_length == 0 || name_length > 255 || flags != 0 ||
            (size_t)name_length > directory_end - cursor - 84u) goto done;
        for (uint16_t index = 0; index < name_length; ++index) {
            const unsigned char value = name[index];
            const int valid = (value >= 'A' && value <= 'Z') ||
                (value >= 'a' && value <= 'z') || (value >= '0' && value <= '9') ||
                value == '_' || value == '-' || value == '.';
            if (!valid) goto done;
        }
        if (previous_name != NULL) {
            const size_t common = previous_name_length < name_length ? previous_name_length : name_length;
            const int order = memcmp(previous_name, name, common);
            if (order > 0 || (order == 0 && previous_name_length >= name_length)) goto done;
        }
        if (offset != payload_cursor || length > size - payload_cursor) goto done;
        unsigned char digest[32];
        char digest_text[64];
        static const char hex[] = "0123456789ABCDEF";
        ube_sha256(bytes + payload_cursor, (size_t)length, digest);
        for (size_t index = 0; index < 32; ++index) {
            digest_text[index * 2] = hex[digest[index] >> 4];
            digest_text[index * 2 + 1] = hex[digest[index] & 15u];
        }
        if (memcmp(expected_hash, digest_text, sizeof(digest_text)) != 0) goto done;
        previous_name = name;
        previous_name_length = name_length;
        cursor += 84u + name_length;
        payload_cursor += (size_t)length;
    }
    if (cursor != directory_end || payload_cursor != size) goto done;
    status = 0;
done:
    free(bytes);
    if (fclose(file) != 0 && status == 0) status = 5;
    return status;
}

int32_t ube_compiler_validate_resource(const char* path) {
    static const unsigned char magic[8] = {'U','B','E','U','B','R','1','\n'};
    return ube_compiler_validate_container(path, magic);
}

char* ube_compiler_resource_llvm_escape(const char* path) {
    enum { UBE_RESOURCE_LIMIT = 67108864 };
    char* empty = NULL;
    if (path == NULL) goto failed;
    FILE* file = fopen(path, "rb");
    if (file == NULL) goto failed;
    if (fseek(file, 0, SEEK_END) != 0) { fclose(file); goto failed; }
    const long measured = ftell(file);
    if (measured <= 0 || measured > UBE_RESOURCE_LIMIT ||
        fseek(file, 0, SEEK_SET) != 0) { fclose(file); goto failed; }
    const size_t length = (size_t)measured;
    unsigned char* bytes = malloc(length);
    if (bytes == NULL) { fclose(file); goto failed; }
    if (fread(bytes, 1, length, file) != length || fclose(file) != 0) {
        free(bytes);
        goto failed;
    }
    if (length > (SIZE_MAX - 1u) / 3u) { free(bytes); goto failed; }
    char* result = ube_allocate_string(length * 3u);
    if (result == NULL) { free(bytes); goto failed; }
    static const char hex[] = "0123456789ABCDEF";
    for (size_t index = 0; index < length; ++index) {
        result[index * 3u] = '\\';
        result[index * 3u + 1u] = hex[bytes[index] >> 4];
        result[index * 3u + 2u] = hex[bytes[index] & 15u];
    }
    result[length * 3u] = '\0';
    free(bytes);
    return result;
failed:
    empty = ube_allocate_string(0);
    if (empty != NULL) empty[0] = '\0';
    return empty;
}

static int ube_bytes_equal(const unsigned char* value, uint16_t length,
                           const char* expected) {
    const size_t expected_length = strlen(expected);
    return length == expected_length && memcmp(value, expected, expected_length) == 0;
}

static int ube_metadata_has_line(const unsigned char* metadata, size_t length,
                                 const char* key, const char* value) {
    const size_t key_length = strlen(key);
    const size_t value_length = strlen(value);
    if (key_length > SIZE_MAX - value_length - 2u) return 0;
    const size_t wanted = key_length + value_length + 1u;
    for (size_t start = 0; start + wanted <= length; ++start) {
        if (start != 0 && metadata[start - 1] != '\n') continue;
        if (memcmp(metadata + start, key, key_length) != 0 ||
            metadata[start + key_length] != '=' ||
            memcmp(metadata + start + key_length + 1u, value, value_length) != 0) continue;
        const size_t end = start + wanted;
        if (end == length || metadata[end] == '\n') return 1;
    }
    return 0;
}

int32_t ube_compiler_validate_library_bundle(const char* path,
                                              const char* target,
                                              const char* required_version,
                                              const char* required_interface) {
    static const unsigned char magic[8] = {'U','B','E','U','B','L','1','\n'};
    const int32_t structural = ube_compiler_validate_container(path, magic);
    if (structural != 0) return structural;
    if (target == NULL || target[0] == '\0' ||
        required_version == NULL || required_version[0] == '\0' ||
        required_interface == NULL || strlen(required_interface) != 64u) return 6;

    FILE* file = fopen(path, "rb");
    if (file == NULL) return 2;
    int status = 7;
    unsigned char* bytes = NULL;
    if (fseek(file, 0, SEEK_END) != 0) goto done;
    const long measured = ftell(file);
    if (measured < 16 || fseek(file, 0, SEEK_SET) != 0) goto done;
    const size_t size = (size_t)measured;
    bytes = malloc(size);
    if (bytes == NULL) { status = 4; goto done; }
    if (fread(bytes, 1, size, file) != size) goto done;
    const uint32_t count = ube_read_u32_le(bytes + 8);
    const size_t directory_end = 16u + ube_read_u32_le(bytes + 12);
    if (count != 3 || directory_end > size) goto done;
    size_t cursor = 16u;
    const unsigned char* metadata = NULL;
    size_t metadata_length = 0;
    int saw_artifact = 0, saw_interface = 0, saw_manifest = 0;
    int interface_hash_matches = 0;
    for (uint32_t entry = 0; entry < count; ++entry) {
        if (directory_end - cursor < 84u) goto done;
        const uint16_t name_length = ube_read_u16_le(bytes + cursor);
        const uint64_t offset = ube_read_u64_le(bytes + cursor + 4u);
        const uint64_t length = ube_read_u64_le(bytes + cursor + 12u);
        if (name_length > directory_end - cursor - 84u ||
            offset > size || length > size - (size_t)offset) goto done;
        const unsigned char* name = bytes + cursor + 84u;
        if (ube_bytes_equal(name, name_length, "Artifact")) saw_artifact = 1;
        else if (ube_bytes_equal(name, name_length, "Interface")) {
            saw_interface = 1;
            interface_hash_matches =
                memcmp(bytes + cursor + 20u, required_interface, 64u) == 0;
        }
        else if (ube_bytes_equal(name, name_length, "Manifest")) {
            saw_manifest = 1;
            metadata = bytes + (size_t)offset;
            metadata_length = (size_t)length;
        } else goto done;
        cursor += 84u + name_length;
    }
    if (!saw_artifact || !saw_interface || !interface_hash_matches ||
        !saw_manifest || metadata == NULL) goto done;
    if (!ube_metadata_has_line(metadata, metadata_length,
                               "Format", "UBE-LibraryBundle-Metadata-1") ||
        !ube_metadata_has_line(metadata, metadata_length,
                               "Language", "1.0") ||
        !ube_metadata_has_line(metadata, metadata_length,
                               "IntrinsicABI", "ube-intrinsic-abi-1") ||
        !ube_metadata_has_line(metadata, metadata_length, "Target", target) ||
        !ube_metadata_has_line(metadata, metadata_length, "Version", required_version) ||
        !ube_metadata_has_line(metadata, metadata_length,
                               "InterfaceSHA256", required_interface)) goto done;
    status = 0;
done:
    free(bytes);
    if (fclose(file) != 0 && status == 0) status = 5;
    return status;
}

int32_t ube_write_all_text(const char* path, const char* contents) {
    static LONG temporary_sequence;
    if (path == NULL || path[0] == '\0') {
        fputs("UBE runtime: cannot open for writing: invalid path\n", stderr);
        return 73;
    }
    if (contents == NULL) contents = "";

    const size_t path_length = strlen(path);
    if (path_length > 1048576 || path_length > SIZE_MAX - 64) {
        fprintf(stderr, "UBE runtime: cannot open for writing: %s\n", path);
        return 73;
    }
    char* temporary_path = malloc(path_length + 64);
    if (temporary_path == NULL) {
        fprintf(stderr, "UBE runtime: failed while writing: %s\n", path);
        return 74;
    }

    HANDLE file = INVALID_HANDLE_VALUE;
    for (int attempt = 0; attempt < 32; ++attempt) {
        const LONG sequence = InterlockedIncrement(&temporary_sequence);
        const int result = snprintf(temporary_path, path_length + 64,
                                    "%s.ube-tmp-%lu-%ld", path,
                                    (unsigned long)GetCurrentProcessId(),
                                    (long)sequence);
        if (result < 0 || (size_t)result >= path_length + 64) {
            free(temporary_path);
            fprintf(stderr, "UBE runtime: cannot open for writing: %s\n", path);
            return 73;
        }
        file = CreateFileA(temporary_path, GENERIC_WRITE, 0, NULL, CREATE_NEW,
                           FILE_ATTRIBUTE_TEMPORARY, NULL);
        if (file != INVALID_HANDLE_VALUE) break;
        if (GetLastError() != ERROR_FILE_EXISTS &&
            GetLastError() != ERROR_ALREADY_EXISTS) {
            free(temporary_path);
            fprintf(stderr, "UBE runtime: cannot open for writing: %s\n", path);
            return 73;
        }
    }
    if (file == INVALID_HANDLE_VALUE) {
        free(temporary_path);
        fprintf(stderr, "UBE runtime: cannot open for writing: %s\n", path);
        return 73;
    }

    const size_t length = strlen(contents);
    size_t offset = 0;
    int write_failed = 0;
    while (offset < length) {
        const size_t remaining = length - offset;
        const DWORD requested = remaining > 0x40000000u
            ? 0x40000000u : (DWORD)remaining;
        DWORD written = 0;
        if (!WriteFile(file, contents + offset, requested, &written, NULL) ||
            written != requested) {
            write_failed = 1;
            break;
        }
        offset += written;
    }
    if (!write_failed && !FlushFileBuffers(file)) write_failed = 1;
    if (!CloseHandle(file)) write_failed = 1;
    if (write_failed) {
        DeleteFileA(temporary_path);
        free(temporary_path);
        fprintf(stderr, "UBE runtime: failed while writing: %s\n", path);
        return 74;
    }
    if (!MoveFileExA(temporary_path, path,
                     MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) {
        DeleteFileA(temporary_path);
        free(temporary_path);
        fprintf(stderr, "UBE runtime: cannot open for writing: %s\n", path);
        return 73;
    }
    free(temporary_path);
    return 0;
}

int32_t ube_compiler_run_tool(const char* executable_path,
                              void** argument_array_reference,
                              int32_t argument_count) {
    if (executable_path == NULL || executable_path[0] == '\0' || argument_count < 0) {
        return -1;
    }
    if (argument_count > 4096) {
        return -1;
    }

    const struct ube_array* arguments = NULL;
    if (argument_count > 0) {
        if (argument_array_reference == NULL || *argument_array_reference == NULL) {
            return -1;
        }
        arguments = *argument_array_reference;
        const int64_t available = (int64_t)arguments->upper - arguments->lower + 1;
        if (arguments->lower != 0 || arguments->element_size != sizeof(char*) ||
            available < argument_count) {
            return -1;
        }
    }

    /* The MinGW _spawnv adapter supplies the child's executable identity;
       this array contains only the distinct user arguments. */
    const char* const* values = arguments != NULL
        ? (const char* const*)arguments->data : NULL;
    size_t command_capacity = strlen(executable_path) * 2 + 4;
    for (int32_t index = 0; index < argument_count; ++index) {
        const char* value = values[index] != NULL ? values[index] : "";
        const size_t length = strlen(value);
        if (length > 524288 || command_capacity > 1048576 - length * 2 - 4) {
            return -1;
        }
        command_capacity += length * 2 + 4;
    }
    char* command_line = malloc(command_capacity);
    if (command_line == NULL) {
        return -2;
    }

    size_t output = 0;
    const char* parts[2] = { executable_path, NULL };
    for (int32_t part_index = -1; part_index < argument_count; ++part_index) {
        const char* value = part_index < 0 ? parts[0]
            : (values[part_index] != NULL ? values[part_index] : "");
        if (output != 0) command_line[output++] = ' ';
        command_line[output++] = '"';
        size_t backslashes = 0;
        for (size_t input = 0;; ++input) {
            const char current = value[input];
            if (current == '\\') {
                ++backslashes;
                continue;
            }
            if (current == '"' || current == '\0') {
                for (size_t copy = 0; copy < backslashes * 2; ++copy) {
                    command_line[output++] = '\\';
                }
                backslashes = 0;
                if (current == '"') {
                    command_line[output++] = '\\';
                    command_line[output++] = '"';
                    continue;
                }
                break;
            }
            while (backslashes > 0) {
                command_line[output++] = '\\';
                --backslashes;
            }
            command_line[output++] = current;
        }
        command_line[output++] = '"';
    }
    command_line[output] = '\0';

    STARTUPINFOA startup;
    PROCESS_INFORMATION process;
    memset(&startup, 0, sizeof(startup));
    memset(&process, 0, sizeof(process));
    startup.cb = sizeof(startup);
    const BOOL started = CreateProcessA(executable_path, command_line, NULL, NULL,
                                        TRUE, 0, NULL, NULL, &startup, &process);
    free(command_line);
    if (!started) return -2;
    const DWORD wait_result = WaitForSingleObject(process.hProcess, INFINITE);
    DWORD exit_code = 0;
    const BOOL got_exit = wait_result == WAIT_OBJECT_0 &&
                          GetExitCodeProcess(process.hProcess, &exit_code);
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    if (!got_exit) return -2;
    if (exit_code > INT32_MAX) return -3;
    return (int32_t)exit_code;
}

int32_t ube_compiler_delete_file(const char* path) {
    if (path == NULL || path[0] == '\0') return -1;
    if (DeleteFileA(path)) return 0;
    const DWORD error = GetLastError();
    if (error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND) return 0;
    return -2;
}

int32_t ube_compiler_monotonic_milliseconds(void) {
    static LARGE_INTEGER frequency = {0};
    static LARGE_INTEGER origin = {0};
    LARGE_INTEGER current;
    if (frequency.QuadPart == 0) {
        if (!QueryPerformanceFrequency(&frequency) || frequency.QuadPart <= 0 ||
            !QueryPerformanceCounter(&origin)) {
            frequency.QuadPart = -1;
            return -1;
        }
    }
    if (frequency.QuadPart < 0 || !QueryPerformanceCounter(&current) ||
        current.QuadPart < origin.QuadPart) {
        return -1;
    }
    const uint64_t ticks = (uint64_t)(current.QuadPart - origin.QuadPart);
    const uint64_t milliseconds = (ticks / (uint64_t)frequency.QuadPart) * UINT64_C(1000) +
        ((ticks % (uint64_t)frequency.QuadPart) * UINT64_C(1000)) /
            (uint64_t)frequency.QuadPart;
    return milliseconds <= (uint64_t)INT32_MAX ? (int32_t)milliseconds : INT32_MAX;
}

int32_t ube_compiler_process_cpu_milliseconds(void) {
    FILETIME created;
    FILETIME exited;
    FILETIME kernel;
    FILETIME user;
    if (!GetProcessTimes(GetCurrentProcess(), &created, &exited, &kernel, &user)) return -1;
    ULARGE_INTEGER kernel_value;
    ULARGE_INTEGER user_value;
    kernel_value.LowPart = kernel.dwLowDateTime;
    kernel_value.HighPart = kernel.dwHighDateTime;
    user_value.LowPart = user.dwLowDateTime;
    user_value.HighPart = user.dwHighDateTime;
    const uint64_t milliseconds =
        (kernel_value.QuadPart + user_value.QuadPart) / UINT64_C(10000);
    return milliseconds <= (uint64_t)INT32_MAX ? (int32_t)milliseconds : INT32_MAX;
}

int32_t ube_compiler_peak_working_set_kilobytes(void) {
    PROCESS_MEMORY_COUNTERS counters;
    memset(&counters, 0, sizeof(counters));
    counters.cb = sizeof(counters);
    if (!K32GetProcessMemoryInfo(GetCurrentProcess(), &counters, sizeof(counters))) return -1;
    const SIZE_T kibibytes = counters.PeakWorkingSetSize / 1024u;
    return kibibytes <= (SIZE_T)INT32_MAX ? (int32_t)kibibytes : INT32_MAX;
}
