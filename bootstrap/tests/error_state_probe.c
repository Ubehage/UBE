#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

void ube_err_set(int32_t number, const char* description, const char* source);
int32_t ube_err_number(void);
void ube_err_clear(void);
void* ube_err_description(void);
void* ube_err_source(void);

/* Proves that a worker receives independent zero-initialized error state and
   cannot overwrite the creating thread's record. */
static DWORD WINAPI worker_main(void* unused) {
    (void)unused;
    if (ube_err_number() != 0) return 10;
    ube_err_set(202, "worker failure", "worker");
    if (ube_err_number() != 202) return 11;
    char* description = ube_err_description();
    char* source = ube_err_source();
    if (description == NULL || source == NULL ||
        strcmp(description, "worker failure") != 0 ||
        strcmp(source, "worker") != 0) return 12;
    ube_err_clear();
    return ube_err_number() == 0 ? 0 : 13;
}

/* Exercises publication, successful-operation persistence, explicit clear,
   and native-thread isolation for the RP7 error substrate. */
int main(void) {
    ube_err_set(101, "main failure", "probe");
    if (ube_err_number() != 101) return 20;
    HANDLE worker = CreateThread(NULL, 0, worker_main, NULL, 0, NULL);
    if (worker == NULL) return 21;
    WaitForSingleObject(worker, INFINITE);
    DWORD worker_status = 0;
    if (!GetExitCodeThread(worker, &worker_status) || worker_status != 0) {
        CloseHandle(worker);
        return worker_status == 0 ? 22 : (int)worker_status;
    }
    CloseHandle(worker);
    if (ube_err_number() != 101) return 23;
    ube_err_clear();
    if (ube_err_number() != 0) return 24;
    puts("error state probe passed");
    return 0;
}
