/* Test-only hooks; the production runtime has no copy counters or callbacks. */
#include "../byte-storage/allocation-probe.h"
void probe_value_copy(size_t);
#define UBE_VALUE_OBSERVE_COPY(bytes) probe_value_copy(bytes)
