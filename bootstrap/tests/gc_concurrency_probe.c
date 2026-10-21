#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

typedef void (*ube_gc_finalizer)(void* value);
struct ube_gc_layout {
    size_t size;
    size_t slot_count;
    const size_t* slot_offsets;
    ube_gc_finalizer finalizer;
};
struct root_storage { void* next; void** slot; size_t slot_count; const size_t* slot_offsets; };
struct node { struct node* next; int32_t value; };

void* ube_gc_allocate(const struct ube_gc_layout* layout);
void* ube_gc_allocate_into(const struct ube_gc_layout* layout, void** slot);
int32_t ube_gc_collect(void);
int32_t ube_gc_root_enter(void* root_storage, void** slot);
int32_t ube_gc_root_leave(void* root_storage);
int32_t ube_gc_write_barrier(void* owner, void** slot, void* value);
size_t ube_gc_live_allocation_bytes(void);

static const size_t node_slots[] = { offsetof(struct node, next) };
static const struct ube_gc_layout node_layout = {
    sizeof(struct node), 1, node_slots, NULL
};

static DWORD WINAPI worker(void* context) {
    const intptr_t worker_id = (intptr_t)context;
    for (int32_t iteration = 0; iteration < 2000; ++iteration) {
        struct node* first = NULL;
        struct root_storage root = {0};
        if (!ube_gc_root_enter(&root, (void**)&first) ||
            ube_gc_allocate_into(&node_layout, (void**)&first) == NULL) return 20;
        struct node* second = NULL;
        struct root_storage second_root = {0};
        if (!ube_gc_root_enter(&second_root, (void**)&second) ||
            ube_gc_allocate_into(&node_layout, (void**)&second) == NULL ||
            !ube_gc_write_barrier(first, (void**)&first->next, second) ||
            !ube_gc_write_barrier(second, (void**)&second->next, first)) return 21;
        if (!ube_gc_root_leave(&second_root)) return 24;
        first->value = (int32_t)worker_id;
        second->value = iteration;
        if ((iteration & 31) == 0) (void)ube_gc_collect();
        if (first->next == NULL || first->next->value != iteration) return 22;
        if (!ube_gc_root_leave(&root)) return 23;
        first = NULL;
        second = NULL;
    }
    return 0;
}

int main(void) {
    enum { thread_count = 4 };
    HANDLE threads[thread_count];
    for (intptr_t index = 0; index < thread_count; ++index) {
        threads[index] = CreateThread(NULL, 0, worker, (void*)index, 0, NULL);
        if (threads[index] == NULL) return 10;
    }
    if (WaitForMultipleObjects(thread_count, threads, TRUE, INFINITE) != WAIT_OBJECT_0) return 11;
    for (int index = 0; index < thread_count; ++index) {
        DWORD result = 0;
        if (!GetExitCodeThread(threads[index], &result) || result != 0) return 12;
        CloseHandle(threads[index]);
    }
    (void)ube_gc_collect();
    (void)ube_gc_collect();
    if (ube_gc_live_allocation_bytes() != 0) return 13;
    puts("GC concurrency probe passed");
    return 0;
}
