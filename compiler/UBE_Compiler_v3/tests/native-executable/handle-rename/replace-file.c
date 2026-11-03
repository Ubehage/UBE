#include <windows.h>
#include <stdio.h>
#include <string.h>

int wmain(int argc, wchar_t **argv) {
    if (argc != 3) return 2;
    HANDLE old = CreateFileW(argv[1], GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE,
                             NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (old == INVALID_HANDLE_VALUE) { fprintf(stderr, "open failed: %lu\n", (unsigned long)GetLastError()); return 1; }
    BOOL locked = ReplaceFileW(argv[1], argv[2], NULL, 0, NULL, NULL);
    DWORD locked_error = locked ? 0 : GetLastError();
    char bytes[3]; DWORD read = 0;
    BOOL old_unchanged = ReadFile(old, bytes, sizeof(bytes), &read, NULL) && read == 3 && memcmp(bytes, "old", 3) == 0;
    CloseHandle(old);
    if (locked) { fprintf(stderr, "replacement succeeded while locked\n"); return 1; }
    if (!old_unchanged) { fprintf(stderr, "old handle contents changed\n"); return 1; }
    printf("locked replacement failed: %lu\n", (unsigned long)locked_error);
    if (!ReplaceFileW(argv[1], argv[2], NULL, 0, NULL, NULL)) {
        fprintf(stderr, "replacement after unlock failed: %lu\n", (unsigned long)GetLastError()); return 1;
    }
    puts("replacement after unlock succeeded");
    return 0;
}
