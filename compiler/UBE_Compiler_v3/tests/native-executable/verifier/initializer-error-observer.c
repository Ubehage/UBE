#include <stdint.h>
#include <stdio.h>
#include <string.h>
extern void ube_err_clear(void);
extern int32_t ube_err_number(void);
extern void library_init(void);
extern void app_init(void);
extern int32_t app_result(void);
int main(int argc, char **argv) {
    if (argc > 2 || (argc == 2 && strcmp(argv[1], "root-first") != 0)) return 2;
    ube_err_clear();
    if (argc == 2) { app_init(); library_init(); }
    else { library_init(); app_init(); }
    int32_t value = app_result(), err = ube_err_number();
    int32_t expected = argc == 2 ? 1 : 8;
#ifdef WRONG_EXPECTATION
    if (argc == 1) expected = 7;
#endif
    if (value != expected || err != 11) return 1;
    printf("result=%ld err=%ld\n", (long)value, (long)err);
    return 0;
}
