/* This complete include is compiled unchanged, then test-only LLVM root-count
   stores receive observation calls. The runner verifies the original identity,
   global type and every transformed store before linking native probes. */
#include "../../../../../runtime/bootstrap_runtime.c"
size_t parser_probe_root_count(void) { ube_gc_enter_lock(); size_t n=ube_gc_root_count; ube_gc_leave_lock(); return n; }
size_t parser_probe_max_roots(void) { return UBE_GC_MAX_ROOTS; }
size_t parser_probe_array_header_size(void) { return sizeof(struct ube_array); }
size_t parser_probe_gc_header_size(void) { return sizeof(struct ube_gc_header); }
