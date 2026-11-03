#include <windows.h>
#include <winternl.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>

int wmain(int argc, wchar_t **argv) {
    if (argc != 5) return 2;
    wchar_t source_path[32768], output_path[32768], command[32768];
    if (swprintf(source_path, 32768, L"%ls\\candidate.ll", argv[1]) < 0 ||
        swprintf(output_path, 32768, L"%ls\\output.o", argv[1]) < 0 ||
        swprintf(command, 32768, L"\"%ls\" --target=x86_64-w64-windows-gnu -O2 -Xclang -llvm-verify-each -x ir -c - -o \"%ls\"", argv[2], output_path) < 0) return 2;
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
    STARTUPINFOEXW si = {0}; si.StartupInfo.cb = sizeof(si);
    PROCESS_INFORMATION child = {0}; SIZE_T size = 0; int initialized = 0, result = 1;
    if (null_output == INVALID_HANDLE_VALUE || !SetHandleInformation(source, HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT)) goto cleanup;
    InitializeProcThreadAttributeList(NULL, 1, 0, &size);
    si.lpAttributeList = HeapAlloc(GetProcessHeap(), 0, size);
    if (!si.lpAttributeList || !InitializeProcThreadAttributeList(si.lpAttributeList, 1, 0, &size)) goto cleanup;
    initialized = 1;
    HANDLE inherited[2] = {source, null_output};
    if (!UpdateProcThreadAttribute(si.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST, inherited, sizeof(inherited), NULL, NULL)) goto cleanup;
    si.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
    si.StartupInfo.hStdInput = source; si.StartupInfo.hStdOutput = null_output; si.StartupInfo.hStdError = null_output;
    if (!CreateProcessW(argv[2], command, NULL, NULL, TRUE, EXTENDED_STARTUPINFO_PRESENT, NULL, NULL, &si.StartupInfo, &child)) goto cleanup;
    if (WaitForSingleObject(child.hProcess, 10000) != WAIT_OBJECT_0) { TerminateProcess(child.hProcess, 9); WaitForSingleObject(child.hProcess, 5000); goto cleanup; }
    DWORD exitcode = 0;
    if (!GetExitCodeProcess(child.hProcess, &exitcode) || exitcode != 0) goto cleanup;
    HANDLE reopened = ReOpenFile(source, GENERIC_READ | DELETE, FILE_SHARE_READ | FILE_SHARE_DELETE, 0);
    if (reopened == INVALID_HANDLE_VALUE) goto cleanup;
    const wchar_t *name = L"published.ll";
    _Alignas(FILE_RENAME_INFO) unsigned char storage[offsetof(FILE_RENAME_INFO, FileName) + 128] = {0};
    FILE_RENAME_INFO *info = (FILE_RENAME_INFO *)storage;
    info->ReplaceIfExists = FALSE; info->RootDirectory = directory;
    info->FileNameLength = (DWORD)(wcslen(name) * sizeof(wchar_t));
    memcpy(info->FileName, name, info->FileNameLength);
    HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
    typedef NTSTATUS (NTAPI *SetInfo)(HANDLE, PIO_STATUS_BLOCK, PVOID, ULONG, FILE_INFORMATION_CLASS);
    SetInfo set_info = (SetInfo)GetProcAddress(ntdll, "NtSetInformationFile");
    IO_STATUS_BLOCK status_block = {0};
    NTSTATUS status = set_info ? set_info(reopened, &status_block, info, (ULONG)(offsetof(FILE_RENAME_INFO, FileName) + info->FileNameLength), (FILE_INFORMATION_CLASS)10) : -1;
    CloseHandle(reopened);
    if (status != 0) goto cleanup;
    puts("held input compiled and reopened file renamed"); result = 0;
cleanup:
    if (result) fprintf(stderr, "tool/reopen probe failed: %lu\n", (unsigned long)GetLastError());
    if (child.hThread) CloseHandle(child.hThread);
    if (child.hProcess) CloseHandle(child.hProcess);
    if (initialized) DeleteProcThreadAttributeList(si.lpAttributeList);
    if (si.lpAttributeList) HeapFree(GetProcessHeap(), 0, si.lpAttributeList);
    if (null_output != INVALID_HANDLE_VALUE) CloseHandle(null_output);
    CloseHandle(source); CloseHandle(directory); return result;
}
