/* Independent regression: all runtime allocator classes are injectable, with
   no size/type/class exemptions. Fixture/CRT setup is outside interception. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifndef UBE_REGRESSION_VALUE_HEADER
#define UBE_REGRESSION_VALUE_HEADER "../../../../../../runtime/value_storage.h"
#endif
#include UBE_REGRESSION_VALUE_HEADER
extern void* ube_array_element(void*,int32_t);
extern int32_t ube_gc_root_enter(void*,void**),ube_gc_root_leave(void*),ube_gc_collect(void),ube_err_number(void);
extern int32_t ube_gc_publish(void*);
extern void ube_err_set(int32_t,const char*,const char*),ube_err_clear(void);
extern void* ube_err_description(void),*ube_err_source(void);
extern size_t ube_gc_root_storage_size(void),ube_gc_live_allocation_bytes(void);
extern void ube_gc_test_fail_next_trace_allocations(uint32_t);
extern size_t runtime_regression_roots(void),runtime_regression_marked(void);
extern int runtime_regression_collecting(void),runtime_regression_try_gc_lock(void);
extern void runtime_regression_error_snapshot(int32_t*,uint64_t*,char*,size_t,char*,size_t);
struct ube_gc_layout {size_t size;size_t slot_count;const size_t* slot_offsets;void(*finalizer)(void*);};
extern void* ube_gc_allocate_into(const struct ube_gc_layout*,void**);
typedef union {uint64_t alignment;unsigned char bytes[32];} root;
static const struct ube_value_layout byte_type={1,0,0,NULL,0,NULL};
static _Thread_local int deny_all;
static _Thread_local size_t fail_calloc_left,fail_realloc_at,realloc_seen,failed_mallocs,failed_callocs,failed_reallocs,marked_at_failure;
static size_t finalizers;
void* runtime_regression_malloc(size_t n) {if(deny_all){++failed_mallocs;return NULL;}return malloc(n);}
void* runtime_regression_calloc(size_t n,size_t s) {
    if(deny_all||fail_calloc_left){if(fail_calloc_left)--fail_calloc_left;++failed_callocs;return NULL;}return calloc(n,s);
}
void* runtime_regression_realloc(void* p,size_t n) {
    ++realloc_seen;
    if(deny_all||(fail_realloc_at&&realloc_seen==fail_realloc_at)) {
        ++failed_reallocs;
        if(fail_realloc_at&&realloc_seen==fail_realloc_at)marked_at_failure=runtime_regression_marked();
        return NULL;
    }
    return realloc(p,n);
}
void runtime_regression_free(void* p) {free(p);}
#define CHECK(x) do{if(!(x)){fprintf(stderr,"runtime regression line%d: %s\n",__LINE__,#x);return 1;}}while(0)
static uint8_t byte_at(void* a) {return __atomic_load_n((uint8_t*)ube_array_element(a,0),__ATOMIC_SEQ_CST);}
static void put_byte(void* a,uint8_t value) {__atomic_store_n((uint8_t*)ube_array_element(a,0),value,__ATOMIC_SEQ_CST);}
static DWORD WINAPI lock_worker(void* unused) {(void)unused;return runtime_regression_try_gc_lock()?0:1;}
static int lock_is_released(void) {
    HANDLE thread=CreateThread(NULL,0,lock_worker,NULL,0,NULL);if(!thread)return 0;
    DWORD status=1;int ok=WaitForSingleObject(thread,5000)==WAIT_OBJECT_0&&GetExitCodeThread(thread,&status)&&status==0;
    CloseHandle(thread);return ok;
}
static void finalize_garbage(void* value) {(void)value;++finalizers;}
static const struct ube_gc_layout finalizable={1,0,NULL,finalize_garbage};
static int trace_case(int partial) {
    enum {ROOTS=70};root roots[ROOTS]={{0}},temporary={0};void* values[ROOTS]={0};
    size_t baseline_roots=runtime_regression_roots(),baseline_bytes=ube_gc_live_allocation_bytes();
    for(size_t i=0;i<ROOTS;++i){CHECK(ube_gc_root_enter(&roots[i],&values[i]));CHECK(ube_value_try_resize(&values[i],1,&byte_type,0));put_byte(values[i],(uint8_t)(17+i));}
    void* garbage=NULL;CHECK(ube_gc_root_enter(&temporary,&garbage));CHECK(ube_value_try_resize(&garbage,1,&byte_type,0));put_byte(garbage,212);CHECK(ube_gc_root_leave(&temporary));
    void* finalized=NULL;root final_root={0};CHECK(ube_gc_root_enter(&final_root,&finalized));CHECK(ube_gc_allocate_into(&finalizable,&finalized)!=NULL);CHECK(ube_gc_root_leave(&final_root));
    size_t before_roots=runtime_regression_roots(),before_bytes=ube_gc_live_allocation_bytes();
    ube_err_set(77,"existing error","runtime regression");
    realloc_seen=0;failed_reallocs=0;marked_at_failure=0;
    if(partial)fail_realloc_at=2;else ube_gc_test_fail_next_trace_allocations(1);
    CHECK(ube_gc_collect()==0);
    fail_realloc_at=0;
    CHECK(ube_err_number()==7&&runtime_regression_collecting()==0&&runtime_regression_marked()==0);
    CHECK(runtime_regression_roots()==before_roots&&ube_gc_live_allocation_bytes()==before_bytes&&finalizers==0);
    CHECK(byte_at(garbage)==212);
    for(size_t i=0;i<ROOTS;++i)CHECK(byte_at(values[i])==(uint8_t)(17+i));
    if(partial)CHECK(realloc_seen==2&&failed_reallocs==1&&marked_at_failure==64);
    CHECK(lock_is_released());
    CHECK(ube_gc_collect()==1&&finalizers==1&&runtime_regression_roots()==before_roots);
    CHECK(ube_gc_live_allocation_bytes()<before_bytes);
    for(size_t i=0;i<ROOTS;++i)CHECK(byte_at(values[i])==(uint8_t)(17+i));
    size_t after_retry=ube_gc_live_allocation_bytes();CHECK(ube_gc_collect()==1&&ube_gc_live_allocation_bytes()+1==after_retry&&finalizers==1);
    for(size_t i=ROOTS;i>0;--i)CHECK(ube_gc_root_leave(&roots[i-1]));
    CHECK(ube_gc_collect()==1&&runtime_regression_roots()==baseline_roots&&ube_gc_live_allocation_bytes()==baseline_bytes);
    printf("PASS trace-%s: abort/no sweep/no finalizer/marks reset/roots retained/lock released/retry/cleanup\n",partial?"partial64":"first");return 0;
}
static int retry_case(void) {
    root r={0};void* value=NULL;size_t baseline_roots=runtime_regression_roots(),baseline_bytes=ube_gc_live_allocation_bytes();
    CHECK(ube_gc_root_enter(&r,&value)&&ube_value_try_resize(&value,1,&byte_type,0));put_byte(value,109);
    size_t before_bytes=ube_gc_live_allocation_bytes();ube_err_set(77,"existing error","runtime regression");
    fail_calloc_left=1;realloc_seen=0;failed_callocs=0;failed_reallocs=0;fail_realloc_at=1;
    CHECK(ube_value_try_resize(&value,2,&byte_type,1));
    fail_realloc_at=0;
    CHECK(failed_callocs==1&&failed_reallocs==1&&ube_err_number()==77);
    CHECK(ube_value_array_length(&value)==2&&byte_at(value)==109&&*(uint8_t*)ube_array_element(value,1)==0);
    CHECK(runtime_regression_collecting()==0&&runtime_regression_roots()==baseline_roots+1&&lock_is_released());
    CHECK(ube_gc_collect()==1&&ube_gc_live_allocation_bytes()==before_bytes+1);
    CHECK(ube_gc_root_leave(&r)&&ube_gc_collect()==1&&runtime_regression_roots()==baseline_roots&&ube_gc_live_allocation_bytes()==baseline_bytes);
    puts("PASS retry-success: failed automatic trace followed by successful allocation preserves Err77/data/roots/cleanup");return 0;
}
static DWORD WINAPI error_worker(void* unused) {
    size_t* denied=unused;char description[1024],source[256];int32_t number=-1;uint64_t first_revision=0,next_revision=0;
    /* No UBE error or FLS state call has executed on this native thread. */
    deny_all=1;
    ube_err_set(7,"persistent OOM first error","runtime regression");
    CHECK(ube_err_number()==7);
    runtime_regression_error_snapshot(&number,&first_revision,description,sizeof description,source,sizeof source);
    CHECK(number==7&&first_revision>0&&strcmp(description,"persistent OOM first error")==0&&strcmp(source,"runtime regression")==0);
    deny_all=0;
    denied[0]=failed_mallocs;denied[1]=failed_callocs;denied[2]=failed_reallocs;
    root roots[2]={{0}};void* description_value=NULL;void* source_value=NULL;
    size_t baseline_roots=runtime_regression_roots(),baseline_bytes=ube_gc_live_allocation_bytes();
    CHECK(ube_gc_root_enter(&roots[0],&description_value)&&ube_gc_root_enter(&roots[1],&source_value));
    description_value=ube_err_description();source_value=ube_err_source();
    CHECK(description_value&&source_value&&strcmp(description_value,"persistent OOM first error")==0&&strcmp(source_value,"runtime regression")==0&&ube_err_number()==7);
    /* Native consumers acknowledge pending managed results after rooting them. */
    CHECK(ube_gc_publish(description_value)&&ube_gc_publish(source_value));
    ube_err_set(42,"recovered error","runtime regression");
    runtime_regression_error_snapshot(&number,&next_revision,description,sizeof description,source,sizeof source);
    CHECK(ube_err_number()==42&&number==42&&next_revision>first_revision&&strcmp(description,"recovered error")==0&&strcmp(source,"runtime regression")==0);
    first_revision=next_revision;ube_err_clear();
    runtime_regression_error_snapshot(&number,&next_revision,description,sizeof description,source,sizeof source);
    CHECK(number==0&&ube_err_number()==0&&next_revision>first_revision&&!description[0]&&!source[0]);
    CHECK(ube_gc_root_leave(&roots[1])&&ube_gc_root_leave(&roots[0]));(void)ube_gc_collect();
    CHECK(runtime_regression_roots()==baseline_roots&&ube_gc_live_allocation_bytes()==baseline_bytes);
    return 0;
}
static int error_case(void) {
    ube_err_set(77,"main-thread error","runtime regression");
    size_t baseline_roots=runtime_regression_roots(),baseline_bytes=ube_gc_live_allocation_bytes();
    size_t denied[3]={0};HANDLE thread=CreateThread(NULL,0,error_worker,denied,0,NULL);CHECK(thread);
    CHECK(WaitForSingleObject(thread,10000)==WAIT_OBJECT_0);DWORD result=99;CHECK(GetExitCodeThread(thread,&result)&&result==0&&CloseHandle(thread));
    CHECK(ube_err_number()==77&&runtime_regression_roots()==baseline_roots&&ube_gc_live_allocation_bytes()==baseline_bytes);
    puts("PASS fresh-error: all allocators denied/Err7 text and revision retained/recovery Err42/clear/thread isolation/cleanup");
    printf("MEASURE first-error denied-malloc:%zu denied-calloc:%zu denied-realloc:%zu\n",denied[0],denied[1],denied[2]);return 0;
}
int main(int argc,char** argv) {
    CHECK(argc==2&&ube_gc_root_storage_size()<=sizeof(root));(void)ube_gc_collect();
    if(strcmp(argv[1],"trace-first")==0)return trace_case(0);
    if(strcmp(argv[1],"trace-partial")==0)return trace_case(1);
    if(strcmp(argv[1],"retry-success")==0)return retry_case();
    if(strcmp(argv[1],"fresh-error")==0)return error_case();
    return 2;
}
