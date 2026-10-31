#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdatomic.h>
#include "../../../../../runtime/value_storage.h"
struct position{int32_t byte,scalar,line,column;};
struct source_failure{int32_t kind;struct position position;};
struct decoder{int32_t remaining,accumulator,minimum;bool failed;};
struct buffer{void* storage;int32_t count;};
struct document{void* bytes;int32_t content,scalars,lines;};
struct input{struct buffer buffer;struct decoder decoder;struct position cursor,sequence,carriage;int32_t content,maximum;bool pending,ready;};
struct command{int32_t kind,first,last,children;};
struct linked_node{int32_t kind,first,last,first_child,next_sibling,children;};
struct edge_node{int32_t kind,first,last,first_edge,children;};
struct linked_result{void* nodes;int32_t count,root,source;};
struct edge_result{void* nodes;void* edges;int32_t count,edge_count,root,source;};
struct storage_failure{int32_t kind,index;};
struct traversal_failure{int32_t kind,first,last;};
struct traversal_metrics{int32_t reads,actions,pending,depth;};
struct command_builder{void* commands;int32_t count,maximum;};
struct walk_frame{int32_t value[8];};
struct fixture{const char* name;const uint8_t* source;int32_t bytes;const struct command* commands;int32_t count;const struct linked_node* linked;const struct edge_node* edged;const int32_t* edges;int32_t edge_count,root,traversal;};
struct expression_case{const char* name;const uint8_t* source;int32_t bytes;const struct command* commands;int32_t count;struct traversal_failure failure;};
struct storage_case{const char* name;const uint8_t* source;int32_t bytes;const struct command* commands;int32_t count,max_nodes,max_edges,max_pending;struct storage_failure failure;};
typedef union{uint64_t align;uint8_t bytes[32];}root;
#include "oracles.h"
extern int32_t probe_begin(struct input*,int32_t),probe_append(struct input*,void**,int32_t,int32_t,struct source_failure*),probe_finish(struct input*,struct document*,struct source_failure*);
extern int32_t probe_build_linked(struct document*,int32_t,void**,int32_t,int32_t,int32_t,void**,struct storage_failure*),probe_build_edge(struct document*,int32_t,void**,int32_t,int32_t,int32_t,void**,struct storage_failure*);
extern int32_t probe_project_linked(void**,int32_t,void**,struct storage_failure*),probe_project_edge(void**,int32_t,void**,struct storage_failure*);
#ifdef PROBE_TRAVERSAL
struct token{int32_t kind;struct position first,last;};
struct scan_failure{int32_t kind;struct position first,last;};
extern int32_t probe_scan(struct document*,int32_t,int32_t,void**,struct scan_failure*);
extern int32_t probe_stack(struct document*,void**,int32_t,int32_t,void**,struct traversal_failure*,struct traversal_metrics*),probe_recursive(struct document*,void**,int32_t,int32_t,void**,struct traversal_failure*,struct traversal_metrics*);
#endif
extern size_t parser_probe_layout(int32_t),ube_gc_root_storage_size(void),ube_gc_live_allocation_bytes(void);
extern int32_t parser_probe_role(const struct ube_value_layout*),ube_gc_root_enter(void*,void**),ube_gc_root_leave(void*),ube_gc_collect(void),ube_err_number(void);
extern void ube_err_set(int32_t,const char*,const char*);
extern void* ube_array_element(void*,int32_t);
#ifdef OBSERVE_PROBES
extern size_t parser_probe_root_count(void),parser_probe_max_roots(void),parser_probe_array_header_size(void),parser_probe_gc_header_size(void);
#endif
enum{ROLE_LONG=1,ROLE_COMMAND=2,ROLE_LINKED=3,ROLE_EDGE=4,ROLE_FRAME=5,ROLE_OPERATOR=6,ROLE_SPAN=7,ROLE_LINKED_RESULT=8,ROLE_EDGE_RESULT=9,ROLE_TOKEN=10,ROLE_BYTE=11,ROLE_EDGE_VECTOR=12,ROLE_COUNT=13};
struct observations{bool active;size_t events[24],allocations,requested,zeroed,calloc_calls,fail_at,byte_reads,source_copied,root_peak;size_t growth[ROLE_COUNT],trim[ROLE_COUNT],publication,other_copies,capacity[ROLE_COUNT],required[ROLE_COUNT];int copy_class,copy_role;void** edge_holders[16];size_t edge_holders_count;};
static _Thread_local struct observations observed;
static _Thread_local unsigned assertions;
static _Atomic size_t global_root_peak;
static int method_only=-1;
static int fault_actor=-1;
static size_t fault_boundary;
static _Thread_local size_t measured_source_bytes,measured_old_bytes,measured_retained_bytes;
static _Thread_local const char* measured_sample;
static _Thread_local int32_t measured_size,measured_status,measured_failure;
void parser_probe_root_count_changed(size_t n){
    if(observed.active&&n>observed.root_peak)observed.root_peak=n;
    size_t old=atomic_load_explicit(&global_root_peak,memory_order_relaxed);
    while(old<n&&!atomic_compare_exchange_weak_explicit(&global_root_peak,&old,n,memory_order_relaxed,memory_order_relaxed)){}
}
static bool allocation_fails(size_t n){if(!observed.active)return false;++observed.allocations;observed.requested+=n;return observed.fail_at&&observed.allocations>=observed.fail_at;}
void* probe_malloc(size_t n){if(allocation_fails(n))return NULL;return malloc(n);}
void* probe_calloc(size_t n,size_t s){
    if(s&&n>SIZE_MAX/s)return NULL;
    if(observed.active)++observed.calloc_calls;if(allocation_fails(n*s))return NULL;
    void* p=calloc(n,s);if(p&&observed.active)observed.zeroed+=n*s;return p;
}
void* probe_realloc(void* p,size_t n){if(allocation_fails(n))return NULL;return realloc(p,n);}
void probe_free(void* p){free(p);}
void probe_value_copy(size_t n){
    if(!observed.active)return;if(n==1)observed.source_copied+=n;
    if(observed.copy_class==1)observed.growth[observed.copy_role]+=n;
    else if(observed.copy_class==2)observed.trim[observed.copy_role]+=n;
    else if(observed.copy_class==3)observed.publication+=n;
    else observed.other_copies+=n;
}
void parser_probe_event(int32_t event){if(observed.active&&event>0&&event<24){++observed.events[event];if(event==2&&observed.events[event]>observed.required[ROLE_COMMAND])observed.required[ROLE_COMMAND]=observed.events[event];}}
static int role_for(int role,void** slot){if(role==ROLE_LONG)for(size_t i=0;i<observed.edge_holders_count;++i)if(slot==observed.edge_holders[i])return ROLE_EDGE_VECTOR;return role;}
void parser_probe_request(int32_t role,void* slot,int32_t required){if(observed.active){role=role_for(role,slot);if(required>=0&&(size_t)required>observed.required[role])observed.required[role]=(size_t)required;}}
void parser_probe_push_request(int32_t role,void* count){if(observed.active){int32_t n=*(int32_t*)count;if(n>=0&&(size_t)n+1>observed.required[role])observed.required[role]=(size_t)n+1;}}
int32_t parser_probe_resize(void** slot,int32_t count,const struct ube_value_layout* layout,int32_t keep){
    int before=ube_value_array_length(slot),role=role_for(parser_probe_role(layout),slot);int old_class=observed.copy_class,old_role=observed.copy_role;
    observed.copy_role=role;observed.copy_class=keep?(count<=before?2:1):0;
    int32_t ok=ube_value_try_resize(slot,count,layout,keep);
    if(observed.active&&ok&&count>=0&&(size_t)count>observed.capacity[role])observed.capacity[role]=(size_t)count;
    observed.copy_class=old_class;observed.copy_role=old_role;return ok;
}
int32_t parser_probe_assign(void* destination,const void* source,const struct ube_value_layout* layout){
    int old=observed.copy_class;observed.copy_class=3;int32_t ok=ube_value_assign(destination,source,layout);observed.copy_class=old;return ok;
}
void* parser_probe_element(void* const* holder,int32_t index,void** keep,void* fallback,const struct ube_value_layout* layout){
    void* result=ube_value_array_element(holder,index,keep,fallback,layout);
    if(observed.active){
        int role=parser_probe_role(layout);if(role==ROLE_BYTE)++observed.byte_reads;
        if(role==ROLE_EDGE_RESULT&&result!=fallback&&observed.edge_holders_count<16){void** edges=(void**)((uint8_t*)result+offsetof(struct edge_result,edges));bool seen=false;for(size_t i=0;i<observed.edge_holders_count;++i)if(edges==observed.edge_holders[i])seen=true;if(!seen)observed.edge_holders[observed.edge_holders_count++]=edges;}
    }
    return result;
}
static void start_observation(size_t fail_at){observed=(struct observations){.active=true,.fail_at=fail_at};
#ifdef OBSERVE_PROBES
    observed.root_peak=parser_probe_root_count();
#endif
}
static void stop_observation(void){observed.active=false;}
#define CHECK(x) do{++assertions;if(!(x)){fprintf(stderr,"parser probe assertion %u at line %d: %s\n",assertions,__LINE__,#x);return 1;}}while(0)
static const struct ube_value_layout byte_layout={1,0,0,NULL,0,NULL},command_layout={16,0,0,NULL,0,NULL};
static void seed(void){ube_err_set(77,"old error","parser probes");}
static int bytes_array(void** out,const uint8_t* data,int32_t n){if(!ube_value_try_resize(out,n,&byte_layout,0))return 0;for(int32_t i=0;i<n;++i)*(uint8_t*)ube_array_element(*out,i)=data[i];return 1;}
static int commands_array(void** out,const struct command* data,int32_t n){if(!ube_value_try_resize(out,n,&command_layout,0))return 0;for(int32_t i=0;i<n;++i)memcpy(ube_array_element(*out,i),&data[i],sizeof *data);return 1;}
static int commands_equal(void* value,const struct command* expected,int32_t count){if(ube_value_array_length(&value)!=count)return 0;for(int32_t i=0;i<count;++i){struct command actual=*(struct command*)ube_array_element(value,i);
#ifdef NEGATIVE_PROBE_KIND
    if(i==0){++actual.kind;fprintf(stderr,"NEGATIVE_PROBE_KIND\n");}
#endif
#ifdef NEGATIVE_PROBE_SPAN
    if(i==0){++actual.first;fprintf(stderr,"NEGATIVE_PROBE_SPAN\n");}
#endif
    if(memcmp(&actual,&expected[i],sizeof *expected))return 0;}return 1;}
struct source_owner{struct input input;struct document document;void* bytes;root roots[3];};
static int source_open(struct source_owner* s,const uint8_t* data,int32_t n){
    memset(s,0,sizeof *s);struct source_failure failure={0};
    return ube_gc_root_enter(&s->roots[0],&s->input.buffer.storage)&&ube_gc_root_enter(&s->roots[1],&s->document.bytes)&&ube_gc_root_enter(&s->roots[2],&s->bytes)&&bytes_array(&s->bytes,data,n)&&probe_begin(&s->input,n)&&probe_append(&s->input,&s->bytes,0,n,&failure)&&probe_finish(&s->input,&s->document,&failure);
}
static int source_close(struct source_owner* s){for(int i=2;i>=0;--i)if(!ube_gc_root_leave(&s->roots[i]))return 0;return 1;}
static int source_equal(struct source_owner* s,const uint8_t* data,int32_t n){if(ube_value_array_length(&s->document.bytes)!=n)return 0;for(int32_t i=0;i<n;++i)if(*(uint8_t*)ube_array_element(s->document.bytes,i)!=data[i])return 0;return 1;}
static int linked_equal(void* result,const struct fixture* f,int32_t source){
    if(ube_value_array_length(&result)!=1)return 0;struct linked_result r=*(struct linked_result*)ube_array_element(result,0);
    if(r.count!=f->count||r.root!=f->root||r.source!=source||ube_value_array_length(&r.nodes)!=f->count)return 0;
    for(int32_t i=0;i<f->count;++i){struct linked_node actual=*(struct linked_node*)ube_array_element(r.nodes,i);
#ifdef NEGATIVE_PROBE_KIND
    if(i==0){++actual.kind;fprintf(stderr,"NEGATIVE_PROBE_KIND\n");}
#endif
#ifdef NEGATIVE_PROBE_SPAN
    if(i==0){++actual.first;fprintf(stderr,"NEGATIVE_PROBE_SPAN\n");}
#endif
    if(memcmp(&actual,&f->linked[i],sizeof(struct linked_node))){fprintf(stderr,"%s linked node %d differs\n",f->name,i);return 0;}}return 1;
}
static int edge_equal(void* result,const struct fixture* f,int32_t source){
    if(ube_value_array_length(&result)!=1)return 0;struct edge_result r=*(struct edge_result*)ube_array_element(result,0);
    if(r.count!=f->count||r.edge_count!=f->edge_count||r.root!=f->root||r.source!=source||ube_value_array_length(&r.nodes)!=f->count||ube_value_array_length(&r.edges)!=f->edge_count)return 0;
    for(int32_t i=0;i<f->count;++i)if(memcmp(ube_array_element(r.nodes,i),&f->edged[i],sizeof(struct edge_node))){fprintf(stderr,"%s edge node %d differs\n",f->name,i);return 0;}
    for(int32_t i=0;i<f->edge_count;++i)if(*(int32_t*)ube_array_element(r.edges,i)!=f->edges[i])return 0;return 1;
}
static void print_observation(const char* phase,int32_t candidate,int32_t n,int32_t e,int32_t tokens,const struct traversal_metrics* m){
    printf("{\"phase\":\"%s\",\"sample\":\"%s\",\"size\":%d,\"candidate\":%d,\"status\":%d,\"failureKind\":%d,\"nodes\":%d,\"edges\":%d,\"tokens\":%d,\"sourceBytes\":%zu,\"retainedOldOutputPayloadBytes\":%zu,\"retainedOutputPayloadBytes\":%zu,\"byteElementAcquisitions\":%zu,\"sourcePayloadCopiedBytes\":%zu,\"allocations\":%zu,\"requestedBytes\":%zu,\"zeroRequestedBytes\":%zu,\"publicationCopiedBytesIncludingWrapper\":%zu,\"otherCopiedBytes\":%zu,\"observedPeakRootRecords\":%zu,\"observedPeakRootStorageBytes\":%zu,\"events\":[",phase,measured_sample?measured_sample:"fixture",measured_size,candidate,measured_status,measured_failure,n,e,tokens,measured_source_bytes,measured_old_bytes,measured_retained_bytes,observed.byte_reads,observed.source_copied,observed.allocations,observed.requested,observed.zeroed,observed.publication,observed.other_copies,observed.root_peak,observed.root_peak*ube_gc_root_storage_size());
    for(int i=0;i<24;++i)printf("%s%zu",i?",":"",observed.events[i]);printf("],\"growthCopiesByRole\":[");for(int i=0;i<ROLE_COUNT;++i)printf("%s%zu",i?",":"",observed.growth[i]);printf("],\"trimCopiesByRole\":[");for(int i=0;i<ROLE_COUNT;++i)printf("%s%zu",i?",":"",observed.trim[i]);printf("],\"capacityByRole\":[");for(int i=0;i<ROLE_COUNT;++i)printf("%s%zu",i?",":"",observed.capacity[i]);printf("],\"requiredByRole\":[");for(int i=0;i<ROLE_COUNT;++i)printf("%s%zu",i?",":"",observed.required[i]);printf("]");if(m)printf(",\"tokenReads\":%d,\"actions\":%d,\"maximumPending\":%d,\"maximumDepth\":%d",m->reads,m->actions,m->pending,m->depth);
#ifdef OBSERVE_PROBES
    printf(",\"runtimeArrayHeaderBytes\":%zu,\"runtimeGcHeaderBytes\":%zu",parser_probe_array_header_size(),parser_probe_gc_header_size());
#endif
    printf("}\n");
}
static int storage_fixture(const struct fixture* f,int32_t id,bool measure){
    struct source_owner s;CHECK(source_open(&s,f->source,f->bytes));void* commands=NULL;void* linked=NULL;void* edged=NULL;void* projection=NULL;root roots[4]={0};
    CHECK(ube_gc_root_enter(&roots[0],&commands)&&ube_gc_root_enter(&roots[1],&linked)&&ube_gc_root_enter(&roots[2],&edged)&&ube_gc_root_enter(&roots[3],&projection));CHECK(commands_array(&commands,f->commands,f->count));
    measured_source_bytes=(size_t)f->bytes;measured_old_bytes=0;measured_retained_bytes=(size_t)f->count*sizeof(struct linked_node)+sizeof(struct linked_result);measured_status=1;measured_failure=0;
    int32_t project_limit=f->count+8;if(f->count>256&&f->commands[f->count-1].children>256)project_limit=256;
    struct storage_failure failure={5,-1};seed();start_observation(0);int32_t ok=probe_build_linked(&s.document,id,&commands,f->count+8,f->edge_count+8,f->count+8,&linked,&failure);stop_observation();
    CHECK(ok&&failure.kind==0&&ube_err_number()==77&&linked_equal(linked,f,id));if(measure)print_observation("construct",0,f->count,f->edge_count,0,NULL);
    CHECK(observed.events[1]==(size_t)f->count&&observed.events[4]==(size_t)f->count&&observed.events[3]==(size_t)f->edge_count&&observed.events[11]==(size_t)f->edge_count);
    measured_retained_bytes=(size_t)f->count*sizeof(struct command);failure=(struct storage_failure){5,-1};seed();start_observation(0);ok=probe_project_linked(&linked,project_limit,&projection,&failure);stop_observation();CHECK(ok&&failure.kind==0&&ube_err_number()==77&&commands_equal(projection,f->commands,f->count));if(measure)print_observation("project",0,f->count,f->edge_count,0,NULL);
    CHECK(observed.events[3]==(size_t)f->count&&observed.events[10]==(size_t)f->edge_count&&observed.events[2]==(size_t)f->count);
    CHECK(ube_gc_root_leave(&roots[1])&&ube_gc_root_leave(&roots[3]));linked=NULL;projection=NULL;CHECK(ube_gc_root_enter(&roots[1],&linked)&&ube_gc_root_enter(&roots[3],&projection));(void)ube_gc_collect();
    measured_retained_bytes=(size_t)f->count*sizeof(struct edge_node)+(size_t)f->edge_count*sizeof(int32_t)+sizeof(struct edge_result);failure=(struct storage_failure){5,-1};seed();start_observation(0);ok=probe_build_edge(&s.document,id,&commands,f->count+8,f->edge_count+8,f->count+8,&edged,&failure);stop_observation();CHECK(ok&&failure.kind==0&&ube_err_number()==77&&edge_equal(edged,f,id));if(measure)print_observation("construct",1,f->count,f->edge_count,0,NULL);
    CHECK(observed.events[1]==(size_t)f->count&&observed.events[6]==(size_t)f->count&&observed.events[8]==(size_t)f->edge_count&&observed.events[11]==(size_t)f->edge_count);
    measured_retained_bytes=(size_t)f->count*sizeof(struct command);failure=(struct storage_failure){5,-1};seed();start_observation(0);ok=probe_project_edge(&edged,project_limit,&projection,&failure);stop_observation();CHECK(ok&&failure.kind==0&&ube_err_number()==77&&commands_equal(projection,f->commands,f->count));if(measure)print_observation("project",1,f->count,f->edge_count,0,NULL);
    CHECK(observed.events[5]==(size_t)f->count&&observed.events[9]==(size_t)f->edge_count&&observed.events[2]==(size_t)f->count);
    CHECK(commands_equal(commands,f->commands,f->count)&&source_equal(&s,f->source,f->bytes));
    for(int i=3;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));CHECK(source_close(&s));(void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==0);return 0;
}
struct owned_fixture{struct fixture f;uint8_t* source;struct command* commands;struct linked_node* linked;struct edge_node* edged;int32_t* edges;};
static int make_tree(struct owned_fixture* o,int32_t n,bool wide){
    memset(o,0,sizeof *o);o->f.name=wide?"synthetic-wide-call":"synthetic-tall-groups";o->f.count=n;o->f.edge_count=n?n-1:0;o->f.root=n?n-1:-1;
    if(!n)return 1;
    o->commands=calloc((size_t)n,sizeof *o->commands);o->linked=calloc((size_t)n,sizeof *o->linked);o->edged=calloc((size_t)n,sizeof *o->edged);o->edges=calloc((size_t)(n>1?n-1:1),sizeof *o->edges);o->source=calloc((size_t)2*n+4,1);if(!o->commands||!o->linked||!o->edged||!o->edges||!o->source)return 0;
    if(n==1){o->source[0]='a';o->f.bytes=1;o->commands[0]=(struct command){1,0,1,0};}
    else if(wide){int32_t at=0;o->source[at++]='F';o->source[at++]='(';o->commands[0]=(struct command){1,0,1,0};for(int32_t i=1;i<n-1;++i){if(i>1)o->source[at++]=',';int32_t first=at;o->source[at++]='a';o->commands[i]=(struct command){1,first,at,0};}o->source[at++]=')';o->f.bytes=at;o->commands[n-1]=(struct command){38,0,at,n-1};}
    else{for(int32_t i=0;i<n-1;++i)o->source[i]='(';o->source[n-1]='a';for(int32_t i=n;i<2*n-1;++i)o->source[i]=')';o->f.bytes=2*n-1;o->commands[0]=(struct command){1,n-1,n,0};for(int32_t i=1;i<n;++i)o->commands[i]=(struct command){3,n-1-i,n+i,1};}
    for(int32_t i=0;i<n;++i){struct command c=o->commands[i];int32_t first=-1,edge=-1;if(c.children){first=wide?0:i-1;edge=wide?0:i-1;}int32_t next=wide&&i<n-2?i+1:-1;o->linked[i]=(struct linked_node){c.kind,c.first,c.last,first,next,c.children};o->edged[i]=(struct edge_node){c.kind,c.first,c.last,edge,c.children};if(i<n-1)o->edges[i]=i;}
    o->f.source=o->source;o->f.commands=o->commands;o->f.linked=o->linked;o->f.edged=o->edged;o->f.edges=o->edges;return 1;
}
static void free_tree(struct owned_fixture* o){free(o->source);free(o->commands);free(o->linked);free(o->edged);free(o->edges);memset(o,0,sizeof *o);}
static int storage_samples(void){const int32_t sizes[]={0,1,8,64,1024,16384};for(size_t i=0;i<sizeof sizes/sizeof *sizes;++i)for(int wide=0;wide<2;++wide){struct owned_fixture o;CHECK(make_tree(&o,sizes[i],wide!=0));measured_sample=wide?"wide":"tall";measured_size=sizes[i];CHECK(storage_fixture(&o.f,7000+sizes[i],true)==0);free_tree(&o);}printf("{\"suite\":\"costs\",\"passed\":true,\"rows\":48}\n");return 0;}
#ifdef PROBE_TRAVERSAL
static int traversal_fixture(const struct expression_case* f,bool measure,bool frame_limited){
    struct source_owner s;CHECK(source_open(&s,f->source,f->bytes));void* tokens=NULL;void* commands=NULL;root roots[2]={0};CHECK(ube_gc_root_enter(&roots[0],&tokens)&&ube_gc_root_enter(&roots[1],&commands));struct scan_failure sf={5,{0,0,1,1},{0,0,1,1}};CHECK(probe_scan(&s.document,0,100000,&tokens,&sf));
    int32_t (*methods[])(struct document*,void**,int32_t,int32_t,void**,struct traversal_failure*,struct traversal_metrics*)={probe_stack,probe_recursive};
    measured_source_bytes=(size_t)f->bytes;measured_old_bytes=sizeof(struct command);
    for(int c=0;c<2;++c){if(method_only>=0&&method_only!=c)continue;struct command old={919,91,92,0};CHECK(commands_array(&commands,&old,1));void* previous=commands;struct traversal_failure expected=f->failure;if(frame_limited&&c==1)expected=(struct traversal_failure){2,1791,1792};struct traversal_failure failure={5,0,0};struct traversal_metrics metrics={0};seed();start_observation(0);int32_t ok=methods[c](&s.document,&tokens,256,100000,&commands,&failure,&metrics);stop_observation();if(ok!=(expected.kind==0)||failure.kind!=expected.kind)fprintf(stderr,"%s traversal%d status%d failure%d [%d,%d] expected%d [%d,%d]\n",f->name,c,ok,failure.kind,failure.first,failure.last,expected.kind,expected.first,expected.last);CHECK(ok==(expected.kind==0)&&failure.kind==expected.kind&&ube_err_number()==77);if(ok)CHECK(commands_equal(commands,f->commands,f->count));else CHECK(failure.first==expected.first&&failure.last==expected.last&&commands==previous&&commands_equal(commands,&old,1));CHECK(metrics.reads<=64*(ube_value_array_length(&tokens)+1)&&metrics.actions<=64*(ube_value_array_length(&tokens)+(int32_t)observed.events[2]+1));CHECK((size_t)metrics.reads==observed.events[19]);measured_retained_bytes=(size_t)ube_value_array_length(&commands)*sizeof(struct command);measured_status=ok;measured_failure=failure.kind;if(measure)print_observation("traverse",c,f->count,0,ube_value_array_length(&tokens),&metrics);}
    CHECK(ube_gc_root_leave(&roots[1])&&ube_gc_root_leave(&roots[0])&&source_close(&s));(void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==0);return 0;
}
struct owned_expression{struct expression_case f;uint8_t* source;struct command* commands;};
static int make_expression(struct owned_expression* o,const char* family,int32_t d){
    memset(o,0,sizeof *o);o->f.name=family;size_t allocation=(size_t)d*64+16;o->source=calloc(allocation,1);o->commands=calloc((size_t)d*24+8,sizeof *o->commands);if(!o->source||!o->commands)return 0;int32_t at=0,n=0;
    if(strcmp(family,"flat")==0){if(d<1){o->f.failure=(struct traversal_failure){101,0,0};}else for(int32_t i=0;i<d;++i){if(i)o->source[at++]='+';int32_t first=at;o->source[at++]='a';o->commands[n++]=(struct command){1,first,at,0};if(i)o->commands[n++]=(struct command){12,0,at,2};}}
    else if(strcmp(family,"groups")==0){for(int32_t i=0;i<d;++i)o->source[at++]='(';o->source[at++]='a';for(int32_t i=0;i<d;++i)o->source[at++]=')';o->commands[n++]=(struct command){1,d,d+1,0};for(int32_t i=d-1;i>=0;--i)o->commands[n++]=(struct command){3,i,2*d+1-i,1};if(d>256)o->f.failure=(struct traversal_failure){2,256,257};}
    else if(strcmp(family,"prefix")==0){for(int32_t i=0;i<d;++i)o->source[at++]='-';o->source[at++]='a';o->commands[n++]=(struct command){1,d,d+1,0};for(int32_t i=d-1;i>=0;--i)o->commands[n++]=(struct command){5,i,d+1,1};if(d>256)o->f.failure=(struct traversal_failure){2,256,257};}
    else if(strcmp(family,"power")==0){for(int32_t i=0;i<=d;++i){if(i){memcpy(o->source+at," ^ ",3);at+=3;}int32_t first=at;o->source[at++]='a';o->commands[n++]=(struct command){1,first,at,0};}for(int32_t i=d-1;i>=0;--i)o->commands[n++]=(struct command){7,4*i,4*d+1,2};if(d>256)o->f.failure=(struct traversal_failure){2,1026,1027};}
    else if(strcmp(family,"mixed")==0){const char prefix[]="a Imp b Eqv c Xor d Or e And f = g & h + i * j \\ k Mod (";const int32_t names[]={0,6,12,18,23,29,33,37,41,45,49};const int32_t kinds[]={30,29,28,26,24,15,14,12,8,10,11};if(sizeof prefix-1!=56)return 0;for(int32_t level=0;level<d;++level){memcpy(o->source+at,prefix,56);at+=56;for(int j=0;j<11;++j)o->commands[n++]=(struct command){1,56*level+names[j],56*level+names[j]+1,0};}o->source[at++]='x';o->commands[n++]=(struct command){1,56*d,56*d+1,0};for(int32_t level=d-1;level>=0;--level){o->source[at++]=')';o->commands[n++]=(struct command){3,56*level+55,at,1};for(int j=10;j>=0;--j)o->commands[n++]=(struct command){kinds[j],56*level+names[j],at,2};}}
    else return 0;
    o->f.source=o->source;o->f.bytes=at;o->f.commands=o->commands;o->f.count=n;return 1;
}
static void free_expression(struct owned_expression* o){free(o->source);free(o->commands);memset(o,0,sizeof *o);}
static int expression_stress(const char* family,int32_t size,bool measure){struct owned_expression o;CHECK(size>=0&&size<=16384&&make_expression(&o,family,size));measured_sample=family;measured_size=size;CHECK(traversal_fixture(&o.f,measure,strcmp(family,"mixed")==0&&size>=32)==0);free_expression(&o);return 0;}
static int traversal_samples(void){const int32_t sizes[]={0,1,8,64,1024,16384};for(size_t i=0;i<sizeof sizes/sizeof *sizes;++i)CHECK(expression_stress("flat",sizes[i],true)==0);for(int32_t d=255;d<=257;++d){CHECK(expression_stress("groups",d,true)==0);CHECK(expression_stress("prefix",d,true)==0);CHECK(expression_stress("power",d,true)==0);}CHECK(expression_stress("mixed",4,true)==0);CHECK(expression_stress("mixed",8,true)==0);CHECK(expression_stress("mixed",256,true)==0);printf("{\"suite\":\"costs\",\"passed\":true,\"rows\":36}\n");return 0;}
#endif
struct actor_environment{
    struct owned_fixture tree,old_tree;struct source_owner source,old_source;
#ifdef PROBE_TRAVERSAL
    struct owned_expression expression;struct source_owner expression_source;
#endif
    void* input;void* linked;void* edged;void* old_linked;void* old_edged;void* old_commands;void* tokens;void* output;root roots[8];
    struct storage_failure failure;struct traversal_failure traversal_failure;struct traversal_metrics metrics;
};
static int actor_environment_open(struct actor_environment* e,int32_t nodes,int32_t expression_depth){
    memset(e,0,sizeof *e);CHECK(make_tree(&e->tree,nodes,true)&&make_tree(&e->old_tree,1,true));CHECK(source_open(&e->source,e->tree.f.source,e->tree.f.bytes)&&source_open(&e->old_source,e->old_tree.f.source,e->old_tree.f.bytes));
    void** slots[]={&e->input,&e->linked,&e->edged,&e->old_linked,&e->old_edged,&e->old_commands,&e->tokens,&e->output};for(int i=0;i<8;++i)CHECK(ube_gc_root_enter(&e->roots[i],slots[i]));
    CHECK(commands_array(&e->input,e->tree.f.commands,e->tree.f.count));struct command old={919,91,92,0};CHECK(commands_array(&e->old_commands,&old,1));
    void* seed_commands=NULL;root temporary={0};CHECK(ube_gc_root_enter(&temporary,&seed_commands)&&commands_array(&seed_commands,e->old_tree.f.commands,1));e->failure=(struct storage_failure){5,-1};
    CHECK(probe_build_linked(&e->old_source.document,919,&seed_commands,16,16,16,&e->old_linked,&e->failure));CHECK(probe_build_edge(&e->old_source.document,919,&seed_commands,16,16,16,&e->old_edged,&e->failure));CHECK(ube_gc_root_leave(&temporary));
    CHECK(probe_build_linked(&e->source.document,9000,&e->input,nodes+8,nodes+8,nodes+8,&e->linked,&e->failure));CHECK(probe_build_edge(&e->source.document,9000,&e->input,nodes+8,nodes+8,nodes+8,&e->edged,&e->failure));
#ifdef PROBE_TRAVERSAL
    CHECK(make_expression(&e->expression,"groups",expression_depth)&&source_open(&e->expression_source,e->expression.f.source,e->expression.f.bytes));struct scan_failure sf={5,{0,0,1,1},{0,0,1,1}};CHECK(probe_scan(&e->expression_source.document,0,100000,&e->tokens,&sf));
#else
    (void)expression_depth;
#endif
    return 0;
}
static int actor_environment_close(struct actor_environment* e){for(int i=7;i>=0;--i)CHECK(ube_gc_root_leave(&e->roots[i]));
#ifdef PROBE_TRAVERSAL
    CHECK(source_close(&e->expression_source));free_expression(&e->expression);
#endif
    CHECK(source_close(&e->old_source)&&source_close(&e->source));free_tree(&e->old_tree);free_tree(&e->tree);(void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==0);return 0;
}
static void* actor_old(struct actor_environment* e,int actor){return actor==0?e->old_linked:actor==1?e->old_edged:e->old_commands;}
static int actor_call(struct actor_environment* e,int actor){
    e->failure=(struct storage_failure){5,-1};e->traversal_failure=(struct traversal_failure){5,0,0};e->metrics=(struct traversal_metrics){0};int32_t n=e->tree.f.count;
    if(actor==0)return probe_build_linked(&e->source.document,9000,&e->input,n+8,n+8,n+8,&e->output,&e->failure);
    if(actor==1)return probe_build_edge(&e->source.document,9000,&e->input,n+8,n+8,n+8,&e->output,&e->failure);
    if(actor==2)return probe_project_linked(&e->linked,n+8,&e->output,&e->failure);
    if(actor==3)return probe_project_edge(&e->edged,n+8,&e->output,&e->failure);
#ifdef PROBE_TRAVERSAL
    if(actor==4)return probe_stack(&e->expression_source.document,&e->tokens,256,100000,&e->output,&e->traversal_failure,&e->metrics);
    if(actor==5)return probe_recursive(&e->expression_source.document,&e->tokens,256,100000,&e->output,&e->traversal_failure,&e->metrics);
#endif
    return 0;
}
static int actor_kind(struct actor_environment* e,int actor){return actor<4?e->failure.kind:e->traversal_failure.kind;}
static int actor_success(struct actor_environment* e,int actor){
    if(actor==0)return linked_equal(e->output,&e->tree.f,9000);if(actor==1)return edge_equal(e->output,&e->tree.f,9000);if(actor<4)return commands_equal(e->output,e->tree.f.commands,e->tree.f.count);
#ifdef PROBE_TRAVERSAL
    return commands_equal(e->output,e->expression.f.commands,e->expression.f.count);
#else
    return 0;
#endif
}
static int actor_old_equal(struct actor_environment* e,int actor){struct command old={919,91,92,0};if(e->output!=actor_old(e,actor))return 0;if(actor==0)return linked_equal(e->output,&e->old_tree.f,919);if(actor==1)return edge_equal(e->output,&e->old_tree.f,919);return commands_equal(e->output,&old,1);}
static int actor_count(void){
#ifdef PROBE_TRAVERSAL
    return 6;
#else
    return 4;
#endif
}
static int storage_domains(void){
    struct actor_environment e;CHECK(actor_environment_open(&e,3,1)==0);size_t cases=0;
    for(size_t i=0;i<sizeof storage_cases/sizeof *storage_cases;++i){const struct storage_case* c=&storage_cases[i];struct source_owner source;CHECK(source_open(&source,c->source,c->bytes));void* commands=NULL;root r={0};CHECK(ube_gc_root_enter(&r,&commands)&&commands_array(&commands,c->commands,c->count));
        for(int candidate=0;candidate<2;++candidate){e.output=candidate?e.old_edged:e.old_linked;e.failure=(struct storage_failure){5,-1};seed();int ok=candidate?probe_build_edge(&source.document,9000,&commands,c->max_nodes,c->max_edges,c->max_pending,&e.output,&e.failure):probe_build_linked(&source.document,9000,&commands,c->max_nodes,c->max_edges,c->max_pending,&e.output,&e.failure);if(ok!=(c->failure.kind==0)||e.failure.kind!=c->failure.kind||e.failure.index!=c->failure.index)fprintf(stderr,"%s candidate%d status%d failure%d index%d expected%d index%d\n",c->name,candidate,ok,e.failure.kind,e.failure.index,c->failure.kind,c->failure.index);CHECK(ok==(c->failure.kind==0)&&e.failure.kind==c->failure.kind&&e.failure.index==c->failure.index&&ube_err_number()==77);
            if(!ok)CHECK(actor_old_equal(&e,candidate));else{void* projected=NULL;root p={0};CHECK(ube_gc_root_enter(&p,&projected));struct storage_failure failure={5,-1};CHECK(candidate?probe_project_edge(&e.output,c->count+8,&projected,&failure):probe_project_linked(&e.output,c->count+8,&projected,&failure));CHECK(failure.kind==0&&commands_equal(projected,c->commands,c->count));if(candidate){struct edge_result value=*(struct edge_result*)ube_array_element(e.output,0);CHECK(value.count==c->count&&value.root==c->count-1&&value.source==9000);}else{struct linked_result value=*(struct linked_result*)ube_array_element(e.output,0);CHECK(value.count==c->count&&value.root==c->count-1&&value.source==9000);}CHECK(ube_gc_root_leave(&p));}++cases;}
        e.output=e.old_commands;CHECK(commands_equal(commands,c->commands,c->count)&&source_equal(&source,c->source,c->bytes));CHECK(ube_gc_root_leave(&r)&&source_close(&source));
    }
    struct command old={919,91,92,0};struct linked_result* linked=ube_array_element(e.linked,0);struct edge_result* edged=ube_array_element(e.edged,0);
    for(int corruption=0;corruption<8;++corruption){
        struct linked_node* a=ube_array_element(linked->nodes,corruption==0?0:2);struct linked_node saved_a=*a;struct edge_node* b=ube_array_element(edged->nodes,2);struct edge_node saved_b=*b;int32_t* edge=ube_array_element(edged->edges,0);int32_t saved_edge=*edge;int32_t saved_count=linked->count,saved_root=edged->root;
        if(corruption==0)a->next_sibling=0;else if(corruption==1)a->first_child=2;else if(corruption==2)a->next_sibling=0;else if(corruption==3)linked->count=4;else if(corruption==4)*edge=2;else if(corruption==5)*edge=-1;else if(corruption==6)b->first_edge=2;else edged->root=-1;
        e.output=e.old_commands;e.failure=(struct storage_failure){5,-1};seed();int ok=corruption<4?probe_project_linked(&e.linked,32,&e.output,&e.failure):probe_project_edge(&e.edged,32,&e.output,&e.failure);CHECK(!ok&&e.failure.kind==1&&e.output==e.old_commands&&commands_equal(e.output,&old,1)&&ube_err_number()==77);
        *a=saved_a;*b=saved_b;*edge=saved_edge;linked->count=saved_count;edged->root=saved_root;++cases;
    }
    e.output=e.old_commands;e.failure=(struct storage_failure){5,-1};seed();CHECK(!probe_project_linked(&e.linked,1,&e.output,&e.failure)&&e.failure.kind==2&&e.output==e.old_commands&&commands_equal(e.output,&old,1));e.failure=(struct storage_failure){5,-1};CHECK(!probe_project_edge(&e.edged,1,&e.output,&e.failure)&&e.failure.kind==2&&e.output==e.old_commands&&commands_equal(e.output,&old,1));cases+=2;
    CHECK(linked_equal(e.linked,&e.tree.f,9000)&&edge_equal(e.edged,&e.tree.f,9000));CHECK(actor_environment_close(&e)==0);printf("{\"suite\":\"domains\",\"passed\":true,\"cases\":%zu}\n",cases);return 0;
}
struct worker_arguments{struct actor_environment* shared;DWORD result;};
static DWORD WINAPI worker_main(void* argument){
    struct worker_arguments* worker=argument;struct actor_environment* shared=worker->shared;void* linked=NULL;void* edged=NULL;void* commands=NULL;root roots[3]={0};
    if(!ube_gc_root_enter(&roots[0],&linked)||!ube_gc_root_enter(&roots[1],&edged)||!ube_gc_root_enter(&roots[2],&commands))return 1;DWORD result=0;
    for(int iteration=0;iteration<4&&!result;++iteration){struct storage_failure failure={5,-1};seed();if(!probe_build_linked(&shared->source.document,9000,&shared->input,32,32,32,&linked,&failure)||!linked_equal(linked,&shared->tree.f,9000)||ube_err_number()!=77){result=2;break;}if(!probe_project_linked(&linked,32,&commands,&failure)||!commands_equal(commands,shared->tree.f.commands,shared->tree.f.count)){result=3;break;}if(!probe_build_edge(&shared->source.document,9000,&shared->input,32,32,32,&edged,&failure)||!edge_equal(edged,&shared->tree.f,9000)){result=4;break;}if(!probe_project_edge(&edged,32,&commands,&failure)||!commands_equal(commands,shared->tree.f.commands,shared->tree.f.count)||ube_err_number()!=77){result=5;break;}
#ifdef PROBE_TRAVERSAL
        struct traversal_failure tf={5,0,0};struct traversal_metrics metrics={0};if(!probe_stack(&shared->expression_source.document,&shared->tokens,256,100000,&commands,&tf,&metrics)||!commands_equal(commands,shared->expression.f.commands,shared->expression.f.count)){result=6;break;}if(!probe_recursive(&shared->expression_source.document,&shared->tokens,256,100000,&commands,&tf,&metrics)||!commands_equal(commands,shared->expression.f.commands,shared->expression.f.count)||ube_err_number()!=77){result=7;break;}
#endif
    }
    for(int i=2;i>=0;--i)if(!ube_gc_root_leave(&roots[i]))result=8;worker->result=result;return result;
}
static int workers(void){
    struct actor_environment shared;CHECK(actor_environment_open(&shared,3,1)==0);
#ifdef OBSERVE_PROBES
    atomic_store(&global_root_peak,parser_probe_root_count());
#endif
    struct worker_arguments args[4]={0};HANDLE threads[4];for(int i=0;i<4;++i){args[i].shared=&shared;threads[i]=CreateThread(NULL,0,worker_main,&args[i],0,NULL);CHECK(threads[i]!=NULL);}CHECK(WaitForMultipleObjects(4,threads,TRUE,60000)==WAIT_OBJECT_0);for(int i=0;i<4;++i){DWORD code=99;CHECK(GetExitCodeThread(threads[i],&code)&&code==0&&args[i].result==0&&CloseHandle(threads[i]));}CHECK(source_equal(&shared.source,shared.tree.f.source,shared.tree.f.bytes)&&commands_equal(shared.input,shared.tree.f.commands,shared.tree.f.count));CHECK(actor_environment_close(&shared)==0);printf("{\"suite\":\"workers\",\"passed\":true,\"workers\":4,\"observedPeakRootRecords\":%zu}\n",atomic_load(&global_root_peak));return 0;
}
#ifdef OBSERVE_PROBES
static int allocation_faults(void){
    struct actor_environment e;CHECK(actor_environment_open(&e,65,32)==0);size_t boundaries=0;
    for(int actor=0;actor<actor_count();++actor){
        if(fault_actor>=0&&actor!=fault_actor)continue;
        e.output=actor_old(&e,actor);seed();start_observation(0);int ok=actor_call(&e,actor);stop_observation();CHECK(ok&&actor_kind(&e,actor)==0&&actor_success(&e,actor)&&ube_err_number()==77);size_t allocations=observed.allocations;CHECK(allocations>0);e.output=actor_old(&e,actor);(void)ube_gc_collect();size_t retained=ube_gc_live_allocation_bytes();
        for(size_t at=1;at<=allocations;++at){if(fault_boundary&&at!=fault_boundary)continue;if(fault_actor>=0||fault_boundary){fprintf(stderr,"REPRO fault actor%d boundary%zu\n",actor,at);fflush(stderr);}e.output=actor_old(&e,actor);e.failure=(struct storage_failure){5,-1};e.traversal_failure=(struct traversal_failure){5,0,0};seed();size_t roots=parser_probe_root_count();start_observation(at);ok=actor_call(&e,actor);stop_observation();if(ok||actor_kind(&e,actor)!=5)fprintf(stderr,"fault actor%d boundary%zu status%d kind%d\n",actor,at,ok,actor_kind(&e,actor));CHECK(!ok&&actor_kind(&e,actor)==5&&ube_err_number()==7&&actor_old_equal(&e,actor));CHECK(parser_probe_root_count()==roots);(void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==retained);++boundaries;}
    }
    CHECK(boundaries>0&&actor_environment_close(&e)==0);printf("{\"suite\":\"faults\",\"passed\":true,\"boundaries\":%zu}\n",boundaries);return 0;
}
static int root_pressure(void){
    struct actor_environment e;CHECK(actor_environment_open(&e,3,1)==0);size_t needed[6]={0},successes[6]={0};size_t maximum=0;
    for(int actor=0;actor<actor_count();++actor){e.output=actor_old(&e,actor);seed();size_t before=parser_probe_root_count();start_observation(0);int ok=actor_call(&e,actor);stop_observation();CHECK(ok&&actor_success(&e,actor)&&actor_kind(&e,actor)==0&&ube_err_number()==77&&parser_probe_root_count()==before);CHECK(observed.root_peak>before);needed[actor]=observed.root_peak-before+1;CHECK(needed[actor]<2048);if(needed[actor]>maximum)maximum=needed[actor];}
    e.output=e.old_commands;(void)ube_gc_collect();size_t baseline=parser_probe_root_count(),capacity=parser_probe_max_roots()-baseline;root* roots=calloc(capacity,sizeof(root));void** holders=calloc(capacity,sizeof(void*));CHECK(roots&&holders);for(size_t i=0;i<capacity;++i)CHECK(ube_gc_root_enter(&roots[i],&holders[i]));size_t attempts=0;
    for(size_t remaining=0;remaining<=maximum;++remaining){if(remaining)CHECK(ube_gc_root_leave(&roots[capacity-remaining]));size_t count=parser_probe_root_count();for(int actor=0;actor<actor_count();++actor){if(remaining>needed[actor])continue;__atomic_store_n(&e.output,actor_old(&e,actor),__ATOMIC_SEQ_CST);seed();start_observation(0);int ok=actor_call(&e,actor);stop_observation();if(!ok&&actor_kind(&e,actor)!=5)fprintf(stderr,"roots actor%d remaining%zu kind%d\n",actor,remaining,actor_kind(&e,actor));CHECK(parser_probe_root_count()==count);if(ok){CHECK(actor_success(&e,actor)&&actor_kind(&e,actor)==0&&ube_err_number()==77);++successes[actor];}else CHECK(actor_kind(&e,actor)==5&&ube_err_number()==7&&actor_old_equal(&e,actor));CHECK(linked_equal(e.old_linked,&e.old_tree.f,919)&&edge_equal(e.old_edged,&e.old_tree.f,919));++attempts;}}
    for(int actor=0;actor<actor_count();++actor)CHECK(successes[actor]>0);for(size_t i=capacity-maximum;i>0;--i)CHECK(ube_gc_root_leave(&roots[i-1]));free(holders);free(roots);CHECK(parser_probe_root_count()==baseline&&actor_environment_close(&e)==0);printf("{\"suite\":\"roots\",\"passed\":true,\"realBacked\":true,\"attempts\":%zu,\"maximumRemaining\":%zu}\n",attempts,maximum);return 0;
}
#endif
int main(int argc,char** argv){
    const char* only=NULL;const char* stress=NULL;const char* suite=NULL;int32_t size=0;bool measure=false;for(int i=1;i<argc;i+=2){if(i+1>=argc){fprintf(stderr,"missing probe argument\n");return 2;}if(strcmp(argv[i],"--case")==0)only=argv[i+1];else if(strcmp(argv[i],"--method")==0){method_only=atoi(argv[i+1]);if(method_only<0||method_only>1)return 2;}else if(strcmp(argv[i],"--stress")==0)stress=argv[i+1];else if(strcmp(argv[i],"--size")==0)size=atoi(argv[i+1]);else if(strcmp(argv[i],"--measure")==0)measure=atoi(argv[i+1])!=0;else if(strcmp(argv[i],"--fault")==0){fault_actor=atoi(argv[i+1]);if(fault_actor<0||fault_actor>=actor_count())return 2;}else if(strcmp(argv[i],"--boundary")==0){int32_t n=atoi(argv[i+1]);if(n<1)return 2;fault_boundary=(size_t)n;}else if(strcmp(argv[i],"--suite")==0)suite=argv[i+1];else return 2;}(void)size;(void)measure;
    const size_t layouts[]={sizeof(struct input),sizeof(struct document),sizeof(struct source_failure),sizeof(struct command),sizeof(struct storage_failure),sizeof(struct linked_node),sizeof(struct edge_node),sizeof(struct linked_result),sizeof(struct edge_result),sizeof(struct walk_frame),sizeof(struct command_builder)
#ifdef PROBE_TRAVERSAL
    ,sizeof(struct token),sizeof(struct traversal_failure),sizeof(struct traversal_metrics),16,8
#endif
    };
    CHECK(ube_gc_root_storage_size()==sizeof(root));for(size_t i=0;i<sizeof layouts/sizeof *layouts;++i)CHECK(parser_probe_layout((int32_t)i)==layouts[i]);
    if(suite){
#ifdef OBSERVE_PROBES
        if(strcmp(suite,"roots")==0){CHECK(root_pressure()==0);}else if(strcmp(suite,"costs")==0){
#ifdef PROBE_STORAGE
            CHECK(storage_samples()==0);
#else
            CHECK(traversal_samples()==0);
#endif
        }else return 2;printf("PASS diagnostic parser probes assertions:%u\n",assertions);return 0;
#else
        return 2;
#endif
    }
    if(fault_actor>=0||fault_boundary){
#ifdef OBSERVE_PROBES
        CHECK(allocation_faults()==0);printf("PASS parser probes assertions:%u cases:1\n",assertions);return 0;
#else
        return 2;
#endif
    }
    if(stress){
#ifdef PROBE_TRAVERSAL
        CHECK(expression_stress(stress,size,measure)==0);printf("PASS parser probes assertions:%u cases:1\n",assertions);return 0;
#else
        return 2;
#endif
    }
    size_t count=0;for(size_t i=0;i<sizeof fixtures/sizeof *fixtures;++i){
#ifdef PROBE_STORAGE
        if(!only||strcmp(only,fixtures[i].name)==0){CHECK(storage_fixture(&fixtures[i],1000+(int32_t)i,false)==0);++count;}
#endif
    }
#ifdef PROBE_TRAVERSAL
    for(size_t i=0;i<sizeof expression_cases/sizeof *expression_cases;++i){if(!only||strcmp(only,expression_cases[i].name)==0){CHECK(traversal_fixture(&expression_cases[i],false,false)==0);++count;}}
#else
    (void)expression_cases;
#endif
    printf("{\"suite\":\"fixtures\",\"passed\":true,\"cases\":%zu}\n",count);
    if(!only){CHECK(storage_domains()==0);CHECK(workers()==0);}
#ifndef PROBE_STORAGE
    (void)storage_fixture;
#endif
    (void)print_observation;(void)storage_samples;(void)actor_call;(void)actor_kind;(void)actor_success;(void)actor_old_equal;(void)actor_count;
#ifdef OBSERVE_PROBES
    if(!only){CHECK(allocation_faults()==0);CHECK(root_pressure()==0);}
#ifdef PROBE_STORAGE
    if(!only)CHECK(storage_samples()==0);
#endif
#ifdef PROBE_TRAVERSAL
    if(!only)CHECK(traversal_samples()==0);
#endif
#else
    (void)storage_samples;
#ifdef PROBE_TRAVERSAL
    (void)traversal_samples;
#endif
#endif
#ifdef OBSERVE_PROBES
    CHECK(parser_probe_root_count()==0);
#endif
    (void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==0&&count>0);printf("PASS parser probes assertions:%u cases:%zu\n",assertions,count);return 0;
}
