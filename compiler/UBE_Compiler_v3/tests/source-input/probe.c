#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <wchar.h>
#include "../../../../runtime/value_storage.h"

struct position { int32_t byte, scalar, line, column; };
struct failure { int32_t kind; struct position position; };
struct decoder { int32_t remaining, accumulator, minimum; bool failed; };
struct buffer { void* storage; int32_t count; };
struct document { void* bytes; int32_t content, scalars, lines; };
struct input {
    struct buffer buffer; struct decoder decoder;
    struct position cursor, sequence, carriage;
    int32_t content, maximum; bool pending, ready;
};
typedef union { uint64_t alignment; unsigned char bytes[32]; } root;
extern size_t source_layout(int32_t);
extern int32_t source_begin(struct input*,int32_t);
extern int32_t source_append(struct input*,void**,int32_t,int32_t,struct failure*);
extern int32_t source_finish(struct input*,struct document*,struct failure*);
extern int32_t source_file(void**,int32_t,struct document*,struct failure*,int32_t*,int32_t*);
extern int32_t source_scoped(int32_t), source_copy(struct document*,struct document*);
extern size_t ube_gc_root_storage_size(void), ube_gc_live_allocation_bytes(void);
extern int32_t ube_gc_root_enter(void*,void**), ube_gc_root_leave(void*), ube_gc_collect(void), ube_err_number(void);
extern void ube_err_set(int32_t,const char*,const char*), ube_gc_test_fail_next_allocations(uint32_t);
extern void* ube_array_element(void*,int32_t);
#ifdef OBSERVE_INPUT
extern void ube_file_test_inject(int32_t);
extern void ube_file_test_before_read(void (*)(void*),void*);
extern int32_t ube_file_test_open_handles(void), ube_file_test_payloads(void), ube_file_test_reads(void);
extern int64_t ube_file_test_bytes_read(void), ube_file_test_bytes_published(void);
extern size_t source_test_root_count(void);
#endif

/* Reuse the maintained runtime's allocation and executed-copy hook boundary.
   These counters include actual requests; zero bytes are calloc arguments,
   not measured physical CPU writes. No input length is substituted for work. */
struct observations { size_t allocations, requested, zero_requested, copied, reserve_copied, feeds, calloc_calls, fail_at, fail_left, in_reserve; };
static _Thread_local struct observations observed;
void* probe_malloc(size_t n) { ++observed.allocations; observed.requested += n; return malloc(n); }
void* probe_calloc(size_t n,size_t s) {
    ++observed.allocations; ++observed.calloc_calls;
    if (s && n > SIZE_MAX / s) return NULL;
    observed.requested += n * s;
    if (observed.fail_left && observed.calloc_calls >= observed.fail_at) { --observed.fail_left; return NULL; }
    void* p = calloc(n,s); if (p) observed.zero_requested += n * s; return p;
}
void* probe_realloc(void* p,size_t n) { ++observed.allocations; observed.requested += n; return realloc(p,n); }
void probe_free(void* p) { free(p); }
void probe_value_copy(size_t n) { observed.copied += n; if (observed.in_reserve) observed.reserve_copied += n; }
void source_feed_called(void) { ++observed.feeds; }
void source_reserve_enter(void) { ++observed.in_reserve; }
void source_reserve_leave(void) { --observed.in_reserve; }
static unsigned assertions;
#define CHECK(x) do { ++assertions; if (!(x)) { fprintf(stderr,"source assertion %u at line %d: %s\n",assertions,__LINE__,#x); return 1; } } while (0)
static const struct ube_value_layout byte_type = {1,0,0,NULL,0,NULL};
static void seed(int32_t n) { ube_err_set(n,"existing error","source input proof"); }
static uint8_t get(void* a,int32_t i) { return __atomic_load_n((uint8_t*)ube_array_element(a,i),__ATOMIC_SEQ_CST); }
static void put(void* a,int32_t i,uint8_t v) { __atomic_store_n((uint8_t*)ube_array_element(a,i),v,__ATOMIC_SEQ_CST); }
static int array(void** a,const uint8_t* bytes,int32_t n) {
    if (!ube_value_try_resize(a,n,&byte_type,0)) return 0;
    for (int32_t i = 0; i < n; ++i) put(*a,i,bytes[i]);
    return 1;
}
static int equal(void* a,const uint8_t* bytes,int32_t n) {
    if (ube_value_array_length(&a) != n) return 0;
    for (int32_t i = 0; i < n; ++i) if (get(a,i) != bytes[i]) return 0;
    return 1;
}
static int position_equal(struct position a,struct position b) {
    return a.byte == b.byte && a.scalar == b.scalar && a.line == b.line && a.column == b.column;
}
static int same_document(struct document a,struct document b) {
    return a.bytes == b.bytes && a.content == b.content && a.scalars == b.scalars && a.lines == b.lines;
}

/* Independent complete-input reference. The decoder uses leading-bit masks
   and explicit continuation/range checks, not production decoder state. */
static struct failure reference(const uint8_t* bytes,int32_t n,int32_t* content) {
    struct position p = {0,0,1,1}; *content = 0;
    while (p.byte < n) {
        struct position start = p;
        uint32_t c = bytes[p.byte]; int32_t width = 1;
        if (c >= 0x80) {
            if ((c & 0xe0) == 0xc0) { width = 2; c &= 31; }
            else if ((c & 0xf0) == 0xe0) { width = 3; c &= 15; }
            else if ((c & 0xf8) == 0xf0) { width = 4; c &= 7; }
            else return (struct failure){3,start};
            if (width > n - p.byte) return (struct failure){3,start};
            for (int32_t j = 1; j < width; ++j) {
                if ((bytes[p.byte+j] & 0xc0) != 0x80) return (struct failure){3,start};
                c = (c << 6) | (bytes[p.byte+j] & 63);
            }
            if ((width == 2 && c < 128) || (width == 3 && c < 2048) || (width == 4 && c < 65536) ||
                c > 0x10ffff || (c >= 0xd800 && c <= 0xdfff)) return (struct failure){3,start};
        }
        p.byte += width;
        if (start.byte == 0 && c == 0xfeff) { *content = 3; continue; }
        ++p.scalar;
        if (c == 13) {
            if (p.byte == n || bytes[p.byte] != 10) return (struct failure){4,start};
        } else if (c == 10) { ++p.line; p.column = 1; }
        else ++p.column;
    }
    return (struct failure){0,p};
}

static int check_vector(const uint8_t* data,int32_t n) {
    int32_t content = 0; struct failure expected = reference(data,n,&content);
    for (int32_t split = 0; split <= n; ++split) {
        struct input input = {0}; struct document document = {0}, copy = {0}; struct failure failure = {0};
        void* bytes = NULL; root roots[4] = {0};
        CHECK(ube_gc_root_enter(&roots[0],&input.buffer.storage));
        CHECK(ube_gc_root_enter(&roots[1],&document.bytes));
        CHECK(ube_gc_root_enter(&roots[2],&bytes));
        CHECK(ube_gc_root_enter(&roots[3],&copy.bytes));
        const uint8_t old[] = {90};
        CHECK(array(&bytes,data,n) && array(&document.bytes,old,1));
        document.content = 91; document.scalars = 92; document.lines = 93;
        CHECK(source_begin(&input,n+1)); seed(77);
        int32_t starts[2] = {0,split}, counts[2] = {split,n-split}; int32_t ok = 1;
        for (int part = 0; part < 2 && ok; ++part) {
            struct input before = input;
            ok = source_append(&input,&bytes,starts[part],counts[part],&failure);
            if (!ok) CHECK(memcmp(&before,&input,sizeof input) == 0);
        }
        if (ok) ok = source_finish(&input,&document,&failure);
        CHECK(ok == (expected.kind == 0));
        CHECK(failure.kind == expected.kind && position_equal(failure.position,expected.position));
        CHECK(ube_err_number() == 77);
        if (ok) {
            CHECK(equal(document.bytes,data,n) && document.content == content && document.scalars == expected.position.scalar && document.lines == expected.position.line);
            CHECK(position_equal(input.cursor,expected.position));
            CHECK(source_copy(&copy,&document));
            CHECK(equal(copy.bytes,data,n) && copy.content == document.content && copy.scalars == document.scalars && copy.lines == document.lines);
            if (n) { CHECK(copy.bytes != document.bytes); put(copy.bytes,0,(uint8_t)(data[0] ^ 255)); put(bytes,0,0); }
            CHECK(source_begin(&input,n+1));
            CHECK(source_append(&input,&bytes,0,n ? 1 : 0,&failure));
            CHECK(equal(document.bytes,data,n));
        } else CHECK(equal(document.bytes,old,1) && document.content == 91 && document.scalars == 92 && document.lines == 93);
        for (int i = 3; i >= 0; --i) CHECK(ube_gc_root_leave(&roots[i]));
        (void)ube_gc_collect(); CHECK(ube_gc_live_allocation_bytes() == 0);
    }
    return 0;
}

static int vectors(void) {
    static const struct { uint8_t bytes[40]; int32_t n; } valid[] = {
        {{0},0}, {{65},1}, {{65,10,66},3}, {{65,13,10,66},4}, {{9,0,65},3},
        {{0xef,0xbb,0xbf},3}, {{0xef,0xbb,0xbf,65,13,10,0},7}, {{65,0xef,0xbb,0xbf},4},
        {{0xc2,0xa2,0xe2,0x82,0xac,0xf0,0x9f,0x98,0x80,10},10},
        {{0x7f,0xc2,0x80,0xdf,0xbf,0xe0,0xa0,0x80,0xed,0x9f,0xbf,0xee,0x80,0x80,0xef,0xbf,0xbf,0xf0,0x90,0x80,0x80,0xf4,0x8f,0xbf,0xbf},25},
        {{0x65,0xcc,0x81},3}, {{0xc3,0xa9},2}, {{10,13,10,13,10},5}
    };
    static const struct { uint8_t bytes[12]; int32_t n; } invalid[] = {
        {{0xc0,0x80},2}, {{0xc1,0xbf},2}, {{0xe0,0x80,0x80},3}, {{0xf0,0x80,0x80,0x80},4},
        {{0xed,0xa0,0x80},3}, {{0xf4,0x90,0x80,0x80},4}, {{0xf5,0x80,0x80,0x80},4},
        {{0xc2},1}, {{0xe2,0x82},2}, {{0xf0,0x9f,0x98},3}, {{0xe2,65,0x80},3},
        {{13},1}, {{65,13,66},3}, {{65,13,0xff},3}, {{0xc3,0xa9,13},3}, {{10,0xc3,0xa9,0xe2,65},5}
    };
    for (size_t i = 0; i < sizeof valid / sizeof *valid; ++i) CHECK(check_vector(valid[i].bytes,valid[i].n) == 0);
    for (size_t i = 0; i < sizeof invalid / sizeof *invalid; ++i) CHECK(check_vector(invalid[i].bytes,invalid[i].n) == 0);
    for (unsigned i = 0x80; i <= 0xc1; ++i) { uint8_t b = (uint8_t)i; CHECK(check_vector(&b,1) == 0); }
    for (unsigned i = 0xf5; i <= 0xff; ++i) { uint8_t b = (uint8_t)i; CHECK(check_vector(&b,1) == 0); }
    return 0;
}

static int domains(void) {
    struct input input = {0}; struct document document = {0}; struct failure failure = {0}; void* bytes = NULL;
    root roots[3] = {0}; CHECK(ube_gc_root_enter(&roots[0],&input.buffer.storage));
    CHECK(ube_gc_root_enter(&roots[1],&document.bytes) && ube_gc_root_enter(&roots[2],&bytes));
    const uint8_t data[] = {0xc3,0xa9,13,10}; CHECK(array(&bytes,data,4)); seed(77);
    CHECK(!source_append(&input,&bytes,0,0,&failure) && failure.kind == 1);
    CHECK(!source_finish(&input,&document,&failure) && failure.kind == 1);
    CHECK(!source_begin(&input,-1) && !source_begin(&input,INT32_MAX));
    CHECK(source_begin(&input,INT32_MAX-1) && source_begin(&input,4));
    const int32_t spans[][2] = {{-1,0},{0,-1},{5,0},{4,1},{1,4},{INT32_MAX,1},{0,INT32_MAX}};
    size_t calls = observed.allocations;
    for (size_t i = 0; i < sizeof spans / sizeof *spans; ++i) CHECK(!source_append(&input,&bytes,spans[i][0],spans[i][1],&failure) && failure.kind == 1 && input.cursor.byte == 0);
    CHECK(observed.allocations == calls && ube_err_number() == 77);
    CHECK(source_append(&input,&bytes,4,0,&failure));
    CHECK(source_begin(&input,3)); calls = observed.allocations;
    CHECK(!source_append(&input,&bytes,0,4,&failure) && failure.kind == 2 && observed.allocations == calls && input.cursor.byte == 0);
    CHECK(source_begin(&input,4) && source_append(&input,&bytes,0,1,&failure));
    CHECK(!source_finish(&input,&document,&failure) && failure.kind == 3 && failure.position.byte == 0);
    CHECK(source_append(&input,&bytes,1,1,&failure) && source_finish(&input,&document,&failure));
    CHECK(document.scalars == 1 && document.lines == 1);
    CHECK(source_append(&input,&bytes,2,1,&failure));
    CHECK(!source_finish(&input,&document,&failure) && failure.kind == 4 && failure.position.byte == 2 && document.scalars == 1);
    CHECK(source_append(&input,&bytes,3,1,&failure) && source_finish(&input,&document,&failure));
    CHECK(document.scalars == 3 && document.lines == 2 && ube_err_number() == 77);
    CHECK(source_begin(&input,0) && source_append(&input,&bytes,0,0,&failure) && source_finish(&input,&document,&failure));
    CHECK(document.scalars == 0 && document.lines == 1);
    CHECK(source_begin(&input,4) && source_append(&input,&bytes,0,1,&failure));
    struct input before = input;
    CHECK(!source_append(&input,&bytes,3,1,&failure) && failure.kind == 3 && position_equal(failure.position,(struct position){0,0,1,1}));
    CHECK(memcmp(&before,&input,sizeof input) == 0);
    CHECK(source_append(&input,&bytes,1,1,&failure) && source_finish(&input,&document,&failure) && document.scalars == 1);
    for (int i = 2; i >= 0; --i) CHECK(ube_gc_root_leave(&roots[i]));
    (void)ube_gc_collect(); CHECK(ube_gc_live_allocation_bytes() == 0); return 0;
}

#ifdef OBSERVE_INPUT
static int failures(void) {
    struct input input = {0}; struct document document = {0}; struct failure failure = {0}; void* bytes = NULL;
    root roots[3] = {0}; CHECK(ube_gc_root_enter(&roots[0],&input.buffer.storage));
    CHECK(ube_gc_root_enter(&roots[1],&document.bytes) && ube_gc_root_enter(&roots[2],&bytes));
    const uint8_t data[] = {65,65,65,65,65,65,65,65,66}; CHECK(array(&bytes,data,9));
    CHECK(source_begin(&input,16) && source_append(&input,&bytes,0,8,&failure) && source_finish(&input,&document,&failure));
    struct input before = input; void* old_document = document.bytes; seed(77); ube_gc_test_fail_next_allocations(2);
    CHECK(!source_append(&input,&bytes,8,1,&failure) && failure.kind == 5 && ube_err_number() == 7);
    CHECK(memcmp(&before,&input,sizeof input) == 0 && document.bytes == old_document);
    for (size_t allocation = 1; allocation <= 3; allocation += 2) {
        seed(77); observed.fail_at = observed.calloc_calls + allocation; observed.fail_left = 2;
        CHECK(!source_finish(&input,&document,&failure) && failure.kind == 5 && ube_err_number() == 7);
        CHECK(observed.fail_left == 0 && document.bytes == old_document && document.scalars == 8 && equal(document.bytes,data,8));
        CHECK(memcmp(&before,&input,sizeof input) == 0);
    }
    observed.fail_left = 0; seed(77);
    CHECK(source_append(&input,&bytes,8,1,&failure) && source_finish(&input,&document,&failure) && document.scalars == 9 && ube_err_number() == 77);
    CHECK(!source_scoped(1) && source_scoped(0));
    for (int i = 2; i >= 0; --i) CHECK(ube_gc_root_leave(&roots[i]));
    (void)ube_gc_collect(); CHECK(ube_gc_live_allocation_bytes() == 0); return 0;
}

static int costs(int32_t n) {
    struct input input = {0}; struct document document = {0}; struct failure failure = {0}; void* bytes = NULL;
    root roots[3] = {0}; CHECK(ube_gc_root_enter(&roots[0],&input.buffer.storage));
    CHECK(ube_gc_root_enter(&roots[1],&document.bytes) && ube_gc_root_enter(&roots[2],&bytes));
    CHECK(ube_value_try_resize(&bytes,n,&byte_type,0)); for (int32_t i = 0; i < n; ++i) put(bytes,i,65);
    CHECK(source_begin(&input,n)); struct observations before = observed; LARGE_INTEGER start, end, frequency;
    CHECK(QueryPerformanceFrequency(&frequency) && QueryPerformanceCounter(&start));
    for (int32_t offset = 0; offset < n;) { int32_t count = n-offset > 4096 ? 4096 : n-offset; CHECK(source_append(&input,&bytes,offset,count,&failure)); offset += count; }
    size_t growth = observed.copied - before.copied, after_append = observed.copied;
    size_t reserve_copied = observed.reserve_copied-before.reserve_copied;
    CHECK(source_finish(&input,&document,&failure)); CHECK(QueryPerformanceCounter(&end));
    size_t copied = observed.copied - before.copied, snapshot = observed.copied-after_append, feeds = observed.feeds-before.feeds;
    CHECK(feeds == (size_t)n && document.scalars == n && document.lines == 1);
    CHECK(n == 0 ? copied == 0 : growth < 3*(size_t)n && snapshot <= 2*(size_t)n && copied < 5*(size_t)n);
    CHECK(growth-reserve_copied == (size_t)n && (n == 0 ? reserve_copied == 0 : reserve_copied < 2*(size_t)n));
    printf("{\"kind\":\"input\",\"n\":%d,\"feedCalls\":%zu,\"appendCopiedBytes\":%zu,\"growthCopiedBytes\":%zu,\"appendPayloadCopiedBytes\":%zu,\"snapshotCopiedBytes\":%zu,\"totalCopiedBytes\":%zu,\"allocationRequests\":%zu,\"requestedBytes\":%zu,\"callocZeroRequestedBytes\":%zu,\"elapsedMicroseconds\":%.3f}\n",n,feeds,growth,reserve_copied,growth-reserve_copied,snapshot,copied,observed.allocations-before.allocations,observed.requested-before.requested,observed.zero_requested-before.zero_requested,1e6*(double)(end.QuadPart-start.QuadPart)/(double)frequency.QuadPart);
    for (int i = 2; i >= 0; --i) CHECK(ube_gc_root_leave(&roots[i]));
    (void)ube_gc_collect(); CHECK(ube_gc_live_allocation_bytes() == 0); return 0;
}
#endif

struct worker { void* const* bytes; int32_t n, marker; };
static DWORD WINAPI worker_main(void* argument) {
    struct worker* work = argument; struct input input = {0}; struct document document = {0}; struct failure failure = {0}; root roots[2] = {0};
    DWORD result = 0;
    if (!ube_gc_root_enter(&roots[0],&input.buffer.storage) || !ube_gc_root_enter(&roots[1],&document.bytes)) return 1;
    seed(work->marker);
    for (unsigned round = 0; round < 16 && !result; ++round) {
        if (!source_begin(&input,work->n) || !source_append(&input,(void**)work->bytes,0,work->n,&failure) || !source_finish(&input,&document,&failure)) { result = 2; break; }
        if (document.scalars != work->n || document.lines != 1 || ube_err_number() != work->marker) { result = 3; break; }
        for (int32_t i = 0; i < work->n; ++i) if (get(document.bytes,i) != 65) { result = 4; break; }
        (void)ube_gc_collect();
    }
    if (!ube_gc_root_leave(&roots[1]) || !ube_gc_root_leave(&roots[0])) result = 5;
    return result;
}
static int workers(void) {
    void* bytes = NULL; root r = {0}; CHECK(ube_gc_root_enter(&r,&bytes)); CHECK(ube_value_try_resize(&bytes,256,&byte_type,0));
    for (int32_t i = 0; i < 256; ++i) put(bytes,i,65);
    struct worker args[4]; HANDLE threads[4];
    for (int32_t i = 0; i < 4; ++i) { args[i] = (struct worker){&bytes,256,100+i}; threads[i] = CreateThread(NULL,0,worker_main,&args[i],0,NULL); CHECK(threads[i] != NULL); }
    CHECK(WaitForMultipleObjects(4,threads,TRUE,20000) == WAIT_OBJECT_0);
    for (int i = 0; i < 4; ++i) { DWORD code = 99; CHECK(GetExitCodeThread(threads[i],&code) && code == 0); CHECK(CloseHandle(threads[i])); }
    for (int32_t i = 0; i < 256; ++i) CHECK(get(bytes,i) == 65);
    CHECK(ube_gc_root_leave(&r)); (void)ube_gc_collect(); CHECK(ube_gc_live_allocation_bytes() == 0); return 0;
}

#ifdef OBSERVE_INPUT
struct mutation { const WCHAR* path; int32_t length, succeeded; };
static void mutate_file(void* context) {
    struct mutation* mutation = context;
    HANDLE file = CreateFileW(mutation->path,GENERIC_WRITE,FILE_SHARE_READ | FILE_SHARE_WRITE,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,NULL);
    if (file == INVALID_HANDLE_VALUE) return;
    LARGE_INTEGER end; end.QuadPart = mutation->length;
    mutation->succeeded = SetFilePointerEx(file,end,NULL,FILE_BEGIN) && SetEndOfFile(file);
    if (!CloseHandle(file)) mutation->succeeded = 0;
}
#endif

static int files(void) {
    WCHAR directory[MAX_PATH], path[MAX_PATH]; CHECK(GetTempPathW(MAX_PATH,directory) != 0);
    CHECK(swprintf(path,MAX_PATH,L"%lsUBE-source-%lu-\x540d.bas",directory,(unsigned long)GetCurrentProcessId()) > 0);
    HANDLE file = CreateFileW(path,GENERIC_WRITE,FILE_SHARE_READ | FILE_SHARE_WRITE,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL); CHECK(file != INVALID_HANDLE_VALUE);
    const uint8_t data[] = {0xef,0xbb,0xbf,0xc3,0xa9,13,10,65}; DWORD wrote = 0;
    CHECK(WriteFile(file,data,sizeof data,&wrote,NULL) && wrote == sizeof data && CloseHandle(file));
    char utf8[MAX_PATH*4]; int length = WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,path,-1,utf8,sizeof utf8,NULL,NULL); CHECK(length > 0);
    void* bytes = NULL; struct document document = {0}; struct failure failure = {0}; root roots[2] = {0}; int32_t domain = 0, token = 0;
    CHECK(ube_gc_root_enter(&roots[0],&bytes) && ube_gc_root_enter(&roots[1],&document.bytes));
    CHECK(array(&bytes,(const uint8_t*)utf8,length-1)); seed(77);
    CHECK(source_file(&bytes,100,&document,&failure,&domain,&token));
    CHECK(equal(document.bytes,data,sizeof data) && document.content == 3 && document.scalars == 4 && document.lines == 2 && token == 0 && domain == 0 && ube_err_number() == 77);
#ifdef OBSERVE_INPUT
    CHECK(ube_file_test_open_handles() == 0);
    struct document original_document = document;
    seed(77); ube_gc_test_fail_next_allocations(2); ube_file_test_inject(6);
    CHECK(!source_file(&bytes,100,&document,&failure,&domain,&token));
    CHECK(failure.kind == 5 && domain == 0 && ube_err_number() == 57 && token != 0 && same_document(document,original_document) && equal(document.bytes,data,sizeof data));
    extern int32_t ube_file_try_close(int32_t*,int32_t*);
    CHECK(ube_file_try_close(&token,&domain) && token == 0 && ube_err_number() == 57 && ube_file_test_open_handles() == 0);
    ube_file_test_inject(0);
    const int32_t modes[] = {1,2,3,5,6};
    for (size_t i = 0; i < sizeof modes / sizeof *modes; ++i) {
        struct document old = document; seed(77); ube_file_test_inject(modes[i]);
        CHECK(!source_file(&bytes,100,&document,&failure,&domain,&token));
        CHECK(same_document(document,old) && equal(document.bytes,data,sizeof data));
        if (modes[i] == 6) {
            CHECK(token != 0 && ube_file_test_open_handles() == 1);
            extern int32_t ube_file_try_close(int32_t*,int32_t*); CHECK(ube_file_try_close(&token,&domain));
        }
        CHECK(token == 0 && ube_file_test_open_handles() == 0); ube_file_test_inject(0);
    }
    ube_file_test_inject(4); seed(77); int32_t before_reads = ube_file_test_reads();
    CHECK(source_file(&bytes,100,&document,&failure,&domain,&token));
    CHECK(ube_file_test_reads()-before_reads > 2 && equal(document.bytes,data,sizeof data)); ube_file_test_inject(0);
    CHECK(ube_file_test_payloads() > 0 && ube_file_test_open_handles() == 0);
    struct document old = document;
    ube_file_test_inject(7);
    CHECK(!source_file(&bytes,0,&document,&failure,&domain,&token) && token != 0 && same_document(document,old) && equal(document.bytes,data,sizeof data) && ube_file_test_open_handles() == 1);
    extern int32_t ube_file_try_close(int32_t*,int32_t*); CHECK(ube_file_try_close(&token,&domain) && token == 0);
    ube_file_test_inject(0);
    HANDLE exclusive = CreateFileW(path,GENERIC_READ,0,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,NULL); CHECK(exclusive != INVALID_HANDLE_VALUE);
    CHECK(!source_file(&bytes,100,&document,&failure,&domain,&token) && failure.kind == 6 && token == 0 && same_document(document,old) && equal(document.bytes,data,sizeof data));
    CHECK(CloseHandle(exclusive));
    for (int32_t change = 0; change < 2; ++change) {
        file = CreateFileW(path,GENERIC_WRITE,FILE_SHARE_READ | FILE_SHARE_WRITE,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL); CHECK(file != INVALID_HANDLE_VALUE);
        CHECK(WriteFile(file,data,sizeof data,&wrote,NULL) && wrote == sizeof data && CloseHandle(file));
        struct mutation mutation = {path,change ? 9 : 2,0};
        ube_file_test_before_read(mutate_file,&mutation);
        CHECK(!source_file(&bytes,100,&document,&failure,&domain,&token));
        CHECK(mutation.succeeded && failure.kind == 6 && domain == (change ? 11 : 6) && token == 0 && same_document(document,old) && equal(document.bytes,data,sizeof data) && ube_file_test_open_handles() == 0);
    }
    const int32_t sizes[] = {0,1,31,4095,4096,4097,16384,65536};
    uint8_t block[4096]; memset(block,65,sizeof block);
    for (size_t index = 0; index < sizeof sizes / sizeof *sizes; ++index) {
        int32_t n = sizes[index];
        file = CreateFileW(path,GENERIC_WRITE,FILE_SHARE_READ | FILE_SHARE_WRITE,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL); CHECK(file != INVALID_HANDLE_VALUE);
        for (int32_t offset = 0; offset < n;) { DWORD requested = n-offset > 4096 ? 4096 : (DWORD)(n-offset); CHECK(WriteFile(file,block,requested,&wrote,NULL) && wrote == requested); offset += (int32_t)wrote; }
        CHECK(CloseHandle(file));
        struct observations before = observed;
        int32_t reads = ube_file_test_reads(), payloads = ube_file_test_payloads();
        int64_t read_bytes = ube_file_test_bytes_read(), published_bytes = ube_file_test_bytes_published();
        seed(77); CHECK(source_file(&bytes,n,&document,&failure,&domain,&token));
        CHECK(document.scalars == n && document.lines == 1 && token == 0 && domain == 0 && ube_err_number() == 77 && ube_file_test_open_handles() == 0);
        CHECK(ube_file_test_bytes_read()-read_bytes == n && ube_file_test_bytes_published()-published_bytes == n && ube_file_test_payloads()-payloads == 1);
        CHECK(ube_file_test_reads()-reads == (n+4095)/4096+1 && observed.feeds-before.feeds == (size_t)n);
        for (int32_t i = 0; i < n; ++i) CHECK(get(document.bytes,i) == 65);
        printf("{\"kind\":\"file\",\"n\":%d,\"actualReadCalls\":%d,\"actualBytesRead\":%lld,\"actualBytesPublished\":%lld,\"scratchPayloadAllocations\":%d,\"feedCalls\":%zu,\"allocationRequests\":%zu,\"requestedBytes\":%zu,\"callocZeroRequestedBytes\":%zu,\"totalCopiedBytes\":%zu}\n",n,ube_file_test_reads()-reads,(long long)(ube_file_test_bytes_read()-read_bytes),(long long)(ube_file_test_bytes_published()-published_bytes),ube_file_test_payloads()-payloads,observed.feeds-before.feeds,observed.allocations-before.allocations,observed.requested-before.requested,observed.zero_requested-before.zero_requested,observed.copied-before.copied);
    }
#endif
    CHECK(DeleteFileW(path));
    struct document retained = document;
    int32_t retained_length = ube_value_array_length(&document.bytes);
    uint8_t* retained_bytes = malloc(retained_length ? (size_t)retained_length : 1); CHECK(retained_bytes != NULL);
    for (int32_t i = 0; i < retained_length; ++i) retained_bytes[i] = get(document.bytes,i);
    CHECK(!source_file(&bytes,100,&document,&failure,&domain,&token) && failure.kind == 6 && token == 0 && same_document(document,retained) && equal(document.bytes,retained_bytes,retained_length));
    free(retained_bytes);
    CHECK(ube_gc_root_leave(&roots[1]) && ube_gc_root_leave(&roots[0])); (void)ube_gc_collect(); CHECK(ube_gc_live_allocation_bytes() == 0); return 0;
}

int main(void) {
    const size_t layouts[] = {sizeof(struct input),sizeof(struct document),sizeof(struct failure),sizeof(struct position),sizeof(struct decoder),sizeof(struct buffer),offsetof(struct input,decoder),offsetof(struct input,cursor),offsetof(struct input,sequence),offsetof(struct input,carriage),offsetof(struct input,content),offsetof(struct input,maximum),offsetof(struct input,pending),offsetof(struct input,ready),offsetof(struct document,content),offsetof(struct document,scalars),offsetof(struct document,lines),offsetof(struct failure,position)};
    CHECK(ube_gc_root_storage_size() == sizeof(root));
    for (size_t i = 0; i < sizeof layouts / sizeof *layouts; ++i) CHECK(source_layout((int32_t)i) == layouts[i]);
    CHECK(vectors() == 0 && domains() == 0 && workers() == 0 && files() == 0);
#ifdef OBSERVE_INPUT
    CHECK(failures() == 0);
    const int32_t sizes[] = {0,1,31,4095,4096,4097,16384,65536};
    for (size_t i = 0; i < sizeof sizes / sizeof *sizes; ++i) CHECK(costs(sizes[i]) == 0);
    CHECK(source_test_root_count() == 0 && ube_file_test_open_handles() == 0);
#endif
    CHECK(ube_gc_live_allocation_bytes() == 0);
    printf("PASS source input assertions:%u\n",assertions); return 0;
}
