/* Test-only observation after all worker joins and root releases. The included
   runtime is the exact identity checked by check-source-input.ps1. */
#include "../../../../runtime/bootstrap_runtime.c"
size_t source_test_root_count(void) { return ube_gc_root_count; }
