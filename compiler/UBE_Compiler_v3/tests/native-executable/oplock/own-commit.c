#include <windows.h>
#include <winioctl.h>
#include <stdio.h>
#include <wchar.h>
#include <winternl.h>
#include <stddef.h>
#include <string.h>

typedef struct { const wchar_t *candidate; const wchar_t *destination; HANDLE directory; int native; } Paths;
static DWORD WINAPI replace(void *raw) {
    Paths *paths = (Paths *)raw;
    if (paths->native) {
        HANDLE file = CreateFileW(paths->candidate, DELETE, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, OPEN_EXISTING, 0, NULL);
        if (file == INVALID_HANDLE_VALUE) return GetLastError();
        HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
        typedef NTSTATUS (NTAPI *SetInfo)(HANDLE, PIO_STATUS_BLOCK, PVOID, ULONG, FILE_INFORMATION_CLASS);
        typedef ULONG (WINAPI *ConvertStatus)(NTSTATUS);
        SetInfo set_info = (SetInfo)GetProcAddress(ntdll, "NtSetInformationFile");
        ConvertStatus convert = (ConvertStatus)GetProcAddress(ntdll, "RtlNtStatusToDosError");
        if (!set_info || !convert) { CloseHandle(file); return 87; }
        _Alignas(FILE_RENAME_INFO) unsigned char storage[offsetof(FILE_RENAME_INFO, FileName) + 65536] = {0};
        FILE_RENAME_INFO *info = (FILE_RENAME_INFO *)storage;
        info->ReplaceIfExists = TRUE;
        info->RootDirectory = paths->directory;
        const wchar_t *name = L"destination.bin";
        info->FileNameLength = (DWORD)(wcslen(name) * sizeof(wchar_t));
        if (info->FileNameLength > 65536) { CloseHandle(file); return 87; }
        memcpy(info->FileName, name, info->FileNameLength);
        IO_STATUS_BLOCK status_block = {0};
        NTSTATUS status = set_info(file, &status_block, info, (ULONG)(offsetof(FILE_RENAME_INFO, FileName) + info->FileNameLength), (FILE_INFORMATION_CLASS)10);
        CloseHandle(file);
        return status == 0 ? 0 : convert(status);
    }
    return MoveFileExW(paths->candidate, paths->destination, MOVEFILE_REPLACE_EXISTING) ? 0 : GetLastError();
}
int wmain(int argc, wchar_t **argv) {
    if (argc != 2 && argc != 3) return 2;
    wchar_t destination[32768], candidate[32768];
    if (swprintf(destination, 32768, L"%ls\\destination.bin", argv[1]) < 0 ||
        swprintf(candidate, 32768, L"%ls\\candidate.bin", argv[1]) < 0) return 3;
    if (argc == 3 && wcscmp(argv[2], L"unlocked") == 0) {
        return MoveFileExW(candidate, destination, MOVEFILE_REPLACE_EXISTING) ? 0 : 9;
    }
    if (argc == 3 && wcscmp(argv[2], L"native-unlocked") == 0) {
        HANDLE directory = CreateFileW(argv[1], FILE_LIST_DIRECTORY | FILE_ADD_FILE,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, NULL);
        if (directory == INVALID_HANDLE_VALUE) return 10;
        Paths paths = {candidate, destination, directory, 1};
        DWORD result = replace(&paths);
        CloseHandle(directory);
        return result == 0 ? 0 : 9;
    }
    if (argc == 3 && wcscmp(argv[2], L"native") != 0) return 2;
    HANDLE lock = CreateFileW(destination, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        NULL, OPEN_EXISTING, FILE_FLAG_OVERLAPPED, NULL);
    if (lock == INVALID_HANDLE_VALUE) return 4;
    OVERLAPPED request = {0}; request.hEvent = CreateEventW(NULL, TRUE, FALSE, NULL);
    if (!request.hEvent) { CloseHandle(lock); return 5; }
    DWORD bytes = 0;
    BOOL immediate = DeviceIoControl(lock, FSCTL_REQUEST_OPLOCK_LEVEL_1, NULL, 0, NULL, 0, &bytes, &request);
    if (immediate || GetLastError() != ERROR_IO_PENDING || WaitForSingleObject(request.hEvent, 0) != WAIT_TIMEOUT) {
        CloseHandle(lock); CloseHandle(request.hEvent); return 6;
    }
    HANDLE directory = CreateFileW(argv[1], FILE_LIST_DIRECTORY | FILE_ADD_FILE,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, NULL);
    if (directory == INVALID_HANDLE_VALUE) { CloseHandle(lock); CloseHandle(request.hEvent); return 10; }
    Paths paths = {candidate, destination, directory, argc == 3};
    HANDLE thread = CreateThread(NULL, 0, replace, &paths, 0, NULL);
    if (!thread) { CloseHandle(directory); CloseHandle(lock); CloseHandle(request.hEvent); return 7; }
    DWORD broken = WaitForSingleObject(request.hEvent, 10000);
    DWORD early = WaitForSingleObject(thread, 0);
    CloseHandle(lock);
    DWORD finished = WaitForSingleObject(thread, 10000), result = 99;
    if (finished != WAIT_OBJECT_0) ExitProcess(8);
    BOOL got = GetExitCodeThread(thread, &result);
    CloseHandle(thread); CloseHandle(request.hEvent); CloseHandle(directory);
    if (broken != WAIT_OBJECT_0 || early != WAIT_TIMEOUT || finished != WAIT_OBJECT_0 || !got || result != 0) {
        fprintf(stderr, "break=%lu early=%lu finish=%lu result=%lu\n", (unsigned long)broken,
            (unsigned long)early, (unsigned long)finished, (unsigned long)result);
        return 1;
    }
    puts("Same-process replacement waited for its own oplock release.");
    return 0;
}
