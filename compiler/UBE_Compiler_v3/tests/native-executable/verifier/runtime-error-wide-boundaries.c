#include <stdint.h>
#include <stdio.h>

extern void ube_err_set(int32_t, const char *, const char *);
extern int32_t ube_err_number(void);
extern int32_t probe_remainder_i32(int32_t, int32_t);
extern int64_t probe_remainder_i64(int64_t, int64_t);

int main(void) {
    const int32_t a32[] = {INT32_MIN, INT32_MIN + 1, -32769, -17, -1, 0, 1, 17, 32768, INT32_MAX - 1, INT32_MAX};
    const int32_t b32[] = {INT32_MIN, -32768, -7, -1, 0, 1, 7, 32767, INT32_MAX};
    const int64_t a64[] = {INT64_MIN, INT64_MIN + 1, INT32_MIN, -17, -1, 0, 1, 17, INT32_MAX, INT64_MAX - 1, INT64_MAX};
    const int64_t b64[] = {INT64_MIN, INT32_MIN, -7, -1, 0, 1, 7, INT32_MAX, INT64_MAX};
    for (unsigned int i = 0; i < sizeof(a32) / sizeof(a32[0]); ++i) {
        for (unsigned int j = 0; j < sizeof(b32) / sizeof(b32[0]); ++j) {
            int32_t expected = b32[j] ? (int32_t)((int64_t)a32[i] % (int64_t)b32[j]) : 0;
            ube_err_set(73, "seed", "test");
            int32_t result = probe_remainder_i32(a32[i], b32[j]);
            if (result != expected || ube_err_number() != (b32[j] ? 73 : 11)) return 1;
        }
    }
    for (unsigned int i = 0; i < sizeof(a64) / sizeof(a64[0]); ++i) {
        for (unsigned int j = 0; j < sizeof(b64) / sizeof(b64[0]); ++j) {
            int64_t expected = b64[j] == 0 || (a64[i] == INT64_MIN && b64[j] == -1) ? 0 : a64[i] % b64[j];
#ifdef WRONG_EXPECTATION
            if (a64[i] == INT64_MIN && b64[j] == -1) expected = 1;
#endif
            ube_err_set(73, "seed", "test");
            int64_t result = probe_remainder_i64(a64[i], b64[j]);
            if (result != expected || ube_err_number() != (b64[j] ? 73 : 11)) return 2;
        }
    }
    puts("i32 and i64 boundary combinations passed");
    return 0;
}
