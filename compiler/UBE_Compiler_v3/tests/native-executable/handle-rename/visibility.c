#include <windows.h>
#include <stdio.h>
#include <wchar.h>
#include <winternl.h>
#include <stddef.h>
#include <string.h>

struct state { wchar_t final_path[32768], candidate_path[32768]; volatile LONG done, failed, reads, reads_a, reads_b; HANDLE ready, release; };

static int replace_file(struct state *s, const wchar_t *directory_path, int native) {
    if (native == 3) {
        if (!DeleteFileW(s->final_path)) return 0;
        Sleep(5);
        return MoveFileExW(s->candidate_path, s->final_path, 0) != 0;
    }
    if (native == 2) return ReplaceFileW(s->final_path, s->candidate_path, NULL, 0, NULL, NULL) != 0;
    if (!native) return MoveFileExW(s->candidate_path, s->final_path, MOVEFILE_REPLACE_EXISTING) != 0;
    HANDLE directory = CreateFileW(directory_path, FILE_LIST_DIRECTORY | FILE_ADD_FILE, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, NULL);
    if (directory == INVALID_HANDLE_VALUE) return 0;
    HANDLE source = CreateFileW(s->candidate_path, DELETE, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, OPEN_EXISTING, 0, NULL);
    if (source == INVALID_HANDLE_VALUE) { DWORD error = GetLastError(); CloseHandle(directory); SetLastError(error); return 0; }
    typedef NTSTATUS (NTAPI *SetInfo)(HANDLE, PIO_STATUS_BLOCK, PVOID, ULONG, FILE_INFORMATION_CLASS);
    typedef ULONG (WINAPI *ConvertStatus)(NTSTATUS);
    HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
    SetInfo set_info = (SetInfo)GetProcAddress(ntdll, "NtSetInformationFile");
    ConvertStatus convert = (ConvertStatus)GetProcAddress(ntdll, "RtlNtStatusToDosError");
    const wchar_t name[] = L"final.bin";
    _Alignas(FILE_RENAME_INFO) unsigned char buffer[offsetof(FILE_RENAME_INFO, FileName) + sizeof(name)] = {0};
    FILE_RENAME_INFO *info = (FILE_RENAME_INFO *)buffer;
    info->ReplaceIfExists = TRUE; info->RootDirectory = directory; info->FileNameLength = sizeof(name) - sizeof(wchar_t);
    if (native == 4) { ULONG flags = 3; memcpy(info, &flags, sizeof(flags)); }
    memcpy(info->FileName, name, info->FileNameLength);
    IO_STATUS_BLOCK block = {0};
    NTSTATUS status = set_info && convert ? set_info(source, &block, info, (ULONG)(offsetof(FILE_RENAME_INFO, FileName) + info->FileNameLength), (FILE_INFORMATION_CLASS)(native == 4 ? 65 : 10)) : (NTSTATUS)0xC0000002L;
    DWORD error = status == 0 ? 0 : convert ? convert(status) : ERROR_PROC_NOT_FOUND;
    CloseHandle(source); CloseHandle(directory); SetLastError(error);
    return status == 0;
}

static int write_image(const wchar_t *path, unsigned char value) {
    unsigned char data[65536]; DWORD written = 0;
    for (unsigned int i = 0; i < sizeof(data); ++i) data[i] = value;
    HANDLE file = CreateFileW(path, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE) return 0;
    int ok = WriteFile(file, data, sizeof(data), &written, NULL) && written == sizeof(data);
    if (!CloseHandle(file)) ok = 0;
    return ok;
}

static DWORD WINAPI read_images(void *arg) {
    struct state *s = arg;
    unsigned char data[65536];
    int first = 1;
    do {
        HANDLE file = CreateFileW(s->final_path, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, OPEN_EXISTING, 0, NULL);
        if (file == INVALID_HANDLE_VALUE) { fprintf(stderr, "reader open failed: %lu\n", (unsigned long)GetLastError()); InterlockedExchange(&s->failed, 1); break; }
        if (first) {
            first = 0;
            if (!SetEvent(s->ready) || WaitForSingleObject(s->release, 10000) != WAIT_OBJECT_0) { CloseHandle(file); InterlockedExchange(&s->failed, 1); break; }
        }
        DWORD total = 0, count = 0;
        while (total < sizeof(data)) {
            if (!ReadFile(file, data + total, (DWORD)sizeof(data) - total, &count, NULL) || !count) break;
            total += count;
        }
        unsigned char extra; DWORD more = 0;
        int valid = total == sizeof(data) && ReadFile(file, &extra, 1, &more, NULL) && more == 0 && (data[0] == 'A' || data[0] == 'B');
        for (DWORD i = 1; valid && i < total; ++i) if (data[i] != data[0]) valid = 0;
        CloseHandle(file);
        if (!valid) { fprintf(stderr, "reader content invalid: %lu bytes\n", (unsigned long)total); InterlockedExchange(&s->failed, 1); break; }
        if (data[0] == 'A') InterlockedIncrement(&s->reads_a); else InterlockedIncrement(&s->reads_b);
        InterlockedIncrement(&s->reads);
    } while (!InterlockedCompareExchange(&s->done, 0, 0));
    return 0;
}

int wmain(int argc, wchar_t **argv) {
    if (argc != 3 || (wcscmp(argv[2], L"move") && wcscmp(argv[2], L"native") && wcscmp(argv[2], L"posix") && wcscmp(argv[2], L"replace") && wcscmp(argv[2], L"no-reader") && wcscmp(argv[2], L"release-first") && wcscmp(argv[2], L"non-atomic"))) return 2;
    int native = wcscmp(argv[2], L"native") == 0 ? 1 : wcscmp(argv[2], L"replace") == 0 ? 2 : wcscmp(argv[2], L"non-atomic") == 0 ? 3 : wcscmp(argv[2], L"posix") == 0 ? 4 : 0;
    int no_reader = wcscmp(argv[2], L"no-reader") == 0;
    int release_first = wcscmp(argv[2], L"release-first") == 0;
    struct state s = {0};
    if (swprintf(s.final_path, 32768, L"%ls\\final.bin", argv[1]) < 0 ||
        swprintf(s.candidate_path, 32768, L"%ls\\candidate.bin", argv[1]) < 0 ||
        !write_image(s.final_path, 'A') || !write_image(s.candidate_path, 'B') ||
        !replace_file(&s, argv[1], native) ||
        !write_image(s.final_path, 'A')) return 3;
    s.ready = CreateEventW(NULL, TRUE, FALSE, NULL);
    s.release = CreateEventW(NULL, TRUE, FALSE, NULL);
    if (!s.ready || !s.release) { if (s.ready) CloseHandle(s.ready); if (s.release) CloseHandle(s.release); return 4; }
    HANDLE reader = no_reader ? NULL : CreateThread(NULL, 0, read_images, &s, 0, NULL);
    if (!no_reader && !reader) { CloseHandle(s.ready); CloseHandle(s.release); return 5; }
    if (!no_reader && WaitForSingleObject(s.ready, 5000) != WAIT_OBJECT_0) InterlockedExchange(&s.failed, 1);
    if (release_first) {
        InterlockedExchange(&s.done, 1);
        SetEvent(s.release);
        if (WaitForSingleObject(reader, 10000) != WAIT_OBJECT_0) InterlockedExchange(&s.failed, 1);
    }
    int completed = 0;
    for (int i = 0; i < 200 && !InterlockedCompareExchange(&s.failed, 0, 0); ++i) {
        if (!write_image(s.candidate_path, (i & 1) ? 'A' : 'B')) { fprintf(stderr, "candidate write failed: %lu\n", (unsigned long)GetLastError()); InterlockedExchange(&s.failed, 1); }
        else if (!replace_file(&s, argv[1], native)) { fprintf(stderr, "replacement failed: %lu\n", (unsigned long)GetLastError()); InterlockedExchange(&s.failed, 1); }
        else ++completed;
        if (i == 0) SetEvent(s.release);
    }
    InterlockedExchange(&s.done, 1);
    SetEvent(s.release);
    DWORD waited = no_reader ? WAIT_OBJECT_0 : WaitForSingleObject(reader, 10000);
    if (waited != WAIT_OBJECT_0) { fprintf(stderr, "reader did not finish\n"); return 6; }
    if (reader) CloseHandle(reader);
    CloseHandle(s.ready); CloseHandle(s.release);
    printf("complete reads: %ld; A: %ld; B: %ld; replacements: %d\n", (long)s.reads, (long)s.reads_a, (long)s.reads_b, completed);
    return s.failed || (!no_reader && !s.reads) ? 1 : 0;
}
