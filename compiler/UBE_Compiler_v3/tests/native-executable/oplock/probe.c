#include <windows.h>
#include <winioctl.h>
#include <stdio.h>
#include <wchar.h>

int wmain(int argc, wchar_t **argv) {
    if (argc == 4 && wcscmp(argv[1], L"move") == 0)
        return MoveFileW(argv[2], argv[3]) ? 0 : 2;
    if (argc != 2) return 3;
    wchar_t self[32768], target[32768], moved[32768], command[32768];
    DWORD length = GetModuleFileNameW(NULL, self, 32768);
    if (!length || length >= 32768) return 4;
    if (swprintf(target, 32768, L"%ls\\destination.bin", argv[1]) < 0 ||
        swprintf(moved, 32768, L"%ls\\moved.bin", argv[1]) < 0 ||
        swprintf(command, 32768, L"\"%ls\" move \"%ls\" \"%ls\"", self, target, moved) < 0) return 5;
    HANDLE lock = CreateFileW(target, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        NULL, OPEN_EXISTING, FILE_FLAG_OVERLAPPED, NULL);
    if (lock == INVALID_HANDLE_VALUE) return 6;
    OVERLAPPED request = {0};
    request.hEvent = CreateEventW(NULL, TRUE, FALSE, NULL);
    if (!request.hEvent) { CloseHandle(lock); return 7; }
    DWORD bytes = 0;
    BOOL immediate = DeviceIoControl(lock, FSCTL_REQUEST_OPLOCK_LEVEL_1, NULL, 0, NULL, 0, &bytes, &request);
    if (immediate || GetLastError() != ERROR_IO_PENDING || WaitForSingleObject(request.hEvent, 0) != WAIT_TIMEOUT) {
        CloseHandle(lock); CloseHandle(request.hEvent); return 8;
    }
    STARTUPINFOW startup = {0}; PROCESS_INFORMATION child = {0}; startup.cb = sizeof(startup);
    if (!CreateProcessW(self, command, NULL, NULL, FALSE, 0, NULL, NULL, &startup, &child)) {
        CloseHandle(lock); CloseHandle(request.hEvent); return 9;
    }
    DWORD broken = WaitForSingleObject(request.hEvent, 10000);
    DWORD early = WaitForSingleObject(child.hProcess, 0);
    CloseHandle(lock);
    DWORD finished = WaitForSingleObject(child.hProcess, 10000), code = 99;
    if (finished == WAIT_TIMEOUT) { TerminateProcess(child.hProcess, 99); WaitForSingleObject(child.hProcess, 10000); }
    BOOL got = GetExitCodeProcess(child.hProcess, &code);
    CloseHandle(child.hThread); CloseHandle(child.hProcess); CloseHandle(request.hEvent);
    if (broken != WAIT_OBJECT_0 || early != WAIT_TIMEOUT || finished != WAIT_OBJECT_0 || !got || code != 0) {
        fprintf(stderr, "break=%lu early=%lu finish=%lu code=%lu\n", (unsigned long)broken,
            (unsigned long)early, (unsigned long)finished, (unsigned long)code);
        return 1;
    }
    puts("Competing rename waited for oplock release.");
    return 0;
}
