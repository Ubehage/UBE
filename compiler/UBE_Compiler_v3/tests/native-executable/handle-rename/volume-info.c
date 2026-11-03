#include <windows.h>
#include <stdio.h>

int wmain(int argc, wchar_t **argv) {
    if (argc != 2) return 2;
    wchar_t root[MAX_PATH], filesystem[MAX_PATH];
    DWORD flags = 0, max_component = 0;
    if (!GetVolumePathNameW(argv[1], root, MAX_PATH) ||
        !GetVolumeInformationW(root, NULL, 0, NULL, &max_component, &flags, filesystem, MAX_PATH)) {
        fprintf(stderr, "volume query failed: %lu\n", (unsigned long)GetLastError());
        return 1;
    }
    wprintf(L"root=%ls filesystem=%ls max-component=%lu flags=0x%08lX\n", root, filesystem, (unsigned long)max_component, (unsigned long)flags);
    return 0;
}
