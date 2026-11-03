#define _WIN32_WINNT 0x0602
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#ifdef COMMITTED_PAGE_WALK
#include "stack-committed-pages.h"
#endif

enum { FRAME = 8192, LARGE_FRAME = 131072, RESERVE = 65536, MAX_DEPTH = 192 };
#ifdef USE_LINKED_FRAME
extern const uint64_t required_frame;
#define NEXT_FRAME required_frame
#else
#define NEXT_FRAME FRAME
#endif
typedef struct { int entered, refused, unwound, large_declined; ULONG_PTR first_frame; } Result;
#ifdef COMMITTED_STACK_CONTROL
static ULONG_PTR observed_available;
static DWORD observed_state, observed_protect;
static uint64_t observed_reserved, observed_committed, observed_guarded;
#ifdef COMMITTED_PAGE_WALK
static unsigned int observed_pages;
#endif
__declspec(noinline) static void observe_regions(void) {
    ULONG_PTR low = 0, high = 0;
    GetCurrentThreadStackLimits(&low, &high);
#ifdef STACK_REGION_TRACE
    fprintf(stderr, "region walk: thread=%lu low=%p high=%p\n", (unsigned long)GetCurrentThreadId(), (void *)low, (void *)high);
#endif
    for (ULONG_PTR cursor = low; cursor < high;) {
        MEMORY_BASIC_INFORMATION region = {0};
        if (!VirtualQuery((void *)cursor, &region, sizeof(region))) return;
        ULONG_PTR base = (ULONG_PTR)region.BaseAddress;
        if (region.RegionSize > UINTPTR_MAX-base) return;
        ULONG_PTR end = base+region.RegionSize;
        if (end <= cursor) return;
        if (end > high) end = high;
        uint64_t length = (uint64_t)(end-cursor);
#ifdef STACK_REGION_TRACE
        fprintf(stderr, "offset=%llu length=%llu state=%lu protect=%lu\n", (unsigned long long)(cursor-low),
                (unsigned long long)length, (unsigned long)region.State, (unsigned long)region.Protect);
#endif
        if (region.State == MEM_RESERVE) observed_reserved += length;
        else if (region.State == MEM_COMMIT && (region.Protect & PAGE_GUARD)) observed_guarded += length;
        else if (region.State == MEM_COMMIT) observed_committed += length;
        cursor = end;
    }
}
#endif
static int fits(ULONG_PTR available, ULONG_PTR next, ULONG_PTR reserve) {
#ifdef IGNORE_FRAME_CONTROL
    (void)next;
    return reserve <= available;
#else
    return next <= available && reserve <= available - next;
#endif
}
__declspec(noinline) static int can_enter(ULONG_PTR next) {
    volatile unsigned char marker = 0;
    ULONG_PTR low = 0, high = 0, here = (ULONG_PTR)&marker;
#ifdef COMMITTED_STACK_CONTROL
    MEMORY_BASIC_INFORMATION region = {0};
    if (!VirtualQuery((void *)here, &region, sizeof(region))) return 0;
#ifdef STACK_REGION_TRACE
    fprintf(stderr, "guard: thread=%lu marker=%p base=%p allocation=%p region-size=%llu\n",
            (unsigned long)GetCurrentThreadId(), (void *)here, region.BaseAddress, region.AllocationBase,
            (unsigned long long)region.RegionSize);
#endif
    observed_state = region.State; observed_protect = region.Protect;
    low = (ULONG_PTR)region.BaseAddress;
    if (low < here) observed_available = here-low;
    if (region.State != MEM_COMMIT ||
        (region.Protect & PAGE_GUARD) || (region.Protect & 0xff) != PAGE_READWRITE) return 0;
    if (region.RegionSize > UINTPTR_MAX-low) return 0;
    high = low + region.RegionSize;
#ifdef COMMITTED_PAGE_WALK
    ULONG_PTR stack_low = 0, stack_high = 0;
    GetCurrentThreadStackLimits(&stack_low, &stack_high);
    if (stack_low >= here || here >= stack_high) return 0;
    unsigned int pages = 0;
    if (!stack_writable_floor(here, stack_low, &low, &pages)) return 0;
    high = stack_high;
    if (pages > observed_pages) observed_pages = pages;
#endif
#else
    GetCurrentThreadStackLimits(&low, &high);
#endif
    return low < here && here < high && fits(here-low, next, RESERVE);
}
__declspec(noinline) static int descend(Result *result, int depth) {
    volatile unsigned char frame[FRAME]; volatile size_t index = FRAME-1;
    frame[index] = (unsigned char)depth;
    ULONG_PTR address = (ULONG_PTR)&frame[index];
    if (depth == 1) result->first_frame = address;
    else if (address >= result->first_frame || result->first_frame - address < (ULONG_PTR)(depth-1)*FRAME) return -1;
    ++result->entered;
    if (depth >= MAX_DEPTH) return -1;
    int small = can_enter(NEXT_FRAME);
    if (small && !can_enter(LARGE_FRAME)) result->large_declined = 1;
    int value;
    if (!small) { ++result->refused; value = 1; }
    else value = descend(result, depth+1);
    if (frame[index] != (unsigned char)depth) return -1;
    ++result->unwound; return value;
}
static DWORD WINAPI worker(void *argument) {
    Result *r = (Result *)argument;
#ifdef COMMITTED_STACK_CONTROL
    observe_regions();
#endif
    if (!can_enter(NEXT_FRAME)) return 1;
    if (descend(r, 1) != 1 || r->entered < 2 || r->entered >= MAX_DEPTH ||
        r->refused != 1 || r->unwound != r->entered || !r->large_declined) return 2;
    return 0;
}
int main(void) {
    if (!fits(100, 60, 40) || fits(99, 60, 40) ||
        fits(100, (ULONG_PTR)-1, 40)) return 1;
    Result result = {0};
#ifdef THREAD_COMMIT_CONTROL
    DWORD thread_flags = 0;
#else
    DWORD thread_flags = STACK_SIZE_PARAM_IS_A_RESERVATION;
#endif
    HANDLE thread = CreateThread(NULL, 256*1024, worker, &result, thread_flags, NULL);
    if (!thread) return 2;
    DWORD wait = WaitForSingleObject(thread, 10000), status = 9;
    BOOL observed = GetExitCodeThread(thread, &status); CloseHandle(thread);
#ifdef COMMITTED_STACK_CONTROL
    if (wait == WAIT_OBJECT_0 && observed && status == 1 && result.entered == 0) {
        printf("committed guard refused before recursion: available=%llu state=%lu protect=%lu reserved=%llu committed=%llu guarded=%llu\n",
               (unsigned long long)observed_available, (unsigned long)observed_state, (unsigned long)observed_protect,
               (unsigned long long)observed_reserved, (unsigned long long)observed_committed, (unsigned long long)observed_guarded);
        return 0;
    }
#endif
    if (wait != WAIT_OBJECT_0 || !observed || status != 0) {
        fprintf(stderr, "worker observation: wait=%lu status=%lu entered=%d refused=%d\n",
                (unsigned long)wait, (unsigned long)status, result.entered, result.refused);
        return 3;
    }
#ifdef COMMITTED_PAGE_WALK
    printf("committed pages walked=%u\n", observed_pages);
#endif
    printf("frame-aware test refused a larger frame and unwound %d smaller frames\n", result.entered);
    return 0;
}
