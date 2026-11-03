#define _WIN32_WINNT 0x0602
#include <windows.h>
#include <stdint.h>
#include <stdio.h>

enum { MARGIN = 65536, MAX_DEPTH = 64 };
typedef struct { int small, large, refused, unwound; ULONG_PTR last_frame; size_t last_size; } Result;
__declspec(noinline) static int enough_space(void) {
    volatile unsigned char marker = 0;
    ULONG_PTR low = 0, high = 0, here = (ULONG_PTR)&marker;
    GetCurrentThreadStackLimits(&low, &high);
#ifdef ALWAYS_REFUSE_CONTROL
    (void)low; (void)high; (void)here;
    return 0;
#else
    return low < here && here < high && here - low > MARGIN;
#endif
}
static int large_frame(Result *r, int depth);
__declspec(noinline) static int small_frame(Result *r, int depth) {
    volatile unsigned char frame[8192]; volatile size_t index = sizeof(frame)-1;
    ULONG_PTR address = (ULONG_PTR)&frame[index];
    if (r->last_frame && (address >= r->last_frame || r->last_frame - address < r->last_size-128)) return -1;
    r->last_frame = address; r->last_size = sizeof(frame);
    frame[index] = (unsigned char)depth; ++r->small;
    if (depth >= MAX_DEPTH) return -1;
    int value;
    if (!enough_space()) { ++r->refused; value = 1; }
    else value = large_frame(r, depth + 1);
    if (frame[index] != (unsigned char)depth) return -1;
    ++r->unwound; return value;
}
__declspec(noinline) static int large_frame(Result *r, int depth) {
    volatile unsigned char frame[32768]; volatile size_t index = sizeof(frame)-1;
    ULONG_PTR address = (ULONG_PTR)&frame[index];
    if (r->last_frame && (address >= r->last_frame || r->last_frame - address < r->last_size-128)) return -1;
    r->last_frame = address; r->last_size = sizeof(frame);
    frame[index] = (unsigned char)depth; ++r->large;
    if (depth >= MAX_DEPTH) return -1;
    int value;
    if (!enough_space()) { ++r->refused; value = 1; }
    else value = small_frame(r, depth + 1);
    if (frame[index] != (unsigned char)depth) return -1;
    ++r->unwound; return value;
}
static DWORD WINAPI worker(void *argument) {
    Result *r = (Result *)argument;
    if (!enough_space()) return 1;
    if (small_frame(r, 1) != 1 || r->small < 1 || r->large < 1 ||
        r->refused != 1 || r->unwound != r->small + r->large) return 2;
    return 0;
}
int main(void) {
    Result r = {0};
    HANDLE thread = CreateThread(NULL, 256 * 1024, worker, &r, STACK_SIZE_PARAM_IS_A_RESERVATION, NULL);
    if (!thread) return 3;
    DWORD wait = WaitForSingleObject(thread, 10000), status = 9;
    BOOL observed = GetExitCodeThread(thread, &status); CloseHandle(thread);
    if (wait != WAIT_OBJECT_0 || !observed) return 4;
#ifdef ALWAYS_REFUSE_CONTROL
    if (status != 1 || r.small != 0 || r.large != 0) return 5;
    puts("mixed always-refuse control rejected before recursion");
#else
    if (status != 0) return 6;
    printf("mixed guard refused after %d small and %d large frames; all unwound\n", r.small, r.large);
#endif
    return 0;
}
