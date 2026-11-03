#include <windows.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>
int wmain(int argc, wchar_t **argv) {
    if (argc != 4 && argc != 5 && argc != 7) return 2;
    HANDLE directory=CreateFileW(argv[1],DELETE|FILE_LIST_DIRECTORY,FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,
                                 NULL,OPEN_EXISTING,FILE_FLAG_BACKUP_SEMANTICS|FILE_FLAG_OPEN_REPARSE_POINT,NULL);
    if (directory==INVALID_HANDLE_VALUE) { fprintf(stderr,"preopen failed: %lu\n",(unsigned long)GetLastError()); return 3; }
    HANDLE ready=OpenEventW(EVENT_MODIFY_STATE,FALSE,argv[2]), release=OpenEventW(SYNCHRONIZE,FALSE,argv[3]);
    if (!ready || !release || !SetEvent(ready) || WaitForSingleObject(release,10000)!=WAIT_OBJECT_0) return 4;
    if (argc == 5 || argc == 7) {
        size_t bytes=wcslen(argv[4])*sizeof(wchar_t), total=offsetof(FILE_RENAME_INFO,FileName)+bytes;
        if (bytes > 65535 || total > MAXDWORD) return 2;
        FILE_RENAME_INFO *info=calloc(1,total);
        if (!info) return 5;
        info->FileNameLength=(DWORD)bytes; memcpy(info->FileName,argv[4],bytes);
        BOOL ok=SetFileInformationByHandle(directory,FileRenameInfo,info,(DWORD)total);
        DWORD error=ok ? 0 : GetLastError();
        printf("preopened handle move error=%lu\n",(unsigned long)error); fflush(stdout);
        if (!ok && argc == 7) {
            HANDLE retry_ready=OpenEventW(EVENT_MODIFY_STATE,FALSE,argv[5]), retry_release=OpenEventW(SYNCHRONIZE,FALSE,argv[6]);
            if (!retry_ready || !retry_release || !SetEvent(retry_ready) || WaitForSingleObject(retry_release,10000)!=WAIT_OBJECT_0) { free(info); return 7; }
            CloseHandle(retry_ready); CloseHandle(retry_release);
            ok=SetFileInformationByHandle(directory,FileRenameInfo,info,(DWORD)total); error=ok ? 0 : GetLastError();
            printf("preopened handle retry error=%lu\n",(unsigned long)error); fflush(stdout);
        }
        free(info);
        if (!ok) return 6;
    }
    CloseHandle(ready); CloseHandle(release); CloseHandle(directory); return 0;
}
