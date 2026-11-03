#include <windows.h>
#include <stdio.h>
#include <wchar.h>

int wmain(int argc, wchar_t **argv) {
    if (argc != 4 && argc != 5) return 2;
    if (argc == 5 && wcscmp(argv[4],L"read-only") != 0) return 2;
    HANDLE directory=CreateFileW(argv[1],FILE_LIST_DIRECTORY|FILE_READ_ATTRIBUTES,argc == 5 ? FILE_SHARE_READ : FILE_SHARE_READ|FILE_SHARE_WRITE,
                                  NULL,OPEN_EXISTING,FILE_FLAG_BACKUP_SEMANTICS|FILE_FLAG_OPEN_REPARSE_POINT,NULL);
    if (directory==INVALID_HANDLE_VALUE) { fprintf(stderr,"directory open failed: %lu\n",(unsigned long)GetLastError()); return 3; }
    FILE_ATTRIBUTE_TAG_INFO info={0};
    if (!GetFileInformationByHandleEx(directory,FileAttributeTagInfo,&info,sizeof(info)) ||
        !(info.FileAttributes & FILE_ATTRIBUTE_DIRECTORY) || (info.FileAttributes & FILE_ATTRIBUTE_REPARSE_POINT)) {
        fprintf(stderr,"not an ordinary directory\n"); CloseHandle(directory); return 4;
    }
    HANDLE ready=OpenEventW(EVENT_MODIFY_STATE,FALSE,argv[2]), release=OpenEventW(SYNCHRONIZE,FALSE,argv[3]);
    if (!ready || !release || !SetEvent(ready) || WaitForSingleObject(release,10000)!=WAIT_OBJECT_0) return 5;
    CloseHandle(ready); CloseHandle(release); CloseHandle(directory); return 0;
}
