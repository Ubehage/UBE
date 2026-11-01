#include "observed_runtime.c"
struct parcel {void *data;int32_t marker;};
struct carrier {void *data;};
_Static_assert(sizeof(struct parcel)==16 && sizeof(struct carrier)==8,"independent fixture layout");
extern void proof_array(void **),proof_record(struct parcel *),proof_alias(void **);
extern void proof_element(struct parcel *,void **),proof_field(void **,void **);
extern const struct ube_value_layout *proof_parcel_layout(void);
extern const struct ube_gc_layout *proof_carrier_layout(void);
static void *watched_container;
static void **watched_slot;
static int watch_enabled,required_gc;
static unsigned long long watch_checks,container_checks,child_checks,required_collections;
static int assertions;
#define CHECK(x) do {++assertions;if(!(x)){fprintf(stderr,"proof assertion%d line%d failed: %s\n",assertions,__LINE__,#x);return 1;}}while(0)
void proof_before_required_gc(void) {required_gc=1;}
static void dead_watch(const char *role) {
    fprintf(stderr,"dead-watch:%s required:%d\n",role,required_gc);exit(92);
}
static void retention_after_collection(void) {
    if(!watch_enabled)return;
    ++watch_checks;
    /* Check the containing allocation before loading an interior slot. Watches
       are untraced native observations and never keep either allocation alive. */
    if(watched_container){
        ++container_checks;
        if(!ube_gc_header_from_value(watched_container))dead_watch("owner");
    }
    void *value=__atomic_load_n(watched_slot,__ATOMIC_SEQ_CST);
    if(value){
        struct ube_gc_header *header=ube_gc_header_from_value(value);
        if(!header)dead_watch("slot");
        if(header->pending_publication || header->pin_count){fputs("masked-watch:pending-or-pinned\n",stderr);exit(93);}
        ++child_checks;
    }
    if(required_gc){
        if(!value){fputs("required-gc:missing-output\n",stderr);exit(94);}
        ++required_collections;required_gc=0;
    }
}
static int bytes_equal(void *value,int count,int first,int last) {
    if(!value)return 0;struct ube_array *array=value;
    return array->lower==0 && array->upper==count-1 && array->element_size==1 &&
        array->data[0]==first && array->data[count-1]==last;
}
int main(int argc,char **argv) {
    if(argc!=4)return 2;
    int which=atoi(argv[1]),force=atoi(argv[2]),negative=atoi(argv[3]);
    if(which<0 || which>4 || force<0 || force>1 || negative<0 || negative>1)return 2;
    void *value=NULL,*owner=NULL,*keep=NULL;struct parcel record={0},fallback={0};
    struct ube_gc_root roots[4]={{0}};int entered[4]={0};struct parcel *element=NULL;
    const struct ube_value_layout *layout=proof_parcel_layout();
    CHECK(layout && layout->size==sizeof(record) && layout->root_count==1 && layout->root_offsets[0]==0);
    if(which<=2){
        if(!negative){CHECK(ube_gc_root_enter(&roots[0],which==1?&record.data:&value));entered[0]=1;}
        watched_slot=which==1?&record.data:&value;
    }else{
        CHECK(ube_gc_root_enter(&roots[0],&owner));entered[0]=1;
        if(!negative){CHECK(ube_gc_root_enter(&roots[1],&keep));entered[1]=1;}
        if(which==3){
            CHECK(ube_value_root_enter(&roots[2],&fallback,layout));entered[2]=1;
            CHECK(ube_value_try_resize(&owner,1,layout,0));
            element=ube_value_array_element(&owner,0,&keep,&fallback,layout);
            CHECK(element && element!=&fallback && keep==owner);
            watched_container=owner;watched_slot=&element->data;
        }else{
            const struct ube_gc_layout *class_layout=proof_carrier_layout();
            CHECK(class_layout && class_layout->size==8 && class_layout->slot_count==1 && class_layout->slot_offsets[0]==0);
            CHECK(ube_value_new_object(&owner,class_layout));keep=owner;
            watched_container=owner;watched_slot=&((struct carrier*)owner)->data;
        }
    }
    retention_force=force;watch_enabled=1;
    retention_collections=retention_requests=retention_failures=0;
    ube_err_set(77,"prior","caller-root proof");
    size_t steady=ube_gc_root_count;
    if(which==0)proof_array(&value);
    if(which==1)proof_record(&record);
    if(which==2)proof_alias(&value);
    if(which==3)proof_element(element,&owner);
    if(which==4)proof_field(&((struct carrier*)keep)->data,&owner);
    watch_enabled=0;retention_force=0;
    CHECK(required_collections==1 && required_gc==0 && watch_checks>0 && child_checks>0);
    CHECK(retention_collections>=1 && retention_collections>=retention_requests && retention_failures==0);
    CHECK(!force || retention_requests>0);
    CHECK(ube_gc_root_count==steady && ube_err_number()==77);
    if(which==0)CHECK(bytes_equal(value,3,65,90));
    if(which==1)CHECK(bytes_equal(record.data,2,66,91) && record.marker==1234);
    if(which==2)CHECK(bytes_equal(value,3,65,90) && ((struct ube_array*)value)->data[1]==67);
    if(which==3)CHECK(bytes_equal(element->data,2,66,91) && element->marker==1234 && owner!=keep && container_checks>0);
    if(which==4)CHECK(owner==NULL && bytes_equal(((struct carrier*)keep)->data,3,65,90) && container_checks>0);
    value=owner=keep=record.data=fallback.data=NULL;
    for(int i=3;i>=0;--i)if(entered[i])CHECK(ube_gc_root_leave(&roots[i]));
    (void)ube_gc_collect();
    CHECK(ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);
    printf("{\"case\":%d,\"forced\":%d,\"negative\":%d,\"assertions\":%d,\"completedCollections\":%llu,\"forcedRequests\":%llu,\"markFailures\":%llu,\"watchChecks\":%llu,\"ownerChecks\":%llu,\"newValueChecks\":%llu,\"requiredPostNestedReturnCollections\":%llu,\"pendingOrPinnedMask\":false,\"cleanup\":true}\n",which,force,negative,assertions,retention_collections,retention_requests,retention_failures,watch_checks,container_checks,child_checks,required_collections);
    return 0;
}
