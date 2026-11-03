#include <windows.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>

typedef struct {
    HANDLE pipe;
    unsigned long long total;
    DWORD kept;
    int failed;
    char prefix[4097];
} Capture;

static DWORD WINAPI drain(void *arg) {
    Capture *c = arg;
    char bytes[1024]; DWORD count;
    for (;;) {
        if (!ReadFile(c->pipe, bytes, sizeof(bytes), &count, NULL)) {
            if (GetLastError() != ERROR_BROKEN_PIPE) c->failed = 1;
            break;
        }
        if (!count) break;
        if (ULLONG_MAX - c->total < count) { c->failed = 1; break; }
        c->total += count;
        DWORD remaining = 4096 - c->kept;
        DWORD take = count < remaining ? count : remaining;
        memcpy(c->prefix + c->kept, bytes, take); c->kept += take;
    }
    c->prefix[c->kept] = 0;
    return 0;
}

int wmain(int argc, wchar_t **argv) {
    if (argc != 3) return 2;
    int result = 1, initialized = 0; SIZE_T size = 0;
    HANDLE source = INVALID_HANDLE_VALUE, job = NULL, read_pipe[2] = {NULL,NULL};
    HANDLE write_pipe[2] = {NULL,NULL}, threads[2] = {NULL,NULL};
    Capture *capture = HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, 2 * sizeof(Capture));
    STARTUPINFOEXW si = {0}; PROCESS_INFORMATION child = {0};
    wchar_t command[32768]; SECURITY_ATTRIBUTES security = {sizeof(security), NULL, TRUE};
    if (!capture || swprintf(command, 32768, L"\"%ls\" --file-headers -", argv[1]) < 0) goto cleanup;
    if (wcscmp(argv[2], L"-") == 0) {
        if (!DuplicateHandle(GetCurrentProcess(),GetStdHandle(STD_INPUT_HANDLE),GetCurrentProcess(),&source,0,TRUE,DUPLICATE_SAME_ACCESS))
            source = INVALID_HANDLE_VALUE;
    } else source = CreateFileW(argv[2], GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_DELETE, &security, OPEN_EXISTING, 0, NULL);
    job = CreateJobObjectW(NULL, NULL);
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = {0}; limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    if (source == INVALID_HANDLE_VALUE || !job || !SetInformationJobObject(job, JobObjectExtendedLimitInformation, &limits, sizeof(limits))) goto cleanup;
    for (int i = 0; i < 2; ++i) {
        if (!CreatePipe(&read_pipe[i], &write_pipe[i], &security, 0) || !SetHandleInformation(read_pipe[i], HANDLE_FLAG_INHERIT, 0)) goto cleanup;
        capture[i].pipe = read_pipe[i];
    }
    InitializeProcThreadAttributeList(NULL, 1, 0, &size);
    si.lpAttributeList = HeapAlloc(GetProcessHeap(), 0, size);
    if (!si.lpAttributeList || !InitializeProcThreadAttributeList(si.lpAttributeList, 1, 0, &size)) goto cleanup;
    initialized = 1;
    HANDLE inherited[3] = {source, write_pipe[0], write_pipe[1]};
    if (!UpdateProcThreadAttribute(si.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST, inherited, sizeof(inherited), NULL, NULL)) goto cleanup;
    si.StartupInfo.cb = sizeof(si); si.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
    si.StartupInfo.hStdInput = source; si.StartupInfo.hStdOutput = write_pipe[0]; si.StartupInfo.hStdError = write_pipe[1];
    if (!CreateProcessW(argv[1], command, NULL, NULL, TRUE, CREATE_SUSPENDED | EXTENDED_STARTUPINFO_PRESENT, NULL, NULL, &si.StartupInfo, &child)) goto cleanup;
    if (!AssignProcessToJobObject(job, child.hProcess)) { TerminateProcess(child.hProcess, 9); WaitForSingleObject(child.hProcess, 5000); goto cleanup; }
    for (int i = 0; i < 2; ++i) {
        CloseHandle(write_pipe[i]); write_pipe[i] = NULL;
        threads[i] = CreateThread(NULL, 0, drain, &capture[i], 0, NULL);
        if (!threads[i]) goto cleanup;
    }
    if (ResumeThread(child.hThread) == (DWORD)-1) goto cleanup;
    if (WaitForSingleObject(child.hProcess, 10000) != WAIT_OBJECT_0) {
        if (TerminateJobObject(job, 9) && WaitForSingleObject(child.hProcess, 5000) == WAIT_OBJECT_0)
            puts("timed out; inspector exit observed");
        else puts("timed out; inspector exit unconfirmed");
        goto cleanup;
    }
    JOBOBJECT_BASIC_ACCOUNTING_INFORMATION info = {0}; DWORD exitcode;
    if (!GetExitCodeProcess(child.hProcess, &exitcode)) goto cleanup;
    printf("inspector exit code=%lu\n", (unsigned long)exitcode);
    if (!QueryInformationJobObject(job, JobObjectBasicAccountingInformation, &info, sizeof(info), NULL)) goto cleanup;
    if (info.ActiveProcesses != 0) {
        if (TerminateJobObject(job, 9)) {
            for (int i = 0; i < 500; ++i) {
                if (!QueryInformationJobObject(job, JobObjectBasicAccountingInformation, &info, sizeof(info), NULL)) break;
                if (info.ActiveProcesses == 0) { puts("remaining job processes stopped"); break; }
                Sleep(10);
            }
        }
        goto cleanup;
    }
    if (exitcode != 0) goto cleanup;
    if (WaitForMultipleObjects(2, threads, TRUE, 5000) != WAIT_OBJECT_0 || capture[0].failed || capture[1].failed) goto cleanup;
    printf("stdout total=%llu kept=%lu; stderr total=%llu kept=%lu\n", capture[0].total, (unsigned long)capture[0].kept, capture[1].total, (unsigned long)capture[1].kept);
    int stdout_a = 1, stderr_b = 1;
    for (DWORD i = 0; i < capture[0].kept; ++i) if (capture[0].prefix[i] != 'A') stdout_a = 0;
    for (DWORD i = 0; i < capture[1].kept; ++i) if (capture[1].prefix[i] != 'B') stderr_b = 0;
    printf("uniform retained prefix: stdout A=%d; stderr B=%d\n", stdout_a, stderr_b);
    if (capture[0].total > 4096) { puts("report truncated; rejected"); goto cleanup; }
    if (memchr(capture[0].prefix, 0, capture[0].kept)) { puts("report contains NUL; rejected"); goto cleanup; }
    if (!strstr(capture[0].prefix, "Machine: IMAGE_FILE_MACHINE_AMD64") || !strstr(capture[0].prefix, "IMAGE_FILE_EXECUTABLE_IMAGE") ||
        !strstr(capture[0].prefix, "ImageOptionalHeader {") || !strstr(capture[0].prefix, "Magic: 0x20B") || strstr(capture[0].prefix, "    IMAGE_FILE_DLL (")) goto cleanup;
    puts("complete report accepted by test marker comparator"); result = 0;
cleanup:
    if (result && job) TerminateJobObject(job, 9);
    for (int i = 0; i < 2; ++i) if (write_pipe[i]) CloseHandle(write_pipe[i]);
    int all_stopped = 1;
    for (int i = 0; i < 2; ++i) {
        if (threads[i] && WaitForSingleObject(threads[i], 5000) != WAIT_OBJECT_0) {
            CancelSynchronousIo(threads[i]);
            if (WaitForSingleObject(threads[i], 5000) != WAIT_OBJECT_0) all_stopped = 0;
        }
    }
    if (all_stopped && threads[0] && threads[1] && capture && !capture[0].failed && !capture[1].failed)
        puts("both output pipes drained to EOF");
    if (all_stopped && threads[0] && capture && !capture[0].failed &&
        strstr(capture[0].prefix, "Machine: IMAGE_FILE_MACHINE_AMD64") && strstr(capture[0].prefix, "IMAGE_FILE_EXECUTABLE_IMAGE") &&
        strstr(capture[0].prefix, "ImageOptionalHeader {") && strstr(capture[0].prefix, "Magic: 0x20B"))
        puts("captured positive marker prefix");
    for (int i = 0; i < 2; ++i) { if (threads[i]) CloseHandle(threads[i]); if (read_pipe[i]) CloseHandle(read_pipe[i]); }
    if (all_stopped && capture) HeapFree(GetProcessHeap(), 0, capture);
    if (child.hThread) CloseHandle(child.hThread); if (child.hProcess) CloseHandle(child.hProcess);
    if (job) CloseHandle(job); if (source != INVALID_HANDLE_VALUE) CloseHandle(source);
    if (initialized) DeleteProcThreadAttributeList(si.lpAttributeList);
    if (si.lpAttributeList) HeapFree(GetProcessHeap(), 0, si.lpAttributeList);
    return result;
}
