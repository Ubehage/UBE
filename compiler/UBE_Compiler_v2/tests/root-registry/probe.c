/* Deterministic registry protocol proof; observes only a private runtime copy. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
enum { SNAPSHOT=1, AFTER_SNAPSHOT, BEFORE_STRIPE, IN_STRIPE, COLLECT_START, CLOSED, BEFORE_LEAVE, RESERVED, PROOF_POINT_COUNT };
static void proof_point(int);
static void proof_frozen(void);
static void proof_before_admit(void*);
static void proof_leave_return(void*,int);
static void proof_reserve_loaded(uint64_t);
static void proof_reserve_retry(uint64_t);
static void proof_reserve_rejected(uint64_t);
static void proof_enter(CRITICAL_SECTION*);
static void proof_leave(CRITICAL_SECTION*);
static BOOL proof_initialize(CRITICAL_SECTION*,DWORD,DWORD);
static void proof_delete(CRITICAL_SECTION*);
#define EnterCriticalSection proof_enter
#define LeaveCriticalSection proof_leave
#define InitializeCriticalSectionEx proof_initialize
#define DeleteCriticalSection proof_delete
#include "bootstrap_runtime.c"
#undef EnterCriticalSection
#undef LeaveCriticalSection
#undef InitializeCriticalSectionEx
#undef DeleteCriticalSection
/* Original assertions retained; copied include removed and private names mapped. */
#define UBE_GC_ROOT_BUCKETS UBE_ROOT_BUCKETS
#define ube_gc_root_buckets ube_root_registry.heads
#define main legacy_main
#include "legacy-proof.c"
#undef main

struct gate { HANDLE seen,release; DWORD thread; volatile LONG armed; };
static struct gate gates[PROOF_POINT_COUNT];
static HANDLE blocked_heap,blocked_stripe;
static volatile LONG watch_heap,watch_stripe;
static DWORD watched_thread;
static _Thread_local uint64_t held;
static _Thread_local unsigned depths[64],heap_depth;
static int init_failure=-1,init_calls,delete_calls,init_order[64],delete_order[64],stripe_entries;
static uint64_t initialized;
static volatile LONG foreign_violations;
static volatile LONG reserve_barrier,reserve_arrivals,reserve_failures,reserve_rejections;
static HANDLE reserve_both,reserve_release;
static void die(int code,const char* label) {
    fprintf(stderr,"SAFE-GUARD %d %s\n",code,label);fflush(stderr);ExitProcess((UINT)code);
}
static void expect(int predicate,const char* label) {
    __atomic_fetch_add(&assertions,1,__ATOMIC_SEQ_CST);if(!predicate){fprintf(stderr,"FAIL %s\n",label);ExitProcess(1);}
}
#define EXPECT(x) expect(!!(x),#x)
static int stripe_index(CRITICAL_SECTION* p) {
    for(int i=0;i<64;++i)if(p==&ube_root_registry.stripes[i].section)return i;
    return -1;
}
static void wait_event(HANDLE h) {
    if(WaitForSingleObject(h,15000)!=WAIT_OBJECT_0)die(2,"bounded event wait");
}
static HANDLE event_new(void) { HANDLE h=CreateEventW(NULL,TRUE,FALSE,NULL);EXPECT(h!=NULL);return h; }
static void join(HANDLE thread) {
    wait_event(thread);DWORD result=999;EXPECT(GetExitCodeThread(thread,&result)&&result==0);EXPECT(CloseHandle(thread));
}
static void setup(void) {
    for(int i=1;i<PROOF_POINT_COUNT;++i){gates[i].seen=event_new();gates[i].release=event_new();}
    blocked_heap=event_new();blocked_stripe=event_new();
}
static void arm(int point,DWORD thread) {
    ResetEvent(gates[point].seen);ResetEvent(gates[point].release);
    gates[point].thread=thread;InterlockedExchange(&gates[point].armed,1);
}
static void proof_point(int point) {
    if(point<=0||point>=PROOF_POINT_COUNT)return;
    struct gate*g=&gates[point];
    if((g->thread==0||g->thread==GetCurrentThreadId())&&
       InterlockedCompareExchange(&g->armed,0,1)==1) {
        SetEvent(g->seen);wait_event(g->release);
    }
}
static BOOL proof_initialize(CRITICAL_SECTION*p,DWORD spin,DWORD flags) {
    int i=stripe_index(p);
    if(i<0)return InitializeCriticalSectionEx(p,spin,flags);
    init_order[init_calls++]=i;
    if(i==init_failure){SetLastError(ERROR_NOT_ENOUGH_MEMORY);return FALSE;}
    BOOL result=InitializeCriticalSectionEx(p,spin,flags);
    if(result)initialized|=UINT64_C(1)<<i;
    return result;
}
static void proof_delete(CRITICAL_SECTION*p) {
    int i=stripe_index(p);
    if(i>=0){
        if(!(initialized&(UINT64_C(1)<<i)))die(3,"delete uninitialized stripe");
        delete_order[delete_calls++]=i;initialized&=~(UINT64_C(1)<<i);
    }
    DeleteCriticalSection(p);
}
static void proof_enter(CRITICAL_SECTION*p) {
    int i=stripe_index(p),is_heap=p==&ube_gc_lock;
    if(is_heap&&held)die(90,"heap acquisition while stripe held");
    if(i>=0){
        if(ube_root_registry.mode==UBE_ROOT_MODE_HEAP)die(3,"stripe in fallback");
        if(!(initialized&(UINT64_C(1)<<i)))die(3,"enter uninitialized stripe");
        if(held&&!heap_depth&&depths[i]==0)die(90,"multiple stripes without heap");
    }
    if(!TryEnterCriticalSection(p)){
        if(GetCurrentThreadId()==watched_thread) {
            if(is_heap&&InterlockedCompareExchange(&watch_heap,0,1)==1)SetEvent(blocked_heap);
            if(i>=0&&InterlockedCompareExchange(&watch_stripe,0,1)==1)SetEvent(blocked_stripe);
        }
        EnterCriticalSection(p);
    }
    if(i>=0){++depths[i];held|=UINT64_C(1)<<i;InterlockedIncrement((LONG*)&stripe_entries);}
    if(is_heap)++heap_depth;
}
static void proof_leave(CRITICAL_SECTION*p) {
    int i=stripe_index(p);
    if(i>=0){if(!depths[i])die(3,"unowned stripe release");if(!--depths[i])held&=~(UINT64_C(1)<<i);}
    if(p==&ube_gc_lock){if(!heap_depth)die(3,"unowned heap release");--heap_depth;}
    LeaveCriticalSection(p);
}
static void proof_frozen(void) {
    if(!heap_depth)die(91,"root traversal without heap");
    if(ube_root_registry.mode==UBE_ROOT_MODE_STRIPED&&held!=UINT64_MAX)die(91,"whole registry not frozen");
    size_t count=0;
    for(size_t bucket=0;bucket<UBE_ROOT_BUCKETS;++bucket)
        for(struct ube_gc_root*root=ube_root_registry.heads[bucket];root;root=root->next){
            if(++count>UBE_GC_MAX_ROOTS||ube_root_registry_bucket(root)!=bucket)
                die(94,"frozen membership corrupt");
        }
    if(count!=ube_gc_root_count)die(94,"frozen count differs from membership");
}
static void proof_before_admit(void*storage) {
    (void)storage;
    if(ube_gc_collecting&&__atomic_load_n(&ube_root_registry.collector,__ATOMIC_SEQ_CST)!=GetCurrentThreadId()){
        InterlockedIncrement(&foreign_violations);die(92,"foreign commit during collection");
    }
}
static void proof_leave_return(void*storage,int result) {
    if(result){
        struct ube_gc_root*root=storage;
        if(root->next||root->slot||root->slot_count||root->slot_offsets)
            die(93,"successful leave returned before unlink/clear");
    }
}
static void proof_reserve_loaded(uint64_t current) {
    if(!InterlockedCompareExchange(&reserve_barrier,0,0))return;
    EXPECT(current==UINT64_C(1048575));
    if(InterlockedIncrement(&reserve_arrivals)==2)SetEvent(reserve_both);
    wait_event(reserve_release);
}
static void proof_reserve_retry(uint64_t current) {
    if(!InterlockedCompareExchange(&reserve_barrier,0,0))return;
    EXPECT(current==UINT64_C(1048576));InterlockedIncrement(&reserve_failures);
}
static void proof_reserve_rejected(uint64_t current) {
    if(!InterlockedCompareExchange(&reserve_barrier,0,0))return;
    EXPECT(current==UINT64_C(1048576));InterlockedIncrement(&reserve_rejections);
}
struct operation {
    struct ube_gc_root*root;void**slot;struct ube_gc_root*remove;
    HANDLE done;int result;int action;DWORD tid;
};
static DWORD WINAPI operation_thread(void*parameter) {
    struct operation*op=parameter;
    if(op->action==1)op->result=ube_gc_root_leave(op->root);
    else if(op->action==2)op->result=ube_gc_collect();
    else if(op->action==3){ube_gc_release_all();op->result=1;}
    else if(op->action==4){ube_thread_capture_destroy(op->slot);op->result=1;}
    else {
        ube_err_set(77,"prior","synchronization proof");
        op->result=op->action==5?ube_value_root_enter(op->root,op->slot,&reference_layout):
            ube_gc_root_enter_layout(op->root,op->slot,1,pointer_offset);
        EXPECT(ube_err_number()==((op->action==5&&!op->result)?7:77));
        if(op->remove&&op->result)EXPECT(ube_gc_root_leave(op->remove));
    }
    if(op->done)SetEvent(op->done);
    return 0;
}
static HANDLE start(struct operation*op,int suspended) {
    HANDLE t=CreateThread(NULL,0,operation_thread,op,suspended?CREATE_SUSPENDED:0,&op->tid);
    EXPECT(t!=NULL);return t;
}
static void check_other_owns_all(void) {
    EXPECT(ube_root_registry.mode==UBE_ROOT_MODE_STRIPED);
    for(int i=0;i<64;++i){
        BOOL acquired=TryEnterCriticalSection(&ube_root_registry.stripes[i].section);
        if(acquired)LeaveCriticalSection(&ube_root_registry.stripes[i].section);
        EXPECT(!acquired);
    }
}
static void watch(DWORD tid,int heap) {
    watched_thread=tid;
    ResetEvent(heap?blocked_heap:blocked_stripe);
    InterlockedExchange(heap?&watch_heap:&watch_stripe,1);
}
static int gate_case(int first_check) {
    setup();EXPECT(ube_root_registry_ensure()==UBE_ROOT_MODE_STRIPED);
    struct ube_gc_root root;memset(&root,0xa5,sizeof(root));void*slot=NULL;
    struct operation add={.root=&root,.slot=&slot,.done=event_new()};
    HANDLE ta=start(&add,1);
    if(first_check){arm(BEFORE_STRIPE,add.tid);ResumeThread(ta);wait_event(gates[BEFORE_STRIPE].seen);}
    struct operation gc={.action=2};HANDLE tc=start(&gc,1);
    arm(AFTER_SNAPSHOT,gc.tid);ResumeThread(tc);wait_event(gates[AFTER_SNAPSHOT].seen);
    EXPECT(ube_gc_collecting&&ube_root_registry.collector==gc.tid);
    watch(add.tid,1);
    if(first_check)SetEvent(gates[BEFORE_STRIPE].release);else ResumeThread(ta);
    wait_event(blocked_heap);
    EXPECT(WaitForSingleObject(add.done,0)==WAIT_TIMEOUT&&ube_gc_root_count==0);
    SetEvent(gates[AFTER_SNAPSHOT].release);join(tc);join(ta);
    EXPECT(add.result==1&&!foreign_violations&&ube_gc_root_count==1);
    EXPECT(!ube_gc_collecting&&!ube_root_registry.collector);
    EXPECT(ube_gc_root_leave(&root)&&ube_gc_root_count==0);
    return 0;
}
static int lifetime_case(void) {
    setup();EXPECT(ube_root_registry_ensure()==UBE_ROOT_MODE_STRIPED);
    struct ube_gc_root*root=VirtualAlloc(NULL,4096,MEM_RESERVE|MEM_COMMIT,PAGE_READWRITE);
    EXPECT(root);void**slot=(void**)((unsigned char*)root+64);
    EXPECT(ube_gc_root_enter(root,slot));
    EXPECT(ube_gc_allocate_into(&leaf_layout,slot));void*value=*slot;((struct leaf*)value)->tag=413;
    struct ube_gc_header*header=ube_gc_header_from_value(value);
    EXPECT(header&&!header->pending_publication&&!header->pin_count);
    struct operation gc={.action=2};HANDLE tc=start(&gc,1);arm(SNAPSHOT,gc.tid);arm(AFTER_SNAPSHOT,gc.tid);
    ResumeThread(tc);wait_event(gates[SNAPSHOT].seen);check_other_owns_all();
    struct operation leave={.root=root,.action=1,.done=event_new()};HANDLE tl=start(&leave,1);
    watch(leave.tid,0);ResumeThread(tl);wait_event(blocked_stripe);
    EXPECT(WaitForSingleObject(leave.done,0)==WAIT_TIMEOUT);
    EXPECT(ube_gc_header_from_value(value)==header&&((struct leaf*)value)->tag==413);
    SetEvent(gates[SNAPSHOT].release);wait_event(gates[AFTER_SNAPSHOT].seen);join(tl);
    EXPECT(leave.result==1&&ube_gc_root_count==0);
    DWORD old;EXPECT(VirtualProtect(root,4096,PAGE_NOACCESS,&old));
    SetEvent(gates[AFTER_SNAPSHOT].release);join(tc);
    EXPECT(ube_gc_header_from_value(value)==header);
    EXPECT(ube_gc_collect()==1&&ube_gc_header_from_value(value)==NULL);
    EXPECT(!ube_gc_root_leave(root));EXPECT(VirtualFree(root,0,MEM_RELEASE));
    return 0;
}
static int inflight_case(void) {
    setup();EXPECT(ube_root_registry_ensure()==UBE_ROOT_MODE_STRIPED);
    struct ube_gc_root records[256],*a=NULL,*b=NULL;void*slot=NULL;
    for(int i=0;i<256&&!a;++i)for(int j=0;j<256;++j){
        size_t x=ube_root_registry_bucket(&records[i])&63,y=ube_root_registry_bucket(&records[j])&63;
        if(x<y){a=&records[i];b=&records[j];break;}
    }
    EXPECT(a&&b);EXPECT(ube_gc_root_enter(b,&slot));EXPECT(ube_gc_allocate_into(&leaf_layout,&slot));
    struct ube_gc_header*header=ube_gc_header_from_value(slot);
    EXPECT(header&&!header->pending_publication&&!header->pin_count);
    struct operation add={.root=a,.slot=&slot,.remove=b};HANDLE ta=start(&add,1);
    arm(IN_STRIPE,add.tid);ResumeThread(ta);wait_event(gates[IN_STRIPE].seen);
    struct operation gc={.action=2};HANDLE tc=start(&gc,1);watch(gc.tid,0);arm(SNAPSHOT,gc.tid);
    ResumeThread(tc);wait_event(blocked_stripe);
    EXPECT(ube_gc_collecting&&ube_gc_root_count==1);
    SetEvent(gates[IN_STRIPE].release);wait_event(gates[SNAPSHOT].seen);check_other_owns_all();
    EXPECT(a->slot==&slot);
    SetEvent(gates[SNAPSHOT].release);join(tc);join(ta);
    EXPECT(add.result==1&&ube_gc_root_count==1&&ube_gc_header_from_value(slot)==header);
    EXPECT(ube_gc_root_leave(a));EXPECT(ube_gc_collect()==1&&ube_gc_live_bytes==0);
    return 0;
}
static int capacity_case(void) {
    enum { contenders=16 };size_t limit=1048576;
    EXPECT(UBE_GC_MAX_ROOTS==limit&&sizeof(struct ube_gc_root)==32);
    struct ube_gc_root*roots=calloc(limit,sizeof(*roots));void*slot=NULL;EXPECT(roots);
    for(size_t i=0;i<limit;++i)EXPECT(ube_gc_root_enter_layout(&roots[i],&slot,1,pointer_offset));
    for(int available=0;available<=4;available=available?available*4:1){
        for(int i=0;i<available;++i)EXPECT(ube_gc_root_leave(&roots[limit-1-i]));
        struct ube_gc_root pool[4096],old[contenders];struct operation ops[contenders];HANDLE threads[contenders];int selected[64]={0},n=0;
        for(int i=0;i<4096&&n<contenders;++i){
            size_t stripe=ube_root_registry_bucket(&pool[i])&63;
            if(selected[stripe])continue;selected[stripe]=1;
            memset(&pool[i],0xa5,sizeof(pool[i]));old[n]=pool[i];
            ops[n]=(struct operation){.root=&pool[i],.slot=&slot,.action=(n&1)?5:0};
            threads[n]=start(&ops[n],1);++n;
        }
        EXPECT(n==contenders);
        for(int i=0;i<n;++i)ResumeThread(threads[i]);
        int winners=0;for(int i=0;i<n;++i){join(threads[i]);if(ops[i].result)++winners;else EXPECT(!memcmp(ops[i].root,&old[i],32));}
        EXPECT(winners==available&&ube_gc_root_count==limit);
        for(int i=0;i<n;++i)if(ops[i].result)EXPECT(ube_gc_root_leave(ops[i].root));
        for(int i=0;i<available;++i)EXPECT(ube_gc_root_enter_layout(&roots[limit-1-i],&slot,1,pointer_offset));
        EXPECT(ube_gc_root_count==limit);
    }
    for(size_t i=0;i<limit;++i)EXPECT(ube_gc_root_leave(&roots[i]));
    free(roots);EXPECT(ube_gc_root_count==0);return 0;
}
static int close_case(int reserved) {
    setup();EXPECT(ube_root_registry_ensure()==UBE_ROOT_MODE_STRIPED);
    struct ube_gc_root before,late,old;void*slot=NULL;memset(&late,0xa5,32);old=late;
    struct operation add={.root=&before,.slot=&slot};HANDLE ta=start(&add,1);
    int point=reserved?RESERVED:IN_STRIPE;
    arm(point,add.tid);ResumeThread(ta);wait_event(gates[point].seen);
    struct operation close={.action=3};HANDLE tc=start(&close,1);watch(close.tid,0);ResumeThread(tc);
    wait_event(blocked_stripe);
    EXPECT(__atomic_load_n(&ube_root_registry.state,__ATOMIC_SEQ_CST)&UBE_ROOT_CLOSED);
    EXPECT(!ube_gc_root_enter_layout(&late,&slot,1,pointer_offset)&&!memcmp(&late,&old,32));
    SetEvent(gates[point].release);join(ta);join(tc);
    EXPECT(add.result==reserved&&ube_gc_root_count==0);
    EXPECT(__atomic_load_n(&ube_root_registry.state,__ATOMIC_SEQ_CST)==UBE_ROOT_CLOSED);
    EXPECT(!ube_gc_root_leave(&before)&&!ube_gc_root_leave(&late));return 0;
}
static int capacity_shared_load_case(void) {
    const size_t limit=1048576;void*slot=NULL;
    EXPECT(UBE_GC_MAX_ROOTS==limit);
    struct ube_gc_root*roots=calloc(limit-1,sizeof(*roots));EXPECT(roots);
    for(size_t i=0;i<limit-1;++i)EXPECT(ube_gc_root_enter_layout(&roots[i],&slot,1,pointer_offset));
    struct ube_gc_root pool[256],*a=&pool[0],*b=NULL,old_a,old_b;
    for(int i=1;i<256;++i)
        if((ube_root_registry_bucket(a)&63)!=(ube_root_registry_bucket(&pool[i])&63)){b=&pool[i];break;}
    EXPECT(b);memset(a,0xa5,32);memset(b,0xa5,32);old_a=*a;old_b=*b;
    reserve_both=event_new();reserve_release=event_new();
    struct operation first={.root=a,.slot=&slot},second={.root=b,.slot=&slot};
    HANDLE ta=start(&first,1),tb=start(&second,1);
    InterlockedExchange(&reserve_barrier,1);ResumeThread(ta);ResumeThread(tb);
    wait_event(reserve_both);EXPECT(reserve_arrivals==2&&ube_gc_root_count==limit-1);
    SetEvent(reserve_release);join(ta);join(tb);
    /* Stop a non-CAS mutant before tracing/freeing any over-capacity registry. */
    if(first.result+second.result!=1)die(95,"capacity reservation not linearizable");
    EXPECT(reserve_failures==1&&reserve_rejections==1&&ube_gc_root_count==limit);
    EXPECT(first.result||!memcmp(a,&old_a,32));EXPECT(second.result||!memcmp(b,&old_b,32));
    InterlockedExchange(&reserve_barrier,0);
    ube_gc_enter_lock();ube_root_registry_freeze();proof_frozen();
    ube_root_registry_unfreeze();ube_gc_leave_lock();
    EXPECT(ube_gc_root_leave(first.result?a:b)&&ube_gc_root_count==limit-1);
    EXPECT(ube_gc_root_enter_layout(first.result?b:a,&slot,1,pointer_offset));
    EXPECT(ube_gc_root_count==limit&&ube_gc_root_leave(first.result?b:a));
    for(size_t i=0;i<limit-1;++i)EXPECT(ube_gc_root_leave(&roots[i]));
    free(roots);EXPECT(ube_gc_root_count==0);return 0;
}
static int fallback_case(int position,int full_capacity) {
    init_failure=position;
    ube_err_set(77,"prior","fallback");EXPECT(ube_root_registry_ensure()==UBE_ROOT_MODE_HEAP);
    EXPECT(init_calls==position+1&&delete_calls==position&&initialized==0);
    for(int i=0;i<=position;++i)EXPECT(init_order[i]==i);
    for(int i=0;i<position;++i)EXPECT(delete_order[i]==position-1-i);
    EXPECT(ube_err_number()==77);
    EXPECT(membership()==0&&aliases()==0&&capture()==0);
    if(full_capacity)EXPECT(capacity()==0);
    EXPECT(ube_root_registry.mode==UBE_ROOT_MODE_HEAP&&init_calls==position+1&&stripe_entries==0);
    EXPECT(!ube_gc_collecting&&!ube_root_registry.collector&&held==0&&heap_depth==0);
    ube_gc_release_all();EXPECT(initialized==0&&delete_calls==position);
    return 0;
}
static int capture_lifetime_case(void) {
    setup();EXPECT(ube_root_registry_ensure()==UBE_ROOT_MODE_STRIPED);
    struct pair*data=ube_thread_capture_allocate(sizeof(*data),2,pair_offsets);
    EXPECT(data&&ube_gc_root_count==1);
    EXPECT(ube_gc_allocate_into(&leaf_layout,&data->first)&&ube_gc_allocate_into(&leaf_layout,&data->second));
    void*first=data->first,*second=data->second;
    EXPECT(!ube_gc_header_from_value(first)->pending_publication&&!ube_gc_header_from_value(second)->pending_publication);
    struct operation gc={.action=2};HANDLE tc=start(&gc,1);arm(SNAPSHOT,gc.tid);arm(AFTER_SNAPSHOT,gc.tid);
    ResumeThread(tc);wait_event(gates[SNAPSHOT].seen);check_other_owns_all();
    struct operation destroy={.action=4,.slot=(void**)data,.done=event_new()};
    HANDLE td=start(&destroy,1);watch(destroy.tid,0);ResumeThread(td);wait_event(blocked_stripe);
    EXPECT(WaitForSingleObject(destroy.done,0)==WAIT_TIMEOUT);
    SetEvent(gates[SNAPSHOT].release);wait_event(gates[AFTER_SNAPSHOT].seen);join(td);
    EXPECT(destroy.result==1&&ube_gc_root_count==0);
    SetEvent(gates[AFTER_SNAPSHOT].release);join(tc);
    EXPECT(ube_gc_header_from_value(first)&&ube_gc_header_from_value(second));
    EXPECT(ube_gc_collect()==1&&ube_gc_live_bytes==0);return 0;
}
static int owner_calls;
static void owner_finalizer(void*ignored) {
    (void)ignored;
    EXPECT(ube_gc_collecting&&ube_root_registry.collector==GetCurrentThreadId()&&held==0&&heap_depth>0);
    DWORD owner=ube_root_registry.collector;struct ube_gc_root root;void*slot=NULL;
    EXPECT(ube_gc_root_enter_layout(&root,&slot,1,pointer_offset));
    EXPECT(ube_gc_collect()==0&&ube_root_registry.collector==owner&&ube_gc_collecting);
    EXPECT(ube_gc_root_leave(&root));
    EXPECT(ube_gc_root_enter(&root,&slot)&&ube_gc_root_leave(&root));
    ++owner_calls;
}
static int owner_case(void) {
    static const struct ube_gc_layout final_layout={sizeof(struct leaf),0,NULL,owner_finalizer};
    void*slot=NULL;struct ube_gc_root root;
    EXPECT(ube_gc_root_enter(&root,&slot)&&ube_gc_allocate_into(&final_layout,&slot));
    EXPECT(ube_gc_root_leave(&root));EXPECT(ube_gc_collect()==1&&owner_calls==1);
    EXPECT(!ube_gc_collecting&&!ube_root_registry.collector);
    EXPECT(ube_gc_collect()==1&&ube_gc_live_bytes==0&&owner_calls==1);
    EXPECT(ube_gc_root_enter(&root,&slot)&&ube_gc_allocate_into(&leaf_layout,&slot));
    size_t live=ube_gc_live_bytes;ube_gc_test_fail_next_trace_allocations(1);
    EXPECT(ube_gc_collect()==0&&ube_err_number()==7&&ube_gc_live_bytes==live);
    EXPECT(!ube_gc_collecting&&!ube_root_registry.collector&&!held&&!heap_depth);
    ube_gc_test_fail_next_trace_allocations(0);EXPECT(ube_gc_collect()==0);
    EXPECT(ube_gc_root_leave(&root)&&ube_gc_collect()==1&&ube_gc_live_bytes==0);return 0;
}
int main(int argc,char**argv) {
    EXPECT(argc>=2);
    int result=0;
    if(!strcmp(argv[1],"gate"))result=gate_case(0);
    else if(!strcmp(argv[1],"recheck"))result=gate_case(1);
    else if(!strcmp(argv[1],"lifetime"))result=lifetime_case();
    else if(!strcmp(argv[1],"inflight"))result=inflight_case();
    else if(!strcmp(argv[1],"capacity"))result=capacity_case();
    else if(!strcmp(argv[1],"capacity-shared-load"))result=capacity_shared_load_case();
    else if(!strcmp(argv[1],"close"))result=close_case(0);
    else if(!strcmp(argv[1],"close-reserved"))result=close_case(1);
    else if(!strcmp(argv[1],"owner"))result=owner_case();
    else if(!strcmp(argv[1],"capture"))result=capture_lifetime_case();
    else if(!strcmp(argv[1],"aliases"))result=aliases();
    else if(!strcmp(argv[1],"shutdown"))result=shutdown_test();
    else if(!strcmp(argv[1],"fallback")){EXPECT(argc==3);result=fallback_case(atoi(argv[2]),0);}
    else if(!strcmp(argv[1],"fallback-capacity"))result=fallback_case(63,1);
    else if(!strcmp(argv[1],"freeze")){void*slot=NULL;struct ube_gc_root r;EXPECT(ube_gc_root_enter(&r,&slot));(void)ube_gc_collect();EXPECT(ube_gc_root_leave(&r));}
    else die(1,"unknown case");
    EXPECT(result==0&&!held&&!heap_depth&&!foreign_violations);
    printf("PASS root synchronization %s assertions:%llu\n",argv[1],assertions);
    return 0;
}
