#include <stdint.h>
#include <stdio.h>
#include <windows.h>

typedef void (*ube_gc_finalizer)(void* value);

struct ube_gc_layout {
    size_t size;
    size_t slot_count;
    const size_t* slot_offsets;
    ube_gc_finalizer finalizer;
};

void* ube_gc_allocate(const struct ube_gc_layout* layout);
int32_t ube_gc_collect(void);
int32_t ube_monitor_enter(void* value);
void ube_monitor_exit(void* value);
int32_t ube_err_number(void);
void ube_err_clear(void);

struct worker_state {
    void* object;
    HANDLE started;
    HANDLE acquired;
};

static DWORD WINAPI enter_worker(LPVOID raw_state) {
    struct worker_state* state = raw_state;
    SetEvent(state->started);
    if (!ube_monitor_enter(state->object)) return 1;
    SetEvent(state->acquired);
    ube_monitor_exit(state->object);
    return 0;
}

int main(void) {
    static const struct ube_gc_layout layout = {sizeof(int64_t), 0u, NULL, NULL};
    void* object = ube_gc_allocate(&layout);
    if (object == NULL) return 1;
    if (!ube_monitor_enter(object) || !ube_monitor_enter(object)) return 2;

    struct worker_state state = {
        object,
        CreateEventA(NULL, TRUE, FALSE, NULL),
        CreateEventA(NULL, TRUE, FALSE, NULL)
    };
    if (state.started == NULL || state.acquired == NULL) return 3;
    HANDLE worker = CreateThread(NULL, 0, enter_worker, &state, 0, NULL);
    if (worker == NULL) return 4;
    if (WaitForSingleObject(state.started, 5000) != WAIT_OBJECT_0) return 5;
    if (WaitForSingleObject(state.acquired, 20) != WAIT_TIMEOUT) return 6;
    if (ube_gc_collect() != 0) return 7;

    ube_monitor_exit(object);
    if (WaitForSingleObject(state.acquired, 20) != WAIT_TIMEOUT) return 8;
    ube_monitor_exit(object);
    if (WaitForSingleObject(state.acquired, 5000) != WAIT_OBJECT_0) return 9;
    if (WaitForSingleObject(worker, 5000) != WAIT_OBJECT_0) return 10;

    CloseHandle(worker);
    CloseHandle(state.acquired);
    CloseHandle(state.started);
    if (ube_gc_collect() != 1) return 11;

    ube_err_clear();
    if (ube_monitor_enter(NULL) != 0 || ube_err_number() != 91) return 12;
    puts("monitor probe passed");
    return 0;
}
