#define _WIN32_WINNT 0x0602
#include <windows.h>
#include <stdint.h>
#include <stdio.h>

#ifndef TEST_FRAME_BYTES
#define TEST_FRAME_BYTES 8192
#endif
enum { FRAME_BYTES = TEST_FRAME_BYTES, RESERVE_BYTES = 65536, MAX_DEPTH = 64 };
typedef struct { int entered, refused, unwound, unsafe_for_large_frame; ULONG_PTR first_frame; } Result;

__declspec(noinline) static int has_test_space(Result *result, ULONG_PTR caller_address) {
    volatile unsigned char marker = 0;
    ULONG_PTR low = 0, high = 0, here = (ULONG_PTR)&marker;
    GetCurrentThreadStackLimits(&low, &high);
#ifdef ALWAYS_REFUSE_CONTROL
    (void)low; (void)high; (void)here; (void)result; (void)caller_address;
    return 0;
#else
    if (!(low < here && here < high && here - low > RESERVE_BYTES)) return 0;
    if (low < caller_address && caller_address < high && caller_address - low < 128 * 1024)
        result->unsafe_for_large_frame = 1;
    return 1;
#endif
}

__declspec(noinline) static int descend(Result *result, int depth) {
    volatile unsigned char frame[FRAME_BYTES];
    volatile size_t index = FRAME_BYTES - 1;
    frame[index] = (unsigned char)depth;
    ULONG_PTR address = (ULONG_PTR)&frame[index];
    if (depth == 1) result->first_frame = address;
    else if (address >= result->first_frame ||
             result->first_frame - address < (ULONG_PTR)(depth - 1) * FRAME_BYTES) return -1;
    ++result->entered;
    if (depth >= MAX_DEPTH) return -1;
    int value;
    if (!has_test_space(result, address)) { ++result->refused; value = 1; }
    else value = descend(result, depth + 1);
    if (frame[index] != (unsigned char)depth) return -1;
    ++result->unwound;
    return value;
}

static DWORD WINAPI worker(void *argument) {
    Result *result = (Result *)argument;
    volatile unsigned char marker = 0;
    if (!has_test_space(result, (ULONG_PTR)&marker)) return 1;
    if (descend(result, 1) != 1) return 2;
    if (result->entered < 2 || result->entered >= MAX_DEPTH ||
        result->refused != 1 || result->unwound != result->entered || !result->unsafe_for_large_frame) return 3;
    return 0;
}

int main(void) {
    Result result = {0};
    HANDLE thread = CreateThread(NULL, 256 * 1024, worker, &result,
                                 STACK_SIZE_PARAM_IS_A_RESERVATION, NULL);
    if (!thread) return 4;
    DWORD wait = WaitForSingleObject(thread, 10000), status = 9;
    BOOL observed = GetExitCodeThread(thread, &status);
    CloseHandle(thread);
    if (wait != WAIT_OBJECT_0 || !observed) return 5;
#ifdef ALWAYS_REFUSE_CONTROL
    if (status != 1 || result.entered != 0) return 6;
    puts("always-refuse control rejected before recursion");
#else
    if (status != 0) return 7;
    printf("guard refused after %d frames; all unwound; larger frame unsafe\n", result.entered);
#endif
    return 0;
}
