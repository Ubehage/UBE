#include <stdint.h>
#include <stdio.h>
#include <windows.h>

extern int64_t ube_message_queue_create(void);
extern void ube_message_queue_destroy(int64_t handle);
extern int32_t ube_message_queue_enqueue(int64_t handle, void* value);
extern int32_t ube_message_queue_dequeue(int64_t handle, void** destination, int64_t timeout_milliseconds);
extern void* ube_variant_from_long(int32_t value);
extern int32_t ube_variant_get_long(const void* value, int32_t* result);
extern void ube_err_clear(void);
extern int32_t ube_err_number(void);
extern int64_t ube_thread_start(void (*entry)(void*), void* capture,
                                void (*destroy)(void*));
extern int32_t ube_thread_request_stop(int64_t id);
extern int32_t ube_thread_wait(int64_t id, int64_t timeout_milliseconds);

struct wait_capture {
    int64_t queue;
    volatile LONG entered;
    int32_t result;
    int32_t error;
};

static void wait_for_message(void* raw_capture) {
    struct wait_capture* capture = raw_capture;
    void* value = NULL;
    InterlockedExchange(&capture->entered, 1);
    capture->result = ube_message_queue_dequeue(capture->queue, &value, -1);
    capture->error = ube_err_number();
}

static void wait_until_entered(struct wait_capture* capture) {
    while (InterlockedCompareExchange(&capture->entered, 0, 0) == 0) Sleep(1);
    Sleep(20);
}

int main(void) {
    int64_t queue = ube_message_queue_create();
    void* first = ube_variant_from_long(10);
    void* second = ube_variant_from_long(20);
    if (queue == 0 || first == NULL || second == NULL) return 1;
    if (ube_message_queue_enqueue(queue, first) != 1) return 2;
    if (ube_message_queue_enqueue(queue, second) != 1) return 3;
    void* received = NULL;
    int32_t numeric = 0;
    if (ube_message_queue_dequeue(queue, &received, 0) != 1 ||
        !ube_variant_get_long(received, &numeric) || numeric != 10) return 4;
    if (ube_message_queue_dequeue(queue, &received, 0) != 1 ||
        !ube_variant_get_long(received, &numeric) || numeric != 20) return 5;
    void* unchanged = received;
    if (ube_message_queue_dequeue(queue, &received, 0) != 0 || received != unchanged) return 6;
    ube_err_clear();
    if (ube_message_queue_dequeue(queue, &received, -2) != 0 || ube_err_number() == 0) return 7;
    ube_message_queue_destroy(queue);

    struct wait_capture cancelled = { ube_message_queue_create(), 0, -1, -1 };
    int64_t cancelled_worker = ube_thread_start(wait_for_message, &cancelled, NULL);
    if (cancelled.queue == 0 || cancelled_worker == 0) return 8;
    wait_until_entered(&cancelled);
    if (!ube_thread_request_stop(cancelled_worker) ||
        !ube_thread_wait(cancelled_worker, 5000) ||
        cancelled.result != 0 || cancelled.error != 0) return 9;
    ube_message_queue_destroy(cancelled.queue);

    struct wait_capture unloaded = { ube_message_queue_create(), 0, -1, -1 };
    int64_t unloaded_worker = ube_thread_start(wait_for_message, &unloaded, NULL);
    if (unloaded.queue == 0 || unloaded_worker == 0) return 10;
    wait_until_entered(&unloaded);
    ube_message_queue_destroy(unloaded.queue);
    if (!ube_thread_wait(unloaded_worker, 5000) ||
        unloaded.result != 0 || unloaded.error != 91) return 11;
    puts("message queue probe passed");
    return 0;
}
