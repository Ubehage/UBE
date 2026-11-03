#include <windows.h>
#include <winioctl.h>
#include <stdio.h>
#include <wchar.h>

int wmain(int argc, wchar_t **argv) {
    if (argc == 3 && wcscmp(argv[1], L"clear") == 0) {
        HANDLE h = CreateFileW(argv[2], GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE,
                               NULL, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS, NULL);
        if (h == INVALID_HANDLE_VALUE) { printf("open failed: %lu\n", (unsigned long)GetLastError()); return 5; }
        struct { DWORD tag; WORD length; WORD reserved; } data = {IO_REPARSE_TAG_MOUNT_POINT, 0, 0};
        DWORD written = 0;
        BOOL ok = DeviceIoControl(h, FSCTL_DELETE_REPARSE_POINT, &data, sizeof(data), NULL, 0, &written, NULL);
        DWORD code = ok ? 0 : GetLastError();
        CloseHandle(h);
        printf("clear result: %lu\n", (unsigned long)code);
        return ok ? 0 : 5;
    }
    if (argc == 4 && wcscmp(argv[1], L"move") == 0) {
        if (MoveFileExW(argv[2], argv[3], 0)) { puts("move succeeded"); return 0; }
        DWORD code = GetLastError();
        printf("move failed: %lu\n", (unsigned long)code);
        return code == ERROR_ACCESS_DENIED || code == ERROR_SHARING_VIOLATION ? 5 : 3;
    }
    int preopen = argc == 5 && (wcscmp(argv[1], L"preopen") == 0 || wcscmp(argv[1], L"prewrite") == 0);
    if (!preopen && argc != 4) return 2;
    const wchar_t *path = argv[preopen ? 2 : 1];
    const wchar_t *ready_name = argv[preopen ? 3 : 2];
    const wchar_t *release_name = argv[preopen ? 4 : 3];
    DWORD access = !preopen ? FILE_LIST_DIRECTORY | FILE_READ_ATTRIBUTES :
                   wcscmp(argv[1], L"prewrite") == 0 ? GENERIC_WRITE | FILE_READ_ATTRIBUTES : DELETE | FILE_READ_ATTRIBUTES;
    DWORD share = preopen ? FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE : FILE_SHARE_READ;
    HANDLE junction = CreateFileW(path, access, share,
                                  NULL, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS, NULL);
    if (junction == INVALID_HANDLE_VALUE) { fprintf(stderr, "open junction failed: %lu\n", (unsigned long)GetLastError()); return 1; }
    FILE_ATTRIBUTE_TAG_INFO tag = {0};
    if (!GetFileInformationByHandleEx(junction, FileAttributeTagInfo, &tag, sizeof(tag)) ||
        !(tag.FileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) || tag.ReparseTag != IO_REPARSE_TAG_MOUNT_POINT) {
        fprintf(stderr, "handle does not identify a junction\n"); CloseHandle(junction); return 1;
    }
    HANDLE ready = OpenEventW(EVENT_MODIFY_STATE, FALSE, ready_name);
    HANDLE release = OpenEventW(SYNCHRONIZE, FALSE, release_name);
    if (!ready || !release || !SetEvent(ready) || WaitForSingleObject(release, 10000) != WAIT_OBJECT_0) {
        fprintf(stderr, "guard synchronization failed\n"); CloseHandle(junction); return 1;
    }
    CloseHandle(release); CloseHandle(ready); CloseHandle(junction);
    return 0;
}
