#include <windows.h>
#include <stdio.h>
#include <wchar.h>

int wmain(int argc, wchar_t **argv) {
    if (argc == 2 && wcscmp(argv[1], L"holder") == 0) {
        Sleep(30000);
        return 0;
    }
    wchar_t executable[32768], command[32768];
    if (!GetModuleFileNameW(NULL, executable, 32768) ||
        swprintf(command, 32768, L"\"%ls\" holder", executable) < 0) return 1;
    STARTUPINFOW startup = {0}; startup.cb = sizeof(startup);
    startup.dwFlags = STARTF_USESTDHANDLES;
    startup.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
    startup.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
    startup.hStdError = GetStdHandle(STD_ERROR_HANDLE);
    PROCESS_INFORMATION child = {0};
    if (!CreateProcessW(executable, command, NULL, NULL, TRUE, 0, NULL, NULL, &startup, &child)) return 1;
    CloseHandle(child.hThread); CloseHandle(child.hProcess);
    puts("Machine: IMAGE_FILE_MACHINE_AMD64\nIMAGE_FILE_EXECUTABLE_IMAGE\nImageOptionalHeader {\nMagic: 0x20B");
    return 0;
}
