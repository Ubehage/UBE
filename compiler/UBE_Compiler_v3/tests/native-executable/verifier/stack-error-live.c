#define _WIN32_WINNT 0x0602
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#ifdef COMMITTED_PAGE_GUARD
#include "stack-committed-pages.h"
#endif

extern void ube_err_set(int32_t, const char *, const char *);
extern int32_t ube_err_number(void);
extern void ube_err_clear(void);
extern int64_t ube_checked_add_i64(int64_t, int64_t);
enum { FRAME = 8192, RESERVE = 65536, MAX_DEPTH = 64 };
#ifdef LINKED_STACK_FRAME
extern const uint64_t required_frame;
#define NEXT_FRAME required_frame
#else
#define NEXT_FRAME FRAME
#endif
typedef struct { int seeded, arguments, entries, unwound, refused, unsafe; ULONG_PTR first_frame; } Result;

__declspec(noinline) static int has_space(void) {
#ifdef FAILED_STACK_QUERY_CONTROL
    return -1;
#else
    volatile unsigned char marker = 0;
    ULONG_PTR low = 0, high = 0, here = (ULONG_PTR)&marker;
    GetCurrentThreadStackLimits(&low, &high);
    if (low >= here || here >= high) return -1;
#ifdef COMMITTED_PAGE_GUARD
    unsigned int pages = 0;
    ULONG_PTR bound = low;
    if (!stack_writable_floor(here, bound, &low, &pages)) return -1;
#ifdef COMPARE_REGION_GUARD
    ULONG_PTR region_floor = 0; unsigned int regions = 0;
    if (!stack_writable_floor_regions(here, bound, &region_floor, &regions) || region_floor != low) return -1;
#endif
#endif
    ULONG_PTR available = here-low;
    return NEXT_FRAME <= available && RESERVE <= available-NEXT_FRAME;
#endif
}
static int next_argument(Result *r, int depth) { ++r->arguments; return depth; }
static int descend(Result *r, int depth);
__declspec(noinline) static int checked_call(Result *r, int depth) {
    int space = has_space();
    if (space < 0) { ++r->unsafe; return -2; }
    if (!space) {
        ++r->refused;
#ifdef WRONG_STACK_ERROR_CONTROL
        ube_err_set(11, "test", "test");
#else
        ube_err_set(28, "test", "test");
#endif
#ifdef WRONG_STACK_RESULT_CONTROL
        return 1;
#else
        return 0;
#endif
    }
    return descend(r, depth);
}
__declspec(noinline) static int descend(Result *r, int depth) {
    volatile unsigned char frame[FRAME]; volatile size_t index = FRAME-1;
    frame[index] = (unsigned char)depth;
    ULONG_PTR address = (ULONG_PTR)&frame[index];
    if (depth == 1) r->first_frame = address;
    else if (address >= r->first_frame || r->first_frame-address < (ULONG_PTR)(depth-1)*FRAME) return -1;
    ++r->entries;
    if (depth >= MAX_DEPTH) return -1;
    int result = checked_call(r, next_argument(r, depth+1));
    if (frame[index] != (unsigned char)depth) return -1;
    ++r->unwound;
    return result;
}
static DWORD WINAPI worker(void *argument) {
    Result *r = (Result *)argument;
    ube_err_clear(); if (r->seeded) ube_err_set(77, "seed", "test");
    int result = checked_call(r, next_argument(r, 1));
    int32_t observed = ube_err_number();
    if (ube_checked_add_i64(1, 2) != 3 || ube_err_number() != observed) return 2;
#ifdef FAILED_STACK_QUERY_CONTROL
    if (result != -2 || observed != (r->seeded ? 77 : 0) || r->unsafe != 1 ||
        r->arguments != 1 || r->entries != 0 || r->unwound != 0 || r->refused != 0) return 1;
#elif defined(OVERSIZED_STACK_FRAME_CONTROL)
    if (result != 0 || observed != 28 || r->unsafe != 0 || r->refused != 1 ||
        r->arguments != 1 || r->entries != 0 || r->unwound != 0) return 1;
#else
    if (result != 0 || observed != 28 || r->entries < 2 || r->entries >= MAX_DEPTH ||
        r->unsafe != 0 || r->refused != 1 || r->arguments != r->entries+1 || r->unwound != r->entries) return 1;
#endif
    return 0;
}
int main(void) {
    ube_err_clear(); ube_err_set(99, "main", "test");
    for (int seeded = 0; seeded <= 1; ++seeded) {
        Result r = {0}; r.seeded = seeded;
        HANDLE thread = CreateThread(NULL, 256*1024, worker, &r, STACK_SIZE_PARAM_IS_A_RESERVATION, NULL);
        if (!thread) return 4;
        DWORD wait = WaitForSingleObject(thread, 10000), status = 9;
        BOOL observed = GetExitCodeThread(thread, &status); CloseHandle(thread);
        if (wait != WAIT_OBJECT_0 || !observed || status != 0 || ube_err_number() != 99) return 1;
    }
#ifdef FAILED_STACK_QUERY_CONTROL
    puts("unreliable stack query did not report a recoverable refusal");
#elif defined(OVERSIZED_STACK_FRAME_CONTROL)
    puts("oversized linked frame refused before entering callee");
#else
    puts("guarded recursion, argument effects and thread-local error passed");
#endif
    return 0;
}
