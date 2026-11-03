#include <windows.h>
#include <winternl.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>

static int job_empty(HANDLE job) {
    JOBOBJECT_BASIC_ACCOUNTING_INFORMATION info = {0};
    return QueryInformationJobObject(job, JobObjectBasicAccountingInformation, &info, sizeof(info), NULL) && info.ActiveProcesses == 0;
}

int wmain(int argc, wchar_t **argv) {
    if (argc != 5 && argc != 7) return 2;
    wchar_t source_path[32768], report_path[32768], snapshot_path[32768], command[32768];
    if (swprintf(source_path, 32768, L"%ls\\candidate.exe", argv[1]) < 0 ||
        swprintf(report_path, 32768, L"%ls\\inspection.txt", argv[1]) < 0 ||
        swprintf(snapshot_path, 32768, L"%ls\\observed.bin", argv[1]) < 0 ||
        swprintf(command, 32768, L"\"%ls\" --file-headers -", argv[2]) < 0) return 2;
    HANDLE directory = CreateFileW(argv[1], FILE_LIST_DIRECTORY | FILE_ADD_FILE, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                                   NULL, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, NULL);
    if (directory == INVALID_HANDLE_VALUE) return 3;
    HANDLE source = CreateFileW(source_path, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_DELETE, NULL, OPEN_EXISTING, 0, NULL);
    if (source == INVALID_HANDLE_VALUE) { CloseHandle(directory); return 4; }
    HANDLE ready = OpenEventW(EVENT_MODIFY_STATE, FALSE, argv[3]);
    HANDLE release = OpenEventW(SYNCHRONIZE, FALSE, argv[4]);
    if (!ready || !release || !SetEvent(ready) || WaitForSingleObject(release, 10000) != WAIT_OBJECT_0) { CloseHandle(source); CloseHandle(directory); return 5; }
    CloseHandle(ready); CloseHandle(release);
    SECURITY_ATTRIBUTES security = {sizeof(security), NULL, TRUE};
    HANDLE null_output = CreateFileW(L"NUL", GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, &security, OPEN_EXISTING, 0, NULL);
    HANDLE report = CreateFileW(report_path, GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, &security, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    STARTUPINFOEXW si = {0}; si.StartupInfo.cb = sizeof(si);
    PROCESS_INFORMATION child = {0}; SIZE_T size = 0; int initialized = 0, result = 1;
    HANDLE job = CreateJobObjectW(NULL, NULL);
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = {0};
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    if (!job || !SetInformationJobObject(job, JobObjectExtendedLimitInformation, &limits, sizeof(limits))) goto cleanup;
    if (null_output == INVALID_HANDLE_VALUE || report == INVALID_HANDLE_VALUE || !SetHandleInformation(source, HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT)) goto cleanup;
    InitializeProcThreadAttributeList(NULL, 1, 0, &size);
    si.lpAttributeList = HeapAlloc(GetProcessHeap(), 0, size);
    if (!si.lpAttributeList || !InitializeProcThreadAttributeList(si.lpAttributeList, 1, 0, &size)) goto cleanup;
    initialized = 1;
    HANDLE inherited[3] = {source, null_output, report};
    if (!UpdateProcThreadAttribute(si.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST, inherited, sizeof(inherited), NULL, NULL)) goto cleanup;
    si.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
    si.StartupInfo.hStdInput = source; si.StartupInfo.hStdOutput = report; si.StartupInfo.hStdError = null_output;
    if (!CreateProcessW(argv[2], command, NULL, NULL, TRUE, EXTENDED_STARTUPINFO_PRESENT | CREATE_SUSPENDED, NULL, NULL, &si.StartupInfo, &child)) goto cleanup;
    if (!AssignProcessToJobObject(job, child.hProcess)) { TerminateProcess(child.hProcess, 9); WaitForSingleObject(child.hProcess, 5000); goto cleanup; }
    if (ResumeThread(child.hThread) == (DWORD)-1) goto cleanup;
    if (WaitForSingleObject(child.hProcess, 10000) != WAIT_OBJECT_0) {
        if (TerminateJobObject(job, 9) && WaitForSingleObject(child.hProcess, 5000) == WAIT_OBJECT_0 && job_empty(job)) fprintf(stderr, "timed out; child exit observed\n");
        else fprintf(stderr, "timed out; child exit unconfirmed\n");
        goto cleanup;
    }
    DWORD exitcode = 0;
    if (!GetExitCodeProcess(child.hProcess, &exitcode)) goto cleanup;
    printf("inspector exit code: %lu\n", (unsigned long)exitcode);
    if (!job_empty(job)) {
        if (TerminateJobObject(job, 9)) {
            for (int i = 0; i < 500 && !job_empty(job); ++i) Sleep(10);
            if (job_empty(job)) fprintf(stderr, "remaining job processes stopped before inspection acceptance\n");
        }
        goto cleanup;
    }
    if (exitcode != 0) goto cleanup;
    LARGE_INTEGER offset = {0}, position;
    if (!SetFilePointerEx(source, offset, &position, FILE_CURRENT)) goto cleanup;
    printf("candidate position after inspection: %lld\n", (long long)position.QuadPart);
    LARGE_INTEGER size_report;
    char header[8192]; DWORD read = 0;
    if (!GetFileSizeEx(report, &size_report) || size_report.QuadPart < 0 || size_report.QuadPart >= (LONGLONG)sizeof(header) ||
        SetFilePointer(report, 0, NULL, FILE_BEGIN) == INVALID_SET_FILE_POINTER ||
        !ReadFile(report, header, (DWORD)size_report.QuadPart, &read, NULL) || read != (DWORD)size_report.QuadPart) goto cleanup;
    header[read] = '\0';
    if (memchr(header, 0, read) || !strstr(header, "Machine: IMAGE_FILE_MACHINE_AMD64") || !strstr(header, "IMAGE_FILE_EXECUTABLE_IMAGE") ||
        !strstr(header, "ImageOptionalHeader {") || !strstr(header, "Magic: 0x20B") || strstr(header, "    IMAGE_FILE_DLL (")) {
        fprintf(stderr, "candidate header rejected\n"); goto cleanup;
    }
    LARGE_INTEGER source_size;
    unsigned char at_current = 0; DWORD current_read = 0;
    if (!GetFileSizeEx(source, &source_size) || position.QuadPart != source_size.QuadPart ||
        !ReadFile(source, &at_current, 1, &current_read, NULL) || current_read != 0) goto cleanup;
    puts("unrewound read returned EOF");
    unsigned char magic[2]; DWORD magic_read = 0;
    if (!SetFilePointerEx(source, offset, NULL, FILE_BEGIN) || !ReadFile(source, magic, sizeof(magic), &magic_read, NULL) ||
        magic_read != sizeof(magic) || magic[0] != 'M' || magic[1] != 'Z') goto cleanup;
    puts("rewound candidate and reread MZ");
    if (!SetFilePointerEx(source, offset, NULL, FILE_BEGIN)) goto cleanup;
    HANDLE snapshot = CreateFileW(snapshot_path, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (snapshot == INVALID_HANDLE_VALUE) goto cleanup;
    unsigned char buffer[4096]; DWORD count = 0, written = 0; int copied = 1;
    for (;;) {
        if (!ReadFile(source, buffer, sizeof(buffer), &count, NULL)) { copied = 0; break; }
        if (!count) break;
        if (!WriteFile(snapshot, buffer, count, &written, NULL) || written != count) { copied = 0; break; }
    }
    if (!CloseHandle(snapshot)) copied = 0;
    if (!copied) goto cleanup;
    puts("inspection succeeded"); fflush(stdout);
    HANDLE reopened = ReOpenFile(source, GENERIC_READ | DELETE, FILE_SHARE_READ | FILE_SHARE_DELETE, 0);
    if (reopened == INVALID_HANDLE_VALUE) goto cleanup;
    if (argc == 7) {
        HANDLE commit_ready = OpenEventW(EVENT_MODIFY_STATE, FALSE, argv[5]);
        HANDLE commit_release = OpenEventW(SYNCHRONIZE, FALSE, argv[6]);
        int signaled = commit_ready && commit_release && SetEvent(commit_ready) && WaitForSingleObject(commit_release, 10000) == WAIT_OBJECT_0;
        if (commit_ready) CloseHandle(commit_ready);
        if (commit_release) CloseHandle(commit_release);
        if (!signaled) { CloseHandle(reopened); goto cleanup; }
    }
    const wchar_t *name = L"published.exe";
    _Alignas(FILE_RENAME_INFO) unsigned char storage[offsetof(FILE_RENAME_INFO, FileName) + 128] = {0};
    FILE_RENAME_INFO *info = (FILE_RENAME_INFO *)storage;
    ULONG flags = 3; memcpy(info, &flags, sizeof(flags)); info->RootDirectory = directory;
    info->FileNameLength = (DWORD)(wcslen(name) * sizeof(wchar_t));
    memcpy(info->FileName, name, info->FileNameLength);
    HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
    typedef NTSTATUS (NTAPI *SetInfo)(HANDLE, PIO_STATUS_BLOCK, PVOID, ULONG, FILE_INFORMATION_CLASS);
    SetInfo set_info = (SetInfo)GetProcAddress(ntdll, "NtSetInformationFile");
    IO_STATUS_BLOCK status_block = {0};
    if (!set_info) { CloseHandle(reopened); goto cleanup; }
    puts("commit attempted"); fflush(stdout);
    NTSTATUS status = set_info ? set_info(reopened, &status_block, info, (ULONG)(offsetof(FILE_RENAME_INFO, FileName) + info->FileNameLength), (FILE_INFORMATION_CLASS)65) : -1;
    CloseHandle(reopened);
    if (status != 0) { fprintf(stderr, "rename NTSTATUS: 0x%08lX\n", (unsigned long)(ULONG)status); goto cleanup; }
    puts("held candidate inspected and reopened file renamed"); result = 0;
cleanup:
    if (result) { if (job) TerminateJobObject(job, 9); fprintf(stderr, "tool/reopen probe failed\n"); }
    if (job) CloseHandle(job);
    if (child.hThread) CloseHandle(child.hThread);
    if (child.hProcess) CloseHandle(child.hProcess);
    if (initialized) DeleteProcThreadAttributeList(si.lpAttributeList);
    if (si.lpAttributeList) HeapFree(GetProcessHeap(), 0, si.lpAttributeList);
    if (null_output != INVALID_HANDLE_VALUE) CloseHandle(null_output);
    if (report != INVALID_HANDLE_VALUE) CloseHandle(report);
    CloseHandle(source); CloseHandle(directory); return result;
}
