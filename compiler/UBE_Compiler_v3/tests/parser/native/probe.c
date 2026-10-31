#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <errno.h>
#include "../../../../../runtime/value_storage.h"

struct position { int32_t byte,scalar,line,column; };
struct source_failure { int32_t kind;struct position position; };
struct decoder { int32_t remaining,accumulator,minimum;bool failed; };
struct buffer { void* storage;int32_t count; };
struct document { void* bytes;int32_t content,scalars,lines; };
struct input { struct buffer buffer;struct decoder decoder;struct position cursor,sequence,carriage;int32_t content,maximum;bool pending,ready; };
struct token { int32_t kind;struct position first,last; };
struct scan_failure { int32_t kind;struct position first,last; };
struct syntax_node { int32_t kind,first,last,first_child,next_sibling,children; };
struct syntax_result { void* nodes;int32_t count,root,source; };
struct syntax_failure { int32_t kind,first,last; };
struct syntax_metrics { int32_t reads,actions,names,pending,depth; };
struct expression_frame { int32_t integers[8];bool flags[4];int32_t call_kind; };
struct control_frame { int32_t integers[7];bool flags[3]; };
struct parser_case { const char* name;const uint8_t* source;int32_t bytes,entry,success;const struct syntax_node* nodes;int32_t count,root;struct syntax_failure failure;int32_t check_failure_span; };
typedef union { uint64_t alignment;uint8_t bytes[32]; } root;
#include "oracles.h"
extern int32_t parser_begin(struct input*,int32_t),parser_append(struct input*,void**,int32_t,int32_t,struct source_failure*),parser_finish(struct input*,struct document*,struct source_failure*);
extern int32_t parser_scan(struct document*,int32_t,int32_t,void**,struct scan_failure*);
extern int32_t parser_parse(struct document*,void**,int32_t,int32_t,int32_t,int32_t,int32_t,void**,struct syntax_failure*,struct syntax_metrics*);
extern int32_t parser_source(struct document*,int32_t,int32_t,int32_t,int32_t,int32_t,void**,struct syntax_failure*,struct syntax_metrics*);
extern size_t parser_layout(int32_t),ube_gc_root_storage_size(void),ube_gc_live_allocation_bytes(void);
extern int32_t parser_layout_role(const struct ube_value_layout*),ube_gc_root_enter(void*,void**),ube_gc_root_leave(void*),ube_gc_collect(void),ube_err_number(void);
extern void ube_err_set(int32_t,const char*,const char*);
extern void* ube_array_element(void*,int32_t);
#ifdef PARSER_OBSERVED
extern size_t parser_root_count(void),parser_root_limit(void),parser_array_header_size(void),parser_gc_header_size(void);
#endif

enum { ROLE_BYTE=1,ROLE_NODE=2,ROLE_RESULT=3,ROLE_TOKEN=4,ROLE_LONG=5,ROLE_EXPRESSION=6,ROLE_CONTROL=7,ROLE_COUNT=8 };
struct workspace { void* slot;int role;size_t live,required,capacity,stride,growth;bool current; };
struct observations {
    bool active;size_t allocations,requested,zeroed,fail_at,root_peak,events[9],source_copies;
    size_t growth[ROLE_COUNT],trim[ROLE_COUNT],publication,other_copies,byte_reads,capacity[ROLE_COUNT];
    size_t maximum_live_nodes,workspace_instances,workspace_live_sum,workspace_requested_sum,workspace_budget_violations;
    struct workspace workspace[64];size_t workspace_slots;
    int copy_class,copy_role,copy_workspace;
};
static _Thread_local struct observations observed;
static _Thread_local unsigned assertions;
static _Thread_local const char* case_name;
static _Thread_local size_t measured_source_bytes;
static const char* admission_only;
static int root_actor=-1,root_first=0,root_last=INT_MAX;
static int command_integer(const char* text,int maximum,int* value) { char* end=NULL;errno=0;long parsed=strtol(text,&end,10);if(errno||end==text||*end||parsed<0||parsed>maximum)return 0;*value=(int)parsed;return 1; }
#define CHECK(x) do { ++assertions;if(!(x)){fprintf(stderr,"parser assertion %u case %s line %d: %s\n",assertions,case_name?case_name:"native",__LINE__,#x);return 1;} } while(0)
void parser_root_changed(size_t count) { if(observed.active&&count>observed.root_peak)observed.root_peak=count; }
void parser_node_live(int32_t count) { if(observed.active&&count>0&&(size_t)count>observed.maximum_live_nodes)observed.maximum_live_nodes=(size_t)count; }
static int workspace_find(int role,void* slot) { for(size_t i=0;i<observed.workspace_slots;++i)if(observed.workspace[i].role==role&&observed.workspace[i].slot==slot)return (int)i;return -1; }
static void workspace_finish(struct workspace* workspace) {
    if(!workspace->current)return;workspace->current=false;++observed.workspace_instances;observed.workspace_live_sum+=workspace->live;observed.workspace_requested_sum+=workspace->required;
    if(workspace->growth>2*workspace->stride*workspace->required+8*workspace->stride||workspace->capacity>(workspace->required*2>8?workspace->required*2:8))++observed.workspace_budget_violations;
}
void parser_workspace_before(int32_t role,void* slot,void* count_slot) {
    if(!observed.active)return;int index=workspace_find(role,slot);if(index<0){if(observed.workspace_slots>=64){++observed.workspace_budget_violations;return;}index=(int)observed.workspace_slots++;observed.workspace[index]=(struct workspace){.slot=slot,.role=role};}
    struct workspace* workspace=observed.workspace+index;int32_t count=*(int32_t*)count_slot;
    if(count==0){workspace_finish(workspace);*workspace=(struct workspace){.slot=slot,.role=role,.current=true};}
    if(count<0){++observed.workspace_budget_violations;return;}if((size_t)count+1>workspace->required)workspace->required=(size_t)count+1;
}
void parser_workspace_after(int32_t role,void* slot,void* count_slot,int32_t success) {
    if(!observed.active||!success)return;int index=workspace_find(role,slot);if(index<0){++observed.workspace_budget_violations;return;}int32_t count=*(int32_t*)count_slot;if(count<0){++observed.workspace_budget_violations;return;}if((size_t)count>observed.workspace[index].live)observed.workspace[index].live=(size_t)count;
}
static bool allocation_fails(size_t bytes) { if(!observed.active)return false;++observed.allocations;observed.requested+=bytes;return observed.fail_at&&observed.allocations>=observed.fail_at; }
void* probe_malloc(size_t bytes) { if(allocation_fails(bytes))return NULL;return malloc(bytes); }
void* probe_calloc(size_t count,size_t bytes) { if(bytes&&count>SIZE_MAX/bytes)return NULL;if(allocation_fails(count*bytes))return NULL;void* value=calloc(count,bytes);if(observed.active&&value)observed.zeroed+=count*bytes;return value; }
void* probe_realloc(void* old,size_t bytes) { if(allocation_fails(bytes))return NULL;return realloc(old,bytes); }
void probe_free(void* value) { free(value); }
void probe_value_copy(size_t bytes) {
    if(!observed.active)return;if(bytes==1&&observed.copy_role!=ROLE_EXPRESSION&&observed.copy_role!=ROLE_CONTROL)observed.source_copies+=bytes;
    if(observed.copy_class==1){observed.growth[observed.copy_role]+=bytes;if(observed.copy_workspace>=0)observed.workspace[observed.copy_workspace].growth+=bytes;}
    else if(observed.copy_class==2)observed.trim[observed.copy_role]+=bytes;
    else if(observed.copy_class==3)observed.publication+=bytes;
    else observed.other_copies+=bytes;
}
void parser_event(int32_t event) { if(observed.active&&event>0&&event<9)++observed.events[event]; }
int32_t parser_runtime_resize(void** holder,int32_t count,const struct ube_value_layout* layout,int32_t preserve) {
    int32_t before=ube_value_array_length(holder);int role=parser_layout_role(layout);if(role<0||role>=ROLE_COUNT)role=0;
    int old_class=observed.copy_class,old_role=observed.copy_role,old_workspace=observed.copy_workspace;observed.copy_role=role;observed.copy_class=preserve?(count<=before?2:1):0;observed.copy_workspace=workspace_find(role,holder);
    int32_t ok=ube_value_try_resize(holder,count,layout,preserve);
    if(observed.active&&ok&&count>=0&&(size_t)count>observed.capacity[role])observed.capacity[role]=(size_t)count;
    if(observed.active&&observed.copy_workspace>=0){struct workspace* workspace=observed.workspace+observed.copy_workspace;workspace->stride=layout->size;if(ok&&count>=0&&(size_t)count>workspace->capacity)workspace->capacity=(size_t)count;}
    observed.copy_class=old_class;observed.copy_role=old_role;observed.copy_workspace=old_workspace;return ok;
}
int32_t parser_runtime_assign(void* destination,const void* source,const struct ube_value_layout* layout) {
    int old=observed.copy_class;observed.copy_class=3;int32_t ok=ube_value_assign(destination,source,layout);observed.copy_class=old;return ok;
}
void* parser_runtime_element(void* const* holder,int32_t index,void** keep,void* fallback,const struct ube_value_layout* layout) {
    if(observed.active&&parser_layout_role(layout)==ROLE_BYTE)++observed.byte_reads;
    return ube_value_array_element(holder,index,keep,fallback,layout);
}
static void observation_start(size_t fail_at) {
    observed=(struct observations){.active=true,.fail_at=fail_at,.copy_workspace=-1};
#ifdef PARSER_OBSERVED
    observed.root_peak=parser_root_count();
#endif
}
static void observation_stop(void) { for(size_t i=0;i<observed.workspace_slots;++i)workspace_finish(observed.workspace+i);observed.active=false; }
static void seed(void) { ube_err_set(77,"prior error","parser acceptance"); }
static const struct ube_value_layout byte_layout={1,0,0,NULL,0,NULL};
static int bytes_array(void** result,const uint8_t* data,int32_t count) { if(!ube_value_try_resize(result,count,&byte_layout,0))return 0;for(int32_t i=0;i<count;++i)*(uint8_t*)ube_array_element(*result,i)=data[i];return 1; }
struct source_owner { struct input input;struct document document,saved_document;void* bytes;root roots[3]; };
static int source_open(struct source_owner* owner,const uint8_t* bytes,int32_t count) {
    memset(owner,0,sizeof *owner);struct source_failure failure={0};
    int ok=ube_gc_root_enter(&owner->roots[0],&owner->input.buffer.storage)&&ube_gc_root_enter(&owner->roots[1],&owner->document.bytes)&&ube_gc_root_enter(&owner->roots[2],&owner->bytes)&&bytes_array(&owner->bytes,bytes,count)&&parser_begin(&owner->input,count)&&parser_append(&owner->input,&owner->bytes,0,count,&failure)&&parser_finish(&owner->input,&owner->document,&failure);if(ok)owner->saved_document=owner->document;return ok;
}
static int source_close(struct source_owner* owner) { for(int i=2;i>=0;--i)if(!ube_gc_root_leave(&owner->roots[i]))return 0;return 1; }
static int source_equal(const struct source_owner* owner,const uint8_t* bytes,int32_t count) { if(owner->document.bytes!=owner->saved_document.bytes||owner->document.content!=owner->saved_document.content||owner->document.scalars!=owner->saved_document.scalars||owner->document.lines!=owner->saved_document.lines||ube_value_array_length(&owner->document.bytes)!=count)return 0;for(int32_t i=0;i<count;++i)if(*(uint8_t*)ube_array_element(owner->document.bytes,i)!=bytes[i])return 0;return 1; }

/* All actual nodes must form one ordered, span-contained tree, including
   details omitted by a leaf Header logical witness. This detects hidden nodes,
   sharing, cycles, detached records and corrupt child/sibling counts. */
static int graph_valid(const struct syntax_result* result,int32_t bytes) {
    if(result->count<1||result->root<0||result->root>=result->count||ube_value_array_length(&result->nodes)!=result->count)return 0;
    uint8_t* seen=calloc((size_t)result->count,1);int32_t* pending=malloc((size_t)result->count*sizeof *pending);if(!seen||!pending){free(seen);free(pending);return 0;}
    int32_t count=1,visited=0;pending[0]=result->root;int valid=1;
    struct syntax_node root_node=*(struct syntax_node*)ube_array_element(result->nodes,result->root);if(root_node.next_sibling!=-1)valid=0;
    while(count&&valid){int32_t index=pending[--count];if(index<0||index>=result->count||seen[index]){valid=0;break;}seen[index]=1;++visited;
        struct syntax_node node=*(struct syntax_node*)ube_array_element(result->nodes,index);
        if(node.kind<1||node.first<0||node.last<node.first||node.last>bytes||node.children<0||node.children>=result->count){valid=0;break;}
        int32_t child=node.first_child,previous=node.first;
        for(int32_t i=0;i<node.children;++i){if(child<0||child>=result->count||count>=result->count){valid=0;break;}struct syntax_node item=*(struct syntax_node*)ube_array_element(result->nodes,child);if(item.first<previous||item.last>node.last){valid=0;break;}previous=item.last;pending[count++]=child;child=item.next_sibling;}
        if(child!=-1)valid=0;
    }
    valid=valid&&visited==result->count;free(seen);free(pending);return valid;
}
struct node_pair { int32_t actual,expected; };
static int graph_equal(void* published,const struct parser_case* expected,int32_t source_id) {
    if(ube_value_array_length(&published)!=1)return 0;struct syntax_result result=*(struct syntax_result*)ube_array_element(published,0);
    if(result.source!=source_id||!graph_valid(&result,expected->bytes))return 0;
    struct node_pair* pending=malloc((size_t)expected->count*sizeof *pending);if(!pending)return 0;
    int32_t count=1,visited=0;pending[0]=(struct node_pair){result.root,expected->root};int equal=1;
    while(count&&equal){struct node_pair pair=pending[--count];if(pair.expected<0||pair.expected>=expected->count){equal=0;break;}
        struct syntax_node actual=*(struct syntax_node*)ube_array_element(result.nodes,pair.actual);struct syntax_node wanted=expected->nodes[pair.expected];
#ifdef NEGATIVE_PARSER_KIND
        if(!visited){++actual.kind;fprintf(stderr,"NEGATIVE_PARSER_KIND\n");}
#endif
#ifdef NEGATIVE_PARSER_SPAN
        if(!visited){++actual.first;fprintf(stderr,"NEGATIVE_PARSER_SPAN\n");}
#endif
        ++visited;if(actual.kind!=wanted.kind||actual.first!=wanted.first||actual.last!=wanted.last){fprintf(stderr,"%s kind/span actual %d[%d,%d] expected %d[%d,%d]\n",expected->name,actual.kind,actual.first,actual.last,wanted.kind,wanted.first,wanted.last);equal=0;break;}
        /* The contract permits Header witnesses to select no detail children.
           No other kind gets a selective or prefix comparison. */
        if(wanted.kind==50&&wanted.children==0)continue;
        if(actual.children!=wanted.children){fprintf(stderr,"%s kind%d children actual%d expected%d\n",expected->name,actual.kind,actual.children,wanted.children);equal=0;break;}
        int32_t a=actual.first_child,e=wanted.first_child;
        for(int32_t i=0;i<wanted.children;++i){if(a<0||e<0||count>=expected->count){equal=0;break;}pending[count++]=(struct node_pair){a,e};a=((struct syntax_node*)ube_array_element(result.nodes,a))->next_sibling;e=expected->nodes[e].next_sibling;}
        if(a!=-1||e!=-1)equal=0;
    }
    equal=equal&&visited==expected->count;free(pending);return equal;
}
#ifdef PARSER_OBSERVED
#include "expression-shapes.h"
#include "control-shapes.h"
#endif
static const uint8_t old_source_bytes[]="old+kept*saved";
static int old_output(void** output,struct source_owner* owner) {
    if(!source_open(owner,old_source_bytes,sizeof old_source_bytes-1))return 0;struct syntax_failure failure={5,0,0};struct syntax_metrics metrics={0};
    int ok=parser_source(&owner->document,1,919,100,100,256,output,&failure,&metrics);if(!ok||failure.kind!=0||ube_value_array_length(output)!=1)return 0;struct syntax_result result=*(struct syntax_result*)ube_array_element(*output,0);return result.count==5&&result.source==919&&graph_valid(&result,sizeof old_source_bytes-1);
}
static struct syntax_node* snapshot_nodes(struct syntax_result result) {
    if(result.count<1||ube_value_array_length(&result.nodes)!=result.count)return NULL;struct syntax_node* nodes=malloc((size_t)result.count*sizeof *nodes);if(!nodes)return NULL;for(int32_t i=0;i<result.count;++i)nodes[i]=*(struct syntax_node*)ube_array_element(result.nodes,i);return nodes;
}
static int old_equal(void* output,void* prior,void* nodes,struct syntax_result old,const struct syntax_node* expected_nodes) {
    if(output!=prior||ube_value_array_length(&output)!=1)return 0;struct syntax_result result=*(struct syntax_result*)ube_array_element(output,0);
    if(result.nodes!=nodes||result.count!=old.count||result.root!=old.root||result.source!=old.source)return 0;
    if(ube_value_array_length(&result.nodes)!=old.count)return 0;for(int32_t i=0;i<old.count;++i)if(memcmp(ube_array_element(result.nodes,i),expected_nodes+i,sizeof *expected_nodes))return 0;return 1;
}
static int fixture(const struct parser_case* expected,int32_t source_id) {
    case_name=expected->name;struct source_owner owner,old_owner;CHECK(source_open(&owner,expected->source,expected->bytes));void* output=NULL;root output_root={0};CHECK(ube_gc_root_enter(&output_root,&output)&&old_output(&output,&old_owner));
    void* prior=output;struct syntax_result old=*(struct syntax_result*)ube_array_element(output,0);struct syntax_node* old_nodes=snapshot_nodes(old);CHECK(old_nodes);
    struct syntax_failure failure={5,0,0};struct syntax_metrics metrics={0};seed();
    int ok=parser_source(&owner.document,expected->entry,source_id,100000,100000,256,&output,&failure,&metrics);
    if(ok!=expected->success||failure.kind!=expected->failure.kind)fprintf(stderr,"%s got status%d failure%d [%d,%d] expected status%d failure%d [%d,%d]\n",expected->name,ok,failure.kind,failure.first,failure.last,expected->success,expected->failure.kind,expected->failure.first,expected->failure.last);
    CHECK(ok==expected->success&&failure.kind==expected->failure.kind&&ube_err_number()==77);
    if(ok)CHECK(graph_equal(output,expected,source_id));
    else { CHECK(old_equal(output,prior,old.nodes,old,old_nodes));if(expected->failure.kind!=3||expected->check_failure_span)CHECK(failure.first==expected->failure.first&&failure.last==expected->failure.last); }
    CHECK(source_equal(&owner,expected->source,expected->bytes)&&source_equal(&old_owner,old_source_bytes,sizeof old_source_bytes-1));free(old_nodes);CHECK(ube_gc_root_leave(&output_root)&&source_close(&owner)&&source_close(&old_owner));(void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==0);return 0;
}

struct environment { struct source_owner source,old_source;void* tokens;void* output;void* old;root roots[3];struct syntax_result previous;struct syntax_node* previous_nodes;struct token* token_snapshot;int32_t token_count; };
static int environment_open(struct environment* value,const uint8_t* bytes,int32_t count) {
    memset(value,0,sizeof *value);CHECK(source_open(&value->source,bytes,count));void** slots[]={&value->tokens,&value->output,&value->old};for(int i=0;i<3;++i)CHECK(ube_gc_root_enter(&value->roots[i],slots[i]));
    struct scan_failure failure={5,{0},{0}};CHECK(parser_scan(&value->source.document,0,1048576,&value->tokens,&failure)&&old_output(&value->old,&value->old_source));value->output=value->old;value->previous=*(struct syntax_result*)ube_array_element(value->old,0);value->previous_nodes=snapshot_nodes(value->previous);CHECK(value->previous_nodes);
    value->token_count=ube_value_array_length(&value->tokens);value->token_snapshot=malloc((size_t)value->token_count*sizeof *value->token_snapshot);CHECK(value->token_snapshot);for(int32_t i=0;i<value->token_count;++i)value->token_snapshot[i]=*(struct token*)ube_array_element(value->tokens,i);measured_source_bytes=(size_t)ube_value_array_length(&value->source.document.bytes);return 0;
}
static int tokens_equal(const struct environment* value) { if(ube_value_array_length(&value->tokens)!=value->token_count)return 0;for(int32_t i=0;i<value->token_count;++i)if(memcmp(ube_array_element(value->tokens,i),value->token_snapshot+i,sizeof *value->token_snapshot))return 0;return 1; }
static int environment_close(struct environment* value) { CHECK(tokens_equal(value)&&source_equal(&value->old_source,old_source_bytes,sizeof old_source_bytes-1));free(value->token_snapshot);free(value->previous_nodes);for(int i=2;i>=0;--i)CHECK(ube_gc_root_leave(&value->roots[i]));CHECK(source_close(&value->source)&&source_close(&value->old_source));(void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==0);return 0; }
static int invoke(struct environment* value,int32_t entry,int32_t maximum_nodes,int32_t maximum_pending,int32_t maximum_depth,struct syntax_failure* failure,struct syntax_metrics* metrics) {
    *failure=(struct syntax_failure){5,0,0};*metrics=(struct syntax_metrics){0};return parser_parse(&value->source.document,&value->tokens,entry,811,maximum_nodes,maximum_pending,maximum_depth,&value->output,failure,metrics);
}
static int domains(void) {
    static const uint8_t bytes[]="a + b";struct environment value;CHECK(environment_open(&value,bytes,sizeof bytes-1)==0);struct syntax_failure failure;struct syntax_metrics metrics;
    const int32_t limits[][4]={{0,100,100,256},{4,100,100,256},{1,-1,100,256},{1,100,-1,256},{1,100,100,-1},{1,0,100,256},{1,2,100,256}};
    for(size_t i=0;i<sizeof limits/sizeof *limits;++i){value.output=value.old;seed();int ok=invoke(&value,limits[i][0],limits[i][1],limits[i][2],limits[i][3],&failure,&metrics);CHECK(!ok&&failure.kind==(i<5?1:2)&&ube_err_number()==77&&old_equal(value.output,value.old,value.previous.nodes,value.previous,value.previous_nodes));}
    value.output=value.old;seed();CHECK(invoke(&value,1,3,100,256,&failure,&metrics)&&failure.kind==0&&ube_err_number()==77);struct syntax_result result=*(struct syntax_result*)ube_array_element(value.output,0);CHECK(result.count==3&&graph_valid(&result,sizeof bytes-1));
    CHECK(environment_close(&value)==0);printf("{\"suite\":\"domains\",\"passed\":true,\"cases\":8}\n");return 0;
}
static int budgets(void) {
    static const struct { const char* source;int32_t entry,nodes,pending,depth; } cases[]={
        {"a",1,1,1,0},{"(a)",1,2,2,1},{"Print a",2,2,2,0},{"While a\nPrint a\nWend",2,5,4,1}
    };
    size_t checks=0;for(size_t sample=0;sample<sizeof cases/sizeof *cases;++sample){
        const uint8_t* bytes=(const uint8_t*)cases[sample].source;int32_t count=(int32_t)strlen(cases[sample].source);struct environment value;CHECK(environment_open(&value,bytes,count)==0);struct syntax_failure failure;struct syntax_metrics metrics;
        for(int dimension=0;dimension<3;++dimension)for(int adjustment=-1;adjustment<=1;++adjustment){
            int32_t minimum=dimension==0?cases[sample].nodes:(dimension==1?cases[sample].pending:cases[sample].depth);if(minimum+adjustment<0)continue;
            int32_t nodes=100,pending=100,depth=256;if(dimension==0)nodes=minimum+adjustment;if(dimension==1)pending=minimum+adjustment;if(dimension==2)depth=minimum+adjustment;
            value.output=value.old;(void)ube_gc_collect();seed();int ok=invoke(&value,cases[sample].entry,nodes,pending,depth,&failure,&metrics);CHECK(ok==(adjustment>=0)&&failure.kind==(adjustment>=0?0:2)&&ube_err_number()==77);
            if(ok){struct syntax_result result=*(struct syntax_result*)ube_array_element(value.output,0);CHECK(result.count==cases[sample].nodes&&graph_valid(&result,count));}else CHECK(old_equal(value.output,value.old,value.previous.nodes,value.previous,value.previous_nodes));CHECK(tokens_equal(&value)&&source_equal(&value.source,bytes,count)&&source_equal(&value.old_source,old_source_bytes,sizeof old_source_bytes-1));++checks;
        }
        CHECK(environment_close(&value)==0);
    }
    printf("{\"suite\":\"budgets\",\"passed\":true,\"cases\":%zu,\"dimensions\":\"nodes shared-pending syntax-depth\"}\n",checks);return 0;
}

static const struct parser_case* find_case(const char* name) { for(size_t i=0;i<sizeof parser_cases/sizeof *parser_cases;++i)if(strcmp(parser_cases[i].name,name)==0)return parser_cases+i;return NULL; }
struct worker { struct source_owner* source;void** tokens;const struct parser_case* expected;int result;unsigned checks; };
static DWORD WINAPI worker_run(void* argument) {
    struct worker* worker=argument;assertions=0;void* output=NULL;root output_root={0};int ok=ube_gc_root_enter(&output_root,&output);struct syntax_failure failure={5,0,0};struct syntax_metrics metrics={0};
    ube_err_set(63,"worker error","parser acceptance");
    for(int i=0;i<12&&ok;++i){ok=parser_parse(&worker->source->document,worker->tokens,worker->expected->entry,811,1000,1000,256,&output,&failure,&metrics)&&failure.kind==0&&ube_err_number()==63&&graph_equal(output,worker->expected,811);}
    if(!ube_gc_root_leave(&output_root))ok=0;worker->result=ok;worker->checks=assertions;return 0;
}
static int workers(void) {
    const char* samples[]={"additive-binds-less-tightly-than-multiplication","statement-nested-with-leading-member-association","native-unit-declarations-parameters-if-while-with"};
    for(size_t sample=0;sample<sizeof samples/sizeof *samples;++sample){const struct parser_case* expected=find_case(samples[sample]);CHECK(expected);struct environment value;CHECK(environment_open(&value,expected->source,expected->bytes)==0);struct worker workers[4]={0};HANDLE threads[4]={0};seed();
        for(int i=0;i<4;++i){workers[i].source=&value.source;workers[i].tokens=&value.tokens;workers[i].expected=expected;threads[i]=CreateThread(NULL,0,worker_run,&workers[i],0,NULL);CHECK(threads[i]!=NULL);}
        CHECK(WaitForMultipleObjects(4,threads,TRUE,30000)==WAIT_OBJECT_0);for(int i=0;i<4;++i){CHECK(workers[i].result);CHECK(CloseHandle(threads[i]));}
        CHECK(ube_err_number()==77&&source_equal(&value.source,expected->source,expected->bytes));CHECK(environment_close(&value)==0);
    }
    printf("{\"suite\":\"workers\",\"passed\":true,\"workers\":4,\"iterations\":12,\"samples\":3,\"comparison\":\"exact kinds grouping original spans and source identity\"}\n");return 0;
}

/* Focused source-admission witnesses are separate from the frozen116 cases.
   They check only the stated admission property, never full deferred grammar. */
static int admission(void) {
    static const struct { const char* name;const char* source;int32_t entry,success,kind; } cases[]={
        {"conditional-before-inactive-malformed-quote","UBE SOURCE 1 MODULE\nAttribute UBE_Name = \"Admission\"\n#If False Then\nDim Broken As String = \"unterminated\n#End If\n",3,0,3},
        {"apostrophe-comment-is-not-directive","UBE SOURCE 1 MODULE\nAttribute UBE_Name = \"Admission\"\n' #If False Then\n",3,1,0},
        {"rem-comment-is-not-directive","UBE SOURCE 1 MODULE\nAttribute UBE_Name = \"Admission\"\nRem #If False Then\n",3,1,0},
        {"quoted-text-is-not-directive","UBE SOURCE 1 MODULE\nAttribute UBE_Name = \"Admission\"\nDim X As String = \"#If False Then\"\n",3,1,0},
        {"continued-physical-line-is-not-directive","UBE SOURCE 1 MODULE\nAttribute UBE_Name = \"Admission\"\nDim X As Long = 1 _\n#If Flag Then\n",3,0,-3},
        {"malformed-quote-before-directive-retains-lexical-error","UBE SOURCE 1 MODULE\nAttribute UBE_Name = \"Admission\"\nDim X As String = \"unterminated\n#If False Then\n#End If\n",3,0,202},
        {"file-number-before-pending-directive","UBE SOURCE 1 MODULE\nAttribute UBE_Name = \"Admission\"\nSub Work()\nPrint #1, 2\n#If False Then\nDim Broken As String = \"unterminated\n#End If\nEnd Sub\n",3,0,3},
        {"then-rem-before-pending-directive","If True Then Rem \"unclosed\n#If False Then\nDim Broken As String = \"unterminated\n#End If\n",2,0,3},
        {"else-rem-before-pending-directive","If True Then F Else Rem \"unclosed\n#If False Then\nDim Broken As String = \"unterminated\n#End If\n",2,0,3},
        {"member-rem-is-not-comment","Call obj.Rem(\"unclosed\n#If False Then\n#End If\n",2,0,202},
        {"argument-rem-is-not-comment","Call F(Rem, \"unclosed\n#If False Then\n#End If\n",2,0,202},
        {"bracketed-member-rem-is-not-comment","Call [Then].Rem(\"unclosed\n#If False Then\n#End If\n",2,0,202},
        {"bracketed-argument-rem-is-not-comment","Call F([Rem], \"unclosed\n#If False Then\n#End If\n",2,0,202},
        {"native-class-body-deferred","UBE SOURCE 1 CLASS\nAttribute UBE_Name = \"Admission\"\n",3,0,3},
        {"native-form-body-deferred","UBE SOURCE 1 FORM\nAttribute UBE_Name = \"Admission\"\n",3,0,3},
        {"native-control-body-deferred","UBE SOURCE 1 CONTROL\nAttribute UBE_Name = \"Admission\"\n",3,0,3},
        {"legacy-module-body-deferred","Attribute VB_Name = \"Legacy\"\nSub Work()\nEnd Sub\n",3,0,3}
    };
    size_t count_cases=0;for(size_t i=0;i<sizeof cases/sizeof *cases;++i){
        if(admission_only&&strcmp(admission_only,cases[i].name)!=0)continue;++count_cases;
        case_name=cases[i].name;const uint8_t* bytes=(const uint8_t*)cases[i].source;int32_t count=(int32_t)strlen(cases[i].source);struct source_owner owner,old_owner;CHECK(source_open(&owner,bytes,count));void* output=NULL;root output_root={0};CHECK(ube_gc_root_enter(&output_root,&output)&&old_output(&output,&old_owner));
        void* prior=output;struct syntax_result old=*(struct syntax_result*)ube_array_element(output,0);struct syntax_node* old_nodes=snapshot_nodes(old);CHECK(old_nodes);struct syntax_failure failure={5,0,0};struct syntax_metrics metrics={0};seed();
        int ok=parser_source(&owner.document,cases[i].entry,971,1000,1000,256,&output,&failure,&metrics);int kind_ok=cases[i].kind==-3?failure.kind!=3:failure.kind==cases[i].kind;
        if(ok!=cases[i].success||!kind_ok)fprintf(stderr,"admission %s got status%d kind%d [%d,%d] expected%d kind%d\n",cases[i].name,ok,failure.kind,failure.first,failure.last,cases[i].success,cases[i].kind);
        CHECK(ok==cases[i].success&&kind_ok&&ube_err_number()==77);if(!ok)CHECK(old_equal(output,prior,old.nodes,old,old_nodes));else{struct syntax_result result=*(struct syntax_result*)ube_array_element(output,0);CHECK(graph_valid(&result,count));}
        CHECK(source_equal(&owner,bytes,count)&&source_equal(&old_owner,old_source_bytes,sizeof old_source_bytes-1));free(old_nodes);CHECK(ube_gc_root_leave(&output_root)&&source_close(&owner)&&source_close(&old_owner));(void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==0);
    }
    CHECK(count_cases>0);printf("{\"suite\":\"admission\",\"passed\":true,\"cases\":%zu}\n",count_cases);return 0;
}

#ifdef PARSER_OBSERVED
static const char* actor_names[]={"postfix-member-application-member-chain","statement-nested-with-leading-member-association","native-unit-declarations-parameters-if-while-with","native-unit-declarations-parameters-if-while-with"};
static int actor_invoke(struct environment* value,const struct parser_case* expected,int actor,struct syntax_failure* failure,struct syntax_metrics* metrics) {
    *failure=(struct syntax_failure){5,0,0};*metrics=(struct syntax_metrics){0};
    if(actor==3)return parser_source(&value->source.document,expected->entry,811,10000,10000,256,&value->output,failure,metrics);
    return parser_parse(&value->source.document,&value->tokens,expected->entry,811,10000,10000,256,&value->output,failure,metrics);
}
static int faults(void) {
    size_t total=0;for(int actor=0;actor<4;++actor){
        const struct parser_case* expected=find_case(actor_names[actor]);CHECK(expected);case_name=expected->name;struct environment value;CHECK(environment_open(&value,expected->source,expected->bytes)==0);struct syntax_failure failure;struct syntax_metrics metrics;seed();observation_start(0);CHECK(actor_invoke(&value,expected,actor,&failure,&metrics));observation_stop();size_t boundaries=observed.allocations;CHECK(boundaries>0&&graph_equal(value.output,expected,811));
        for(size_t boundary=1;boundary<=boundaries;++boundary){value.output=value.old;(void)ube_gc_collect();size_t root_count=parser_root_count(),live_bytes=ube_gc_live_allocation_bytes();seed();observation_start(boundary);int ok=actor_invoke(&value,expected,actor,&failure,&metrics);observation_stop();
            if(ok||failure.kind!=5)fprintf(stderr,"fault actor%d boundary%zu status%d kind%d Err%d\n",actor,boundary,ok,failure.kind,ube_err_number());
            CHECK(!ok&&failure.kind==5&&ube_err_number()==7&&old_equal(value.output,value.old,value.previous.nodes,value.previous,value.previous_nodes));CHECK(parser_root_count()==root_count&&tokens_equal(&value));CHECK(source_equal(&value.source,expected->source,expected->bytes)&&source_equal(&value.old_source,old_source_bytes,sizeof old_source_bytes-1));(void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==live_bytes);
        }
        seed();CHECK(actor_invoke(&value,expected,actor,&failure,&metrics)&&failure.kind==0&&ube_err_number()==77&&graph_equal(value.output,expected,811));CHECK(environment_close(&value)==0);total+=boundaries;
    }
    printf("{\"suite\":\"faults\",\"passed\":true,\"persistent\":true,\"actors\":4,\"boundaries\":%zu}\n",total);return 0;
}
static int roots(void) {
    size_t total=0,actors=0;for(int actor=0;actor<4;++actor){
        if(root_actor>=0&&root_actor!=actor)continue;
        ++actors;
        const struct parser_case* expected=find_case(actor_names[actor]);CHECK(expected);case_name=expected->name;struct environment value;CHECK(environment_open(&value,expected->source,expected->bytes)==0);struct syntax_failure failure;struct syntax_metrics metrics;
        size_t before=parser_root_count();observation_start(0);CHECK(actor_invoke(&value,expected,actor,&failure,&metrics));observation_stop();CHECK(observed.root_peak>before&&graph_equal(value.output,expected,811));size_t required=observed.root_peak-before;
        size_t first=(size_t)root_first,last=(size_t)root_last;if(last>required)last=required;CHECK(first<=last);
        fprintf(stderr,"ROOT actor=%d required=%zu first=%zu last=%zu\n",actor,required,first,last);fflush(stderr);
        value.output=value.old;(void)ube_gc_collect();size_t capacity=parser_root_limit()-parser_root_count();root* backed=calloc(capacity,sizeof *backed);void** holders=calloc(capacity,sizeof *holders);CHECK(backed&&holders&&capacity>=required);
        for(size_t i=0;i<capacity;++i)CHECK(ube_gc_root_enter(&backed[i],&holders[i]));CHECK(parser_root_count()==parser_root_limit());size_t successes=0,attempts=0;
        for(size_t released=0;released<first;++released)CHECK(ube_gc_root_leave(&backed[capacity-1-released]));
        for(size_t available=first;available<=last;++available){if(available>first)CHECK(ube_gc_root_leave(&backed[capacity-available]));if(available==first||available%16==0){fprintf(stderr,"ROOT-PROGRESS actor=%d available=%zu required=%zu\n",actor,available,required);fflush(stderr);}value.output=value.old;(void)ube_gc_collect();size_t baseline=parser_root_count(),live_bytes=ube_gc_live_allocation_bytes();seed();int ok=actor_invoke(&value,expected,actor,&failure,&metrics);
            CHECK(baseline==parser_root_limit()-available&&parser_root_count()==baseline);if(ok){CHECK(failure.kind==0&&ube_err_number()==77&&graph_equal(value.output,expected,811));++successes;}else{CHECK(failure.kind==5&&ube_err_number()==7&&old_equal(value.output,value.old,value.previous.nodes,value.previous,value.previous_nodes));(void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==live_bytes);}CHECK(tokens_equal(&value)&&source_equal(&value.source,expected->source,expected->bytes)&&source_equal(&value.old_source,old_source_bytes,sizeof old_source_bytes-1));++attempts;
        }
        if(last==required)CHECK(successes>0);for(size_t i=capacity-last;i>0;--i)CHECK(ube_gc_root_leave(&backed[i-1]));free(backed);free(holders);CHECK(environment_close(&value)==0);total+=attempts;
        fprintf(stderr,"ROOT-COMPLETE actor=%d attempts=%zu\n",actor,attempts);fflush(stderr);
        printf("{\"suite\":\"root-range\",\"passed\":true,\"realBacked\":true,\"actor\":%d,\"first\":%zu,\"last\":%zu,\"required\":%zu,\"attempts\":%zu,\"successes\":%zu,\"registryLimit\":%zu,\"backedRoots\":%zu}\n",actor,first,last,required,attempts,successes,parser_root_limit(),capacity);
    }
    printf("{\"suite\":\"roots\",\"passed\":true,\"realBacked\":true,\"actors\":%zu,\"attempts\":%zu}\n",actors,total);return 0;
}
static int root_requirements(void) {
    for(int actor=0;actor<4;++actor){const struct parser_case* expected=find_case(actor_names[actor]);CHECK(expected);struct environment value;CHECK(environment_open(&value,expected->source,expected->bytes)==0);struct syntax_failure failure;struct syntax_metrics metrics;size_t before=parser_root_count();observation_start(0);CHECK(actor_invoke(&value,expected,actor,&failure,&metrics));observation_stop();CHECK(observed.root_peak>before&&graph_equal(value.output,expected,811));printf("{\"suite\":\"root-requirement\",\"passed\":true,\"actor\":%d,\"required\":%zu}\n",actor,observed.root_peak-before);CHECK(environment_close(&value)==0);}
    return 0;
}
static int observer_controls(void) {
    static const uint8_t bytes[17]={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,255};void* source=NULL;void* destination=NULL;root roots[2]={0};CHECK(ube_gc_root_enter(&roots[0],&source)&&ube_gc_root_enter(&roots[1],&destination));CHECK(bytes_array(&source,bytes,17)&&ube_value_try_resize(&destination,17,&byte_layout,0));seed();size_t before=parser_root_count();observation_start(0);CHECK(ube_value_copy_bytes(&source,0,&destination,0,17));observation_stop();CHECK(observed.source_copies==17&&observed.allocations==0&&ube_err_number()==77&&parser_root_count()==before);
    for(int i=0;i<17;++i)CHECK(*(uint8_t*)ube_array_element(source,i)==bytes[i]&&*(uint8_t*)ube_array_element(destination,i)==bytes[i]);CHECK(ube_gc_root_leave(&roots[1])&&ube_gc_root_leave(&roots[0]));(void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==0);printf("{\"suite\":\"observer-controls\",\"passed\":true,\"actualSourceByteCopies\":17,\"allocations\":0}\n");return 0;
}
static void print_observation(const char* family,int32_t size,int32_t tokens,int32_t nodes,int ok,const struct syntax_failure* failure,const struct syntax_metrics* metrics) {
    printf("{\"phase\":\"parse\",\"family\":\"%s\",\"size\":%d,\"tokens\":%d,\"nodes\":%d,\"status\":%d,\"failureKind\":%d,\"maximumLiveNodes\":%zu,\"sourcePayloadCopiedBytes\":%zu,\"byteElementAcquisitions\":%zu,\"allocations\":%zu,\"requestedBytes\":%zu,\"zeroRequestedBytes\":%zu,\"publicationCopiedBytes\":%zu,\"otherCopiedBytes\":%zu,\"observedPeakRoots\":%zu,\"observedPeakRootStorageBytes\":%zu,\"runtimeArrayHeaderBytes\":%zu,\"runtimeGcHeaderBytes\":%zu,\"retainedOldSourceBytes\":%zu,\"retainedOldOutputPayloadBytes\":%zu,\"retainedOutputPayloadBytes\":%zu,\"tokenReads\":%d,\"transitions\":%d,\"nameReads\":%d,\"maximumPending\":%d,\"maximumDepth\":%d,\"workspaceInstances\":%zu,\"workspaceMaximumLiveSum\":%zu,\"workspaceMaximumRequestedSum\":%zu,\"workspaceBudgetViolations\":%zu,\"expressionFrameBytes\":%zu,\"controlFrameBytes\":%zu,\"events\":[",family,size,tokens,nodes,ok,failure->kind,observed.maximum_live_nodes,observed.source_copies,observed.byte_reads,observed.allocations,observed.requested,observed.zeroed,observed.publication,observed.other_copies,observed.root_peak,observed.root_peak*ube_gc_root_storage_size(),parser_array_header_size(),parser_gc_header_size(),sizeof old_source_bytes-1,sizeof(struct syntax_result)+5*sizeof(struct syntax_node),sizeof(struct syntax_result)+(ok?(size_t)nodes:5)*sizeof(struct syntax_node),metrics->reads,metrics->actions,metrics->names,metrics->pending,metrics->depth,observed.workspace_instances,observed.workspace_live_sum,observed.workspace_requested_sum,observed.workspace_budget_violations,sizeof(struct expression_frame),sizeof(struct control_frame));
    for(int i=0;i<9;++i)printf("%s%zu",i?",":"",observed.events[i]);printf("],\"growthCopiesByRole\":[");for(int i=0;i<ROLE_COUNT;++i)printf("%s%zu",i?",":"",observed.growth[i]);printf("],\"trimCopiesByRole\":[");for(int i=0;i<ROLE_COUNT;++i)printf("%s%zu",i?",":"",observed.trim[i]);printf("],\"capacityByRole\":[");for(int i=0;i<ROLE_COUNT;++i)printf("%s%zu",i?",":"",observed.capacity[i]);printf("],\"sourceBytes\":%zu}\n",measured_source_bytes);
}
static int cost_sample(const char* family,int32_t size) {
    size_t capacity=(size_t)size*64+16;uint8_t* bytes=calloc(capacity,1);CHECK(bytes);int32_t count=0;int expected_nodes=0;int expected_failure=0;
    if(strcmp(family,"flat")==0){for(int32_t i=0;i<size;++i){if(i)bytes[count++]='+';bytes[count++]='a';}expected_nodes=2*size-1;}
    else if(strcmp(family,"groups")==0){for(int32_t i=0;i<size;++i)bytes[count++]='(';bytes[count++]='a';for(int32_t i=0;i<size;++i)bytes[count++]=')';expected_nodes=size+1;if(size>256)expected_failure=2;}
    else if(strcmp(family,"prefix")==0){for(int32_t i=0;i<size;++i)bytes[count++]='-';bytes[count++]='a';expected_nodes=size+1;if(size>256)expected_failure=2;}
    else if(strcmp(family,"power")==0){for(int32_t i=0;i<=size;++i){if(i){memcpy(bytes+count," ^ ",3);count+=3;}bytes[count++]='a';}expected_nodes=2*size+1;if(size>256)expected_failure=2;}
    else if(strcmp(family,"wide")==0){bytes[count++]='f';bytes[count++]='(';for(int32_t i=0;i<size;++i){if(i)bytes[count++]=',';bytes[count++]='a';}bytes[count++]=')';expected_nodes=size+2;}
    else if(strcmp(family,"mixed")==0){static const char prefix[]="a Imp b Eqv c Xor d Or e And f = g & h + i * j \\ k Mod (";for(int32_t i=0;i<size;++i){memcpy(bytes+count,prefix,sizeof prefix-1);count+=(int32_t)sizeof prefix-1;}bytes[count++]='x';for(int32_t i=0;i<size;++i)bytes[count++]=')';expected_nodes=23*size+1;}
    else{free(bytes);return 1;}
    struct environment value;CHECK(environment_open(&value,bytes,count)==0);struct syntax_failure failure;struct syntax_metrics metrics;seed();observation_start(0);int ok=invoke(&value,1,1000000,1000000,256,&failure,&metrics);observation_stop();
    CHECK(ok==(expected_failure==0)&&failure.kind==expected_failure&&ube_err_number()==77);int32_t nodes=0;if(ok){struct syntax_result result=*(struct syntax_result*)ube_array_element(value.output,0);nodes=result.count;CHECK(nodes==expected_nodes&&graph_valid(&result,count)&&parser_expression_shape(value.output,family,size,count,811));}else CHECK(old_equal(value.output,value.old,value.previous.nodes,value.previous,value.previous_nodes)&&parser_expression_depth_failure(family,size,&failure));
    CHECK((size_t)metrics.reads==observed.events[1]);CHECK(metrics.reads>0&&metrics.actions>0);if(ok)CHECK(observed.events[2]==(size_t)nodes);
    print_observation(family,size,ube_value_array_length(&value.tokens),nodes,ok,&failure,&metrics);CHECK(source_equal(&value.source,bytes,count));CHECK(environment_close(&value)==0);free(bytes);return 0;
}
static int control_cost_sample(const char* family,int32_t size) {
    const char* prefix=NULL;const char* suffix=NULL;int32_t entry=2,expected_nodes=3*size+2;
    if(strcmp(family,"if")==0){prefix="If a Then\n";suffix="End If\n";}else if(strcmp(family,"while")==0){prefix="While a\n";suffix="Wend\n";}else if(strcmp(family,"with")==0){prefix="With a\n";suffix="End With\n";}else if(strcmp(family,"unit-lines")==0){prefix="UBE SOURCE 1 MODULE\nAttribute UBE_Name = \"Cost\"\nSub Work()\n";suffix="End Sub\n";entry=3;expected_nodes=8+2*size;}else return 1;
    size_t capacity=(size_t)size*32+128;uint8_t* bytes=calloc(capacity,1);CHECK(bytes);int32_t count=0;
    if(entry==3){memcpy(bytes,prefix,strlen(prefix));count=(int32_t)strlen(prefix);for(int32_t i=0;i<size;++i){memcpy(bytes+count,"Print a\n",8);count+=8;}memcpy(bytes+count,suffix,strlen(suffix));count+=(int32_t)strlen(suffix);}
    else{for(int32_t i=0;i<size;++i){memcpy(bytes+count,prefix,strlen(prefix));count+=(int32_t)strlen(prefix);}memcpy(bytes+count,"Print a\n",8);count+=8;for(int32_t i=0;i<size;++i){memcpy(bytes+count,suffix,strlen(suffix));count+=(int32_t)strlen(suffix);}}
    struct environment value;CHECK(environment_open(&value,bytes,count)==0);struct syntax_failure failure;struct syntax_metrics metrics;seed();observation_start(0);int ok=invoke(&value,entry,1000000,1000000,256,&failure,&metrics);observation_stop();int expected_failure=entry==2&&size>256?2:0;
    if(ok!=(expected_failure==0)||failure.kind!=expected_failure)fprintf(stderr,"control %s%d got%d kind%d [%d,%d] expected%d\n",family,size,ok,failure.kind,failure.first,failure.last,expected_failure);
    CHECK(ok==(expected_failure==0)&&failure.kind==expected_failure&&ube_err_number()==77);int32_t nodes=0;if(ok){struct syntax_result result=*(struct syntax_result*)ube_array_element(value.output,0);nodes=result.count;CHECK(nodes==expected_nodes&&parser_control_shape(value.output,family,size,count,811));}else CHECK(old_equal(value.output,value.old,value.previous.nodes,value.previous,value.previous_nodes)&&parser_control_depth_failure(family,size,&failure));
    CHECK((size_t)metrics.reads==observed.events[1]&&metrics.reads>0&&metrics.actions>0);print_observation(family,size,ube_value_array_length(&value.tokens),nodes,ok,&failure,&metrics);CHECK(source_equal(&value.source,bytes,count));CHECK(environment_close(&value)==0);free(bytes);return 0;
}
static int opaque_cost_sample(const char* family,int32_t size) {
    static const char native[]="UBE SOURCE 1 MODULE\nAttribute UBE_Name = \"Opaque\"\n";const char* prefix=NULL;const char* suffix=NULL;int32_t expected_count=3;
    if(strcmp(family,"initializer")==0){prefix="Dim ResultValue As Long = ";suffix="\n";}else if(strcmp(family,"default")==0){prefix="Sub Work(Optional ByVal X As Long = ";suffix=")\nEnd Sub\n";expected_count=9;}else if(strcmp(family,"bound")==0){prefix="Dim Grid(";suffix=") As Long\n";}else return 1;
    size_t capacity=(size_t)size*2+160;uint8_t* bytes=calloc(capacity,1);CHECK(bytes&&sizeof native-1==50);int32_t count=0;memcpy(bytes,native,sizeof native-1);count=(int32_t)sizeof native-1;memcpy(bytes+count,prefix,strlen(prefix));count+=(int32_t)strlen(prefix);for(int32_t i=0;i<size;++i){if(i)bytes[count++]='+';bytes[count++]='a';}int32_t expression_end=count;memcpy(bytes+count,suffix,strlen(suffix));count+=(int32_t)strlen(suffix);
    struct syntax_node expected_nodes[9]={0};int32_t expected_nodes_count=0;int32_t header=expression_expected_node(expected_nodes,&expected_nodes_count,50,0,50,-1,-1),member=-1;
    if(expected_count==3){member=expression_expected_node(expected_nodes,&expected_nodes_count,54,50,count-1,-1,-1);}
    else{CHECK(strlen(prefix)==36);int32_t name=expression_expected_node(expected_nodes,&expected_nodes_count,1,54,58,-1,-1);int32_t parameter=expression_expected_node(expected_nodes,&expected_nodes_count,56,59,expression_end,-1,-1);int32_t parameters=expression_expected_node(expected_nodes,&expected_nodes_count,47,58,expression_end+1,parameter,-1);int32_t procedure_header=expression_expected_node(expected_nodes,&expected_nodes_count,50,50,expression_end+1,name,parameters);int32_t block=expression_expected_node(expected_nodes,&expected_nodes_count,46,expression_end+2,expression_end+2,-1,-1);int32_t end=expression_expected_node(expected_nodes,&expected_nodes_count,58,expression_end+2,count-1,-1,-1);member=expression_expected_node(expected_nodes,&expected_nodes_count,65,50,count-1,procedure_header,block);expected_nodes[block].next_sibling=end;++expected_nodes[member].children;}
    int32_t root=expression_expected_node(expected_nodes,&expected_nodes_count,45,0,count,header,member);CHECK(expected_nodes_count==expected_count);struct parser_case expected={.name=family,.bytes=count,.nodes=expected_nodes,.count=expected_nodes_count,.root=root};
    struct environment value;CHECK(environment_open(&value,bytes,count)==0);struct syntax_failure failure;struct syntax_metrics metrics;seed();observation_start(0);int ok=invoke(&value,3,1000000,1000000,256,&failure,&metrics);observation_stop();CHECK(ok&&failure.kind==0&&ube_err_number()==77&&graph_equal(value.output,&expected,811));CHECK(observed.maximum_live_nodes>=(size_t)expected_count&&observed.events[2]>=(size_t)expected_count);if(size>=64)CHECK(observed.maximum_live_nodes>4*(size_t)expected_count);
    print_observation(family,size,ube_value_array_length(&value.tokens),expected_nodes_count,ok,&failure,&metrics);CHECK(source_equal(&value.source,bytes,count));CHECK(environment_close(&value)==0);free(bytes);return 0;
}
static int costs(void) {
    const int32_t sizes[]={1,8,64,1024,16384};size_t rows=0;for(size_t i=0;i<sizeof sizes/sizeof *sizes;++i){CHECK(cost_sample("flat",sizes[i])==0);++rows;CHECK(cost_sample("wide",sizes[i])==0);++rows;}
    for(int32_t depth=255;depth<=257;++depth){CHECK(cost_sample("groups",depth)==0);CHECK(cost_sample("prefix",depth)==0);CHECK(cost_sample("power",depth)==0);rows+=3;}
    CHECK(cost_sample("mixed",4)==0);CHECK(cost_sample("mixed",8)==0);CHECK(cost_sample("mixed",256)==0);rows+=3;
    for(int32_t depth=255;depth<=257;++depth){CHECK(control_cost_sample("if",depth)==0);CHECK(control_cost_sample("while",depth)==0);CHECK(control_cost_sample("with",depth)==0);rows+=3;}
    for(size_t i=0;i<sizeof sizes/sizeof *sizes;++i){CHECK(control_cost_sample("unit-lines",sizes[i])==0);++rows;}
    for(size_t i=0;i<sizeof sizes/sizeof *sizes;++i){CHECK(opaque_cost_sample("initializer",sizes[i])==0);CHECK(opaque_cost_sample("default",sizes[i])==0);CHECK(opaque_cost_sample("bound",sizes[i])==0);rows+=3;}
    printf("{\"suite\":\"costs\",\"passed\":true,\"rows\":%zu}\n",rows);return 0;
}
#endif

int main(int argc,char** argv) {
    (void)observation_start;(void)observation_stop;(void)measured_source_bytes;
    (void)setvbuf(stdout,NULL,_IONBF,0);
    const char* only=NULL;const char* suite=NULL;for(int i=1;i<argc;i+=2){if(i+1>=argc)return 2;if(strcmp(argv[i],"--case")==0)only=argv[i+1];else if(strcmp(argv[i],"--suite")==0)suite=argv[i+1];else if(strcmp(argv[i],"--root-actor")==0){if(!command_integer(argv[i+1],3,&root_actor))return 2;}else if(strcmp(argv[i],"--root-first")==0){if(!command_integer(argv[i+1],1000000,&root_first))return 2;}else if(strcmp(argv[i],"--root-last")==0){if(!command_integer(argv[i+1],1000000,&root_last))return 2;}else return 2;}
    const size_t layouts[]={sizeof(struct input),sizeof(struct document),sizeof(struct source_failure),sizeof(struct token),sizeof(struct syntax_node),sizeof(struct syntax_result),sizeof(struct syntax_failure),sizeof(struct syntax_metrics),sizeof(struct expression_frame),sizeof(struct control_frame)};
    CHECK(ube_gc_root_storage_size()==sizeof(root));for(size_t i=0;i<sizeof layouts/sizeof *layouts;++i)CHECK(parser_layout((int32_t)i)==layouts[i]);
    bool fixtures_only=suite&&strcmp(suite,"fixtures")==0;
    if(suite&&!fixtures_only){
        if(strcmp(suite,"admission")==0){admission_only=only;CHECK(admission()==0);printf("PASS native parser assertions:%u cases:0\n",assertions);return 0;}
        if(strcmp(suite,"domains")==0){CHECK(domains()==0);printf("PASS native parser assertions:%u cases:0\n",assertions);return 0;}
        if(strcmp(suite,"budgets")==0){CHECK(budgets()==0);printf("PASS native parser assertions:%u cases:0\n",assertions);return 0;}
        if(strcmp(suite,"workers")==0){CHECK(workers()==0);printf("PASS native parser assertions:%u cases:0\n",assertions);return 0;}
#ifdef PARSER_OBSERVED
        if(strcmp(suite,"costs")==0){CHECK(costs()==0);}else if(strcmp(suite,"faults")==0){CHECK(faults()==0);}else if(strcmp(suite,"roots")==0){CHECK(roots()==0);}else if(strcmp(suite,"root-requirements")==0){CHECK(root_requirements()==0);}else if(strcmp(suite,"observer-controls")==0){CHECK(observer_controls()==0);}else return 2;CHECK(parser_root_count()==0);(void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==0);printf("PASS native parser assertions:%u cases:0\n",assertions);return 0;
#else
        return 2;
#endif
    }
    size_t cases=0;for(size_t i=0;i<sizeof parser_cases/sizeof *parser_cases;++i)if(!only||strcmp(only,parser_cases[i].name)==0){CHECK(fixture(&parser_cases[i],1000+(int32_t)i)==0);++cases;}
    printf("{\"suite\":\"fixtures\",\"passed\":true,\"cases\":%zu}\n",cases);if(!only&&!fixtures_only){case_name="domain";CHECK(domains()==0);CHECK(budgets()==0);case_name="workers";CHECK(workers()==0);CHECK(admission()==0);}
#ifdef PARSER_OBSERVED
    if(!only&&!fixtures_only){case_name="faults";CHECK(faults()==0);CHECK(observer_controls()==0);case_name="roots";CHECK(roots()==0);case_name="costs";CHECK(costs()==0);}CHECK(parser_root_count()==0);
#endif
    (void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==0&&cases>0);printf("PASS native parser assertions:%u cases:%zu\n",assertions,cases);return 0;
}
