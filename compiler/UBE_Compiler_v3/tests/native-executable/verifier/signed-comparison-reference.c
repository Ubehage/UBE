#include <stdint.h>
#include <stdio.h>

#ifdef UNSIGNED_ORDER_CONTROL
typedef uint16_t test_integer;
typedef uint32_t test_long;
#else
typedef int16_t test_integer;
typedef int32_t test_long;
#endif

#define CHECK_PAIR(minimum, maximum) do { \
    score += (minimum) < (maximum); \
    score += !((maximum) < (minimum)); \
    score += (minimum) <= (minimum); \
    score += !((maximum) <= (minimum)); \
    score += (maximum) > (minimum); \
    score += !((minimum) > (maximum)); \
    score += (maximum) >= (maximum); \
    score += !((minimum) >= (maximum)); \
    score += (minimum) == (minimum); \
    score += !((minimum) == (maximum)); \
    score += (minimum) != (maximum); \
    score += !((maximum) != (maximum)); \
} while (0)

int main(void) {
    volatile test_integer imin = (test_integer)INT16_MIN, imax = INT16_MAX;
    volatile test_long lmin = (test_long)INT32_MIN, lmax = INT32_MAX;
    int score = 0;
    CHECK_PAIR(imin, imax);
    CHECK_PAIR(lmin, lmax);
    printf("%d\n", score);
    return score == 24 ? 0 : 1;
}
