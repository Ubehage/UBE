#include <windows.h>
#include <stdio.h>
#include <wchar.h>
int wmain(int argc, wchar_t **argv) {
    if (argc != 6) return 2;
    wchar_t candidate[32768], destination[32768];
    if (swprintf(candidate,32768,L"%ls\\candidate.bin",argv[1]) < 0 || swprintf(destination,32768,L"%ls\\destination.bin",argv[1]) < 0) return 2;
    HANDLE a=OpenEventW(EVENT_MODIFY_STATE,FALSE,argv[2]), b=OpenEventW(SYNCHRONIZE,FALSE,argv[3]);
    HANDLE c=OpenEventW(EVENT_MODIFY_STATE,FALSE,argv[4]), d=OpenEventW(SYNCHRONIZE,FALSE,argv[5]);
    if (!a || !b || !c || !d || !SetEvent(a) || WaitForSingleObject(b,10000)!=WAIT_OBJECT_0 ||
        !SetEvent(c) || WaitForSingleObject(d,10000)!=WAIT_OBJECT_0) return 3;
    if (!DeleteFileW(destination)) return 4;
    Sleep(100);
    if (!MoveFileExW(candidate,destination,0)) return 5;
    CloseHandle(a); CloseHandle(b); CloseHandle(c); CloseHandle(d);
    return 0;
}
