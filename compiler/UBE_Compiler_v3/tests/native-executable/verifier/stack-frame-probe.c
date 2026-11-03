#include <stdint.h>

extern void observe_frame(volatile uint8_t *frame);
extern int recursion_guard(void);

__declspec(noinline) int guarded_callee(int depth) {
    volatile uint8_t frame[8192];
    if (!recursion_guard()) return -1;
    frame[0] = (uint8_t)depth;
    observe_frame(frame);
    return (int)frame[0];
}

__declspec(noinline) int guarded_caller(int depth) {
    if (!recursion_guard()) return -1;
    return guarded_callee(depth) + 1;
}
