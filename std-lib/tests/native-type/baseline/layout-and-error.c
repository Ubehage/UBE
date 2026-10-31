#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#ifndef EXPECTED_SIZE
#define EXPECTED_SIZE 1
#endif
#ifndef EXPECTED_ALIGNMENT
#define EXPECTED_ALIGNMENT 1
#endif
#ifndef INITIAL_ERR
#define INITIAL_ERR 77
#endif
#ifndef FINAL_ERR
#define FINAL_ERR 77
#endif

extern uint64_t value_record_size(void);
extern uint64_t value_record_alignment(void);
extern void ube_err_set(int32_t, const char*, const char*);
extern int32_t ube_err_number(void);
extern int32_t value_record_entry(int32_t, char**);

/* Test adapter only: delegate to the complete compiler-generated entry wrapper,
   with layout queries and a pre-existing error checked around that call. */
int main(int argc, char** argv) {
    const uint64_t size = value_record_size();
    const uint64_t alignment = value_record_alignment();
    if (size != EXPECTED_SIZE || alignment != EXPECTED_ALIGNMENT) {
        fputs("record layout oracle failed\n", stderr);
        return 2;
    }
    printf("layout:%llu:%llu\n", (unsigned long long)size, (unsigned long long)alignment);
    ube_err_set(INITIAL_ERR, "pre-existing", "value test");
    const int32_t result = value_record_entry(argc, argv);
    if (result != 0) return result;
    if (ube_err_number() != FINAL_ERR) {
        fputs("record operations changed Err\n", stderr);
        return 3;
    }
    printf("err:%d\n", FINAL_ERR);
    return 0;
}
