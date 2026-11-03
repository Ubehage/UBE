#include <stdint.h>
#include <stdio.h>

extern void ube_err_set(int32_t, const char *, const char *);
extern int32_t ube_err_number(void);
extern int16_t probe_remainder_i16(int16_t, int16_t);

int main(void) {
    const int32_t divisors[] = {-32768, -255, -7, -1, 1, 7, 255, 32767};
    ube_err_set(73, "seed", "test");
    for (int32_t dividend = -32768; dividend <= 32767; ++dividend) {
        for (unsigned int i = 0; i < sizeof(divisors) / sizeof(divisors[0]); ++i) {
            int32_t expected = dividend % divisors[i];
#ifdef WRONG_EXPECTATION
            if (dividend == -32768 && divisors[i] == -1) expected = 1;
#endif
            if (probe_remainder_i16((int16_t)dividend, (int16_t)divisors[i]) != expected || ube_err_number() != 73) return 1;
        }
        if (probe_remainder_i16((int16_t)dividend, 0) != 0 || ube_err_number() != 11) return 2;
        ube_err_set(73, "seed", "test");
    }
    puts("all i16 dividends passed eight divisors and zero-divisor error check");
    return 0;
}
