#include <stdint.h>
#include <stdio.h>

int main(void) {
    volatile int16_t small = INT16_MIN, large = INT16_MAX;
    volatile int32_t minimum = INT32_MIN, maximum = INT32_MAX;
    volatile int64_t wide_min = INT64_MIN, wide_max = INT64_MAX;
    volatile int64_t wide_bit = INT64_C(4294967296), wide_zero = 0;
    volatile uint8_t byte_min = 0, byte_max = UINT8_MAX;
    int score = 0;
#ifdef TRUNCATE_WIDE_CONTROL
    wide_bit = (int32_t)wide_bit;
#endif
    score += small < large;
    score += !(large < small);
    score += minimum <= minimum;
    score += !(maximum <= minimum);
    score += maximum > minimum;
    score += !(minimum > maximum);
    score += large >= large;
    score += !(small >= large);
    score += minimum == minimum;
    score += !(minimum == maximum);
    score += minimum != maximum;
    score += !(large != large);
    score += wide_min < wide_max;
    score += !(wide_max < wide_min);
    score += wide_min <= wide_min;
    score += !(wide_max <= wide_min);
    score += wide_bit > wide_zero;
    score += !(wide_min > wide_max);
    score += wide_max >= wide_max;
    score += !(wide_min >= wide_max);
    score += wide_bit == wide_bit;
    score += !(wide_bit == wide_zero);
    score += wide_bit != wide_zero;
    score += !(wide_min != wide_min);
    score += byte_min < byte_max;
    score += !(byte_max < byte_min);
    score += byte_min <= byte_min;
    score += !(byte_max <= byte_min);
    score += byte_max > byte_min;
    score += !(byte_min > byte_max);
    score += byte_max >= byte_max;
    score += !(byte_min >= byte_max);
    score += byte_min == byte_min;
    score += !(byte_min == byte_max);
    score += byte_min != byte_max;
    score += !(byte_max != byte_max);
    printf("%d\n", score);
    return score == 36 ? 0 : 1;
}
