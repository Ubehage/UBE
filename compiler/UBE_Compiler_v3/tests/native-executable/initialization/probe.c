#define main retained_file_output_main
#include "std-lib/tests/file-output/native.c"
#undef main
struct limits {int64_t payload,llvm,identities,pending,work,depth,candidate;};
struct usage {int64_t payload,peak_payload,llvm,identities,pending,peak_pending,work,depth,peak_depth;};
struct failure {int32_t code,resource;};
struct buffer {void* bytes;int32_t count;};
struct output {struct buffer buffer;void* snapshot;int32_t capacity,length,snapshot_length,status;};
struct writer {struct failure failure;struct limits limits;struct usage usage;struct output output;void* cancellation;};
extern void defaults(struct limits*);
extern int32_t data_support(struct writer*,int32_t),order_support(struct writer*,int32_t,int32_t);
extern int32_t begin(struct writer*),dispose(struct writer*),snapshot(struct writer*),line(struct writer*,const char*),support(struct writer*,int32_t,int32_t),stack_support(struct writer*,int32_t),make_cancel(void**);
static int64_t visits;static void* cancel_at_visit;
void visit_event(void){
#ifndef OMIT_INITIALIZATION_VISIT_CONTROL
++visits;
#endif
if(cancel_at_visit && visits==4097)*(bool*)cancel_at_visit=true;}
static int emit(struct writer* w,int kind,int n,int f){w->failure=(struct failure){1509,0};return kind==2?order_support(w,n,f):kind?data_support(w,n):support(w,n,f);}
static int save(struct writer* w,const char* name){CHECK(snapshot(w));FILE* out=fopen(name,"wb");CHECK(out!=NULL && fputs("target triple = \"x86_64-w64-windows-gnu\"\n",out)>=0);CHECK(fwrite(((struct ube_array*)w->output.snapshot)->data,1,w->output.snapshot_length,out)==(size_t)w->output.snapshot_length && fclose(out)==0);return 0;}
#include "entry-probe.c"
#include "platform-probe.c"
#include "frame-probe.c"
#ifndef INITIALIZATION_PROBE_ENTRY
#define INITIALIZATION_PROBE_ENTRY main
#endif
int INITIALIZATION_PROBE_ENTRY(void) {
 CHECK(sizeof(struct writer)==184);struct writer w={0};struct ube_gc_root roots[3]={{0}};
 void** owners[]={&w.output.buffer.bytes,&w.output.snapshot,&w.cancellation};for(int i=0;i<3;++i)CHECK(ube_gc_root_enter(&roots[i],owners[i]));
 for(int kind=0;kind<3;++kind){w.usage=(struct usage){0};defaults(&w.limits);CHECK(begin(&w));ube_err_set(77,"prior","initialization emission");observe();visits=0;
  CHECK(emit(&w,kind,3,2) && w.usage.work==(kind==2?3:kind?6:0) && visits==w.usage.work && w.usage.identities==(kind==2?9:kind?6:41) && w.usage.pending==0 && w.usage.depth==0 && copies<=(size_t)w.output.capacity*2 && ube_err_number()==77);observing=0;
  int64_t bytes=w.usage.llvm,peak=w.usage.peak_payload,work=w.usage.work,identities=w.usage.identities;CHECK(bytes>100 && w.usage.payload==w.output.capacity);
  if(kind==2){CHECK(dispose(&w) && w.usage.payload==0);for(int root_count=1;root_count<=3;++root_count){w.usage=(struct usage){0};CHECK(begin(&w) && order_support(&w,3,root_count) && support(&w,3,2) && stack_support(&w,6));CHECK(line(&w,"define i1 @schedule_run() {\n %ok = call i1 @ube.module.initialize()\n ret i1 %ok\n}\ndefine i1 @schedule_require(i32 %owner, i32 %lexical) {\n %ok = call i1 @ube.module.require(i32 %owner, i32 %lexical)\n ret i1 %ok\n}"));char name[48];snprintf(name,sizeof name,"initialization-order-%d.ll",root_count);CHECK(save(&w,name)==0 && dispose(&w) && w.usage.payload==0);}CHECK(begin(&w));}
  else if(kind){CHECK(save(&w,"initialization-data.ll")==0);}
  else {
   CHECK(stack_support(&w,6));
   const char* tail[]={"define i32 @initialization_require(i32 %owner, i32 %lexical) {", " %ok = call i1 @ube.module.require(i32 %owner, i32 %lexical)"," %wide = zext i1 %ok to i32"," ret i32 %wide","}",
   "define i32 @initialization_state(i32 %id) {"," %p = getelementptr [3 x i8], ptr @ube.module.states, i32 0, i32 %id"," %s = load i8, ptr %p"," %r = zext i8 %s to i32"," ret i32 %r","}",
   "define i32 @initialization_failed() {"," %s = load i1, ptr @ube.module.failed"," %r = zext i1 %s to i32"," ret i32 %r","}"};
   for(size_t i=0;i<sizeof tail/sizeof tail[0];++i)CHECK(line(&w,tail[i]));CHECK(save(&w,"initialization.ll")==0);
  }
  CHECK(dispose(&w) && w.usage.payload==0);
  for(int category=0;category<4;++category)for(int delta=-1;delta<=0;++delta){if(category==0 && !kind && delta<0)continue;w.usage=(struct usage){0};defaults(&w.limits);if(category==0)w.limits.work=work+delta;if(category==1)w.limits.identities=identities+delta;if(category==2)w.limits.llvm=bytes+delta;if(category==3)w.limits.payload=peak+delta;CHECK(begin(&w));visits=0;int ok=emit(&w,kind,3,2);CHECK(ok==(delta==0));if(!ok)CHECK(w.failure.code==1502);CHECK(w.usage.payload==w.output.capacity && w.usage.work==visits-(!ok && w.failure.resource==5));CHECK(dispose(&w) && w.usage.payload==0);}
  w.usage=(struct usage){0};defaults(&w.limits);CHECK(begin(&w));ube_gc_test_fail_next_allocations(1000000);CHECK(!emit(&w,kind,3,2) && w.failure.code!=0);ube_gc_test_fail_next_allocations(0);CHECK(dispose(&w) && w.usage.payload==0);
  w.usage=(struct usage){0};CHECK(begin(&w) && make_cancel(&w.cancellation));*(bool*)w.cancellation=true;observe();CHECK(!emit(&w,kind,3,2) && w.failure.code==1507 && clean_cost());CHECK(dispose(&w));w.cancellation=NULL;
 }
 const int bad[][2]={{0,2},{-1,2},{3,-1},{3,INT32_MAX},{INT32_MAX,0}};
 for(size_t i=0;i<sizeof bad/sizeof bad[0];++i){w.usage=(struct usage){0};defaults(&w.limits);CHECK(begin(&w));ube_err_set(77,"prior","invalid dimensions");observe();CHECK(!emit(&w,0,bad[i][0],bad[i][1]) && w.failure.code==1509 && w.usage.llvm==0 && w.usage.identities==0 && clean_cost() && ube_err_number()==77);CHECK(dispose(&w));}
 const int bad_order[][2]={{0,0},{-1,1},{3,0},{3,-1},{3,4}};
 for(size_t i=0;i<sizeof bad_order/sizeof bad_order[0];++i){w.usage=(struct usage){0};defaults(&w.limits);CHECK(begin(&w));observe();CHECK(!order_support(&w,bad_order[i][0],bad_order[i][1]) && w.failure.code==1509 && w.usage.llvm==0 && w.usage.identities==0 && clean_cost());CHECK(dispose(&w));}
 const int counts[]={1,2,8,256};
 for(size_t i=0;i<sizeof counts/sizeof counts[0];++i){w.usage=(struct usage){0};defaults(&w.limits);CHECK(begin(&w));visits=0;CHECK(order_support(&w,counts[i],counts[i]) && w.usage.work==counts[i] && visits==w.usage.work && w.usage.identities==2*counts[i]+3);CHECK(dispose(&w) && w.usage.payload==0);}
 w.usage=(struct usage){0};defaults(&w.limits);w.limits.work=0;CHECK(begin(&w));visits=0;CHECK(!order_support(&w,3,2) && w.failure.code==1502 && w.failure.resource==5 && w.usage.work==0 && visits==1);CHECK(dispose(&w) && w.usage.payload==0);defaults(&w.limits);
 for(size_t i=0;i<sizeof counts/sizeof counts[0];++i){w.usage=(struct usage){0};defaults(&w.limits);CHECK(begin(&w));visits=0;CHECK(emit(&w,1,counts[i],0) && w.usage.work==2*counts[i] && visits==w.usage.work && w.usage.identities==counts[i]+3);CHECK(dispose(&w) && w.usage.payload==0);}
 w.usage=(struct usage){0};CHECK(begin(&w) && make_cancel(&w.cancellation));cancel_at_visit=w.cancellation;visits=0;CHECK(!emit(&w,1,4097,0) && w.failure.code==1507 && w.usage.work==4096 && visits==4097);cancel_at_visit=NULL;CHECK(dispose(&w) && w.usage.payload==0);w.cancellation=NULL;
 CHECK(entry_cases(&w)==0 && platform_cases(&w)==0 && frame_cases(&w)==0);
 size_t available=UBE_GC_MAX_ROOTS-ube_gc_root_count;struct ube_gc_root* pressure=calloc(available,sizeof(*pressure));void* neutral=NULL;CHECK(pressure!=NULL);for(size_t i=0;i<available;++i)CHECK(ube_gc_root_enter(&pressure[i],&neutral));
 for(int kind=0;kind<3;++kind){w.usage=(struct usage){0};observe();CHECK(!emit(&w,kind,3,2) && w.failure.code==1509 && w.usage.payload==0 && w.usage.llvm==0 && clean_cost());}w.usage=(struct usage){0};observe();CHECK(!platform_support(&w) && w.failure.code==1509 && w.usage.payload==0 && w.usage.llvm==0 && clean_cost());for(size_t i=0;i<available;++i)CHECK(ube_gc_root_leave(&pressure[i]));free(pressure);
 for(int i=2;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));CHECK(ube_gc_collect() && ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);
 printf("PASS initialization emission %d assertions\n",checks);return 0;
}
