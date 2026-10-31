/* Bootstrap Windows adapter over existing thread/TLS mechanisms. Included by
   bootstrap_runtime.c; contract: ../../THREADS-CONTRACT.md. No scheduling policy. */
_Static_assert(sizeof(uint8_t) == 1, "UBE Boolean output storage");
_Static_assert(sizeof(int64_t) == 8, "UBE LongLong thread identity");

/* Every native call records new failures in this thread's fixed error state. */
static int ube_thread_status_unchanged(uint64_t revision) {
    return ube_current_error_state()->revision == revision;
}

/* Reject invalid borrowed output storage before invoking any operation. */
static int ube_thread_output_valid(const void* output) {
    if (output != NULL) return 1;
    ube_err_set(5, "thread output storage is unavailable", "UBECore.Threads");
    return 0;
}

/* Publish a positive identity only after native registration succeeds. */
int32_t ube_thread_try_current_id(int64_t* output) {
    if (!ube_thread_output_valid(output)) return 0;
    const uint64_t revision = ube_current_error_state()->revision;
    const int64_t id = ube_thread_current_id();
    if (!ube_thread_status_unchanged(revision)) return 0;
    if (id <= 0) {
        ube_err_set(7, "thread identity admission failed", "UBECore.Threads");
        return 0;
    }
    __atomic_store_n(output, id, __ATOMIC_SEQ_CST);
    return 1;
}

/* Completed issued IDs are successful observations with a false value. */
int32_t ube_thread_try_is_alive(int64_t id, uint8_t* output) {
    if (!ube_thread_output_valid(output)) return 0;
    const uint64_t revision = ube_current_error_state()->revision;
    const bool alive = ube_thread_is_alive(id);
    if (!ube_thread_status_unchanged(revision)) return 0;
    __atomic_store_n(output, (uint8_t)(alive ? 1 : 0), __ATOMIC_SEQ_CST);
    return 1;
}

/* Preserve output on failure; successful requests remain sticky. */
int32_t ube_thread_try_request_stop(int64_t id, uint8_t* output) {
    if (!ube_thread_output_valid(output)) return 0;
    const uint64_t revision = ube_current_error_state()->revision;
    const int32_t requested = ube_thread_request_stop(id);
    if (!ube_thread_status_unchanged(revision)) return 0;
    __atomic_store_n(output, (uint8_t)(requested != 0 ? 1 : 0), __ATOMIC_SEQ_CST);
    return 1;
}

/* Read only the current worker's stop state without clearing it. */
int32_t ube_thread_try_stop_requested(uint8_t* output) {
    if (!ube_thread_output_valid(output)) return 0;
    const uint64_t revision = ube_current_error_state()->revision;
    const bool requested = ube_thread_stop_requested();
    if (!ube_thread_status_unchanged(revision)) return 0;
    __atomic_store_n(output, (uint8_t)(requested ? 1 : 0), __ATOMIC_SEQ_CST);
    return 1;
}

/* Timeout/interruption is fresh success with Completed=False, never cleanup. */
int32_t ube_thread_try_wait(int64_t id, int64_t timeout, uint8_t* output) {
    if (!ube_thread_output_valid(output)) return 0;
    const uint64_t revision = ube_current_error_state()->revision;
    const int32_t completed = ube_thread_wait(id, timeout);
    if (!ube_thread_status_unchanged(revision)) return 0;
    __atomic_store_n(output, (uint8_t)(completed != 0 ? 1 : 0), __ATOMIC_SEQ_CST);
    return 1;
}

/* A scheduling hint does not require another runnable thread. */
int32_t ube_thread_try_yield(void) {
    const uint64_t revision = ube_current_error_state()->revision;
    ube_thread_yield();
    return ube_thread_status_unchanged(revision);
}
