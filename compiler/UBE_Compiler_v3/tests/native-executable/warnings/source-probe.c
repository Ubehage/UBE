#define main counted_output_reference_main
#include "std-lib/tests/file-output/native.c"
#undef main
struct limits {int64_t payload,llvm,identities,pending,work,depth,candidate;};
struct usage {int64_t payload,peak_payload,llvm,identities,pending,peak_pending,work,depth,peak_depth;};
struct failure {int32_t code,resource;};
struct semantic_failure {int32_t kind,code,source,first,last,related,rfirst,rlast;};
struct buffer {void* bytes;int32_t count;};
struct output {struct buffer buffer;void* snapshot;int32_t capacity,length,snapshot_length,status;};
struct writer {struct failure failure;struct limits limits;struct usage usage;struct output output;void* cancellation;};
struct declarations {void* targets;int32_t count,status,frames,byrefs;};
struct checked_module {void* catalog;int32_t source;void* facts;int32_t fact_count;void* values;int32_t value_count,root;};
struct checked_result {void* catalog;void* modules;int32_t entry;};
struct snapshot {void* owner;void* saved;size_t bytes;};
struct cursor {void* frames;int32_t capacity,count,status,pending,ordinal;};
struct dependencies {void* procedures;void* formals;void* edges;void* arguments;struct cursor cursor;int32_t procedures_capacity,formals_capacity,edges_capacity,arguments_capacity,edge_count,procedure_head,procedure_tail,formal_head,formal_tail,root,status;};
struct components {void* slots;int32_t capacity,status,direction,index,stack_count,order_count,component_count;};
struct warnings {void* matrix;void* spans;void* members;void* warnings;struct components components;int32_t modules,matrix_capacity,span_capacity,member_capacity,warning_capacity,component_capacity,pending,count,status;};
struct span {int32_t first,last;};
struct warning {int32_t code,source,first,last,minimum;};
struct expected_edge {int32_t from,to,source,first,last;};
struct source_case {const char* path;int32_t modules,edge_count,warning_count;struct expected_edge edges[256];struct warning warnings[16];int32_t scale,rejection,rsource,rfirst,rlast;};
#include "source-cases.h"
extern int32_t source_check(void**,int32_t,void**,struct semantic_failure*);
extern int32_t source_declarations(void**,struct declarations*,struct writer*),source_release_declarations(struct declarations*,struct writer*);
extern int32_t source_discover(struct dependencies*,void**,struct declarations*,struct warnings*,struct writer*),source_dispose(struct dependencies*,struct writer*);
extern int32_t warning_begin(struct warnings*,int32_t,struct limits*,struct usage*,void**,struct failure*),warning_finish(struct warnings*,struct limits*,struct usage*,void**,struct failure*),warning_dispose(struct warnings*,struct usage*,struct failure*);
extern int32_t source_cancel(void**);
extern void source_defaults(struct limits*);
static uint64_t visits,cursor_events,component_events,actual_pending_peak;
static int watching;
static int cancel_when_seeded;
static bool* active_cancellation;
static uint64_t other_pending,last_work,last_payload;
static struct dependencies* active_dependencies;
void source_dependency_event(struct dependencies* d);
void source_visit_event(void) {if(watching)++visits;}
void source_cursor_event(void* event,int32_t ok) {if(watching){if(ok && *(int32_t*)event!=0)++cursor_events;source_dependency_event(active_dependencies);}}
void source_component_event(struct components* c) {if(watching){++component_events;uint64_t live=other_pending+(uint64_t)c->stack_count;if(live>actual_pending_peak)actual_pending_peak=live;}}
void source_dependency_event(struct dependencies* d) {
 if(watching){uint64_t live=other_pending+(uint64_t)(d->procedure_tail-d->procedure_head)+(uint64_t)(d->formal_tail-d->formal_head)+(uint64_t)d->cursor.count;if(live>actual_pending_peak)actual_pending_peak=live;
  if(cancel_when_seeded && d->formal_tail>d->formal_head){*active_cancellation=true;cancel_when_seeded=0;}}
}
static void* payload(void* owner){return ((struct ube_array*)owner)->data;}
static int clean(struct dependencies* d,struct warnings* g,struct writer* w) {
 w->failure=(struct failure){1509,0};CHECK(source_dispose(d,w));
 struct failure f={1509,0};CHECK(warning_dispose(g,&w->usage,&f));
 CHECK(d->status==0 && !d->procedures && !d->formals && !d->edges && !d->arguments && !d->cursor.frames && (uint64_t)w->usage.pending==other_pending && w->usage.depth==0);return 0;
}
static int inspect(struct warnings* g,const struct source_case* c) {
 CHECK(g->modules==c->modules && g->status==2 && g->count==c->warning_count);
 int32_t* matrix=payload(g->matrix);struct span* spans=payload(g->spans);int edges=0;
 for(int from=0;from<c->modules;++from)for(int to=0;to<c->modules;++to){int cell=from*c->modules+to;if(!matrix[cell])continue;++edges;int found=0;
  for(int j=0;j<c->edge_count;++j){struct expected_edge e=c->edges[j];if(e.from==from && e.to==to){CHECK(matrix[cell]==e.source+1 && spans[cell].first==e.first && spans[cell].last==e.last);++found;}}CHECK(found==1);
 }
 CHECK(edges==c->edge_count);
 struct warning* values=payload(g->warnings);
 for(int i=0;i<c->warning_count;++i){struct warning expected=c->warnings[i];
#ifdef WRONG_SOURCE_WITNESS_CONTROL
  ++expected.first;
#endif
  CHECK(memcmp(&values[i],&expected,sizeof expected)==0);
 }
 return 0;
}
static int run_case(const struct source_case* c,int jobs,int resources) {
 void* path=NULL;void* result=NULL;struct declarations decl={0};struct writer w={0};struct dependencies d={0};struct warnings g={0};
 struct ube_gc_root roots[16]={{0}};void** owners[]={&path,&result,&decl.targets,&w.output.buffer.bytes,&w.output.snapshot,&w.cancellation,&d.procedures,&d.formals,&d.edges,&d.arguments,&d.cursor.frames,&g.matrix,&g.spans,&g.members,&g.warnings,&g.components.slots};
 for(int i=0;i<16;++i)CHECK(ube_gc_root_enter(&roots[i],owners[i]));
 CHECK(ube_value_try_resize(&path,(int32_t)strlen(c->path),&ube_file_byte_layout,0));memcpy(payload(path),c->path,strlen(c->path));
 struct semantic_failure sf={5,1428,0,0,0,0,0,0};int ok=source_check(&path,jobs,&result,&sf);
 if(c->rejection){CHECK(!ok && result==NULL && sf.code==c->rejection && sf.source==c->rsource && sf.first==c->rfirst && sf.last==c->rlast);for(int i=15;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));path=NULL;ube_gc_collect();CHECK(ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);last_work=last_payload=0;return 0;}
 if(!ok)fprintf(stderr,"checker code %d kind %d source %d first %d\n",sf.code,sf.kind,sf.source,sf.first);
 CHECK(ok && sf.code==0 && result!=NULL);source_defaults(&w.limits);w.failure=(struct failure){1509,0};CHECK(source_declarations(&result,&decl,&w));
 struct snapshot saved[33]={{0}};int saved_count=0;CHECK(c->modules<=16);
 struct checked_result* checked=result;CHECK(ube_value_array_length(&checked->modules)==c->modules);
 for(int module=0;module<c->modules;++module){struct checked_module* m=((struct checked_module**)payload(checked->modules))[module];CHECK(m && m->source==module);
  void* values[]={m->values,m->facts};int counts[]={m->value_count,m->fact_count};
  for(int i=0;i<2;++i){size_t bytes=(size_t)counts[i]*48;CHECK(!bytes || (((struct ube_array*)values[i])->element_size==48));void* copy=malloc(bytes?bytes:1);CHECK(copy!=NULL);if(bytes)memcpy(copy,payload(values[i]),bytes);saved[saved_count++]=(struct snapshot){values[i],copy,bytes};}
 }
 size_t target_bytes=(size_t)decl.count*72;void* target_copy=malloc(target_bytes);CHECK(target_copy!=NULL);memcpy(target_copy,payload(decl.targets),target_bytes);saved[saved_count++]=(struct snapshot){decl.targets,target_copy,target_bytes};
 int64_t base_payload=w.usage.payload,base_work=w.usage.work;uint64_t baseline_work=0,baseline_peak=0,baseline_pending=0;
 for(int attempt=0;attempt<(resources?13:1);++attempt) {
  if(attempt==11 && (!decl.byrefs || !c->warning_count))continue;
  if(attempt==12 && resources!=2)continue;
  other_pending=attempt==10?2:0;cancel_when_seeded=0;
  source_defaults(&w.limits);w.usage=(struct usage){0};w.usage.payload=base_payload;w.usage.peak_payload=base_payload;
  w.usage.pending=w.usage.peak_pending=other_pending;
  w.failure=(struct failure){1509,0};CHECK(warning_begin(&g,c->modules,&w.limits,&w.usage,&w.cancellation,&w.failure));
  int64_t live_base=w.usage.payload;
  if(attempt==1)w.limits.work=(int64_t)baseline_work-1;
  if(attempt==2)w.limits.work=baseline_work;
  if(attempt==3)w.limits.payload=(int64_t)baseline_peak-1;
  if(attempt==4)w.limits.payload=baseline_peak;
  if(attempt==5)w.limits.pending=(int64_t)baseline_pending-1;
  if(attempt==6)w.limits.pending=baseline_pending;
  if(attempt==7){CHECK(source_cancel(&w.cancellation));*(bool*)w.cancellation=true;}
  if(attempt==8)ube_gc_test_fail_next_allocations(1000000);
  if(attempt==9)w.limits.work=0;
  if(attempt==10)w.limits.pending=(int64_t)baseline_pending+2;
  if(attempt==11){CHECK(source_cancel(&w.cancellation));active_cancellation=w.cancellation;cancel_when_seeded=1;}
  struct ube_gc_root* pressure=NULL;size_t available=0;void* neutral=NULL;
  if(attempt==12){available=UBE_GC_MAX_ROOTS-ube_gc_root_count;pressure=calloc(available,sizeof(*pressure));CHECK(pressure!=NULL);for(size_t i=0;i<available;++i)CHECK(ube_gc_root_enter(&pressure[i],&neutral));}
  w.failure=(struct failure){1509,0};ube_err_set(77,"prior","warning discovery");
  visits=cursor_events=component_events=0;actual_pending_peak=other_pending;active_dependencies=&d;watching=1;observe();
  ok=source_discover(&d,&result,&decl,&g,&w);
  if(ok){w.failure=(struct failure){1509,0};ok=warning_finish(&g,&w.limits,&w.usage,&w.cancellation,&w.failure);}
  observing=0;watching=0;ube_gc_test_fail_next_allocations(0);
  int should_pass=attempt==0 || attempt==2 || attempt==4 || attempt==6 || attempt==10;
  if(ok!=should_pass)fprintf(stderr,"discovery %s jobs=%d attempt=%d ok=%d code=%d resource=%d work=%lld payload=%lld pending=%lld state=%d\n",c->path,jobs,attempt,ok,w.failure.code,w.failure.resource,(long long)w.usage.work,(long long)w.usage.peak_payload,(long long)w.usage.peak_pending,d.status);
  CHECK(ok==should_pass);
  for(int i=0;i<saved_count;++i)CHECK(!saved[i].bytes || memcmp(saved[i].saved,payload(saved[i].owner),saved[i].bytes)==0);
  if(ok){CHECK(w.failure.code==0 && (uint64_t)w.usage.pending==other_pending && w.usage.depth==0 && ube_err_number()==77);CHECK(inspect(&g,c)==0);
   int64_t owned=base_payload+(int64_t)d.procedures_capacity*12+(int64_t)d.formals_capacity*12+(int64_t)d.edges_capacity*24+(int64_t)d.arguments_capacity*4+(int64_t)d.cursor.capacity*24+(int64_t)g.matrix_capacity*4+(int64_t)g.span_capacity*8+(int64_t)g.member_capacity*4+(int64_t)g.warning_capacity*20+(int64_t)g.component_capacity*20;
   CHECK(w.usage.payload==owned && w.usage.llvm==0 && w.usage.identities==0);
   uint64_t observed=visits+cursor_events+component_events;
#ifdef OMIT_SOURCE_VISIT_CONTROL
   --observed;
#endif
   CHECK((uint64_t)w.usage.work==observed && (uint64_t)w.usage.peak_pending==actual_pending_peak);
   if(attempt==0){baseline_work=w.usage.work;baseline_peak=w.usage.peak_payload;baseline_pending=w.usage.peak_pending;}
   else CHECK((uint64_t)w.usage.work==baseline_work && (uint64_t)w.usage.peak_payload==baseline_peak);
  } else {
   CHECK(g.status!=2 && w.failure.code!=0);
   if(attempt==7)CHECK(w.failure.code==1507 && w.usage.payload==live_base && allocations==0 && copies==0);
   else if(attempt==11)CHECK(w.failure.code==1507 && !cancel_when_seeded && w.usage.work>0 && w.usage.pending>0);
   else if(attempt==12)CHECK(w.failure.code==1509 && d.status==0 && w.usage.payload==live_base && allocations==0 && copies==0);
   else CHECK(w.failure.code==1502 && w.failure.resource==(attempt==1 || attempt==9?5:attempt==5?4:1));
  }
  if(pressure){for(size_t i=0;i<available;++i)CHECK(ube_gc_root_leave(&pressure[i]));free(pressure);}
  CHECK(clean(&d,&g,&w)==0 && w.usage.payload==base_payload);w.cancellation=NULL;
 }
 last_work=baseline_work;last_payload=baseline_peak;
 for(int i=0;i<saved_count;++i)free(saved[i].saved);
 w.usage.work=base_work;w.failure=(struct failure){1509,0};CHECK(source_release_declarations(&decl,&w) && w.usage.payload==0);
 for(int i=15;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));path=NULL;result=NULL;ube_gc_collect();CHECK(ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);return 0;
}
int main(void) {
 CHECK(sizeof(struct dependencies)==112 && sizeof(struct warnings)==112 && sizeof(struct declarations)==24);
 uint64_t previous_scale_work=0,previous_scale_payload=0;
 for(size_t i=0;i<sizeof source_cases/sizeof source_cases[0];++i){uint64_t first_work=0,first_payload=0;
  for(int jobs=1;jobs<=4;jobs*=2){CHECK(run_case(&source_cases[i],jobs,jobs==1?(i==0?2:1):0)==0);if(jobs==1){first_work=last_work;first_payload=last_payload;}else CHECK(first_work==last_work && first_payload==last_payload);}
  if(source_cases[i].scale){if(previous_scale_work)CHECK(first_work>previous_scale_work && first_work<=4*previous_scale_work && first_payload>previous_scale_payload && first_payload<=4*previous_scale_payload);previous_scale_work=first_work;previous_scale_payload=first_payload;printf("METRIC source-scale n=%d work=%llu payload=%llu\n",source_cases[i].scale,(unsigned long long)first_work,(unsigned long long)first_payload);}
 }
 printf("PASS checked warning sources %llu assertions\n",(unsigned long long)checks);return 0;
}
