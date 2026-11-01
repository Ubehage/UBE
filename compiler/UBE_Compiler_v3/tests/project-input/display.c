/* Actual bounded UBE display helper, observed only at native allocation leaves. */
#include <stddef.h>
#include <stdlib.h>
static void* display_malloc(size_t);
static void* display_calloc(size_t,size_t);
#define malloc display_malloc
#define calloc display_calloc
#include "bootstrap_runtime.c"
#undef malloc
#undef calloc
static size_t calls,requested,deny_at,denied;
static int observing,disconnected;
static int reject(size_t bytes){
    if(!observing||disconnected)return 0;
    ++calls;requested+=bytes;
    if(deny_at&&calls>=deny_at&&denied<2){++denied;return 1;}
    return 0;
}
static void* display_malloc(size_t bytes){return reject(bytes)?NULL:malloc(bytes);}
static void* display_calloc(size_t count,size_t bytes){if(bytes&&count>SIZE_MAX/bytes)return NULL;return reject(count*bytes)?NULL:calloc(count,bytes);}
extern int32_t display_format(void**,char**);
static const struct ube_value_layout byte_type={1,0,0,NULL,0,NULL};
static unsigned assertions;
#define CHECK(x) do{++assertions;if(!(x)){fprintf(stderr,"display assertion %u line %d: %s\n",assertions,__LINE__,#x);return 0;}}while(0)
struct concurrent_display {void** input;const uint8_t* expected;size_t length;int ok;};
static DWORD WINAPI format_worker(void* parameter){
    struct concurrent_display* test=parameter;char* output="older";struct ube_gc_root root={0};
    if(!ube_gc_root_enter(&root,(void**)&output))return 1;
    test->ok=1;
    for(int i=0;i<8;++i){
        if(!display_format(test->input,&output)||strlen(output)!=test->length||memcmp(output,test->expected,test->length)!=0){test->ok=0;break;}
        output="older";
    }
    if(!ube_gc_root_leave(&root))test->ok=0;
    return test->ok?0:1;
}
static size_t string_nodes(void){size_t count=0;for(struct ube_string_allocation* item=ube_string_allocations;item;item=item->next)++count;return count;}
static int run(void){
    const uint8_t source[]={67,58,92,195,166,240,159,152,128,34,10,0,127};
    const uint8_t expected[]={34,67,58,92,92,195,166,240,159,152,128,92,34,92,120,48,65,92,120,48,48,92,120,55,70,34};
    void* bytes=NULL;char* output="older";struct ube_gc_root roots[2]={{0}};
    CHECK(ube_gc_root_enter(&roots[0],&bytes)&&ube_gc_root_enter(&roots[1],(void**)&output));
    CHECK(ube_value_try_resize(&bytes,(int32_t)sizeof(source),&byte_type,0));
    for(size_t i=0;i<sizeof(source);++i)*(uint8_t*)ube_array_element(bytes,(int32_t)i)=source[i];
    calls=requested=deny_at=denied=0;observing=1;
    int32_t ok=display_format(&bytes,&output);observing=0;
    CHECK(ok&&strlen(output)==sizeof(expected)&&memcmp(output,expected,sizeof(expected))==0);
    for(size_t i=0;i<sizeof(source);++i)CHECK(*(uint8_t*)ube_array_element(bytes,(int32_t)i)==source[i]);
    size_t nodes_per_call=string_nodes();CHECK(nodes_per_call>0);
    size_t positions=calls;CHECK(positions>0&&positions<=32*sizeof(source)+64&&requested<=128*sizeof(source)+4096);
    output="older";ube_release_strings();ube_gc_collect();
    for(size_t position=1;position<=positions;++position){
        calls=requested=denied=0;deny_at=position;observing=1;
        ok=display_format(&bytes,&output);observing=0;
        if(ok||!denied||strcmp(output,"older")!=0){fprintf(stderr,"display allocation %zu/%zu: ok %d denied %zu\n",position,positions,ok,denied);return 0;}
        CHECK(ube_gc_root_count==2);
        for(size_t i=0;i<sizeof(source);++i)CHECK(*(uint8_t*)ube_array_element(bytes,(int32_t)i)==source[i]);
        ube_release_strings();ube_gc_collect();
        CHECK(display_format(&bytes,&output)&&strlen(output)==sizeof(expected)&&memcmp(output,expected,sizeof(expected))==0);
        output="older";ube_release_strings();ube_gc_collect();
    }
    size_t pressure_count=UBE_GC_MAX_ROOTS-ube_gc_root_count;
    struct ube_gc_root* pressure=calloc(pressure_count,sizeof(*pressure));void* neutral=NULL;CHECK(pressure);
    for(size_t i=0;i<pressure_count;++i)CHECK(ube_gc_root_enter(&pressure[i],&neutral));
    CHECK(!display_format(&bytes,&output)&&strcmp(output,"older")==0&&ube_gc_root_count==UBE_GC_MAX_ROOTS);
    for(size_t i=pressure_count;i>0;--i)CHECK(ube_gc_root_leave(&pressure[i-1]));free(pressure);
    struct concurrent_display workers[4];HANDLE threads[4];
    for(int i=0;i<4;++i){workers[i]=(struct concurrent_display){&bytes,expected,sizeof(expected),0};threads[i]=CreateThread(NULL,0,format_worker,&workers[i],0,NULL);CHECK(threads[i]);}
    for(int i=0;i<4;++i){CHECK(WaitForSingleObject(threads[i],60000)==WAIT_OBJECT_0&&workers[i].ok&&CloseHandle(threads[i]));}
    CHECK(ube_gc_root_count==2&&string_nodes()==32*nodes_per_call);
    for(size_t i=0;i<sizeof(source);++i)CHECK(*(uint8_t*)ube_array_element(bytes,(int32_t)i)==source[i]);
    ube_release_strings();ube_gc_collect();
    const int32_t sizes[]={0,1,16,512,131068,131069};
    for(size_t s=0;s<sizeof(sizes)/sizeof(sizes[0]);++s){
        int32_t n=sizes[s];CHECK(ube_value_try_resize(&bytes,n,&byte_type,0));
        for(int32_t i=0;i<n;++i)*(uint8_t*)ube_array_element(bytes,i)='x';
        calls=requested=deny_at=denied=0;observing=1;ok=display_format(&bytes,&output);observing=0;
        CHECK(ube_gc_root_count==2&&calls<=32*(size_t)n+64&&requested<=128*(size_t)n+4096);
        if(n<=131068){
            CHECK(ok&&strlen(output)==(size_t)n+2&&output[0]=='"'&&output[n+1]=='"');
            for(int32_t i=0;i<n;++i)CHECK(output[i+1]=='x');
        }else CHECK(!ok&&strcmp(output,"older")==0&&calls==0);
        for(int32_t i=0;i<n;++i)CHECK(*(uint8_t*)ube_array_element(bytes,i)=='x');
        output="older";ube_release_strings();ube_gc_collect();
    }
    int32_t controls=131068;CHECK(ube_value_try_resize(&bytes,controls,&byte_type,0));
    calls=requested=deny_at=denied=0;observing=1;ok=display_format(&bytes,&output);observing=0;
    CHECK(ok&&strlen(output)==4*(size_t)controls+2&&output[0]=='"'&&output[4*controls+1]=='"');
    CHECK(calls<=32*(size_t)controls+64&&requested<=128*(size_t)controls+4096);
    for(int32_t i=0;i<controls;++i)CHECK(memcmp(output+1+4*i,"\\x00",4)==0&&*(uint8_t*)ube_array_element(bytes,i)==0);
    output="older";ube_release_strings();ube_gc_collect();
    for(int i=1;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));ube_gc_collect();
    CHECK(ube_gc_root_count==0&&ube_gc_live_allocation_bytes()==0&&ube_string_allocations==NULL);
    printf("PASS project display allocation-positions:%zu assertions:%u\n",positions,assertions);return 1;
}
int main(int argc,char** argv){(void)argv;disconnected=argc>1;return run()?0:1;}
