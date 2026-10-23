#include <stdint.h>
#include <stdio.h>
#include <windows.h>

extern int64_t ube_semaphore_create(int64_t initial_count, int64_t maximum_count);
extern void ube_semaphore_destroy(int64_t handle);
extern int32_t ube_semaphore_wait(int64_t handle, int64_t timeout_milliseconds);
extern int32_t ube_semaphore_release(int64_t handle, int64_t release_count);
extern int32_t ube_semaphore_test_waiter_count(int64_t handle);
extern void ube_err_clear(void);
extern int32_t ube_err_number(void);

struct waiter_input { int64_t handle; int value; };
struct unload_waiter_input { int64_t handle; int result; int error; };
static volatile LONG completion_count;
static int completion_order[2];

static DWORD WINAPI wait_worker(void* raw) {
    struct waiter_input* input = raw;
    if (ube_semaphore_wait(input->handle, -1) != 1) return 1;
    LONG slot = InterlockedIncrement(&completion_count) - 1;
    if (slot >= 0 && slot < 2) completion_order[slot] = input->value;
    return 0;
}

static DWORD WINAPI unload_wait_worker(void* raw) {
    struct unload_waiter_input* input = raw;
    input->result = ube_semaphore_wait(input->handle, -1);
    input->error = ube_err_number();
    return 0;
}

int main(void) {
    int64_t semaphore = ube_semaphore_create(1, 2);
    if (semaphore == 0) return 1;
    if (ube_semaphore_wait(semaphore, 0) != 1) return 2;
    if (ube_semaphore_wait(semaphore, 0) != 0) return 3;
    struct waiter_input first = { semaphore, 1 };
    struct waiter_input second = { semaphore, 2 };
    HANDLE first_thread = CreateThread(NULL, 0, wait_worker, &first, 0, NULL);
    if (first_thread == NULL) return 4;
    while (ube_semaphore_test_waiter_count(semaphore) < 1) SwitchToThread();
    HANDLE second_thread = CreateThread(NULL, 0, wait_worker, &second, 0, NULL);
    if (second_thread == NULL) return 4;
    while (ube_semaphore_test_waiter_count(semaphore) < 2) SwitchToThread();
    if (ube_semaphore_release(semaphore, 1) != 1) return 5;
    while (completion_count < 1) SwitchToThread();
    if (completion_order[0] != 1) return 7;
    if (ube_semaphore_release(semaphore, 1) != 1) return 5;
    HANDLE threads[2] = { first_thread, second_thread };
    if (WaitForMultipleObjects(2, threads, TRUE, 5000) != WAIT_OBJECT_0) return 6;
    CloseHandle(first_thread);
    CloseHandle(second_thread);
    if (completion_order[1] != 2) return 7;
    if (ube_semaphore_release(semaphore, 2) != 1) return 8;
    ube_err_clear();
    if (ube_semaphore_release(semaphore, 1) != 0 || ube_err_number() == 0) return 9;
    ube_semaphore_destroy(semaphore);
    int64_t unloading = ube_semaphore_create(0, 1);
    struct unload_waiter_input unload_input = { unloading, -1, 0 };
    HANDLE unload_thread = CreateThread(NULL, 0, unload_wait_worker, &unload_input, 0, NULL);
    if (unloading == 0 || unload_thread == NULL) return 10;
    while (ube_semaphore_test_waiter_count(unloading) < 1) SwitchToThread();
    ube_semaphore_destroy(unloading);
    if (WaitForSingleObject(unload_thread, 5000) != WAIT_OBJECT_0) return 11;
    CloseHandle(unload_thread);
    if (unload_input.result != 0 || unload_input.error != 91) return 12;
    puts("semaphore probe passed");
    return 0;
}
