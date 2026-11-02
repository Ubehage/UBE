#include <stdbool.h>
struct observations {bool active;size_t allocations,requested,zeroed,copied,roots_before,root_peak,heap_events,steps,operations;};
static _Thread_local struct observations observed;
extern size_t storage_root_count(void),storage_root_limit(void);
void storage_root_changed(size_t n){if(observed.active&&n>observed.root_peak)observed.root_peak=n;}
void storage_heap_changed(size_t n){(void)n;if(observed.active)++observed.heap_events;}
static void allocation(size_t n){if(observed.active){++observed.allocations;observed.requested+=n;}}
void* probe_malloc(size_t n){allocation(n);return malloc(n);}
void* probe_calloc(size_t n,size_t size){if(size&&n>SIZE_MAX/size)return NULL;allocation(n*size);void* p=calloc(n,size);if(observed.active&&p)observed.zeroed+=n*size;return p;}
void* probe_realloc(void* old,size_t n){allocation(n);return realloc(old,n);}
void probe_free(void* p){free(p);}
void probe_value_copy(size_t n){if(observed.active)observed.copied+=n;}
void capacity_step(void){if(observed.active)++observed.steps;}
#define BINARY_OPERATION(name,width,type) extern type ube_checked_##name##_##width(type,type);type scalar_checked_##name##_##width(type a,type b){if(observed.active)++observed.operations;return ube_checked_##name##_##width(a,b);}
#define UNARY_OPERATION(width,type) extern type ube_checked_neg_##width(type);type scalar_checked_neg_##width(type n){if(observed.active)++observed.operations;return ube_checked_neg_##width(n);}
BINARY_OPERATION(add,i32,int32_t) BINARY_OPERATION(sub,i32,int32_t) BINARY_OPERATION(mul,i32,int32_t) BINARY_OPERATION(div,i32,int32_t) BINARY_OPERATION(mod,i32,int32_t) UNARY_OPERATION(i32,int32_t)
BINARY_OPERATION(add,i64,int64_t) BINARY_OPERATION(sub,i64,int64_t) BINARY_OPERATION(mul,i64,int64_t) BINARY_OPERATION(div,i64,int64_t) BINARY_OPERATION(mod,i64,int64_t) UNARY_OPERATION(i64,int64_t)
extern int64_t ube_checked_narrow_i64(int64_t,int32_t,int32_t);
int64_t scalar_checked_narrow_i64(int64_t n,int32_t bits,int32_t unsign){if(observed.active)++observed.operations;return ube_checked_narrow_i64(n,bits,unsign);}
static void observation_start(void){observed=(struct observations){.active=true};observed.roots_before=storage_root_count();observed.root_peak=observed.roots_before;}
static void observation_stop(void){observed.active=false;}
