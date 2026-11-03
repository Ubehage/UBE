#include <windows.h>
#include <winternl.h>
#include <ktmw32.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>

static int inspect_executable(HANDLE input, const wchar_t *wrapper, const wchar_t *inspector) {
    wchar_t command[32768]; SECURITY_ATTRIBUTES security={sizeof(security),NULL,TRUE};
    HANDLE sink=CreateFileW(L"NUL",GENERIC_WRITE,FILE_SHARE_READ|FILE_SHARE_WRITE,&security,OPEN_EXISTING,0,NULL);
    HANDLE job=CreateJobObjectW(NULL,NULL); PROCESS_INFORMATION child={0}; STARTUPINFOEXW si={0};
    SIZE_T size=0; int initialized=0, ok=0;
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits={0}; limits.BasicLimitInformation.LimitFlags=JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    LARGE_INTEGER start={0};
    int written=inspector ? swprintf(command,32768,L"\"%ls\" \"%ls\" -",wrapper,inspector) : swprintf(command,32768,L"\"%ls\" -",wrapper);
    if (sink==INVALID_HANDLE_VALUE || !job || !SetInformationJobObject(job,JobObjectExtendedLimitInformation,&limits,sizeof(limits)) ||
        !SetFilePointerEx(input,start,NULL,FILE_BEGIN) || !SetHandleInformation(input,HANDLE_FLAG_INHERIT,HANDLE_FLAG_INHERIT) || written<0) goto done;
    InitializeProcThreadAttributeList(NULL,1,0,&size); si.lpAttributeList=HeapAlloc(GetProcessHeap(),0,size);
    if (!si.lpAttributeList || !InitializeProcThreadAttributeList(si.lpAttributeList,1,0,&size)) goto done;
    initialized=1; HANDLE inherited[2]={input,sink};
    if (!UpdateProcThreadAttribute(si.lpAttributeList,0,PROC_THREAD_ATTRIBUTE_HANDLE_LIST,inherited,sizeof(inherited),NULL,NULL)) goto done;
    si.StartupInfo.cb=sizeof(si); si.StartupInfo.dwFlags=STARTF_USESTDHANDLES;
    si.StartupInfo.hStdInput=input; si.StartupInfo.hStdOutput=sink; si.StartupInfo.hStdError=sink;
    if (!CreateProcessW(wrapper,command,NULL,NULL,TRUE,CREATE_SUSPENDED|EXTENDED_STARTUPINFO_PRESENT,NULL,NULL,&si.StartupInfo,&child)) goto done;
    if (!AssignProcessToJobObject(job,child.hProcess)) { TerminateProcess(child.hProcess,9); WaitForSingleObject(child.hProcess,5000); goto done; }
    if (ResumeThread(child.hThread)==(DWORD)-1 || WaitForSingleObject(child.hProcess,10000)!=WAIT_OBJECT_0) goto done;
    DWORD code=1; JOBOBJECT_BASIC_ACCOUNTING_INFORMATION info={0};
    if (!GetExitCodeProcess(child.hProcess,&code) || code!=0 ||
        !QueryInformationJobObject(job,JobObjectBasicAccountingInformation,&info,sizeof(info),NULL) || info.ActiveProcesses!=0) goto done;
    ok=1;
done:
    if (!ok && job) TerminateJobObject(job,9);
    if (child.hThread) CloseHandle(child.hThread); if (child.hProcess) CloseHandle(child.hProcess);
    if (initialized) DeleteProcThreadAttributeList(si.lpAttributeList);
    if (si.lpAttributeList) HeapFree(GetProcessHeap(),0,si.lpAttributeList);
    if (job) CloseHandle(job); if (sink!=INVALID_HANDLE_VALUE) CloseHandle(sink);
    return ok;
}

int wmain(int argc, wchar_t **argv) {
    if (argc != 6 && argc != 8 && argc != 10 && argc != 11 && argc != 12 && argc != 13 && argc != 14 && argc != 15 && argc != 16) return 2;
    if (argc == 16 && wcscmp(argv[11],L"--protected-set") != 0) return 2;
    if (argc == 12 && wcscmp(argv[11],L"parent-sharewrite") != 0 && wcsncmp(argv[11],L"--protected=",12) != 0 && wcsncmp(argv[11],L"--protected-late=",17) != 0) return 2;
    if (argc == 14 && wcscmp(argv[13],L"allow-absent") != 0) return 2;
    if (argc == 15 && (wcscmp(argv[13],L"existing") != 0 || (wcscmp(argv[14],L"parent-guard") != 0 && wcscmp(argv[14],L"parent-posix") != 0 && wcscmp(argv[14],L"unprotected-posix") != 0 && wcscmp(argv[14],L"parent-sharewrite") != 0 && wcscmp(argv[14],L"parent-sharewrite-posix") != 0))) return 2;
    wchar_t candidate[32768], destination[32768], protected_path[32768];
    if (swprintf(candidate, 32768, L"%ls\\candidate.bin", argv[1]) < 0 ||
        swprintf(destination, 32768, L"%ls\\destination.bin", argv[1]) < 0 ||
        swprintf(protected_path, 32768, L"%ls\\protected.bin", argv[1]) < 0) return 2;
    if (argc == 12 && wcsncmp(argv[11],L"--protected=",12) == 0 && swprintf(protected_path,32768,L"%ls",argv[11]+12)<0) return 2;
    if (argc == 12 && wcsncmp(argv[11],L"--protected-late=",17) == 0 && swprintf(protected_path,32768,L"%ls",argv[11]+17)<0) return 2;
    HANDLE retained_protected=INVALID_HANDLE_VALUE;
    HANDLE retained_set[4]={INVALID_HANDLE_VALUE,INVALID_HANDLE_VALUE,INVALID_HANDLE_VALUE,INVALID_HANDLE_VALUE};
    if (argc == 16) {
        for (int i=0;i<4;++i) {
            retained_set[i]=CreateFileW(argv[12+i],GENERIC_READ,FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,NULL,OPEN_EXISTING,0,NULL);
            if (retained_set[i]==INVALID_HANDLE_VALUE) return 13;
        }
        puts("protected set retained"); fflush(stdout);
    }
    if (argc == 12 && wcsncmp(argv[11],L"--protected=",12) == 0) {
        retained_protected=CreateFileW(protected_path,GENERIC_READ,FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,NULL,OPEN_EXISTING,0,NULL);
        if (retained_protected==INVALID_HANDLE_VALUE) return 13;
        puts("protected identity retained"); fflush(stdout);
    }
    HANDLE inspected = INVALID_HANDLE_VALUE;
    if (argc == 8 || argc == 10 || argc == 11 || argc == 12 || argc == 13 || argc == 14 || argc == 15 || argc == 16) {
        inspected = CreateFileW(candidate, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_DELETE, NULL, OPEN_EXISTING, 0, NULL);
        HANDLE inspect_ready = OpenEventW(EVENT_MODIFY_STATE,FALSE,argv[6]);
        HANDLE inspect_release = OpenEventW(SYNCHRONIZE,FALSE,argv[7]);
        if (inspected == INVALID_HANDLE_VALUE || !inspect_ready || !inspect_release) return 10;
        if (argc == 11 || argc == 12 || argc == 16) {
            if (!inspect_executable(inspected,argv[10],NULL)) { fprintf(stderr,"structural inspection failed\n"); return 12; }
            puts("structural inspection succeeded"); fflush(stdout);
        }
        if (argc == 10 || argc == 11 || argc == 12 || argc == 13 || argc == 14 || argc == 15 || argc == 16) {
            if (!inspect_executable(inspected,argv[8],argv[9])) { fprintf(stderr,"executable inspection failed\n"); return 11; }
            puts("external inspection succeeded"); fflush(stdout);
        } else {
            char bytes[9]; DWORD count=0;
            if (!ReadFile(inspected,bytes,sizeof(bytes),&count,NULL) || count != sizeof(bytes) || memcmp(bytes,"candidate",sizeof(bytes))) return 10;
        }
        if (!SetEvent(inspect_ready) || WaitForSingleObject(inspect_release,10000) != WAIT_OBJECT_0) return 10;
        CloseHandle(inspect_ready); CloseHandle(inspect_release);
    }
    HANDLE events[4] = {OpenEventW(EVENT_MODIFY_STATE,FALSE,argv[2]), OpenEventW(SYNCHRONIZE,FALSE,argv[3]),
                        OpenEventW(EVENT_MODIFY_STATE,FALSE,argv[4]), OpenEventW(SYNCHRONIZE,FALSE,argv[5])};
    HANDLE tx = CreateTransaction(NULL,NULL,0,0,0,0,NULL);
    if (!events[0] || !events[1] || !events[2] || !events[3] || tx == INVALID_HANDLE_VALUE) return 3;
    int parent_guard=(argc==12 && wcscmp(argv[11],L"parent-sharewrite")==0) || (argc==15 && wcscmp(argv[14],L"unprotected-posix")!=0);
    int share_write=(argc==12 && wcscmp(argv[11],L"parent-sharewrite")==0) || (argc==15 && (wcscmp(argv[14],L"parent-sharewrite")==0 || wcscmp(argv[14],L"parent-sharewrite-posix")==0));
    DWORD dir_share=parent_guard ? (share_write ? FILE_SHARE_READ|FILE_SHARE_WRITE : FILE_SHARE_READ) : FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE;
    HANDLE dir = CreateFileW(argv[1], FILE_LIST_DIRECTORY | FILE_ADD_FILE, dir_share,
                             NULL, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, NULL);
    DWORD directory_error=dir==INVALID_HANDLE_VALUE ? GetLastError() : 0;
    HANDLE target = CreateFileTransactedW(destination, GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                                          NULL, argc == 14 ? OPEN_ALWAYS : OPEN_EXISTING, 0, NULL, tx, NULL, NULL);
    DWORD target_error=target==INVALID_HANDLE_VALUE ? GetLastError() : 0;
    HANDLE source = CreateFileTransactedW(candidate, DELETE | GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_DELETE,
                                          NULL, OPEN_EXISTING, 0, NULL, tx, NULL, NULL);
    DWORD source_error=source==INVALID_HANDLE_VALUE ? GetLastError() : 0;
    HANDLE protected_file = argc==16 ? retained_set[0] : retained_protected != INVALID_HANDLE_VALUE ? retained_protected :
        CreateFileW(protected_path, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, OPEN_EXISTING, 0, NULL);
    DWORD protected_error=protected_file==INVALID_HANDLE_VALUE ? GetLastError() : 0;
    int result = 1;
    if (dir == INVALID_HANDLE_VALUE || target == INVALID_HANDLE_VALUE || source == INVALID_HANDLE_VALUE || protected_file == INVALID_HANDLE_VALUE) {
        if (directory_error) fprintf(stderr,"directory open failed: %lu\n",(unsigned long)directory_error);
        if (target_error) fprintf(stderr,"target open failed: %lu\n",(unsigned long)target_error);
        if (source_error) fprintf(stderr,"source open failed: %lu\n",(unsigned long)source_error);
        if (protected_error) fprintf(stderr,"protected input open failed: %lu\n",(unsigned long)protected_error);
        goto cleanup;
    }
    BY_HANDLE_FILE_INFORMATION a = {0}, b = {0};
    if (!GetFileInformationByHandle(target,&a) || !GetFileInformationByHandle(protected_file,&b)) goto cleanup;
    if (a.dwVolumeSerialNumber == b.dwVolumeSerialNumber && a.nFileIndexHigh == b.nFileIndexHigh && a.nFileIndexLow == b.nFileIndexLow) {
        fprintf(stderr,"protected identity rejected\n"); goto cleanup;
    }
    if (argc==16) {
        int protected_count=4;
#ifdef OMIT_LAST_PROTECTED
        protected_count=3;
#endif
        for (int i=1;i<protected_count;++i) {
            BY_HANDLE_FILE_INFORMATION entry={0};
            if (!GetFileInformationByHandle(retained_set[i],&entry)) goto cleanup;
            if (a.dwVolumeSerialNumber==entry.dwVolumeSerialNumber && a.nFileIndexHigh==entry.nFileIndexHigh && a.nFileIndexLow==entry.nFileIndexLow) {
                fprintf(stderr,"protected identity rejected\n"); goto cleanup;
            }
        }
    }
    if (inspected != INVALID_HANDLE_VALUE) {
        BY_HANDLE_FILE_INFORMATION inspected_info = {0}, source_info = {0};
        if (!GetFileInformationByHandle(inspected,&inspected_info) || !GetFileInformationByHandle(source,&source_info)) goto cleanup;
        if (inspected_info.dwVolumeSerialNumber != source_info.dwVolumeSerialNumber || inspected_info.nFileIndexHigh != source_info.nFileIndexHigh ||
            inspected_info.nFileIndexLow != source_info.nFileIndexLow) { fprintf(stderr,"candidate identity mismatch\n"); goto cleanup; }
        puts("inspected candidate identity matched"); fflush(stdout);
    }
    if (!SetEvent(events[0]) || WaitForSingleObject(events[1],10000) != WAIT_OBJECT_0) goto cleanup;
    CloseHandle(target); target=INVALID_HANDLE_VALUE;
    if (!SetEvent(events[2]) || WaitForSingleObject(events[3],10000) != WAIT_OBJECT_0) goto cleanup;
    const wchar_t *name=L"destination.bin";
    _Alignas(FILE_RENAME_INFO) unsigned char storage[offsetof(FILE_RENAME_INFO,FileName)+128] = {0};
    FILE_RENAME_INFO *info=(FILE_RENAME_INFO *)storage;
    info->ReplaceIfExists=TRUE; info->RootDirectory=dir; info->FileNameLength=(DWORD)(wcslen(name)*sizeof(wchar_t));
    int posix_rename=argc==15 && (wcscmp(argv[14],L"parent-posix")==0 || wcscmp(argv[14],L"unprotected-posix")==0 || wcscmp(argv[14],L"parent-sharewrite-posix")==0);
    if (posix_rename) { ULONG flags=3; memcpy(info,&flags,sizeof(flags)); }
    memcpy(info->FileName,name,info->FileNameLength);
    typedef NTSTATUS (NTAPI *SetInfo)(HANDLE,PIO_STATUS_BLOCK,PVOID,ULONG,FILE_INFORMATION_CLASS);
    SetInfo set_info=(SetInfo)GetProcAddress(GetModuleHandleW(L"ntdll.dll"),"NtSetInformationFile");
    IO_STATUS_BLOCK status_block={0};
    if (!set_info) goto cleanup;
    NTSTATUS status=set_info(source,&status_block,info,(ULONG)(offsetof(FILE_RENAME_INFO,FileName)+info->FileNameLength),(FILE_INFORMATION_CLASS)(posix_rename ? 65 : 10));
    if (status != 0) { fprintf(stderr,"transacted handle rename NTSTATUS: 0x%08lX\n",(unsigned long)(ULONG)status); goto cleanup; }
    CloseHandle(source); source=INVALID_HANDLE_VALUE;
    if (argc == 13 || argc == 14 || argc == 15) {
        HANDLE staged_ready=OpenEventW(EVENT_MODIFY_STATE,FALSE,argv[10]);
        HANDLE staged_release=OpenEventW(SYNCHRONIZE,FALSE,argv[11]);
        if (!staged_ready || !staged_release || !SetEvent(staged_ready) || WaitForSingleObject(staged_release,10000)!=WAIT_OBJECT_0) {
            if (staged_ready) CloseHandle(staged_ready); if (staged_release) CloseHandle(staged_release);
            goto cleanup;
        }
        CloseHandle(staged_ready); CloseHandle(staged_release);
        if (wcscmp(argv[12],L"rollback")==0) {
            if (!RollbackTransaction(tx)) { fprintf(stderr,"rollback failed: %lu\n",(unsigned long)GetLastError()); goto cleanup; }
            puts("transaction rollback succeeded"); result=0; goto cleanup;
        }
        if (wcscmp(argv[12],L"commit")!=0) goto cleanup;
    }
    if (!CommitTransaction(tx)) { fprintf(stderr,"commit failed: %lu\n",(unsigned long)GetLastError()); goto cleanup; }
    puts("transacted handle rename committed"); result=0;
cleanup:
    if (target != INVALID_HANDLE_VALUE) CloseHandle(target);
    if (source != INVALID_HANDLE_VALUE) CloseHandle(source);
    if (protected_file != INVALID_HANDLE_VALUE) CloseHandle(protected_file);
    if (argc==16) for (int i=1;i<4;++i) if (retained_set[i]!=INVALID_HANDLE_VALUE) CloseHandle(retained_set[i]);
    if (dir != INVALID_HANDLE_VALUE) CloseHandle(dir);
    if (inspected != INVALID_HANDLE_VALUE) CloseHandle(inspected);
    if (result) RollbackTransaction(tx);
    CloseHandle(tx); for (int i=0;i<4;++i) CloseHandle(events[i]);
    return result;
}
