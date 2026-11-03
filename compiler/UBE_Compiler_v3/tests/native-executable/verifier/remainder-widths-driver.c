#include <stdint.h>

extern int16_t remainder16(int16_t, int16_t, int32_t *);
extern int64_t remainder64(int64_t, int64_t, int32_t *);

static volatile int16_t minimum16 = INT16_MIN;
static volatile int64_t minimum64 = INT64_MIN;
static volatile int16_t minus16 = -1, zero16 = 0, five16 = 5, normal16 = -17;
static volatile int64_t minus64 = -1, zero64 = 0, five64 = 5, normal64 = -17;

int main(void) {
    int32_t err = 73;
    if (remainder16(minimum16, minus16, &err) != 0 || err != 73) return 1;
    if (remainder64(minimum64, minus64, &err) != 0 || err != 73) return 2;
    if (remainder16(normal16, five16, &err) != -2 || err != 73) return 3;
    if (remainder64(normal64, five64, &err) != -2 || err != 73) return 4;
    if (remainder16(normal16, zero16, &err) != 0 || err != 11) return 5;
    err = 73;
    if (remainder64(normal64, zero64, &err) != 0 || err != 11) return 6;
#ifdef WRONG_EXPECTATION
    if (err != 73) return 7;
#endif
    return 0;
}
