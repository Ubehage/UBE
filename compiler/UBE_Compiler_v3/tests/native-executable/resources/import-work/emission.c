/* Actual module-consumer accounting against the approved 3*D+I bound. */
#define main retained_file_output_main
#include "std-lib/tests/file-output/native.c"
#undef main
struct limits {int64_t payload,llvm,identities,pending,work,depth,candidate;};
struct usage {int64_t payload,peak_payload,llvm,identities,pending,peak_pending,work,depth,peak_depth;};
struct failure {int32_t code,resource;};
struct buffer {void* bytes;int32_t count;};
struct output {struct buffer buffer;void* snapshot;int32_t capacity,length,snapshot_length,status;};
struct writer {struct failure failure;struct limits limits;struct usage usage;struct output output;void* cancellation;};
struct target {int32_t kind,source,scope,type,representation,flags,role,first_parameter,parameter_count,first_member,last_member,next_member,frame,byref;int64_t value,address;};
struct declarations {void* targets;int32_t count,status,frames,byrefs;};
struct semantic_failure {int32_t kind,code,source,first,last,related,rfirst,rlast;};
struct result {void* catalog;void* modules;int32_t entry;};
struct module_prefix {void* catalog;int32_t source;void* facts;int32_t fact_count;void* values;int32_t value_count,root;};
struct node {int32_t source,syntax,kind,type;int64_t value;int32_t target,child,next,children,flags,auxiliary;};
extern int32_t graph_project(void**,int32_t,void**,struct semantic_failure*),graph_declarations(void**,struct declarations*,struct writer*),graph_release_declarations(struct declarations*,struct writer*),writer_begin(struct writer*),writer_dispose(struct writer*);
extern void graph_defaults(struct limits*);
static void* data(void* array){return ((struct ube_array*)array)->data;}

struct cursor {void* frames;int32_t capacity,count,status,pending,ordinal;};
struct plan {void* syntax;void* nodes;void* arguments;struct cursor cursor;int32_t syntax_count,node_count,argument_count,argument_capacity,status;void* procedure_roots;int32_t procedure_capacity,procedure_count,first_frame;void* import_marks;void* imports;int32_t import_mark_count,import_capacity,import_count;};
struct body {void* values;void* controls;int64_t current,temporary_address;int32_t value_count,control_count,procedure,status,overflow,temporary_count;bool terminated,error,calls,initialization;};
extern int32_t graph_plan(void**,int32_t,struct declarations*,struct plan*,struct limits*,struct usage*,struct failure*),graph_dispose(struct plan*,struct usage*,struct failure*);
extern int32_t body_begin(struct body*,int32_t,struct writer*),body_dispose(struct body*,struct writer*),body_module(void**,int32_t,struct body*,struct declarations*,struct plan*,struct writer*);
extern int32_t writer_snapshot(struct writer*),writer_release(struct output*,struct usage*,struct failure*);
static int64_t expected_work(struct result* result) {
 struct module_prefix** modules=data(result->modules);int64_t visits=0,edges=0,args=0,facts=0;
 for(int s=0;s<11;++s){struct module_prefix* m=modules[s];struct node* nodes=data(m->values);int* stack=malloc((size_t)m->value_count*sizeof(int));bool* seen=calloc((size_t)m->value_count,sizeof(bool));CHECK(stack && seen);int count=1;stack[0]=m->root;facts+=m->fact_count;
  while(count){int n=stack[--count];CHECK(n>=0 && n<m->value_count && !seen[n]);seen[n]=true;++visits;struct node* node=&nodes[n];if(node->kind==6)args+=node->children;int child=node->child;for(int i=0;i<node->children;++i){CHECK(child>=0 && child<m->value_count && count<m->value_count);stack[count++]=child;++edges;child=nodes[child].next;}CHECK(child==-1);}
  free(stack);free(seen);
 }
 CHECK(args==200 && edges==visits-11 && 210<=visits+args+1);return 126+210+4*visits+2*edges+2*args+facts;
}
int main(int argc,char** argv){if(argc!=2)return 2;void* bytes=NULL;void* checked=NULL;struct declarations declarations={0};struct writer w={0};struct plan plan={0};struct body body={0};
 struct ube_gc_root roots[15]={{0}};void** owners[]={&bytes,&checked,&declarations.targets,&w.output.buffer.bytes,&w.output.snapshot,&w.cancellation,&plan.syntax,&plan.nodes,&plan.arguments,&plan.procedure_roots,&plan.import_marks,&plan.imports,&plan.cursor.frames,&body.values,&body.controls};
 for(int i=0;i<15;++i)CHECK(ube_gc_root_enter(&roots[i],owners[i]));CHECK(ube_value_try_resize(&bytes,(int32_t)strlen(argv[1]),&ube_file_byte_layout,0));memcpy(data(bytes),argv[1],strlen(argv[1]));
 unsigned char* prior[11]={0};size_t lengths[11]={0};const int jobs[]={1,4};int64_t recorded=-1;
 for(int j=0;j<2;++j){struct semantic_failure failure={0};CHECK(graph_project(&bytes,jobs[j],&checked,&failure));int64_t expected=expected_work(checked);if(j==0)recorded=expected;else CHECK(expected==recorded);
  for(int delta=-1;delta<=1;++delta){graph_defaults(&w.limits);w.limits.work=expected+delta;w.usage=(struct usage){0};CHECK(writer_begin(&w) && graph_declarations(&checked,&declarations,&w));CHECK(declarations.count==42 && w.usage.work==42);
   if(j==0 && delta==0){struct result* r=checked;struct target* t=data(declarations.targets);CHECK(r->entry>=0 && r->entry<declarations.count);FILE* file=fopen("import-functions.h","wb");CHECK(file && fprintf(file,"extern int32_t imported_main(void) __asm__(\"ube.f%lld\");\n",(long long)t[r->entry].value)>0 && fclose(file)==0);}
   unsigned char saved_targets[42*sizeof(struct target)];memcpy(saved_targets,data(declarations.targets),sizeof saved_targets);
   CHECK(writer_snapshot(&w) && writer_release(&w.output,&w.usage,&w.failure));int imports=0,completed=0;struct result* r=checked;struct module_prefix** modules=data(r->modules);
   for(int source=0;source<11;++source){CHECK(writer_begin(&w));CHECK(graph_plan(&checked,source,&declarations,&plan,&w.limits,&w.usage,&w.failure) && body_begin(&body,modules[source]->value_count,&w));CHECK(plan.import_count==(source<10?1:0));imports+=source<10?21:0;
    size_t vb=(size_t)modules[source]->value_count*sizeof(struct node),fb=(size_t)modules[source]->fact_count*48;void* saved_values=malloc(vb);void* saved_facts=malloc(fb);CHECK(saved_values && saved_facts);memcpy(saved_values,data(modules[source]->values),vb);memcpy(saved_facts,data(modules[source]->facts),fb);
    int accepted=body_module(&checked,source,&body,&declarations,&plan,&w);CHECK(memcmp(saved_values,data(modules[source]->values),vb)==0 && memcmp(saved_facts,data(modules[source]->facts),fb)==0 && memcmp(saved_targets,data(declarations.targets),sizeof saved_targets)==0);free(saved_values);free(saved_facts);if(!accepted){CHECK(delta==-1 && source==10 && w.failure.code==1502 && w.failure.resource==5 && w.usage.work==expected-1);}
    else{++completed;CHECK(writer_snapshot(&w));if(delta==0){if(j==0){lengths[source]=(size_t)w.output.snapshot_length;prior[source]=malloc(lengths[source]);CHECK(prior[source]);memcpy(prior[source],data(w.output.snapshot),lengths[source]);char name[80];snprintf(name,sizeof name,"import-module-%d.ll",source);FILE* file=fopen(name,"wb");CHECK(file && fwrite(prior[source],1,lengths[source],file)==lengths[source] && fclose(file)==0);}else CHECK((size_t)w.output.snapshot_length==lengths[source] && memcmp(prior[source],data(w.output.snapshot),lengths[source])==0);}CHECK(writer_release(&w.output,&w.usage,&w.failure));}
    CHECK(body_dispose(&body,&w) && graph_dispose(&plan,&w.usage,&w.failure) && !w.usage.pending && !w.usage.depth);if(!accepted)break;
   }
   CHECK(imports==210 && completed==(delta<0?10:11) && w.usage.work==expected-(delta<0));CHECK(graph_release_declarations(&declarations,&w) && writer_dispose(&w) && !w.usage.payload);
  }
  printf("PASS actual import work jobs=%d D=42 own=126 imports=210 total=%lld boundary=-1/0/1\n",jobs[j],(long long)expected);
 }
 for(int i=0;i<11;++i)free(prior[i]);for(int i=14;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));CHECK(ube_gc_collect() && !ube_gc_root_count && !ube_gc_live_allocation_bytes());return 0;
}
