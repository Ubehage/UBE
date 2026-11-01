#include "bootstrap_runtime.c"
struct node {int32_t kind,token,left,right,operation,type,next,uses;};
struct local {int32_t owner,name,type,dynamic,first,count,initializer;};
struct statement {int32_t owner,kind,first,last,operation,value,target,flags;};
extern int32_t q_prepare(void**,int32_t,void**,int32_t,void**,int32_t);
extern int32_t q_needs(void**,int32_t),q_address(void**,int32_t);
extern uint64_t q_size(int32_t);
static const struct ube_value_layout node_layout={sizeof(struct node),0,0,NULL,0,NULL};
static const struct ube_value_layout local_layout={sizeof(struct local),0,0,NULL,0,NULL};
static const struct ube_value_layout statement_layout={sizeof(struct statement),0,0,NULL,0,NULL};
static unsigned checks;
#define CHECK(c) do{++checks;if(!(c)){fprintf(stderr,"classifier assertion %u line %d: %s\n",checks,__LINE__,#c);return 0;}}while(0)
static struct node* at(void* nodes,int i){return ube_array_element(nodes,i);}
static int reset(void** nodes,int count){
 CHECK(ube_value_try_resize(nodes,count,&node_layout,0));
 for(int i=0;i<count;++i)*at(*nodes,i)=(struct node){0,0,-1,-1,0,0,-1,77};
 return 1;
}
static int prepare(void** nodes,int count,void** locals,int local_count,void** statements,int statement_count){
 size_t roots=ube_gc_root_count;ube_err_set(77,"seed","classifier");
 CHECK(q_prepare(nodes,count,locals,local_count,statements,statement_count)==1);
 CHECK(ube_gc_root_count==roots&&ube_err_number()==77);return 1;
}
static int run(void){
 CHECK(q_size(0)==sizeof(struct node)&&q_size(1)==sizeof(struct local)&&q_size(2)==sizeof(struct statement));
 CHECK(sizeof(struct node)==32&&ube_gc_root_storage_size()==32);
 void *nodes=NULL,*locals=NULL,*statements=NULL;struct ube_gc_root roots[3]={{0}};
 CHECK(ube_gc_root_enter(&roots[0],&nodes)&&ube_gc_root_enter(&roots[1],&locals)&&ube_gc_root_enter(&roots[2],&statements));
 /* Managed inline record member chain: no rvalue evaluation of either base. */
 CHECK(reset(&nodes,3));at(nodes,0)->kind=12;at(nodes,0)->type=1000;
 at(nodes,1)->kind=14;at(nodes,1)->left=0;at(nodes,1)->type=1000;
 at(nodes,2)->kind=14;at(nodes,2)->left=1;at(nodes,2)->type=2;
 CHECK(prepare(&nodes,3,&locals,0,&statements,0));
 CHECK(at(nodes,0)->uses==1&&at(nodes,1)->uses==1&&!q_needs(&nodes,0)&&!q_needs(&nodes,1)&&q_address(&nodes,1));
 /* A direct argument edge, even an unlinked argument node, conservatively wins. */
 CHECK(reset(&nodes,3));at(nodes,0)->kind=12;at(nodes,0)->type=1000;
 at(nodes,1)->kind=14;at(nodes,1)->left=0;at(nodes,1)->type=2;
 at(nodes,2)->kind=17;at(nodes,2)->token=1000000;at(nodes,2)->left=0;
 CHECK(prepare(&nodes,3,&locals,0,&statements,0));CHECK(at(nodes,0)->uses==3&&q_needs(&nodes,0));
 /* Statement and initializer roots independently prevent omission. */
 CHECK(ube_value_try_resize(&statements,1,&statement_layout,0));
 *(struct statement*)ube_array_element(statements,0)=(struct statement){0,1,0,0,0,0,-1,0};
 CHECK(prepare(&nodes,2,&locals,0,&statements,1));CHECK(at(nodes,0)->uses==3&&q_needs(&nodes,0));
 CHECK(ube_value_try_resize(&locals,1,&local_layout,0));
 *(struct local*)ube_array_element(locals,0)=(struct local){0,0,0,0,0,0,0};
 CHECK(prepare(&nodes,2,&locals,1,&statements,0));CHECK(at(nodes,0)->uses==3&&q_needs(&nodes,0));
 /* Reference identity base must really load and remain rooted. */
 at(nodes,0)->type=20000;
 CHECK(prepare(&nodes,2,&locals,0,&statements,0));CHECK(at(nodes,0)->uses==2&&q_needs(&nodes,0));
 /* Array-of-record indexing used as a member address: borrow/fallback are separate. */
 CHECK(reset(&nodes,5));at(nodes,0)->kind=12;at(nodes,0)->type=101000;
 at(nodes,1)->kind=13;at(nodes,1)->type=1000;at(nodes,1)->left=0;at(nodes,1)->right=3;
 at(nodes,2)->kind=14;at(nodes,2)->type=2;at(nodes,2)->left=1;
 at(nodes,3)->kind=17;at(nodes,3)->left=4;at(nodes,4)->kind=10;at(nodes,4)->type=2;
 CHECK(prepare(&nodes,5,&locals,0,&statements,0));CHECK(!q_needs(&nodes,0)&&!q_needs(&nodes,1)&&q_address(&nodes,1));
 /* Call result with an untyped procedure designator cannot use a variable address. */
 CHECK(reset(&nodes,3));at(nodes,0)->kind=12;
 at(nodes,1)->kind=13;at(nodes,1)->type=1000;at(nodes,1)->left=0;
 at(nodes,2)->kind=14;at(nodes,2)->type=2;at(nodes,2)->left=1;
 CHECK(prepare(&nodes,3,&locals,0,&statements,0));CHECK(at(nodes,1)->uses==2&&q_needs(&nodes,1)&&!q_address(&nodes,1));
 /* New/Nothing/unknown/unreferenced materializations always remain. */
 for(int kind=18;kind<=19;++kind){
  CHECK(reset(&nodes,2));at(nodes,0)->kind=kind;at(nodes,0)->type=20000;
  at(nodes,1)->kind=14;at(nodes,1)->left=0;at(nodes,1)->type=2;
  CHECK(prepare(&nodes,2,&locals,0,&statements,0));CHECK(q_needs(&nodes,0)&&!q_address(&nodes,0));
 }
 CHECK(reset(&nodes,1));at(nodes,0)->kind=12;at(nodes,0)->type=1000;
 CHECK(prepare(&nodes,1,&locals,0,&statements,0));CHECK(at(nodes,0)->uses==0&&q_needs(&nodes,0));
 /* Bounded classifier handles cyclic/too-deep synthetic address queries neutrally. */
 at(nodes,0)->kind=14;at(nodes,0)->left=0;CHECK(!q_address(&nodes,0));
 at(nodes,0)->left=1;CHECK(!q_prepare(&nodes,1,&locals,0,&statements,0));
 CHECK(!q_prepare(&nodes,-1,&locals,0,&statements,0)&&!q_prepare(&nodes,200001,&locals,0,&statements,0));
 /* Real registry exhaustion, exact observed required admissions and recovery. */
 CHECK(reset(&nodes,1));at(nodes,0)->kind=12;at(nodes,0)->type=1000;at(nodes,0)->uses=0;
 size_t base=ube_gc_root_count,capacity=UBE_GC_MAX_ROOTS-base;
 struct ube_gc_root* pressure=calloc(capacity,sizeof(*pressure));CHECK(pressure);
 void* neutral=NULL;for(size_t i=0;i<capacity;++i)CHECK(ube_gc_root_enter(&pressure[i],&neutral));
 for(size_t available=0;available<=EXPECTED_NEED_ROOTS+1;++available){
  if(available)CHECK(ube_gc_root_leave(&pressure[capacity-available]));
  size_t before=ube_gc_root_count;ube_err_set(77,"seed","capacity");
  int32_t answer=q_needs(&nodes,0);CHECK(ube_gc_root_count==before);
  if(available<EXPECTED_NEED_ROOTS)CHECK(answer==0&&ube_err_number()==7);
  else CHECK(answer==1&&ube_err_number()==77);
 }
 for(size_t i=capacity-(EXPECTED_NEED_ROOTS+1);i>0;--i)CHECK(ube_gc_root_leave(&pressure[i-1]));free(pressure);
 CHECK(ube_gc_root_count==base&&q_needs(&nodes,0));
 ube_gc_test_set_threshold(1);CHECK(ube_gc_collect());CHECK(q_needs(&nodes,0));
 for(int i=2;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));
 CHECK(ube_gc_collect()&&ube_gc_root_count==0&&ube_gc_live_allocation_bytes()==0);
 printf("PASS classifier native assertions:%u required-roots:%d\n",checks,EXPECTED_NEED_ROOTS);return 1;
}
#include "argument-classifier.inc.c"
