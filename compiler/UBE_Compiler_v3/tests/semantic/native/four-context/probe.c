#define main scalar_fixture_main
#include "base-probe.c"
#undef main
#include "exact-small.h"
extern int32_t shared_is_live(void*),ube_thread_try_request_stop(int64_t,int32_t*);
struct semantic_work {struct catalog* catalog;struct source* source;void* cancellation;struct limits limits;int32_t max_facts,max_pending;void* facts;int32_t fact_count;void* values;int32_t value_count,root,scope;struct failure failure,diagnostic;struct metrics metrics;struct module* result;int64_t worker;int32_t state;};
_Static_assert(sizeof(struct semantic_work)==256,"four context work ABI");
extern int32_t four_bind_body(struct semantic_work*);
struct context {struct source* input;void* cancellation;struct result* result;struct result* old;struct limits limits;struct failure failure;int ok,err;DWORD caller;struct catalog* catalog;struct semantic_work* work;int64_t worker;};
static struct context contexts[4];
static _Atomic int armed,arrived,release_workers,returned,release_callers,active,peak,control_errors;
static struct work* target_work;
static void max_active(int value){int previous=atomic_load(&peak);while(value>previous&&!atomic_compare_exchange_weak(&peak,&previous,value)){} }
static int wait_flag(_Atomic int* flag,int value){ULONGLONG start=GetTickCount64();while(atomic_load(flag)!=value){if(GetTickCount64()-start>30000)return 0;Sleep(0);}return 1;}
int32_t four_bind(struct semantic_work* work){
 if(!atomic_load(&armed))return four_bind_body(work);
 if(!shared_is_live(work)){atomic_fetch_add(&control_errors,1);return 0;}
 int slot=-1;for(int i=0;i<4;++i)if(contexts[i].cancellation==work->cancellation)slot=i;
 if(slot<0||!shared_is_live(work)||!shared_is_live(work->catalog)||!shared_is_live(work->source)){atomic_fetch_add(&control_errors,1);return four_bind_body(work);}
 struct context* c=&contexts[slot];if(c->work||work->source->input!=target_work||!work->worker)atomic_fetch_add(&control_errors,1);
 c->work=work;c->catalog=work->catalog;c->worker=work->worker;
 max_active(atomic_fetch_add(&active,1)+1);atomic_fetch_add(&arrived,1);
 if(!wait_flag(&release_workers,1))atomic_fetch_add(&control_errors,1);
 int32_t accepted=four_bind_body(work);atomic_fetch_sub(&active,1);return accepted;
}
static DWORD WINAPI call_context(LPVOID value){struct context* c=value;root roots[2]={{0}};c->caller=GetCurrentThreadId();if(!ube_gc_root_enter(&roots[0],(void**)&c->result)||!ube_gc_root_enter(&roots[1],&c->cancellation)){atomic_fetch_add(&control_errors,1);atomic_fetch_add(&returned,1);return 1;}
 int index=(int)(c-contexts);ube_err_set(77+index,"prior","separate whole context");c->failure=(struct failure){5,1428,-1,0,0,-1,0,0};
 c->ok=statement_check(c->input,1,&c->limits,c->cancellation,(void**)&c->result,&c->failure);c->err=ube_err_number();atomic_fetch_add(&returned,1);
 if(!wait_flag(&release_callers,1))atomic_fetch_add(&control_errors,1);
 if(!ube_gc_root_leave(&roots[1])||!ube_gc_root_leave(&roots[0]))atomic_fetch_add(&control_errors,1);return 0;
}
static uint64_t full_hash(const struct result* result){uint64_t h=hash_result(result);struct catalog* c=result->catalog;h=hash_bytes(h,c,sizeof *c);int count=ube_value_array_length(&result->modules);for(int i=0;i<count;++i){struct module* m=*(struct module**)ube_array_element(result->modules,i);h=hash_bytes(h,m,sizeof *m);h=hash_array(h,m->facts,sizeof(struct fact));h=hash_array(h,m->values,sizeof(struct node));}return h;}
static uint64_t logical_rows(uint64_t h,void* values,int count,size_t width){h=hash_bytes(h,&count,sizeof count);for(int i=0;i<count;++i)h=hash_bytes(h,ube_array_element(values,i),width);return h;}
static uint64_t logical_hash(const struct result* r){struct catalog* c=r->catalog;struct module* m=module(r);uint64_t h=hash_bytes(UINT64_C(1469598103934665603),&r->entry,4);h=logical_rows(h,c->declarations,c->declaration_count,64);h=logical_rows(h,c->types,c->type_count,40);h=logical_rows(h,c->names,c->name_count,24);h=logical_rows(h,c->name_bytes.bytes,c->name_bytes.count,1);h=logical_rows(h,c->facts,c->fact_count,48);h=logical_rows(h,c->values,c->value_count,48);h=logical_rows(h,m->facts,m->fact_count,48);return logical_rows(h,m->values,m->value_count,48);}
static int live_graph(struct work* work){CHECK(shared_is_live(work)&&shared_is_live(work->owner)&&shared_is_live(work->owner->document.bytes)&&shared_is_live(work->tokens)&&shared_is_live(work->syntax));struct syntax* s=ube_array_element(work->syntax,0);CHECK(shared_is_live(s->nodes));return 0;}
static int private_catalog_arrays(const struct catalog* a,const struct catalog* b){void* left[]={a->sources,a->declarations,a->types,a->names,a->name_bytes.bytes,a->keys,a->order,a->facts,a->values};void* right[]={b->sources,b->declarations,b->types,b->names,b->name_bytes.bytes,b->keys,b->order,b->facts,b->values};for(int i=0;i<9;++i)if(left[i]&&right[i])CHECK(left[i]!=right[i]);struct source* sa=*(struct source**)ube_array_element(a->sources,0),*sb=*(struct source**)ube_array_element(b->sources,0);CHECK(sa!=sb&&sa->name_map!=sb->name_map&&sa->input==target_work&&sb->input==target_work);return 0;}
static int unowned_control(void){struct environment weak={0};CHECK(ube_gc_root_enter(&weak.roots[0],&weak.bytes)&&ube_gc_root_enter(&weak.roots[1],(void**)&weak.input));CHECK(input(&weak,"UBE SOURCE 1 MODULE\nAttribute UBE_Name = \"WeakGraph\"\nSub Main()\nEnd Sub\n")==0);struct source* borrowed_source=weak.input;struct work* borrowed_work=weak.input->input;void* borrowed_bytes=borrowed_work->owner->document.bytes;CHECK(ube_gc_root_leave(&weak.roots[1])&&ube_gc_root_leave(&weak.roots[0]));weak.input=NULL;weak.bytes=NULL;(void)ube_gc_collect();CHECK(!shared_is_live(borrowed_source)&&!shared_is_live(borrowed_work)&&!shared_is_live(borrowed_bytes));int admitted=shared_is_live(borrowed_source);CHECK(!admitted);puts("{\"suite\":\"four-context-unowned-borrow\",\"reclaimed\":true,\"admissionRejected\":true,\"dereferencedFreedStorage\":false,\"passed\":true}");return 0;}
int main(void){
 CHECK(sizeof(struct catalog)==240&&sizeof(struct source)==64&&sizeof(struct work)==88&&sizeof(root)>=ube_gc_root_storage_size());
 struct environment prior={0},shared={0};void* cancellations[4]={0};struct result* old[4]={0},*published[4]={0};root old_roots[4]={{0}},cancel_roots[4]={{0}},new_roots[4]={{0}};
 void** prior_slots[]={&prior.bytes,(void**)&prior.input,&prior.cancellation,(void**)&prior.result};for(int i=0;i<4;++i)CHECK(ube_gc_root_enter(&prior.roots[i],prior_slots[i]));
 CHECK(statement_cancel(&prior.cancellation)&&input(&prior,"UBE SOURCE 1 MODULE\nAttribute UBE_Name = \"BlankApp\"\nSub Main()\nEnd Sub\n")==0);
 uint64_t old_hashes[4];for(int i=0;i<4;++i){CHECK(ube_gc_root_enter(&old_roots[i],(void**)&old[i])&&ube_gc_root_enter(&cancel_roots[i],&cancellations[i])&&ube_gc_root_enter(&new_roots[i],(void**)&published[i]));struct failure failure={5,1428,-1,0,0,-1,0,0};CHECK(statement_check(prior.input,1,&generous,prior.cancellation,(void**)&prior.result,&failure)&&failure.kind==0&&empty_case(&prior)==0);CHECK(prior.result->catalog->fact_count==1&&prior.result->catalog->value_count==0);old[i]=prior.result;old_hashes[i]=full_hash(old[i]);CHECK(statement_cancel(&cancellations[i])&&cancellations[i]);for(int j=0;j<i;++j)CHECK(old[i]!=old[j]&&old[i]->catalog!=old[j]->catalog&&cancellations[i]!=cancellations[j]);}
 for(int i=3;i>=0;--i)CHECK(ube_gc_root_leave(&prior.roots[i]));memset(&prior,0,sizeof prior);(void)ube_gc_collect();
 CHECK(ube_gc_root_enter(&shared.roots[0],&shared.bytes)&&ube_gc_root_enter(&shared.roots[1],(void**)&shared.input)&&input(&shared,valid_source)==0);target_work=shared.input->input;CHECK(live_graph(target_work)==0);uint64_t original=hash_input(shared.input);observe_input(shared.input);
 for(int i=0;i<4;++i){contexts[i]=(struct context){.input=shared.input,.cancellation=cancellations[i],.result=old[i],.old=old[i],.limits=generous};}contexts[1].limits=(struct limits){3,9,6,1};contexts[2].limits=(struct limits){3,10,6,1};
 atomic_store(&allocations,0);atomic_store(&copied,0);atomic_store(&source_copies,0);atomic_store(&source_resizes,0);atomic_store(&capture_bytes,0);atomic_store(&capture_live,0);atomic_store(&root_peak,index_root_count());atomic_store(&heap_peak,ube_gc_live_allocation_bytes());atomic_store(&enabled,true);atomic_store(&armed,1);
 HANDLE threads[4];for(int i=0;i<4;++i){threads[i]=CreateThread(NULL,0,call_context,&contexts[i],0,NULL);CHECK(threads[i]);}CHECK(wait_flag(&arrived,4));
 CHECK(atomic_load(&active)==4&&whole_worker_count()==4&&atomic_load(&capture_live)==4&&!atomic_load(&control_errors));for(int i=0;i<4;++i){CHECK(contexts[i].work&&contexts[i].catalog&&contexts[i].worker>0&&contexts[i].catalog->source_count==1&&contexts[i].work->source->input==target_work);for(int j=0;j<i;++j)CHECK(contexts[i].catalog!=contexts[j].catalog&&contexts[i].work!=contexts[j].work&&contexts[i].worker!=contexts[j].worker&&contexts[i].caller!=contexts[j].caller&&private_catalog_arrays(contexts[i].catalog,contexts[j].catalog)==0);CHECK(!*(uint8_t*)cancellations[i]);}
 CHECK(ube_gc_root_leave(&shared.roots[1])&&ube_gc_root_leave(&shared.roots[0]));shared.input=NULL;shared.bytes=NULL;(void)ube_gc_collect();CHECK(live_graph(target_work)==0);struct source view={.input=target_work};CHECK(hash_input(&view)==original);int32_t stop_detail=5;CHECK(ube_thread_try_request_stop(contexts[3].worker,&stop_detail)&&!*(uint8_t*)cancellations[3]);atomic_store(&release_workers,1);CHECK(wait_flag(&returned,4));
 for(int i=0;i<4;++i)published[i]=contexts[i].result;atomic_store(&release_callers,1);CHECK(WaitForMultipleObjects(4,threads,TRUE,30000)==WAIT_OBJECT_0);for(int i=0;i<4;++i)CHECK(CloseHandle(threads[i]));atomic_store(&armed,0);atomic_store(&enabled,false);
 CHECK(!atomic_load(&control_errors)&&atomic_load(&active)==0&&whole_worker_count()==0&&atomic_load(&capture_live)==0&&atomic_load(&capture_bytes)==32&&atomic_load(&source_copies)==0&&atomic_load(&source_resizes)==0);
 int expected_peak=4;
#ifdef NEGATIVE_FOUR_OVERLAP
 expected_peak=3;
#endif
 CHECK(atomic_load(&peak)==expected_peak);const struct failure budget={2,1427,0,0,0,-1,0,0},cancel={4,1429,0,0,0,-1,0,0};for(int i=0;i<4;++i){CHECK(contexts[i].err==77+i&&full_hash(old[i])==old_hashes[i]&&!*(uint8_t*)cancellations[i]);if(i==0||i==2){struct environment expected={.input=&view,.result=published[i]};CHECK(contexts[i].ok&&contexts[i].failure.kind==0&&contexts[i].failure.code==0&&published[i]!=old[i]&&published[i]->catalog==contexts[i].catalog&&exact_small_result(&expected)==0);CHECK(!memcmp(&published[i]->catalog->limits,&contexts[i].limits,sizeof(struct limits)));}else{CHECK(!contexts[i].ok&&published[i]==old[i]&&!memcmp(&contexts[i].failure,i==1?&budget:&cancel,sizeof(struct failure)));}}
 CHECK(published[0]->catalog!=published[2]->catalog&&published[0]->catalog->declarations!=published[2]->catalog->declarations&&module(published[0])->facts!=module(published[2])->facts&&module(published[0])->values!=module(published[2])->values&&logical_hash(published[0])==logical_hash(published[2]));
 (void)ube_gc_collect();CHECK(live_graph(target_work)==0&&hash_input(&view)==original&&shared_is_live(contexts[0].catalog)&&shared_is_live(contexts[2].catalog)&&!shared_is_live(contexts[1].catalog)&&!shared_is_live(contexts[3].catalog));CHECK(unowned_control()==0);for(int i=0;i<4;++i)CHECK(full_hash(old[i])==old_hashes[i]);
 printf("{\"suite\":\"four-context-whole-checker\",\"contexts\":4,\"actualInnerWorkerPeak\":%d,\"captureBytes\":%zu,\"sourceCopies\":%zu,\"sourceResizes\":%zu,\"allocations\":%zu,\"copiedBytes\":%zu,\"rootPeak\":%zu,\"heapPeak\":%zu,\"privateCatalogs\":true,\"oldOwnersPreserved\":true,\"inputUnchanged\":true,\"passed\":true}\n",atomic_load(&peak),atomic_load(&capture_bytes),atomic_load(&source_copies),atomic_load(&source_resizes),atomic_load(&allocations),atomic_load(&copied),atomic_load(&root_peak),atomic_load(&heap_peak));
 for(int i=3;i>=0;--i){CHECK(ube_gc_root_leave(&new_roots[i])&&ube_gc_root_leave(&cancel_roots[i])&&ube_gc_root_leave(&old_roots[i]));}memset(contexts,0,sizeof contexts);(void)ube_gc_collect();CHECK(index_root_count()==0&&ube_gc_live_allocation_bytes()==0&&whole_worker_count()==0);printf("PASS four simultaneous whole contexts assertions:%u\n",assertions);return 0;
}
