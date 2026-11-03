#include <io.h>
#include <stdio.h>

int main(void) {
    printf("stdout_terminal=%d\n", _isatty(_fileno(stdout)) != 0);
    return 0;
}
