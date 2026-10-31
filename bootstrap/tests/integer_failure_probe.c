#include <stdint.h>
#include <stdio.h>
#include <limits.h>

extern int32_t ube_checked_add_i32(int32_t, int32_t);
extern int32_t ube_checked_sub_i32(int32_t, int32_t);
extern int32_t ube_checked_mul_i32(int32_t, int32_t);
extern int32_t ube_checked_div_i32(int32_t, int32_t);
extern int32_t ube_checked_mod_i32(int32_t, int32_t);
extern int32_t ube_checked_neg_i32(int32_t);
extern int32_t ube_err_number(void);
extern void ube_err_set(int32_t, const char*, const char*);

#define CHECK(test) do { if (!(test)) { fprintf(stderr, "integer check failed at %d\n", __LINE__); return 1; } } while (0)
int main(void) {
    CHECK(ube_checked_div_i32(1, 0) == 0);
    CHECK(ube_err_number() == 11);
    CHECK(ube_checked_mod_i32(1, 0) == 0);
    CHECK(ube_err_number() == 11);
    CHECK(ube_checked_add_i32(INT32_MAX, 1) == 0);
    CHECK(ube_err_number() == 6);
    CHECK(ube_checked_sub_i32(INT32_MIN, 1) == 0);
    CHECK(ube_checked_mul_i32(INT32_MAX, 2) == 0);
    CHECK(ube_checked_div_i32(INT32_MIN, -1) == 0);
    CHECK(ube_checked_neg_i32(INT32_MIN) == 0);
    CHECK(ube_checked_mod_i32(INT32_MIN, -1) == 0);
    ube_err_set(77, "previous", "test");
    CHECK(ube_checked_add_i32(20, 22) == 42);
    CHECK(ube_checked_sub_i32(20, 22) == -2);
    CHECK(ube_checked_mul_i32(-6, 7) == -42);
    CHECK(ube_checked_div_i32(-9, 2) == -4);
    CHECK(ube_checked_mod_i32(-9, 2) == -1);
    CHECK(ube_checked_neg_i32(-3) == 3);
    CHECK(ube_err_number() == 77);
    puts("integer failure probe passed");
    return 0;
}
