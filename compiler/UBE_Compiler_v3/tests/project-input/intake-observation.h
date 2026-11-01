/* Existing native enter/exit observation pattern; no production scheduler. */
static _Atomic unsigned intake_worker_entries;
static _Atomic int intake_schedule_enabled,intake_schedule_entered,intake_schedule_exited,intake_schedule_error;
static int intake_schedule_target,intake_schedule_order[3];
static int64_t intake_schedule_ids[3];
void intake_observe_enter(struct work* work){
    atomic_fetch_add(&intake_worker_entries,1);
    if(!atomic_load(&intake_schedule_enabled))return;
    int id=work->owner->id;
    if(id<0||id>=intake_schedule_target)return;
    intake_schedule_ids[id]=ube_thread_current_id();
    atomic_fetch_add(&intake_schedule_entered,1);
    ULONGLONG deadline=GetTickCount64()+60000;
    while(atomic_load(&intake_schedule_entered)<intake_schedule_target){
        if(GetTickCount64()>deadline){atomic_store(&intake_schedule_error,1);return;}
        SwitchToThread();
    }
}
void intake_observe_exit(struct work* work){
    if(!atomic_load(&intake_schedule_enabled))return;
    int id=work->owner->id;
    if(id<0||id>=intake_schedule_target)return;
    if(id<intake_schedule_target-1){
        ULONGLONG deadline=GetTickCount64()+60000;
        while(!ube_thread_wait(intake_schedule_ids[id+1],100)){
            if(GetTickCount64()>deadline){atomic_store(&intake_schedule_error,1);break;}
        }
    }
    int index=atomic_fetch_add(&intake_schedule_exited,1);
    if(index>=0&&index<intake_schedule_target)intake_schedule_order[index]=id;
    else atomic_store(&intake_schedule_error,1);
}
#ifdef INTAKE_CONTRACT
static void intake_reverse_begin(int count,int jobs){
    intake_schedule_target=count<jobs?count:jobs;
    memset(intake_schedule_ids,0,sizeof(intake_schedule_ids));
    for(int i=0;i<3;++i)intake_schedule_order[i]=-1;
    atomic_store(&intake_schedule_entered,0);atomic_store(&intake_schedule_exited,0);
    atomic_store(&intake_schedule_error,0);atomic_store(&intake_schedule_enabled,1);
}
static int intake_reverse_matches(const int* order,int target){
    if(atomic_load(&intake_schedule_error)||atomic_load(&intake_schedule_entered)!=target||atomic_load(&intake_schedule_exited)!=target)return 0;
    for(int i=0;i<target;++i)if(order[i]!=target-1-i)return 0;
    return 1;
}
#endif
