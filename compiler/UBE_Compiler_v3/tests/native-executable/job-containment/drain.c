#include <windows.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

struct capture { HANDLE pipe; unsigned long long total; DWORD kept; unsigned char prefix[4096]; int failed; };
struct input_writer { HANDLE pipe; unsigned long long total; int failed; DWORD error; };

static DWORD WINAPI write_input(void *argument) {
    struct input_writer *writer = argument;
    unsigned char buffer[1024]; memset(buffer, 'I', sizeof(buffer));
    for (unsigned int i = 0; i < 128; ++i) {
        DWORD count = 0;
        if (!WriteFile(writer->pipe, buffer, sizeof(buffer), &count, NULL)) { writer->error = GetLastError(); writer->failed = 1; break; }
        if (count != sizeof(buffer)) { writer->failed = 1; break; }
        writer->total += count;
    }
    CloseHandle(writer->pipe); writer->pipe = NULL;
    return 0;
}

static int matches(const struct capture *capture, unsigned char expected, unsigned long long total, DWORD kept) {
    if (capture->failed || capture->total != total || capture->kept != kept) return 0;
    for (DWORD i = 0; i < capture->kept; ++i) if (capture->prefix[i] != expected) return 0;
    return 1;
}

static DWORD WINAPI drain(void *argument) {
    struct capture *capture = argument;
    unsigned char buffer[1024]; DWORD count = 0;
    for (;;) {
        if (!ReadFile(capture->pipe, buffer, sizeof(buffer), &count, NULL)) {
            if (GetLastError() != ERROR_BROKEN_PIPE) capture->failed = 1;
            break;
        }
        if (!count) break;
        DWORD remaining = (DWORD)sizeof(capture->prefix) - capture->kept;
        DWORD take = count < remaining ? count : remaining;
        memcpy(capture->prefix + capture->kept, buffer, take);
        capture->kept += take;
        capture->total += count;
    }
    return 0;
}

static int produce(const wchar_t *ready_name, const wchar_t *sentinel_text, const wchar_t *sentinel_name, unsigned int out_total, unsigned int err_total, int descendant, int duplex, int close_input) {
    HANDLE sentinel = (HANDLE)(uintptr_t)_wcstoui64(sentinel_text, NULL, 10);
    HANDLE named = OpenEventW(SYNCHRONIZE, FALSE, sentinel_name);
    if (!named) return 88;
    typedef LONG (WINAPI *CompareObjectsFn)(HANDLE, HANDLE);
    CompareObjectsFn compare = (CompareObjectsFn)GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "NtCompareObjects");
    if (!compare) { CloseHandle(named); return 88; }
    int inherited = named != sentinel && compare(named, sentinel) == 0;
    CloseHandle(named);
    if (inherited) return 89;
    unsigned char out[1024], err[1024];
    memset(out, 'A', sizeof(out)); memset(err, 'B', sizeof(err));
    DWORD count;
    unsigned char input;
    if (close_input && !CloseHandle(GetStdHandle(STD_INPUT_HANDLE))) return 100;
    if (!duplex && (!ReadFile(GetStdHandle(STD_INPUT_HANDLE), &input, 1, &count, NULL) ||
        (descendant == 2 ? (count != 1 || input != 'X') : count != 0))) return 90;
    unsigned int out_remaining = out_total, err_remaining = err_total;
    while (out_remaining || err_remaining) {
        DWORD chunk = out_remaining < sizeof(out) ? out_remaining : (DWORD)sizeof(out);
        if (chunk && (!WriteFile(GetStdHandle(STD_OUTPUT_HANDLE), out, chunk, &count, NULL) || count != chunk)) return 91;
        out_remaining -= chunk;
        chunk = err_remaining < sizeof(err) ? err_remaining : (DWORD)sizeof(err);
        if (chunk && (!WriteFile(GetStdHandle(STD_ERROR_HANDLE), err, chunk, &count, NULL) || count != chunk)) return 92;
        err_remaining -= chunk;
    }
    if (duplex && !close_input) {
        unsigned char buffer[1024]; unsigned long long total = 0;
        for (;;) {
            if (!ReadFile(GetStdHandle(STD_INPUT_HANDLE), buffer, sizeof(buffer), &count, NULL)) {
                if (GetLastError() == ERROR_BROKEN_PIPE) break;
                return 97;
            }
            if (!count) break;
            for (DWORD i = 0; i < count; ++i) if (buffer[i] != 'I') return 98;
            total += count;
        }
        if (total != 131072) return 99;
    }
    if (ready_name) {
        if (descendant) {
            wchar_t self[32768], line[32768];
            DWORD length = GetModuleFileNameW(NULL, self, 32768);
            if (!length || length >= 32768 || swprintf(line, 32768, L"\"%ls\" %ls %ls", self, descendant == 2 ? L"holder-candidate" : L"holder", ready_name) < 0) return 94;
            STARTUPINFOW si = {0}; PROCESS_INFORMATION pi = {0}; si.cb = sizeof(si);
            si.dwFlags = STARTF_USESTDHANDLES;
            si.hStdInput = GetStdHandle(STD_INPUT_HANDLE); si.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE); si.hStdError = GetStdHandle(STD_ERROR_HANDLE);
            if (!CreateProcessW(self, line, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)) return 95;
            CloseHandle(pi.hThread); CloseHandle(pi.hProcess);
            return 41;
        }
        HANDLE ready = OpenEventW(EVENT_MODIFY_STATE, FALSE, ready_name);
        if (!ready || !SetEvent(ready)) return 93;
        CloseHandle(ready);
        Sleep(INFINITE);
    }
    return close_input ? 0 : 41;
}

int wmain(int argc, wchar_t **argv) {
    if (argc == 3 && (wcscmp(argv[1], L"holder") == 0 || wcscmp(argv[1], L"holder-candidate") == 0)) {
        HANDLE ready = OpenEventW(EVENT_MODIFY_STATE, FALSE, argv[2]);
        if (!ready || !SetEvent(ready)) return 96;
        CloseHandle(ready);
        if (wcscmp(argv[1], L"holder-candidate") == 0) {
            wchar_t action_name[160], finished_name[160];
            if (swprintf(action_name, 160, L"%ls-action", argv[2]) < 0 || swprintf(finished_name, 160, L"%ls-finished", argv[2]) < 0) return 97;
            HANDLE action = OpenEventW(SYNCHRONIZE, FALSE, action_name);
            HANDLE finished = OpenEventW(EVENT_MODIFY_STATE, FALSE, finished_name);
            unsigned char byte = 0; DWORD count = 0;
            if (!action || !finished || WaitForSingleObject(action, 10000) != WAIT_OBJECT_0 ||
                !ReadFile(GetStdHandle(STD_INPUT_HANDLE), &byte, 1, &count, NULL) || count != 1 || byte != 'Y' || !SetEvent(finished)) return 97;
            CloseHandle(action); CloseHandle(finished);
        }
        Sleep(INFINITE); return 0;
    }
    if (argc == 4 && (wcscmp(argv[1], L"child") == 0 || wcscmp(argv[1], L"child-duplex") == 0 || wcscmp(argv[1], L"child-close-input") == 0 || wcscmp(argv[1], L"child-exact") == 0 || wcscmp(argv[1], L"child-excess") == 0 || wcscmp(argv[1], L"child-out-excess") == 0 || wcscmp(argv[1], L"child-err-excess") == 0)) {
        int close_input = wcscmp(argv[1], L"child-close-input") == 0;
        int duplex = wcscmp(argv[1], L"child-duplex") == 0 || close_input;
        unsigned int out = wcscmp(argv[1], L"child") == 0 || duplex ? 65536U : wcscmp(argv[1], L"child-exact") == 0 || wcscmp(argv[1], L"child-err-excess") == 0 ? 4096U : 4097U;
        unsigned int err = wcscmp(argv[1], L"child") == 0 || duplex ? 65536U : wcscmp(argv[1], L"child-exact") == 0 || wcscmp(argv[1], L"child-out-excess") == 0 ? 4096U : 4097U;
        return produce(NULL, argv[2], argv[3], out, err, 0, duplex, close_input);
    }
    if (argc == 5 && (wcscmp(argv[1], L"child-cancel") == 0 || wcscmp(argv[1], L"child-partial") == 0 || wcscmp(argv[1], L"child-descendant") == 0 || wcscmp(argv[1], L"child-candidate-descendant") == 0))
        return produce(argv[2], argv[3], argv[4], wcscmp(argv[1], L"child-cancel") == 0 ? 65536U : 5120U, wcscmp(argv[1], L"child-cancel") == 0 ? 65536U : 5120U, wcscmp(argv[1], L"child-candidate-descendant") == 0 ? 2 : wcscmp(argv[1], L"child-descendant") == 0, 0, 0);
    int candidate_descendant = argc == 3 && wcscmp(argv[1], L"candidate-descendant") == 0;
    int descendant = (argc == 2 && wcscmp(argv[1], L"descendant") == 0) || candidate_descendant;
    int partial = (argc == 2 && wcscmp(argv[1], L"cancel-partial") == 0) || descendant;
    int cancel = (argc == 2 && wcscmp(argv[1], L"cancel") == 0) || partial;
    int leak_control = argc == 2 && wcscmp(argv[1], L"leak-control") == 0;
    int exact = argc == 2 && wcscmp(argv[1], L"exact") == 0;
    int excess = argc == 2 && wcscmp(argv[1], L"excess") == 0;
    int out_excess = argc == 2 && wcscmp(argv[1], L"out-excess") == 0;
    int err_excess = argc == 2 && wcscmp(argv[1], L"err-excess") == 0;
    int undrained = argc == 2 && wcscmp(argv[1], L"duplex-undrained") == 0;
    int close_input = argc == 2 && wcscmp(argv[1], L"duplex-close-input") == 0;
    int duplex = argc == 2 && (wcscmp(argv[1], L"duplex") == 0 || undrained || close_input);
    if (argc != 1 && !cancel && !leak_control && !exact && !excess && !out_excess && !err_excess && !duplex) return 2;
    wchar_t self[32768], line[32768], ready_name[128], sentinel_name[128], action_name[160], finished_name[160];
    DWORD length = GetModuleFileNameW(NULL, self, 32768);
    if (!length || length >= 32768 || swprintf(ready_name, 128, L"Local\\UBE-drain-%lu", (unsigned long)GetCurrentProcessId()) < 0 ||
        swprintf(sentinel_name, 128, L"Local\\UBE-sentinel-%lu", (unsigned long)GetCurrentProcessId()) < 0) return 2;
    SECURITY_ATTRIBUTES security = {sizeof(security), NULL, TRUE};
    HANDLE out_read = NULL, out_write = NULL, err_read = NULL, err_write = NULL;
    HANDLE input = INVALID_HANDLE_VALUE, input_write = NULL, observer = NULL, threads[2] = {NULL, NULL}, input_thread = NULL, job = NULL, ready = NULL, sentinel = NULL, action = NULL, finished = NULL;
    PROCESS_INFORMATION child = {0};
    STARTUPINFOEXW si = {0}; si.StartupInfo.cb = sizeof(si);
    SIZE_T list_size = 0; int result = 1; int attributes_ready = 0;
    struct capture captures[2] = {0};
    struct input_writer writer = {0};
    if (cancel) { ready = CreateEventW(NULL, TRUE, FALSE, ready_name); if (!ready) goto cleanup; }
    if (candidate_descendant) {
        if (swprintf(action_name, 160, L"%ls-action", ready_name) < 0 || swprintf(finished_name, 160, L"%ls-finished", ready_name) < 0) goto cleanup;
        action = CreateEventW(NULL, TRUE, FALSE, action_name); finished = CreateEventW(NULL, TRUE, FALSE, finished_name);
        if (!action || !finished) goto cleanup;
    }
    sentinel = CreateEventW(&security, TRUE, FALSE, sentinel_name);
    if (!sentinel) goto cleanup;
    unsigned long long sentinel_value = (unsigned long long)(uintptr_t)sentinel;
    if (cancel) {
        const wchar_t *mode = candidate_descendant ? L"child-candidate-descendant" : descendant ? L"child-descendant" : partial ? L"child-partial" : L"child-cancel";
        if (swprintf(line, 32768, L"\"%ls\" %ls %ls %llu %ls", self, mode, ready_name, sentinel_value, sentinel_name) < 0) goto cleanup;
    } else if (swprintf(line, 32768, L"\"%ls\" %ls %llu %ls", self, exact ? L"child-exact" : excess ? L"child-excess" : out_excess ? L"child-out-excess" : err_excess ? L"child-err-excess" : close_input ? L"child-close-input" : duplex ? L"child-duplex" : L"child", sentinel_value, sentinel_name) < 0) goto cleanup;
    if (!CreatePipe(&out_read, &out_write, &security, 0) || !CreatePipe(&err_read, &err_write, &security, 0) ||
        !SetHandleInformation(out_read, HANDLE_FLAG_INHERIT, 0) || !SetHandleInformation(err_read, HANDLE_FLAG_INHERIT, 0)) goto cleanup;
    if (duplex) {
        if (!CreatePipe(&input, &input_write, &security, 0) || !SetHandleInformation(input_write, HANDLE_FLAG_INHERIT, 0)) goto cleanup;
        DWORD out_capacity = 0, err_capacity = 0, input_capacity = 0;
        if (!GetNamedPipeInfo(out_read, NULL, &out_capacity, NULL, NULL) ||
            !GetNamedPipeInfo(err_read, NULL, &err_capacity, NULL, NULL) ||
            !GetNamedPipeInfo(input_write, NULL, &input_capacity, NULL, NULL) ||
            !out_capacity || !err_capacity || !input_capacity || out_capacity >= 65536 || err_capacity >= 65536 || input_capacity >= 131072) goto cleanup;
        printf("pipe capacities: stdout=%lu stderr=%lu stdin=%lu\n", (unsigned long)out_capacity, (unsigned long)err_capacity, (unsigned long)input_capacity);
    } else input = candidate_descendant ? CreateFileW(argv[2], GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_DELETE, &security, OPEN_EXISTING, 0, NULL) : CreateFileW(L"NUL", GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, &security, OPEN_EXISTING, 0, NULL);
    if (input == INVALID_HANDLE_VALUE) goto cleanup;
    if (candidate_descendant && !DuplicateHandle(GetCurrentProcess(), input, GetCurrentProcess(), &observer, 0, FALSE, DUPLICATE_SAME_ACCESS)) goto cleanup;
    InitializeProcThreadAttributeList(NULL, 1, 0, &list_size);
    si.lpAttributeList = HeapAlloc(GetProcessHeap(), 0, list_size);
    if (!si.lpAttributeList || !InitializeProcThreadAttributeList(si.lpAttributeList, 1, 0, &list_size)) goto cleanup;
    attributes_ready = 1;
    HANDLE inherited[4] = {input, out_write, err_write, sentinel};
    SIZE_T inherited_size = (leak_control ? 4U : 3U) * sizeof(HANDLE);
    if (!UpdateProcThreadAttribute(si.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST, inherited, inherited_size, NULL, NULL)) goto cleanup;
    si.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
    si.StartupInfo.hStdInput = input; si.StartupInfo.hStdOutput = out_write; si.StartupInfo.hStdError = err_write;
    job = CreateJobObjectW(NULL, NULL);
    if (!job) goto cleanup;
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = {0};
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation, &limits, sizeof(limits))) goto cleanup;
    if (!CreateProcessW(self, line, NULL, NULL, TRUE, CREATE_SUSPENDED | EXTENDED_STARTUPINFO_PRESENT, NULL, NULL, &si.StartupInfo, &child)) goto cleanup;
    if (!AssignProcessToJobObject(job, child.hProcess)) goto cleanup;
    CloseHandle(out_write); out_write = NULL; CloseHandle(err_write); err_write = NULL; CloseHandle(input); input = INVALID_HANDLE_VALUE;
    captures[0].pipe = out_read; captures[1].pipe = err_read;
    if (!undrained) {
        threads[0] = CreateThread(NULL, 0, drain, &captures[0], 0, NULL);
        threads[1] = CreateThread(NULL, 0, drain, &captures[1], 0, NULL);
    }
    if (duplex) { writer.pipe = input_write; input_thread = CreateThread(NULL, 0, write_input, &writer, 0, NULL); if (input_thread) input_write = NULL; }
    if ((!undrained && (!threads[0] || !threads[1])) || (duplex && !input_thread) || ResumeThread(child.hThread) == (DWORD)-1) goto cleanup;
    if (undrained) {
        if (WaitForSingleObject(child.hProcess, 1000) != WAIT_TIMEOUT || WaitForSingleObject(input_thread, 0) != WAIT_TIMEOUT) goto cleanup;
        if (!TerminateJobObject(job, 73) || WaitForSingleObject(child.hProcess, 5000) != WAIT_OBJECT_0 ||
            WaitForSingleObject(input_thread, 5000) != WAIT_OBJECT_0 || !writer.failed || writer.total >= 131072) goto cleanup;
        DWORD stopped = 0;
        if (!GetExitCodeProcess(child.hProcess, &stopped) || stopped != 73) goto cleanup;
        puts("undrained output stalled child and input; termination released writer"); result = 0; goto cleanup;
    }
    if (cancel && WaitForSingleObject(ready, 10000) != WAIT_OBJECT_0) goto cleanup;
    if (descendant) {
        if (WaitForSingleObject(child.hProcess, 10000) != WAIT_OBJECT_0 ||
            WaitForSingleObject(threads[0], 0) != WAIT_TIMEOUT || WaitForSingleObject(threads[1], 0) != WAIT_TIMEOUT) goto cleanup;
        if (candidate_descendant) {
            if (!SetEvent(action) || WaitForSingleObject(finished, 10000) != WAIT_OBJECT_0) goto cleanup;
            LARGE_INTEGER zero = {0}, position;
            if (!SetFilePointerEx(observer, zero, &position, FILE_CURRENT) || position.QuadPart != 2) goto cleanup;
            CloseHandle(observer); observer = NULL;
            HANDLE writer = CreateFileW(argv[2], GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, OPEN_EXISTING, 0, NULL);
            if (writer != INVALID_HANDLE_VALUE) { CloseHandle(writer); goto cleanup; }
            if (GetLastError() != ERROR_SHARING_VIOLATION) goto cleanup;
        }
    }
    if (cancel && !TerminateJobObject(job, 73)) goto cleanup;
    if (WaitForSingleObject(child.hProcess, 10000) != WAIT_OBJECT_0 || WaitForMultipleObjects(2, threads, TRUE, 10000) != WAIT_OBJECT_0) goto cleanup;
    if (duplex && WaitForSingleObject(input_thread, 10000) != WAIT_OBJECT_0) goto cleanup;
    if (close_input ? (!writer.failed || !writer.error || writer.total >= 131072) : (duplex && (writer.failed || writer.total != 131072))) goto cleanup;
    DWORD exitcode = 0;
    if (!GetExitCodeProcess(child.hProcess, &exitcode) || exitcode != (leak_control ? 89U : cancel && !descendant ? 73U : close_input ? 0U : 41U)) {
        fprintf(stderr, "unexpected child exit: %lu\n", (unsigned long)exitcode); goto cleanup;
    }
    JOBOBJECT_BASIC_ACCOUNTING_INFORMATION stats = {0};
    for (int attempt = 0; attempt < 500; ++attempt) {
        if (!QueryInformationJobObject(job, JobObjectBasicAccountingInformation, &stats, sizeof(stats), NULL)) goto cleanup;
        if (stats.ActiveProcesses == 0) break;
        Sleep(10);
    }
    if (stats.ActiveProcesses != 0) goto cleanup;
    if (candidate_descendant) {
        HANDLE writer = CreateFileW(argv[2], GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, OPEN_EXISTING, 0, NULL);
        if (writer == INVALID_HANDLE_VALUE) goto cleanup;
        CloseHandle(writer);
        puts("descendant advanced shared candidate position and retained guard until Job termination");
    }
    if (leak_control) {
        if (captures[0].failed || captures[1].failed || captures[0].total || captures[1].total) goto cleanup;
        puts("unrelated inherited handle detected by child"); result = 0; goto cleanup;
    }
    for (int i = 0; i < 2; ++i) {
        unsigned long long expected_total = partial ? 5120 : exact ? 4096 : excess ? 4097 : out_excess ? (i ? 4096 : 4097) : err_excess ? (i ? 4097 : 4096) : 65536;
        unsigned char expected = (unsigned char)(i ? 'B' : 'A');
        if (!matches(&captures[i], expected, expected_total, 4096) ||
            matches(&captures[i], (unsigned char)(i ? 'A' : 'B'), expected_total, 4096) ||
            matches(&captures[i], expected, expected_total - 1, 4096) ||
            ((captures[i].total > captures[i].kept) != (expected_total > 4096))) {
            fprintf(stderr, "capture %d: total=%llu kept=%lu failed=%d expected=%llu\n", i,
                    captures[i].total, (unsigned long)captures[i].kept, captures[i].failed, expected_total);
            goto cleanup;
        }
    }
    if (close_input) printf("closed input detected: error=%lu bytes=%llu; outputs drained and Job empty\n", (unsigned long)writer.error, writer.total);
    else puts(duplex ? "full-duplex input and both output streams completed" : out_excess ? "stdout excess only; stderr exactly at limit" : err_excess ? "stderr excess only; stdout exactly at limit" :
         exact ? "4096 bytes per stream retained; no excess" : excess ? "4097 bytes per stream drained; 4096 retained; excess observed" :
         descendant ? "child exited 41; descendant held both pipes; Job terminated; streams drained; controls rejected" :
         partial ? "input EOF; partial output cancelled; child exit 73; Job empty; both streams drained; controls rejected" :
         cancel ? "input EOF; cancelled child exit 73; Job empty; both streams drained; controls rejected" :
                  "input EOF; contained child exit 41; Job empty; drained 65536 bytes per stream; retained 4096; controls rejected");
    result = 0;
cleanup:
    if (result) {
        fprintf(stderr, "drain probe failed: %lu\n", (unsigned long)GetLastError());
        if (job) TerminateJobObject(job, 99);
        if (child.hProcess) { TerminateProcess(child.hProcess, 99); WaitForSingleObject(child.hProcess, 5000); }
    }
    if (out_write) CloseHandle(out_write);
    if (err_write) CloseHandle(err_write);
    if (input != INVALID_HANDLE_VALUE) CloseHandle(input);
    if (observer) CloseHandle(observer);
    if (input_write) CloseHandle(input_write);
    for (int i = 0; i < 2; ++i) if (threads[i]) { WaitForSingleObject(threads[i], 5000); CloseHandle(threads[i]); }
    if (input_thread) { WaitForSingleObject(input_thread, 5000); CloseHandle(input_thread); }
    if (out_read) CloseHandle(out_read);
    if (err_read) CloseHandle(err_read);
    if (child.hThread) CloseHandle(child.hThread);
    if (child.hProcess) CloseHandle(child.hProcess);
    if (job) CloseHandle(job);
    if (ready) CloseHandle(ready);
    if (action) CloseHandle(action);
    if (finished) CloseHandle(finished);
    if (sentinel) CloseHandle(sentinel);
    if (attributes_ready) DeleteProcThreadAttributeList(si.lpAttributeList);
    if (si.lpAttributeList) HeapFree(GetProcessHeap(), 0, si.lpAttributeList);
    return result;
}
