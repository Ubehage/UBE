/* Independent fixed-slot state/control assertions around actual UBE workers. */
struct source_worker_slots {
 int64_t ids[4];int32_t sources[4];int32_t jobs,total,next,active;
 uint8_t stopped;int32_t cursor,first_kind,first_source;
};
_Static_assert(sizeof(struct source_worker_slots)==80,"independent rootless slot payload");
extern size_t proof_slots_size(void);
extern int32_t proof_slots_init(struct source_worker_slots*,int32_t,int32_t);
extern int32_t proof_slots_next(struct source_worker_slots*,int32_t,int32_t,int32_t*,int32_t*);
extern void proof_slots_commit(struct source_worker_slots*,int32_t,int64_t);
extern void proof_slots_failure(struct source_worker_slots*,int32_t,int32_t);
extern int64_t proof_slots_id(struct source_worker_slots*,int32_t);
static int slot_wait_fault,slot_stop_fault;
static unsigned slot_wait_calls,slot_stop_calls,slot_yield_calls;
int32_t observed_slot_wait(int64_t id,int64_t timeout,uint8_t* completed){
 ++slot_wait_calls;if(timeout!=1){fprintf(stderr,"FAIL controller wait timeout\n");return 0;}
 if(slot_wait_fault){--slot_wait_fault;ube_err_set(7,"injected slot wait","controller native test");return 0;}
 return ube_thread_try_wait(id,timeout,completed);
}
int32_t observed_slot_stop(int64_t id,uint8_t* requested){
 ++slot_stop_calls;if(slot_stop_fault){--slot_stop_fault;ube_err_set(7,"injected slot stop","controller native test");return 0;}
 return ube_thread_try_request_stop(id,requested);
}
int32_t observed_slot_yield(void){++slot_yield_calls;return ube_thread_try_yield();}
static int slot_action(struct source_worker_slots* slots,int cancel,int allow,int* slot,int* source){
 unsigned waits=slot_wait_calls,stops=slot_stop_calls,yields=slot_yield_calls;
 int action=proof_slots_next(slots,cancel,allow,slot,source);
 if(!require(slot_wait_calls-waits<=1&&slot_stop_calls-stops<=1&&slot_yield_calls-yields<=1,"one bounded wait/stop/yield per controller action"))return -1;
 return action;
}
static int prove_worker_slots(void* published){
 struct source_worker_slots slots={0};int slot=-9,source=-9;int success=0;
 void* private_work=NULL;struct ube_gc_root owner={0};int rooted=0;int64_t outstanding=0;
 const size_t before_roots=ube_gc_root_count;
#define SLOT_CHECK(value,message) do{if(!require(!!(value),(message)))goto cleanup;}while(0)
 SLOT_CHECK(proof_slots_size()==sizeof slots,"actual fixed controller scalar payload is80bytes");
 const int invalid[][2]={{0,0},{5,0},{1,-1},{4,257}};
 for(size_t i=0;i<sizeof invalid/sizeof invalid[0];++i){SLOT_CHECK(!proof_slots_init(&slots,invalid[i][0],invalid[i][1]),"invalid slot domain rejected before admission");SLOT_CHECK(slots.active==0&&slots.next==0&&slots.first_source==-1,"invalid slot domain leaves neutral rootless state");}
 SLOT_CHECK(proof_slots_init(&slots,4,2),"initialize bounded slot controller");
 unsigned waits=slot_wait_calls,stops=slot_stop_calls,yields=slot_yield_calls;
 SLOT_CHECK(slot_action(&slots,0,0,&slot,&source)==0&&slot==-1&&source==-1&&slots.next==0&&slots.active==0,"admission pause is idle with untouched canonical cursor");
 SLOT_CHECK(slot_wait_calls==waits&&slot_stop_calls==stops&&slot_yield_calls==yields,"inactive admission pause performs no native wait/stop/yield");
 SLOT_CHECK(slot_action(&slots,0,1,&slot,&source)==1&&slot==0&&source==0&&slots.next==0&&slots.active==0,"admit is an uncommitted canonical scalar action");
 proof_slots_commit(&slots,slot,0);SLOT_CHECK(slots.first_kind==2&&slots.first_source==0&&slots.stopped&&slots.active==0&&slots.next==0,"zero start closes admission without phantom ID");
 SLOT_CHECK(slot_action(&slots,0,1,&slot,&source)==3,"failed start controller drains to done");
 SLOT_CHECK(proof_slots_init(&slots,4,10),"initialize first-infrastructure policy");
 proof_slots_failure(&slots,5,7);proof_slots_failure(&slots,4,-1);proof_slots_failure(&slots,5,2);proof_slots_failure(&slots,5,-1);
 SLOT_CHECK(slots.first_kind==5&&slots.first_source==2&&slots.stopped,"first infrastructure kind and smallest same-kind canonical source survive later cancellation");
 SLOT_CHECK(slot_action(&slots,1,1,&slot,&source)==3&&slots.first_kind==5&&slots.first_source==2,"cancel does not overwrite prior infrastructure kind");
 SLOT_CHECK(proof_slots_init(&slots,1,1)&&slot_action(&slots,1,1,&slot,&source)==3&&slots.first_kind==4&&slots.first_source==-1,"cancel before admission has no source owner");

 SLOT_CHECK(ube_value_array_length(&published)>0&&workers_drained(),"real UBE slot witness starts from a completed retained source set");
 struct work* retained=*(struct work**)ube_array_element(published,0);SLOT_CHECK(retained&&retained->state==1,"real UBE slot witness retains accepted token owner");
 SLOT_CHECK(ube_gc_root_enter(&owner,&private_work),"private UBE slot work owner root");rooted=1;
 proof_make_shared(retained,&private_work);SLOT_CHECK(private_work&&((struct shared_work*)private_work)->owner==retained,"real UBE slot worker retains immutable source/token owner");
 SLOT_CHECK(proof_slots_init(&slots,1,2)&&slot_action(&slots,0,1,&slot,&source)==1,"real UBE slot admission action");
 outstanding=proof_start_shared(private_work);SLOT_CHECK(outstanding>0,"real static UBE CallNew issues native slot ID");
 proof_slots_commit(&slots,slot,outstanding);SLOT_CHECK(slots.active==1&&slots.next==1&&proof_slots_id(&slots,0)==outstanding&&slots.sources[0]==0,"rootless commit retains exact real ID and canonical source");
 slot_wait_fault=1;
 SLOT_CHECK(slot_action(&slots,0,0,&slot,&source)==0&&slots.active==1&&proof_slots_id(&slots,0)==outstanding&&slots.next==1&&slots.stopped&&slots.first_kind==6&&slots.first_source==0,"failed wait while admission paused retains active ID and stops new admission");
 slot_stop_fault=1;slot_wait_fault=1;
 SLOT_CHECK(slot_action(&slots,0,0,&slot,&source)==0&&slots.active==1&&proof_slots_id(&slots,0)==outstanding&&slots.first_kind==6,"false stop and false wait still retain exact native ID");
 ULONGLONG deadline=GetTickCount64()+60000;int action=0;
 do{action=slot_action(&slots,0,0,&slot,&source);SLOT_CHECK(action>=0&&GetTickCount64()<deadline,"failed-wait controller keeps bounded polling toward real drain");}while(action==0);
 SLOT_CHECK(action==2&&slot==0&&source==0&&slots.active==0&&proof_slots_id(&slots,0)==0&&slots.next==1,"only confirmed completion releases ID without admitting paused source");outstanding=0;
 SLOT_CHECK(slot_action(&slots,0,1,&slot,&source)==3&&workers_drained(),"infra failure remains closed after complete native drain");
 SLOT_CHECK(((struct shared_work*)private_work)->owner==retained&&((struct shared_work*)private_work)->state==1,"actual UBE worker completed using retained owner");

 private_work=NULL;proof_make_shared(retained,&private_work);SLOT_CHECK(private_work,"fresh private work for full-registry scalar controller");
 SLOT_CHECK(proof_slots_init(&slots,1,1)&&slot_action(&slots,0,1,&slot,&source)==1,"full-registry control admission");
 outstanding=proof_start_shared(private_work);SLOT_CHECK(outstanding>0,"full-registry control real UBE worker admission");proof_slots_commit(&slots,slot,outstanding);
 uint8_t alive=1;deadline=GetTickCount64()+60000;
 do{SLOT_CHECK(ube_thread_try_is_alive(outstanding,&alive)&&GetTickCount64()<deadline,"actual UBE worker finishes before rootless full-registry action");if(alive)Sleep(1);}while(alive);
 fill_root_pressure();SLOT_CHECK(ube_gc_root_count==UBE_GC_MAX_ROOTS,"real backed full registry for scalar action");
 LONG64 allocations=allocation_calls,copies=copy_bytes;enabled=1;deny_all=1;
 action=slot_action(&slots,0,0,&slot,&source);deny_all=0;enabled=0;
 SLOT_CHECK(action==2&&slots.active==0&&proof_slots_id(&slots,0)==0&&allocation_calls==allocations&&copy_bytes==copies&&ube_gc_root_count==UBE_GC_MAX_ROOTS,"rootless completion action survives full registry and allocator denial with zero allocation/copy/root entry");outstanding=0;
 while(pressure_count)ube_gc_root_leave(&pressure[--pressure_count]);
 SLOT_CHECK(slot_action(&slots,0,0,&slot,&source)==3&&workers_drained(),"full-registry controller reaches done and native cleanup");
 success=1;
cleanup:
 enabled=0;deny_all=0;slot_wait_fault=slot_stop_fault=0;
 while(pressure_count)ube_gc_root_leave(&pressure[--pressure_count]);
 if(outstanding){(void)ube_thread_request_stop(outstanding);(void)shared_wait_for_worker(outstanding);}
 if(rooted)ube_gc_root_leave(&owner);
 if(success&&!require(ube_gc_root_count==before_roots&&workers_drained(),"focused scalar controller restores all roots and native resources"))success=0;
 if(success)printf("{\"suite\":\"rootless-worker-slots\",\"bytes\":80,\"rootlessHelpers\":7,\"admissionPause\":true,\"actualUbeWorkers\":2,\"failedWaitRetained\":true,\"failedStopRetained\":true,\"fullRootRegistry\":true,\"allocatorDenied\":true,\"passed\":true}\n");
 return success;
#undef SLOT_CHECK
}
