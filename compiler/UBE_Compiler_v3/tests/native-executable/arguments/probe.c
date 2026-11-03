#include <windows.h>
#include <stdio.h>
#include <wchar.h>

int wmain(int argc, wchar_t **argv) {
    if (argc > 1 && wcscmp(argv[1], L"child") == 0) {
        if (argc != 10) return 10;
        const wchar_t slash_quote[] = {L'\\', L'\\', L'"', L'e', L'n', L'd', 0};
        if (wcscmp(argv[2], L"") || wcscmp(argv[3], L"two words") ||
            wcscmp(argv[4], L"a&b") || wcscmp(argv[5], L"trailing\\") ||
            wcscmp(argv[6], L"one\"quote") || wcscmp(argv[7], L"æøå") ||
            wcscmp(argv[8], L"\xD801\xDC00") || wcscmp(argv[9], slash_quote)) return 11;
        return 0;
    }
    if (argc > 2 || (argc == 2 && wcscmp(argv[1], L"wrong") != 0)) return 2;
    wchar_t self[32768], command[32768];
    DWORD length = GetModuleFileNameW(NULL, self, 32768);
    if (!length || length >= 32768) return 3;
    const wchar_t *tail = argc == 2
        ? L"child \"\" \"two words\" \"a&b\" \"trailing\\\\\" \"one\\\"quote\" \"wrong\" \"\xD801\xDC00\""
        : L"child \"\" \"two words\" \"a&b\" \"trailing\\\\\" \"one\\\"quote\" \"æøå\" \"\xD801\xDC00\"";
    if (swprintf(command, 32768, L"\"%ls\" %ls", self, tail) < 0) return 4;
    size_t used = wcslen(command);
    if (used + 12 >= 32768) return 4;
    command[used++] = L' '; command[used++] = L'"';
    for (int i = 0; i < 5; ++i) command[used++] = L'\\';
    command[used++] = L'"'; command[used++] = L'e'; command[used++] = L'n';
    command[used++] = L'd'; command[used++] = L'"'; command[used] = 0;
    STARTUPINFOW startup = {0}; PROCESS_INFORMATION process = {0};
    startup.cb = sizeof(startup);
    if (!CreateProcessW(self, command, NULL, NULL, FALSE, 0, NULL, NULL, &startup, &process)) return 5;
    DWORD wait = WaitForSingleObject(process.hProcess, 10000), code = 99;
    if (wait == WAIT_TIMEOUT) { TerminateProcess(process.hProcess, 99); WaitForSingleObject(process.hProcess, 10000); }
    BOOL got = GetExitCodeProcess(process.hProcess, &code);
    CloseHandle(process.hThread); CloseHandle(process.hProcess);
    if (wait != WAIT_OBJECT_0 || !got) return 6;
    if (argc == 2) return code == 11 ? 0 : 7;
    return code == 0 ? 0 : 8;
}
