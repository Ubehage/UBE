#include <windows.h>
#include <stdio.h>
#include <string.h>

static int mark(const char *event) { return puts(event) >= 0 && fflush(stdout) == 0; }
static int wait_forever(void) {
    HANDLE event = CreateEventW(NULL, TRUE, FALSE, NULL);
    if (!event) return 3;
    DWORD result = WaitForSingleObject(event, INFINITE);
    CloseHandle(event);
    return result == WAIT_OBJECT_0 ? 4 : 3;
}
int main(int argc, char **argv) {
    if (argc != 2 || !mark("A-enter") || !mark("B-enter")) return 2;
    if (strcmp(argv[1], "early") == 0) {
        int y = 7, count = 1, x = y + 1;
        if (!mark("B-complete") || !mark("A-complete")) return 2;
        printf("main=%d\n", x * 10 + count);
        return fflush(stdout) == 0 ? 0 : 2;
    }
    if (strcmp(argv[1], "wait") == 0) { if (!mark("wait:A")) return 2; }
    else if (strcmp(argv[1], "recursive-control") == 0) { if (!mark("A-enter")) return 2; }
    else if (strcmp(argv[1], "stall-control") == 0) { if (!mark("before-wait")) return 2; }
    else return 2;
    return wait_forever();
}
