#include <stddef.h>

extern void observe_dynamic(volatile unsigned char *frame, size_t count);

__declspec(noinline) void dynamic_frame(size_t count) {
    volatile unsigned char frame[count];
    observe_dynamic(frame, count);
}
