/* Synthetic regression: a denied callback-liveness event must not terminate GC. */
#include <windows.h>
#include <stdio.h>
static HANDLE denied_event(LPSECURITY_ATTRIBUTES security, BOOL manual, BOOL initial, LPCSTR name) {
    (void)security; (void)manual; (void)initial; (void)name;
    SetLastError(ERROR_NOT_ENOUGH_MEMORY);
    return NULL;
}
#define CreateEventA denied_event
#include "../../../../runtime/bootstrap_runtime.c"
#undef CreateEventA

/* Ordinary managed roots/objects do not require a callback source event. */
int main(void) {
    struct ube_gc_root root = {0};
    void* value = NULL;
    static const struct ube_gc_layout layout = {8,0,NULL,NULL};
    ube_err_set(77, "seed", "initialization probe");
    if (!ube_gc_root_enter(&root, &value) || !ube_value_new_object(&value, &layout) ||
        value == NULL || ube_err_number() != 77) return 1;
    if (!ube_component_begin_load(value, 51)) return 2;
    if (ube_component_finish_load(value, 1) != 0 || ube_err_number() != 7 ||
        ube_components != NULL || ube_active_event_sources != 0 ||
        ube_gc_header_from_value(value)->pin_count != 0) return 3;
    (void)ube_gc_root_leave(&root);
    value = NULL;
    (void)ube_gc_collect();
    if (ube_gc_root_count != 0 || ube_gc_live_allocation_bytes() != 0) return 4;
    puts("PASS managed initialization without callback event; source admission fails cleanly");
    return 0;
}
