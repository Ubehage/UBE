/* Independent consumer assertions. Discovery, policy and workers are UBE. */
#include <stdatomic.h>
#ifdef INTAKE_ALLOCATIONS
#include <stddef.h>
#include <stdlib.h>
#include <stdatomic.h>
static void* intake_calloc(size_t,size_t);
#define calloc intake_calloc
#endif
#include "bootstrap_runtime.c"
#include <io.h>
#ifdef INTAKE_ALLOCATIONS
#undef calloc
static _Atomic size_t allocation_calls,allocation_position,allocation_denials;
static _Atomic int allocation_observed;
static void* intake_calloc(size_t count,size_t size){
    if(allocation_observed){
        size_t call=atomic_fetch_add(&allocation_calls,1)+1;
        if(allocation_position&&call>=allocation_position){
            size_t denied=allocation_denials;
            while(denied<2)if(atomic_compare_exchange_weak(&allocation_denials,&denied,denied+1))return NULL;
        }
    }
    return calloc(count,size);
}
#endif

#include "diagnostic-layout.h"
struct document {void* bytes;int32_t content,scalars,lines;};
struct declaration {int32_t first,last,value_first,value_last;};
struct manifest {
    int32_t name_first,name_last,kind,kind_first,kind_last,startup_first,startup_last,optimization,debug;
    void* sources;int32_t source_count;void* references;
    int32_t reference_count,unsupported,unsupported_first,unsupported_last;
};
struct path {void* declared;void* normalized;void* resolved;int32_t parents,first,last;};
struct envelope {int32_t format,kind,first,last;uint8_t has_identity;};
struct package {
    struct document document;struct manifest metadata;
    void *declared,*resolved,*directory,*identity,*references;
    int32_t id,parent,first,last;
};
struct owner {struct document document;int32_t id;};
struct source {struct owner* owner;struct path path;void* identity;struct envelope envelope;int32_t package,declaration;};
struct input {
    void *invocation,*directory,*packages,*sources;
    int32_t package_count,source_count,source_bytes,path_bytes,metadata_bytes;uint8_t validated;
};
struct syntax {struct input* input;void* work;};
struct token {int32_t kind;struct position first,last;};
struct node {int32_t kind,first,last,child,next,children;};
struct result {void* nodes;int32_t count,root,source;};
struct metrics {int32_t reads,actions,names,pending,depth;};
struct work {
    struct owner* owner;void *tokens,*syntax;struct unit_failure failure;
    struct metrics metrics;int64_t id;int32_t state,tokens_limit,nodes_limit,pending_limit,depth_limit;
};
struct intake_case {const char *name,*path;int32_t kind,code,source,unit,packages,sources,option,oracle;};
struct source_oracle {const char *declared,*normalized,*identity;int32_t package,declaration;};
/* Independent fixture expectations: source order never comes from loaded metadata. */
static const struct source_oracle standard_sources[]={
    {"src/Main.bas","src/Main.bas","\"Main\"",0,0},
    {"src/Helper.bas","src/Helper.bas","\"Helper\"",0,1},
    {"Core.bas","Core.bas","\"CoreValue\"",1,0}
};
static const struct source_oracle normalized_sources[]={
    {"src/./unused/../Main.bas","src/Main.bas","\"Main\"",0,0},
    {"src/Helper.bas","src/Helper.bas","\"Helper\"",0,1}
};
static const struct source_oracle package_local_sources[]={
    {"src/Main.bas","src/Main.bas","\"Main\"",0,0},
    {"src/Helper.bas","src/Helper.bas","\"Helper\"",0,1},
    {"Same.bas","Same.bas","\"Main\"",1,0}
};
static const struct source_oracle reverse_sources[]={
    {"src/Helper.bas","src/Helper.bas","\"Helper\"",0,0},
    {"src/Main.bas","src/Main.bas","\"Main\"",0,1},
    {"Core.bas","Core.bas","\"CoreValue\"",1,0}
};
static const struct source_oracle case_sensitive_sources[]={
    {"Main.bas","Main.bas","\"UpperValue\"",0,0},
    {"main.bas","main.bas","\"LowerValue\"",0,1}
};
static const struct source_oracle* source_oracles[]={standard_sources,normalized_sources,package_local_sources,reverse_sources,case_sensitive_sources};
#include "intake-cases.h"
#include "intake-observation.h"
extern int32_t intake_parse(void**,struct limits*,int32_t,void*,void**,struct failure*,int32_t*);
extern void intake_limits(struct limits*);
extern size_t intake_size(int32_t);
extern const struct ube_gc_layout* intake_class(int32_t);
static const struct ube_value_layout byte_layout={1,0,0,NULL,0,NULL};
static _Atomic unsigned assertions;
#define CHECK(x) do{++assertions;if(!(x)){fprintf(stderr,"intake assertion %u line %d: %s\n",assertions,__LINE__,#x);return 0;}}while(0)
static int bytes_equal(void* a,void* b){
    int32_t n=ube_value_array_length(&a);CHECK(n==ube_value_array_length(&b));
    for(int32_t i=0;i<n;++i)CHECK(*(uint8_t*)ube_array_element(a,i)==*(uint8_t*)ube_array_element(b,i));return 1;
}
static int bytes_text(void* bytes,const char* expected){
    int32_t n=ube_value_array_length(&bytes);CHECK((size_t)n==strlen(expected));
    for(int32_t i=0;i<n;++i)CHECK(*(uint8_t*)ube_array_element(bytes,i)==(uint8_t)expected[i]);return 1;
}
static int file_equal(void* bytes,void* path,void* identity){
    int32_t n=ube_value_array_length(&path);char* name=malloc((size_t)n+1);CHECK(name);
    for(int32_t i=0;i<n;++i)name[i]=*(char*)ube_array_element(path,i);name[n]=0;
    int count=MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,name,n,NULL,0);CHECK(count>0);
    wchar_t* wide=calloc((size_t)count+1,sizeof(*wide));CHECK(wide);
    CHECK(MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,name,n,wide,count)==count);
    FILE* file=_wfopen(wide,L"rb");free(wide);free(name);CHECK(file);
    BY_HANDLE_FILE_INFORMATION information;
    CHECK(GetFileInformationByHandle((HANDLE)_get_osfhandle(_fileno(file)),&information));
    const uint32_t words[]={1u,information.dwVolumeSerialNumber,information.nFileIndexLow,information.nFileIndexHigh};
    CHECK(ube_value_array_length(&identity)==16);
    for(int w=0;w<4;++w)for(int b=0;b<4;++b)CHECK(*(uint8_t*)ube_array_element(identity,w*4+b)==(uint8_t)(words[w]>>(b*8)));
    n=ube_value_array_length(&bytes);for(int32_t i=0;i<n;++i)CHECK(fgetc(file)==*(uint8_t*)ube_array_element(bytes,i));
    CHECK(fgetc(file)==EOF);CHECK(fclose(file)==0);return 1;
}
static int drained(void){
    CHECK(ube_file_readers==NULL);CHECK(ube_thread_enter_lock());
    int workers=0;for(struct ube_thread_record* t=ube_threads;t;t=t->next)if(t->is_worker)++workers;
    ube_thread_leave_lock();CHECK(workers==0);return 1;
}
static const struct intake_case* graph_case(struct input* input){
    int32_t n=ube_value_array_length(&input->invocation);
    for(size_t i=0;i<sizeof(intake_cases)/sizeof(intake_cases[0]);++i){
        const struct intake_case* test=&intake_cases[i];
        if(test->kind||strlen(test->path)!=(size_t)n)continue;
        int match=1;for(int32_t b=0;b<n;++b)if(*(uint8_t*)ube_array_element(input->invocation,b)!=(uint8_t)test->path[b]){match=0;break;}
        if(match)return test;
    }
    if(strlen(intake_contract_case.path)==(size_t)n){
        int match=1;for(int32_t b=0;b<n;++b)if(*(uint8_t*)ube_array_element(input->invocation,b)!=(uint8_t)intake_contract_case.path[b]){match=0;break;}
        if(match)return &intake_contract_case;
    }
    return NULL;
}
static int check_graph(struct syntax* value){
    CHECK(value&&value->input&&value->input->validated);
    struct input* input=value->input;
    CHECK(input->package_count==ube_value_array_length(&input->packages));
    CHECK(input->source_count==ube_value_array_length(&input->sources));
    CHECK(input->source_count==ube_value_array_length(&value->work));
    int32_t bytes=0;
    const struct intake_case* test=graph_case(input);CHECK(test&&test->oracle>=0&&test->oracle<(int32_t)(sizeof(source_oracles)/sizeof(source_oracles[0])));
    CHECK(input->package_count==test->packages&&input->source_count==test->sources);
    const struct source_oracle* expected=source_oracles[test->oracle];
    for(int32_t p=0;p<input->package_count;++p){
        struct package* package=*(struct package**)ube_array_element(input->packages,p);
        CHECK(package&&package->id==p&&package->parent==p-1);
        CHECK(ube_value_array_length(&package->identity)==16);
        CHECK(file_equal(package->document.bytes,package->resolved,package->identity));
        CHECK(package->metadata.kind==(p==0?1:2));
        CHECK(package->metadata.source_count==(p==0?2:1));
        CHECK(package->metadata.optimization==(test->option==11&&p==0?3:2)&&package->metadata.debug==(test->option==11&&p==0?1:2));
    }
    for(int32_t i=0;i<input->source_count;++i){
        struct source* source=*(struct source**)ube_array_element(input->sources,i);
        struct work* work=*(struct work**)ube_array_element(value->work,i);
        CHECK(source&&source->owner&&source->owner->id==i&&source->package>=0&&source->package<input->package_count);
        CHECK(i<3&&source->package==expected[i].package&&source->declaration==expected[i].declaration);
        CHECK(bytes_text(source->path.declared,expected[i].declared));
        CHECK(bytes_text(source->path.normalized,expected[i].normalized));
        CHECK(source->envelope.format==1&&source->envelope.kind==1&&source->envelope.has_identity);
        CHECK((size_t)(source->envelope.last-source->envelope.first)==strlen(expected[i].identity));
        for(int32_t b=source->envelope.first;b<source->envelope.last;++b)CHECK(*(uint8_t*)ube_array_element(source->owner->document.bytes,b)==(uint8_t)expected[i].identity[b-source->envelope.first]);
        struct package* package=*(struct package**)ube_array_element(input->packages,source->package);
        struct declaration* declaration=ube_array_element(package->metadata.sources,source->declaration);
        CHECK(source->path.first==declaration->value_first&&source->path.last==declaration->value_last);
        CHECK(source->path.first>=0&&source->path.last-source->path.first==(int32_t)strlen(expected[i].declared));
        for(int32_t b=source->path.first;b<source->path.last;++b)CHECK(*(uint8_t*)ube_array_element(package->document.bytes,b)==(uint8_t)expected[i].declared[b-source->path.first]);
        CHECK(ube_value_array_length(&source->identity)==16&&source->path.parents==0);
        CHECK(file_equal(source->owner->document.bytes,source->path.resolved,source->identity));
        bytes+=ube_value_array_length(&source->owner->document.bytes);
        CHECK(work&&work->owner==source->owner&&work->state==1&&work->failure.kind==0&&work->id>0);
        CHECK(ube_value_array_length(&work->tokens)>0&&ube_value_array_length(&work->syntax)==1);
        struct result* result=ube_array_element(work->syntax,0);
        CHECK(result->source==i&&result->count==ube_value_array_length(&result->nodes));
        CHECK(result->root>=0&&result->root<result->count);
    }
    if(test->oracle==4){
        struct source* upper=*(struct source**)ube_array_element(input->sources,0);
        struct source* lower=*(struct source**)ube_array_element(input->sources,1);
        int distinct=0;for(int b=0;b<16;++b)if(*(uint8_t*)ube_array_element(upper->identity,b)!=*(uint8_t*)ube_array_element(lower->identity,b))distinct=1;
        CHECK(distinct);
    }
    CHECK(bytes==input->source_bytes);return 1;
}
static int compare_documents(struct document* a,struct document* b){
    CHECK(a->content==b->content&&a->scalars==b->scalars&&a->lines==b->lines);
    CHECK(bytes_equal(a->bytes,b->bytes));return 1;
}
static int compare_paths(struct path* a,struct path* b){
    CHECK(a->parents==b->parents&&a->first==b->first&&a->last==b->last);
    CHECK(bytes_equal(a->declared,b->declared)&&bytes_equal(a->normalized,b->normalized)&&bytes_equal(a->resolved,b->resolved));return 1;
}
static int compare_declarations(void* a,void* b){
    int32_t count=ube_value_array_length(&a);CHECK(count==ube_value_array_length(&b));
    for(int32_t i=0;i<count;++i)CHECK(memcmp(ube_array_element(a,i),ube_array_element(b,i),sizeof(struct declaration))==0);
    return 1;
}
static int compare_manifests(struct manifest* a,struct manifest* b){
    CHECK(memcmp(a,b,offsetof(struct manifest,sources))==0);
    CHECK(a->source_count==b->source_count&&a->reference_count==b->reference_count);
    CHECK(a->unsupported==b->unsupported&&a->unsupported_first==b->unsupported_first&&a->unsupported_last==b->unsupported_last);
    CHECK(compare_declarations(a->sources,b->sources)&&compare_declarations(a->references,b->references));return 1;
}
static int compare_graphs(struct syntax* a,struct syntax* b){
    CHECK(check_graph(a)&&check_graph(b));
    CHECK(a->input->package_count==b->input->package_count&&a->input->source_count==b->input->source_count);
    CHECK(a->input->source_bytes==b->input->source_bytes&&a->input->path_bytes==b->input->path_bytes&&a->input->metadata_bytes==b->input->metadata_bytes);
    CHECK(bytes_equal(a->input->invocation,b->input->invocation)&&bytes_equal(a->input->directory,b->input->directory));
    for(int32_t i=0;i<a->input->package_count;++i){
        struct package* pa=*(struct package**)ube_array_element(a->input->packages,i);
        struct package* pb=*(struct package**)ube_array_element(b->input->packages,i);
        CHECK(pa->id==pb->id&&pa->parent==pb->parent&&pa->first==pb->first&&pa->last==pb->last);
        CHECK(compare_documents(&pa->document,&pb->document)&&compare_manifests(&pa->metadata,&pb->metadata));
        CHECK(bytes_equal(pa->declared,pb->declared)&&bytes_equal(pa->resolved,pb->resolved)&&bytes_equal(pa->directory,pb->directory)&&bytes_equal(pa->identity,pb->identity));
        int32_t count=ube_value_array_length(&pa->references);CHECK(count==ube_value_array_length(&pb->references));
        for(int32_t r=0;r<count;++r)CHECK(compare_paths(ube_array_element(pa->references,r),ube_array_element(pb->references,r)));
    }
    for(int32_t i=0;i<a->input->source_count;++i){
        struct source* sa=*(struct source**)ube_array_element(a->input->sources,i);
        struct source* sb=*(struct source**)ube_array_element(b->input->sources,i);
        CHECK(sa->package==sb->package&&sa->declaration==sb->declaration);
        CHECK(memcmp(&sa->envelope,&sb->envelope,sizeof(sa->envelope))==0);
        CHECK(compare_paths(&sa->path,&sb->path));
        CHECK(bytes_equal(sa->identity,sb->identity)&&compare_documents(&sa->owner->document,&sb->owner->document));
        struct work* wa=*(struct work**)ube_array_element(a->work,i);
        struct work* wb=*(struct work**)ube_array_element(b->work,i);
        CHECK(memcmp(&wa->metrics,&wb->metrics,sizeof(wa->metrics))==0);
        CHECK(wa->state==wb->state&&wa->tokens_limit==wb->tokens_limit&&wa->nodes_limit==wb->nodes_limit&&wa->pending_limit==wb->pending_limit&&wa->depth_limit==wb->depth_limit);
        CHECK(memcmp(&wa->failure,&wb->failure,sizeof(wa->failure))==0);
        int32_t n=ube_value_array_length(&wa->tokens);CHECK(n==ube_value_array_length(&wb->tokens));
        for(int32_t t=0;t<n;++t)CHECK(memcmp(ube_array_element(wa->tokens,t),ube_array_element(wb->tokens,t),sizeof(struct token))==0);
        struct result* ra=ube_array_element(wa->syntax,0);struct result* rb=ube_array_element(wb->syntax,0);
        CHECK(ra->count==rb->count&&ra->root==rb->root&&ra->source==rb->source);
        for(int32_t t=0;t<ra->count;++t)CHECK(memcmp(ube_array_element(ra->nodes,t),ube_array_element(rb->nodes,t),sizeof(struct node))==0);
    }
    return 1;
}
static int set_path(void** path,const char* name){
    size_t n=strlen(name);CHECK(n<=INT32_MAX);
    CHECK(ube_value_try_resize(path,(int32_t)n,&byte_layout,0));
    for(size_t i=0;i<n;++i)*(uint8_t*)ube_array_element(*path,(int32_t)i)=(uint8_t)name[i];return 1;
}
static void seed_failure(struct failure* failure){
    memset(failure,0,sizeof(*failure));failure->kind=5;failure->code=1310;failure->package=failure->source=-1;
}
/* Native threads are independent API callers, not another production executor. */
struct caller {
    void* path;void* cancel;void* published;void* old;struct failure failure;
    void* expected;HANDLE ready,start;int index;DWORD native_id;unsigned successes,cancellations;
};
static _Atomic unsigned active_callers,peak_callers;
static int run_caller(struct caller* caller){
    caller->native_id=GetCurrentThreadId();
    CHECK(SetEvent(caller->ready));CHECK(WaitForSingleObject(caller->start,30000)==WAIT_OBJECT_0);
    const int32_t budgets[]={1,2,4,4,2,1};
    for(unsigned round=0;round<sizeof(budgets)/sizeof(budgets[0]);++round){
        struct limits limits={0};intake_limits(&limits);int32_t token=0;
        void* previous=caller->published;seed_failure(&caller->failure);
        int cancel=round==1u+(unsigned)caller->index;*(uint8_t*)caller->cancel=(uint8_t)cancel;
        ube_err_set(101+caller->index,"seed","independent project caller");
        unsigned active=atomic_fetch_add(&active_callers,1)+1,peak=peak_callers;
        while(peak<active&&!atomic_compare_exchange_weak(&peak_callers,&peak,active)){}
        int32_t ok=intake_parse(&caller->path,&limits,budgets[round],caller->cancel,&caller->published,&caller->failure,&token);
        atomic_fetch_sub(&active_callers,1);
        CHECK(token==0&&ube_err_number()==101+caller->index);
        if(cancel){
            CHECK(!ok&&caller->failure.kind==8&&caller->failure.code==1317&&caller->published==previous);
            ++caller->cancellations;
        }else{
            CHECK(ok&&caller->failure.kind==0&&caller->failure.code==0&&caller->published!=previous);
            CHECK(compare_graphs(caller->expected,caller->published));
            if(!caller->old)caller->old=caller->published;
            ++caller->successes;
        }
        CHECK(caller->old&&compare_graphs(caller->expected,caller->old));
        CHECK(compare_graphs(caller->old,caller->published));
        /* Collection while the other contexts run must retain all old graphs. */
        ube_gc_collect();CHECK(compare_graphs(caller->expected,caller->old));
    }
    return 1;
}
static DWORD WINAPI caller_main(void* context){return run_caller(context)?0:1;}
static int simultaneous_contexts(void* path,void* expected){
    struct caller callers[4]={0};struct ube_gc_root roots[20]={{0}};HANDLE threads[4]={0},ready[4]={0};
    HANDLE start=CreateEventW(NULL,TRUE,FALSE,NULL);CHECK(start);
    active_callers=peak_callers=0;
    for(int i=0;i<4;++i){
        callers[i].path=path;callers[i].expected=expected;callers[i].index=i;callers[i].start=start;
        CHECK(ube_gc_root_enter(&roots[i*5],&callers[i].cancel)&&ube_gc_root_enter(&roots[i*5+1],&callers[i].published)&&ube_gc_root_enter(&roots[i*5+2],&callers[i].old)&&ube_gc_root_enter(&roots[i*5+3],(void**)&callers[i].failure.context)&&ube_gc_root_enter(&roots[i*5+4],&callers[i].path));
        CHECK(ube_value_new_object(&callers[i].cancel,intake_class(0)));
        ready[i]=callers[i].ready=CreateEventW(NULL,TRUE,FALSE,NULL);CHECK(ready[i]);
        threads[i]=CreateThread(NULL,0,caller_main,&callers[i],0,NULL);CHECK(threads[i]);
    }
    CHECK(WaitForMultipleObjects(4,ready,TRUE,30000)==WAIT_OBJECT_0&&SetEvent(start));
    CHECK(WaitForMultipleObjects(4,threads,TRUE,60000)==WAIT_OBJECT_0);
    CHECK(active_callers==0&&peak_callers>=2&&peak_callers<=4);
    for(int i=0;i<4;++i){
        DWORD exit=99;CHECK(GetExitCodeThread(threads[i],&exit)&&exit==0);
        CHECK(callers[i].successes==5&&callers[i].cancellations==1);
        CHECK(compare_graphs(expected,callers[i].published)&&compare_graphs(expected,callers[i].old));
        for(int j=0;j<i;++j){
            CHECK(callers[i].native_id!=callers[j].native_id&&callers[i].cancel!=callers[j].cancel);
            CHECK(callers[i].published!=callers[j].published&&callers[i].published!=callers[i].old);
            CHECK(callers[i].failure.context!=callers[j].failure.context);
        }
        CHECK(CloseHandle(threads[i])&&CloseHandle(ready[i]));
    }
    CHECK(CloseHandle(start)&&drained());
    for(int i=19;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));
    return 1;
}
#ifdef UBE_FILE_TESTING
static void cancel_during_read(void* context){*(uint8_t*)context=1;}
static void fail_close_after_read(void* context){(void)context;ube_file_test_inject(6);}
static int controlled_failures(void** path,const char* baseline_path,void* cancel,void** published,void* baseline,struct failure* failure){
    struct limits limits={0};intake_limits(&limits);int32_t token=0;
    CHECK(set_path(path,baseline_path));*(uint8_t*)cancel=0;void* previous=*published;
    seed_failure(failure);
    size_t count=UBE_GC_MAX_ROOTS-ube_gc_root_count;struct ube_gc_root* pressure=calloc(count,sizeof(*pressure));void* neutral=NULL;
    CHECK(pressure&&count>0);for(size_t i=0;i<count;++i)CHECK(ube_gc_root_enter(&pressure[i],&neutral));
    CHECK(ube_gc_root_count==UBE_GC_MAX_ROOTS);
    CHECK(!intake_parse(path,&limits,4,cancel,published,failure,&token));
    CHECK(failure->kind==5&&failure->code==1310&&failure->context==NULL&&token==0&&*published==previous);
    for(size_t i=count;i>0;--i)CHECK(ube_gc_root_leave(&pressure[i-1]));free(pressure);
    CHECK(drained()&&compare_graphs(baseline,*published));
    seed_failure(failure);ube_thread_test_fail_starts(1);
    CHECK(!intake_parse(path,&limits,4,cancel,published,failure,&token));
    CHECK(failure->kind==9&&failure->code==1318&&token==0&&*published==previous);
    CHECK(drained()&&compare_graphs(baseline,*published));
    seed_failure(failure);ube_thread_test_fail_waits(1);
    CHECK(!intake_parse(path,&limits,4,cancel,published,failure,&token));
    CHECK(failure->kind==10&&failure->code==1319&&token==0&&*published==previous);
    CHECK(drained()&&compare_graphs(baseline,*published));
    CHECK(ube_thread_test_start_failures==0&&ube_thread_test_wait_failures==0);
    seed_failure(failure);ube_file_test_inject(2);
    CHECK(!intake_parse(path,&limits,4,cancel,published,failure,&token));
    CHECK(failure->kind==6&&failure->code==0&&failure->input.kind==6&&failure->file==5&&token==0&&*published==previous);
    CHECK(drained()&&compare_graphs(baseline,*published));
    seed_failure(failure);ube_file_test_inject(6);
    CHECK(!intake_parse(path,&limits,4,cancel,published,failure,&token));
    CHECK(failure->kind==6&&failure->code==0&&failure->input.kind==6&&failure->file==7&&token>0&&*published==previous);
    CHECK(ube_file_test_open_handles()==1);int32_t close_failure=0;
    CHECK(ube_file_try_close(&token,&close_failure)&&token==0&&close_failure==0);
    CHECK(drained()&&compare_graphs(baseline,*published));
    CHECK(set_path(path,INTAKE_INVALID_MANIFEST));seed_failure(failure);
    ube_file_test_before_read(fail_close_after_read,NULL);
    CHECK(!intake_parse(path,&limits,4,cancel,published,failure,&token));
    CHECK(failure->kind==6&&failure->code==0&&failure->input.kind==3&&failure->file==0&&token>0&&*published==previous);
    CHECK(ube_file_test_open_handles()==1&&ube_file_try_close(&token,&close_failure)&&token==0);
    CHECK(drained()&&compare_graphs(baseline,*published));
    CHECK(set_path(path,baseline_path));seed_failure(failure);
    ube_file_test_before_read(cancel_during_read,cancel);
    CHECK(!intake_parse(path,&limits,4,cancel,published,failure,&token));
    CHECK(failure->kind==8&&failure->code==1317&&token==0&&*published==previous);
    CHECK(drained()&&compare_graphs(baseline,*published));
    *(uint8_t*)cancel=0;seed_failure(failure);
    CHECK(intake_parse(path,&limits,4,cancel,published,failure,&token));
    CHECK(failure->kind==0&&failure->code==0&&token==0&&*published!=previous);
    CHECK(drained()&&compare_graphs(baseline,*published));return 1;
}
#endif
#ifdef INTAKE_ALLOCATIONS
static int allocation_failures(void** path,const char* baseline_path,void* cancel,void** published,void* baseline,struct failure* failure){
    struct limits limits={0};intake_limits(&limits);int32_t token=0;*(uint8_t*)cancel=0;
    CHECK(set_path(path,baseline_path));seed_failure(failure);
    allocation_calls=allocation_denials=allocation_position=0;allocation_observed=1;
    int ok=intake_parse(path,&limits,1,cancel,published,failure,&token);allocation_observed=0;
    size_t positions=allocation_calls;CHECK(ok&&positions>0&&token==0&&compare_graphs(baseline,*published));
    size_t one_attempt=0,two_attempts=0;
    for(size_t position=1;position<=positions;++position){
        void* previous=*published;seed_failure(failure);
        allocation_calls=allocation_denials=0;allocation_position=position;allocation_observed=1;
        ok=intake_parse(path,&limits,1,cancel,published,failure,&token);allocation_observed=0;
        if(ok||allocation_denials<1||allocation_denials>2||(failure->kind!=5&&!(failure->kind==7&&failure->code==0&&failure->unit.kind==5)&&!(failure->kind==9&&failure->code==1318))){
            fprintf(stderr,"allocation %zu/%zu: ok %d denied %zu kind/code %d/%d unit %d\n",position,positions,ok,(size_t)allocation_denials,failure->kind,failure->code,failure->unit.kind);
            if(failure->context&&ube_value_array_length(&failure->context->sources)>=2){
                void* a=*(void**)ube_array_element(failure->context->sources,0);void* b=*(void**)ube_array_element(failure->context->sources,1);
                fprintf(stderr,"retained source count %d, first two association slots identical: %d\n",failure->context->source_count,a&&a==b);
            }
            return 0;
        }
        if(allocation_denials==1)++one_attempt;else ++two_attempts;
        CHECK(token==0&&*published==previous&&drained()&&compare_graphs(baseline,*published));
        seed_failure(failure);CHECK(intake_parse(path,&limits,1,cancel,published,failure,&token));
        CHECK(token==0&&drained()&&compare_graphs(baseline,*published));
    }
    CHECK(one_attempt+two_attempts==positions);
    printf("{\"allocationPositions\":%zu,\"maximumDenialsPerPosition\":2,\"singleAttemptPositions\":%zu,\"retriedPositions\":%zu}\n",positions,one_attempt,two_attempts);return 1;
}
#endif
static int run(void){
    const size_t sizes[]={sizeof(struct document),sizeof(struct manifest),sizeof(struct path),sizeof(struct envelope),sizeof(struct package),sizeof(struct source),sizeof(struct input),sizeof(struct syntax),sizeof(struct limits),sizeof(struct failure),sizeof(struct owner),sizeof(struct work)};
    for(int32_t i=0;i<(int32_t)(sizeof(sizes)/sizeof(sizes[0]));++i)CHECK(intake_size(i)==sizes[i]);
    void *path=NULL,*cancel=NULL,*published=NULL,*baseline=NULL;struct failure failure={0};
    const char* baseline_path=NULL;
    struct ube_gc_root roots[5]={{0}};
    CHECK(ube_gc_root_enter(&roots[0],&path)&&ube_gc_root_enter(&roots[1],&cancel)&&ube_gc_root_enter(&roots[2],&published)&&ube_gc_root_enter(&roots[3],&baseline)&&ube_gc_root_enter(&roots[4],(void**)&failure.context));
    CHECK(ube_value_new_object(&cancel,intake_class(0)));
    int32_t budgets[]={1,2,4,4,2,1};
    for(size_t ci=0;ci<sizeof(intake_cases)/sizeof(intake_cases[0]);++ci){
        const struct intake_case* test=&intake_cases[ci];
        CHECK(set_path(&path,test->path));
        if(test->code==0&&test->kind==0)baseline=NULL;
        for(size_t bi=0;bi<sizeof(budgets)/sizeof(budgets[0]);++bi){
            struct limits limits={0};intake_limits(&limits);int32_t token=0;
            if(test->option==1)limits.sources=0;
            if(test->option==2)limits.manifest=0;
            if(test->option==3)limits.packages=0;
            if(test->option==4)limits.source=0;
            if(test->option==5)limits.tokens=0;
            if(test->option==6)limits.total_source=0;
            if(test->option==7)limits.path=0;
            if(test->option==8)limits.metadata=0;
            if(test->option==9)limits.depth=-1;
            *(uint8_t*)cancel=test->option==10;
            void* previous=published;
            seed_failure(&failure);
            int32_t ok=intake_parse(&path,&limits,budgets[bi],cancel,&published,&failure,&token);
            if(failure.kind!=test->kind||failure.code!=test->code||(test->unit>=0&&failure.unit.kind!=test->unit)||(test->source>=0&&failure.source!=test->source)){fprintf(stderr,"case %s jobs %d: expected %d/%d unit %d source %d actual %d/%d unit %d source %d at %d..%d\n",test->name,budgets[bi],test->kind,test->code,test->unit,test->source,failure.kind,failure.code,failure.unit.kind,failure.source,failure.first,failure.last);return 0;}
            CHECK(ok==(test->kind==0)&&token==0&&drained());
            if(ok){
                struct syntax* value=published;
                CHECK(value!=previous&&value->input->package_count==test->packages&&value->input->source_count==test->sources);
                CHECK(bytes_text(value->input->invocation,test->path));
                CHECK(check_graph(value));
                if(baseline)CHECK(compare_graphs(baseline,published));else{
                    baseline=published;
                    baseline_path=test->path;
                }
            }else{
                CHECK(published==previous);
                if(test->source>=0)CHECK(failure.source==test->source);
                if(test->unit>=0)CHECK(failure.unit.kind==test->unit);
                if(published)CHECK(compare_graphs(baseline,published));
            }
        }
    }
#ifdef UBE_FILE_TESTING
    CHECK(controlled_failures(&path,baseline_path,cancel,&published,baseline,&failure));
#endif
#ifdef INTAKE_ALLOCATIONS
    CHECK(allocation_failures(&path,baseline_path,cancel,&published,baseline,&failure));
#endif
    CHECK(set_path(&path,baseline_path)&&simultaneous_contexts(path,baseline));
    for(int i=4;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));
    ube_gc_collect();CHECK(ube_gc_root_count==0&&ube_gc_live_allocation_bytes()==0&&drained());
    printf("PASS project intake cases:%zu budgets:6 contexts:4 assertions:%u\n",sizeof(intake_cases)/sizeof(intake_cases[0]),assertions);return 1;
}
#ifdef INTAKE_CONTRACT
#include "intake-contract-proof.h"
int main(void){return run_contract_proof()?0:1;}
#else
int main(void){return run()?0:1;}
#endif
