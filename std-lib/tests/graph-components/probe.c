#define main retained_file_output_main
#include "std-lib/tests/file-output/native.c"
#undef main
#undef CHECK
#define CHECK(c) do { ++checks; if (!(c)) { fprintf(stderr,"graph component assertion line %d: %s\n",__LINE__,#c); return 1; } } while (0)
struct slot {int32_t seen,order,component,vertex,neighbor;};
struct components {void* slots;int32_t capacity,status,direction,index,stack_count,order_count,component_count;};
extern int32_t components_begin(struct components*,void**,int32_t,int32_t*);
extern int32_t components_advance(struct components*,void**,int32_t,int32_t,int32_t*,int32_t*,int32_t*,bool*,int32_t*);
extern int32_t components_read(struct components*,int32_t,int32_t*,int32_t*);
extern int32_t components_dispose(struct components*,int32_t*);
static _Thread_local uint64_t transition_events;
static _Thread_local int32_t observed_pending_peak;
void graph_transition_event(struct components* state) {
 if(state->stack_count>observed_pending_peak)observed_pending_peak=state->stack_count;
#ifndef OMIT_TRANSITION_CONTROL
 ++transition_events;
#endif
}
static int32_t advance_limit(struct components* c,void** matrix,int32_t allowance,int32_t limit,int32_t* used,bool* complete,int32_t* failure) {
 int32_t pending=c->stack_count,peak=pending;observed_pending_peak=pending;
 int32_t ok=components_advance(c,matrix,allowance,limit,used,&pending,&peak,complete,failure);
 if(c->stack_count>observed_pending_peak)observed_pending_peak=c->stack_count;
 if((ok || *failure==2) && (pending!=c->stack_count || peak!=observed_pending_peak || peak>c->capacity)){fprintf(stderr,"graph pending observation mismatch\n");return 0;}
 return ok;
}
static int32_t advance(struct components* c,void** matrix,int32_t allowance,int32_t* used,bool* complete,int32_t* failure) {
 return advance_limit(c,matrix,allowance,INT32_MAX,used,complete,failure);
}
static const struct ube_value_layout long_layout={4,0,0,NULL,0,NULL};
static void* payload(void* owner){return ((struct ube_array*)owner)->data;}
/* Independent transitive closure, deliberately unlike the production stacks. */
static int relation(const int32_t* matrix,int n,const int32_t* labels) {
 unsigned char reach[64*64]={0};
 for(int i=0;i<n;++i)for(int j=0;j<n;++j)reach[i*n+j]=(i==j || matrix[i*n+j]!=0);
 for(int k=0;k<n;++k)for(int i=0;i<n;++i)for(int j=0;j<n;++j)if(reach[i*n+k] && reach[k*n+j])reach[i*n+j]=1;
 for(int i=0;i<n;++i)for(int j=0;j<n;++j)if((labels[i]==labels[j])!=(reach[i*n+j] && reach[j*n+i]))return 0;
 return 1;
}
static int run_graph(const int32_t* source,int n) {
 void* matrix=NULL;struct components left={0},right={0};struct ube_gc_root roots[3]={{0}};void** owners[]={&matrix,&left.slots,&right.slots};
 for(int i=0;i<3;++i)CHECK(ube_gc_root_enter(&roots[i],owners[i]));
 CHECK(ube_value_try_resize(&matrix,n*n,&long_layout,0));if(n)memcpy(payload(matrix),source,(size_t)n*n*4);
 int32_t failure=5;CHECK(components_begin(&left,&matrix,n,&failure) && failure==0 && left.capacity==n);
 failure=5;CHECK(components_begin(&right,&matrix,n,&failure) && failure==0 && right.capacity==n);
 CHECK((n==0 && !left.slots) || (left.slots && ((struct ube_array*)left.slots)->lower==0 && ((struct ube_array*)left.slots)->upper==n-1 && ((struct ube_array*)left.slots)->element_size==20));
 int32_t value=-99;failure=5;CHECK(!components_read(&left,0,&value,&failure) && failure==1 && value==-99);
 const int64_t expected=n?2*(int64_t)n*n+5*n+2:0;int64_t work[2]={0,0};bool done[2]={false,n==0};int32_t labels[2][64]={{0}};
 ube_err_set(77,"prior","graph components");
 struct components untouched=left;int32_t used=0;failure=5;observe();
 CHECK(advance(&left,&matrix,0,&used,&done[0],&failure) && failure==0 && used==0 && clean_cost());
 CHECK(memcmp(&untouched,&left,sizeof(left))==0 && done[0]==(n==0));
 unsigned iteration=0;
 do {
  for(int s=0;s<2;++s)if(!done[s]) {
   struct components* owner=s?&right:&left;int32_t allowance=s?4096:1+(int32_t)(iteration%11);
   if(expected-work[s]<allowance)allowance=(int32_t)(expected-work[s]);
   CHECK(allowance>0);failure=5;used=0;uint64_t before_events=transition_events;observe();
   CHECK(advance(owner,&matrix,allowance,&used,&done[s],&failure) && failure==0 && clean_cost());
   CHECK(used>0 && used<=allowance && (uint64_t)used==transition_events-before_events);work[s]+=used;CHECK(work[s]<=expected && done[s]==(work[s]==expected));
  }
  ++iteration;
 } while(!done[0] || !done[1]);
 CHECK(work[0]==expected && work[1]==expected && left.component_count==right.component_count && ube_err_number()==77);
 for(int i=0;i<n;++i)for(int s=0;s<2;++s){failure=5;observe();CHECK(components_read(s?&right:&left,i,&labels[s][i],&failure) && failure==0 && clean_cost());CHECK(labels[s][i]>0);}
 CHECK(memcmp(labels[0],labels[1],(size_t)n*4)==0);
#ifdef WRONG_COMPONENT_CONTROL
 if(n>1)labels[0][0]=labels[0][1];
#endif
 CHECK(relation(source,n,labels[0]));if(n)CHECK(memcmp(source,payload(matrix),(size_t)n*n*4)==0);
 used=99;failure=5;bool complete=false;CHECK(advance(&left,&matrix,7,&used,&complete,&failure) && complete && used==0 && failure==0);
 value=-99;failure=5;CHECK(!components_read(&left,n,&value,&failure) && failure==1 && value==-99);
 failure=5;CHECK(components_dispose(&left,&failure) && failure==0 && left.slots==NULL && left.capacity==0 && left.status==0);
 failure=5;CHECK(components_dispose(&right,&failure) && failure==0);
 for(int i=2;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));(void)ube_gc_collect();CHECK(ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);return 0;
}
static int failures(void) {
 struct components c={0};void* matrix=NULL;struct ube_gc_root roots[2]={{0}};
 CHECK(ube_gc_root_enter(&roots[0],&c.slots) && ube_gc_root_enter(&roots[1],&matrix));
 CHECK(ube_value_try_resize(&matrix,16,&long_layout,0));int32_t failure=5,used=0;bool complete=false;
 const int invalid[]={-1,5,INT32_MAX};
 for(int i=0;i<3;++i){failure=5;CHECK(!components_begin(&c,&matrix,invalid[i],&failure) && failure==1 && !c.slots && c.capacity==0);CHECK(components_dispose(&c,&failure));}
 ube_gc_test_fail_next_allocations(1000000);failure=5;CHECK(!components_begin(&c,&matrix,4,&failure) && failure==5 && c.capacity==0);ube_gc_test_fail_next_allocations(0);CHECK(components_dispose(&c,&failure));
 failure=5;CHECK(components_begin(&c,&matrix,4,&failure));struct components before=c;failure=5;CHECK(!components_begin(&c,&matrix,4,&failure) && failure==1 && memcmp(&before,&c,sizeof(c))==0);
 failure=5;CHECK(!advance(&c,&matrix,-1,&used,&complete,&failure) && failure==1 && c.status==4);CHECK(components_dispose(&c,&failure));
 failure=5;CHECK(components_begin(&c,&matrix,4,&failure));c.direction=2;c.index=4;failure=5;CHECK(!advance(&c,&matrix,1,&used,&complete,&failure) && failure==1 && c.status==4);CHECK(components_dispose(&c,&failure));
 failure=5;CHECK(components_begin(&c,&matrix,4,&failure));c.direction=1;c.stack_count=1;((struct slot*)payload(c.slots))[0].vertex=-1;failure=5;CHECK(!advance(&c,&matrix,1,&used,&complete,&failure) && failure==1 && c.status==4);CHECK(components_dispose(&c,&failure));
 failure=5;CHECK(components_begin(&c,&matrix,4,&failure));CHECK(ube_value_try_resize(&matrix,15,&long_layout,0));failure=5;CHECK(!advance(&c,&matrix,1,&used,&complete,&failure) && failure==1 && c.status==4);CHECK(components_dispose(&c,&failure));CHECK(ube_value_try_resize(&matrix,16,&long_layout,0));
 size_t available=UBE_GC_MAX_ROOTS-ube_gc_root_count;struct ube_gc_root* pressure=calloc(available,sizeof(*pressure));void* neutral=NULL;CHECK(pressure);
 for(size_t i=0;i<available;++i)CHECK(ube_gc_root_enter(&pressure[i],&neutral));
 failure=5;int ok=components_begin(&c,&matrix,4,&failure);CHECK(!ok && failure==5 && c.capacity==0);
 for(size_t i=0;i<available;++i)CHECK(ube_gc_root_leave(&pressure[i]));free(pressure);CHECK(components_dispose(&c,&failure));
 CHECK(ube_gc_root_leave(&roots[1]) && ube_gc_root_leave(&roots[0]));CHECK(ube_gc_collect() && ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);return 0;
}

static int pending_cases(void) {
 struct components c={0};void* matrix=NULL;struct ube_gc_root roots[2]={{0}};
 CHECK(ube_gc_root_enter(&roots[0],&c.slots) && ube_gc_root_enter(&roots[1],&matrix));
 CHECK(ube_value_try_resize(&matrix,64,&long_layout,0));int32_t* cells=payload(matrix);
 for(int chain=0;chain<2;++chain) for(int limit=0;limit<=9;++limit) {
  memset(cells,0,64*4);if(chain)for(int i=0;i<7;++i)cells[i*8+i+1]=1;
  int32_t failure=5,used=0;bool complete=false;CHECK(components_begin(&c,&matrix,8,&failure));
  int ok=advance_limit(&c,&matrix,1000,limit,&used,&complete,&failure);
  if(limit<(chain?8:1))CHECK(!ok && failure==2 && !complete && c.status==4 && c.stack_count==limit && used>0 && used<170);
  else CHECK(ok && failure==0 && complete && used==170 && c.stack_count==0);
  CHECK(components_dispose(&c,&failure));
 }
 CHECK(ube_gc_root_leave(&roots[1]) && ube_gc_root_leave(&roots[0]));
 (void)ube_gc_collect();CHECK(ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);return 0;
}
int main(void) {
 CHECK(sizeof(struct slot)==20 && sizeof(struct components)==40);
 int32_t matrix[64*64]={0};CHECK(run_graph(matrix,0)==0 && run_graph(matrix,1)==0 && run_graph(matrix,2)==0);
 for(unsigned bits=0;bits<512;++bits){for(int i=0;i<9;++i)matrix[i]=(bits&(1u<<i))?(i%2?-7:3):0;CHECK(run_graph(matrix,3)==0);}
 const int sizes[]={4,8,16,32,64};
 for(int k=0;k<5;++k){int n=sizes[k];for(int shape=0;shape<5;++shape){memset(matrix,0,sizeof(matrix));for(int i=0;i<n;++i)for(int j=0;j<n;++j){bool edge=shape==0?i+1==j:shape==1?(i+1)%n==j:shape==2?true:shape==3?(i/3==j/3 || (i%3==0 && i+3==j)):((i*17+j*31+7)%23<3);matrix[i*n+j]=edge?11:0;}CHECK(run_graph(matrix,n)==0);}}
 CHECK(failures()==0 && pending_cases()==0);printf("PASS graph components %d assertions\n",checks);return 0;
}
