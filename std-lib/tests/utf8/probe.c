/* Independent test oracle/instrumentation; no product decoding implementation. */
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern uint64_t test_state_size(void), test_state_alignment(void);
extern void test_reset(void*), test_copy(void*, void*), test_disturb(void*);
extern void test_corrupt(void*, int32_t);
extern int32_t test_feed(void*, uint8_t, int32_t*, int32_t*), test_finish(void*);
extern void ube_err_set(int32_t, const char*, const char*);
extern int32_t ube_err_number(void);
extern void* ube_array_redim(void*, int32_t, int32_t, size_t, int);
extern void ube_array_release(void*);
static volatile LONG measuring;
static volatile LONG64 allocations;
void* probe_malloc(size_t n) {
    if (measuring) InterlockedIncrement64(&allocations);
    return malloc(n);
}
void* probe_calloc(size_t n, size_t s) {
    if (measuring) InterlockedIncrement64(&allocations);
    return calloc(n, s);
}
void* probe_realloc(void* p, size_t n) {
    if (measuring) InterlockedIncrement64(&allocations);
    return realloc(p, n);
}
typedef union { uint64_t align; unsigned char bytes[32]; } state;
static uint64_t feeds;
static int fail(const char* what) {
    fprintf(stderr, "UTF-8 acceptance failed: %s\n", what);
    return 0;
}
static int feed(state* s, uint8_t b, int32_t* scalar, int32_t* complete) {
    ++feeds;
    return test_feed(s, b, scalar, complete);
}
/* Independent whole-sequence oracle: accumulate digits, then check shortest
   length and Unicode scalar membership, rather than mirror the streaming state. */
static int reference(const uint8_t* p, size_t n, int32_t* out, size_t* count) {
    size_t at = 0;
    *count = 0;
    while (at < n) {
        uint32_t first = p[at++], value;
        unsigned extra;
        if (first < 128) { value = first; extra = 0; }
        else if ((first & 0xe0) == 0xc0) { value = first & 31; extra = 1; }
        else if ((first & 0xf0) == 0xe0) { value = first & 15; extra = 2; }
        else if ((first & 0xf8) == 0xf0) { value = first & 7; extra = 3; }
        else return 0;
        if (n - at < extra) return 0;
        for (unsigned j = 0; j < extra; ++j) {
            uint32_t next = p[at++];
            if ((next & 0xc0) != 0x80) return 0;
            value = value * 64 + (next & 63);
        }
        unsigned shortest = value < 128 ? 0 : value < 2048 ? 1 : value < 65536 ? 2 : 3;
        if (extra != shortest || value > 0x10ffff || (value >= 0xd800 && value <= 0xdfff)) return 0;
        out[(*count)++] = (int32_t)value;
    }
    return 1;
}
static size_t encode(uint32_t cp, uint8_t* p) {
    if (cp < 128) { p[0] = (uint8_t)cp; return 1; }
    if (cp < 2048) { p[0] = 0xc0 | (cp >> 6); p[1] = 0x80 | (cp & 63); return 2; }
    if (cp < 65536) {
        p[0] = 0xe0 | (cp >> 12); p[1] = 0x80 | ((cp >> 6) & 63); p[2] = 0x80 | (cp & 63); return 3;
    }
    p[0] = 0xf0 | (cp >> 18); p[1] = 0x80 | ((cp >> 12) & 63);
    p[2] = 0x80 | ((cp >> 6) & 63); p[3] = 0x80 | (cp & 63); return 4;
}
static int sequence(const uint8_t* p, size_t n) {
    state s = {0}; /* Prove neutral initialization independently of Reset. */
    int32_t expected[16];
    size_t expected_count, actual_count = 0;
    int expected_valid = reference(p, n, expected, &expected_count), valid = 1;
    for (size_t i = 0; i < n; ++i) {
        int32_t scalar = -7, complete = -7;
        int accepted = feed(&s, p[i], &scalar, &complete);
        if (!accepted) {
            if (scalar || complete) return fail("failure outputs are not neutral");
            valid = 0;
            break;
        }
        if (complete) {
            if (actual_count >= expected_count || scalar != expected[actual_count++]) return fail("decoded scalar differs");
        } else if (scalar != 0) return fail("pending scalar is not neutral");
    }
    if (!test_finish(&s)) valid = 0;
    if (valid != expected_valid || actual_count != expected_count) return fail("whole-sequence result differs");
    if (!valid) {
        int32_t scalar = 99, complete = 99;
        if (feed(&s, 65, &scalar, &complete) || scalar || complete || test_finish(&s)) return fail("failure was not sticky");
    } else if (!test_finish(&s)) return fail("repeated finish failed");
    return 1;
}
static int state_cases(void) {
    state a = {0}, b = {0};
    int32_t scalar, complete;
    if (!feed(&a, 0xf0, &scalar, &complete) || complete || !feed(&a, 0x9f, &scalar, &complete) || complete) return fail("split prefix");
    test_copy(&b, &a);
    test_disturb(&a); /* UBE ByVal mutation must not reset the caller. */
    if (!feed(&a, 0x98, &scalar, &complete) || complete || !feed(&a, 0x80, &scalar, &complete) || !complete || scalar != 0x1f600) return fail("ByVal/copy original");
    if (!feed(&b, 0x98, &scalar, &complete) || complete || !feed(&b, 0x81, &scalar, &complete) || !complete || scalar != 0x1f601) return fail("independent copy");
    test_reset(&a);
    if (!test_finish(&a) || !feed(&a, 0xe2, &scalar, &complete) || test_finish(&a)) return fail("truncated finish");
    test_reset(&a);
    if (!feed(&a, 0, &scalar, &complete) || !complete || scalar != 0 || !test_finish(&a)) return fail("reset/NUL");
    for (int i = 0; i < 5; ++i) {
        test_corrupt(&a, i);
        scalar = complete = 99;
        if (feed(&a, 0x80, &scalar, &complete) || scalar || complete) return fail("corrupt state accepted");
    }
    return ube_err_number() == 77 || fail("stale Err changed");
}
static const uint8_t shared_input[] = {0,65,0xc2,0xa2,0xe2,0x82,0xac,0xf0,0x9f,0x98,0x80};
static const int32_t shared_scalars[] = {0,65,0xa2,0x20ac,0x1f600};
static int work_cases(void) {
    const unsigned blocks[] = {1,16,256,4096};
    for (size_t k = 0; k < sizeof(blocks)/sizeof(blocks[0]); ++k) {
        state s = {0};
        uint64_t before = feeds;
        unsigned count = 0;
        for (unsigned block = 0; block < blocks[k]; ++block) {
            for (size_t i = 0; i < sizeof(shared_input); ++i) {
                int32_t scalar, complete;
                if (!feed(&s, shared_input[i], &scalar, &complete)) return fail("workload input");
                if (complete && scalar != shared_scalars[count++ % 5]) return fail("workload scalar");
            }
        }
        if (!test_finish(&s) || count != 5 * blocks[k] || feeds - before != sizeof(shared_input) * blocks[k]) return fail("work budget");
    }
    return 1;
}
static HANDLE go;
static volatile LONG ready;
static DWORD WINAPI worker(void* argument) {
    int32_t err = 80 + (int32_t)(uintptr_t)argument;
    ube_err_set(err, "worker", "decoder test");
    InterlockedIncrement(&ready);
    if (WaitForSingleObject(go, 10000) != WAIT_OBJECT_0) return 1;
    for (int iteration = 0; iteration < 10000; ++iteration) {
        state s = {0};
        size_t count = 0;
        for (size_t i = 0; i < sizeof(shared_input); ++i) {
            int32_t scalar, complete;
            if (!test_feed(&s, shared_input[i], &scalar, &complete)) return 2;
            if (complete && (count >= 5 || scalar != shared_scalars[count++])) return 3;
        }
        if (count != 5 || !test_finish(&s) || ube_err_number() != err) return 4;
    }
    return 0;
}
static int concurrent(void) {
    HANDLE threads[4] = {0};
    go = CreateEventW(NULL, TRUE, FALSE, NULL);
    if (!go) return fail("create start event");
    int ok = 1;
    size_t created = 0;
    for (; created < 4; ++created) {
        threads[created] = CreateThread(NULL, 0, worker, (void*)(uintptr_t)created, 0, NULL);
        if (!threads[created]) { ok = 0; break; }
    }
    DWORD start = GetTickCount();
    while (ready != (LONG)created && GetTickCount() - start < 10000) Sleep(1);
    if (ready != (LONG)created) ok = 0;
    measuring = 1;
    SetEvent(go);
    for (size_t i = 0; i < created; ++i) {
        DWORD result = 99;
        if (WaitForSingleObject(threads[i], 10000) != WAIT_OBJECT_0) {
            /* Do not let a timed-out worker outlive stack/process test state. */
            fputs("decoder worker timed out\n", stderr);
            ExitProcess(2);
        }
        if (!GetExitCodeThread(threads[i], &result) || result != 0) ok = 0;
        CloseHandle(threads[i]);
    }
    measuring = 0;
    CloseHandle(go);
    return ok || fail("independent worker result");
}
int main(void) {
    if (test_state_size() != 16 || test_state_alignment() != 4) return !fail("state layout");
    ube_err_set(77, "pre-existing", "decoder test");
    /* Confirm that the instrumented runtime call boundary observes allocation. */
#ifdef PROBE_ALLOCATIONS
    measuring = 1;
    void* allocation = ube_array_redim(NULL, 0, 0, 1, 0);
    measuring = 0;
    ube_array_release(allocation);
    if (allocations != 1) return !fail("allocator instrumentation is inactive");
#endif
    allocations = 0;
    measuring = 1;
    uint8_t bytes[8] = {0};
    if (!sequence(bytes, 0)) return 1;
    for (uint32_t cp = 0; cp <= 0x10ffff; ++cp) {
        if (cp >= 0xd800 && cp <= 0xdfff) continue;
        if (!sequence(bytes, encode(cp, bytes))) { fprintf(stderr, "scalar:%u\n", cp); return 1; }
    }
    for (unsigned a = 0; a < 256; ++a) {
        bytes[0] = (uint8_t)a;
        if (!sequence(bytes, 1)) return 1;
        for (unsigned b = 0; b < 256; ++b) {
            bytes[1] = (uint8_t)b;
            if (!sequence(bytes, 2)) return 1;
        }
    }
    static const struct { size_t n; uint8_t b[8]; } boundaries[] = {
        {3,{0xe0,0x80,0x80}}, {3,{0xe0,0x9f,0xbf}}, {3,{0xe0,0xa0,0x80}},
        {3,{0xed,0x9f,0xbf}}, {3,{0xed,0xa0,0x80}}, {3,{0xed,0xbf,0xbf}},
        {3,{0xee,0x80,0x80}}, {4,{0xf0,0x80,0x80,0x80}}, {4,{0xf0,0x8f,0xbf,0xbf}},
        {4,{0xf0,0x90,0x80,0x80}}, {4,{0xf4,0x8f,0xbf,0xbf}}, {4,{0xf4,0x90,0x80,0x80}},
        {4,{0xf5,0x80,0x80,0x80}}, {4,{0xff,0xff,0xff,0xff}}, {3,{0xe2,0x28,0xa1}},
        {6,{0xed,0xa0,0xbd,0xed,0xb8,0x80}}, {3,{0xef,0xbb,0xbf}}, {3,{0xef,0xbf,0xbe}},
        {5,{65,0xe0,0x80,0x80,66}}
    };
    for (size_t i = 0; i < sizeof(boundaries)/sizeof(boundaries[0]); ++i) {
        for (size_t n = 0; n <= boundaries[i].n; ++n) {
            if (!sequence(boundaries[i].b, n)) return 1;
        }
    }
    uint32_t random = 0x9e3779b9;
    for (unsigned i = 0; i < 50000; ++i) {
        size_t n = i % 9;
        for (size_t j = 0; j < n; ++j) {
            random ^= random << 13; random ^= random >> 17; random ^= random << 5;
            bytes[j] = (uint8_t)random;
        }
        if (!sequence(bytes, n)) return 1;
    }
    /* Explicit multi-scalar input includes embedded NUL and a supplementary scalar. */
    if (!sequence(shared_input, sizeof(shared_input)) || !state_cases() || !work_cases()) return 1;
    measuring = 0;
    fprintf(stderr, "MEASURE sequential-feed-calls:%llu\n", (unsigned long long)feeds);
    if (!concurrent() || allocations != 0 || ube_err_number() != 77) return !fail("allocation/Err budget");
    puts("PASS scalars:1112064 single:256 pairs:65536 random:50000");
    puts("PASS state:copy/byval/reset/sticky/truncated/corrupt err:77");
    puts("PASS workers:4 iterations:10000 input:immutable errors:independent");
    puts("PASS work:11/176/2816/45056 bytes one-feed-per-byte");
#ifdef PROBE_ALLOCATIONS
    puts("PASS allocations:0 state:16:4");
#else
    puts("PASS runtime:accepted state:16:4");
#endif
    return 0;
}
