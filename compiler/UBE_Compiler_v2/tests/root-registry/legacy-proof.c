#include "bootstrap_runtime.c"
static unsigned long long assertions;
#define CHECK(x) do{++assertions;if(!(x)){fprintf(stderr,"root bucket proof line%d: %s\n",__LINE__,#x);return 1;}}while(0)
struct leaf {int32_t tag;};
static const struct ube_gc_layout leaf_layout={sizeof(struct leaf),0,NULL,NULL};
static const size_t pointer_offset[]={0};
static const struct ube_value_layout reference_layout={sizeof(void*),3,0,NULL,1,pointer_offset};
struct pair {void* first;void* second;};
static const size_t pair_offsets[]={0,sizeof(void*)};
static const struct ube_value_field pair_fields[]={{0,&reference_layout},{sizeof(void*),&reference_layout}};
static const struct ube_value_layout pair_layout={sizeof(struct pair),2,2,pair_fields,2,pair_offsets};
static size_t maximum_chain(void){
    size_t maximum=0;
#ifdef UBE_ROOT_BUCKETS
    for(size_t i=0;i<UBE_ROOT_BUCKETS;++i){size_t n=0;for(struct ube_gc_root*r=ube_root_registry.heads[i];r;r=r->next)++n;if(n>maximum)maximum=n;}
#else
    for(struct ube_gc_root*r=ube_gc_roots;r;r=r->next)++maximum;
#endif
    return maximum;
}
static int membership(void){
    enum {count=257};struct ube_gc_root roots[count];void* slots[count]={0};int active[count]={0};
    memset(roots,0xa5,sizeof(roots));
    for(int i=0;i<count;++i){CHECK(ube_gc_root_enter(&roots[i],&slots[i]));active[i]=1;struct leaf*p=ube_gc_allocate(&leaf_layout);CHECK(p);p->tag=1000+i;CHECK(ube_gc_write_barrier(NULL,&slots[i],p));}
    CHECK(ube_gc_root_count==count);
    struct ube_gc_root absent;memset(&absent,0xa5,sizeof(absent));struct ube_gc_root old=absent;
    ube_err_set(77,"prior","root bucket test");CHECK(!ube_gc_root_leave(&absent)&&!memcmp(&absent,&old,sizeof(old))&&ube_err_number()==77);
    void* inaccessible=VirtualAlloc(NULL,4096,MEM_RESERVE|MEM_COMMIT,PAGE_NOACCESS);CHECK(inaccessible);CHECK(!ube_gc_root_leave(inaccessible));CHECK(VirtualFree(inaccessible,0,MEM_RELEASE));
    size_t live=ube_gc_live_allocation_bytes();ube_gc_test_fail_next_trace_allocations(1);CHECK(!ube_gc_collect()&&ube_gc_live_allocation_bytes()==live);ube_gc_test_fail_next_trace_allocations(0);
    for(int step=0;step<count;++step){
        int index=(step*73)%count;CHECK(active[index]);CHECK(ube_gc_root_leave(&roots[index]));active[index]=0;CHECK(!ube_gc_root_leave(&roots[index]));
        if(step%13==0||step==count-1){
            CHECK(ube_gc_collect()==1);
            for(int i=0;i<count;++i){struct ube_gc_header*h=ube_gc_header_from_value(slots[i]);CHECK((h!=NULL)==active[i]);if(active[i])CHECK(((struct leaf*)slots[i])->tag==1000+i);}
        }
    }
    CHECK(ube_gc_root_count==0&&ube_gc_live_allocation_bytes()==0);return 0;
}
static int aliases(void){
    void* alias=NULL;struct pair pair={0};struct ube_gc_root a={0},p={0};
    CHECK(ube_gc_root_enter(&a,&alias));CHECK(ube_value_root_enter(&p,&pair,&pair_layout));
    CHECK(ube_gc_allocate_into(&leaf_layout,&alias));pair.first=alias;CHECK(ube_gc_allocate_into(&leaf_layout,&pair.second));
    CHECK(ube_gc_root_count==2);(void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==2*sizeof(struct leaf));
    ube_gc_enter_lock();ube_component_clear_aliases_locked(alias);ube_gc_leave_lock();CHECK(!alias&&!pair.first&&pair.second);
    CHECK(ube_gc_collect()==1&&ube_gc_live_allocation_bytes()==sizeof(struct leaf));CHECK(ube_gc_root_leave(&a)&&ube_gc_root_leave(&p));CHECK(ube_gc_collect()==1&&ube_gc_live_allocation_bytes()==0);return 0;
}
static DWORD WINAPI destroy_capture(void* capture){ube_thread_capture_destroy(capture);return 0;}
static int capture(void){
    struct pair* data=ube_thread_capture_allocate(sizeof(*data),2,pair_offsets);CHECK(data&&ube_gc_root_count==1);
    CHECK(ube_gc_allocate_into(&leaf_layout,&data->first)&&ube_gc_allocate_into(&leaf_layout,&data->second));(void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==2*sizeof(struct leaf));
    HANDLE thread=CreateThread(NULL,0,destroy_capture,data,0,NULL);CHECK(thread);CHECK(WaitForSingleObject(thread,20000)==WAIT_OBJECT_0);DWORD result=1;CHECK(GetExitCodeThread(thread,&result)&&result==0&&CloseHandle(thread));
    CHECK(ube_gc_root_count==0&&ube_gc_collect()==1&&ube_gc_live_allocation_bytes()==0);return 0;
}
static int capacity(void){
    size_t limit=1048576;struct ube_gc_root* roots=calloc(limit,sizeof(*roots));void* slot=NULL;CHECK(roots&&sizeof(*roots)==32&&UBE_GC_MAX_ROOTS==limit);
    for(size_t i=0;i<limit;++i)CHECK(ube_gc_root_enter(&roots[i],&slot));CHECK(ube_gc_root_count==limit);
    size_t longest=maximum_chain();struct ube_gc_root extra,old;memset(&extra,0xa5,sizeof(extra));old=extra;
    CHECK(!ube_gc_root_enter(&extra,&slot)&&!memcmp(&extra,&old,sizeof(extra)));CHECK(!ube_gc_root_enter_layout(&extra,&slot,1,pointer_offset)&&!memcmp(&extra,&old,sizeof(extra)));
    CHECK(!ube_value_root_enter(&extra,&slot,&reference_layout)&&ube_err_number()==7&&!memcmp(&extra,&old,sizeof(extra)));CHECK(!ube_gc_root_leave(&extra));
    void* inaccessible=VirtualAlloc(NULL,4096,MEM_RESERVE|MEM_COMMIT,PAGE_NOACCESS);CHECK(inaccessible);CHECK(!ube_gc_root_enter(inaccessible,&slot)&&!ube_gc_root_leave(inaccessible));CHECK(VirtualFree(inaccessible,0,MEM_RELEASE));
    (void)ube_gc_collect();CHECK(ube_gc_root_count==limit);
    CHECK(ube_gc_root_leave(&roots[limit-1]));CHECK(ube_value_root_enter(&extra,&slot,&reference_layout));CHECK(ube_gc_root_count==limit);CHECK(ube_gc_root_leave(&extra));
    for(size_t i=limit-1;i>0;--i)CHECK(ube_gc_root_leave(&roots[i-1]));free(roots);CHECK(ube_gc_root_count==0);
    static const struct ube_value_layout scalar={4,0,0,NULL,0,NULL};int32_t value=0;memset(&extra,0xa5,sizeof(extra));old=extra;ube_err_set(77,"prior","root bucket test");
    CHECK(ube_value_root_enter(&extra,&value,&scalar)&&!memcmp(&extra,&old,sizeof(extra))&&!ube_gc_root_leave(&extra)&&ube_err_number()==77);
    ube_gc_test_fail_next_allocations(2);CHECK(ube_gc_root_enter(&extra,&slot));CHECK(!ube_gc_allocate(&leaf_layout));CHECK(ube_gc_root_leave(&extra)&&ube_err_number()==77);
    printf("{\"capacity\":1048576,\"maximumChainAtCapacity\":%zu,\"rootBytes\":32}\n",longest);return 0;
}
static int duplicate_observation(void){
    /* Unsupported input: observe legacy behavior without tracing its self-cycle. */
    struct ube_gc_root root={0};void* slot=NULL;CHECK(ube_gc_root_enter(&root,&slot));CHECK(ube_gc_root_enter(&root,&slot));CHECK(root.next==&root&&ube_gc_root_count==2);
    CHECK(ube_gc_root_leave(&root)&&ube_gc_root_leave(&root)&&ube_gc_root_count==0);return 0;
}
static int shutdown_test(void){
    struct ube_gc_root root={0};void* slot=NULL;CHECK(ube_gc_root_enter(&root,&slot));CHECK(ube_gc_allocate_into(&leaf_layout,&slot));ube_gc_release_all();CHECK(ube_gc_root_count==0&&ube_gc_live_bytes==0&&maximum_chain()==0);
    CHECK(!ube_gc_root_leave(&root)&&!ube_gc_root_enter(&root,&slot));return 0;
}
int main(void){
    CHECK(ube_gc_root_storage_size()==32);CHECK(!ube_gc_root_leave(NULL));
    if(membership()||aliases()||capture()||capacity()||duplicate_observation()||shutdown_test())return 1;
    printf("PASS root storage bucket synthetic assertions:%llu\n",assertions);return 0;
}
