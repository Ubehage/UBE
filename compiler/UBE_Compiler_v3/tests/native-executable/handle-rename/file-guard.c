#include <windows.h>
#include <stdio.h>
#include <wchar.h>

int wmain(int argc, wchar_t **argv) {
    if (argc != 4 && !(argc == 5 && wcscmp(argv[4], L"readonly") == 0)) return 2;
    int readonly = argc == 5;
    HANDLE file = CreateFileW(argv[1], GENERIC_READ | (readonly ? 0 : DELETE),
                              FILE_SHARE_READ | (readonly ? FILE_SHARE_DELETE : 0), NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE) { fprintf(stderr, "guard open failed: %lu\n", (unsigned long)GetLastError()); return 1; }
    HANDLE ready = OpenEventW(EVENT_MODIFY_STATE, FALSE, argv[2]);
    HANDLE release = OpenEventW(SYNCHRONIZE, FALSE, argv[3]);
    if (!ready || !release || !SetEvent(ready) || WaitForSingleObject(release, 10000) != WAIT_OBJECT_0) { CloseHandle(file); return 1; }
    CloseHandle(release); CloseHandle(ready); CloseHandle(file); return 0;
}
