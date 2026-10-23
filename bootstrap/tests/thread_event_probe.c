#include <stdint.h>
#include <stdio.h>
#include <windows.h>

extern int64_t ube_thread_event_create(int32_t manual_reset, int32_t initially_signaled);
extern void ube_thread_event_destroy(int64_t handle);
extern int32_t ube_thread_event_set(int64_t handle);
extern int32_t ube_thread_event_reset(int64_t handle);
extern int32_t ube_thread_event_wait(int64_t handle, int64_t timeout_milliseconds);
extern void ube_err_clear(void);
extern int32_t ube_err_number(void);
typedef void (*ube_thread_entry)(void*);
extern int64_t ube_thread_start(ube_thread_entry, void*, void (*)(void*));
extern int32_t ube_thread_request_stop(int64_t id);
extern int32_t ube_thread_wait(int64_t id, int64_t timeout_milliseconds);

struct cancellation_input {
    int64_t event;
    volatile LONG entered;
    int32_t result;
    int32_t error;
};

static void cancellation_worker(void* raw) {
    struct cancellation_input* input = raw;
    InterlockedExchange(&input->entered, 1);
    input->result = ube_thread_event_wait(input->event, -1);
    input->error = ube_err_number();
}

int main(void) {
    int64_t automatic = ube_thread_event_create(0, 0);
    int64_t manual = ube_thread_event_create(1, 1);
    if (automatic == 0 || manual == 0) return 1;
    if (ube_thread_event_wait(automatic, 0) != 0) return 2;
    if (ube_thread_event_set(automatic) != 1) return 3;
    if (ube_thread_event_wait(automatic, 0) != 1) return 4;
    if (ube_thread_event_wait(automatic, 0) != 0) return 5;
    if (ube_thread_event_wait(manual, 0) != 1) return 6;
    if (ube_thread_event_wait(manual, 0) != 1) return 7;
    if (ube_thread_event_reset(manual) != 1) return 8;
    if (ube_thread_event_wait(manual, 0) != 0) return 9;
    ube_err_clear();
    if (ube_thread_event_wait(manual, -2) != 0 || ube_err_number() == 0) return 10;
    ube_err_clear();
    struct cancellation_input cancellation = { automatic, 0, -1, -1 };
    int64_t worker = ube_thread_start(cancellation_worker, &cancellation, NULL);
    if (worker == 0) return 11;
    while (InterlockedCompareExchange(&cancellation.entered, 0, 0) == 0) {
        SwitchToThread();
    }
    if (!ube_thread_request_stop(worker) || !ube_thread_wait(worker, 5000)) return 12;
    if (cancellation.result != 0 || cancellation.error != 0) return 13;
    ube_thread_event_destroy(automatic);
    ube_thread_event_destroy(manual);
    puts("thread event probe passed");
    return 0;
}
