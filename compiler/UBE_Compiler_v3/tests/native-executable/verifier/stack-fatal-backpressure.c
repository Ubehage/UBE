#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <wchar.h>

int wmain(int argc, wchar_t **argv) {
    if (argc != 2 && argc != 3) return 2;
    int empty = argc == 3 && wcscmp(argv[2], L"nowait-empty") == 0;
    int nowait = argc == 3 && (wcscmp(argv[2], L"nowait") == 0 || empty);
    int threaded = argc == 3 && wcscmp(argv[2], L"threaded") == 0;
    int prestarted = argc == 3 && wcscmp(argv[2], L"prestarted") == 0;
    int cancel = argc == 3 && wcscmp(argv[2], L"cancel") == 0;
    if (argc == 3 && !nowait && !threaded && !prestarted && !cancel) return 2;
    SECURITY_ATTRIBUTES security = { sizeof(security), NULL, TRUE };
    HANDLE read_pipe = NULL, write_pipe = NULL;
    if (!CreatePipe(&read_pipe, &write_pipe, &security, 4096)) return 3;
    if (!SetHandleInformation(read_pipe, HANDLE_FLAG_INHERIT, 0)) return 4;
    DWORD capacity = 0;
    if (!GetNamedPipeInfo(write_pipe, NULL, &capacity, NULL, NULL) || capacity == 0 || capacity > 1048576) return 5;
    unsigned char *buffer = (unsigned char *)calloc(capacity, 1);
    if (!buffer) return 6;
    DWORD count = 0;
    if (!empty && (!WriteFile(write_pipe, buffer, capacity, &count, NULL) || count != capacity)) return 7;
    wchar_t command[32768];
    DWORD initial_state = 0;
    if (!GetNamedPipeHandleStateW(write_pipe, &initial_state, NULL, NULL, NULL, NULL, 0)) return 13;
    if (swprintf(command, 32768, L"\"%ls\" %ls", argv[1], nowait ? L"nowait" : threaded ? L"threaded" : prestarted ? L"prestarted" : cancel ? L"cancel" : L"fatal") < 0) return 8;
    STARTUPINFOW startup = {0}; startup.cb = sizeof(startup); startup.dwFlags = STARTF_USESTDHANDLES;
    startup.hStdInput = GetStdHandle(STD_INPUT_HANDLE); startup.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE); startup.hStdError = write_pipe;
    PROCESS_INFORMATION child = {0};
    if (!CreateProcessW(argv[1], command, NULL, NULL, TRUE, CREATE_NO_WINDOW, NULL, NULL, &startup, &child)) return 9;
    CloseHandle(child.hThread);
    DWORD first = WaitForSingleObject(child.hProcess, 500);
    if (threaded || prestarted || cancel) {
        DWORD status = 0, final_state = 0, available = 0;
        BOOL observed = GetExitCodeProcess(child.hProcess, &status);
        BOOL state_ok = GetNamedPipeHandleStateW(write_pipe, &final_state, NULL, NULL, NULL, NULL, 0);
        BOOL pipe_ok = PeekNamedPipe(read_pipe, NULL, 0, NULL, &available, NULL);
        if (first != WAIT_OBJECT_0) { TerminateProcess(child.hProcess, 99); WaitForSingleObject(child.hProcess, 5000); }
        CloseHandle(child.hProcess); CloseHandle(write_pipe); CloseHandle(read_pipe); free(buffer);
        if (first != WAIT_OBJECT_0 || !observed || status != 1 || !state_ok || initial_state != final_state || !pipe_ok || available != capacity) return 15;
        puts(cancel ? "cancelled write and exited while pipe remained full; parent mode unchanged" : prestarted ? "prestarted writer exited while pipe remained full; parent mode unchanged" :
                      "threaded fatal exited while pipe remained full; parent mode unchanged");
        return 0;
    }
    if (nowait) {
        DWORD status = 0, final_state = 0;
        BOOL observed = GetExitCodeProcess(child.hProcess, &status);
        BOOL state_ok = GetNamedPipeHandleStateW(write_pipe, &final_state, NULL, NULL, NULL, NULL, 0);
        if (first != WAIT_OBJECT_0) { TerminateProcess(child.hProcess, 99); WaitForSingleObject(child.hProcess, 5000); }
        CloseHandle(child.hProcess); CloseHandle(write_pipe); CloseHandle(read_pipe); free(buffer);
        if (first != WAIT_OBJECT_0 || !observed || !state_ok || (status != 1 && status < 100)) {
            fprintf(stderr, "nowait observation: wait=%lu observed=%d status=%lu state=%d\n",
                    (unsigned long)first, (int)observed, (unsigned long)status, (int)state_ok);
            return 14;
        }
        if (status >= 100) { printf("nowait setup failed with error %lu\n", (unsigned long)(status-100)); return 0; }
        puts((initial_state & PIPE_NOWAIT) == (final_state & PIPE_NOWAIT) ?
             "nowait exited; parent pipe mode unchanged" : "nowait exited; parent pipe mode changed");
        return 0;
    }
    if (first != WAIT_TIMEOUT) { CloseHandle(child.hProcess); return 10; }
    DWORD read = 0;
    if (!ReadFile(read_pipe, buffer, capacity, &read, NULL) || read != capacity) return 11;
    DWORD last = WaitForSingleObject(child.hProcess, 5000), status = 0;
    BOOL observed = GetExitCodeProcess(child.hProcess, &status);
    if (last != WAIT_OBJECT_0) { TerminateProcess(child.hProcess, 99); WaitForSingleObject(child.hProcess, 5000); }
    CloseHandle(child.hProcess); CloseHandle(write_pipe); CloseHandle(read_pipe); free(buffer);
    if (last != WAIT_OBJECT_0 || !observed || status != 1) return 12;
    puts("full stderr blocked fatal write until pipe was drained");
    return 0;
}
