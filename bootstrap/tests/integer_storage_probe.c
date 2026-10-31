#include <stdint.h>
#include <stdio.h>
#include <limits.h>
#include <stddef.h>

extern int64_t ube_checked_narrow_i64(int64_t, int32_t, int32_t);
extern int32_t ube_err_number(void);
extern void ube_err_set(int32_t, const char*, const char*);
extern void* ube_array_redim(void*, int32_t, int32_t, size_t, _Bool);
extern void* ube_array_element(void*, int32_t);
extern void ube_array_release(void*);

#define CHECK(test) do { if (!(test)) { fprintf(stderr, "storage check failed at %d\n", __LINE__); return 1; } } while (0)
int main(void) {
    ube_err_set(77, "previous", "test");
    CHECK(ube_checked_narrow_i64(0, 8, 1) == 0);
    CHECK(ube_checked_narrow_i64(255, 8, 1) == 255);
    CHECK(ube_checked_narrow_i64(INT16_MIN, 16, 0) == INT16_MIN);
    CHECK(ube_checked_narrow_i64(INT16_MAX, 16, 0) == INT16_MAX);
    CHECK(ube_checked_narrow_i64(INT32_MIN, 32, 0) == INT32_MIN);
    CHECK(ube_checked_narrow_i64(INT32_MAX, 32, 0) == INT32_MAX);
    CHECK(ube_err_number() == 77);
    CHECK(ube_checked_narrow_i64(256, 8, 1) == 0 && ube_err_number() == 6);
    CHECK(ube_checked_narrow_i64(-1, 8, 1) == 0 && ube_err_number() == 6);
    CHECK(ube_checked_narrow_i64(32768, 16, 0) == 0 && ube_err_number() == 6);
    CHECK(ube_checked_narrow_i64(-32769, 16, 0) == 0 && ube_err_number() == 6);
    CHECK(ube_checked_narrow_i64(INT64_MAX, 32, 0) == 0 && ube_err_number() == 6);
    CHECK(ube_checked_narrow_i64(1, 7, 0) == 0 && ube_err_number() == 5);
    void* bytes = ube_array_redim(NULL, 0, 2, 1, 0);
    CHECK(bytes != NULL);
    CHECK((uintptr_t)ube_array_element(bytes, 1) - (uintptr_t)ube_array_element(bytes, 0) == 1);
    *(uint8_t*)ube_array_element(bytes, 0) = 65;
    *(uint8_t*)ube_array_element(bytes, 1) = 0;
    *(uint8_t*)ube_array_element(bytes, 2) = 255;
    bytes = ube_array_redim(bytes, 0, 4, 1, 1);
    CHECK(*(uint8_t*)ube_array_element(bytes, 0) == 65);
    CHECK(*(uint8_t*)ube_array_element(bytes, 1) == 0);
    CHECK(*(uint8_t*)ube_array_element(bytes, 2) == 255);
    CHECK(*(uint8_t*)ube_array_element(bytes, 4) == 0);
    ube_array_release(bytes);
    puts("integer storage probe passed");
    return 0;
}
