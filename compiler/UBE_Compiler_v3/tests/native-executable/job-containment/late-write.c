#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>

static int error(const char *what) {
    fprintf(stderr, "%s failed: %lu\n", what, (unsigned long)GetLastError());
    return 1;
}

int wmain(int argc, wchar_t **argv) {
    wchar_t self[32768], line[32768];
    DWORD n = GetModuleFileNameW(NULL, self, 32768);
    if (!n || n >= 32768) return error("GetModuleFileNameW");
    if (argc == 5 && wcscmp(argv[1], L"writer") == 0) {
        HANDLE ready = OpenEventW(EVENT_MODIFY_STATE, FALSE, argv[2]);
        HANDLE release = OpenEventW(SYNCHRONIZE, FALSE, argv[3]);
        if (!ready || !release) return error("open events");
        HANDLE file = CreateFileW(argv[4], FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
        if (file == INVALID_HANDLE_VALUE) return error("open candidate");
        if (!SetEvent(ready) || WaitForSingleObject(release, 5000) != WAIT_OBJECT_0) { CloseHandle(file); return error("writer synchronization"); }
        DWORD written = 0;
        BOOL ok = WriteFile(file, "-late", 5, &written, NULL);
        CloseHandle(file); CloseHandle(release); CloseHandle(ready);
        return ok && written == 5 ? 0 : error("write candidate");
    }
    if (argc == 5 && wcscmp(argv[1], L"child") == 0) {
        if (swprintf(line, 32768, L"\"%ls\" writer %ls %ls \"%ls\"", self, argv[2], argv[3], argv[4]) < 0) return 1;
        STARTUPINFOW si = {0}; PROCESS_INFORMATION pi = {0}; si.cb = sizeof(si);
        if (!CreateProcessW(self, line, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)) return error("start writer");
        CloseHandle(pi.hThread); CloseHandle(pi.hProcess);
        return 0;
    }
    if (argc != 2 && !(argc == 3 && wcscmp(argv[2], L"cancel") == 0)) {
        fprintf(stderr, "usage: late-write <new test candidate> [cancel]\n"); return 1;
    }
    int cancel = argc == 3;
    HANDLE file = CreateFileW(argv[1], GENERIC_WRITE, 0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE) return error("create new test candidate");
    DWORD written = 0;
    BOOL ok = WriteFile(file, "prefix", 6, &written, NULL);
    CloseHandle(file);
    if (!ok || written != 6) { DeleteFileW(argv[1]); return error("write prefix"); }
    wchar_t ready_name[128], release_name[128];
    swprintf(ready_name, 128, L"Local\\UBELateReady-%lu", (unsigned long)GetCurrentProcessId());
    swprintf(release_name, 128, L"Local\\UBELateRelease-%lu", (unsigned long)GetCurrentProcessId());
    HANDLE ready = CreateEventW(NULL, TRUE, FALSE, ready_name);
    HANDLE release = CreateEventW(NULL, TRUE, FALSE, release_name);
    HANDLE job = CreateJobObjectW(NULL, NULL);
    if (!ready || !release || !job) { DeleteFileW(argv[1]); return error("create synchronization"); }
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = {0};
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation, &limits, sizeof(limits))) return error("configure job");
    SECURITY_ATTRIBUTES security = {sizeof(security), NULL, TRUE};
    HANDLE pipe_read = NULL, pipe_write = NULL;
    if (!CreatePipe(&pipe_read, &pipe_write, &security, 0) ||
        !SetHandleInformation(pipe_read, HANDLE_FLAG_INHERIT, 0)) return error("create pipe");
    if (swprintf(line, 32768, L"\"%ls\" child %ls %ls \"%ls\"", self, ready_name, release_name, argv[1]) < 0) return 1;
    STARTUPINFOW si = {0}; PROCESS_INFORMATION pi = {0}; si.cb = sizeof(si);
    if (!CreateProcessW(self, line, NULL, NULL, TRUE, CREATE_SUSPENDED, NULL, NULL, &si, &pi)) return error("start child");
    CloseHandle(pipe_write); pipe_write = NULL;
    int result = 1;
    if (!AssignProcessToJobObject(job, pi.hProcess)) { TerminateProcess(pi.hProcess, 2); WaitForSingleObject(pi.hProcess, 5000); goto cleanup; }
    if (ResumeThread(pi.hThread) == (DWORD)-1) goto cleanup;
    if (WaitForSingleObject(ready, 5000) != WAIT_OBJECT_0 || WaitForSingleObject(pi.hProcess, 5000) != WAIT_OBJECT_0) goto cleanup;
    DWORD exitcode = 1;
    if (!GetExitCodeProcess(pi.hProcess, &exitcode) || exitcode != 0) goto cleanup;
    DWORD available = 0;
    if (!PeekNamedPipe(pipe_read, NULL, 0, NULL, &available, NULL) || available != 0) goto cleanup;
    file = CreateFileW(argv[1], GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE) goto cleanup;
    char bytes[32] = {0}; DWORD read = 0;
    ok = ReadFile(file, bytes, sizeof(bytes), &read, NULL); CloseHandle(file);
    if (!ok || read != 6 || memcmp(bytes, "prefix", 6) != 0) goto cleanup;
    file = CreateFileW(argv[1], GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_DELETE, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (file != INVALID_HANDLE_VALUE) { CloseHandle(file); fprintf(stderr, "inspection guard ignored descendant writer\n"); goto cleanup; }
    if (GetLastError() != ERROR_SHARING_VIOLATION) goto cleanup;
    if (cancel) {
        if (!TerminateJobObject(job, 73)) goto cleanup;
    } else if (!SetEvent(release)) goto cleanup;
    JOBOBJECT_BASIC_ACCOUNTING_INFORMATION stats = {0};
    for (unsigned int i = 0; i < 500; ++i) {
        if (!QueryInformationJobObject(job, JobObjectBasicAccountingInformation, &stats, sizeof(stats), NULL)) goto cleanup;
        if (!stats.ActiveProcesses) break;
        Sleep(10);
    }
    if (stats.ActiveProcesses) goto cleanup;
    int pipe_closed = 0;
    for (unsigned int i = 0; i < 500; ++i) {
        if (!PeekNamedPipe(pipe_read, NULL, 0, NULL, &available, NULL)) {
            if (GetLastError() == ERROR_BROKEN_PIPE) { pipe_closed = 1; break; }
            goto cleanup;
        }
        Sleep(10);
    }
    if (!pipe_closed) goto cleanup;
    file = CreateFileW(argv[1], GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE) goto cleanup;
    memset(bytes, 0, sizeof(bytes)); read = 0;
    ok = ReadFile(file, bytes, sizeof(bytes), &read, NULL); CloseHandle(file);
    const char *expected = cancel ? "prefix" : "prefix-late";
    DWORD expected_size = cancel ? 6 : 11;
    if (!ok || read != expected_size || memcmp(bytes, expected, expected_size) != 0) goto cleanup;
    puts(cancel ? "child exit 0; descendant's write handle blocked inspection; termination preserved candidate" :
                  "child exit 0; descendant's write handle blocked inspection; released writer changed candidate");
    result = 0;
cleanup:
    if (result) { fprintf(stderr, "late-write observation failed\n"); TerminateJobObject(job, 2); }
    CloseHandle(pi.hThread); CloseHandle(pi.hProcess); CloseHandle(job); CloseHandle(pipe_read); CloseHandle(release); CloseHandle(ready);
    if (!DeleteFileW(argv[1])) { error("remove test candidate"); return 1; }
    return result;
}
