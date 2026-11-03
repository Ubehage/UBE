#include <windows.h>
#include <winioctl.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>

struct junction_data { DWORD tag; WORD length, reserved, substitute_offset, substitute_length, print_offset, print_length; WCHAR path[32768]; };
int wmain(int argc, wchar_t **argv) {
    if (argc != 3) return 2;
    struct junction_data data={0}; wchar_t substitute[16384];
    int chars=swprintf(substitute,16384,L"\\??\\%ls",argv[2]);
    size_t print_chars=wcslen(argv[2]);
    if (chars < 0 || (size_t)chars + print_chars + 2 > 32768) return 2;
    size_t substitute_bytes=(size_t)chars*sizeof(WCHAR), print_bytes=print_chars*sizeof(WCHAR);
    size_t payload=8+substitute_bytes+sizeof(WCHAR)+print_bytes+sizeof(WCHAR);
    if (payload > 65535) return 2;
    data.tag=IO_REPARSE_TAG_MOUNT_POINT; data.length=(WORD)payload;
    data.substitute_length=(WORD)substitute_bytes; data.print_offset=(WORD)(substitute_bytes+sizeof(WCHAR)); data.print_length=(WORD)print_bytes;
    memcpy(data.path,substitute,substitute_bytes); memcpy((unsigned char *)data.path+data.print_offset,argv[2],print_bytes);
    HANDLE h=CreateFileW(argv[1],GENERIC_WRITE,FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,NULL,OPEN_EXISTING,
                         FILE_FLAG_OPEN_REPARSE_POINT|FILE_FLAG_BACKUP_SEMANTICS,NULL);
    if (h==INVALID_HANDLE_VALUE) { printf("open error=%lu\n",(unsigned long)GetLastError()); return 3; }
    DWORD written=0; BOOL ok=DeviceIoControl(h,FSCTL_SET_REPARSE_POINT,&data,(DWORD)(8+payload),NULL,0,&written,NULL);
    DWORD error=ok?0:GetLastError(); CloseHandle(h);
    printf("set error=%lu\n",(unsigned long)error); return ok?0:4;
}
