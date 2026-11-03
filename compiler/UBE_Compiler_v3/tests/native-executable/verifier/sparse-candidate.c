#include <windows.h>
#include <winioctl.h>
#include <stdint.h>
#include <stdio.h>
#include <wchar.h>

int wmain(int argc, wchar_t **argv) {
    if (argc != 2) return 2;
    HANDLE file = CreateFileW(argv[1], GENERIC_READ | GENERIC_WRITE, 0, NULL,
                              CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE) return 3;
    int result = 1;
    DWORD ignored = 0, written = 0;
    if (!DeviceIoControl(file, FSCTL_SET_SPARSE, NULL, 0, NULL, 0, &ignored, NULL)) goto done;
    LARGE_INTEGER position; position.QuadPart = 32LL * 1024 * 1024 - 1;
    if (!SetFilePointerEx(file, position, NULL, FILE_BEGIN)) goto done;
    const unsigned char marker = 42;
    if (!WriteFile(file, &marker, 1, &written, NULL) || written != 1 || !FlushFileBuffers(file)) goto done;
    FILE_STANDARD_INFO information;
    if (!GetFileInformationByHandleEx(file, FileStandardInfo, &information, sizeof(information))) goto done;
    if (information.EndOfFile.QuadPart != 32LL * 1024 * 1024 || information.AllocationSize.QuadPart < 0 ||
        information.AllocationSize.QuadPart >= information.EndOfFile.QuadPart) goto done;
    printf("logical=%llu allocated=%llu\n", (unsigned long long)information.EndOfFile.QuadPart,
           (unsigned long long)information.AllocationSize.QuadPart);
    result = 0;
done:
    CloseHandle(file);
    if (!DeleteFileW(argv[1])) return 4;
    return result;
}
