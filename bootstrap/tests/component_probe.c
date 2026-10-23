#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <windows.h>

typedef void (*ube_gc_finalizer)(void* value);
typedef void (*ube_event_callback)(void* receiver, void* arguments);

struct ube_gc_layout {
    size_t size;
    size_t slot_count;
    const size_t* slot_offsets;
    ube_gc_finalizer finalizer;
};

struct root_storage {
    void* next;
    void** slot;
    size_t slot_count;
    const size_t* slot_offsets;
};

void* ube_object_allocate(const struct ube_gc_layout* layout);
int32_t ube_gc_publish(void* value);
int32_t ube_gc_root_enter(void* root_storage, void** slot);
int32_t ube_gc_root_leave(void* root_storage);
int32_t ube_component_begin_load(void* value, int32_t kind);
int32_t ube_component_attach_parent(void* child, void* parent);
int32_t ube_component_finish_load(void* value, int32_t succeeded);
int32_t ube_component_enter_call(void* value);
void ube_component_leave_call(void* value);
int32_t ube_component_accept_unload(void* value);
int32_t ube_event_connect(void* receiver, int64_t field_id, void* source,
                          int64_t event_id, ube_event_callback callback);
int32_t ube_event_dispatch(void* source, int64_t event_id, void* arguments);
void ube_event_test_fail_snapshots(uint32_t count);
void ube_thread_program_wait(void);
int32_t ube_err_number(void);
void ube_err_set(int32_t number, const char* description, const char* source);
void ube_err_clear(void);

static int callback_count;
static int recursive_callback_count;
static int recursive_failure_seen;
static void* recursive_source;

static void count_callback(void* receiver, void* arguments) {
    (void)receiver;
    (void)arguments;
    ++callback_count;
}

static void recursive_callback(void* receiver, void* arguments) {
    (void)receiver;
    (void)arguments;
    ++recursive_callback_count;
    if (!ube_event_dispatch(recursive_source, 3, NULL)) {
        recursive_failure_seen = 1;
    }
}

static DWORD WINAPI program_wait_worker(void* unused) {
    (void)unused;
    ube_thread_program_wait();
    return 0;
}

int main(void) {
    static const struct ube_gc_layout layout = { sizeof(int64_t), 0, NULL, NULL };
    void* component = ube_object_allocate(&layout);
    void* alias = component;
    struct root_storage component_root = {0};
    struct root_storage alias_root = {0};
    if (component == NULL || !ube_gc_publish(component)) return 10;
    if (!ube_gc_root_enter(&component_root, &component) ||
        !ube_gc_root_enter(&alias_root, &alias)) return 11;
    ube_err_set(17, "preserved", "component-probe");
    if (ube_component_begin_load(component, 51) != 1) return 12;
    if (!ube_component_finish_load(component, 1) || ube_err_number() != 17) return 35;
    ube_err_clear();
    void* child = ube_object_allocate(&layout);
    if (child == NULL || !ube_gc_publish(child)) return 27;
    ube_err_clear();
    if (ube_component_begin_load(child, 52) != 0 || ube_err_number() != 91) return 28;
    ube_err_clear();
    if (!ube_component_attach_parent(child, component) ||
        ube_component_begin_load(child, 52) != 1) return 29;
    if (!ube_component_finish_load(child, 1)) return 36;
    if (!ube_component_accept_unload(child)) return 30;
    void* retry = ube_object_allocate(&layout);
    if (retry == NULL || !ube_gc_publish(retry)) return 31;
    if (ube_component_begin_load(retry, 51) != 1) return 32;
    if (ube_component_finish_load(retry, 0)) return 37;
    if (ube_component_begin_load(retry, 51) != 1) return 33;
    ube_err_set(5, "synthetic load-hook failure", "component-probe");
    if (ube_component_finish_load(retry, 1)) return 38;
    ube_err_clear();
    if (ube_component_begin_load(retry, 51) != 1 ||
        !ube_component_finish_load(retry, 1)) return 39;
    if (!ube_component_accept_unload(retry)) return 34;
    HANDLE program_waiter = CreateThread(NULL, 0, program_wait_worker, NULL, 0, NULL);
    if (program_waiter == NULL ||
        WaitForSingleObject(program_waiter, 20) != WAIT_TIMEOUT) return 25;
    if (!ube_event_connect(NULL, 1, component, 2, count_callback)) return 13;
    if (!ube_event_dispatch(component, 2, NULL) || callback_count != 1) return 14;
    ube_event_test_fail_snapshots(1);
    ube_err_clear();
    if (ube_event_dispatch(component, 2, NULL) != 0 || callback_count != 1 ||
        ube_err_number() != 7) return 22;
    ube_err_clear();
    recursive_source = component;
    if (!ube_event_connect(NULL, 2, component, 3, recursive_callback)) return 23;
    if (!ube_event_dispatch(component, 3, NULL) || !recursive_failure_seen ||
        recursive_callback_count != 128 || ube_err_number() != 28) return 24;
    ube_err_clear();
    if (!ube_component_enter_call(component)) return 15;

    void* identity = component;
    if (!ube_component_accept_unload(identity)) return 16;
    if (component == NULL || alias == NULL) return 17;
    if (ube_component_enter_call(identity) != 0 || ube_err_number() != 91) return 18;
    ube_err_clear();
    if (ube_event_dispatch(identity, 2, NULL) != 0 || callback_count != 1 ||
        ube_err_number() != 91) return 19;
    ube_err_clear();

    ube_component_leave_call(identity);
    if (component != NULL || alias != NULL) return 20;
    if (WaitForSingleObject(program_waiter, 5000) != WAIT_OBJECT_0) return 26;
    CloseHandle(program_waiter);
    if (!ube_gc_root_leave(&alias_root) || !ube_gc_root_leave(&component_root)) return 21;
    puts("component probe passed");
    return 0;
}
