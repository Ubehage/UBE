#include <stdint.h>

extern void ube_err_set(int32_t, const char *, const char *);
extern int32_t ube_err_number(void);
extern void ube_err_clear(void);
extern int64_t ube_checked_add_i64(int64_t, int64_t);
static int arguments, entries;
static int32_t argument(void) { ++arguments; return 7; }
static int32_t work(int32_t value) { ++entries; return value+1; }
static int32_t checked_call(int32_t value, int refuse) {
    if (!refuse) return work(value);
#ifdef BAD_ERROR_CONTROL
    ube_err_set(11, "test", "test");
#else
    ube_err_set(28, "test", "test");
#endif
#ifdef BAD_ENTRY_CONTROL
    (void)work(value);
#endif
#ifdef BAD_RESULT_CONTROL
    return 1;
#else
    return 0;
#endif
}
static int check_case(int refuse, int seeded) {
    arguments = 0; entries = 0; ube_err_clear();
    if (seeded) ube_err_set(77, "seed", "test");
#ifdef BAD_ARGUMENT_CONTROL
    int32_t value = checked_call(refuse ? 7 : argument(), refuse);
#else
    int32_t value = checked_call(argument(), refuse);
#endif
    int32_t error_after_call = ube_err_number();
    int32_t total = arguments*100 + entries*10 + value;
    if (ube_checked_add_i64(1, 2) != 3) return 0;
    int32_t error_after_success = ube_err_number();
    return total == (refuse ? 100 : 118) &&
           error_after_call == (refuse ? 28 : (seeded ? 77 : 0)) &&
           error_after_success == error_after_call;
}
int main(void) {
    if (!check_case(0, 0) || !check_case(0, 1) ||
        !check_case(1, 0) || !check_case(1, 1)) return 1;
    return 0;
}
