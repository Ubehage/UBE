#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../../../../../runtime/value_storage.h"

struct position { int32_t byte, scalar, line, column; };
struct failure { int32_t kind; struct position position; };
struct decoder { int32_t remaining, accumulator, minimum; bool failed; };
struct buffer { void* storage; int32_t count; };
struct document { void* bytes; int32_t content, scalars, lines; };
struct input { struct buffer buffer; struct decoder decoder; struct position cursor, sequence, carriage; int32_t content, maximum; bool pending, ready; };
struct token { int32_t kind; struct position first,last; };
struct token_case { const char* name; const uint8_t* source; int32_t bytes,context; const struct token* expected; int32_t count; struct token failure; };
struct envelope { int32_t format,kind,identity_first,identity_last; bool has_identity; };
struct raw_span { int32_t first,count; const uint8_t* bytes; };
struct envelope_case { const char* name; const uint8_t* source; int32_t bytes,extension,format,kind,identity_first,identity_last,has_identity;struct token failure;const struct raw_span* spans;int32_t span_count; };
typedef union { uint64_t alignment; unsigned char bytes[32]; } root;
#include "oracles.h"
extern int32_t source_begin(struct input*,int32_t),source_append(struct input*,void**,int32_t,int32_t,struct failure*),source_finish(struct input*,struct document*,struct failure*);
extern int32_t scanner_scan(struct document*,int32_t,int32_t,void**,struct token*);
extern int32_t scanner_envelope(struct document*,int32_t,struct envelope*,struct token*);
extern size_t scanner_layout(int32_t),ube_gc_root_storage_size(void),ube_gc_live_allocation_bytes(void);
extern int32_t ube_gc_root_enter(void*,void**),ube_gc_root_leave(void*),ube_gc_collect(void),ube_err_number(void);
extern void ube_err_set(int32_t,const char*,const char*);
extern void* ube_array_element(void*,int32_t);
#ifdef OBSERVE_SCANNER
extern size_t scanner_test_root_count(void),scanner_test_max_roots(void);
extern size_t scanner_test_array_header_size(void),scanner_test_gc_header_size(void);
#endif
struct observations { size_t allocations,requested,zero_requested,copied,growth_copied,feeds,reads,calloc_calls,fail_at,in_grow,record_copied,capacity,growths,source_copied,array_headers,gc_headers,workspace; };
static _Thread_local struct observations observed;
void* probe_malloc(size_t n) { ++observed.allocations; observed.requested+=n; return malloc(n); }
void* probe_calloc(size_t n,size_t s) {
    ++observed.allocations; ++observed.calloc_calls;
    if (s && n>SIZE_MAX/s) return NULL;
    observed.requested+=n*s;
#ifdef OBSERVE_SCANNER
    size_t total=n*s,ah=scanner_test_array_header_size(),gh=scanner_test_gc_header_size();
    if(total==sizeof(void*))observed.workspace+=total;
    else if(total>=ah+gh&&(total-ah-gh)%sizeof(struct token)==0){observed.array_headers+=ah;observed.gc_headers+=gh;}
#endif
    if (observed.fail_at && observed.calloc_calls>=observed.fail_at) return NULL;
    void* p=calloc(n,s); if (p) observed.zero_requested+=n*s; return p;
}
void* probe_realloc(void* p,size_t n) { ++observed.allocations; observed.requested+=n; return realloc(p,n); }
void probe_free(void* p) { free(p); }
void probe_value_copy(size_t n) { observed.copied+=n; if (observed.in_grow) observed.growth_copied+=n; if(n==1)observed.source_copied+=n; }
void scanner_feed_called(void) { ++observed.feeds; ++observed.reads; }
void scanner_read_called(void) { ++observed.reads; }
void scanner_grow_enter(void) { ++observed.in_grow; }
void scanner_grow_leave(void) { --observed.in_grow; }
int32_t scanner_runtime_resize(void** values,int32_t count,const struct ube_value_layout* element,int32_t keep) {
    bool growth=keep&&element->size==sizeof(struct token);
    if(growth)scanner_grow_enter();
    int32_t ok=ube_value_try_resize(values,count,element,keep);
    if(growth){if(ok){observed.capacity=(size_t)count;++observed.growths;}scanner_grow_leave();}
    return ok;
}
void scanner_record_copied(void) { observed.record_copied+=sizeof(struct token); }
static _Thread_local unsigned assertions;
#define CHECK(x) do { ++assertions; if (!(x)) { fprintf(stderr,"scanner assertion %u at line %d: %s\n",assertions,__LINE__,#x); return 1; } } while (0)
static const struct ube_value_layout byte_type={1,0,0,NULL,0,NULL},token_type={sizeof(struct token),0,0,NULL,0,NULL};
static void seed(void) { ube_err_set(77,"existing error","scanner proof"); }
static int array(void** a,const uint8_t* bytes,int32_t n) {
    if (!ube_value_try_resize(a,n,&byte_type,0)) return 0;
    for (int32_t i=0;i<n;++i) *(uint8_t*)ube_array_element(*a,i)=bytes[i];
    return 1;
}
static int equal_bytes(void* a,const uint8_t* data,int32_t n) {
    if (ube_value_array_length(&a)!=n) return 0;
    for (int32_t i=0;i<n;++i) if (*(uint8_t*)ube_array_element(a,i)!=data[i]) return 0;
    return 1;
}
static int token_equal(struct token a,struct token b) { return memcmp(&a,&b,sizeof a)==0; }
static int compare(void* tokens,const struct token_case* c) {
    if (ube_value_array_length(&tokens)!=c->count) { fprintf(stderr,"%s count %d expected %d\n",c->name,ube_value_array_length(&tokens),c->count); return 0; }
    for (int32_t i=0;i<c->count;++i) {
        struct token actual=*(struct token*)ube_array_element(tokens,i);
#ifdef NEGATIVE_TOKEN_KIND
        if(i==0&&strcmp(c->name,"empty")==0)++actual.kind;
#endif
#ifdef NEGATIVE_TOKEN_POSITION
        if(i==0&&strcmp(c->name,"empty")==0)++actual.first.byte;
#endif
        if (!token_equal(actual,c->expected[i])) { fprintf(stderr,"%s token %d actual kind=%d [%d,%d,%d,%d]-[%d,%d,%d,%d] expected kind=%d [%d,%d,%d,%d]-[%d,%d,%d,%d]\n",c->name,i,actual.kind,actual.first.byte,actual.first.scalar,actual.first.line,actual.first.column,actual.last.byte,actual.last.scalar,actual.last.line,actual.last.column,c->expected[i].kind,c->expected[i].first.byte,c->expected[i].first.scalar,c->expected[i].first.line,c->expected[i].first.column,c->expected[i].last.byte,c->expected[i].last.scalar,c->expected[i].last.line,c->expected[i].last.column); return 0; }
    }
    return 1;
}
static int make_document(struct input* input,struct document* document,void** bytes,const uint8_t* data,int32_t n,int32_t split) {
    struct failure failure={0};
    return array(bytes,data,n)&&source_begin(input,n)&&source_append(input,bytes,0,split,&failure)&&source_append(input,bytes,split,n-split,&failure)&&source_finish(input,document,&failure);
}
static int check_vector(const struct token_case* c,int32_t split) {
    struct input input={0}; struct document document={0}; struct token failure={0}; void* bytes=NULL; void* tokens=NULL; root roots[4]={0};
    CHECK(ube_gc_root_enter(&roots[0],&input.buffer.storage)&&ube_gc_root_enter(&roots[1],&document.bytes)&&ube_gc_root_enter(&roots[2],&bytes)&&ube_gc_root_enter(&roots[3],&tokens));
    CHECK(make_document(&input,&document,&bytes,c->source,c->bytes,split));
    CHECK(ube_value_try_resize(&tokens,1,&token_type,0)); struct token old={919,{1,2,3,4},{5,6,7,8}}; *(struct token*)ube_array_element(tokens,0)=old; void* previous=tokens;
    struct document original=document; seed();
    int32_t ok=scanner_scan(&document,c->context,100000,&tokens,&failure);
    CHECK(ok==(c->failure.kind==0)); CHECK(ube_err_number()==77);
    CHECK(memcmp(&original,&document,sizeof document)==0&&equal_bytes(document.bytes,c->source,c->bytes));
    if (ok) { CHECK(failure.kind==0); CHECK(compare(tokens,c)); }
    else { CHECK(token_equal(failure,c->failure)); CHECK(tokens==previous&&ube_value_array_length(&tokens)==1&&token_equal(*(struct token*)ube_array_element(tokens,0),old)); }
    for (int i=3;i>=0;--i) CHECK(ube_gc_root_leave(&roots[i]));
    return 0;
}
static int vectors(void) {
    for (size_t i=0;i<sizeof token_cases/sizeof *token_cases;++i) {
        int32_t limit=i<token_fixture_count?token_cases[i].bytes:0;
        for (int32_t split=0;split<=limit;++split) CHECK(check_vector(&token_cases[i],split)==0);
    }
    (void)ube_gc_collect(); CHECK(ube_gc_live_allocation_bytes()==0); return 0;
}
static int envelopes(void) {
    for(size_t i=0;i<sizeof envelope_cases/sizeof *envelope_cases;++i){
        const struct envelope_case* c=&envelope_cases[i];
        for(int32_t split=0;split<=c->bytes;++split){
            struct input input={0};struct document document={0};void* bytes=NULL;root roots[3]={0};struct token failure={0};
            CHECK(ube_gc_root_enter(&roots[0],&input.buffer.storage)&&ube_gc_root_enter(&roots[1],&document.bytes)&&ube_gc_root_enter(&roots[2],&bytes));
            CHECK(make_document(&input,&document,&bytes,c->source,c->bytes,split));
            struct envelope metadata={91,92,93,94,true},old=metadata;seed();
            int32_t ok=scanner_envelope(&document,c->extension,&metadata,&failure);
            if(ok!=(c->format!=0)){fprintf(stderr,"envelope %s status %d failure %d at %d\n",c->name,ok,failure.kind,failure.first.byte);CHECK(0);}
            CHECK(ube_err_number()==77&&equal_bytes(document.bytes,c->source,c->bytes));
            if(ok){
                CHECK(failure.kind==0&&metadata.format==c->format);
                if(c->kind)CHECK(metadata.kind==c->kind);
                CHECK(metadata.has_identity==(bool)c->has_identity);
                if(c->has_identity)CHECK(metadata.identity_first==c->identity_first&&metadata.identity_last==c->identity_last);
                for(int32_t s=0;s<c->span_count;++s)for(int32_t b=0;b<c->spans[s].count;++b)CHECK(*(uint8_t*)ube_array_element(document.bytes,c->spans[s].first+b)==c->spans[s].bytes[b]);
            }else{
                if(!token_equal(failure,c->failure)){fprintf(stderr,"envelope %s expected failure %d [%d,%d] actual %d [%d,%d]\n",c->name,c->failure.kind,c->failure.first.byte,c->failure.last.byte,failure.kind,failure.first.byte,failure.last.byte);CHECK(0);}
                CHECK(metadata.format==old.format&&metadata.kind==old.kind&&metadata.identity_first==old.identity_first&&metadata.identity_last==old.identity_last&&metadata.has_identity==old.has_identity);
            }
            for(int r=2;r>=0;--r)CHECK(ube_gc_root_leave(&roots[r]));
        }
        (void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==0);
    }
    return 0;
}
static int failure_atomicity(void) {
    const uint8_t data[]="a+a+a+a+a+a+a+a+a+a+a+a+a+a+a+a+a+a+a+a";
    struct input input={0}; struct document document={0}; struct token failure={0}; void* bytes=NULL; void* tokens=NULL; root roots[4]={0};
    CHECK(ube_gc_root_enter(&roots[0],&input.buffer.storage)&&ube_gc_root_enter(&roots[1],&document.bytes)&&ube_gc_root_enter(&roots[2],&bytes)&&ube_gc_root_enter(&roots[3],&tokens));
    CHECK(make_document(&input,&document,&bytes,data,sizeof data-1,1)); CHECK(ube_value_try_resize(&tokens,1,&token_type,0));
    struct token old={919,{1,2,3,4},{5,6,7,8}}; *(struct token*)ube_array_element(tokens,0)=old; void* previous=tokens;
    CHECK(!scanner_scan(&document,-1,1000,&tokens,&failure)&&failure.kind==7&&tokens==previous);
    CHECK(!scanner_scan(&document,0,1,&tokens,&failure)&&failure.kind==6&&tokens==previous);
    struct envelope metadata={91,92,93,94,true};failure=(struct token){99,{99,99,99,99},{99,99,99,99}};
    CHECK(!scanner_envelope(&document,0,&metadata,&failure)&&failure.kind==7);
    CHECK(token_equal(failure,(struct token){7,{0,0,1,1},{0,0,1,1}})&&metadata.format==91&&metadata.kind==92&&metadata.identity_first==93&&metadata.identity_last==94&&metadata.has_identity);
#ifdef OBSERVE_SCANNER
    observed=(struct observations){0}; CHECK(scanner_scan(&document,0,1000,&tokens,&failure)); size_t allocations=observed.calloc_calls;
    CHECK(allocations>2);
    for (size_t fail=1;fail<=allocations;++fail) {
        CHECK(ube_value_try_resize(&tokens,1,&token_type,0)); *(struct token*)ube_array_element(tokens,0)=old; previous=tokens;
        observed=(struct observations){.fail_at=fail};
        CHECK(!scanner_scan(&document,0,1000,&tokens,&failure));
        CHECK(tokens==previous&&ube_value_array_length(&tokens)==1&&token_equal(*(struct token*)ube_array_element(tokens,0),old));
        CHECK(failure.kind==5||failure.kind==6); CHECK(ube_err_number()==7);
        observed=(struct observations){0};
    }
#endif
    for (int i=3;i>=0;--i) CHECK(ube_gc_root_leave(&roots[i]));
    (void)ube_gc_collect(); CHECK(ube_gc_live_allocation_bytes()==0); return 0;
}
#ifdef OBSERVE_SCANNER
static int admission_sweep(void) {
    const uint8_t data[]="a=1";
    const struct token expected[]={
        {1,{0,0,1,1},{1,1,1,2}},{7,{1,1,1,2},{2,2,1,3}},{3,{2,2,1,3},{3,3,1,4}},
        {13,{3,3,1,4},{3,3,1,4}},{15,{3,3,1,4},{3,3,1,4}}
    };
    const struct token_case c={"partial-root-admission",data,3,0,expected,5,{0}};
    const struct token_case* cases[5]={&c,NULL,NULL,NULL,NULL};
    const char* names[]={"explicit-continuation","real-core-closure","bom-unicode-eof","doubled-quote"};
    for(size_t j=0;j<4;++j){for(size_t k=0;k<token_fixture_count;++k)if(strcmp(token_cases[k].name,names[j])==0)cases[j+1]=&token_cases[k];CHECK(cases[j+1]!=NULL);}
    struct input inputs[5]={0},envelope_input={0};struct document documents[5]={0},envelope_document={0};void* bytes[5]={0};void* envelope_bytes=NULL;void* tokens=NULL;root roots[19]={0};size_t succeeded[5]={0};
    for(int j=0;j<5;++j){CHECK(ube_gc_root_enter(&roots[3*j],&inputs[j].buffer.storage)&&ube_gc_root_enter(&roots[3*j+1],&documents[j].bytes)&&ube_gc_root_enter(&roots[3*j+2],&bytes[j]));CHECK(make_document(&inputs[j],&documents[j],&bytes[j],cases[j]->source,cases[j]->bytes,0));}
    CHECK(ube_gc_root_enter(&roots[15],&tokens)&&ube_gc_root_enter(&roots[16],&envelope_input.buffer.storage)&&ube_gc_root_enter(&roots[17],&envelope_document.bytes)&&ube_gc_root_enter(&roots[18],&envelope_bytes));
    CHECK(make_document(&envelope_input,&envelope_document,&envelope_bytes,envelope_cases[0].source,envelope_cases[0].bytes,0));
    struct token old={919,{1,2,3,4},{5,6,7,8}};CHECK(ube_value_try_resize(&tokens,1,&token_type,0));*(struct token*)ube_array_element(tokens,0)=old;bool last_ok=false;
    size_t capacity=scanner_test_max_roots()-scanner_test_root_count();
    root* fixture=calloc(capacity,sizeof(root));void** slots=calloc(capacity,sizeof(void*));CHECK(fixture!=NULL&&slots!=NULL);
    for(size_t i=0;i<capacity;++i)CHECK(ube_gc_root_enter(&fixture[i],&slots[i]));
    for(size_t remaining=0;remaining<=200;++remaining){
        if(remaining)CHECK(ube_gc_root_leave(&fixture[capacity-remaining]));
        size_t baseline=scanner_test_root_count();
        for(int j=0;j<5;++j){
            if(last_ok){CHECK(ube_value_try_resize(&tokens,1,&token_type,0));*(struct token*)ube_array_element(tokens,0)=old;}void* previous=tokens;
            struct token failure={5,{0,0,1,1},{0,0,1,1}};seed();
            int32_t ok=scanner_scan(&documents[j],cases[j]->context,1000,&tokens,&failure);size_t after=scanner_test_root_count();
            if(!ok&&failure.kind!=5){fprintf(stderr,"root admission %s remaining=%zu kind=%d first=%d last=%d Err=%d\n",cases[j]->name,remaining,failure.kind,failure.first.byte,failure.last.byte,ube_err_number());CHECK(0);}
            CHECK(after==baseline);
            if(ok){CHECK(compare(tokens,cases[j]));CHECK(failure.kind==0&&ube_err_number()==77);++succeeded[j];}
            else{CHECK(tokens==previous&&ube_value_array_length(&tokens)==1&&token_equal(*(struct token*)ube_array_element(tokens,0),old));CHECK(ube_err_number()==7);}
            CHECK(equal_bytes(documents[j].bytes,cases[j]->source,cases[j]->bytes));last_ok=ok!=0;
        }
        struct envelope metadata={91,92,93,94,true};struct token failure={5,{0,0,1,1},{0,0,1,1}};seed();
        int32_t envelope_ok=scanner_envelope(&envelope_document,1,&metadata,&failure);CHECK(scanner_test_root_count()==baseline);
        if(!envelope_ok&&failure.kind!=5){fprintf(stderr,"envelope root admission remaining=%zu kind=%d first=%d last=%d Err=%d\n",remaining,failure.kind,failure.first.byte,failure.last.byte,ube_err_number());CHECK(0);}
        if(envelope_ok){CHECK(metadata.format==1&&metadata.kind==1&&metadata.identity_first==envelope_cases[0].identity_first&&metadata.identity_last==envelope_cases[0].identity_last&&metadata.has_identity&&failure.kind==0&&ube_err_number()==77);}
        else{CHECK(metadata.format==91&&metadata.kind==92&&metadata.identity_first==93&&metadata.identity_last==94&&metadata.has_identity&&ube_err_number()==7);}
    }
    for(int j=0;j<5;++j)CHECK(succeeded[j]>0);
    for(size_t i=capacity-200;i>0;--i)CHECK(ube_gc_root_leave(&fixture[i-1]));free(slots);free(fixture);
    for(int i=18;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));(void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==0);return 0;
}
#endif
struct worker { struct document* shared;struct document* envelope_shared; int result; unsigned checks; };
static DWORD WINAPI worker_main(void* argument) {
    struct worker* w=argument; void* tokens=NULL; root r={0}; struct token failure={0};
    if (!ube_gc_root_enter(&r,&tokens)) return 1;
    for (int i=0;i<8;++i) {
        seed(); if (!scanner_scan(w->shared,0,100000,&tokens,&failure)||!compare(tokens,&token_cases[2])||ube_err_number()!=77) { w->result=1; break; }
        struct envelope metadata={0};if(!scanner_envelope(w->envelope_shared,1,&metadata,&failure)||metadata.format!=1||metadata.identity_first!=envelope_cases[0].identity_first||metadata.identity_last!=envelope_cases[0].identity_last||!metadata.has_identity||ube_err_number()!=77){w->result=3;break;}
        if (check_vector(&token_cases[4],i%4)) { w->result=2; break; }
    }
    w->checks=assertions; if (!ube_gc_root_leave(&r)) return 3; return (DWORD)w->result;
}
static int workers(void) {
    struct input input={0},envelope_input={0}; struct document document={0},envelope_document={0}; void* bytes=NULL;void* envelope_bytes=NULL; root roots[6]={0};
    CHECK(ube_gc_root_enter(&roots[0],&input.buffer.storage)&&ube_gc_root_enter(&roots[1],&document.bytes)&&ube_gc_root_enter(&roots[2],&bytes));
    CHECK(ube_gc_root_enter(&roots[3],&envelope_input.buffer.storage)&&ube_gc_root_enter(&roots[4],&envelope_document.bytes)&&ube_gc_root_enter(&roots[5],&envelope_bytes));
    CHECK(make_document(&input,&document,&bytes,token_cases[2].source,token_cases[2].bytes,0));
    CHECK(make_document(&envelope_input,&envelope_document,&envelope_bytes,envelope_cases[0].source,envelope_cases[0].bytes,0));
    struct worker args[4]={0}; HANDLE handles[4];
    for (int i=0;i<4;++i) { args[i].shared=&document;args[i].envelope_shared=&envelope_document; handles[i]=CreateThread(NULL,0,worker_main,&args[i],0,NULL); CHECK(handles[i]!=NULL); }
    CHECK(WaitForMultipleObjects(4,handles,TRUE,30000)==WAIT_OBJECT_0);
    for (int i=0;i<4;++i) { DWORD code=99; CHECK(GetExitCodeThread(handles[i],&code)&&code==0&&args[i].checks>0); CHECK(CloseHandle(handles[i])); }
    for (int i=5;i>=0;--i) CHECK(ube_gc_root_leave(&roots[i])); (void)ube_gc_collect(); CHECK(ube_gc_live_allocation_bytes()==0); return 0;
}
static int costs(int32_t n,int32_t shape) {
    uint8_t* data=malloc((size_t)n+1); CHECK(data!=NULL);
    memset(data,shape==0?'a':shape==1?'x':' ',n); if (shape==1&&n>=2) { data[0]='"';data[n-1]='"'; } if (shape==2&&n) data[0]='\'';
    if (shape==3) for(int32_t i=0;i<n;++i)data[i]=i%2?'+':'a';
    struct input input={0}; struct document document={0}; struct token failure={0}; void* bytes=NULL;void* tokens=NULL;root roots[4]={0};
    CHECK(ube_gc_root_enter(&roots[0],&input.buffer.storage)&&ube_gc_root_enter(&roots[1],&document.bytes)&&ube_gc_root_enter(&roots[2],&bytes)&&ube_gc_root_enter(&roots[3],&tokens));
    CHECK(make_document(&input,&document,&bytes,data,n,n)); free(data);
    observed=(struct observations){0}; CHECK(scanner_scan(&document,0,1000000,&tokens,&failure));
    int32_t count=ube_value_array_length(&tokens);
    printf("{\"kind\":\"scanner-cost\",\"n\":%d,\"shape\":%d,\"tokens\":%d,\"stride\":%zu,\"sourceReads\":%zu,\"feedCalls\":%zu,\"copiedBytes\":%zu,\"growthCopiedBytes\":%zu,\"recordPublicationCopiedBytes\":%zu,\"sourcePayloadCopiedBytes\":%zu,\"capacity\":%zu,\"growths\":%zu,\"allocations\":%zu,\"requestedBytes\":%zu,\"zeroRequestedBytes\":%zu,\"retainedSourceBytes\":%d,\"callerRootStorageBytes\":%zu,\"callerWorkspaceBytes\":%zu,\"arrayHeaderRequestedBytes\":%zu,\"gcHeaderRequestedBytes\":%zu,\"publicationWorkspaceRequestedBytes\":%zu}\n",n,shape,count,sizeof(struct token),observed.reads,observed.feeds,observed.copied,observed.growth_copied,observed.record_copied,observed.source_copied,observed.capacity,observed.growths,observed.allocations,observed.requested,observed.zero_requested,n,sizeof roots,sizeof input+sizeof document+sizeof failure+sizeof tokens+sizeof bytes,observed.array_headers,observed.gc_headers,observed.workspace);
    for(int i=3;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i])); (void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==0);return 0;
}
int main(void) {
    const size_t layouts[]={sizeof(struct input),sizeof(struct document),sizeof(struct token),sizeof(struct position),sizeof(struct envelope)};
    CHECK(ube_gc_root_storage_size()==sizeof(root));for(int i=0;i<5;++i)CHECK(scanner_layout(i)==layouts[i]);
#ifdef OBSERVE_SCANNER
    CHECK(admission_sweep()==0);
#endif
    CHECK(vectors()==0&&envelopes()==0&&workers()==0&&failure_atomicity()==0);
#ifdef OBSERVE_SCANNER
    const int32_t sizes[]={0,2,31,4096,16384};for(size_t i=0;i<sizeof sizes/sizeof *sizes;++i)for(int32_t s=0;s<4;++s)CHECK(costs(sizes[i],s)==0);
    CHECK(scanner_test_root_count()==0);
#else
    (void)costs;
#endif
    (void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==0);printf("PASS scanner assertions:%u\n",assertions);return 0;
}
