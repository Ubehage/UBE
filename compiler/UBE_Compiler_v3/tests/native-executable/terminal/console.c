#include <windows.h>
#include <io.h>
#include <stdio.h>

int main(int argc, char **argv) {
    if (argc != 2) return 2;
    FILE *report = fopen(argv[1], "wb");
    if (!report) return 3;
    DWORD mode = 0;
    int console = GetConsoleMode(GetStdHandle(STD_OUTPUT_HANDLE), &mode) != 0;
    int terminal = _isatty(_fileno(stdout)) != 0;
    int ok = fprintf(report, "console=%d terminal=%d\n", console, terminal) > 0;
    if (fclose(report) != 0) ok = 0;
    return ok ? 0 : 4;
}
