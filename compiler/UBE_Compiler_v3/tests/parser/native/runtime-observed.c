/* Includes the intact current runtime. Its root-count stores receive checked
   test-only callbacks in generated LLVM; production source is never rewritten. */
#include "../../../../../runtime/bootstrap_runtime.c"
size_t parser_root_count(void) { ube_gc_enter_lock(); size_t n=ube_gc_root_count; ube_gc_leave_lock(); return n; }
size_t parser_root_limit(void) { return UBE_GC_MAX_ROOTS; }
size_t parser_array_header_size(void) { return sizeof(struct ube_array); }
size_t parser_gc_header_size(void) { return sizeof(struct ube_gc_header); }
