#include <stdint.h>
extern void ube_err_set(int32_t, const char *, const char *);

#ifdef MUTATE_SPECIAL
#define SPECIAL_ERROR() ube_err_set(11, "mutated", "test")
#else
#define SPECIAL_ERROR() ((void)0)
#endif

#define DEFINE_REMAINDER(width, type, minimum) \
__declspec(noinline) type probe_remainder_i##width(type left, type right) { \
    if (right == 0) { ube_err_set(11, "zero", "test"); return 0; } \
    if (left == (minimum) && right == -1) { SPECIAL_ERROR(); return 0; } \
    return (type)(left % right); \
}

DEFINE_REMAINDER(16, int16_t, INT16_MIN)
DEFINE_REMAINDER(32, int32_t, INT32_MIN)
DEFINE_REMAINDER(64, int64_t, INT64_MIN)
