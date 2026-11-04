/* Read actual checker/catalog output from a retained qualified adapter.
   This is a work-bound counterexample, not a new lowering implementation. */
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
int main(int argc,char** argv){if(argc!=2)return 2;void* bytes=NULL;void* checked=NULL;struct declarations declarations={0};struct writer writer={0};struct ube_gc_root roots[6]={{0}};void** owners[]={&bytes,&checked,&declarations.targets,&writer.output.buffer.bytes,&writer.output.snapshot,&writer.cancellation};
 for(int i=0;i<6;++i)CHECK(ube_gc_root_enter(&roots[i],owners[i]));CHECK(ube_value_try_resize(&bytes,(int32_t)strlen(argv[1]),&ube_file_byte_layout,0));memcpy(data(bytes),argv[1],strlen(argv[1]));
 const int jobs[]={1,4};for(int j=0;j<2;++j){struct semantic_failure failure={0};CHECK(graph_project(&bytes,jobs[j],&checked,&failure));graph_defaults(&writer.limits);writer.usage=(struct usage){0};CHECK(writer_begin(&writer) && graph_declarations(&checked,&declarations,&writer));CHECK(declarations.count==42 && declarations.frames==11 && declarations.byrefs==0 && writer.usage.work==42);
  struct target* targets=data(declarations.targets);int modules=0,functions=0,parameters=0,callee=-1;
  for(int d=0;d<declarations.count;++d){if(targets[d].kind==1)++modules;else if(targets[d].kind==6){++functions;if(targets[d].source==10){CHECK(callee==-1 && targets[d].parameter_count==20 && targets[d].role==0);callee=d;}}else{CHECK(targets[d].kind==4 && targets[d].source==10 && (targets[d].flags&4)!=0);++parameters;}}
  CHECK(modules==11 && functions==11 && parameters==20 && callee>=0);struct result* result=checked;struct module_prefix** checked_modules=data(result->modules);int imports=0,formal_visits=0;
  for(int source=0;source<10;++source){struct module_prefix* module=checked_modules[source];CHECK(module->source==source);struct node* nodes=data(module->values);int calls=0;for(int n=0;n<module->value_count;++n)if(nodes[n].kind==6){CHECK(nodes[n].target==callee && nodes[n].children==20);++calls;}CHECK(calls==1);++imports;formal_visits+=20;}
  int definitions=functions+2*parameters;int own_work=declarations.count+definitions;int import_work=imports+formal_visits;CHECK(own_work==93 && import_work==210 && own_work+import_work==303 && 3*declarations.count==126 && own_work+import_work>3*declarations.count);
  printf("PASS import work jobs=%d D=42 own=93 imports=210 minimum=303 bound=126\n",jobs[j]);CHECK(graph_release_declarations(&declarations,&writer) && writer_dispose(&writer) && writer.usage.payload==0);
 }
 for(int i=5;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));CHECK(ube_gc_collect() && ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);return 0;
}
