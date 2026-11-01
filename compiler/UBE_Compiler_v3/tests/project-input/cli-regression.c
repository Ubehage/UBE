/* Native test controls only; invoke actual production UBE entries unchanged. */
#include <stddef.h>
#include <stdlib.h>
static void* regression_malloc(size_t);
static void* regression_calloc(size_t,size_t);
#define malloc regression_malloc
#define calloc regression_calloc
#define UBE_FILE_TESTING
#define ube_file_try_close regression_close_body
#include "bootstrap_runtime.c"
#undef ube_file_try_close
#undef malloc
#undef calloc
#include "diagnostic-layout.h"
static size_t allocation_calls,allocation_position,denied;
static int observing,close_failures,failed_closes;
static int reject_allocation(void){
    if(!observing)return 0;++allocation_calls;
    if(allocation_position&&allocation_calls>=allocation_position&&denied<2){++denied;return 1;}
    return 0;
}
static void* regression_malloc(size_t n){return reject_allocation()?NULL:malloc(n);}
static void* regression_calloc(size_t n,size_t s){return reject_allocation()?NULL:calloc(n,s);}
int32_t ube_file_try_close(int32_t* token,int32_t* failure){
    if(close_failures>0){--close_failures;++failed_closes;ube_file_test_inject(6);}
    return regression_close_body(token,failure);
}
extern int32_t regression_main(int32_t,char**),regression_read(void**,struct limits*,void*,void**,struct failure*,int32_t*),regression_print(void**,struct failure*);
extern void regression_limits(struct limits*),regression_fallback(void);
extern const struct ube_gc_layout* regression_cancel_layout(void);
extern size_t regression_failure_size(void);
#ifndef REGRESSION_MAIN
static const struct ube_value_layout byte_type={1,0,0,NULL,0,NULL};
#endif
static int resources_empty(void){
    if(!ube_thread_enter_lock())return 0;
    int ok=1;for(struct ube_thread_record* record=ube_threads;record;record=record->next)if(record->is_worker)ok=0;
    ube_thread_leave_lock();return ok&&ube_file_readers==NULL;
}
static int finish(void){
    (void)failed_closes;
    ube_release_strings();ube_gc_collect();
    return resources_empty()&&ube_gc_root_count==0&&ube_gc_live_allocation_bytes()==0&&ube_string_allocations==NULL;
}
#ifdef REGRESSION_MAIN
int main(int argc,char** argv){
    ube_runtime_set_args(argc,argv);
    struct ube_gc_root* pressure=NULL;size_t count=0;
#if REGRESSION_MAIN == 1
    void* neutral=NULL;
    count=UBE_GC_MAX_ROOTS;pressure=calloc(count,sizeof(*pressure));if(!pressure)return 90;
    for(size_t i=0;i<count;++i)if(!ube_gc_root_enter(&pressure[i],&neutral))return 91;
#elif REGRESSION_MAIN == 2
    ube_thread_test_fail_starts(1);
#elif REGRESSION_MAIN == 3
    ube_thread_test_fail_waits(1);
#elif REGRESSION_MAIN == 4
    close_failures=1;
#elif REGRESSION_MAIN == 5
    close_failures=2;
#endif
    /* Execute the actual emitted platform entry, including its admission ABI. */
    int32_t result=regression_main(argc,argv);
    if(result!=1)return 92;
#if REGRESSION_MAIN == 4 || REGRESSION_MAIN == 5
    if(failed_closes!=REGRESSION_MAIN-3||close_failures)return 103;
#endif
    for(size_t i=count;i>0;--i)if(!ube_gc_root_leave(&pressure[i-1]))return 93;free(pressure);
#if REGRESSION_MAIN == 5
    if(!ube_file_readers||ube_file_readers->next)return 94;
    int32_t token=ube_file_readers->token,failure=0;
    if(!regression_close_body(&token,&failure)||token)return 95;
#endif
    if(!finish())return 96;
    return result;
}
#else
int main(int argc,char** argv){
    if(argc<3||regression_failure_size()!=sizeof(struct failure))return 90;
    void *path=NULL,*cancel=NULL,*input=NULL;struct failure failure={0};struct limits limits={0};
    struct ube_gc_root roots[4]={{0}};
    if(!ube_gc_root_enter(&roots[0],&path)||!ube_gc_root_enter(&roots[1],&cancel)||!ube_gc_root_enter(&roots[2],&input)||!ube_gc_root_enter(&roots[3],(void**)&failure.context))return 91;
    size_t length=strlen(argv[1]);if(length>INT32_MAX||!ube_value_try_resize(&path,(int32_t)length,&byte_type,0))return 92;
    for(size_t i=0;i<length;++i)*(uint8_t*)ube_array_element(path,(int32_t)i)=(uint8_t)argv[1][i];
    if(!ube_value_new_object(&cancel,regression_cancel_layout()))return 93;
    regression_limits(&limits);int32_t token=0;
    failure.kind=5;failure.code=1310;failure.package=failure.source=-1;
    if(!regression_read(&path,&limits,cancel,&input,&failure,&token)||token)return 94;
    memset(&failure,0,sizeof(failure));failure.context=input;failure.package=0;failure.source=-1;failure.location=1;
    int code=atoi(argv[2]);failure.code=code;failure.kind=3;
    if(code<0){
        failure.code=0;failure.location=2;failure.source=0;
        int selected=argc>5?atoi(argv[5]):(code==-1?3:code==-2?103:1);
        if(code==-1){failure.kind=6;failure.input.kind=selected;failure.file=argc>6?atoi(argv[6]):0;failure.input.position.line=failure.input.position.column=1;}
        else{failure.kind=7;failure.first=failure.unit.first=48;failure.unit.last=48;failure.unit.kind=code==-2?selected:200+selected;}
    }
    struct failure before=failure;
    struct ube_gc_root* pressure=NULL;size_t count=0;void* neutral=NULL;
    if(argc>3&&strcmp(argv[3],"root")==0){
        count=UBE_GC_MAX_ROOTS-ube_gc_root_count;pressure=calloc(count,sizeof(*pressure));if(!pressure)return 95;
        for(size_t i=0;i<count;++i)if(!ube_gc_root_enter(&pressure[i],&neutral))return 96;
    }
    if(argc>4)allocation_position=(size_t)strtoull(argv[4],NULL,10);
    allocation_calls=denied=0;observing=1;
    int32_t ok=regression_print(&path,&failure);observing=0;
    if(!ok)regression_fallback();
    if(memcmp(&failure,&before,sizeof(failure))!=0||token||!resources_empty())return 97;
    if((count||allocation_position)&&ok)return 98;
    if(allocation_position&&!denied)return 99;
    if(argc>3&&strcmp(argv[3],"count")==0)printf("{\"allocationPositions\":%zu}\n",allocation_calls);
    for(size_t i=count;i>0;--i)if(!ube_gc_root_leave(&pressure[i-1]))return 100;free(pressure);
    for(int i=3;i>=0;--i)if(!ube_gc_root_leave(&roots[i]))return 101;
    return finish()?0:102;
}
#endif
