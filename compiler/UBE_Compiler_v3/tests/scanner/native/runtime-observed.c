/* Test-only hooks around the exact source identity selected by the gate. */
#include "../../../../../runtime/bootstrap_runtime.c"
size_t scanner_test_root_count(void) { return ube_gc_root_count; }
size_t scanner_test_max_roots(void) { return UBE_GC_MAX_ROOTS; }
size_t scanner_test_array_header_size(void) { return sizeof(struct ube_array); }
size_t scanner_test_gc_header_size(void) { return sizeof(struct ube_gc_header); }
