#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <limits.h>

extern void ube_err_set(int32_t, const char *, const char *);
extern int32_t ube_err_number(void);
extern void ube_err_clear(void);
extern int16_t probe_remainder_i16(int16_t, int16_t);
extern int32_t probe_remainder_i32(int32_t, int32_t);
extern int64_t probe_remainder_i64(int64_t, int64_t);

typedef struct { HANDLE ready, start, done, release; int mode; } Work;
static DWORD WINAPI worker(void *argument) {
    Work *work = (Work *)argument;
    ube_err_clear();
    if (ube_err_number() != 0 || !SetEvent(work->ready) || WaitForSingleObject(work->start, 5000) != WAIT_OBJECT_0) return 1;
    if (work->mode == 0) {
        ube_err_set(77, "seed", "test");
        if (probe_remainder_i16(INT16_MIN, -1) != 0 || probe_remainder_i32(INT32_MIN, -1) != 0 ||
            probe_remainder_i64(INT64_MIN, -1) != 0 || ube_err_number() != 77) return 2;
    } else {
        ube_err_set(55, "seed", "test");
        if (probe_remainder_i16(3, 0) != 0 || ube_err_number() != 11) return 3;
        ube_err_set(55, "seed", "test");
        if (probe_remainder_i32(3, 0) != 0 || ube_err_number() != 11) return 4;
        ube_err_set(55, "seed", "test");
        if (probe_remainder_i64(3, 0) != 0 || ube_err_number() != 11) return 5;
    }
    if (!SetEvent(work->done) || WaitForSingleObject(work->release, 5000) != WAIT_OBJECT_0) return 6;
#ifdef WRONG_THREAD_CONTROL
    int32_t expected = work->mode == 0 ? 99 : 11;
#else
    int32_t expected = work->mode == 0 ? 77 : 11;
#endif
    if (ube_err_number() != expected) return 7;
    ube_err_clear();
    return ube_err_number() == 0 ? 0 : 8;
}

int main(void) {
    ube_err_clear(); ube_err_set(99, "main", "test");
    for (int order = 0; order != 2; ++order) {
        Work work[2] = {{0}}; HANDLE threads[2] = {NULL, NULL};
        HANDLE start = CreateEventW(NULL, TRUE, FALSE, NULL), release = CreateEventW(NULL, TRUE, FALSE, NULL);
        int result = 1;
        if (!start || !release) return 1;
        for (int i = 0; i != 2; ++i) {
            work[i].ready = CreateEventW(NULL, TRUE, FALSE, NULL);
            work[i].done = CreateEventW(NULL, TRUE, FALSE, NULL);
            work[i].start = start; work[i].release = release; work[i].mode = i;
            if (!work[i].ready || !work[i].done) goto cleanup;
        }
        for (int n = 0; n != 2; ++n) {
            int i = order ? 1-n : n;
            threads[i] = CreateThread(NULL, 0, worker, &work[i], 0, NULL);
            if (!threads[i] || WaitForSingleObject(work[i].ready, 5000) != WAIT_OBJECT_0) goto cleanup;
        }
        if (!SetEvent(start)) goto cleanup;
        for (int i = 0; i != 2; ++i)
            if (WaitForSingleObject(work[i].done, 5000) != WAIT_OBJECT_0) goto cleanup;
        if (ube_err_number() != 99 || !SetEvent(release)) goto cleanup;
        for (int i = 0; i != 2; ++i) {
            DWORD status = 1;
            if (WaitForSingleObject(threads[i], 5000) != WAIT_OBJECT_0 ||
                !GetExitCodeThread(threads[i], &status) || status != 0) goto cleanup;
        }
        result = 0;
cleanup:
        SetEvent(start); SetEvent(release);
        for (int i = 0; i != 2; ++i) {
            if (threads[i]) { WaitForSingleObject(threads[i], 5000); CloseHandle(threads[i]); }
            if (work[i].ready) CloseHandle(work[i].ready);
            if (work[i].done) CloseHandle(work[i].done);
        }
        CloseHandle(start); CloseHandle(release);
        if (result) return 1;
    }
    if (ube_err_number() != 99) return 1;
    ube_err_clear();
    if (ube_err_number() != 0) return 1;
    puts("three-width remainder and overlapping thread-local Err passed in both launch orders");
    return 0;
}
