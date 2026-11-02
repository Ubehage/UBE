#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <stdatomic.h>
#include <windows.h>
#include "value_storage.h"
#include "scalar-source.h"
struct limits {int32_t declarations,facts,pending,depth;};
struct failure {int32_t kind,code,source,first,last,related,rfirst,rlast;};
struct declaration {int32_t kind,source,syntax,name,scope,type,flags,first_parameter,parameters,ordinal,initializer,known,auxiliary,body;int64_t value;};
struct name {int32_t source,syntax,first,last,byte_first,byte_count;};
struct semantic_type {int32_t kind,declaration,representation,pack,unpack,bits;int64_t minimum,maximum;};
_Static_assert(sizeof(struct semantic_type)==40,"semantic type ABI");
struct fact {int32_t source,syntax,kind,type;int64_t value;int32_t target,left,right,flags,auxiliary,extra;};
struct node {int32_t source,syntax,kind,type;int64_t value;int32_t target,child,next,children,flags,auxiliary;};
struct metrics {int64_t syntax_reads,declaration_reads,declaration_writes,fact_writes,node_writes,transitions,scalars,bytes,lookups;int32_t pending,depth;};
struct buffer {void* bytes;int32_t count;};
struct catalog {void* input;void* sources;int32_t source_count,packages;struct limits limits;void* declarations;int32_t declaration_count;void* types;int32_t type_count;void* names;int32_t name_count;struct buffer name_bytes;void* keys;int32_t key_count;void* order;void* facts;int32_t fact_count;void* values;int32_t value_count;struct metrics metrics;};
struct module {struct catalog* catalog;int32_t source;void* facts;int32_t fact_count;void* values;int32_t value_count,root;struct metrics metrics;};
struct result {struct catalog* catalog;void* modules;int32_t entry;};
struct envelope {int32_t format,kind,first,last;uint8_t identity;};
struct source {void* input;struct envelope envelope;int32_t source,package,module,first_declaration,declarations,private_module;void* name_map;};
struct document {void* bytes;int32_t content,scalars,lines;};
struct owner {struct document document;int32_t source;};
struct syntax_node {int32_t kind,first,last,child,next,children;};
struct syntax {void* nodes;int32_t count,root,source;};
struct work {struct owner* owner;void* tokens;void* syntax;int32_t failure[3],metrics[5];int64_t worker;int32_t state,limits[4];};
typedef union {uint64_t alignment;uint8_t bytes[32];} root;
extern int32_t statement_make(void**,int32_t,int32_t,void**,struct failure*),statement_cancel(void**),statement_check(void*,int32_t,struct limits*,void*,void**,struct failure*);
extern size_t index_root_count(void),index_root_limit(void),ube_gc_live_allocation_bytes(void),ube_gc_root_storage_size(void);
extern int32_t ube_gc_root_enter(void*,void**),ube_gc_root_leave(void*),ube_gc_collect(void),whole_worker_count(void);
extern void* ube_array_element(void*,int32_t);
extern void ube_err_set(int32_t,const char*,const char*);
extern int32_t ube_err_number(void);
extern void* ube_thread_capture_allocate(size_t,size_t,const size_t*);
extern void ube_thread_capture_destroy(void*);
static unsigned assertions;
void whole_envelope_begin(const struct document* doc,int extension){int count=ube_value_array_length(&doc->bytes);fprintf(stderr,"envelope entry ext%d content%d scalars%d lines%d bytes%d: ",extension,doc->content,doc->scalars,doc->lines,count);for(int i=0;i<count&&i<24;++i)fprintf(stderr,"%02x",*(uint8_t*)ube_array_element(doc->bytes,i));fprintf(stderr,"\n");}
void whole_envelope_end(const int32_t* failure,int ok){fprintf(stderr,"envelope exit ok%d scanKind%d firstByte%d lastByte%d\n",ok,failure[0],failure[1],failure[5]);}
#define CHECK(x) do{++assertions;if(!(x)){fprintf(stderr,"whole checker assertion %u line %d: %s\n",assertions,__LINE__,#x);return 1;}}while(0)
static _Atomic bool enabled;
static _Atomic size_t allocations,copied,source_copies,source_resizes,root_peak,heap_peak,capture_bytes,capture_live;
static void* borrowed[16];
static void maximum(_Atomic size_t* at,size_t value){size_t old=atomic_load(at);while(value>old&&!atomic_compare_exchange_weak(at,&old,value)){} }
void index_root_changed(size_t value){if(atomic_load(&enabled))maximum(&root_peak,value);}
void name_heap_changed(size_t value){if(atomic_load(&enabled))maximum(&heap_peak,value);}
void* probe_malloc(size_t bytes){if(atomic_load(&enabled))atomic_fetch_add(&allocations,1);return malloc(bytes);}
void* probe_calloc(size_t count,size_t bytes){if(bytes&&count>SIZE_MAX/bytes)return NULL;if(atomic_load(&enabled))atomic_fetch_add(&allocations,1);return calloc(count,bytes);}
void* probe_realloc(void* old,size_t bytes){if(atomic_load(&enabled))atomic_fetch_add(&allocations,1);return realloc(old,bytes);}
void probe_free(void* value){free(value);}
void probe_value_copy(size_t bytes){if(atomic_load(&enabled))atomic_fetch_add(&copied,bytes);}
static int borrowed_array(void* value){for(int i=0;i<16;++i)if(value&&value==borrowed[i])return 1;return 0;}
int32_t whole_assign(void* destination,const void* original,const struct ube_value_layout* layout){if(atomic_load(&enabled)&&layout->kind==1&&borrowed_array(*(void*const*)original))atomic_fetch_add(&source_copies,1);return ube_value_assign(destination,original,layout);}
int32_t whole_resize(void** holder,int32_t count,const struct ube_value_layout* layout,int32_t keep){if(atomic_load(&enabled)&&borrowed_array(*holder))atomic_fetch_add(&source_resizes,1);return ube_value_try_resize(holder,count,layout,keep);}
int32_t whole_copybytes(void** original,int32_t first,void** destination,int32_t to,int32_t count){if(atomic_load(&enabled)&&count>0&&borrowed_array(*original))atomic_fetch_add(&source_copies,1);return ube_value_copy_bytes(original,first,destination,to,count);}
void* whole_capture_allocate(size_t bytes,size_t roots,const size_t* offsets){void* value=ube_thread_capture_allocate(bytes,roots,offsets);if(value&&atomic_load(&enabled)){atomic_fetch_add(&capture_bytes,bytes);atomic_fetch_add(&capture_live,1);}return value;}
void whole_capture_destroy(void* value){if(value&&atomic_load(&enabled))atomic_fetch_sub(&capture_live,1);ube_thread_capture_destroy(value);}
static const struct ube_value_layout byte_layout={1,0,0,NULL,0,NULL};
static struct limits generous={1048576,1048576,1048576,256};
struct environment {void* bytes;struct source* input;void* cancellation;struct result* result;struct result* old;root roots[5];};
static struct syntax* input_syntax(const struct source* input){return ube_array_element(((struct work*)input->input)->syntax,0);}
static struct syntax_node* syntax_node(const struct source* input,int id){return ube_array_element(input_syntax(input)->nodes,id);}
static void dump_syntax(const struct source* input){struct syntax* s=input_syntax(input);fprintf(stderr,"parsed root%d count%d\n",s->root,s->count);for(int i=0;i<s->count;++i){struct syntax_node* n=syntax_node(input,i);fprintf(stderr,"syntax%d kind%d span%d..%d child%d next%d count%d\n",i,n->kind,n->first,n->last,n->child,n->next,n->children);}}
static struct module* module(const struct result* result){return *(struct module**)ube_array_element(result->modules,0);}
static struct declaration* declaration(const struct result* result,int id){return ube_array_element(result->catalog->declarations,id);}
static struct fact* fact(const struct module* module,int id){return ube_array_element(module->facts,id);}
static struct node* node(const struct module* module,int id){return ube_array_element(module->values,id);}
static int input(struct environment* e,const char* text){size_t bytes=strlen(text);CHECK(bytes<16777216&&ube_value_try_resize(&e->bytes,(int32_t)bytes,&byte_layout,0));for(size_t i=0;i<bytes;++i)*(uint8_t*)ube_array_element(e->bytes,(int32_t)i)=(uint8_t)text[i];struct failure failure={5,1428,-1,0,0,-1,0,0};int made=statement_make(&e->bytes,0,0,(void**)&e->input,&failure);if(!made||failure.kind)fprintf(stderr,"makeSource returned%d failure%d/%d stage%d..%d Err%d\n",made,failure.kind,failure.code,failure.first,failure.last,ube_err_number());CHECK(made&&failure.kind==0);return 0;}
static uint64_t hash_bytes(uint64_t hash,const void* value,size_t bytes){const uint8_t* p=value;for(size_t i=0;i<bytes;++i){hash^=p[i];hash*=UINT64_C(1099511628211);}return hash;}
static uint64_t hash_array(uint64_t hash,void* array,size_t width){int32_t count=ube_value_array_length(&array);hash=hash_bytes(hash,&count,4);for(int32_t i=0;i<count;++i)hash=hash_bytes(hash,ube_array_element(array,i),width);return hash;}
static uint64_t hash_input(const struct source* input){struct work* work=input->input;uint64_t hash=UINT64_C(1469598103934665603);hash=hash_array(hash,work->owner->document.bytes,1);hash=hash_array(hash,work->tokens,36);hash=hash_array(hash,work->syntax,24);return hash_array(hash,input_syntax(input)->nodes,24);}
static uint64_t hash_result(const struct result* result){uint64_t hash=UINT64_C(1469598103934665603);struct catalog* c=result->catalog;struct module* m=module(result);hash=hash_bytes(hash,&result->entry,4);hash=hash_array(hash,c->declarations,64);hash=hash_array(hash,c->types,40);hash=hash_array(hash,c->names,24);hash=hash_array(hash,c->name_bytes.bytes,1);hash=hash_array(hash,c->facts,48);hash=hash_array(hash,c->values,48);hash=hash_array(hash,m->facts,48);return hash_array(hash,m->values,48);}
static void observe_input(const struct source* input){struct work* work=input->input;borrowed[0]=work->owner->document.bytes;borrowed[1]=work->tokens;borrowed[2]=work->syntax;borrowed[3]=input_syntax(input)->nodes;}
static int check(struct environment* e,int jobs,struct limits* limits,struct failure* failure){observe_input(e->input);atomic_store(&allocations,0);atomic_store(&copied,0);atomic_store(&source_copies,0);atomic_store(&source_resizes,0);atomic_store(&capture_bytes,0);atomic_store(&capture_live,0);atomic_store(&root_peak,index_root_count());atomic_store(&heap_peak,ube_gc_live_allocation_bytes());atomic_store(&enabled,true);int ok=statement_check(e->input,jobs,limits,e->cancellation,(void**)&e->result,failure);atomic_store(&enabled,false);return ok;}
static int expect_node(const struct module* m,int kind,int syntax,int type,int64_t value,int target,int child,int next,int children,int flags,int auxiliary){int found=-1;for(int i=0;i<m->value_count;++i){struct node* n=node(m,i);if(n->kind==kind&&n->syntax==syntax){CHECK(found==-1);found=i;CHECK(n->source==0&&n->type==type&&n->value==value&&n->target==target&&n->child==child&&n->next==next&&n->children==children&&n->flags==flags&&n->auxiliary==auxiliary);}}CHECK(found>=0);return 0;}
static int node_id(const struct module* m,int kind,int syntax){for(int i=0;i<m->value_count;++i){struct node* n=node(m,i);if(n->kind==kind&&n->syntax==syntax)return i;}return -1;}
static int syntax_at(const struct source* input,int kind,int first,int last){struct syntax* s=input_syntax(input);int found=-1;for(int i=0;i<s->count;++i){struct syntax_node* n=syntax_node(input,i);if(n->kind==kind&&n->first==first&&n->last==last){if(found>=0)return -1;found=i;}}return found;}
static int text_syntax(const struct source* input,const char* source,int kind,const char* text,const char* within){const char* start=within?strstr(source,within):source;if(!start)return -1;const char* at=strstr(start,text);return at?syntax_at(input,kind,(int)(at-source),(int)(at-source+strlen(text))):-1;}
static int expect_fact(const struct module* m,struct fact expected){int found=0;for(int i=0;i<m->fact_count;++i)if(memcmp(fact(m,i),&expected,sizeof expected)==0)++found;CHECK(found==1);return 0;}
static int conversion(const struct module* m,int syntax,int placement,int target){for(int i=0;i<m->fact_count;++i){struct fact* f=fact(m,i);if(f->kind==3&&f->syntax==syntax&&f->right==placement&&f->target==target)return i;}return -1;}
static int empty_case(const struct environment* e){struct result* r=e->result;struct module* m=module(r);CHECK(r->entry==1&&r->catalog->declaration_count==2&&r->catalog->type_count==6&&m->fact_count==0&&m->value_count==3&&m->root>=0);struct declaration* d=declaration(r,1);int root=input_syntax(e->input)->root;int proc=node_id(m,101,d->syntax),block=node_id(m,102,d->body);CHECK(m->root==node_id(m,100,root)&&d->kind==5&&d->type==0&&d->parameters==0&&d->scope==0);CHECK(expect_node(m,100,root,0,0,0,proc,-1,1,0,-1)==0&&expect_node(m,101,d->syntax,0,0,1,block,-1,1,0,-1)==0&&expect_node(m,102,d->body,0,0,1,-1,-1,0,0,-1)==0);return 0;}
static int integer_case(const struct environment* e,const char* source){struct result* r=e->result;struct module* m=module(r);CHECK(r->entry==1&&r->catalog->declaration_count==3&&m->value_count==5&&m->fact_count==7);struct declaration* main=declaration(r,1);struct declaration* x=declaration(r,2);CHECK(main->kind==5&&x->kind==2&&x->scope==1&&x->type==3);int root=input_syntax(e->input)->root;int expr=text_syntax(e->input,source,13,"40000 - 10000",NULL),left=text_syntax(e->input,source,2,"40000",NULL),right=text_syntax(e->input,source,2,"10000",NULL);CHECK(expr>=0&&left>=0&&right>=0&&x->initializer==expr);int proc=node_id(m,101,main->syntax),block=node_id(m,102,main->body),storage=node_id(m,103,x->syntax),value=node_id(m,1,expr),convert=conversion(m,expr,4,2);CHECK(proc>=0&&block>=0&&storage>=0&&value>=0&&convert>=0);
 int64_t answer=30000;
#ifdef NEGATIVE_BODY_EXPECTATION
 answer=30001;
#endif
 CHECK(expect_node(m,100,root,0,0,0,proc,-1,1,0,-1)==0&&expect_node(m,101,main->syntax,0,0,1,block,-1,1,0,-1)==0&&expect_node(m,102,main->body,0,0,1,storage,-1,1,0,-1)==0&&expect_node(m,103,x->syntax,3,0,2,value,-1,1,3,convert)==0&&expect_node(m,1,expr,4,answer,-1,-1,-1,0,0,-1)==0);
 struct fact expected[]={
 {0,left,1,4,40000,-1,3,2,9,-1,left},{0,right,1,3,10000,-1,3,1,9,-1,right},
 {0,left,3,4,40000,expr,4,1,2,0,-1},{0,right,3,4,10000,expr,3,2,3,1,-1},
 {0,expr,1,4,30000,-1,3,0,25,value,expr},{0,expr,3,3,30000,2,4,4,3,-1,-1},
 {0,expr,9,3,0,2,value,convert,0,-1,-1}};
 for(size_t i=0;i<sizeof expected/sizeof expected[0];++i)CHECK(expect_fact(m,expected[i])==0);return 0;}
#include "scalar-complete.h"
static int scalar_case(const struct environment* e){return scalar_complete(e);}
static int flow_case(const struct environment* e){
 struct result* r=e->result;struct module* m=module(r);CHECK(r->entry==1&&r->catalog->declaration_count==3&&m->value_count==24);
 int branch=-1,loop=-1,exits=0;
 for(int i=0;i<m->value_count;++i){struct node* n=node(m,i);if(n->kind==106){CHECK(branch==-1);branch=i;}if(n->kind==107){CHECK(loop==-1);loop=i;}}
 CHECK(branch>=0&&loop>=0);struct node* conditional=node(m,branch);CHECK(conditional->children==3&&conditional->target==1);
 struct node* condition=node(m,conditional->child);CHECK(condition->kind==2&&condition->type==1&&condition->value==1);
 struct node* yes=node(m,condition->next);CHECK(yes->kind==102&&yes->children==1);struct node* no=node(m,yes->next);CHECK(no->kind==102&&no->children==1&&no->next==-1);
 CHECK(node(m,yes->child)->kind==104&&node(m,no->child)->kind==104);
 struct node* while_node=node(m,loop);CHECK(while_node->children==2&&while_node->target==1);struct node* while_condition=node(m,while_node->child);CHECK(while_condition->type==1&&while_condition->kind==5);
 struct node* body=node(m,while_condition->next);CHECK(body->kind==102&&body->children==2&&body->next==-1);
 for(int i=0;i<m->value_count;++i){struct node* n=node(m,i);if(n->kind==108){++exits;CHECK(n->children==0&&n->child==-1);if(n->flags==3)CHECK(n->target==loop);else CHECK(n->flags==1&&n->target==1);}}
 CHECK(exits==2);return 0;
}
static int module_forward_case(const struct environment* e){
 struct result* r=e->result;struct module* m=module(r);CHECK(r->entry==3&&r->catalog->declaration_count==4&&m->value_count==7&&m->fact_count==7);
 CHECK(declaration(r,1)->kind==2&&declaration(r,1)->scope==0&&declaration(r,2)->kind==2&&declaration(r,2)->scope==0);
 int reads=0,bindings=0;for(int i=0;i<m->value_count;++i){struct node* n=node(m,i);if(n->kind==3){++reads;CHECK(n->target==2&&n->type==4);}if(n->kind==103&&n->target==1){CHECK(n->flags==3&&n->children==1);struct node* value=node(m,n->child);CHECK(value->kind==3&&value->target==2);}}
 for(int i=0;i<m->fact_count;++i){struct fact* f=fact(m,i);if(f->kind==2){++bindings;CHECK(f->target==2&&f->left==1&&f->right==3&&f->type==4);}if(f->kind==1&&f->target==2)CHECK((f->flags&1)==0&&f->type==4);}
 CHECK(reads==1&&bindings==1);return 0;
}
static int positive(struct environment* e,const char* text,int which){
 CHECK(input(e,text)==0);uint64_t original=hash_input(e->input),baseline=0;
 for(int jobs=1;jobs<=4;jobs*=2){
  e->old=e->result;uint64_t old=e->old?hash_result(e->old):0;
  struct failure failure={5,1428,-1,0,0,-1,0,0};size_t roots=index_root_count();
  ube_err_set(77,"prior","whole semantic checker");int ok=check(e,jobs,&generous,&failure);
  if(!ok){fprintf(stderr,"whole check case%d jobs%d failed kind%d code%d source%d span%d..%d\n",which,jobs,failure.kind,failure.code,failure.source,failure.first,failure.last);dump_syntax(e->input);}
  CHECK(ok&&failure.kind==0&&failure.code==0&&e->result&&e->result!=e->old&&ube_err_number()==77);
  if(atomic_load(&source_copies)||atomic_load(&source_resizes)||atomic_load(&capture_bytes)!=8||atomic_load(&capture_live)||whole_worker_count()||index_root_count()!=roots||hash_input(e->input)!=original)fprintf(stderr,"ownership copies%zu resizes%zu captureBytes%zu captureLive%zu workers%d roots%zu expected%zu inputEqual%d\n",atomic_load(&source_copies),atomic_load(&source_resizes),atomic_load(&capture_bytes),atomic_load(&capture_live),whole_worker_count(),index_root_count(),roots,hash_input(e->input)==original);
  CHECK(atomic_load(&source_copies)==0&&atomic_load(&source_resizes)==0&&atomic_load(&capture_bytes)==8&&atomic_load(&capture_live)==0&&whole_worker_count()==0&&index_root_count()==roots&&hash_input(e->input)==original);
  if(e->old)CHECK(hash_result(e->old)==old);
  CHECK(ube_value_array_length(&e->result->modules)==1&&module(e->result)->catalog==e->result->catalog);
  if(which==0)CHECK(empty_case(e)==0);
  if(which==1)CHECK(integer_case(e,text)==0);
  if(which==2)CHECK(scalar_case(e)==0);
  if(which==3)CHECK(flow_case(e)==0);
  if(which==4)CHECK(module_forward_case(e)==0);
  uint64_t current=hash_result(e->result);if(jobs==1)baseline=current;else CHECK(current==baseline);
  printf("{\"suite\":\"whole-source-check\",\"case\":%d,\"jobs\":%d,\"bodyFacts\":%d,\"bodyNodes\":%d,\"actualAllocations\":%zu,\"actualCopiedBytes\":%zu,\"captureBytes\":%zu,\"sourceCopies\":%zu,\"rootPeak\":%zu,\"heapPeak\":%zu,\"passed\":true}\n",which,jobs,module(e->result)->fact_count,module(e->result)->value_count,atomic_load(&allocations),atomic_load(&copied),atomic_load(&capture_bytes),atomic_load(&source_copies),atomic_load(&root_peak),atomic_load(&heap_peak));
  (void)ube_gc_collect();
 }
 return 0;
}
static int negative(struct environment* e,const char* source,int jobs,int cancel,int code,const char* at){CHECK(input(e,source)==0);struct result* old=e->result;uint64_t hash=hash_result(old),original=hash_input(e->input);*(uint8_t*)e->cancellation=(uint8_t)cancel;struct failure failure={5,1428,-1,0,0,-1,0,0};size_t roots=index_root_count();CHECK(!check(e,jobs,&generous,&failure)&&failure.code==code&&e->result==old&&hash_result(old)==hash&&hash_input(e->input)==original&&whole_worker_count()==0&&atomic_load(&capture_live)==0&&index_root_count()==roots);if(at){const char* first=strstr(source,at);CHECK(first&&failure.source==0&&failure.first==first-source&&failure.last-failure.first==(int)strlen(at));}*(uint8_t*)e->cancellation=0;return 0;}
int main(void){CHECK(sizeof(struct catalog)==240&&sizeof(struct module)==128&&sizeof(struct result)==24&&sizeof(struct source)==64&&sizeof(struct work)==88&&sizeof(struct fact)==48&&sizeof(struct node)==48&&sizeof(struct declaration)==64&&sizeof(root)>=ube_gc_root_storage_size());struct environment e={0};void** slots[]={&e.bytes,(void**)&e.input,&e.cancellation,(void**)&e.result,(void**)&e.old};for(int i=0;i<5;++i)CHECK(ube_gc_root_enter(&e.roots[i],slots[i]));CHECK(statement_cancel(&e.cancellation)&&e.cancellation);const char* empty="UBE SOURCE 1 MODULE\nAttribute UBE_Name = \"BlankApp\"\nSub Main()\nEnd Sub\n";const char* integer="UBE SOURCE 1 MODULE\nAttribute UBE_Name = \"CalcApp\"\nSub Main()\nDim x As Integer = 40000 - 10000\nEnd Sub\n";const char* flow="UBE SOURCE 1 MODULE\nAttribute UBE_Name = \"FlowApp\"\nSub Main()\nDim x As Long = 0\nIf True Then x = 1 Else x = 2\nWhile x < 3\nx = x + 1\nExit While\nWend\nExit Sub\nEnd Sub\n";
const char* forward="UBE SOURCE 1 MODULE\nAttribute UBE_Name = \"ForwardApp\"\nPrivate first As Long = later\nPrivate later As Long = 1\nSub Main()\nEnd Sub\n";
CHECK(positive(&e,empty,0)==0&&positive(&e,integer,1)==0&&positive(&e,scalar_source,2)==0&&positive(&e,flow,3)==0&&positive(&e,forward,4)==0);CHECK(negative(&e,"UBE SOURCE 1 MODULE\nAttribute UBE_Name = \"Bad\"\nSub Main()\nDim x As Integer = 40000\nEnd Sub\n",4,0,1410,"40000")==0);CHECK(negative(&e,"UBE SOURCE 1 MODULE\nAttribute UBE_Name = \"Bad\"\nSub Main()\nExit Function\nEnd Sub\n",2,0,1421,"Exit Function")==0);CHECK(negative(&e,empty,0,0,1426,NULL)==0&&negative(&e,empty,5,0,1426,NULL)==0&&negative(&e,empty,4,1,1429,NULL)==0);for(int i=4;i>=0;--i)CHECK(ube_gc_root_leave(&e.roots[i]));(void)ube_gc_collect();CHECK(index_root_count()==0&&ube_gc_live_allocation_bytes()==0&&whole_worker_count()==0&&atomic_load(&capture_live)==0);printf("PASS whole semantic checker assertions:%u\n",assertions);return 0;}




