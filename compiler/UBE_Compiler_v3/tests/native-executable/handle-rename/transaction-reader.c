#include <windows.h>
#include <stdio.h>
#include <string.h>

int wmain(int argc, wchar_t **argv) {
    if (argc != 5) return 2;
    HANDLE old_event=OpenEventW(EVENT_MODIFY_STATE,FALSE,argv[2]);
    HANDLE new_event=OpenEventW(EVENT_MODIFY_STATE,FALSE,argv[3]);
    HANDLE stop=OpenEventW(SYNCHRONIZE,FALSE,argv[4]);
    if (!old_event || !new_event || !stop) return 3;
    unsigned long old_count=0,new_count=0,missing=0,sharing=0,other=0,invalid=0;
    do {
        HANDLE file=CreateFileW(argv[1],GENERIC_READ,FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,NULL,OPEN_EXISTING,0,NULL);
        if (file == INVALID_HANDLE_VALUE) {
            DWORD error=GetLastError();
            if (error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND) ++missing;
            else if (error == ERROR_SHARING_VIOLATION || error == ERROR_ACCESS_DENIED) ++sharing;
            else ++other;
        } else {
            char data[16]; DWORD count=0,extra=0; char more;
            int valid=ReadFile(file,data,sizeof(data),&count,NULL) && ReadFile(file,&more,1,&extra,NULL) && extra==0;
            if (valid && count==3 && memcmp(data,"old",3)==0) { ++old_count; SetEvent(old_event); }
            else if (valid && count==9 && memcmp(data,"candidate",9)==0) { ++new_count; SetEvent(new_event); }
            else ++invalid;
            CloseHandle(file);
        }
        Sleep(0);
    } while (WaitForSingleObject(stop,0)==WAIT_TIMEOUT);
    printf("old=%lu new=%lu missing=%lu sharing=%lu other=%lu invalid=%lu\n",old_count,new_count,missing,sharing,other,invalid);
    CloseHandle(old_event); CloseHandle(new_event); CloseHandle(stop);
    return invalid || other ? 1 : 0;
}
