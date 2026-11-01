#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../../../bootstrap/runtime/value_storage.h"

typedef union { uint64_t alignment; unsigned char bytes[32]; } root_storage;
extern int32_t path_normalize(void**,void**,int32_t*,int32_t*);
extern int32_t path_resolve(void**,void**,void**,int32_t*);
extern int32_t ube_gc_root_enter(void*,void**),ube_gc_root_leave(void*),ube_gc_collect(void),ube_err_number(void);
extern void ube_err_set(int32_t,const char*,const char*),ube_gc_test_fail_next_allocations(uint32_t);
extern size_t ube_gc_root_storage_size(void),ube_gc_live_allocation_bytes(void),path_test_roots(void);
extern void* ube_array_element(void*,int32_t);

/* Real allocator calls and payload copy leaves, not estimates from input size.
   Requested bytes include allocator headers/workspace; process RSS is separate. */
struct allocation {void* pointer;size_t size;};
static struct allocation allocations[8192];
static SRWLOCK allocation_lock=SRWLOCK_INIT;
static size_t live_requested,peak_requested,tracking_errors;
static _Thread_local size_t calls,copied,components,feeds;
static _Thread_local size_t path_fail_at,path_calloc_ordinal,path_fail_left;
static int corrupt_output;
void path_component_called(void){++components;}
void path_feed_called(void){++feeds;}
static void track_add(void* pointer,size_t size){
    if(!pointer)return;
    for(size_t i=0;i<8192;++i)if(!allocations[i].pointer){
        allocations[i]=(struct allocation){pointer,size};live_requested+=size;
        if(live_requested>peak_requested)peak_requested=live_requested;
        return;
    }
    ++tracking_errors;
}
static void track_remove(void* pointer){
    if(!pointer)return;
    for(size_t i=0;i<8192;++i)if(allocations[i].pointer==pointer){
        live_requested-=allocations[i].size;allocations[i].pointer=NULL;return;
    }
    ++tracking_errors;
}
void* probe_malloc(size_t size){
    ++calls;void* pointer=malloc(size);
    AcquireSRWLockExclusive(&allocation_lock);track_add(pointer,size);ReleaseSRWLockExclusive(&allocation_lock);
    return pointer;
}
void* probe_calloc(size_t count,size_t size){
    ++calls;++path_calloc_ordinal;
    if(path_fail_left&&path_calloc_ordinal>=path_fail_at){--path_fail_left;return NULL;}
    void* pointer=calloc(count,size);
    AcquireSRWLockExclusive(&allocation_lock);track_add(pointer,count*size);ReleaseSRWLockExclusive(&allocation_lock);
    return pointer;
}
void* probe_realloc(void* pointer,size_t size){
    ++calls;AcquireSRWLockExclusive(&allocation_lock);
    void* resized=realloc(pointer,size);
    if(resized||size==0){track_remove(pointer);track_add(resized,size);}
    ReleaseSRWLockExclusive(&allocation_lock);return resized;
}
void probe_free(void* pointer){
    AcquireSRWLockExclusive(&allocation_lock);track_remove(pointer);ReleaseSRWLockExclusive(&allocation_lock);free(pointer);
}
void probe_value_copy(size_t size){copied+=size;}

static unsigned assertions;
#define CHECK(condition) do{++assertions;if(!(condition)){fprintf(stderr,"path assertion %u line %d: %s\n",assertions,__LINE__,#condition);return 1;}}while(0)
static const struct ube_value_layout byte_type={1,0,0,NULL,0,NULL};
static uint8_t at(void* bytes,int32_t index){return __atomic_load_n((uint8_t*)ube_array_element(bytes,index),__ATOMIC_SEQ_CST);}
static void put(void* bytes,int32_t index,uint8_t value){__atomic_store_n((uint8_t*)ube_array_element(bytes,index),value,__ATOMIC_SEQ_CST);}
static int make_bytes(void** bytes,const char* value){
    size_t length=strlen(value);
    if(length>INT32_MAX||!ube_value_try_resize(bytes,(int32_t)length,&byte_type,0))return 0;
    for(size_t i=0;i<length;++i)put(*bytes,(int32_t)i,(uint8_t)value[i]);
    return 1;
}
static int equals(void* bytes,const char* expected){
    size_t length=strlen(expected);
    if(ube_value_array_length(&bytes)!=(int32_t)length)return 0;
    for(size_t i=0;i<length;++i)if(at(bytes,(int32_t)i)!=(uint8_t)expected[i])return 0;
    return 1;
}
static int cleanup(root_storage* roots,size_t count){
    for(size_t i=count;i>0;--i)if(!ube_gc_root_leave(&roots[i-1]))return 0;
    ube_gc_collect();
    return path_test_roots()==0&&ube_gc_live_allocation_bytes()==0&&tracking_errors==0;
}
static int root_paths(root_storage* roots,void** first,void** second,void** output){
    void** slots[3]={first,second,output};
    size_t entered=0;
    while(entered<3){
        if(!ube_gc_root_enter(&roots[entered],slots[entered])){
            while(entered>0){--entered;(void)ube_gc_root_leave(&roots[entered]);}
            return 0;
        }
        ++entered;
    }
    return 1;
}
static int measure(int32_t n,int resolve){
    void* base=NULL;void* input=NULL;void* output=NULL;
    root_storage roots[3]={{0}};
    CHECK(root_paths(roots,&base,&input,&output));
    CHECK(make_bytes(&base,"C:/work/app"));
    CHECK(ube_value_try_resize(&input,n,&byte_type,0));
    /* Many one-byte components maximize stack occupancy, unlike a single name. */
    for(int32_t i=0;i<n;++i)put(input,i,(i%2)?47:97);
    size_t s=(size_t)n+(resolve?11:0)+8;
    size_t start_calls=calls,start_copied=copied,start_components=components,start_feeds=feeds;
    size_t start_live=live_requested;peak_requested=start_live;
    int32_t failure=8,parents=0;
    ube_err_set(77,"existing","path costs");
    CHECK(resolve?path_resolve(&base,&input,&output,&failure):path_normalize(&input,&output,&parents,&failure));
    CHECK(failure==0&&parents==0&&ube_err_number()==77);
    size_t allocation_calls=calls-start_calls,copy_bytes=copied-start_copied;
    size_t extra_peak=peak_requested-start_live;
    size_t log=0,power=1;while(power<s+1){power*=2;++log;}
    CHECK(allocation_calls<=40+12*log);
    CHECK(copy_bytes<=16*s+128&&extra_peak<=16*s+4096);
    CHECK(components-start_components<=3*s&&feeds-start_feeds<=6*s);
    int32_t prefix=resolve?12:0;
    CHECK(ube_value_array_length(&output)==n+prefix);
    if(corrupt_output)put(output,prefix,120);
    for(int32_t i=0;i<n;++i)CHECK(at(input,i)==(uint8_t)((i%2)?47:97)&&at(output,prefix+i)==at(input,i));
    if(resolve)CHECK(at(output,0)==67&&at(output,1)==58&&at(output,11)==47);
    put(output,prefix,98);CHECK(at(input,0)==97);
    printf("{\"n\":%d,\"resolve\":%d,\"allocationCalls\":%zu,\"copyBytes\":%zu,\"peakRequestedAdditionalBytes\":%zu,\"componentCalls\":%zu,\"feedCalls\":%zu}\n",
        n,resolve,allocation_calls,copy_bytes,extra_peak,components-start_components,feeds-start_feeds);
    CHECK(cleanup(roots,3));
    return 0;
}

static int failures(void){
    void* base=NULL;void* input=NULL;void* output=NULL;
    root_storage roots[3]={{0}};
    CHECK(root_paths(roots,&base,&input,&output));
    CHECK(make_bytes(&base,"C:/work/app")&&make_bytes(&input,"a/../b")&&make_bytes(&output,"old"));
    /* Native construction proves payload-offset input independent of lower bound. */
    CHECK(ube_value_try_redim(&input,5,7,&byte_type,0));
    put(input,5,97);put(input,6,47);put(input,7,98);
    int32_t parents=0,failure=8;
    CHECK(path_normalize(&input,&output,&parents,&failure)&&failure==0&&equals(output,"a/b"));
    CHECK(at(input,5)==97&&at(input,6)==47&&at(input,7)==98);
    CHECK(make_bytes(&input,"a/../b"));
    for(int resolve=0;resolve<2;++resolve){
        /* Each successive payload allocation fails both initial attempt/retry.
           Stop only when injection is no longer reached and success is exact. */
        int reached_success=0;
        for(uint32_t position=1;position<=32;++position){
            CHECK(make_bytes(&output,"old"));void* old=output;
            failure=8;parents=0;
            /* Injection at an observed calloc ordinal, implemented below. */
            path_calloc_ordinal=0;path_fail_at=position;path_fail_left=2;
            int ok=resolve?path_resolve(&base,&input,&output,&failure):path_normalize(&input,&output,&parents,&failure);
            size_t remaining=path_fail_left;path_fail_left=0;path_fail_at=0;
            if(ok){CHECK(failure==0&&remaining==2&&equals(output,resolve?"C:/work/app/b":"b"));reached_success=1;break;}
            CHECK(remaining==0&&failure==8&&parents==0&&output==old&&equals(output,"old")&&ube_err_number()==7);
            CHECK(path_test_roots()==3);
            ube_gc_collect();
        }
        CHECK(reached_success);
    }
    CHECK(cleanup(roots,3));
    return 0;
}

struct worker {void* input;int32_t marker;};
static DWORD WINAPI run_worker(void* parameter){
    struct worker* state=parameter;
    void* input=state->input;void* output=NULL;
    root_storage roots[2]={{0}};
    if(!ube_gc_root_enter(&roots[0],&input))return 1;
    if(!ube_gc_root_enter(&roots[1],&output)){
        (void)ube_gc_root_leave(&roots[0]);
        return 1;
    }
    DWORD result=0;
    for(int i=0;i<20;++i){
        int32_t parents=0,failure=8;
        ube_err_set(state->marker,"worker","path tests");
        if(!path_normalize(&input,&output,&parents,&failure)||failure||parents!=1||!equals(output,"../b")||ube_err_number()!=state->marker){result=2;break;}
    }
    int output_released=ube_gc_root_leave(&roots[1]);
    int input_released=ube_gc_root_leave(&roots[0]);
    if((!output_released||!input_released)&&!result)result=3;
    return result;
}
static int workers(void){
    void* input=NULL;root_storage root={0};CHECK(ube_gc_root_enter(&root,&input));
    CHECK(make_bytes(&input,"../a/../b"));
    HANDLE handles[4]={0};struct worker states[4];
    for(int i=0;i<4;++i){states[i]=(struct worker){input,100+i};handles[i]=CreateThread(NULL,0,run_worker,&states[i],0,NULL);CHECK(handles[i]!=NULL);}
    CHECK(WaitForMultipleObjects(4,handles,TRUE,20000)==WAIT_OBJECT_0);
    for(int i=0;i<4;++i){DWORD exit=99;CHECK(GetExitCodeThread(handles[i],&exit)&&exit==0);CHECK(CloseHandle(handles[i]));}
    CHECK(equals(input,"../a/../b"));CHECK(cleanup(&root,1));return 0;
}

static int root_capacity(void){
    void* input=NULL;void* base=NULL;void* output=NULL;root_storage roots[3]={{0}};
    CHECK(root_paths(roots,&input,&base,&output));
    CHECK(make_bytes(&input,"a/../b")&&make_bytes(&base,"C:/work")&&make_bytes(&output,"old"));
    const size_t maximum=1048576;
    root_storage* pressure=calloc(maximum,sizeof(*pressure));CHECK(pressure!=NULL);
    size_t count=0;
    while(count<maximum&&ube_gc_root_enter(&pressure[count],&input))++count;
    CHECK(count==maximum-3&&path_test_roots()==maximum);
    int32_t parents=0,failure=8;void* old=output;
    CHECK(!path_normalize(&input,&output,&parents,&failure)&&failure==8&&parents==0&&output==old&&equals(output,"old")&&ube_err_number()==7);
    failure=8;
    CHECK(!path_resolve(&base,&input,&output,&failure)&&failure==8&&output==old&&equals(output,"old")&&ube_err_number()==7);
    CHECK(ube_gc_root_leave(&pressure[--count]));
    struct worker state={input,123};
    HANDLE thread=CreateThread(NULL,0,run_worker,&state,0,NULL);CHECK(thread!=NULL);
    CHECK(WaitForSingleObject(thread,20000)==WAIT_OBJECT_0);
    DWORD result=99;CHECK(GetExitCodeThread(thread,&result)&&result==1);
    CHECK(CloseHandle(thread));
    CHECK(path_test_roots()==maximum-1);
    /* Both adapter roots fit, then the necessary UBE private admission fails.
       Exit2 must retain its primary failure and release both worker-stack roots. */
    CHECK(ube_gc_root_leave(&pressure[--count]));
    thread=CreateThread(NULL,0,run_worker,&state,0,NULL);CHECK(thread!=NULL);
    CHECK(WaitForSingleObject(thread,20000)==WAIT_OBJECT_0);
    result=99;CHECK(GetExitCodeThread(thread,&result)&&result==2);
    CHECK(CloseHandle(thread));
    CHECK(path_test_roots()==maximum-2);
    while(count>0){--count;CHECK(ube_gc_root_leave(&pressure[count]));}
    free(pressure);CHECK(path_test_roots()==3);
    failure=8;parents=0;
    CHECK(path_normalize(&input,&output,&parents,&failure)&&failure==0&&equals(output,"b"));
    failure=8;
    CHECK(path_resolve(&base,&input,&output,&failure)&&failure==0&&equals(output,"C:/work/b"));
    CHECK(cleanup(roots,3));return 0;
}

int main(int argc,char** argv){
    corrupt_output=argc==2&&strcmp(argv[1],"corrupt")==0;
    CHECK(ube_gc_root_storage_size()==sizeof(root_storage));
    const int32_t sizes[]={1,9,65,257,4097,16385};
    for(size_t i=0;i<sizeof(sizes)/sizeof(sizes[0]);++i)for(int resolve=0;resolve<2;++resolve)if(measure(sizes[i],resolve))return 1;
    if(failures()||root_capacity()||workers())return 1;
    printf("PASS path costs assertions:%u\n",assertions);return 0;
}
