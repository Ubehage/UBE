#define TARGETED_ENTRY_NAME targeted_fixture_main
static void overlap_begin(void* input);
static void overlap_end(void);
#define TARGETED_BEFORE_CHECK(input) overlap_begin(input)
#define TARGETED_AFTER_CHECK() overlap_end()
#include "targeted-probe.c"
struct semantic_work {struct catalog* catalog;struct source* source;void* cancellation;struct limits limits;int32_t max_facts,max_pending;void* facts;int32_t fact_count;void* values;int32_t value_count,root,scope;struct failure failure,diagnostic;struct metrics metrics;struct module* result;int64_t worker;int32_t state;};
_Static_assert(sizeof(struct semantic_work)==256&&offsetof(struct semantic_work,worker)==240&&offsetof(struct semantic_work,state)==248,"semantic worker ABI");
extern int32_t statement_bind(struct semantic_work*);
static _Atomic int arrivals,active_workers,peak_workers,finished,bad;
static int expected_parallel;
static _Atomic uintptr_t captured_work[4];
static _Atomic int64_t native_ids[4];
static _Atomic uint32_t os_ids[4];
static void overlap_begin(void* original){struct project_syntax* input=original;for(int i=0;i<4;++i){struct work* work=*(struct work**)ube_array_element(input->work,i);struct syntax* syntax=ube_array_element(work->syntax,0);borrowed[4*i]=work->owner->document.bytes;borrowed[4*i+1]=work->tokens;borrowed[4*i+2]=work->syntax;borrowed[4*i+3]=syntax->nodes;}atomic_store(&enabled,true);}
static void overlap_end(void){atomic_store(&enabled,false);}
int32_t whole_semantic_worker(struct semantic_work* work){
 int slot=atomic_fetch_add(&arrivals,1),active=atomic_fetch_add(&active_workers,1)+1;int peak=atomic_load(&peak_workers);while(active>peak&&!atomic_compare_exchange_weak(&peak_workers,&peak,active)){}
 if(slot<0||slot>=4||!work||!work->source){atomic_store(&bad,1);}else{atomic_store(&captured_work[slot],(uintptr_t)work);atomic_store(&os_ids[slot],GetCurrentThreadId());}
 ULONGLONG start=GetTickCount64();while(atomic_load(&arrivals)<expected_parallel){if(GetTickCount64()-start>10000){atomic_store(&bad,1);break;}Sleep(0);}
 int32_t accepted=statement_bind(work);
 if(work&&work->source){int source=work->source->source;
#ifdef OVERLAP_NEGATIVE_CAPTURE
  source=source+1;
#endif
  if(source<0||source>=4||!accepted||work->state!=2||work->failure.kind!=5||work->worker<=0||work->result||work->fact_count!=3||work->value_count!=5)atomic_store(&bad,1);
  int constants=0;for(int i=0;i<work->value_count;++i){struct node* n=ube_array_element(work->values,i);if(n->source!=source)atomic_store(&bad,1);if(n->kind==1){++constants;if(n->type!=4||n->value!=source+1||n->children!=0||n->child!=-1)atomic_store(&bad,1);}}
  if(constants!=1)atomic_store(&bad,1);if(slot>=0&&slot<4)atomic_store(&native_ids[slot],work->worker);
 }
 atomic_fetch_sub(&active_workers,1);atomic_fetch_add(&finished,1);
 return accepted;
}
int main(int argc,char** argv){
 if(argc!=4||strcmp(argv[1],"--project"))return 2;expected_parallel=atoi(argv[3]);if(expected_parallel!=1&&expected_parallel!=2&&expected_parallel!=4)return 2;
 int result=targeted_fixture_main(argc,argv);CHECK(result==0&&atomic_load(&arrivals)==4&&atomic_load(&finished)==4&&atomic_load(&active_workers)==0&&atomic_load(&peak_workers)==expected_parallel);
 for(int i=0;i<4;++i){CHECK(atomic_load(&captured_work[i])!=0&&atomic_load(&native_ids[i])>0&&atomic_load(&os_ids[i])!=0);for(int j=0;j<i;++j){CHECK(atomic_load(&captured_work[i])!=atomic_load(&captured_work[j])&&atomic_load(&native_ids[i])!=atomic_load(&native_ids[j]));if(expected_parallel==4)CHECK(atomic_load(&os_ids[i])!=atomic_load(&os_ids[j]));}}
 CHECK(atomic_load(&bad)==0);CHECK(index_root_count()==0&&ube_gc_live_allocation_bytes()==0&&whole_worker_count()==0&&atomic_load(&capture_live)==0);
 CHECK(atomic_load(&capture_bytes)==32&&atomic_load(&source_copies)==0&&atomic_load(&source_resizes)==0);
 printf("{\"overlap\":true,\"jobs\":%d,\"actualPeakWorkers\":%d,\"admitted\":%d,\"completed\":%d,\"actualCaptureBytes\":%zu,\"sourceCopies\":%zu,\"actualAllocations\":%zu,\"actualCopiedBytes\":%zu,\"rootPeak\":%zu,\"heapPeak\":%zu,\"passed\":true}\n",expected_parallel,atomic_load(&peak_workers),atomic_load(&arrivals),atomic_load(&finished),atomic_load(&capture_bytes),atomic_load(&source_copies),atomic_load(&allocations),atomic_load(&copied),atomic_load(&root_peak),atomic_load(&heap_peak));return 0;
}
