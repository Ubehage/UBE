#define main retained_file_output_main
#include "std-lib/tests/file-output/native.c"
#undef main
#undef CHECK
#define CHECK(c) do { ++checks; if (!(c)) { fprintf(stderr,"native warning assertion line %d: %s\n",__LINE__,#c); return 1; } } while (0)
struct limits {int64_t payload,llvm,identities,pending,work,depth,candidate;};
struct usage {int64_t payload,peak_payload,llvm,identities,pending,peak_pending,work,depth,peak_depth;};
struct failure {int32_t code,resource;};
struct components {void* slots;int32_t capacity,status,direction,index,stack_count,order_count,component_count;};
struct warning {int32_t code,source,first,last,smallest;};
struct graph {void* matrix;void* spans;void* members;void* warnings;struct components components;int32_t modules,matrix_capacity,span_capacity,member_capacity,warning_capacity,component_capacity,pending,count,status;};
struct fixture {struct graph graph;struct limits limits;struct usage usage;struct failure failure;void* cancellation;struct ube_gc_root roots[6];};
extern void warning_defaults(struct limits*);
extern int32_t warning_begin(struct graph*,int32_t,struct limits*,struct usage*,void**,struct failure*);
extern int32_t warning_add(struct graph*,int32_t,int32_t,int32_t,int32_t,int32_t,struct limits*,struct usage*,void**,struct failure*);
extern int32_t warning_finish(struct graph*,struct limits*,struct usage*,void**,struct failure*);
extern int32_t warning_read(struct graph*,int32_t,struct warning*,struct failure*),warning_dispose(struct graph*,struct usage*,struct failure*),warning_cancel(void**);
static _Thread_local int64_t visit_events,component_events;
static _Thread_local int32_t component_peak;
static _Thread_local void* cancel_at_chunk;
void warning_visit_event(void) {
#ifndef OMIT_VISIT_CONTROL
 ++visit_events;
#endif
}
void warning_component_event(struct components* c) {
 ++component_events;if(c->stack_count>component_peak)component_peak=c->stack_count;
 if(cancel_at_chunk && component_events==4096)*(bool*)cancel_at_chunk=true;
}
static int start(struct fixture* f) {
 memset(f,0,sizeof(*f));void** owners[]={&f->graph.matrix,&f->graph.spans,&f->graph.members,&f->graph.warnings,&f->graph.components.slots,&f->cancellation};
 for(int i=0;i<6;++i)CHECK(ube_gc_root_enter(&f->roots[i],owners[i]));warning_defaults(&f->limits);f->failure=(struct failure){1509,0};visit_events=0;component_events=0;component_peak=0;return 0;
}
static int64_t owned(struct graph* g) {return 4*(int64_t)g->matrix_capacity+8*(int64_t)g->span_capacity+4*(int64_t)g->member_capacity+20*(int64_t)g->warning_capacity+20*(int64_t)g->component_capacity;}
static int dispose(struct fixture* f,int64_t other_pending) {
 CHECK(f->usage.payload==owned(&f->graph));f->failure=(struct failure){1509,0};
 CHECK(warning_dispose(&f->graph,&f->usage,&f->failure) && f->failure.code==0 && f->usage.payload==0 && f->usage.pending==other_pending && f->graph.status==0 && f->graph.count==0);
 for(int i=5;i>=0;--i)CHECK(ube_gc_root_leave(&f->roots[i]));(void)ube_gc_collect();CHECK(ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);return 0;
}
static int begin(struct fixture* f,int n) {f->failure=(struct failure){1509,0};return warning_begin(&f->graph,n,&f->limits,&f->usage,&f->cancellation,&f->failure);}
static int add(struct fixture* f,int from,int to,int source,int first,int last) {f->failure=(struct failure){1509,0};return warning_add(&f->graph,from,to,source,first,last,&f->limits,&f->usage,&f->cancellation,&f->failure);}
static int finish(struct fixture* f) {f->failure=(struct failure){1509,0};return warning_finish(&f->graph,&f->limits,&f->usage,&f->cancellation,&f->failure);}
static int witnesses(void) {
 const int edges[][5]={{0,1,0,50,55},{1,0,1,10,15},{1,2,0,1,2},{3,3,2,20,24},{4,5,0,40,60},{5,4,4,3,6},{0,1,0,40,49},{0,1,0,40,45}};
 struct warning expected[]={{1514,0,40,45,0},{1514,0,40,60,4},{1514,2,20,24,3}};
#ifdef WRONG_WITNESS_CONTROL
 expected[0].first=1;
#endif
 int64_t prior_work=-1;struct warning retained[3];
 for(int reverse=0;reverse<2;++reverse) {
  struct fixture f;CHECK(start(&f)==0 && begin(&f,6));CHECK(f.usage.payload==576 && f.failure.code==0);
  struct warning untouched={99,98,97,96,95},actual=untouched;CHECK(!warning_read(&f.graph,0,&actual,&f.failure) && f.failure.code==1509 && memcmp(&actual,&untouched,sizeof(actual))==0);
  ube_err_set(77,"prior","native warnings");
  for(int i=0;i<8;++i){int at=reverse?7-i:i;const int* e=edges[at];observe();CHECK(add(&f,e[0],e[1],e[2],e[3],e[4]) && clean_cost() && f.failure.code==0);}
  CHECK(finish(&f) && f.failure.code==0 && f.graph.status==2 && f.graph.count==3 && f.usage.payload==696);
  CHECK(f.usage.work==visit_events+component_events && component_events==104 && f.usage.peak_pending==component_peak && f.usage.pending==0 && f.usage.depth==0 && ube_err_number()==77);
  for(int i=0;i<3;++i){f.failure=(struct failure){1509,0};observe();CHECK(warning_read(&f.graph,i,&actual,&f.failure) && clean_cost() && f.failure.code==0);CHECK(memcmp(&actual,&expected[i],sizeof actual)==0);if(!reverse)retained[i]=actual;else CHECK(memcmp(&actual,&retained[i],sizeof actual)==0);}
  if(!reverse)prior_work=f.usage.work;else CHECK(f.usage.work==prior_work);
  CHECK(!warning_read(&f.graph,3,&actual,&f.failure) && f.failure.code==1509);
  CHECK(dispose(&f,0)==0);
 }
 return 0;
}
static int boundaries(void) {
 for(int delta=-1;delta<=1;++delta) {
  struct fixture f;CHECK(start(&f)==0);f.limits.payload=576+delta;int ok=begin(&f,6);
  CHECK(ok==(delta>=0));if(!ok)CHECK(f.failure.code==1502 && f.failure.resource==1 && f.graph.status==4);
  CHECK(dispose(&f,0)==0);
  CHECK(start(&f)==0);f.limits.payload=696+delta;CHECK(begin(&f,6));ok=finish(&f);
  CHECK(ok==(delta>=0));if(!ok)CHECK(f.failure.code==1502 && f.failure.resource==1 && f.graph.status==4);else CHECK(f.graph.count==0 && f.usage.payload==696);
  CHECK(dispose(&f,0)==0);
 }
 struct fixture f;CHECK(start(&f)==0);f.limits.payload=0;f.limits.pending=0;f.limits.work=0;CHECK(begin(&f,0) && finish(&f) && f.graph.count==0 && f.usage.work==0 && f.usage.payload==0);CHECK(dispose(&f,0)==0);
 const int allowances[]={0,1,8,11,12,13};
 for(int c=0;c<6;++c) {
  CHECK(start(&f)==0 && begin(&f,1) && add(&f,0,0,0,4,7));int64_t before=f.usage.work;f.limits.work=before+allowances[c];int ok=finish(&f);
  CHECK(ok==(allowances[c]>=12));if(ok)CHECK(f.graph.count==1 && f.usage.work==before+12);else CHECK(f.failure.code==1502 && f.failure.resource==5 && f.graph.status==4 && f.usage.work==f.limits.work);
  struct warning result={0};if(!ok)CHECK(!warning_read(&f.graph,0,&result,&f.failure));CHECK(dispose(&f,0)==0);
 }
 for(int chain=0;chain<2;++chain)for(int limit=0;limit<=9;++limit) {
  CHECK(start(&f)==0);f.usage.pending=2;f.usage.peak_pending=2;f.limits.pending=limit+2;CHECK(begin(&f,8));
  if(chain)for(int i=0;i<7;++i)CHECK(add(&f,i,i+1,i,10+i,11+i));
  int ok=finish(&f);CHECK(ok==(limit>=(chain?8:1)));
  if(ok)CHECK(f.graph.count==0 && f.usage.pending==2 && f.usage.peak_pending==(chain?10:3));
  else CHECK(f.failure.code==1502 && f.failure.resource==4 && f.graph.status==4 && f.usage.pending==2+limit && f.usage.peak_pending==2+limit);
  CHECK(dispose(&f,2)==0);
 }
 return 0;
}
static int failures(void) {
 struct fixture f;CHECK(start(&f)==0);ube_gc_test_fail_next_allocations(1000000);CHECK(!begin(&f,8) && f.failure.code==1502 && f.failure.resource==1);ube_gc_test_fail_next_allocations(0);CHECK(dispose(&f,0)==0);
 CHECK(start(&f)==0);CHECK(warning_cancel(&f.cancellation));*(bool*)f.cancellation=true;observe();CHECK(!begin(&f,8) && f.failure.code==1507 && clean_cost() && f.usage.payload==0);CHECK(dispose(&f,0)==0);
 CHECK(start(&f)==0);CHECK(warning_cancel(&f.cancellation) && begin(&f,64));cancel_at_chunk=f.cancellation;CHECK(!finish(&f) && f.failure.code==1507 && component_events==4096 && f.usage.work==4096 && f.graph.status==4);cancel_at_chunk=NULL;CHECK(dispose(&f,0)==0);
 CHECK(start(&f)==0 && begin(&f,2));struct graph before=f.graph;CHECK(!begin(&f,2) && f.failure.code==1509 && memcmp(&f.graph,&before,sizeof before)==0);CHECK(dispose(&f,0)==0);
 CHECK(start(&f)==0);CHECK(!begin(&f,-1) && f.failure.code==1509);CHECK(dispose(&f,0)==0);
 CHECK(start(&f)==0);CHECK(!begin(&f,INT32_MAX) && f.failure.code==1502 && f.failure.resource==1);CHECK(dispose(&f,0)==0);
 const int bad[][5]={{-1,0,0,0,1},{0,2,0,0,1},{0,0,2,0,1},{0,0,0,-1,1},{0,0,0,5,4}};
 for(int i=0;i<5;++i){CHECK(start(&f)==0 && begin(&f,2));CHECK(!add(&f,bad[i][0],bad[i][1],bad[i][2],bad[i][3],bad[i][4]) && f.failure.code==1509 && f.graph.status==4 && f.usage.work==0);CHECK(dispose(&f,0)==0);}
 CHECK(start(&f)==0);size_t available=UBE_GC_MAX_ROOTS-ube_gc_root_count;struct ube_gc_root* pressure=calloc(available,sizeof(*pressure));void* neutral=NULL;CHECK(pressure);
 for(size_t i=0;i<available;++i)CHECK(ube_gc_root_enter(&pressure[i],&neutral));CHECK(!begin(&f,8) && f.failure.code!=0 && f.usage.payload==0);
 for(size_t i=0;i<available;++i)CHECK(ube_gc_root_leave(&pressure[i]));free(pressure);CHECK(dispose(&f,0)==0);return 0;
}
int main(void) {CHECK(sizeof(struct graph)==112 && sizeof(struct warning)==20);CHECK(witnesses()==0 && boundaries()==0 && failures()==0);printf("PASS native warnings %d assertions\n",checks);return 0;}
