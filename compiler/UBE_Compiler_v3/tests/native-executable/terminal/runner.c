#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>

static int run(const wchar_t *exe, const wchar_t *report, const wchar_t *output, int redirect, int wrong) {
    wchar_t command[4096];
    if (swprintf(command, 4096, L"\"%ls\" \"%ls\"", exe, report) < 0) return 1;
    DeleteFileW(report);
    STARTUPINFOW startup = {0};
    startup.cb = sizeof(startup);
    startup.dwFlags = STARTF_USESHOWWINDOW;
    startup.wShowWindow = SW_HIDE;
    SECURITY_ATTRIBUTES security = {sizeof(security), NULL, TRUE};
    HANDLE file = INVALID_HANDLE_VALUE;
    HANDLE pipe_read = NULL;
    HANDLE pipe_write = NULL;
    if (redirect == 1) {
        file = CreateFileW(output, GENERIC_WRITE, FILE_SHARE_READ, &security, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
        if (file == INVALID_HANDLE_VALUE) return 2;
    } else if (redirect == 2) {
        if (!CreatePipe(&pipe_read, &pipe_write, &security, 0)) return 2;
        file = pipe_write;
    }
    if (redirect) {
        startup.dwFlags |= STARTF_USESTDHANDLES;
        startup.hStdOutput = file;
        startup.hStdError = file;
        startup.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
    }
    PROCESS_INFORMATION process = {0};
    BOOL started = CreateProcessW(exe, command, NULL, NULL, redirect, CREATE_NEW_CONSOLE, NULL, NULL, &startup, &process);
    if (file != INVALID_HANDLE_VALUE) CloseHandle(file);
    if (pipe_read) CloseHandle(pipe_read);
    if (!started) return 3;
    DWORD wait = WaitForSingleObject(process.hProcess, 10000);
    DWORD code = 1;
    if (wait == WAIT_TIMEOUT) { TerminateProcess(process.hProcess, 99); WaitForSingleObject(process.hProcess, 10000); }
    BOOL got = GetExitCodeProcess(process.hProcess, &code);
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    if (wait != WAIT_OBJECT_0 || !got || code != 0) return 4;
    FILE *input = _wfopen(report, L"rb");
    if (!input) return 5;
    char line[64] = {0};
    int ok = fgets(line, sizeof(line), input) != NULL;
    fclose(input);
    if (!ok) return 6;
    const char *expected = redirect ? "console=0 terminal=0\n" : "console=1 terminal=1\n";
    if (wrong) expected = redirect ? "console=1 terminal=1\n" : "console=0 terminal=0\n";
    return strcmp(line, expected) == 0 ? 0 : 7;
}

int wmain(int argc, wchar_t **argv) {
    if (argc != 5 && argc != 6) return 2;
    int wrong = argc == 6 && wcscmp(argv[5], L"wrong") == 0;
    if (argc == 6 && !wrong) return 2;
    int console = run(argv[1], argv[2], argv[4], 0, wrong);
    int file = run(argv[1], argv[3], argv[4], 1, wrong);
    int pipe = run(argv[1], argv[3], argv[4], 2, wrong);
    if (console || file || pipe) { fprintf(stderr, "console=%d file=%d pipe=%d\n", console, file, pipe); return 1; }
    puts("Passed console, redirected-file and redirected-pipe handle checks.");
    return 0;
}
