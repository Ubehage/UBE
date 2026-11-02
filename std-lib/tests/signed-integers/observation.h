/* Test-only actual runtime events. Callbacks use only bounded TLS/scalar state. */
#include <stdbool.h>
struct numeric_observations {
 bool active;size_t allocations,requested,zeroed,copies,byte_reads,read_calls,machine_calls;
 size_t roots_before,root_peak,heap_before,heap_peak,heap_events,heap_callback_peak;
};
static _Thread_local struct numeric_observations observed;
extern size_t index_root_count(void),index_root_limit(void),index_array_header(void),index_gc_header(void);
extern int32_t numeric_layout_role(const struct ube_value_layout*);
void index_root_changed(size_t count){if(observed.active&&count>observed.root_peak)observed.root_peak=count;}
void name_heap_changed(size_t bytes){if(observed.active){++observed.heap_events;
#ifdef NEGATIVE_NUMERIC_HEAP
 bytes=SIZE_MAX/2;
#endif
 if(bytes>observed.heap_callback_peak)observed.heap_callback_peak=bytes;if(bytes>observed.heap_peak)observed.heap_peak=bytes;}}
void* probe_malloc(size_t bytes){if(observed.active){++observed.allocations;observed.requested+=bytes;}return malloc(bytes);}
void* probe_calloc(size_t count,size_t bytes){if(bytes&&count>SIZE_MAX/bytes)return NULL;if(observed.active){++observed.allocations;observed.requested+=count*bytes;}void* value=calloc(count,bytes);if(observed.active&&value)observed.zeroed+=count*bytes;return value;}
void* probe_realloc(void* old,size_t bytes){if(observed.active){++observed.allocations;observed.requested+=bytes;}return realloc(old,bytes);}
void probe_free(void* value){free(value);}
void probe_value_copy(size_t bytes){if(observed.active)observed.copies+=bytes;}
void numeric_read_event(void){if(observed.active)++observed.read_calls;}
void* numeric_runtime_element(void*const* holder,int32_t index,void** keep,void* fallback,const struct ube_value_layout* layout){if(observed.active&&numeric_layout_role(layout)==1)++observed.byte_reads;return ube_value_array_element(holder,index,keep,fallback,layout);}
#define BINARY_OBSERVER(name,width,type) extern type ube_checked_##name##_##width(type,type);type numeric_checked_##name##_##width(type left,type right){if(observed.active)++observed.machine_calls;return ube_checked_##name##_##width(left,right);}
#define UNARY_OBSERVER(width,type) extern type ube_checked_neg_##width(type);type numeric_checked_neg_##width(type value){if(observed.active)++observed.machine_calls;return ube_checked_neg_##width(value);}
BINARY_OBSERVER(add,i32,int32_t) BINARY_OBSERVER(sub,i32,int32_t) BINARY_OBSERVER(mul,i32,int32_t) BINARY_OBSERVER(div,i32,int32_t) BINARY_OBSERVER(mod,i32,int32_t) UNARY_OBSERVER(i32,int32_t)
BINARY_OBSERVER(add,i64,int64_t) BINARY_OBSERVER(sub,i64,int64_t) BINARY_OBSERVER(mul,i64,int64_t) BINARY_OBSERVER(div,i64,int64_t) BINARY_OBSERVER(mod,i64,int64_t) UNARY_OBSERVER(i64,int64_t)
static void numeric_start(void){observed=(struct numeric_observations){.active=true};observed.roots_before=index_root_count();observed.root_peak=observed.roots_before;observed.heap_before=ube_gc_live_allocation_bytes();observed.heap_peak=observed.heap_before;}
static void numeric_pause(void){observed.active=false;}
static int numeric_stop(int32_t expected_reads,int scalar,size_t maximum_operations){
 numeric_pause();
#ifdef NEGATIVE_NUMERIC_COUNTER
 if(!scalar)++observed.byte_reads;
#endif
#ifdef NEGATIVE_NUMERIC_OPERATIONS
 observed.machine_calls+=1000000;
#endif
 CHECK(observed.allocations==0&&observed.requested==0&&observed.zeroed==0&&observed.copies==0);
 CHECK(observed.byte_reads==observed.read_calls&&observed.machine_calls<=maximum_operations);
 if(expected_reads>=0)CHECK(observed.byte_reads==(size_t)expected_reads);
 CHECK(observed.root_peak-observed.roots_before<=(scalar?0u:16u));
 CHECK(observed.heap_events==0&&observed.heap_peak==observed.heap_before);
 return 0;
}
