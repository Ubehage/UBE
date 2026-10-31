#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include "../../../runtime/value_storage.h"

extern size_t ube_gc_root_storage_size(void), ube_gc_live_allocation_bytes(void);
extern int32_t ube_gc_root_leave(void*), ube_gc_collect(void), ube_err_number(void);
extern void ube_err_set(int32_t,const char*,const char*);
extern void ube_gc_test_fail_next_allocations(uint32_t), ube_gc_test_fail_next_trace_allocations(uint32_t);
extern void* ube_array_element(void*, int32_t);

/* Test-only failure injection through the runtime's real allocator call sites. */
static size_t malloc_calls, calloc_calls, realloc_calls, failure_start, failures_left;
static size_t copied_payload_bytes, copied_payload_leaves;
void probe_value_copy(size_t bytes) {
    __atomic_add_fetch(&copied_payload_bytes,bytes,__ATOMIC_SEQ_CST);
    __atomic_add_fetch(&copied_payload_leaves,1,__ATOMIC_SEQ_CST);
}
void* probe_malloc(size_t n) { __atomic_add_fetch(&malloc_calls,1,__ATOMIC_SEQ_CST); return malloc(n); }
void* probe_calloc(size_t n, size_t size) {
    size_t call = __atomic_add_fetch(&calloc_calls,1,__ATOMIC_SEQ_CST);
    if (failures_left && call >= failure_start) { --failures_left; return NULL; }
    return calloc(n,size);
}
void* probe_realloc(void* p, size_t n) { __atomic_add_fetch(&realloc_calls,1,__ATOMIC_SEQ_CST); return realloc(p,n); }
void probe_free(void* p) { free(p); }

static unsigned assertions;
#define CHECK(condition) do { ++assertions; if (!(condition)) { fprintf(stderr,"storage assertion %u line %d failed: %s\n",assertions,__LINE__,#condition); return 1; } } while (0)
static const struct ube_value_layout byte_type = {1,0,0,NULL,0,NULL};
static const struct ube_value_layout long_type = {4,0,0,NULL,0,NULL};
static const size_t pointer_root[] = {0};
static const struct ube_value_field byte_element[] = {{0,&byte_type}};
static const struct ube_value_layout byte_array = {sizeof(void*),1,1,byte_element,1,pointer_root};
struct bytes_record { int32_t tag; void* bytes; };
static const struct ube_value_field record_fields[] = {{offsetof(struct bytes_record,tag),&long_type},{offsetof(struct bytes_record,bytes),&byte_array}};
static const size_t record_roots[] = {offsetof(struct bytes_record,bytes)};
static const struct ube_value_layout record_type = {sizeof(struct bytes_record),2,2,record_fields,1,record_roots};
struct pair_record { void* first; void* second; };
static const struct ube_value_field pair_fields[] = {{offsetof(struct pair_record,first),&byte_array},{offsetof(struct pair_record,second),&byte_array}};
static const size_t pair_roots[] = {0,sizeof(void*)};
static const struct ube_value_layout pair_type = {sizeof(struct pair_record),2,2,pair_fields,2,pair_roots};
static const struct ube_value_field record_element[] = {{0,&record_type}};
static const struct ube_value_layout record_array = {sizeof(void*),1,1,record_element,1,pointer_root};
struct scalar_record { int32_t fields[4]; };
static const struct ube_value_field scalar_fields[] = {{0,&long_type},{4,&long_type},{8,&long_type},{12,&long_type}};
static const struct ube_value_layout scalar_type = {16,2,4,scalar_fields,0,NULL};
typedef union { uint64_t alignment; unsigned char bytes[32]; } root_storage;
static void write_byte(void* array, int32_t index, uint8_t value) {
    __atomic_store_n((uint8_t*)ube_array_element(array,index),value,__ATOMIC_SEQ_CST);
}
static uint8_t read_byte(void* array, int32_t index) {
    return __atomic_load_n((uint8_t*)ube_array_element(array,index),__ATOMIC_SEQ_CST);
}
static DWORD WINAPI collect_after_trace_failure(LPVOID result) {
    __atomic_store_n((int32_t*)result,ube_gc_collect(),__ATOMIC_SEQ_CST);
    return 0;
}
static int check_byte_copy(void) {
    void *source = NULL, *destination = NULL, *wrong_stride = NULL, *empty = NULL;
    root_storage sr = {0}, dr = {0}, wr = {0};
    CHECK(ube_value_root_enter(&sr,&source,&byte_array));
    CHECK(ube_value_root_enter(&dr,&destination,&byte_array));
    CHECK(ube_value_root_enter(&wr,&wrong_stride,&byte_array));
    CHECK(ube_value_try_resize(&source,6,&byte_type,0));
    CHECK(ube_value_try_resize(&destination,6,&byte_type,0));
    CHECK(ube_value_try_resize(&wrong_stride,2,&long_type,0));
    for (int32_t i = 0; i < 6; ++i) { write_byte(source,i,(uint8_t)(i + 1)); write_byte(destination,i,9); }
    const uint8_t initial[] = {1,2,3,4,5,6}, backward[] = {1,1,2,3,4,5}, forward[] = {1,2,3,4,5,5};
    ube_err_set(77,"pre-existing","managed byte copy test");
    size_t observed_before = copied_payload_bytes, leaves_before = copied_payload_leaves;
    size_t malloc_before = malloc_calls, calloc_before = calloc_calls, realloc_before = realloc_calls;
    /* Valid byte spans must work without consulting either allocation path. */
    failure_start = calloc_calls + 1; failures_left = 2;
    ube_gc_test_fail_next_allocations(2);
    CHECK(ube_value_copy_bytes(&source,0,&destination,0,6));
    CHECK(memcmp(ube_array_element(destination,0),initial,6) == 0);
    CHECK(ube_err_number() == 77);
    CHECK(ube_value_copy_bytes(&source,0,&source,1,5));
    CHECK(memcmp(ube_array_element(source,0),backward,6) == 0);
    CHECK(ube_value_copy_bytes(&source,1,&source,0,5));
    CHECK(memcmp(ube_array_element(source,0),forward,6) == 0);
    CHECK(ube_value_copy_bytes(&source,0,&source,0,6));
    CHECK(memcmp(ube_array_element(source,0),forward,6) == 0);
    CHECK(copied_payload_bytes - observed_before == 22 && copied_payload_leaves - leaves_before == 22);
    CHECK(ube_value_copy_bytes(&empty,0,&empty,0,0));
    CHECK(ube_value_copy_bytes(&source,6,&destination,6,0));
    CHECK(ube_value_copy_bytes(&source,6,&empty,0,0) && ube_err_number() == 77);
    CHECK(!ube_value_copy_bytes(&source,-1,&destination,0,1) && ube_err_number() == 9);
    CHECK(!ube_value_copy_bytes(&source,0,&destination,-1,1) && ube_err_number() == 9);
    CHECK(!ube_value_copy_bytes(&source,5,&destination,0,INT32_MAX) && ube_err_number() == 9);
    CHECK(!ube_value_copy_bytes(&source,INT32_MAX,&destination,0,1) && ube_err_number() == 9);
    CHECK(!ube_value_copy_bytes(&empty,0,&destination,0,1) && ube_err_number() == 9);
    CHECK(!ube_value_copy_bytes(&source,0,&empty,0,1) && ube_err_number() == 9);
    CHECK(!ube_value_copy_bytes(&empty,1,&empty,0,0) && ube_err_number() == 9);
    CHECK(!ube_value_copy_bytes(&source,0,&destination,0,-1) && ube_err_number() == 5);
    CHECK(!ube_value_copy_bytes(NULL,0,&destination,0,1) && ube_err_number() == 5);
    CHECK(!ube_value_copy_bytes(&source,0,NULL,0,1) && ube_err_number() == 5);
    CHECK(!ube_value_copy_bytes(&wrong_stride,0,&destination,0,0) && ube_err_number() == 5);
    CHECK(!ube_value_copy_bytes(&source,0,&wrong_stride,0,0) && ube_err_number() == 5);
    CHECK(memcmp(ube_array_element(destination,0),initial,6) == 0 && memcmp(ube_array_element(source,0),forward,6) == 0);
    CHECK(copied_payload_bytes - observed_before == 22 && copied_payload_leaves - leaves_before == 22);
    CHECK(malloc_calls == malloc_before && calloc_calls == calloc_before && realloc_calls == realloc_before && failures_left == 2);
    failures_left = 0;
    ube_gc_test_fail_next_allocations(0);
    CHECK(ube_gc_root_leave(&sr) && ube_gc_root_leave(&dr) && ube_gc_root_leave(&wr));
    CHECK(ube_gc_collect() == 1 && ube_gc_live_allocation_bytes() == 0);
    return 0;
}
/* Each worker owns its mutable values. Simultaneous explicit collections must
   preserve all workers' registered roots and their independent Err records. */
static DWORD WINAPI independent_worker(void* argument) {
    uintptr_t number = (uintptr_t)argument;
    void *source = NULL, *copy = NULL;
    root_storage sr = {0}, cr = {0};
    DWORD failed = 0;
    if (!ube_value_root_enter(&sr,&source,&byte_array) ||
        !ube_value_root_enter(&cr,&copy,&byte_array)) failed = 1;
    ube_err_set((int32_t)(100 + number),"worker","managed value test");
    for (unsigned round = 0; round < 128 && !failed; ++round) {
        struct scalar_record scalar = {{(int32_t)number,(int32_t)round,-13,INT32_MAX}}, scalar_copy = {{0}};
        if (!ube_value_assign(&scalar_copy,&scalar,&scalar_type) ||
            memcmp(&scalar_copy,&scalar,sizeof(scalar)) != 0) { failed = 5; break; }
        if (!ube_value_try_resize(&source,33,&byte_type,0)) { failed = 2; break; }
        write_byte(source,0,(uint8_t)number);
        write_byte(source,32,(uint8_t)round);
        if (!ube_value_assign(&copy,&source,&byte_array)) { failed = 3; break; }
        write_byte(source,0,255);
        (void)ube_gc_collect();
        if (read_byte(copy,0) != number || read_byte(copy,32) != (uint8_t)round ||
            ube_err_number() != (int32_t)(100 + number)) failed = 4;
    }
    (void)ube_gc_root_leave(&cr);
    (void)ube_gc_root_leave(&sr);
    return failed;
}
static int check_root_limit(void) {
    enum { maximum = 1048576 };
    root_storage* roots = calloc(maximum,sizeof(*roots));
    void* slot = NULL;
    CHECK(roots != NULL);
    size_t entered = 0;
    while (entered < maximum && ube_value_root_enter(&roots[entered],&slot,&byte_array)) ++entered;
    CHECK(entered == maximum);
    root_storage extra = {0};
    CHECK(!ube_value_root_enter(&extra,&slot,&byte_array) && ube_err_number() == 7);
    CHECK(!ube_gc_root_leave(&extra));
    CHECK(!ube_value_try_resize(&slot,1,&byte_type,0));
    CHECK(slot == NULL && ube_err_number() == 7);
    while (entered) CHECK(ube_gc_root_leave(&roots[--entered]));
    CHECK(ube_value_root_enter(&extra,&slot,&byte_array));
    CHECK(ube_value_try_resize(&slot,1,&byte_type,0));
    CHECK(ube_gc_root_leave(&extra));
    CHECK(ube_gc_collect() == 1 && ube_gc_live_allocation_bytes() == 0);
    free(roots);
    printf("PASS managed root limit:1048576\n");
    return 0;
}
int main(int argc, char** argv) {
    CHECK(ube_gc_root_storage_size() == sizeof(root_storage));
    CHECK(ube_gc_live_allocation_bytes() == 0);
    if (argc == 2 && strcmp(argv[1],"roots") == 0) return check_root_limit();
    if (argc == 1) CHECK(check_byte_copy() == 0);
    struct scalar_record scalar = {{1,-2,3,INT32_MIN}}, scalar_copy = {{0}};
    size_t malloc_before = malloc_calls, calloc_before = calloc_calls, realloc_before = realloc_calls;
    size_t observed_before = copied_payload_bytes;
    CHECK(ube_value_assign(&scalar_copy,&scalar,&scalar_type));
    CHECK(memcmp(&scalar_copy,&scalar,sizeof(scalar)) == 0);
    CHECK(malloc_calls == malloc_before && calloc_calls == calloc_before && realloc_calls == realloc_before);
    CHECK(copied_payload_bytes == observed_before); /* Stack fields are not array payload. */
    ube_err_set(77,"pre-existing","managed value test");
    void* a = NULL;
    void* b = NULL;
    root_storage ar = {0}, br = {0};
    CHECK(ube_value_root_enter(&ar,&a,&byte_array));
    CHECK(ube_value_root_enter(&br,&b,&byte_array));
    malloc_before = malloc_calls; calloc_before = calloc_calls; realloc_before = realloc_calls;
    CHECK(ube_value_assign(&b,&a,&byte_array) && b == NULL && ube_err_number() == 77);
    CHECK(malloc_calls == malloc_before && calloc_calls == calloc_before && realloc_calls == realloc_before);
    CHECK(ube_value_array_length(&a) == 0);
    CHECK(ube_value_try_resize(&a,3,&byte_type,0));
    CHECK(read_byte(a,0) == 0 && read_byte(a,2) == 0);
    write_byte(a,0,65); write_byte(a,1,0); write_byte(a,2,255);
    observed_before = copied_payload_bytes;
    CHECK(ube_value_assign(&b,&a,&byte_array));
    CHECK(copied_payload_bytes - observed_before == 3); /* Actual Byte leaves, not root pointers. */
    CHECK(b != a && ube_value_array_length(&b) == 3);
    write_byte(a,0,66);
    CHECK(read_byte(b,0) == 65 && read_byte(b,1) == 0 && read_byte(b,2) == 255);
    CHECK(ube_err_number() == 77);
    if (argc == 2 && strcmp(argv[1],"bookkeeping") == 0) {
        void* retained_a = a;
        void* retained_b = b;
        const size_t retained_bytes = ube_gc_live_allocation_bytes();
        ube_gc_test_fail_next_trace_allocations(1);
        CHECK(ube_gc_collect() == 0 && ube_err_number() == 7);
        CHECK(a == retained_a && b == retained_b);
        CHECK(ube_gc_live_allocation_bytes() == retained_bytes);
        CHECK(ube_value_array_length(&a) == 3 && read_byte(a,0) == 66 && read_byte(a,1) == 0 && read_byte(a,2) == 255);
        CHECK(ube_value_array_length(&b) == 3 && read_byte(b,0) == 65 && read_byte(b,1) == 0 && read_byte(b,2) == 255);
        int32_t collected_from_worker = -1;
        HANDLE thread = CreateThread(NULL,0,collect_after_trace_failure,&collected_from_worker,0,NULL);
        CHECK(thread != NULL);
        const DWORD waited = WaitForSingleObject(thread,5000);
        CHECK(CloseHandle(thread));
        CHECK(waited == WAIT_OBJECT_0 && __atomic_load_n(&collected_from_worker,__ATOMIC_SEQ_CST) == 0);
        CHECK(ube_err_number() == 7);
        CHECK(ube_gc_root_leave(&br) && ube_gc_root_leave(&ar));
        a = NULL; b = NULL;
        CHECK(ube_gc_collect() == 1 && ube_gc_live_allocation_bytes() == 0);
        puts("PASS recoverable trace bookkeeping");
        return 0;
    }
    void* old = a;
    ube_gc_test_fail_next_allocations(2);
    CHECK(!ube_value_try_resize(&a,12,&byte_type,1));
    CHECK(a == old && ube_value_array_length(&a) == 3 && read_byte(a,0) == 66);
    CHECK(ube_err_number() == 7);
    ube_err_set(77,"pre-existing","managed value test");
    ube_gc_test_fail_next_allocations(1);
    observed_before = copied_payload_bytes;
    CHECK(ube_value_try_resize(&a,12,&byte_type,1));
    CHECK(copied_payload_bytes - observed_before == 3); /* Preserve copies its actual payload intersection. */
    CHECK(ube_value_array_length(&a) == 12 && read_byte(a,0) == 66 && read_byte(a,2) == 255 && read_byte(a,11) == 0);
    CHECK(ube_err_number() == 77);
    CHECK(!ube_value_try_redim(&a,2,1,&byte_type,1));
    CHECK(ube_value_array_length(&a) == 12 && ube_err_number() == 9);
    struct bytes_record source = {17,a}, copy = {0};
    root_storage sr = {0}, cr = {0};
    CHECK(ube_value_root_enter(&sr,&source,&record_type));
    CHECK(ube_value_root_enter(&cr,&copy,&record_type));
    CHECK(ube_value_assign(&copy,&source,&record_type));
    CHECK(copy.tag == 17 && copy.bytes != source.bytes && read_byte(copy.bytes,0) == 66);
    write_byte(source.bytes,0,67);
    CHECK(read_byte(copy.bytes,0) == 66);
    struct bytes_record neutral_source = {23,NULL};
    ube_err_set(77,"pre-existing","managed value test");
    malloc_before = malloc_calls; calloc_before = calloc_calls; realloc_before = realloc_calls;
    CHECK(ube_value_assign(&copy,&neutral_source,&record_type));
    CHECK(copy.tag == 23 && copy.bytes == NULL && ube_err_number() == 77);
    CHECK(malloc_calls == malloc_before && calloc_calls == calloc_before && realloc_calls == realloc_before);
    CHECK(ube_value_assign(&copy,&source,&record_type));
    write_byte(copy.bytes,0,66);
    struct pair_record pair = {a,b}, destination = {copy.bytes,copy.bytes};
    root_storage pr = {0}, dr = {0};
    CHECK(ube_value_root_enter(&pr,&pair,&pair_type));
    CHECK(ube_value_root_enter(&dr,&destination,&pair_type));
    (void)ube_gc_collect();
    size_t before = ube_gc_live_allocation_bytes();
    /* Workspace succeeds, first child succeeds, second child fails twice. */
    failure_start = calloc_calls + 3;
    failures_left = 2;
    CHECK(!ube_value_assign(&destination,&pair,&pair_type));
    CHECK(failures_left == 0 && destination.first == copy.bytes && destination.second == copy.bytes);
    CHECK(ube_err_number() == 7);
    CHECK(ube_gc_live_allocation_bytes() == before); /* Partial child unwound now. */
    CHECK(ube_value_assign(&destination,&pair,&pair_type));
    CHECK(destination.first != a && destination.second != b);
    CHECK(read_byte(destination.first,0) == 67 && read_byte(destination.second,0) == 65);
    CHECK(ube_err_number() == 7); /* Successful copy must not erase the earlier error. */
    CHECK(ube_value_assign(&destination,&destination,&pair_type));
    CHECK(ube_gc_root_leave(&dr));
    CHECK(ube_gc_root_leave(&pr));
    CHECK(ube_gc_root_leave(&sr));
    CHECK(ube_gc_root_leave(&ar));
    CHECK(ube_gc_root_leave(&br));
    a = b = NULL; source.bytes = NULL;
    CHECK(ube_gc_collect() == 1);
    CHECK(read_byte(copy.bytes,0) == 66 && ube_value_array_length(&copy.bytes) == 12);
    CHECK(ube_gc_root_leave(&cr));
    copy.bytes = NULL;
    CHECK(ube_gc_collect() == 1 && ube_gc_live_allocation_bytes() == 0);
    /* A deep inline shape must use bounded work storage rather than C recursion. */
    enum { depth = 1024 };
    struct ube_value_layout* types = calloc(depth,sizeof(*types));
    struct ube_value_field* fields = calloc(depth,sizeof(*fields));
    CHECK(types != NULL && fields != NULL);
    for (int i = 0; i < depth; ++i) {
        fields[i] = (struct ube_value_field){0,i + 1 == depth ? &byte_array : &types[i + 1]};
        types[i] = (struct ube_value_layout){sizeof(void*),2,1,&fields[i],1,pointer_root};
    }
    CHECK(ube_value_root_enter(&ar,&a,&types[0]));
    CHECK(ube_value_root_enter(&br,&b,&types[0]));
    CHECK(ube_value_try_resize(&a,1,&byte_type,0));
    write_byte(a,0,42);
    CHECK(ube_value_assign(&b,&a,&types[0]));
    CHECK(read_byte(b,0) == 42 && b != a);
    CHECK(ube_gc_root_leave(&ar) && ube_gc_root_leave(&br));
    a = b = NULL;
    CHECK(ube_gc_collect() == 1 && ube_gc_live_allocation_bytes() == 0);
    free(fields); free(types);
    /* Field order is deliberate: the shallow scalar would previously be
       stored before a later, deep inline child ran out of workspace. */
    enum { inline_depth = 80 };
    struct ube_value_layout inline_types[inline_depth];
    struct ube_value_field inline_fields[inline_depth];
    for (int i = 0; i < inline_depth; ++i) {
        inline_fields[i] = (struct ube_value_field){0,i + 1 == inline_depth ? &long_type : &inline_types[i + 1]};
        inline_types[i] = (struct ube_value_layout){4,2,1,&inline_fields[i],0,NULL};
    }
    const struct ube_value_field wide_fields[] = {{0,&inline_types[0]},{4,&long_type}};
    const struct ube_value_layout wide_type = {8,2,2,wide_fields,0,NULL};
    int32_t wide_source[] = {1,2}, wide_destination[] = {21,22};
    ube_err_set(77,"pre-existing","managed value test");
    failure_start = calloc_calls + 1; failures_left = 2;
    CHECK(!ube_value_assign(wide_destination,wide_source,&wide_type));
    CHECK(failures_left == 0 && wide_destination[0] == 21 && wide_destination[1] == 22);
    CHECK(ube_err_number() == 7);
    CHECK(ube_value_assign(wide_destination,wide_source,&wide_type));
    CHECK(wide_destination[0] == 1 && wide_destination[1] == 2 && ube_err_number() == 7);
    wide_destination[0] = 21; wide_destination[1] = 22;
    ube_err_set(77,"pre-existing","managed value test");
    failure_start = calloc_calls + 1; failures_left = 2;
    CHECK(!ube_value_read(wide_destination,wide_source,&wide_type));
    CHECK(failures_left == 0 && wide_destination[0] == 0 && wide_destination[1] == 0 && ube_err_number() == 7);
    /* An outer array is the sole root for a record's inner array. A deep copy
       must retain that graph but must never share mutable inner storage. */
    void *outer = NULL, *outer_copy = NULL, *inner = NULL, *keep_alive = NULL;
    struct bytes_record fallback = {0};
    root_storage or = {0}, ocr = {0}, ir = {0}, kr = {0}, fr = {0};
    CHECK(ube_value_root_enter(&or,&outer,&record_array));
    CHECK(ube_value_root_enter(&ocr,&outer_copy,&record_array));
    CHECK(ube_value_root_enter(&ir,&inner,&byte_array));
    CHECK(ube_value_root_enter(&kr,&keep_alive,&record_array));
    CHECK(ube_value_root_enter(&fr,&fallback,&record_type));
    CHECK(ube_value_try_resize(&outer,2,&record_type,0));
    CHECK(ube_value_try_resize(&inner,2,&byte_type,0));
    write_byte(inner,1,193);
    struct bytes_record nested = {91,inner};
    struct bytes_record* borrowed = ube_value_array_element(&outer,1,&keep_alive,&fallback,&record_type);
    CHECK(borrowed != &fallback && ube_value_snapshot(borrowed,&nested,&record_type));
    struct bytes_record* first = ube_array_element(outer,0);
    CHECK(ube_value_snapshot(first,&nested,&record_type));
    CHECK(ube_gc_root_leave(&ir));
    inner = nested.bytes = NULL;
    CHECK(ube_gc_collect() == 0 && read_byte(borrowed->bytes,1) == 193);
    before = ube_gc_live_allocation_bytes();
    old = outer;
    /* Parent allocation and first inner copy succeed; second inner copy fails
       twice. Resize must unwind both prepared allocations immediately. */
    failure_start = calloc_calls + 3; failures_left = 2;
    CHECK(!ube_value_try_resize(&outer,3,&record_type,1));
    CHECK(failures_left == 0 && outer == old && ube_value_array_length(&outer) == 2);
    CHECK(read_byte(borrowed->bytes,1) == 193 && ube_gc_live_allocation_bytes() == before && ube_err_number() == 7);
    observed_before = copied_payload_bytes;
    CHECK(ube_value_assign(&outer_copy,&outer,&record_array));
    CHECK(copied_payload_bytes - observed_before == 12); /* Two Long tags plus two 2-byte children; padding/ownership metadata excluded. */
    struct bytes_record* independent = ube_array_element(outer_copy,1);
    CHECK(independent->tag == 91 && independent->bytes != borrowed->bytes && read_byte(independent->bytes,1) == 193);
    /* Replacing the owner slot does not end the borrowed address's lifetime. */
    CHECK(ube_value_try_resize(&outer,1,&record_type,0));
    (void)ube_gc_collect();
    CHECK(borrowed->tag == 91 && read_byte(borrowed->bytes,1) == 193);
    fallback = (struct bytes_record){12,independent->bytes};
    CHECK(ube_value_array_element(&outer,-1,&keep_alive,&fallback,&record_type) == &fallback);
    CHECK(fallback.tag == 0 && fallback.bytes == NULL && ube_err_number() == 9);
    CHECK(ube_value_array_element(&outer,1,&keep_alive,&fallback,&record_type) == &fallback && ube_err_number() == 9);
    CHECK(ube_value_try_resize(&outer,0,&record_type,0));
    CHECK(ube_value_array_element(&outer,0,&keep_alive,&fallback,&record_type) == &fallback && keep_alive == NULL && ube_err_number() == 9);
    CHECK(ube_gc_root_leave(&or) && ube_gc_root_leave(&ocr) && ube_gc_root_leave(&kr) && ube_gc_root_leave(&fr));
    CHECK(ube_gc_collect() == 1 && ube_gc_live_allocation_bytes() == 0);
    /* The hard bound rejects an over-deep value without touching its target or
       consuming C stack. Its source/destination roots remain valid afterward. */
    enum { excessive_depth = 65536 };
    types = calloc(excessive_depth,sizeof(*types));
    fields = calloc(excessive_depth,sizeof(*fields));
    CHECK(types != NULL && fields != NULL);
    for (int i = 0; i < excessive_depth; ++i) {
        fields[i] = (struct ube_value_field){0,i + 1 == excessive_depth ? &byte_array : &types[i + 1]};
        types[i] = (struct ube_value_layout){sizeof(void*),2,1,&fields[i],1,pointer_root};
    }
    CHECK(ube_value_root_enter(&ar,&a,&byte_array) && ube_value_root_enter(&br,&b,&byte_array));
    CHECK(ube_value_try_resize(&a,1,&byte_type,0) && ube_value_try_resize(&b,1,&byte_type,0));
    write_byte(a,0,11); write_byte(b,0,22); old = b;
    before = ube_gc_live_allocation_bytes();
    CHECK(!ube_value_assign(&b,&a,&types[0]) && ube_err_number() == 7);
    CHECK(b == old && read_byte(b,0) == 22 && ube_gc_live_allocation_bytes() == before);
    CHECK(ube_gc_root_leave(&ar) && ube_gc_root_leave(&br));
    CHECK(ube_gc_collect() == 1 && ube_gc_live_allocation_bytes() == 0);
    free(fields); free(types);
    void* private_value = NULL;
    root_storage private_root = {0};
    CHECK(ube_value_root_enter(&private_root,&private_value,&byte_array));
    CHECK(ube_value_try_resize(&private_value,5,&byte_type,0));
    ube_err_set(77,"pre-existing","managed value test");
    malloc_before = malloc_calls; calloc_before = calloc_calls; realloc_before = realloc_calls;
    ube_value_zero(&private_value,&byte_array);
    CHECK(private_value == NULL && ube_err_number() == 77);
    CHECK(malloc_calls == malloc_before && calloc_calls == calloc_before && realloc_calls == realloc_before);
    CHECK(ube_gc_collect() == 1 && ube_gc_live_allocation_bytes() == 0);
    CHECK(ube_gc_root_leave(&private_root));
    ube_err_set(7,"pre-existing","managed value test");
    HANDLE workers[4] = {0};
    for (uintptr_t i = 0; i < 4; ++i) {
        workers[i] = CreateThread(NULL,0,independent_worker,(void*)(i + 1),0,NULL);
        CHECK(workers[i] != NULL);
    }
    CHECK(WaitForMultipleObjects(4,workers,TRUE,10000) == WAIT_OBJECT_0);
    for (unsigned i = 0; i < 4; ++i) {
        DWORD result = 99;
        CHECK(GetExitCodeThread(workers[i],&result) && result == 0);
        CHECK(CloseHandle(workers[i]));
    }
    CHECK(ube_err_number() == 7);
    CHECK(ube_gc_collect() == 1 && ube_gc_live_allocation_bytes() == 0);
    printf("PASS managed substrate assertions:%u\n",assertions);
    return 0;
}
