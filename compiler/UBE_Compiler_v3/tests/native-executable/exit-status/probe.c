#include <windows.h>
#include <string.h>

int main(int argc, char **argv) {
    if (argc != 2) return 2;
    if (strcmp(argv[1], "min") == 0) ExitProcess(0x80000000UL);
    if (strcmp(argv[1], "max") == 0) ExitProcess(0x7FFFFFFFUL);
    return 3;
}
