#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

extern void ube_err_set(int32_t, const char *, const char *);
extern int32_t ube_err_number(void);
extern void ube_err_clear(void);
extern int64_t ube_checked_mod_i64(int64_t, int64_t);
extern int64_t ube_checked_div_i64(int64_t, int64_t);
#ifdef UBE_LLVM_REMAINDER
extern int16_t probe_remainder_i16(int16_t, int16_t);
extern int32_t probe_remainder_i32(int32_t, int32_t);
extern int64_t probe_remainder_i64(int64_t, int64_t);
#endif

struct worker { HANDLE ready, release, arrived, proceed; int failure, overlap; int32_t before, after, after_barrier, bridge_error; int64_t result, bridge_result; int bridge_ok; };
static DWORD WINAPI run_worker(void *arg) {
    struct worker *w = arg;
    ube_err_clear();
    ube_err_set(w->failure ? 31 : 32, "seed", "test");
    w->before = ube_err_number();
    if (!SetEvent(w->ready) || WaitForSingleObject(w->release, 10000) != WAIT_OBJECT_0) return 1;
    if (w->failure) w->result = ube_checked_div_i64(1, 0);
#ifdef UBE_LLVM_REMAINDER
    else w->result = probe_remainder_i64(INT64_MIN, -1);
#else
    else w->result = ube_checked_mod_i64(INT64_MIN, -1);
#endif
    w->after = ube_err_number();
    if (w->overlap) {
        if (!SetEvent(w->arrived) || WaitForSingleObject(w->proceed, 10000) != WAIT_OBJECT_0) return 2;
        w->after_barrier = ube_err_number();
    }
#ifdef UBE_LLVM_REMAINDER
    if (!w->failure) {
        w->bridge_ok = probe_remainder_i16(INT16_MIN, -1) == 0 && ube_err_number() == 32 &&
                       probe_remainder_i32(INT32_MIN, -1) == 0 && ube_err_number() == 32;
        w->bridge_ok = w->bridge_ok && probe_remainder_i16(-17, 5) == -2 && probe_remainder_i16(17, -5) == 2 && probe_remainder_i16(-17, -5) == -2 &&
                       probe_remainder_i32(-17, 5) == -2 && probe_remainder_i32(17, -5) == 2 && probe_remainder_i32(-17, -5) == -2 &&
                       probe_remainder_i64(-17, 5) == -2 && probe_remainder_i64(17, -5) == 2 && probe_remainder_i64(-17, -5) == -2 && ube_err_number() == 32;
        w->bridge_result = probe_remainder_i64(1, 0); w->bridge_error = ube_err_number();
        ube_err_set(32, "seed", "test");
        w->bridge_ok = w->bridge_ok && probe_remainder_i16(1, 0) == 0 && ube_err_number() == 11;
        ube_err_set(32, "seed", "test");
        w->bridge_ok = w->bridge_ok && probe_remainder_i32(1, 0) == 0 && ube_err_number() == 11;
    }
#endif
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 2 || (argc == 2 && strcmp(argv[1], "reverse") != 0 && strcmp(argv[1], "overlap") != 0)) return 2;
    int overlap = argc == 2 && strcmp(argv[1], "overlap") == 0;
    int first = argc == 2 && !overlap ? 1 : 0, second = 1 - first;
    struct worker w[2] = {0}; HANDLE threads[2] = {NULL, NULL}; int result = 1;
    ube_err_clear(); ube_err_set(77, "main", "test");
    for (int i = 0; i < 2; ++i) {
        w[i].failure = i == 0;
        w[i].overlap = overlap;
        w[i].ready = CreateEventW(NULL, TRUE, FALSE, NULL);
        w[i].release = CreateEventW(NULL, TRUE, FALSE, NULL);
        w[i].arrived = CreateEventW(NULL, TRUE, FALSE, NULL);
        w[i].proceed = CreateEventW(NULL, TRUE, FALSE, NULL);
        if (!w[i].ready || !w[i].release || !w[i].arrived || !w[i].proceed) goto cleanup;
        threads[i] = CreateThread(NULL, 0, run_worker, &w[i], 0, NULL);
        if (!threads[i]) goto cleanup;
    }
    if (WaitForSingleObject(w[0].ready, 10000) != WAIT_OBJECT_0 || WaitForSingleObject(w[1].ready, 10000) != WAIT_OBJECT_0 || ube_err_number() != 77) goto cleanup;
    if (overlap) {
        if (!SetEvent(w[0].release) || !SetEvent(w[1].release) ||
            WaitForSingleObject(w[0].arrived, 10000) != WAIT_OBJECT_0 || WaitForSingleObject(w[1].arrived, 10000) != WAIT_OBJECT_0 ||
            ube_err_number() != 77 || !SetEvent(w[0].proceed) || !SetEvent(w[1].proceed) ||
            WaitForMultipleObjects(2, threads, TRUE, 10000) != WAIT_OBJECT_0) goto cleanup;
    } else if (!SetEvent(w[first].release) || WaitForSingleObject(threads[first], 10000) != WAIT_OBJECT_0 ||
               WaitForSingleObject(threads[second], 0) != WAIT_TIMEOUT || !SetEvent(w[second].release) ||
               WaitForSingleObject(threads[second], 10000) != WAIT_OBJECT_0) goto cleanup;
    DWORD e0 = 0, e1 = 0;
    if (!GetExitCodeThread(threads[0], &e0) || !GetExitCodeThread(threads[1], &e1) || e0 || e1) goto cleanup;
    if (w[0].before != 31 || w[0].after != 11 || w[0].result != 0 ||
        w[1].before != 32 || w[1].after != 32 || w[1].result != 0 || ube_err_number() != 77) goto cleanup;
    if (overlap && (w[0].after_barrier != 11 || w[1].after_barrier != 32)) goto cleanup;
#ifdef UBE_LLVM_REMAINDER
    if (w[1].bridge_result != 0 || w[1].bridge_error != 11 || !w[1].bridge_ok) goto cleanup;
#endif
#ifdef WRONG_THREAD_EXPECTATION
    if (w[1].after != 31) goto cleanup;
#endif
    ube_err_clear();
    if (ube_err_number() != 0) goto cleanup;
    puts("thread-local error observer and guarded arithmetic passed"); result = 0;
cleanup:
    for (int i = 0; i < 2; ++i) if (w[i].release) SetEvent(w[i].release);
    for (int i = 0; i < 2; ++i) if (w[i].proceed) SetEvent(w[i].proceed);
    for (int i = 0; i < 2; ++i) {
        if (threads[i]) { WaitForSingleObject(threads[i], 10000); CloseHandle(threads[i]); }
        if (w[i].ready) CloseHandle(w[i].ready);
        if (w[i].release) CloseHandle(w[i].release);
        if (w[i].arrived) CloseHandle(w[i].arrived);
        if (w[i].proceed) CloseHandle(w[i].proceed);
    }
    return result;
}
