#define _WIN32_WINNT 0x0602
#include <windows.h>
#include <stdint.h>
#include <stdio.h>

typedef struct { ULONG_PTR low, high, local; DWORD state, protect; int in_bounds; uint64_t reserved, committed, guarded, other; } Observation;
static void capture(Observation *out) {
    volatile unsigned char marker = 0;
    GetCurrentThreadStackLimits(&out->low, &out->high);
    out->local = (ULONG_PTR)&marker;
    out->in_bounds = out->low < out->local && out->local < out->high;
    MEMORY_BASIC_INFORMATION region = {0};
    if (!VirtualQuery((void *)out->low, &region, sizeof(region))) { out->in_bounds = 0; return; }
    out->state = region.State; out->protect = region.Protect;
    ULONG_PTR cursor = out->low;
    while (cursor < out->high) {
        if (!VirtualQuery((void *)cursor, &region, sizeof(region))) { out->in_bounds = 0; return; }
        ULONG_PTR start = (ULONG_PTR)region.BaseAddress;
        if (region.RegionSize > UINTPTR_MAX-start) { out->in_bounds = 0; return; }
        ULONG_PTR end = start + region.RegionSize;
        if (end <= cursor) { out->in_bounds = 0; return; }
        if (end > out->high) end = out->high;
        uint64_t length = (uint64_t)(end-cursor);
        if (region.State == MEM_RESERVE) out->reserved += length;
        else if (region.State == MEM_COMMIT && (region.Protect & PAGE_GUARD)) out->guarded += length;
        else if (region.State == MEM_COMMIT) out->committed += length;
        else out->other += length;
        cursor = end;
    }
    if (out->reserved + out->committed + out->guarded + out->other != (uint64_t)(out->high-out->low)) out->in_bounds = 0;
}
__declspec(noinline) static void capture_deep(Observation *out) {
    volatile unsigned char frame[48 * 1024];
    volatile size_t step = 4096;
    for (size_t i = 0; i < sizeof(frame); i += step) frame[i] = (unsigned char)i;
    capture(out);
    if (frame[0] != 0) out->in_bounds = 0;
}
typedef struct { Observation shallow, deep; } WorkerObservations;
static DWORD WINAPI worker(void *value) {
    WorkerObservations *observations = (WorkerObservations *)value;
    capture(&observations->shallow);
    capture_deep(&observations->deep);
    return 0;
}
int main(void) {
    Observation main_observation = {0}; WorkerObservations worker_observation = {0};
    capture(&main_observation);
    HANDLE thread = CreateThread(NULL, 128 * 1024, worker, &worker_observation,
                                 STACK_SIZE_PARAM_IS_A_RESERVATION, NULL);
    if (!thread) return 2;
    DWORD wait = WaitForSingleObject(thread, 10000), status = 1;
    BOOL observed = GetExitCodeThread(thread, &status);
    CloseHandle(thread);
    if (wait != WAIT_OBJECT_0 || !observed || status != 0) return 3;
#ifdef WRONG_BOUNDS_CONTROL
    worker_observation.shallow.low = worker_observation.shallow.high;
    worker_observation.shallow.in_bounds = worker_observation.shallow.low < worker_observation.shallow.local &&
                                          worker_observation.shallow.local < worker_observation.shallow.high;
#endif
    if (!main_observation.in_bounds || !worker_observation.shallow.in_bounds ||
        !worker_observation.deep.in_bounds || main_observation.local == worker_observation.shallow.local ||
        worker_observation.shallow.high != worker_observation.deep.high ||
        worker_observation.shallow.local <= worker_observation.deep.local ||
        worker_observation.shallow.local - worker_observation.deep.local < 48 * 1024) return 1;
    puts("main and worker local addresses lie within their reported bounds");
    if (main_observation.state == MEM_RESERVE) puts("main lower-bound page reserved");
    else if (main_observation.state == MEM_COMMIT && (main_observation.protect & PAGE_GUARD)) puts("main lower-bound page guarded");
    else if (main_observation.state == MEM_COMMIT) puts("main lower-bound page committed");
    else puts("main lower-bound page other");
    printf("main regions reserved=%llu committed=%llu guarded=%llu other=%llu\n",
           (unsigned long long)main_observation.reserved, (unsigned long long)main_observation.committed,
           (unsigned long long)main_observation.guarded, (unsigned long long)main_observation.other);
    puts(worker_observation.shallow.low == worker_observation.deep.low ?
         "worker lower bound unchanged" : "worker lower bound changed");
    if (worker_observation.shallow.state == MEM_RESERVE) puts("worker lower-bound page reserved");
    else if (worker_observation.shallow.state == MEM_COMMIT && (worker_observation.shallow.protect & PAGE_GUARD)) puts("worker lower-bound page guarded");
    else if (worker_observation.shallow.state == MEM_COMMIT) puts("worker lower-bound page committed");
    else puts("worker lower-bound page other");
    printf("worker regions reserved=%llu committed=%llu guarded=%llu other=%llu\n",
           (unsigned long long)worker_observation.shallow.reserved, (unsigned long long)worker_observation.shallow.committed,
           (unsigned long long)worker_observation.shallow.guarded, (unsigned long long)worker_observation.shallow.other);
    return 0;
}
