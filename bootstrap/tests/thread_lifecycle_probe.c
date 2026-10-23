#include <inttypes.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <windows.h>

typedef void (*ube_thread_entry)(void*);
typedef void (*ube_thread_capture_destroy)(void*);

int64_t ube_thread_start(ube_thread_entry, void*, ube_thread_capture_destroy);
int64_t ube_thread_current_id(void);
bool ube_thread_is_alive(int64_t);
int32_t ube_thread_request_stop(int64_t);
bool ube_thread_stop_requested(void);
int32_t ube_thread_wait(int64_t, int64_t);
void ube_thread_yield(void);
void ube_thread_test_fail_starts(uint32_t);
void ube_thread_test_fail_waits(uint32_t);
void ube_thread_close_admission(void);
typedef void (*ube_dispatch_callback)(void*);
typedef int32_t (*ube_dispatch_adapter)(int64_t, ube_dispatch_callback, void*);
void ube_dispatch_install_adapter(ube_dispatch_adapter);
int32_t ube_dispatch_invoke(int64_t, ube_dispatch_callback, void*);
void ube_dispatch_test_fail_admissions(uint32_t);
int32_t ube_dispatch_test_set_wait_target(int64_t, int64_t);
int32_t ube_err_number(void);
void ube_err_clear(void);
void ube_err_set(int32_t, const char*, const char*);

struct worker_capture {
    volatile LONG entered;
    volatile LONG observed;
    int32_t snapshot;
    int64_t worker_id;
};

struct wait_capture {
    int64_t id;
    int32_t result;
};

static void worker(void* raw_capture) {
    struct worker_capture* capture = raw_capture;
    capture->worker_id = ube_thread_current_id();
    InterlockedExchange(&capture->observed, capture->snapshot);
    ube_err_set(91, "worker-local", "thread-probe");
    InterlockedExchange(&capture->entered, 1);
    while (!ube_thread_stop_requested()) ube_thread_yield();
    if (ube_err_number() != 91) InterlockedExchange(&capture->observed, -1);
}

static DWORD WINAPI wait_for_worker(void* raw_capture) {
    struct wait_capture* capture = raw_capture;
    capture->result = ube_thread_wait(capture->id, 5000);
    return 0;
}

static int require(int condition, const char* message) {
    if (condition) return 1;
    fprintf(stderr, "thread lifecycle probe: %s\n", message);
    return 0;
}

static int32_t passthrough_dispatch(int64_t target_thread_id,
                                    ube_dispatch_callback callback,
                                    void* context) {
    (void)target_thread_id;
    callback(context);
    return 1;
}

static void count_dispatch(void* context) {
    LONG* count = context;
    InterlockedIncrement(count);
}

int main(void) {
    struct worker_capture first = {0, 0, 42, 0};
    const int64_t main_id = ube_thread_current_id();
    if (!require(main_id > 0, "main thread did not receive an ID")) return 1;

    ube_err_set(17, "main-local", "thread-probe");
    const int64_t first_id = ube_thread_start(worker, &first, NULL);
    first.snapshot = 99; /* the probe's explicit capture is not a compiler snapshot. */
    if (!require(first_id > main_id, "CallNew ID was not monotonic")) return 1;
    while (InterlockedCompareExchange(&first.entered, 0, 0) == 0) Sleep(1);
    if (!require(first.worker_id == first_id, "worker current ID disagrees")) return 1;
    if (!require(ube_thread_is_alive(first_id) == 1, "live worker reported completed")) return 1;
    if (!require(ube_err_number() == 17, "worker error state leaked to main")) return 1;
    if (!require(ube_thread_wait(first_id, 1) == 0, "finite wait did not time out")) return 1;
    ube_dispatch_install_adapter(passthrough_dispatch);
    LONG dispatch_count = 0;
    ube_dispatch_test_fail_admissions(1);
    ube_err_clear();
    if (!require(ube_dispatch_invoke(first_id, count_dispatch, &dispatch_count) == 0 &&
                 dispatch_count == 0 && ube_err_number() != 0,
                 "injected dispatcher admission failure was not clean")) return 1;
    ube_err_clear();
    if (!require(ube_dispatch_test_set_wait_target(first_id, main_id) == 1 &&
                 ube_dispatch_invoke(first_id, count_dispatch, &dispatch_count) == 0 &&
                 dispatch_count == 0 && ube_err_number() != 0,
                 "direct dispatcher wait cycle was not rejected")) return 1;
    if (!require(ube_dispatch_test_set_wait_target(first_id, 0) == 1,
                 "dispatcher cycle test state could not be cleared")) return 1;
    ube_err_clear();
    if (!require(ube_dispatch_invoke(first_id, count_dispatch, &dispatch_count) == 1 &&
                 dispatch_count == 1,
                 "installed dispatcher adapter did not run")) return 1;
    struct wait_capture first_waiter = { first_id, 0 };
    struct wait_capture second_waiter = { first_id, 0 };
    HANDLE waiter_threads[2] = {
        CreateThread(NULL, 0, wait_for_worker, &first_waiter, 0, NULL),
        CreateThread(NULL, 0, wait_for_worker, &second_waiter, 0, NULL)
    };
    if (!require(waiter_threads[0] != NULL && waiter_threads[1] != NULL,
                 "multiple waiter threads could not start")) return 1;
    ube_err_clear();
    ube_thread_test_fail_waits(1);
    if (!require(ube_thread_wait(first_id, 0) == 0 && ube_err_number() != 0,
                 "injected wait registration failure was not clean")) return 1;
    ube_err_clear();
    if (!require(ube_thread_request_stop(first_id) == 1, "stop request was rejected")) return 1;
    if (!require(WaitForMultipleObjects(2, waiter_threads, TRUE, 5000) == WAIT_OBJECT_0 &&
                 first_waiter.result == 1 && second_waiter.result == 1,
                 "multiple waiters did not observe completion")) return 1;
    CloseHandle(waiter_threads[0]);
    CloseHandle(waiter_threads[1]);
    if (!require(ube_thread_wait(first_id, 5000) == 1, "worker did not complete")) return 1;
    if (!require(ube_thread_is_alive(first_id) == 0, "completed worker reported alive")) return 1;
    if (!require(ube_thread_wait(first_id, 0) == 1, "completed ID did not wait immediately")) return 1;

    ube_err_clear();
    if (!require(ube_thread_wait(main_id, 0) == 0 && ube_err_number() != 0,
                 "self-wait did not report an error")) return 1;
    ube_err_clear();
    if (!require(ube_thread_is_alive(INT64_C(9223372036854775807)) == 0 &&
                 ube_err_number() != 0, "never-issued ID did not report an error")) return 1;

    ube_err_clear();
    ube_thread_test_fail_starts(1);
    if (!require(ube_thread_start(worker, &first, NULL) == 0 &&
                 ube_err_number() != 0, "injected creation failure was not clean")) return 1;

    ube_err_clear();
    ube_thread_close_admission();
    if (!require(ube_thread_start(worker, &first, NULL) == 0 &&
                 ube_err_number() != 0, "shutdown admission accepted a worker")) return 1;

    puts("thread lifecycle probe passed");
    return 0;
}
