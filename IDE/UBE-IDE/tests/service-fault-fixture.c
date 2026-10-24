#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <string.h>

int main(int argc, char **argv) {
    if (argc != 2) return 2;
    if (strcmp(argv[1], "hang") == 0) {
        Sleep(30000);
        return 0;
    }
    if (strcmp(argv[1], "crash") == 0) {
        TerminateProcess(GetCurrentProcess(), 137);
        return 137;
    }
    return strcmp(argv[1], "ok") == 0 ? 0 : 2;
}
