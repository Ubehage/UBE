#include <windows.h>
#include <ktmw32.h>
#include <stdio.h>
#include <wchar.h>

int wmain(int argc, wchar_t **argv) {
    if (argc != 4 && argc != 6) return 2;
    wchar_t candidate[32768], destination[32768], protected_path[32768];
    if (swprintf(candidate, 32768, L"%ls\\candidate.bin", argv[1]) < 0 ||
        swprintf(destination, 32768, L"%ls\\destination.bin", argv[1]) < 0 ||
        swprintf(protected_path, 32768, L"%ls\\protected.bin", argv[1]) < 0) return 2;
    HANDLE ready = OpenEventW(EVENT_MODIFY_STATE, FALSE, argv[2]);
    HANDLE release = OpenEventW(SYNCHRONIZE, FALSE, argv[3]);
    HANDLE transaction = CreateTransaction(NULL, NULL, 0, 0, 0, 0, NULL);
    if (!ready || !release || transaction == INVALID_HANDLE_VALUE) return 3;
    HANDLE guarded = CreateFileTransactedW(destination, GENERIC_READ | GENERIC_WRITE,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL, NULL, transaction, NULL, NULL);
    if (guarded == INVALID_HANDLE_VALUE) {
        fprintf(stderr, "transacted open failed: %lu\n", (unsigned long)GetLastError());
        RollbackTransaction(transaction); CloseHandle(transaction); CloseHandle(ready); CloseHandle(release); return 4;
    }
    HANDLE protected_file = CreateFileW(protected_path, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                                        NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    BY_HANDLE_FILE_INFORMATION target_info = {0}, protected_info = {0};
    if (protected_file == INVALID_HANDLE_VALUE || !GetFileInformationByHandle(guarded, &target_info) ||
        !GetFileInformationByHandle(protected_file, &protected_info)) {
        if (protected_file != INVALID_HANDLE_VALUE) CloseHandle(protected_file);
        CloseHandle(guarded); RollbackTransaction(transaction); CloseHandle(transaction); CloseHandle(ready); CloseHandle(release); return 9;
    }
    CloseHandle(protected_file);
    if (target_info.dwVolumeSerialNumber == protected_info.dwVolumeSerialNumber &&
        target_info.nFileIndexHigh == protected_info.nFileIndexHigh && target_info.nFileIndexLow == protected_info.nFileIndexLow) {
        fprintf(stderr, "protected identity rejected\n");
        CloseHandle(guarded); RollbackTransaction(transaction); CloseHandle(transaction); CloseHandle(ready); CloseHandle(release); return 8;
    }
    if (!SetEvent(ready) || WaitForSingleObject(release, 10000) != WAIT_OBJECT_0) {
        CloseHandle(guarded); RollbackTransaction(transaction); CloseHandle(transaction); CloseHandle(ready); CloseHandle(release); return 5;
    }
    if (argc == 6) {
        HANDLE closed_ready = OpenEventW(EVENT_MODIFY_STATE, FALSE, argv[4]);
        HANDLE closed_release = OpenEventW(SYNCHRONIZE, FALSE, argv[5]);
        CloseHandle(guarded); guarded = INVALID_HANDLE_VALUE;
        if (!closed_ready || !closed_release || !SetEvent(closed_ready) || WaitForSingleObject(closed_release, 10000) != WAIT_OBJECT_0) {
            if (closed_ready) CloseHandle(closed_ready); if (closed_release) CloseHandle(closed_release);
            RollbackTransaction(transaction); CloseHandle(transaction); CloseHandle(ready); CloseHandle(release); return 5;
        }
        CloseHandle(closed_ready); CloseHandle(closed_release);
    }
    BOOL moved = MoveFileTransactedW(candidate, destination, NULL, NULL, MOVEFILE_REPLACE_EXISTING, transaction);
    DWORD error = moved ? 0 : GetLastError();
    if (guarded != INVALID_HANDLE_VALUE) CloseHandle(guarded);
    if (!moved) {
        fprintf(stderr, "transacted move failed: %lu\n", (unsigned long)error);
        RollbackTransaction(transaction); CloseHandle(transaction); CloseHandle(ready); CloseHandle(release); return 6;
    }
    if (!CommitTransaction(transaction)) {
        fprintf(stderr, "transaction commit failed: %lu\n", (unsigned long)GetLastError());
        RollbackTransaction(transaction); CloseHandle(transaction); CloseHandle(ready); CloseHandle(release); return 7;
    }
    puts("transacted replacement committed");
    CloseHandle(transaction); CloseHandle(ready); CloseHandle(release); return 0;
}
