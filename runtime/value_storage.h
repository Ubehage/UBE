#ifndef UBE_VALUE_STORAGE_H
#define UBE_VALUE_STORAGE_H
#include <stddef.h>
#include <stdint.h>

/* Compiler-only, target-native layout. Algorithms and semantic policy live in
   UBE. Kind: 0 scalar, 1 independent array, 2 field record, 3 shared reference.
   Arrays have one field describing their element, at offset zero. Root offsets
   enumerate pointer slots within one value, never arbitrary integer bytes. */
struct ube_value_layout;
struct ube_value_field {
    size_t offset;
    const struct ube_value_layout* layout;
};
struct ube_value_layout {
    size_t size;
    int32_t kind;
    int32_t field_count;
    const struct ube_value_field* fields;
    size_t root_count;
    const size_t* root_offsets;
};

/* Layouts and their field/root tables are immutable compiler-owned metadata
   lasting through every registered root/allocation that refers to them.
   Values use native, properly aligned scalar and pointer storage. */

/* Register caller-owned root storage (ube_gc_root_storage_size bytes) for a
   zero-initialized or valid live value. Keep both alive until root_leave.
   Rootless layouts succeed without registration; root_leave tolerates absence.
   Capacity failure returns zero and sets thread-local Err 7. */
int32_t ube_value_root_enter(void*, void*, const struct ube_value_layout*);

/* Snapshot copies scalar fields and managed references, borrowing the same
   arrays; it never creates an independently owned mutable value. The caller
   roots both values and any containing allocation throughout their use.
   Use only for compiler temporaries/publication, never ordinary assignment.
   Small rootless records allocate nothing and use atomic scalar accesses
   without the collector lock. Managed snapshots synchronize with collection. */
int32_t ube_value_snapshot(void*, const void*, const struct ube_value_layout*);

/* Compiler-private, unshared temporary/fallback/result storage only. Zero is
   allocation-free and preserves Err; registered managed slots are cleared
   under the collector lock. Read snapshots and returns fresh status, clearing
   its private destination to neutral on failure while retaining that Err.
   Public assignment/snapshot destinations instead remain unchanged on failure. */
void ube_value_zero(void*, const struct ube_value_layout*);
int32_t ube_value_read(void*, const void*, const struct ube_value_layout*);

/* Ordinary assignment prepares independent mutable array copies, publishes
   only after complete success, and immediately reclaims partial construction
   on failure. Zero is fresh failure status; Err 7 reports memory/work bounds.
   A successful call preserves earlier Err. Managed transactions synchronize
   with collection; independent scalar values need no global lock. */
int32_t ube_value_assign(void*, const void*, const struct ube_value_layout*);

/* Replace a rooted array slot; preserve requests independent copies of the
   intersecting bounds. New elements are neutral. Failure preserves the old
   slot and sets Err 5/6/7/9 for invalid request/overflow/memory/bounds.
   Resize uses zero-based count and releases the slot for count zero. */
int32_t ube_value_try_redim(void**, int32_t, int32_t,
                           const struct ube_value_layout*, int32_t);
int32_t ube_value_try_resize(void**, int32_t,
                            const struct ube_value_layout*, int32_t);
int32_t ube_value_array_length(void* const*);

/* Copy zero-based payload spans between rooted Byte-array holders. Valid spans
   always succeed without allocation/workspace and preserve Err; overlapping
   spans behave like memmove with atomic bytes. Zero count permits neutral empty
   arrays and starts at each array's length. Invalid holder/count/stride sets
   Err 5; invalid starts/spans set Err 9. Failure leaves destination unchanged.
   Array lifetimes/stores synchronize with collection; shared mutable callers
   still require synchronization for a coherent multi-byte user transaction. */
int32_t ube_value_copy_bytes(void* const*, int32_t, void* const*, int32_t, int32_t);

/* Resolve one borrowed element and atomically publish its owner in keep_alive.
   Caller roots keep_alive and element-sized fallback before this call and
   until its use ends. Owner replacement cannot invalidate the borrow. Invalid
   bounds return neutral fallback with Err 9. Accesses synchronize with GC;
   mutable values remain owned by one caller or require user synchronization. */
void* ube_value_array_element(void* const*, int32_t, void**, void*, const struct ube_value_layout*);
#endif
