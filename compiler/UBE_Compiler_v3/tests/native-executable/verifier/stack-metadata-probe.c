#include <stdint.h>

extern const uint64_t required_frame;
extern int check_frame(uint64_t);
extern void observe_frame(volatile unsigned char *);

__declspec(noinline) int measured_callee(int value) {
    volatile unsigned char frame[8192]; volatile unsigned int index = 8191;
    frame[index] = (unsigned char)value;
    observe_frame(frame);
    return frame[index];
}
__declspec(noinline) int metadata_caller(int value) {
    if (!check_frame(required_frame)) return -1;
    return measured_callee(value) + 1;
}
