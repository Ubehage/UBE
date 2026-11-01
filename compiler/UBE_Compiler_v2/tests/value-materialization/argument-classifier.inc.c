struct token {int32_t kind,start,length;const char*spelling;const char*decoded;};
struct procedure {int32_t kind,name,header,end,intrinsic,thread,first,count,result,array,role,native,first_node,last_node;};
struct parameter {int32_t owner,name,type,mode,array;};
_Static_assert(sizeof(struct token)==32&&offsetof(struct token,spelling)==16&&
               offsetof(struct token,decoded)==24&&sizeof(struct procedure)==56&&
               sizeof(struct parameter)==20,"private argument classifier ABI");
extern int32_t q_prepare_ex(void**,int32_t,void**,int32_t,void**,int32_t,void**,int32_t,void**,int32_t,void**,int32_t);
static const struct ube_value_layout token_layout={sizeof(struct token),0,0,NULL,0,NULL};
static const struct ube_value_layout procedure_layout={sizeof(struct procedure),0,0,NULL,0,NULL};
static const struct ube_value_layout parameter_layout={sizeof(struct parameter),0,0,NULL,0,NULL};
static int argument_run(void){
 void *nodes=NULL,*locals=NULL,*statements=NULL,*tokens=NULL,*procedures=NULL,*parameters=NULL;
 struct ube_gc_root roots[6]={{0}};void** holders[]={&nodes,&locals,&statements,&tokens,&procedures,&parameters};
 for(int i=0;i<6;++i)CHECK(ube_gc_root_enter(&roots[i],holders[i]));
 CHECK(ube_value_try_resize(&tokens,2,&token_layout,0));
 *(struct token*)ube_array_element(tokens,0)=(struct token){0,0,0,"Target",""};
 *(struct token*)ube_array_element(tokens,1)=(struct token){0,0,0,"Unknown",""};
 CHECK(ube_value_try_resize(&procedures,1,&procedure_layout,0));
 struct procedure* proc=ube_array_element(procedures,0);*proc=(struct procedure){0};proc->count=1;
 CHECK(ube_value_try_resize(&parameters,2,&parameter_layout,0));
 struct parameter* p0=ube_array_element(parameters,0);struct parameter* p1=ube_array_element(parameters,1);
 *p0=(struct parameter){0,0,0,1,0};*p1=(struct parameter){0,0,0,2,0};
 CHECK(reset(&nodes,8));at(nodes,0)->kind=12;at(nodes,0)->type=1000;
 at(nodes,1)->kind=17;at(nodes,1)->left=0;
 at(nodes,2)->kind=12;at(nodes,2)->token=0;
 at(nodes,3)->kind=13;at(nodes,3)->left=2;at(nodes,3)->right=1;
 #define PREPARE() q_prepare_ex(&nodes,8,&locals,0,&statements,0,&tokens,2,&procedures,1,&parameters,2)
 CHECK(PREPARE()&&at(nodes,0)->uses==1&&!q_needs(&nodes,0));
 p0->mode=3;CHECK(PREPARE()&&at(nodes,0)->uses==1&&!q_needs(&nodes,0));
 p0->mode=2;CHECK(PREPARE()&&at(nodes,0)->uses==2&&q_needs(&nodes,0));
 p0->mode=1;CHECK(PREPARE()&&at(nodes,0)->uses==1); /* fresh flags */
 p0->owner=-1;CHECK(PREPARE()&&at(nodes,0)->uses==2&&q_needs(&nodes,0));p0->owner=0;
 at(nodes,2)->token=1;CHECK(PREPARE()&&at(nodes,0)->uses==2&&q_needs(&nodes,0));at(nodes,2)->token=0;
 proc->count=0;CHECK(PREPARE()&&at(nodes,0)->uses==2&&q_needs(&nodes,0));proc->count=1;
 at(nodes,3)->kind=0;CHECK(PREPARE()&&at(nodes,0)->uses==2&&q_needs(&nodes,0));at(nodes,3)->kind=13;
 /* Exact alias, then independently value-used same actual. */
 at(nodes,1)->right=4;at(nodes,4)->kind=17;at(nodes,4)->left=0;proc->count=2;
 p1->mode=1;CHECK(PREPARE()&&at(nodes,0)->uses==1&&!q_needs(&nodes,0));
 p1->mode=2;CHECK(PREPARE()&&at(nodes,0)->uses==3&&q_needs(&nodes,0));
 at(nodes,1)->right=-1;at(nodes,4)->kind=0;at(nodes,4)->left=-1;proc->count=1;
 /* Missing-callee shared links must contribute conservative value use. */
 at(nodes,4)->kind=13;at(nodes,4)->left=-1;at(nodes,4)->right=1;
 CHECK(PREPARE()&&at(nodes,1)->uses==3&&at(nodes,0)->uses==2&&q_needs(&nodes,0));
 at(nodes,4)->kind=0;at(nodes,4)->right=-1;
 CHECK(ube_value_try_resize(&locals,1,&local_layout,0));
 *(struct local*)ube_array_element(locals,0)=(struct local){0,0,0,0,0,0,0};
 CHECK(q_prepare_ex(&nodes,8,&locals,1,&statements,0,&tokens,2,&procedures,1,&parameters,2)&&at(nodes,0)->uses==3&&q_needs(&nodes,0));
 /* CLASS receiver still loads; only its field actual is address-only. */
 at(nodes,0)->type=20000;at(nodes,5)->kind=14;at(nodes,5)->left=0;at(nodes,5)->type=1000;at(nodes,1)->left=5;
 CHECK(PREPARE()&&at(nodes,0)->uses==2&&q_needs(&nodes,0)&&at(nodes,5)->uses==1&&!q_needs(&nodes,5));
 at(nodes,5)->kind=0;at(nodes,5)->left=-1;at(nodes,5)->type=0;at(nodes,0)->type=1000;at(nodes,1)->left=0;
 at(nodes,1)->right=1;CHECK(!PREPARE());at(nodes,1)->right=-1;
 CHECK(PREPARE()&&at(nodes,0)->uses==1); /* fresh success after failure */
 for(int i=5;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));
 CHECK(ube_gc_collect()&&!ube_gc_root_count&&!ube_gc_live_allocation_bytes());
 printf("PASS ByRef argument controls cumulative assertions:%u\n",checks);return 1;
}
int main(void){return run()&&argument_run()?0:1;}
