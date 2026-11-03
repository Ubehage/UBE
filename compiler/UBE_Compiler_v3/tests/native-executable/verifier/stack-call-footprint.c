#include <stdint.h>
#include <stdio.h>

#ifndef FRAME_BYTES
#define FRAME_BYTES 8192
#endif

/* Test-only x86-64 observer: no UBE runtime or production guard is substituted. */
extern const uint64_t required_call_bytes;
static uintptr_t observed_delta;
static unsigned int entries, unwound;

__declspec(noinline) static int descend(uintptr_t parent_rsp, unsigned int depth) {
    volatile unsigned char frame[FRAME_BYTES];
    volatile unsigned int index = FRAME_BYTES - 1;
    uintptr_t here;
    __asm__ volatile("movq %%rsp, %0" : "=r"(here));
    frame[index] = (unsigned char)depth;
    ++entries;
    if (depth == 2) {
        if (parent_rsp <= here) return 2;
        observed_delta = parent_rsp - here;
        ++unwound;
        return observed_delta == required_call_bytes ? 0 : 1;
    }
    int result = descend(here, depth + 1);
    if (frame[index] != (unsigned char)depth) return 3;
    ++unwound;
    return result;
}

int main(void) {
    int result = descend(0, 1);
    if (entries != 2 || unwound != 2) return 4;
    printf("call-bytes=%llu expected=%llu entries=%u unwound=%u\n",
           (unsigned long long)observed_delta,
           (unsigned long long)required_call_bytes, entries, unwound);
    return result;
}
