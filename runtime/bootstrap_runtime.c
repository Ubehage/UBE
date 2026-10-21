#include <inttypes.h>
#include <limits.h>
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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
    unsigned char data[];
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
static INIT_ONCE ube_gc_lock_once = INIT_ONCE_STATIC_INIT;
static CRITICAL_SECTION ube_gc_lock;
static void ube_gc_release_all(void);
static char* ube_allocate_string_managed(size_t length);

static BOOL CALLBACK ube_gc_initialize_lock(PINIT_ONCE once, PVOID parameter,
                                             PVOID* context) {
    (void)once;
    (void)parameter;
    (void)context;
    InitializeCriticalSection(&ube_gc_lock);
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
            ube_library_set_diagnostic_text("library is shutting down");
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
                if (!ube_gc_push_value(*root->slot, &work, &count, &capacity)) {
                    free(work);
                    return 0;
                }
            } else {
                const unsigned char* base = (const unsigned char*)root->slot;
                for (size_t index = 0; index < root->slot_count; ++index) {
                    void* child = NULL;
                    memcpy(&child, base + root->slot_offsets[index], sizeof(child));
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

static void ube_gc_controlled_fatal(const char* message) {
    fputs("UBE managed support: ", stderr);
    fputs(message, stderr);
    fputc('\n', stderr);
    fflush(stderr);
    ExitProcess(70);
}

int32_t ube_gc_collect(void) {
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
        ube_gc_collecting = 0;
        ube_gc_controlled_fatal("insufficient bookkeeping memory while tracing");
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

int32_t ube_gc_safe_point(void) {
    ube_gc_enter_lock();
    const int should_collect = !ube_gc_collecting && !ube_gc_shutdown &&
        ube_gc_live_bytes >= ube_gc_threshold;
    ube_gc_leave_lock();
    if (!should_collect) return 0;
    return ube_gc_collect();
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
        (void)ube_gc_collect();
    }
    struct ube_gc_header* header = NULL;
    if (ube_gc_test_allocation_failures != 0) {
        ube_gc_test_allocation_failures -= 1;
    } else {
        header = calloc(1, sizeof(*header) + layout->size);
    }
    if (header == NULL) {
        (void)ube_gc_collect();
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
        (void)ube_gc_collect();
    }
    struct ube_gc_header* header = NULL;
    if (ube_gc_test_allocation_failures != 0) {
        ube_gc_test_allocation_failures -= 1;
    } else {
        header = calloc(1, sizeof(*header) + size);
    }
    if (header == NULL) {
        (void)ube_gc_collect();
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
    *slot = value;
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
    if (value == NULL || result == NULL) return 0;
    const unsigned char* cursor = (const unsigned char*)value;
    while (*cursor == ' ' || *cursor == '\t') ++cursor;
    int negative = 0;
    if (*cursor == '-' || *cursor == '+') {
        negative = *cursor == '-';
        ++cursor;
    }
    if (*cursor < '0' || *cursor > '9') return 0;
    uint64_t magnitude = 0;
    while (*cursor >= '0' && *cursor <= '9') {
        const uint32_t digit = (uint32_t)(*cursor - '0');
        const uint64_t limit = negative ? UINT64_C(2147483648) : UINT64_C(2147483647);
        if (magnitude > (limit - digit) / 10) return 0;
        magnitude = magnitude * 10 + digit;
        ++cursor;
    }
    while (*cursor == ' ' || *cursor == '\t') ++cursor;
    if (*cursor != '\0') return 0;
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

static void ube_integer_error(const char* operation) {
    fprintf(stderr, "UBE runtime: Long %s failed\n", operation);
    exit(65);
}

int32_t ube_checked_add_i32(int32_t left, int32_t right) {
    const int64_t result = (int64_t)left + right;
    if (result < INT32_MIN || result > INT32_MAX) ube_integer_error("addition overflow");
    return (int32_t)result;
}

int32_t ube_checked_sub_i32(int32_t left, int32_t right) {
    const int64_t result = (int64_t)left - right;
    if (result < INT32_MIN || result > INT32_MAX) ube_integer_error("subtraction overflow");
    return (int32_t)result;
}

int32_t ube_checked_mul_i32(int32_t left, int32_t right) {
    const int64_t result = (int64_t)left * right;
    if (result < INT32_MIN || result > INT32_MAX) ube_integer_error("multiplication overflow");
    return (int32_t)result;
}

int32_t ube_checked_div_i32(int32_t left, int32_t right) {
    if (right == 0) ube_integer_error("division by zero");
    if (left == INT32_MIN && right == -1) ube_integer_error("division overflow");
    return left / right;
}

int32_t ube_checked_mod_i32(int32_t left, int32_t right) {
    if (right == 0) ube_integer_error("remainder division by zero");
    if (left == INT32_MIN && right == -1) return 0;
    return left % right;
}

int32_t ube_checked_neg_i32(int32_t value) {
    if (value == INT32_MIN) ube_integer_error("negation overflow");
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

int32_t ube_string_length(const char* value) {
    const size_t length = value != NULL ? strlen(value) : 0;
    if (length > INT32_MAX) {
        fputs("UBE runtime: string is too long for a Long length\n", stderr);
        exit(70);
    }
    return (int32_t)length;
}

int32_t ube_string_byte_at(const char* value, int32_t index) {
    const size_t length = value != NULL ? strlen(value) : 0;
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
