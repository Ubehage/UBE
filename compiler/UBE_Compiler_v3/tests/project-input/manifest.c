#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include "../../../../bootstrap/runtime/value_storage.h"

struct source_position {int32_t byte,scalar,line,column;};
struct source_failure {int32_t kind;struct source_position position;};
struct document {void* bytes;int32_t content,scalars,lines;};
struct declaration {int32_t first,last,value_first,value_last;};
struct manifest {
    int32_t name_first,name_last,kind,kind_first,kind_last,startup_first,startup_last,optimization,debug;
    void* sources;int32_t source_count;void* references;int32_t reference_count,unsupported,unsupported_first,unsupported_last;
};
struct manifest_failure {int32_t code,entry,first,last;};
struct manifest_case {
    const char* name;const uint8_t* bytes;int32_t length,code,first,last,entry,kind,sources,references,optimization,debug,unsupported;
    int32_t source_span[4],name_span[2];
};
typedef union{uint64_t alignment;uint8_t bytes[32];} root;
extern int32_t manifest_make(void**,struct document*,struct source_failure*),manifest_parse(struct document*,struct manifest*,struct manifest_failure*);
extern size_t manifest_layout(int32_t),ube_gc_root_storage_size(void),ube_gc_live_allocation_bytes(void);
extern int32_t ube_gc_root_enter(void*,void**),ube_gc_root_leave(void*),ube_gc_collect(void),ube_err_number(void);
extern void ube_err_set(int32_t,const char*,const char*);
extern void* ube_array_element(void*,int32_t);
#ifdef OBSERVE_MANIFEST
extern size_t manifest_test_roots(void);
static _Thread_local size_t allocation_calls,copy_bytes,fail_at,fail_left,calloc_calls;
static _Thread_local size_t source_reads;
static _Thread_local void** watched_source;
static int corrupt_watch;
struct allocation {void* pointer;size_t bytes;};
static struct allocation allocations[8192];
static SRWLOCK observation_lock=SRWLOCK_INIT;
static size_t requested_live,requested_peak,tracking_errors;
static void track_add(void* pointer,size_t n){if(!pointer)return;for(size_t i=0;i<8192;++i)if(!allocations[i].pointer){allocations[i]=(struct allocation){pointer,n};requested_live+=n;if(requested_live>requested_peak)requested_peak=requested_live;return;}++tracking_errors;}
static void track_remove(void* pointer){if(!pointer)return;for(size_t i=0;i<8192;++i)if(allocations[i].pointer==pointer){requested_live-=allocations[i].bytes;allocations[i].pointer=NULL;return;}++tracking_errors;}
void* probe_malloc(size_t n){++allocation_calls;void* value=malloc(n);AcquireSRWLockExclusive(&observation_lock);track_add(value,n);ReleaseSRWLockExclusive(&observation_lock);return value;}
void* probe_calloc(size_t n,size_t s){++allocation_calls;++calloc_calls;if(fail_left&&calloc_calls>=fail_at){--fail_left;return NULL;}if(s&&n>SIZE_MAX/s)return NULL;void* value=calloc(n,s);AcquireSRWLockExclusive(&observation_lock);track_add(value,n*s);ReleaseSRWLockExclusive(&observation_lock);return value;}
void* probe_realloc(void* p,size_t n){++allocation_calls;AcquireSRWLockExclusive(&observation_lock);void* value=realloc(p,n);if(value||n==0){track_remove(p);track_add(value,n);}ReleaseSRWLockExclusive(&observation_lock);return value;}
void probe_free(void* p){AcquireSRWLockExclusive(&observation_lock);track_remove(p);ReleaseSRWLockExclusive(&observation_lock);free(p);}
void probe_value_copy(size_t n){copy_bytes+=n;}
void manifest_read_called(void* const* holder){if(watched_source&&__atomic_load_n(holder,__ATOMIC_SEQ_CST)==__atomic_load_n(watched_source,__ATOMIC_SEQ_CST))++source_reads;}
#endif
static const struct ube_value_layout byte_type={1,0,0,NULL,0,NULL};
static unsigned assertions;
#define CHECK(x) do{++assertions;if(!(x)){fprintf(stderr,"manifest assertion %u line %d: %s\n",assertions,__LINE__,#x);return 1;}}while(0)
#include "manifest-cases.h"
static int run_case(const struct manifest_case* test){
    void* bytes=NULL;struct document document={0};struct manifest metadata={0};root roots[4]={{0}};
    CHECK(ube_gc_root_enter(&roots[0],&bytes)&&ube_gc_root_enter(&roots[1],&document.bytes)&&ube_gc_root_enter(&roots[2],&metadata.sources)&&ube_gc_root_enter(&roots[3],&metadata.references));
    CHECK(ube_value_try_resize(&bytes,test->length,&byte_type,0));
    for(int32_t i=0;i<test->length;++i)*(uint8_t*)ube_array_element(bytes,i)=test->bytes[i];
    struct source_failure input_failure={0};CHECK(manifest_make(&bytes,&document,&input_failure)&&input_failure.kind==0);
    struct manifest_failure failure={1310,0,0,0};ube_err_set(77,"earlier","manifest proof");
#ifdef OBSERVE_MANIFEST
    size_t before_calls=allocation_calls,before_copies=copy_bytes,before_live=requested_live;
    requested_peak=requested_live;source_reads=0;watched_source=corrupt_watch?&bytes:&document.bytes;
#endif
    int32_t accepted=manifest_parse(&document,&metadata,&failure);
#ifdef OBSERVE_MANIFEST
    watched_source=NULL;
    CHECK(copy_bytes==before_copies);
    CHECK(allocation_calls-before_calls<=16&&requested_peak-before_live<=32768);
    CHECK((test->length==0||source_reads>0)&&source_reads<=64*(size_t)test->length+1024);
    printf("{\"case\":\"%s\",\"bytes\":%d,\"sourceReads\":%zu,\"allocationCalls\":%zu,\"copiedBytes\":%zu,\"peakRequestedAdditionalBytes\":%zu}\n",test->name,test->length,source_reads,allocation_calls-before_calls,copy_bytes-before_copies,requested_peak-before_live);
#endif
    if(failure.code!=test->code){fprintf(stderr,"case %s: expected %d, actual %d at %d..%d\n",test->name,test->code,failure.code,failure.first,failure.last);return 1;}
    CHECK(accepted==(test->code==0)&&ube_err_number()==77);
    if(test->code){
        if(test->first>=0)CHECK(failure.first==test->first&&failure.last==test->last);
        if(test->entry>=0)CHECK(failure.entry==test->entry);
    }else{
        CHECK(metadata.kind==test->kind&&metadata.source_count==test->sources&&metadata.reference_count==test->references&&metadata.optimization==test->optimization&&metadata.debug==test->debug&&metadata.unsupported==test->unsupported);
        if(test->source_span[0]>=0){struct declaration* first=ube_array_element(metadata.sources,0);CHECK(first->first==test->source_span[0]&&first->last==test->source_span[1]&&first->value_first==test->source_span[2]&&first->value_last==test->source_span[3]);}
        if(test->name_span[0]>=0)CHECK(metadata.name_first==test->name_span[0]&&metadata.name_last==test->name_span[1]);
        CHECK(failure.entry==0&&failure.first==0&&failure.last==0);
    }
    CHECK(ube_value_array_length(&document.bytes)==test->length);
    for(int32_t i=0;i<test->length;++i)CHECK(*(uint8_t*)ube_array_element(document.bytes,i)==test->bytes[i]);
    for(int i=3;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));
    ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==0);return 0;
}
#ifdef OBSERVE_MANIFEST
static int make_common(void** bytes,struct document* document){
    const struct manifest_case* test=&manifest_cases[0];
    if(!ube_value_try_resize(bytes,test->length,&byte_type,0))return 0;
    for(int32_t i=0;i<test->length;++i)*(uint8_t*)ube_array_element(*bytes,i)=test->bytes[i];
    struct source_failure failure={0};return manifest_make(bytes,document,&failure)&&failure.kind==0;
}
static int allocation_failures(void){
    void* bytes=NULL;struct document document={0};struct manifest metadata={0};root roots[4]={{0}};
    CHECK(ube_gc_root_enter(&roots[0],&bytes)&&ube_gc_root_enter(&roots[1],&document.bytes)&&ube_gc_root_enter(&roots[2],&metadata.sources)&&ube_gc_root_enter(&roots[3],&metadata.references));
    CHECK(make_common(&bytes,&document));
    for(size_t position=1;position<=3;++position){
        struct manifest_failure failure={1310,0,0,0};calloc_calls=0;fail_at=position;fail_left=2;
        CHECK(!manifest_parse(&document,&metadata,&failure));
        CHECK(fail_left==0&&failure.code==1310&&ube_err_number()==7&&manifest_test_roots()==4);
        fail_left=0;metadata=(struct manifest){0};ube_gc_collect();
        CHECK(ube_value_array_length(&document.bytes)==manifest_cases[0].length);
    }
    struct manifest_failure failure={1310,0,0,0};CHECK(manifest_parse(&document,&metadata,&failure)&&failure.code==0);
    for(int i=3;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==0);return 0;
}
static int root_failure(void){
    void* bytes=NULL;struct document document={0};struct manifest metadata={0};root roots[4]={{0}};
    CHECK(ube_gc_root_enter(&roots[0],&bytes)&&ube_gc_root_enter(&roots[1],&document.bytes)&&ube_gc_root_enter(&roots[2],&metadata.sources)&&ube_gc_root_enter(&roots[3],&metadata.references));CHECK(make_common(&bytes,&document));
    root* pressure=calloc(1048576,sizeof(root));CHECK(pressure!=NULL);size_t count=0;
    while(count<1048576&&ube_gc_root_enter(&pressure[count],&bytes))++count;
    CHECK(count==1048572&&manifest_test_roots()==1048576);
    struct manifest_failure failure={1310,0,0,0};CHECK(!manifest_parse(&document,&metadata,&failure)&&failure.code==1310&&ube_err_number()==7);
    while(count){--count;CHECK(ube_gc_root_leave(&pressure[count]));}free(pressure);
    CHECK(manifest_parse(&document,&metadata,&failure)&&failure.code==0&&metadata.kind==1);
    for(int i=3;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==0);return 0;
}
struct manifest_worker {struct document document;int marker;};
static DWORD WINAPI parse_worker(void* opaque){
    struct manifest_worker* argument=opaque;root document_root={0};DWORD status=0;
    if(!ube_gc_root_enter(&document_root,&argument->document.bytes))return 1;
    for(int i=0;i<8;++i){
        struct manifest metadata={0};root roots[2]={{0}};int entered=0;
        if(ube_gc_root_enter(&roots[0],&metadata.sources)){entered=1;if(ube_gc_root_enter(&roots[1],&metadata.references))entered=2;}
        if(entered!=2)status=1;
        struct manifest_failure failure={1310,0,0,0};ube_err_set(argument->marker,"worker","manifest proof");
        if(!status){
            if(!manifest_parse(&argument->document,&metadata,&failure)||failure.code||metadata.kind!=1||metadata.source_count!=1||ube_err_number()!=argument->marker)status=2;
            if(!status)ube_gc_collect();
        }
        while(entered){--entered;if(!ube_gc_root_leave(&roots[entered]))status=3;}
        if(status)break;
    }
    if(!ube_gc_root_leave(&document_root))status=3;return status;
}
static int independent_workers(void){
    void* bytes=NULL;struct document document={0};root roots[2]={{0}};
    CHECK(ube_gc_root_enter(&roots[0],&bytes)&&ube_gc_root_enter(&roots[1],&document.bytes)&&make_common(&bytes,&document));
    struct manifest_worker workers[4];HANDLE handles[4]={0};
    for(int i=0;i<4;++i){workers[i]=(struct manifest_worker){document,100+i};handles[i]=CreateThread(NULL,0,parse_worker,&workers[i],0,NULL);CHECK(handles[i]!=NULL);}
    CHECK(WaitForMultipleObjects(4,handles,TRUE,30000)==WAIT_OBJECT_0);
    for(int i=0;i<4;++i){DWORD result=99;CHECK(GetExitCodeThread(handles[i],&result)&&result==0&&CloseHandle(handles[i]));}
    CHECK(manifest_test_roots()==2);CHECK(ube_gc_root_leave(&roots[1])&&ube_gc_root_leave(&roots[0]));ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==0);return 0;
}
#endif
int main(int argc,char** argv){
#ifdef OBSERVE_MANIFEST
    corrupt_watch=argc==2&&strcmp(argv[1],"wrong-source-watch")==0;
#else
    (void)argc;(void)argv;
#endif
    const size_t shapes[]={sizeof(struct manifest),sizeof(struct manifest_failure),sizeof(struct declaration),sizeof(struct document),offsetof(struct manifest,sources),offsetof(struct manifest,references)};
    CHECK(ube_gc_root_storage_size()==sizeof(root));
    for(size_t i=0;i<sizeof shapes/sizeof *shapes;++i)CHECK(manifest_layout((int32_t)i)==shapes[i]);
    for(size_t i=0;i<sizeof manifest_cases/sizeof *manifest_cases;++i)if(run_case(&manifest_cases[i]))return 1;
#ifdef OBSERVE_MANIFEST
    if(allocation_failures()||root_failure()||independent_workers())return 1;
    CHECK(tracking_errors==0&&manifest_test_roots()==0);
#endif
    printf("PASS manifest cases:%zu assertions:%u\n",sizeof manifest_cases/sizeof *manifest_cases,assertions);return 0;
}
