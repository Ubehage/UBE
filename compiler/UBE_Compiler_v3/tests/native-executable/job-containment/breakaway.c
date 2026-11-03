#include <windows.h>
#include <stdio.h>
#include <wchar.h>

int wmain(int argc, wchar_t **argv) {
    wchar_t self[32768], line[32768];
    DWORD len = GetModuleFileNameW(NULL, self, 32768);
    if (!len || len >= 32768) return 2;
    if (argc == 3 && (wcscmp(argv[1], L"grandchild") == 0 || wcscmp(argv[1], L"normal") == 0 || wcscmp(argv[1], L"breakaway") == 0 || wcscmp(argv[1], L"wrongjob") == 0)) {
        HANDLE expected_job = OpenJobObjectW(JOB_OBJECT_QUERY, FALSE, argv[2]);
        if (!expected_job) return 89;
        BOOL in_job = FALSE;
        BOOL observed = IsProcessInJob(GetCurrentProcess(), expected_job, &in_job);
        CloseHandle(expected_job);
        if (!observed || !in_job) return 90;
        if (wcscmp(argv[1], L"grandchild") == 0) return 0;
        if (swprintf(line, 32768, L"\"%ls\" grandchild %ls%ls", self, argv[2], wcscmp(argv[1], L"wrongjob") == 0 ? L"-missing" : L"") < 0) return 91;
        STARTUPINFOW si = {0}; PROCESS_INFORMATION pi = {0}; si.cb = sizeof(si);
        DWORD flags = wcscmp(argv[1], L"breakaway") == 0 ? CREATE_BREAKAWAY_FROM_JOB : 0;
        if (!CreateProcessW(self, line, NULL, NULL, FALSE, flags, NULL, NULL, &si, &pi)) {
            DWORD code = GetLastError();
            return code == ERROR_ACCESS_DENIED ? 5 : 92;
        }
        if (WaitForSingleObject(pi.hProcess, 5000) != WAIT_OBJECT_0) { TerminateProcess(pi.hProcess, 2); CloseHandle(pi.hThread); CloseHandle(pi.hProcess); return 93; }
        DWORD grandchild_exit = 0;
        if (!GetExitCodeProcess(pi.hProcess, &grandchild_exit) || grandchild_exit != 0) { CloseHandle(pi.hThread); CloseHandle(pi.hProcess); return 95; }
        CloseHandle(pi.hThread); CloseHandle(pi.hProcess);
        return flags ? 94 : 0;
    }
    if (argc != 2 || (wcscmp(argv[1], L"test-normal") && wcscmp(argv[1], L"test-breakaway") &&
                      wcscmp(argv[1], L"test-nested-normal") && wcscmp(argv[1], L"test-nested-breakaway") && wcscmp(argv[1], L"test-wrongjob"))) return 2;
    int nested = wcscmp(argv[1], L"test-nested-normal") == 0 || wcscmp(argv[1], L"test-nested-breakaway") == 0;
    int breaking = wcscmp(argv[1], L"test-breakaway") == 0 || wcscmp(argv[1], L"test-nested-breakaway") == 0;
    int wrongjob = wcscmp(argv[1], L"test-wrongjob") == 0;
    HANDLE outer = NULL;
    if (nested) {
        outer = CreateJobObjectW(NULL, NULL);
        if (!outer || !AssignProcessToJobObject(outer, GetCurrentProcess())) {
            fprintf(stderr, "outer Job setup failed: %lu\n", (unsigned long)GetLastError());
            if (outer) CloseHandle(outer);
            return 3;
        }
    }
    wchar_t job_name[128];
    if (swprintf(job_name, 128, L"Local\\UBE-breakaway-%lu", (unsigned long)GetCurrentProcessId()) < 0 ||
        swprintf(line, 32768, L"\"%ls\" %ls %ls", self, breaking ? L"breakaway" : wrongjob ? L"wrongjob" : L"normal", job_name) < 0) return 2;
    HANDLE job = CreateJobObjectW(NULL, job_name);
    if (!job) return 3;
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = {0};
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation, &limits, sizeof(limits))) { CloseHandle(job); return 3; }
    STARTUPINFOW si = {0}; PROCESS_INFORMATION pi = {0}; si.cb = sizeof(si);
    if (!CreateProcessW(self, line, NULL, NULL, FALSE, CREATE_SUSPENDED, NULL, NULL, &si, &pi)) { CloseHandle(job); return 3; }
    int result = 1;
    if (!AssignProcessToJobObject(job, pi.hProcess)) { TerminateProcess(pi.hProcess, 2); WaitForSingleObject(pi.hProcess, 5000); goto cleanup; }
    if (ResumeThread(pi.hThread) == (DWORD)-1 || WaitForSingleObject(pi.hProcess, 5000) != WAIT_OBJECT_0) goto cleanup;
    DWORD code = 0;
    if (!GetExitCodeProcess(pi.hProcess, &code) || code != (breaking ? 5U : wrongjob ? 95U : 0U)) { fprintf(stderr, "unexpected child result: %lu\n", (unsigned long)code); goto cleanup; }
    printf(breaking ? "breakaway request denied\n" : wrongjob ? "wrong Job control rejected\n" : "ordinary descendant in expected Job\n");
    result = 0;
cleanup:
    if (result) TerminateJobObject(job, 2);
    CloseHandle(pi.hThread); CloseHandle(pi.hProcess); CloseHandle(job);
    if (outer) CloseHandle(outer);
    return result;
}
