#include <stdio.h>

int main(void) {
#ifdef ALTERNATE_LINKER
    fputs("independent-linker-two\n", stderr);
#else
    fputs("independent-linker-one\n", stderr);
#endif
    return 41;
}
