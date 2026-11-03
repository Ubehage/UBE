#include <stdint.h>
#include <stdio.h>

extern int64_t ube_checked_narrow_i64(int64_t, int32_t, int32_t);
extern void ube_err_set(int32_t, const char *, const char *);
extern int32_t ube_err_number(void);

typedef struct { int bits, unsigned_result; int64_t value, expected; int failure; } Case;
int main(void) {
    const Case cases[] = {
        {8, 1, 0, 0, 0}, {8, 1, 255, 255, 0}, {8, 1, -1, 0, 1}, {8, 1, 256, 0, 1},
        {16, 0, -32768, -32768, 0}, {16, 0, 32767, 32767, 0},
        {16, 0, -32769, 0, 1}, {16, 0, 32768, 0, 1},
        {32, 0, INT64_C(-2147483648), INT64_C(-2147483648), 0},
        {32, 0, INT64_C(2147483647), INT64_C(2147483647), 0},
        {32, 0, INT64_C(-2147483649), 0, 1}, {32, 0, INT64_C(2147483648), 0, 1}
    };
    for (unsigned int i = 0; i < sizeof(cases)/sizeof(cases[0]); ++i) {
        for (int seed = 0; seed <= 73; seed += 73) {
            volatile int64_t input = cases[i].value;
            int expected_error = cases[i].failure ? 6 : seed;
            int64_t expected = cases[i].expected;
#ifdef WRONG_ERROR
            if (cases[i].failure) expected_error = 11;
#endif
#ifdef WRONG_VALUE
            if (cases[i].bits == 16 && cases[i].value == 32767) expected = 0;
#endif
#ifdef WRONG_PRESERVATION
            if (!cases[i].failure && seed == 73) expected_error = 0;
#endif
            ube_err_set(seed, "seed", "test");
            int64_t actual = ube_checked_narrow_i64(input, cases[i].bits, cases[i].unsigned_result);
            if (actual != expected || ube_err_number() != expected_error) return 1;
        }
    }
    puts("12 narrowing boundaries, both Err states passed");
    return 0;
}
