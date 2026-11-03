#include <fcntl.h>
#include <io.h>
#include <stdio.h>

int main(int argc, char **argv) {
    (void)argv;
    if (argc > 1 && _setmode(_fileno(stdout), _O_BINARY) == -1) return 2;
    if (fputs("A\nB\n", stdout) < 0) return 3;
    return fflush(stdout) == 0 ? 0 : 4;
}
