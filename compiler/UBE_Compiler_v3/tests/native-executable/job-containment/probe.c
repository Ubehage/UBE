#include <windows.h>
#include <stdio.h>
#include <wchar.h>

static int fail(const char *stage) {
    fprintf(stderr, "%s failed (%lu)\n", stage, (unsigned long)GetLastError());
    return 1;
}

int wmain(int argc, wchar_t **argv) {
    wchar_t self[32768];
    DWORD len = GetModuleFileNameW(NULL, self, 32768);
    if (!len || len >= 32768) return fail("GetModuleFileNameW");
    if (argc == 3 && wcscmp(argv[1], L"marker-child") == 0) {
        HANDLE event = OpenEventW(EVENT_MODIFY_STATE, FALSE, argv[2]);
        if (!event) return fail("marker OpenEventW");
        if (!SetEvent(event)) { CloseHandle(event); return fail("marker SetEvent"); }
        CloseHandle(event);
        return 0;
    }
    if (argc == 3 && wcscmp(argv[1], L"grandchild") == 0) {
        HANDLE event = OpenEventW(EVENT_MODIFY_STATE, FALSE, argv[2]);
        if (!event) return fail("OpenEventW");
        if (!SetEvent(event)) { CloseHandle(event); return fail("SetEvent"); }
        CloseHandle(event);
        Sleep(INFINITE);
        return 0;
    }
    if (argc == 3 && (wcscmp(argv[1], L"child") == 0 || wcscmp(argv[1], L"child-exits") == 0)) {
        wchar_t line[32768];
        if (swprintf(line, 32768, L"\"%ls\" grandchild %ls", self, argv[2]) < 0) return 1;
        STARTUPINFOW si = {0}; PROCESS_INFORMATION pi = {0}; si.cb = sizeof(si);
        if (!CreateProcessW(self, line, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi)) return fail("grandchild CreateProcessW");
        CloseHandle(pi.hThread); CloseHandle(pi.hProcess);
        if (wcscmp(argv[1], L"child-exits") == 0) return 0;
        Sleep(INFINITE);
        return 0;
    }
    wchar_t name[128], line[32768];
    if (swprintf(name, 128, L"Local\\UBEJobProbe-%lu", (unsigned long)GetCurrentProcessId()) < 0) return 1;
    int child_exits = argc == 2 && wcscmp(argv[1], L"child-exits") == 0;
    int assignment_failure = argc == 2 && wcscmp(argv[1], L"assignment-failure") == 0;
    int marker_control = argc == 2 && wcscmp(argv[1], L"assignment-control") == 0;
    const wchar_t *child_mode = (assignment_failure || marker_control) ? L"marker-child" : (child_exits ? L"child-exits" : L"child");
    if (swprintf(line, 32768, L"\"%ls\" %ls %ls", self, child_mode, name) < 0) return 1;
    HANDLE event = CreateEventW(NULL, TRUE, FALSE, name);
    if (!event) return fail("CreateEventW");
    HANDLE job = CreateJobObjectW(NULL, NULL);
    if (!job) { CloseHandle(event); return fail("CreateJobObjectW"); }
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = {0};
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation, &limits, sizeof(limits))) {
        CloseHandle(job); CloseHandle(event); return fail("SetInformationJobObject");
    }
    STARTUPINFOW si = {0}; PROCESS_INFORMATION pi = {0}; si.cb = sizeof(si);
    if (!CreateProcessW(self, line, NULL, NULL, FALSE, CREATE_SUSPENDED, NULL, NULL, &si, &pi)) {
        CloseHandle(job); CloseHandle(event); return fail("CreateProcessW");
    }
    if (assignment_failure) {
        BOOL assigned = AssignProcessToJobObject(NULL, pi.hProcess);
        DWORD assignment_error = GetLastError();
        BOOL terminated = TerminateProcess(pi.hProcess, 73);
        DWORD waited = WaitForSingleObject(pi.hProcess, 5000);
        DWORD exitcode = 0;
        BOOL observed = GetExitCodeProcess(pi.hProcess, &exitcode);
        DWORD marker = WaitForSingleObject(event, 0);
        CloseHandle(pi.hThread); CloseHandle(pi.hProcess); CloseHandle(job); CloseHandle(event);
        if (assigned || assignment_error != ERROR_INVALID_HANDLE || !terminated || waited != WAIT_OBJECT_0 ||
            !observed || exitcode != 73 || marker != WAIT_TIMEOUT) {
            fprintf(stderr, "assignment failure control did not reach expected state\n"); return 1;
        }
        puts("assignment failed; suspended child terminated without marker"); return 0;
    }
    if (!AssignProcessToJobObject(job, pi.hProcess)) {
        DWORD error = GetLastError(); TerminateProcess(pi.hProcess, 2); WaitForSingleObject(pi.hProcess, 5000);
        CloseHandle(pi.hThread); CloseHandle(pi.hProcess); CloseHandle(job); CloseHandle(event);
        SetLastError(error); return fail("AssignProcessToJobObject");
    }
    int result = 1;
    if (ResumeThread(pi.hThread) == (DWORD)-1) { fail("ResumeThread"); goto cleanup; }
    if (marker_control) {
        if (WaitForSingleObject(event, 5000) != WAIT_OBJECT_0 || WaitForSingleObject(pi.hProcess, 5000) != WAIT_OBJECT_0) {
            fprintf(stderr, "marker control failed\n"); goto cleanup;
        }
        puts("assignment succeeded; resumed child reached marker"); result = 0; goto cleanup;
    }
    if (WaitForSingleObject(event, 5000) != WAIT_OBJECT_0) { fprintf(stderr, "grandchild readiness timeout\n"); goto cleanup; }
    if (child_exits && WaitForSingleObject(pi.hProcess, 5000) != WAIT_OBJECT_0) { fprintf(stderr, "child exit timeout\n"); goto cleanup; }
    JOBOBJECT_BASIC_ACCOUNTING_INFORMATION stats = {0};
    DWORD expected = child_exits ? 1 : 2;
    for (unsigned int i = 0; i < 500; ++i) {
        if (!QueryInformationJobObject(job, JobObjectBasicAccountingInformation, &stats, sizeof(stats), NULL)) { fail("QueryInformationJobObject"); goto cleanup; }
        if (stats.ActiveProcesses == expected) break;
        Sleep(10);
    }
    if (stats.ActiveProcesses != expected) { fprintf(stderr, "expected %lu active, got %lu\n", (unsigned long)expected, (unsigned long)stats.ActiveProcesses); goto cleanup; }
    printf("ready: active=%lu\n", (unsigned long)stats.ActiveProcesses);
    if (!TerminateJobObject(job, 73)) { fail("TerminateJobObject"); goto cleanup; }
    if (WaitForSingleObject(pi.hProcess, 5000) != WAIT_OBJECT_0) { fprintf(stderr, "child exit timeout\n"); goto cleanup; }
    for (unsigned int i = 0; i < 500; ++i) {
        if (!QueryInformationJobObject(job, JobObjectBasicAccountingInformation, &stats, sizeof(stats), NULL)) { fail("post-termination query"); goto cleanup; }
        if (stats.ActiveProcesses == 0) break;
        Sleep(10);
    }
    DWORD exitcode = 0;
    DWORD expected_exit = child_exits ? 0 : 73;
    if (stats.ActiveProcesses != 0 || !GetExitCodeProcess(pi.hProcess, &exitcode) || exitcode != expected_exit) {
        fprintf(stderr, "drain failed: active=%lu exit=%lu\n", (unsigned long)stats.ActiveProcesses, (unsigned long)exitcode); goto cleanup;
    }
    printf("terminated: active=0 child_exit=%lu\n", (unsigned long)exitcode); result = 0;
cleanup:
    if (result != 0) { TerminateJobObject(job, 73); WaitForSingleObject(pi.hProcess, 5000); }
    CloseHandle(pi.hThread); CloseHandle(pi.hProcess); CloseHandle(job); CloseHandle(event);
    return result;
}
