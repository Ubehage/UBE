#include <windows.h>
#include <stdio.h>
#include <string.h>

int wmain(int argc, wchar_t **argv) {
    if (argc != 4) return 2;
    HANDLE file = CreateFileW(argv[1], GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                              NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE) return 3;
    HANDLE mapping = CreateFileMappingW(file, NULL, PAGE_READWRITE, 0, 0, NULL);
    if (!mapping) { CloseHandle(file); return 4; }
    void *view = MapViewOfFile(mapping, FILE_MAP_WRITE, 0, 0, 9);
    CloseHandle(file);
    if (!view) { CloseHandle(mapping); return 5; }
    HANDLE ready = OpenEventW(EVENT_MODIFY_STATE, FALSE, argv[2]);
    HANDLE release = OpenEventW(SYNCHRONIZE, FALSE, argv[3]);
    if (!ready || !release || !SetEvent(ready) || WaitForSingleObject(release, 10000) != WAIT_OBJECT_0) return 6;
    memcpy(view, "TAMPERED!", 9);
    if (!FlushViewOfFile(view, 9)) return 7;
    UnmapViewOfFile(view); CloseHandle(mapping); CloseHandle(ready); CloseHandle(release);
    return 0;
}
