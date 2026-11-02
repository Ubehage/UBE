#include <stdbool.h>
struct observations {bool active;int copy_class;size_t allocations,requested,zeroed,fail_at,publication,other,byte_copied,roots_before,root_peak,gc_before,gc_peak,heap_events,byte_reads,key_reads,long_accesses,events[5];};
static _Thread_local struct observations observed;
extern size_t storage_root_count(void),storage_root_limit(void),storage_array_header(void),storage_gc_header(void);
extern int32_t byte_key_role(const struct ube_value_layout*);
void storage_root_changed(size_t n){if(observed.active&&n>observed.root_peak)observed.root_peak=n;}
void storage_heap_changed(size_t n){if(observed.active){++observed.heap_events;
#ifdef NEGATIVE_ORDER_HEAP
 n=SIZE_MAX/2;
#endif
 if(n>observed.gc_peak)observed.gc_peak=n;}}
static bool denied(size_t n){if(!observed.active)return false;++observed.allocations;observed.requested+=n;return observed.fail_at&&observed.allocations>=observed.fail_at;}
void* probe_malloc(size_t n){if(denied(n))return NULL;return malloc(n);}
void* probe_calloc(size_t n,size_t size){if(size&&n>SIZE_MAX/size)return NULL;if(denied(n*size))return NULL;void* p=calloc(n,size);if(observed.active&&p)observed.zeroed+=n*size;return p;}
void* probe_realloc(void* old,size_t n){if(denied(n))return NULL;return realloc(old,n);}
void probe_free(void* p){free(p);}
void probe_value_copy(size_t n){if(!observed.active)return;if(n==1)observed.byte_copied+=n;if(observed.copy_class==3)observed.publication+=n;else observed.other+=n;}
void byte_key_event(int32_t event){if(observed.active&&event>0&&event<5)++observed.events[event];}
int32_t byte_key_resize(void** holder,int32_t n,const struct ube_value_layout* layout,int32_t keep){return ube_value_try_resize(holder,n,layout,keep);}
int32_t byte_key_assign(void* destination,const void* source,const struct ube_value_layout* layout){int old=observed.copy_class;observed.copy_class=3;int32_t ok=ube_value_assign(destination,source,layout);observed.copy_class=old;return ok;}
void* byte_key_element(void*const* holder,int32_t index,void** keep,void* fallback,const struct ube_value_layout* layout){if(observed.active){int role=byte_key_role(layout);if(role==1)++observed.byte_reads;if(role==2)++observed.key_reads;if(role==3)++observed.long_accesses;}return ube_value_array_element(holder,index,keep,fallback,layout);}
static void observation_start(size_t fault){observed=(struct observations){.active=true,.fail_at=fault};observed.roots_before=storage_root_count();observed.root_peak=observed.roots_before;observed.gc_before=ube_gc_live_allocation_bytes();observed.gc_peak=observed.gc_before;}
static void observation_stop(void){observed.active=false;}
