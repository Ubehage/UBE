/* Small synthetic regression: collector tracing must not terminate a caller
   whose allocation already failed. No UBE parser or probe candidate is needed. */
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include "../../../../../runtime/value_storage.h"
static int deny_allocations;
void* probe_malloc(size_t n){return deny_allocations?NULL:malloc(n);}
void* probe_calloc(size_t n,size_t s){return deny_allocations?NULL:calloc(n,s);}
void* probe_realloc(void* p,size_t n){return deny_allocations?NULL:realloc(p,n);}
void probe_free(void* p){free(p);}
void probe_value_copy(size_t n){(void)n;}
void parser_probe_root_count_changed(size_t n){(void)n;}
extern int32_t ube_gc_root_enter(void*,void**),ube_gc_root_leave(void*),ube_gc_collect(void),ube_err_number(void);
extern size_t ube_gc_root_storage_size(void),ube_gc_live_allocation_bytes(void);
extern void ube_err_set(int32_t,const char*,const char*);
extern void* ube_array_element(void*,int32_t);
int main(void){
    void* bytes=NULL;uint64_t storage[4]={0};static const struct ube_value_layout byte={1,0,0,NULL,0,NULL};
    if(ube_gc_root_storage_size()!=sizeof storage||!ube_gc_root_enter(storage,&bytes)||!ube_value_try_resize(&bytes,1,&byte,0))return 2;
    *(uint8_t*)ube_array_element(bytes,0)=65;void* old=bytes;ube_err_set(77,"old error","runtime OOM regression");
    fprintf(stderr,"REPRO: one rooted Byte[1], persistent allocation failure, resize to2\n");
    deny_allocations=1;int32_t ok=ube_value_try_resize(&bytes,2,&byte,1);deny_allocations=0;
    if(ok||bytes!=old||ube_value_array_length(&bytes)!=1||*(uint8_t*)ube_array_element(bytes,0)!=65||ube_err_number()!=7)return 3;
    if(!ube_gc_root_leave(storage))return 4;(void)ube_gc_collect();if(ube_gc_live_allocation_bytes()!=0)return 5;
    puts("PASS collector OOM preserves old Byte array and returns Err7");return 0;
}
