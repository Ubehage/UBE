/* Test-only ordinary-directory publication probe, not a production path walker. */
#include <windows.h>
#include <winternl.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>

#define PATH_CAPACITY 32768
#define HANDLE_CAPACITY 32768
#define OPEN_REPARSE_POINT_OPTION 0x00200000UL
#define DIRECTORY_FILE_OPTION 0x00000001UL
#define SYNCHRONOUS_NONALERT_OPTION 0x00000020UL
#define OPEN_EXISTING_DISPOSITION 1UL
#define CASE_INSENSITIVE_ATTRIBUTE 0x00000040UL

typedef NTSTATUS (NTAPI *CreateFileFn)(PHANDLE, ACCESS_MASK,
    POBJECT_ATTRIBUTES, PIO_STATUS_BLOCK, PLARGE_INTEGER, ULONG, ULONG,
    ULONG, ULONG, PVOID, ULONG);
typedef NTSTATUS (NTAPI *SetInformationFn)(HANDLE, PIO_STATUS_BLOCK,
    PVOID, ULONG, FILE_INFORMATION_CLASS);

static wchar_t resolved_path[PATH_CAPACITY];
static HANDLE directory_handles[HANDLE_CAPACITY];

static int usable_handle(HANDLE handle) {
    return handle != NULL && handle != INVALID_HANDLE_VALUE;
}

static void close_handle(HANDLE *handle) {
    if (usable_handle(*handle)) CloseHandle(*handle);
    *handle = INVALID_HANDLE_VALUE;
}

static int ordinary_file(HANDLE handle, int directory) {
    FILE_ATTRIBUTE_TAG_INFO attributes = {0};
    if (!GetFileInformationByHandleEx(handle, FileAttributeTagInfo,
                                     &attributes, sizeof(attributes))) return 0;
    if (attributes.FileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) return 0;
    return ((attributes.FileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0) == directory;
}

static int leaf_name(const wchar_t *name) {
    size_t length = wcslen(name);
    return length > 0 && length < PATH_CAPACITY &&
        wcscmp(name, L".") != 0 && wcscmp(name, L"..") != 0 &&
        wcspbrk(name, L"\\/:") == NULL;
}

static NTSTATUS open_relative(CreateFileFn create_file, HANDLE parent,
                              const wchar_t *leaf, ACCESS_MASK access,
                              ULONG share, int directory, HANDLE *result) {
    UNICODE_STRING name = {0};
    OBJECT_ATTRIBUTES attributes = {0};
    IO_STATUS_BLOCK status_block = {0};
    size_t length = wcslen(leaf);
    *result = INVALID_HANDLE_VALUE;
    if (!leaf_name(leaf) || length > 32767) return (NTSTATUS)0xC0000033L;
    name.Buffer = (PWSTR)leaf;
    name.Length = (USHORT)(length * sizeof(wchar_t));
    name.MaximumLength = name.Length;
    attributes.Length = sizeof(attributes);
    attributes.RootDirectory = parent;
    attributes.ObjectName = &name;
    attributes.Attributes = CASE_INSENSITIVE_ATTRIBUTE;
    /* Directory handles only anchor names and inspect attributes. They perform
       no directory enumeration or synchronous I/O, so request neither right. */
    return create_file(result, access | (directory ? 0 : SYNCHRONIZE), &attributes, &status_block,
        NULL, FILE_ATTRIBUTE_NORMAL, share, OPEN_EXISTING_DISPOSITION,
        OPEN_REPARSE_POINT_OPTION | (directory ? 0 : SYNCHRONOUS_NONALERT_OPTION) |
            (directory ? DIRECTORY_FILE_OPTION : 0), NULL, 0);
}

static int same_file(const BY_HANDLE_FILE_INFORMATION *left,
                     const BY_HANDLE_FILE_INFORMATION *right) {
    return left->dwVolumeSerialNumber == right->dwVolumeSerialNumber &&
        left->nFileIndexHigh == right->nFileIndexHigh &&
        left->nFileIndexLow == right->nFileIndexLow;
}

int wmain(int argc, wchar_t **argv) {
    int result = 21;
    size_t directory_count = 0;
    HANDLE source = INVALID_HANDLE_VALUE, destination = INVALID_HANDLE_VALUE;
    HANDLE candidate = INVALID_HANDLE_VALUE;
    HANDLE ready = INVALID_HANDLE_VALUE, release = INVALID_HANDLE_VALUE;
    BY_HANDLE_FILE_INFORMATION source_identity = {0};
    const ULONG source_sharing = FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE;
    const wchar_t output_leaf[] = L"destination.bin";
    const wchar_t candidate_leaf[] = L"candidate.bin";
    HMODULE ntdll;
    CreateFileFn create_file;
    SetInformationFn set_information;
    DWORD length;
    wchar_t root[4];
    HANDLE parent;
    NTSTATUS status;

    if (argc != 6 || !leaf_name(argv[2]) ||
        (wcscmp(argv[5], L"commit") != 0 && wcscmp(argv[5], L"cancel") != 0)) {
        fprintf(stderr, "usage: probe directory source-leaf ready-event release-event commit|cancel\n");
        return 21;
    }
    /* This probe admits drive-absolute names only, not UNC or device paths. */
    if (wcslen(argv[1]) < 3 ||
        !((argv[1][0] >= L'A' && argv[1][0] <= L'Z') ||
          (argv[1][0] >= L'a' && argv[1][0] <= L'z')) ||
        argv[1][1] != L':' || argv[1][2] != L'\\') {
        fprintf(stderr, "directory is not an ordinary drive-absolute path\n");
        goto done;
    }
    length = GetFullPathNameW(argv[1], PATH_CAPACITY, resolved_path, NULL);
    if (length < 3 || length >= PATH_CAPACITY || resolved_path[1] != L':' ||
        resolved_path[2] != L'\\') {
        fprintf(stderr, "directory normalization failed\n");
        goto done;
    }
    ntdll = GetModuleHandleW(L"ntdll.dll");
    if (!ntdll) goto done;
    create_file = (CreateFileFn)GetProcAddress(ntdll, "NtCreateFile");
    set_information = (SetInformationFn)GetProcAddress(ntdll, "NtSetInformationFile");
    if (!create_file || !set_information) goto done;
    root[0] = resolved_path[0]; root[1] = L':'; root[2] = L'\\'; root[3] = 0;
    parent = CreateFileW(root,
        FILE_READ_ATTRIBUTES,
        FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING,
        FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, NULL);
    if (!usable_handle(parent)) {
        fprintf(stderr, "root open failed: %lu\n", (unsigned long)GetLastError());
        goto done;
    }
    directory_handles[directory_count++] = parent;
    if (!ordinary_file(parent, 1)) {
        fprintf(stderr, "root is not an ordinary directory\n");
        goto done;
    }
    for (size_t offset = 3; resolved_path[offset] != 0;) {
        size_t end = offset;
        wchar_t delimiter;
        HANDLE child = INVALID_HANDLE_VALUE;
        while (resolved_path[end] != 0 && resolved_path[end] != L'\\') end++;
        delimiter = resolved_path[end]; resolved_path[end] = 0;
        if (!leaf_name(resolved_path + offset) || directory_count == HANDLE_CAPACITY) {
            resolved_path[end] = delimiter;
            fprintf(stderr, "invalid directory component or path limit\n");
            goto done;
        }
        status = open_relative(create_file, parent, resolved_path + offset,
            FILE_READ_ATTRIBUTES,
            FILE_SHARE_READ | FILE_SHARE_WRITE, 1, &child);
        resolved_path[end] = delimiter;
        if (status < 0 || !usable_handle(child)) {
            close_handle(&child);
            fprintf(stderr, "relative directory open failed for %.*ls: %08lx\n",
                    (int)(end - offset), resolved_path + offset, (unsigned long)(ULONG)status);
            goto done;
        }
        directory_handles[directory_count++] = child;
        if (!ordinary_file(child, 1)) {
            fprintf(stderr, "reparse or non-directory component rejected\n");
            goto done;
        }
        parent = child;
        if (delimiter == 0) break;
        offset = end + 1;
    }
    status = open_relative(create_file, parent, argv[2], GENERIC_READ,
                           source_sharing, 0, &source);
    if (status < 0 || !ordinary_file(source, 0) ||
        !GetFileInformationByHandle(source, &source_identity)) {
        fprintf(stderr, "source read/identity open failed\n");
        goto done;
    }
    if (_wcsicmp(argv[2], output_leaf) == 0 ||
        _wcsicmp(argv[2], candidate_leaf) == 0) {
        fprintf(stderr, "initial source entry rejected\n");
        result = 20;
        goto done;
    }
    status = open_relative(create_file, parent, output_leaf, GENERIC_READ,
                           source_sharing, 0, &destination);
    if (status >= 0) {
        BY_HANDLE_FILE_INFORMATION destination_identity = {0};
        if (!ordinary_file(destination, 0) ||
            !GetFileInformationByHandle(destination, &destination_identity)) {
            fprintf(stderr, "initial destination identity failed\n");
            goto done;
        }
        if (same_file(&source_identity, &destination_identity)) {
            fprintf(stderr, "initial source alias rejected\n");
            result = 20;
            goto done;
        }
    } else if ((ULONG)status != 0xC0000034UL) {
        fprintf(stderr, "initial destination open failed: %08lx\n", (unsigned long)(ULONG)status);
        goto done;
    }
    close_handle(&source);
    close_handle(&destination);
    status = open_relative(create_file, parent, candidate_leaf, GENERIC_READ | DELETE,
                           FILE_SHARE_READ, 0, &candidate);
    result = 22;
    if (status < 0 || !ordinary_file(candidate, 0)) {
        fprintf(stderr, "candidate guarded open failed\n");
        goto done;
    }
    {
        LARGE_INTEGER candidate_length = {0};
        BY_HANDLE_FILE_INFORMATION candidate_identity = {0};
        char bytes[9];
        DWORD read = 0;
        if (!GetFileInformationByHandle(candidate, &candidate_identity) ||
            same_file(&source_identity, &candidate_identity) ||
            !GetFileSizeEx(candidate, &candidate_length) || candidate_length.QuadPart != 9 ||
            !ReadFile(candidate, bytes, sizeof(bytes), &read, NULL) || read != sizeof(bytes) ||
            memcmp(bytes, "candidate", sizeof(bytes)) != 0) {
            fprintf(stderr, "candidate validation failed\n");
            goto done;
        }
    }
    result = 21;
    ready = OpenEventW(EVENT_MODIFY_STATE, FALSE, argv[3]);
    release = OpenEventW(SYNCHRONIZE, FALSE, argv[4]);
    if (!usable_handle(ready) || !usable_handle(release) || !SetEvent(ready) ||
        WaitForSingleObject(release, 10000) != WAIT_OBJECT_0) {
        fprintf(stderr, "publication barrier failed\n");
        goto done;
    }
    if (wcscmp(argv[5], L"cancel") == 0) {
        result = 10;
        goto done;
    }
    {
        struct RenameRecord {
            ULONG flags;
            HANDLE root_directory;
            ULONG file_name_length;
            wchar_t file_name[sizeof(output_leaf) / sizeof(output_leaf[0])];
        } rename_info = {0};
        IO_STATUS_BLOCK status_block = {0};
        rename_info.flags = 3; /* REPLACE_IF_EXISTS | POSIX_SEMANTICS */
        rename_info.root_directory = parent;
        rename_info.file_name_length = sizeof(output_leaf) - sizeof(output_leaf[0]);
        memcpy(rename_info.file_name, output_leaf, rename_info.file_name_length);
        status = set_information(candidate, &status_block, &rename_info,
            (ULONG)(offsetof(struct RenameRecord, file_name) + rename_info.file_name_length),
            (FILE_INFORMATION_CLASS)65); /* FileRenameInformationEx */
        if (status < 0) {
            fprintf(stderr, "rename failed: %08lx\n", (unsigned long)(ULONG)status);
            result = 1;
        } else {
            puts("anchored rename succeeded");
            result = 0;
        }
    }
done:
    close_handle(&release);
    close_handle(&ready);
    close_handle(&candidate);
    close_handle(&destination);
    close_handle(&source);
    while (directory_count != 0) close_handle(&directory_handles[--directory_count]);
    return result;
}
