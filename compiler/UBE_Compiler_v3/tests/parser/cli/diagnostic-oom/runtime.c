/* Observe the complete production runtime without replacing its root behavior. */
#include "../../../../../../runtime/bootstrap_runtime.c"

/* Read real registry state under its ordinary lock, never a synthetic counter. */
size_t diagnostic_root_count(void) {
    ube_gc_enter_lock();
    size_t result=ube_gc_root_count;
    ube_gc_leave_lock();
    return result;
}

/* Expose the actual production admission limit to the bounded test driver. */
size_t diagnostic_root_limit(void) { return UBE_GC_MAX_ROOTS; }

static struct ube_error_state diagnostic_saved_error;

/* Snapshot every fixed-buffer error field without allocating managed Strings. */
void diagnostic_capture_error(void) {
    memcpy(&diagnostic_saved_error,ube_current_error_state(),sizeof(diagnostic_saved_error));
}

/* Include the revision and full text buffers in preservation assertions. */
int32_t diagnostic_error_unchanged(void) {
    return memcmp(&diagnostic_saved_error,ube_current_error_state(),sizeof(diagnostic_saved_error))==0;
}
