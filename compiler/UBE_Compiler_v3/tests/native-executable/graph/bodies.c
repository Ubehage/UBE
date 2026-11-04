#define main retained_output_reference_main
#include "std-lib/tests/file-output/native.c"
#undef main
struct limits {int64_t payload,llvm,identities,pending,work,depth,candidate;};
struct usage {int64_t payload,peak_payload,llvm,identities,pending,peak_pending,work,depth,peak_depth;};
struct failure {int32_t code,resource;};
struct semantic_failure {int32_t kind,code,source,first,last,related,rfirst,rlast;};
struct cursor {void* frames;int32_t capacity,count,status,pending,ordinal;};
struct plan {void* syntax;void* nodes;void* arguments;struct cursor cursor;int32_t syntax_count,node_count,argument_count,argument_capacity,status;void* procedure_roots;int32_t procedure_capacity,procedure_count,first_frame;void* import_marks;void* imports;int32_t import_mark_count,import_capacity,import_count;};
struct target {int32_t kind,source,scope,type,representation,flags,role,first_parameter,parameter_count,first_member,last_member,next_member,frame;int64_t value,address;};
struct declarations {void* targets;int32_t count,status,frames;};
struct node {int32_t source,syntax,kind,type;int64_t value;int32_t target,child,next,children,flags,auxiliary;};
struct fact {int32_t source,syntax,kind,type;int64_t value;int32_t target,left,right,flags,auxiliary,extra;};
struct metrics {int64_t syntax_reads,declaration_reads,declaration_writes,fact_writes,node_writes,transitions,scalars,bytes,lookups;int32_t pending,depth;};
struct module {void* catalog;int32_t source;void* facts;int32_t fact_count;void* values;int32_t value_count,root;struct metrics metrics;};
struct result {void* catalog;void* modules;int32_t entry;};
struct buffer {void* bytes;int32_t count;};
struct output {struct buffer buffer;void* snapshot;int32_t capacity,length,snapshot_length,status;};
struct writer {struct failure failure;struct limits limits;struct usage usage;struct output output;void* cancellation;};
struct body {void* values;void* controls;int64_t current,temporary_address;int32_t value_count,control_count,procedure,status,overflow,temporary_count;bool terminated,error,calls,initialization;};
extern int32_t graph_check(void**,int32_t,void**,struct semantic_failure*),graph_plan(void**,int32_t,struct declarations*,struct plan*,struct limits*,struct usage*,struct failure*),graph_dispose(struct plan*,struct usage*,struct failure*);
extern int32_t graph_declarations(void**,struct declarations*,struct writer*),graph_release_declarations(struct declarations*,struct writer*);
extern void graph_defaults(struct limits*);
extern int32_t writer_begin(struct writer*),writer_line(struct writer*,const char*),writer_snapshot(struct writer*),writer_dispose(struct writer*),writer_support(struct writer*),writer_overflow(struct writer*,int32_t);
extern int32_t body_begin(struct body*,int32_t,struct writer*),body_dispose(struct body*,struct writer*),body_emit(void**,int32_t,int32_t,struct body*,struct declarations*,struct plan*,struct writer*);
extern int32_t body_cancellation(void**);
extern int32_t writer_stack(struct writer*,int32_t),writer_storage(struct writer*,struct target*,int32_t);
extern int32_t graph_root(struct plan*,int32_t,int32_t*);
static void* data(void* owner){return ((struct ube_array*)owner)->data;}
static const char source[]=
 "UBE SOURCE 1 MODULE\nAttribute UBE_Name = \"BodyInput\"\n"
 "Function Compute(ByVal X As Long, ByRef Seen As Long) As Long\n"
 " Dim Total As Long = X + 2\n While Total < 10\n Total = Total + 1\n"
 " If Total = 7 Then\n Seen = Seen + 1\n ElseIf Total = 8 Then\n Seen = Seen + 2\n Else\n Seen = Seen + 3\n End If\n"
 " If Total = 9 Then\n Exit While\n End If\n Wend\n Compute = Total\nEnd Function\n"
 "Function Branches(ByVal X As Long) As Long\n If X < 0 Then\n Branches = -3\n ElseIf X = 0 Then\n Branches = 17\n ElseIf X < 10 Then\n Branches = 23\n Else\n Branches = 31\n End If\nEnd Function\n"
 "Function Early(ByVal X As Long) As Long\n Early = X\n Exit Function\n Early = 10 \\ X\nEnd Function\n"
 "Function Short(ByVal Gate As Boolean, ByVal Z As Long) As Boolean\n Short = Gate AndAlso ((10 \\ Z) > 0)\nEnd Function\n"
 "Function Nested(ByVal A As Boolean, ByVal B As Boolean, ByVal Z As Long) As Boolean\n Nested = (A AndAlso B) OrElse ((Z <> 0) AndAlso ((10 \\ Z) > 0))\nEnd Function\n"
 "Function Sum(ByVal N As Long) As Long\n Dim I As Long\n Dim Total As Long\n While I < N\n I = I + 1\n Total = Total + I\n Wend\n If N > 0 Then\n Sum = Total\n End If\nEnd Function\n"
 "Sub Change(ByRef X As Long)\n X = X + 1\n Exit Sub\n X = X + 99\nEnd Sub\nSub Main()\nEnd Sub\n"
 "Function RepeatedDeclaration(ByVal N As Long) As Long\n Dim I As Long\n While I < N\n Dim Total As Long = Total + 1\n RepeatedDeclaration = Total\n I = I + 1\n Wend\nEnd Function\n";
static int ownership_cases(void) {
 struct body body={0};struct writer w={0};struct ube_gc_root roots[5]={{0}};void** owners[]={&body.values,&body.controls,&w.output.buffer.bytes,&w.output.snapshot,&w.cancellation};
 for(int i=0;i<5;++i)CHECK(ube_gc_root_enter(&roots[i],owners[i]));
 for(int delta=-1;delta<=1;++delta) {
  graph_defaults(&w.limits);w.limits.payload=512+delta;w.usage=(struct usage){0};w.failure=(struct failure){1509,0};observe();int ok=body_begin(&body,8,&w);observing=0;
  CHECK(ok==(delta>=0) && copies==0 && w.usage.payload==(ok?512:0));if(ok)CHECK(body.value_count==8 && body.control_count==8);else CHECK(w.failure.code==1502 && w.failure.resource==1);
  CHECK(body_dispose(&body,&w) && w.usage.payload==0);
 }
 graph_defaults(&w.limits);w.usage=(struct usage){0};w.failure=(struct failure){1509,0};ube_gc_test_fail_next_allocations(1000000);
 CHECK(!body_begin(&body,8,&w) && w.failure.code==1502 && w.failure.resource==1 && w.usage.payload==0);ube_gc_test_fail_next_allocations(0);CHECK(body_dispose(&body,&w));
 CHECK(body_cancellation(&w.cancellation));*(bool*)w.cancellation=true;w.usage=(struct usage){0};w.failure=(struct failure){1509,0};observe();
 CHECK(!body_begin(&body,8,&w) && w.failure.code==1507 && w.usage.payload==0 && clean_cost());CHECK(body_dispose(&body,&w));w.cancellation=NULL;
 size_t available=UBE_GC_MAX_ROOTS-ube_gc_root_count;struct ube_gc_root* pressure=calloc(available,sizeof(*pressure));void* neutral=NULL;CHECK(pressure);
 for(size_t i=0;i<available;++i)CHECK(ube_gc_root_enter(&pressure[i],&neutral));int successes=0,failures=0;
 for(size_t spare=0;spare<=32;++spare) {
  w.usage=(struct usage){0};w.failure=(struct failure){1509,0};int ok=body_begin(&body,8,&w);
  CHECK((ok && w.failure.code==0) || (!ok && w.failure.code!=0));CHECK(w.usage.payload==24*(int64_t)body.value_count+40*(int64_t)body.control_count);
  if(ok)++successes;else ++failures;
  for(size_t i=0;i<128;++i)CHECK(ube_gc_root_leave(&pressure[available-spare-1-i]));CHECK(body_dispose(&body,&w) && w.usage.payload==0);
  for(size_t i=0;i<128;++i)CHECK(ube_gc_root_enter(&pressure[available-spare-1-i],&neutral));if(spare<32)CHECK(ube_gc_root_leave(&pressure[available-spare-1]));
 }
 CHECK(successes && failures);for(size_t i=0;i<available-32;++i)CHECK(ube_gc_root_leave(&pressure[i]));free(pressure);
 for(int i=4;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));CHECK(ube_gc_collect() && ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);return 0;
}
static int run(void) {
 CHECK(sizeof(struct body)==64);void* bytes=NULL;void* checked=NULL;struct declarations declarations={0};struct plan plan={0};struct body body={0};struct writer w={0};
 struct ube_gc_root roots[15]={{0}};void** owners[]={&bytes,&checked,&declarations.targets,&plan.syntax,&plan.nodes,&plan.arguments,&plan.procedure_roots,&plan.import_marks,&plan.imports,&plan.cursor.frames,&body.values,&body.controls,&w.output.buffer.bytes,&w.output.snapshot,&w.cancellation};
 for(int i=0;i<15;++i)CHECK(ube_gc_root_enter(&roots[i],owners[i]));
 CHECK(ube_value_try_resize(&bytes,(int32_t)strlen(source),&ube_file_byte_layout,0));memcpy(data(bytes),source,strlen(source));
 const char* prototypes[]={"int32_t body_compute(int32_t,int32_t*,int32_t)","int32_t body_branches(int32_t)","int32_t body_early(int32_t)","bool body_short(bool,int32_t)","bool body_nested(bool,bool,int32_t)","int32_t body_sum(int32_t)","void body_change(int32_t*,int32_t)","void body_main(void)","int32_t body_reset(int32_t)"};
 const int jobs[]={1,2,4};unsigned char* prior=NULL;size_t prior_bytes=0;int64_t prior_work=-1,prior_ids=-1;
 for(int j=0;j<3;++j) {
  struct semantic_failure failure={5,1428,0,0,0,0,0,0};int ok=graph_check(&bytes,jobs[j],&checked,&failure);
  if(!ok)fprintf(stderr,"body source check jobs=%d kind=%d code=%d span=%d..%d\n",jobs[j],failure.kind,failure.code,failure.first,failure.last);
  CHECK(ok && checked);struct result* r=checked;struct module* m=*(struct module**)data(r->modules);CHECK(m && m->value_count>0);
  size_t vb=(size_t)m->value_count*sizeof(struct node),fb=(size_t)m->fact_count*sizeof(struct fact);void* original_values=malloc(vb);void* original_facts=malloc(fb);CHECK(original_values && original_facts);memcpy(original_values,data(m->values),vb);memcpy(original_facts,data(m->facts),fb);
  graph_defaults(&w.limits);w.usage=(struct usage){0};w.failure=(struct failure){1509,0};ube_err_set(77,"prior","body emission");
  CHECK(writer_begin(&w) && graph_declarations(&checked,&declarations,&w));
  /* Independent source inventory: one module, nine procedures, twelve
     parameters and five locals. Preparation visits all 27 once. */
  CHECK(declarations.count==27 && w.usage.work==27);
  CHECK(graph_plan(&checked,0,&declarations,&plan,&w.limits,&w.usage,&w.failure) && body_begin(&body,m->value_count,&w));
  CHECK(writer_line(&w,"target triple = \"x86_64-w64-windows-gnu\""));
  struct node* nodes=data(m->values);struct target* targets=data(declarations.targets);FILE* header=NULL;if(j==0){header=fopen("body-functions.h","wb");CHECK(header!=NULL);}
  int procedures=0;int64_t emitted_work=0;
  for(int i=0;i<m->value_count;++i)if(nodes[i].kind==101) {
   int32_t indexed_root=-1;CHECK(graph_root(&plan,targets[nodes[i].target].frame,&indexed_root) && indexed_root==i);
   CHECK(procedures<9);if(header)CHECK(fprintf(header,"extern %s __asm__(\"ube.f%lld\");\n",prototypes[procedures],(long long)targets[nodes[i].target].value)>0);
   int64_t before=w.usage.work;w.failure=(struct failure){1509,0};ok=body_emit(&checked,0,i,&body,&declarations,&plan,&w);
   if(!ok)fprintf(stderr,"body procedure=%d node=%d code=%d resource=%d work=%lld\n",procedures,i,w.failure.code,w.failure.resource,(long long)w.usage.work);
   CHECK(ok && body.status==1 && w.usage.pending==0 && w.usage.depth==0);emitted_work+=w.usage.work-before;++procedures;
  }
  CHECK(procedures==9 && body.error && body.overflow!=0);if(header)CHECK(fclose(header)==0);
  /* The second walk covers each procedure subtree once. All materialized nodes
     below those roots are owned, with V-9 edges across the nine trees. */
  int live=0;struct {int32_t scope,base,count,argument,temporaries;}* links=data(plan.nodes);
  for(int i=0;i<m->value_count;++i)if(links[i].scope && nodes[links[i].scope-1].kind==101)++live;
  /* Definitions visit nine procedures, twelve signature parameters and
     seventeen entry members. These 38 visits must not disappear from the
     ledger merely because they read a prepared target index. */
  CHECK(emitted_work==3*(int64_t)live-9+38);
  CHECK(body.initialization && writer_line(&w,"declare i1 @ube.module.require(i32, i32)") && writer_overflow(&w,body.overflow) && writer_support(&w) && writer_snapshot(&w));
  CHECK(memcmp(original_values,data(m->values),vb)==0 && memcmp(original_facts,data(m->facts),fb)==0 && ube_err_number()==77);free(original_values);free(original_facts);
  if(j==0){prior_bytes=(size_t)w.output.snapshot_length;prior=malloc(prior_bytes);CHECK(prior);memcpy(prior,data(w.output.snapshot),prior_bytes);FILE* file=fopen("bodies.ll","wb");CHECK(file && fwrite(prior,1,prior_bytes,file)==prior_bytes && fclose(file)==0);prior_work=w.usage.work;prior_ids=w.usage.identities;}
  else CHECK((size_t)w.output.snapshot_length==prior_bytes && memcmp(prior,data(w.output.snapshot),prior_bytes)==0 && w.usage.work==prior_work && w.usage.identities==prior_ids);
  CHECK(body_dispose(&body,&w) && graph_dispose(&plan,&w.usage,&w.failure) && graph_release_declarations(&declarations,&w) && writer_dispose(&w) && w.usage.payload==0 && w.usage.pending==0 && w.usage.depth==0);
  if(j==0) {
   int root=-1;for(int i=0;i<m->value_count;++i)if(nodes[i].kind==101){root=i;break;}CHECK(root>=0);
   /* Independently follow the retained source tree; the first procedure has
      one definition, two signature parameters and three entry members. */
   int stack[512],pending=1,occurrences=0;stack[0]=root;
   while(pending) {
    int id=stack[--pending];CHECK(id>=0 && id<m->value_count);++occurrences;
    int child=nodes[id].child;
    for(int c=0;c<nodes[id].children;++c){CHECK(child>=0 && child<m->value_count && pending<512);stack[pending++]=child;child=nodes[child].next;}
    CHECK(child==-1);
   }
   int64_t required=3*(int64_t)occurrences-1+6;
   const int64_t caps[]={0,3,required-1,required,required+1};
   for(int c=0;c<5;++c) {
    graph_defaults(&w.limits);w.usage=(struct usage){0};w.failure=(struct failure){1509,0};
    CHECK(writer_begin(&w) && graph_declarations(&checked,&declarations,&w) && graph_plan(&checked,0,&declarations,&plan,&w.limits,&w.usage,&w.failure) && body_begin(&body,m->value_count,&w));
    int64_t initial=w.usage.work;w.limits.work=initial+caps[c];int emitted=body_emit(&checked,0,root,&body,&declarations,&plan,&w);
    if(caps[c]<required) CHECK(!emitted && w.failure.code==1502 && w.failure.resource==5 && body.status==4 && w.usage.work==w.limits.work);
    else CHECK(emitted && w.failure.code==0 && body.status==1 && w.usage.work==initial+required);
    CHECK((caps[c]==0 && w.output.length==0) || (caps[c]>0 && w.output.length>0));
    CHECK(body_dispose(&body,&w) && graph_dispose(&plan,&w.usage,&w.failure) && graph_release_declarations(&declarations,&w) && writer_dispose(&w) && w.usage.payload==0 && w.usage.pending==0 && w.usage.depth==0);
   }
   graph_defaults(&w.limits);
  }
 }
 free(prior);for(int i=14;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));CHECK(ube_gc_collect() && ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);return 0;
}
#include "native-bodies.c"
#include "call-bodies.c"
#include "initializer-bodies.c"
#include "guard-bodies.c"
#include "module-bodies.c"
#include "expectations.c"
#include "entry-bodies.c"
int main(int argc,char** argv){if(argc!=3)return 2;if(ownership_cases() || run() || native_body_cases() || call_body_cases() || initializer_body_cases() || guard_body_cases(argv[1],0) || guard_body_cases(argv[2],1) || module_body_cases(argv[1],0) || module_body_cases(argv[2],1) || entry_body_cases(argv[1],0) || entry_body_cases(argv[2],1))return 1;printf("PASS checked native bodies %d assertions\n",checks);return 0;}
