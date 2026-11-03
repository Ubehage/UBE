#include <windows.h>
#include <stdio.h>
#include <stddef.h>
#include <string.h>
#include <wchar.h>
#include <winternl.h>

int wmain(int argc, wchar_t **argv) {
    if ((argc != 3 && argc != 5) || (wcscmp(argv[2], L"relative") && wcscmp(argv[2], L"absolute") && wcscmp(argv[2], L"native-relative") && wcscmp(argv[2], L"native-posix") && wcscmp(argv[2], L"native-create") && wcscmp(argv[2], L"native-parentguard") && wcscmp(argv[2], L"native-parent-nodel") && wcscmp(argv[2], L"native-parent-nowrite") && wcscmp(argv[2], L"native-parent-posix") && wcscmp(argv[2], L"native-sourceguard") && wcscmp(argv[2], L"native-reopen") && wcscmp(argv[2], L"native-reopen-posix") && wcscmp(argv[2], L"native-link"))) return 2;
    int reopen_mode = wcscmp(argv[2], L"native-reopen") == 0 || wcscmp(argv[2], L"native-reopen-posix") == 0;
    int posix_reopen = wcscmp(argv[2], L"native-reopen-posix") == 0;
    wchar_t candidate[32768], destination[32768];
    if (swprintf(candidate, 32768, L"%ls\\candidate.bin", argv[1]) < 0 ||
        swprintf(destination, 32768, L"%ls\\destination.bin", argv[1]) < 0) return 3;
    DWORD share = (wcscmp(argv[2], L"native-parentguard") == 0 || wcscmp(argv[2], L"native-parent-posix") == 0) ? FILE_SHARE_READ : FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE;
    if (wcscmp(argv[2], L"native-parent-nodel") == 0) share = FILE_SHARE_READ | FILE_SHARE_WRITE;
    if (wcscmp(argv[2], L"native-parent-nowrite") == 0) share = FILE_SHARE_READ | FILE_SHARE_DELETE;
    HANDLE directory = CreateFileW(argv[1], FILE_LIST_DIRECTORY | FILE_ADD_FILE | FILE_READ_ATTRIBUTES,
        share, NULL, OPEN_EXISTING,
        FILE_FLAG_BACKUP_SEMANTICS, NULL);
    if (directory == INVALID_HANDLE_VALUE) return 4;
    DWORD source_share = wcscmp(argv[2], L"native-sourceguard") == 0 ? FILE_SHARE_READ : FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE;
    DWORD source_access = DELETE | FILE_READ_ATTRIBUTES | (wcscmp(argv[2], L"native-sourceguard") == 0 ? GENERIC_READ : 0);
    if (reopen_mode) { source_share = FILE_SHARE_READ | FILE_SHARE_DELETE; source_access = GENERIC_READ; }
    HANDLE source = CreateFileW(candidate, source_access,
        source_share, NULL, OPEN_EXISTING, 0, NULL);
    if (source == INVALID_HANDLE_VALUE) { fprintf(stderr, "candidate open failed: %lu\n", (unsigned long)GetLastError()); CloseHandle(directory); return 5; }
    if (wcscmp(argv[2], L"native-sourceguard") == 0 || reopen_mode) {
        char content[9]; DWORD read = 0;
        if (!ReadFile(source, content, sizeof(content), &read, NULL) || read != sizeof(content) || memcmp(content, "candidate", sizeof(content)) != 0) {
            CloseHandle(source); CloseHandle(directory); return 8;
        }
    }
    if (argc == 5) {
        HANDLE ready = OpenEventW(EVENT_MODIFY_STATE, FALSE, argv[3]);
        HANDLE release = OpenEventW(SYNCHRONIZE, FALSE, argv[4]);
        if (!ready || !release || !SetEvent(ready) || WaitForSingleObject(release, 10000) != WAIT_OBJECT_0) {
            if (ready) CloseHandle(ready);
            if (release) CloseHandle(release);
            CloseHandle(source); CloseHandle(directory); return 7;
        }
        CloseHandle(ready); CloseHandle(release);
    }
    if (reopen_mode) {
        HANDLE reopened = ReOpenFile(source, GENERIC_READ | DELETE, FILE_SHARE_READ | FILE_SHARE_DELETE, 0);
        if (reopened == INVALID_HANDLE_VALUE) { fprintf(stderr, "reopen failed: %lu\n", (unsigned long)GetLastError()); CloseHandle(source); CloseHandle(directory); return 9; }
        CloseHandle(source); source = reopened;
    }
    int relative = wcscmp(argv[2], L"absolute") != 0;
    const wchar_t *name = relative ? L"destination.bin" : destination;
    _Alignas(FILE_RENAME_INFO) unsigned char storage[offsetof(FILE_RENAME_INFO, FileName) + 65536] = {0};
    FILE_RENAME_INFO *info = (FILE_RENAME_INFO *)storage;
    info->ReplaceIfExists = wcscmp(argv[2], L"native-create") != 0;
    if (wcscmp(argv[2], L"native-posix") == 0 || wcscmp(argv[2], L"native-parent-posix") == 0 || wcscmp(argv[2], L"native-link") == 0 || posix_reopen) {
        ULONG flags = 3; /* replace and POSIX semantics */
        memcpy(info, &flags, sizeof(flags));
    }
    info->RootDirectory = relative ? directory : NULL;
    info->FileNameLength = (DWORD)((wcslen(name)) * sizeof(wchar_t));
    memcpy(info->FileName, name, info->FileNameLength);
    BOOL ok;
    DWORD error;
    if (wcscmp(argv[2], L"native-relative") == 0 || wcscmp(argv[2], L"native-posix") == 0 || wcscmp(argv[2], L"native-create") == 0 || wcscmp(argv[2], L"native-parentguard") == 0 || wcscmp(argv[2], L"native-parent-nodel") == 0 || wcscmp(argv[2], L"native-parent-nowrite") == 0 || wcscmp(argv[2], L"native-parent-posix") == 0 || wcscmp(argv[2], L"native-sourceguard") == 0 || reopen_mode || wcscmp(argv[2], L"native-link") == 0) {
        HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
        typedef NTSTATUS (NTAPI *SetInfo)(HANDLE, PIO_STATUS_BLOCK, PVOID, ULONG, FILE_INFORMATION_CLASS);
        typedef ULONG (WINAPI *ConvertStatus)(NTSTATUS);
        SetInfo set_info = (SetInfo)GetProcAddress(ntdll, "NtSetInformationFile");
        ConvertStatus convert = (ConvertStatus)GetProcAddress(ntdll, "RtlNtStatusToDosError");
        if (!set_info || !convert) { CloseHandle(source); CloseHandle(directory); return 6; }
        IO_STATUS_BLOCK status_block = {0};
        NTSTATUS status = set_info(source, &status_block, info,
            (ULONG)(offsetof(FILE_RENAME_INFO, FileName) + info->FileNameLength),
            (FILE_INFORMATION_CLASS)(wcscmp(argv[2], L"native-link") == 0 ? 72 : (wcscmp(argv[2], L"native-posix") == 0 || wcscmp(argv[2], L"native-parent-posix") == 0 || posix_reopen) ? 65 : 10));
        ok = status == 0;
        error = ok ? 0 : convert(status);
    } else {
        ok = SetFileInformationByHandle(source, FileRenameInfo, info,
            (DWORD)(offsetof(FILE_RENAME_INFO, FileName) + info->FileNameLength));
        error = ok ? 0 : GetLastError();
    }
    CloseHandle(source);
    CloseHandle(directory);
    if (!ok) { fprintf(stderr, "rename failed: %lu\n", (unsigned long)error); return 1; }
    puts("rename reported success");
    return 0;
}
