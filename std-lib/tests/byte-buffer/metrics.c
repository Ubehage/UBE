#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../../../runtime/value_storage.h"

struct buffer { void* storage; int32_t count; };
typedef union { uint64_t alignment; unsigned char bytes[32]; } root_storage;
extern size_t metrics_buffer_size(void), metrics_buffer_alignment(void), metrics_count_offset(void), metrics_decoder_size(void);
extern int32_t metrics_capacity(struct buffer*), metrics_length(struct buffer*), metrics_clear(struct buffer*);
extern int32_t metrics_reserve(struct buffer*,int32_t), metrics_append(struct buffer*,uint8_t);
extern int32_t metrics_append_range(struct buffer*,void**,int32_t,int32_t), metrics_snapshot(struct buffer*,void**);
extern int32_t metrics_count_utf8(struct buffer*,int32_t*), metrics_scoped(uint8_t,int32_t);
extern size_t ube_gc_root_storage_size(void), ube_gc_live_allocation_bytes(void);
extern int32_t ube_gc_root_enter(void*,void**), ube_gc_root_leave(void*), ube_gc_collect(void), ube_err_number(void);
extern void ube_err_set(int32_t,const char*,const char*), ube_gc_test_fail_next_allocations(uint32_t);
extern void* ube_array_element(void*,int32_t);

/* Fixed test bookkeeping never calls the observed allocator. Requested live
   bytes are allocator arguments, not OS committed memory or process RSS. */
struct allocation { void* pointer; size_t size; };
static struct allocation allocations[32768];
static SRWLOCK allocation_lock = SRWLOCK_INIT;
static size_t requested_live, requested_peak, tracking_errors;
struct observations {
    size_t calls, requested, calloc_calls, calloc_success, calloc_zero_requested;
    size_t calloc_sizes[16], copied, leaves, feeds, finishes;
    size_t fail_at, fail_left;
};
static _Thread_local struct observations observed;
static size_t hash_pointer(void* pointer) { return ((uintptr_t)pointer >> 4) % 32768; }
static void track_add(void* pointer, size_t size) {
    if (!pointer) return;
    size_t index = hash_pointer(pointer);
    for (size_t n = 0; n < 32768; ++n, index = (index + 1) % 32768) {
        if (allocations[index].pointer == NULL || allocations[index].pointer == (void*)1) {
            allocations[index] = (struct allocation){pointer,size};
            requested_live += size;
            if (requested_live > requested_peak) requested_peak = requested_live;
            return;
        }
    }
    ++tracking_errors;
}
static void track_remove(void* pointer) {
    if (!pointer) return;
    size_t index = hash_pointer(pointer);
    for (size_t n = 0; n < 32768; ++n, index = (index + 1) % 32768) {
        if (allocations[index].pointer == pointer) {
            requested_live -= allocations[index].size;
            allocations[index].pointer = (void*)1;
            return;
        }
        if (allocations[index].pointer == NULL) break;
    }
    ++tracking_errors;
}
void* probe_malloc(size_t size) {
    ++observed.calls; observed.requested += size;
    void* pointer = malloc(size);
    AcquireSRWLockExclusive(&allocation_lock); track_add(pointer,size); ReleaseSRWLockExclusive(&allocation_lock);
    return pointer;
}
void* probe_calloc(size_t count, size_t size) {
    ++observed.calls; ++observed.calloc_calls;
    if (size != 0 && count > SIZE_MAX / size) return NULL;
    size_t bytes = count * size;
    observed.requested += bytes;
    if (observed.fail_left && observed.calloc_calls >= observed.fail_at) { --observed.fail_left; return NULL; }
    void* pointer = calloc(count,size);
    if (pointer) {
        observed.calloc_sizes[observed.calloc_success % 16] = bytes;
        ++observed.calloc_success; observed.calloc_zero_requested += bytes;
    }
    AcquireSRWLockExclusive(&allocation_lock); track_add(pointer,bytes); ReleaseSRWLockExclusive(&allocation_lock);
    return pointer;
}
void* probe_realloc(void* pointer, size_t size) {
    ++observed.calls; observed.requested += size;
    AcquireSRWLockExclusive(&allocation_lock);
    void* resized = realloc(pointer,size);
    if (resized || size == 0) { track_remove(pointer); track_add(resized,size); }
    ReleaseSRWLockExclusive(&allocation_lock);
    return resized;
}
void probe_free(void* pointer) {
    AcquireSRWLockExclusive(&allocation_lock); track_remove(pointer); ReleaseSRWLockExclusive(&allocation_lock);
    free(pointer);
}
void probe_value_copy(size_t bytes) { observed.copied += bytes; ++observed.leaves; }
void metrics_feed_called(void) { ++observed.feeds; }
void metrics_finish_called(void) { ++observed.finishes; }

static unsigned assertions;
#define CHECK(condition) do { ++assertions; if (!(condition)) { fprintf(stderr,"buffer metric assertion %u line %d failed: %s\n",assertions,__LINE__,#condition); return 1; } } while (0)
static const struct ube_value_layout byte_type = {1,0,0,NULL,0,NULL};
static void seed(int32_t number) { ube_err_set(number,"pre-existing error","ByteBuffer measurements"); }
static uint8_t get_byte(void* array, int32_t index) { return __atomic_load_n((uint8_t*)ube_array_element(array,index),__ATOMIC_SEQ_CST); }
static void put_byte(void* array, int32_t index, uint8_t byte) { __atomic_store_n((uint8_t*)ube_array_element(array,index),byte,__ATOMIC_SEQ_CST); }
static int root_values(struct buffer* buffer, void** output, root_storage* br, root_storage* or) {
    return ube_gc_root_enter(br,&buffer->storage) && ube_gc_root_enter(or,output);
}
static int release_values(root_storage* br, root_storage* or) {
    return ube_gc_root_leave(or) && ube_gc_root_leave(br);
}
static int prefix_equal(void* array, int32_t n, int32_t modulus) {
    for (int32_t i = 0; i < n; ++i) if (get_byte(array,i) != (uint8_t)(i % modulus)) return 0;
    return 1;
}
static int bytes_equal(void* array, int32_t n, int32_t modulus) {
    return ube_value_array_length(&array) == n && prefix_equal(array,n,modulus);
}

/* Budgets were fixed in BYTE-BUFFER-CONTRACT.md/ORACLES.md before this run.
   Each allocation/copy counter below is incremented at an executed call/store. */
static int measure_growth(int32_t n, size_t baseline) {
    struct buffer buffer = {0}; void* output = NULL;
    root_storage br = {0}, or = {0};
    CHECK(root_values(&buffer,&output,&br,&or));
    seed(77);
    struct observations start = observed;
    requested_peak = requested_live;
    size_t allocation_count = 0, append_calls = 0, overhead = 0, payload_zero_requested = 0;
    int32_t expected_capacity = 0;
    for (int32_t i = 0; i < n; ++i) {
        size_t success_before = observed.calloc_success;
        CHECK(metrics_append(&buffer,(uint8_t)(i % 127))); ++append_calls;
        if (i == expected_capacity) {
            expected_capacity = expected_capacity == 0 ? 8 : expected_capacity * 2;
            CHECK(observed.calloc_success == success_before + 1);
            size_t request = observed.calloc_sizes[success_before % 16];
            if (overhead == 0) overhead = request - (size_t)expected_capacity;
            CHECK(request == overhead + (size_t)expected_capacity);
            payload_zero_requested += request - overhead;
            ++allocation_count;
        } else CHECK(observed.calloc_success == success_before);
        CHECK(metrics_capacity(&buffer) == expected_capacity);
    }
    const size_t growth_copied = observed.copied - start.copied;
    const size_t growth_requests = observed.calls - start.calls;
    const size_t growth_requested = observed.requested - start.requested;
    const size_t growth_zero = observed.calloc_zero_requested - start.calloc_zero_requested;
    const size_t growth_peak = requested_peak - baseline;
    CHECK(append_calls == (size_t)n && metrics_length(&buffer) == n && ube_err_number() == 77);
    CHECK(expected_capacity >= n && (n <= 8 ? expected_capacity == 8 : expected_capacity < 2 * n));
    CHECK(growth_copied < 2 * (size_t)n);
    CHECK(growth_requests == allocation_count && observed.calloc_success - start.calloc_success == allocation_count);
    CHECK(growth_peak == growth_requested && growth_zero == growth_requested);
    CHECK(growth_peak < 2 * (size_t)expected_capacity + allocation_count * overhead);
    (void)ube_gc_collect();
    CHECK(requested_live == baseline + overhead + (size_t)expected_capacity);
    size_t retained_gc_bytes = ube_gc_live_allocation_bytes();
    CHECK(retained_gc_bytes >= (size_t)expected_capacity && retained_gc_bytes <= (size_t)expected_capacity + overhead);
    struct observations before = observed;
    CHECK(metrics_reserve(&buffer,n) && metrics_length(&buffer) == n && metrics_capacity(&buffer) == expected_capacity);
    int32_t scalars = -1;
    CHECK(metrics_count_utf8(&buffer,&scalars) && scalars == n);
    CHECK(observed.feeds - before.feeds == (size_t)n && observed.finishes - before.finishes == 1);
    CHECK(observed.calls == before.calls && observed.copied == before.copied && ube_err_number() == 77);
    before = observed;
    CHECK(metrics_snapshot(&buffer,&output));
    size_t snapshot_copied = observed.copied - before.copied;
    size_t snapshot_zero = observed.calloc_zero_requested - before.calloc_zero_requested;
    size_t snapshot_arrays = 0, snapshot_workspaces = 0, snapshot_payload_zero = 0;
    for (size_t event = before.calloc_success; event < observed.calloc_success; ++event) {
        const size_t bytes = observed.calloc_sizes[event % 16];
        if (bytes >= overhead) { ++snapshot_arrays; snapshot_payload_zero += bytes - overhead; }
        else ++snapshot_workspaces;
    }
    CHECK(snapshot_copied <= 2 * (size_t)n && snapshot_copied == 2 * (size_t)n);
    CHECK(observed.calloc_success - before.calloc_success == 3);
    CHECK(snapshot_arrays == 2 && snapshot_workspaces == 1 && snapshot_payload_zero == 2 * (size_t)n);
    CHECK(observed.calloc_sizes[before.calloc_success % 16] == overhead + (size_t)n);
    CHECK(observed.calloc_sizes[(before.calloc_success + 1) % 16] == sizeof(void*));
    CHECK(observed.calloc_sizes[(before.calloc_success + 2) % 16] == overhead + (size_t)n);
    CHECK(snapshot_zero == 2 * (overhead + (size_t)n) + sizeof(void*));
    CHECK(bytes_equal(output,n,127) && output != buffer.storage && ube_err_number() == 77);
    (void)ube_gc_collect();
    CHECK(requested_live == baseline + 2 * overhead + (size_t)expected_capacity + (size_t)n);
    before = observed;
    CHECK(metrics_clear(&buffer) && metrics_length(&buffer) == 0 && metrics_capacity(&buffer) == expected_capacity);
    scalars = -1;
    CHECK(metrics_count_utf8(&buffer,&scalars) && scalars == 0);
    CHECK(observed.feeds == before.feeds && observed.finishes - before.finishes == 1);
    CHECK(metrics_append(&buffer,255));
    scalars = -1;
    CHECK(!metrics_count_utf8(&buffer,&scalars) && scalars == 0);
    CHECK(observed.feeds - before.feeds == 1 && observed.finishes - before.finishes == 1);
    CHECK(observed.calls == before.calls && observed.copied == before.copied && ube_err_number() == 77);
    CHECK(bytes_equal(output,n,127));
    CHECK(release_values(&br,&or));
    (void)ube_gc_collect();
    CHECK(ube_gc_live_allocation_bytes() == 0 && requested_live == baseline && tracking_errors == 0);
    printf("{\"n\":%d,\"capacity\":%d,\"appendCalls\":%zu,\"growthArrayAllocations\":%zu,\"growthCopiedBytes\":%zu,\"allocationRequests\":%zu,\"requestedBytes\":%zu,\"callocZeroRequestedBytes\":%zu,\"payloadZeroRequestedBytes\":%zu,\"peakRequestedLiveBytes\":%zu,\"retainedGcBytes\":%zu,\"snapshotCopiedBytes\":%zu,\"snapshotArrayAllocations\":%zu,\"snapshotWorkspaceAllocations\":%zu,\"snapshotCallocZeroRequestedBytes\":%zu,\"snapshotPayloadZeroRequestedBytes\":%zu,\"allocationHeaderBytes\":%zu,\"baselineRequestedLiveBytes\":%zu,\"postScopeRequestedDelta\":%zu,\"postScopeGcBytes\":%zu}\n",
        n,expected_capacity,append_calls,allocation_count,growth_copied,growth_requests,growth_requested,growth_zero,payload_zero_requested,growth_peak,retained_gc_bytes,snapshot_copied,snapshot_arrays,snapshot_workspaces,snapshot_zero,snapshot_payload_zero,overhead,baseline,requested_live - baseline,ube_gc_live_allocation_bytes());
    return 0;
}

static int initial_buffer_unchanged(struct buffer* buffer, void* output) {
    return buffer->count == 8 && metrics_capacity(buffer) == 8 && bytes_equal(buffer->storage,8,256) &&
        ube_value_array_length(&output) == 2 && get_byte(output,0) == 91 && get_byte(output,1) == 92;
}
static int check_failures(size_t baseline) {
    struct buffer buffer = {0}; void* output = NULL;
    root_storage br = {0}, or = {0};
    CHECK(root_values(&buffer,&output,&br,&or));
    for (uint8_t i = 0; i < 8; ++i) CHECK(metrics_append(&buffer,i));
    CHECK(ube_value_try_resize(&output,2,&byte_type,0)); put_byte(output,0,91); put_byte(output,1,92);
    (void)ube_gc_collect();
    const size_t stable_live = requested_live;
    const size_t overhead = observed.calloc_sizes[(observed.calloc_success - 1) % 16] - 2;
    seed(77); ube_gc_test_fail_next_allocations(2);
    CHECK(!metrics_append(&buffer,8) && ube_err_number() == 7 && initial_buffer_unchanged(&buffer,output));
    seed(77); ube_gc_test_fail_next_allocations(2);
    CHECK(!metrics_snapshot(&buffer,&output) && ube_err_number() == 7 && initial_buffer_unchanged(&buffer,output));
    seed(77);
    size_t successful_before = observed.calloc_success, copied_before = observed.copied;
    observed.fail_at = observed.calloc_calls + 3; observed.fail_left = 2;
    CHECK(!metrics_snapshot(&buffer,&output));
    CHECK(observed.fail_left == 0 && ube_err_number() == 7 && initial_buffer_unchanged(&buffer,output));
    CHECK(observed.calloc_success - successful_before == 2 && observed.copied - copied_before == 8);
    CHECK(observed.calloc_sizes[successful_before % 16] == overhead + 8 && observed.calloc_sizes[(successful_before + 1) % 16] == sizeof(void*));
    (void)ube_gc_collect();
    size_t retained = requested_live;
    CHECK(retained == stable_live);
    seed(77); ube_gc_test_fail_next_allocations(2);
    size_t calloc_before = observed.calloc_calls;
    CHECK(!metrics_reserve(&buffer,INT32_MAX) && ube_err_number() == 7 && initial_buffer_unchanged(&buffer,output));
    CHECK(observed.calloc_calls == calloc_before && requested_live == retained);
    seed(77); ube_gc_test_fail_next_allocations(1);
    CHECK(metrics_append(&buffer,8) && ube_err_number() == 77);
    CHECK(buffer.count == 9 && metrics_capacity(&buffer) == 16 && prefix_equal(buffer.storage,9,256));
    seed(7);
    CHECK(metrics_reserve(&buffer,9) && metrics_snapshot(&buffer,&output) && ube_err_number() == 7);
    CHECK(metrics_clear(&buffer) && metrics_append_range(&buffer,&output,9,0) && ube_err_number() == 7);
    CHECK(!metrics_reserve(&buffer,-1) && !metrics_append_range(&buffer,&output,-1,1) && ube_err_number() == 7);
    CHECK(!metrics_scoped(65,1));
    CHECK(metrics_scoped(65,0));
    CHECK(release_values(&br,&or));
    (void)ube_gc_collect();
    CHECK(ube_gc_live_allocation_bytes() == 0 && requested_live == baseline && tracking_errors == 0);
    return 0;
}

struct worker { void* const* shared; uint8_t marker; unsigned index; };
static DWORD WINAPI worker_main(void* argument) {
    struct worker* worker = argument;
    struct buffer buffer = {0}; void* output = NULL;
    root_storage br = {0}, or = {0};
    DWORD failed = 0;
    if (!root_values(&buffer,&output,&br,&or)) failed = 1;
    seed((int32_t)(100 + worker->index));
    for (unsigned round = 0; round < 32 && !failed; ++round) {
        if (!metrics_clear(&buffer) || !metrics_append(&buffer,worker->marker) ||
            !metrics_append_range(&buffer,(void**)worker->shared,0,256)) { failed = 2; break; }
        if (worker->index == 0 && round % 8 == 0) {
            observed.fail_at = observed.calloc_calls + 3; observed.fail_left = 2;
            if (metrics_snapshot(&buffer,&output) || observed.fail_left || ube_err_number() != 7) { failed = 3; break; }
            seed(100);
            if (metrics_scoped(worker->marker,1)) { failed = 4; break; }
        }
        if (!metrics_snapshot(&buffer,&output) || ube_value_array_length(&output) != 257 ||
            get_byte(output,0) != worker->marker) { failed = 5; break; }
        for (int32_t i = 0; i < 256; ++i) if (get_byte(output,i + 1) != (uint8_t)i) { failed = 6; break; }
        if (failed) break;
        if (!metrics_clear(&buffer) || !metrics_append(&buffer,(uint8_t)(worker->marker ^ 255)) ||
            get_byte(output,0) != worker->marker || ube_err_number() != (int32_t)(100 + worker->index)) { failed = 7; break; }
        (void)ube_gc_collect();
    }
    observed.fail_left = 0;
    if (!release_values(&br,&or)) failed = 8;
    return failed;
}
static int check_workers(size_t baseline) {
    void* shared = NULL; root_storage sr = {0};
    CHECK(ube_gc_root_enter(&sr,&shared));
    CHECK(ube_value_try_resize(&shared,256,&byte_type,0));
    for (int32_t i = 0; i < 256; ++i) put_byte(shared,i,(uint8_t)i);
    const uint8_t markers[] = {0,65,128,255};
    struct worker arguments[4]; HANDLE workers[4] = {0};
    for (unsigned i = 0; i < 4; ++i) {
        arguments[i] = (struct worker){&shared,markers[i],i};
        workers[i] = CreateThread(NULL,0,worker_main,&arguments[i],0,NULL);
        CHECK(workers[i] != NULL);
    }
    CHECK(WaitForMultipleObjects(4,workers,TRUE,20000) == WAIT_OBJECT_0);
    for (unsigned i = 0; i < 4; ++i) {
        DWORD result = 99;
        CHECK(GetExitCodeThread(workers[i],&result) && result == 0);
        CHECK(CloseHandle(workers[i]));
    }
    CHECK(bytes_equal(shared,256,256));
    CHECK(ube_gc_root_leave(&sr));
    (void)ube_gc_collect();
    CHECK(ube_gc_live_allocation_bytes() == 0 && requested_live == baseline && tracking_errors == 0);
    return 0;
}
static int functional_subset(void) {
    struct buffer buffer = {0}; void* output = NULL;
    root_storage br = {0}, or = {0};
    CHECK(root_values(&buffer,&output,&br,&or)); seed(77);
    for (int32_t i = 0; i < 256; ++i) CHECK(metrics_append(&buffer,(uint8_t)i));
    CHECK(metrics_capacity(&buffer) == 256 && metrics_snapshot(&buffer,&output) && bytes_equal(output,256,256));
    CHECK(metrics_clear(&buffer) && metrics_append(&buffer,99) && bytes_equal(output,256,256) && ube_err_number() == 77);
    CHECK(release_values(&br,&or)); (void)ube_gc_collect();
    CHECK(ube_gc_live_allocation_bytes() == 0);
    puts("PASS byte-buffer exact accepted runtime subset");
    return 0;
}
int main(int argc, char** argv) {
    CHECK(metrics_buffer_size() == sizeof(struct buffer) && metrics_buffer_alignment() == _Alignof(struct buffer));
    CHECK(metrics_count_offset() == offsetof(struct buffer,count) && metrics_decoder_size() == 16);
    CHECK(ube_gc_root_storage_size() == sizeof(root_storage));
    if (argc == 2 && strcmp(argv[1],"functional") == 0) return functional_subset();
    seed(77); (void)ube_gc_collect();
    const size_t baseline = requested_live;
    CHECK(ube_gc_live_allocation_bytes() == 0);
    const int32_t sizes[] = {1,8,9,16,17,64,65,256,4096,65536};
    for (size_t i = 0; i < sizeof(sizes) / sizeof(sizes[0]); ++i) CHECK(measure_growth(sizes[i],baseline) == 0);
    CHECK(check_failures(baseline) == 0);
    CHECK(check_workers(baseline) == 0);
    CHECK(ube_err_number() == 7);
    printf("PASS byte-buffer costs assertions:%u\n",assertions);
    return 0;
}
