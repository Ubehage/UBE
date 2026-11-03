#include <stdint.h>

int guarded_caller(int depth);
static int allowed, guards, observations;

int recursion_guard(void) {
    ++guards;
#ifdef ALWAYS_ALLOW_CONTROL
    (void)allowed;
    return 1;
#else
    return allowed;
#endif
}
void observe_frame(volatile uint8_t *frame) {
    if (frame[0] == 7) ++observations;
}
int main(void) {
    allowed = 0; guards = 0; observations = 0;
    if (guarded_caller(7) != -1 || guards != 1 || observations != 0) return 1;
    allowed = 1; guards = 0; observations = 0;
    if (guarded_caller(7) != 8 || guards != 2 || observations != 1) return 2;
    return 0;
}
