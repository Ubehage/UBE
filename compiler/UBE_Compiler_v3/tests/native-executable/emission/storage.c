struct st_target {int32_t kind,source,scope,type,representation,flags,role,first_parameter,parameter_count,first_member,last_member,next_member,frame,byref;int64_t value,address;};
struct st_plan {void* targets;int32_t count,status,frames,byrefs;};
struct st_declaration {int32_t kind,source,syntax,name,scope,type,flags,first_parameter,parameter_count,ordinal,initializer,known,role,body;int64_t value;};
extern int32_t st_make_declarations(void**,int32_t),st_make_types(void**,int32_t);
extern int32_t st_prepare(struct st_plan*,void**,int32_t,void**,int32_t,int32_t,struct ll_writer*),st_dispose(struct st_plan*,struct ll_writer*);
extern int32_t st_storage(struct ll_writer*,struct st_target*,int32_t),st_load(struct ll_writer*,struct st_target*,int32_t,struct ll_operand*),st_store(struct ll_writer*,struct st_target*,int32_t,struct ll_operand*);
extern int32_t st_owner(struct st_target*,int32_t,struct ll_operand*);
static int declaration_cases(void) {
    CHECK(sizeof(struct st_target)==72 && sizeof(struct st_plan)==24 && sizeof(struct st_declaration)==64);
    void* declarations=NULL;void* types=NULL;struct st_plan p={0};struct ll_writer w={0};em_defaults(&w.limits);struct ube_gc_root roots[6]={{0}};
    void** owners[]={&declarations,&types,&p.targets,&w.output.buffer.bytes,&w.output.snapshot,&w.cancellation};for(int i=0;i<6;++i)CHECK(ube_gc_root_enter(&roots[i],owners[i]));
    CHECK(st_make_declarations(&declarations,9) && st_make_types(&types,7));struct st_declaration* d=gr_data(declarations);struct ll_type* t=gr_data(types);
    for(int i=0;i<9;++i){d[i]=(struct st_declaration){0};d[i].scope=0;d[i].first_parameter=-1;d[i].type=4;}
    d[0].kind=1;d[0].scope=-1;d[0].type=0;
    d[1].kind=2;d[1].type=6;t[6].kind=3;t[6].representation=2;
    d[2].kind=6;d[2].first_parameter=3;d[2].parameter_count=2;
    d[3].kind=4;d[3].scope=2;d[3].flags=4;d[3].ordinal=0;
    d[4].kind=4;d[4].scope=2;d[4].ordinal=1;
    d[5].kind=2;d[5].scope=2;d[5].type=6;
    d[6].kind=6;d[6].role=1;d[6].type=6;d[6].first_parameter=7;d[6].parameter_count=1;
    d[7].kind=4;d[7].scope=6;d[7].flags=4;d[7].type=2;
    d[8].kind=3;
    struct st_declaration saved[9];memcpy(saved,d,sizeof saved);struct ll_type saved_types[7];memcpy(saved_types,t,sizeof saved_types);
    w.failure=(struct em_failure){1509,0};ube_err_set(77,"prior","declaration plan");observe();int ok=st_prepare(&p,&declarations,9,&types,7,1,&w);observing=0;
    CHECK(ok && p.status==1 && p.count==9 && w.failure.code==0 && w.usage.work==9 && w.usage.payload==9*72 && w.usage.identities==8 && ube_err_number()==77);
    CHECK(memcmp(saved,d,sizeof saved)==0 && memcmp(saved_types,t,sizeof saved_types)==0 && copies==0 && allocations>0);
    struct st_target* a=gr_data(p.targets);CHECK(a[0].first_member==2 && a[0].last_member==9 && a[1].next_member==3 && a[2].next_member==7 && a[6].next_member==9);
    CHECK(a[2].first_member==4 && a[2].last_member==6 && a[3].next_member==5 && a[4].next_member==6 && a[5].next_member==0);
    CHECK(a[1].representation==2 && a[1].address==0 && a[2].value==1 && a[2].address==2 && a[3].value==3 && a[3].address==4 && a[4].value==5 && a[4].address==5 && a[5].address==7);
    CHECK(a[6].value==-1 && a[6].address==-1 && a[7].value==-1 && a[7].address==-1 && a[8].value==-1 && a[8].address==-1);
    CHECK(p.frames==1 && a[2].frame==0 && a[6].frame==-1 && a[7].frame==-1 && a[0].frame==-1);
    CHECK(p.byrefs==1 && a[4].byref==0);
    for(int i=0;i<9;++i)if(i!=4)CHECK(a[i].byref==-1);
    struct ll_operand owner={0};
    CHECK(st_owner(&a[1],1,&owner) && owner.kind==1 && owner.type==4 && owner.representation==4 && owner.value==0);
    CHECK(st_owner(&a[3],1,&owner) && owner.kind==1 && owner.value==-1);
    CHECK(st_owner(&a[4],1,&owner) && owner.kind==2 && owner.value==6);
    CHECK(st_owner(&a[5],1,&owner) && owner.kind==1 && owner.value==-1);
    CHECK(st_owner(&a[2],1,&owner) && owner.kind==1 && owner.value==-1);
    struct st_target foreign=a[1];foreign.source=3;foreign.scope=3;CHECK(st_owner(&foreign,4,&owner) && owner.kind==1 && owner.value==3);
    struct ll_operand saved_owner=owner;foreign.source=4;observe();CHECK(!st_owner(&foreign,4,&owner) && memcmp(&owner,&saved_owner,sizeof owner)==0 && clean_cost());
    foreign=a[4];foreign.value=INT64_MAX;CHECK(!st_owner(&foreign,1,&owner) && memcmp(&owner,&saved_owner,sizeof owner)==0 && ube_err_number()==77);
    foreign.value=INT64_MAX-1;CHECK(st_owner(&foreign,1,&owner) && owner.kind==2 && owner.value==INT64_MAX && ube_err_number()==77);
    saved_owner=owner;foreign.value=-1;CHECK(!st_owner(&foreign,1,&owner) && memcmp(&owner,&saved_owner,sizeof owner)==0 && ube_err_number()==77);
    CHECK(st_dispose(&p,&w) && w.usage.payload==0 && p.status==0 && p.frames==0 && p.byrefs==0);
    /* Parameter identity is independent of an intrinsic's lack of emitted body. */
    d[7].flags=0;w.usage=(struct em_usage){0};w.failure=(struct em_failure){1509,0};
    CHECK(st_prepare(&p,&declarations,9,&types,7,1,&w) && p.byrefs==2 && w.usage.work==9 && w.usage.payload==9*72 && w.usage.identities==8);
    a=gr_data(p.targets);CHECK(a[4].byref==0 && a[7].byref==1 && a[7].value==-1 && a[7].address==-1);
    CHECK(st_dispose(&p,&w) && p.byrefs==0 && w.usage.payload==0);d[7].flags=4;
    /* The owner companion is a real identity reservation, including refusal
       after its pointer has already consumed the preceding identity. */
    for(int limit=0;limit<=9;++limit) {
        w.usage=(struct em_usage){0};em_defaults(&w.limits);w.limits.identities=limit;w.failure=(struct em_failure){1509,0};
        ok=st_prepare(&p,&declarations,9,&types,7,1,&w);
        CHECK(ok==(limit>=8) && w.usage.identities==(limit<8?limit:8));
        CHECK(ok || (w.failure.code==1502 && w.failure.resource==3));
        CHECK(st_dispose(&p,&w) && w.usage.payload==0 && p.status==0 && p.byrefs==0);
        CHECK(memcmp(saved,d,sizeof saved)==0 && ube_err_number()==77);
    }
    for(int limit=0;limit<=9;++limit) {
        w.usage=(struct em_usage){0};em_defaults(&w.limits);w.limits.work=limit;w.failure=(struct em_failure){1509,0};ok=st_prepare(&p,&declarations,9,&types,7,1,&w);
        CHECK(ok==(limit==9) && w.usage.work==limit && (ok || (w.failure.code==1502 && w.failure.resource==5)));
        CHECK(p.byrefs==(limit>=5?1:0));
        CHECK(st_dispose(&p,&w) && w.usage.payload==0 && p.byrefs==0);
    }
    em_defaults(&w.limits);w.usage=(struct em_usage){0};w.limits.payload=9*72-1;w.failure=(struct em_failure){1509,0};
    CHECK(!st_prepare(&p,&declarations,9,&types,7,1,&w) && w.failure.code==1502 && p.count==0 && w.usage.payload==0 && st_dispose(&p,&w));
    em_defaults(&w.limits);w.usage=(struct em_usage){0};d[4].ordinal=0;w.failure=(struct em_failure){1509,0};
    CHECK(!st_prepare(&p,&declarations,9,&types,7,1,&w) && w.failure.code==1509 && st_dispose(&p,&w) && w.usage.payload==0);d[4].ordinal=1;
    w.usage=(struct em_usage){0};w.failure=(struct em_failure){1509,0};ube_gc_test_fail_next_allocations(1000000);
    CHECK(!st_prepare(&p,&declarations,9,&types,7,1,&w) && w.failure.code==1502 && w.failure.resource==1 && p.count==0 && w.usage.payload==0);
    ube_gc_test_fail_next_allocations(0);CHECK(st_dispose(&p,&w));
    CHECK(em_cancel_make(&w.cancellation));em_cancel(w.cancellation);w.usage=(struct em_usage){0};w.failure=(struct em_failure){1509,0};observe();
    CHECK(!st_prepare(&p,&declarations,9,&types,7,1,&w) && w.failure.code==1507 && w.usage.payload==0 && clean_cost());CHECK(st_dispose(&p,&w));w.cancellation=NULL;
    size_t available=UBE_GC_MAX_ROOTS-ube_gc_root_count;struct ube_gc_root* pressure=calloc(available,sizeof(*pressure));void* neutral=NULL;CHECK(pressure!=NULL);
    for(size_t i=0;i<available;++i)CHECK(ube_gc_root_enter(&pressure[i],&neutral));int successes=0,failures=0;
    for(size_t spare=0;spare<=32;++spare) {
        w.usage=(struct em_usage){0};w.failure=(struct em_failure){1509,0};int prepared=st_prepare(&p,&declarations,9,&types,7,1,&w);
        CHECK((prepared && w.failure.code==0) || (!prepared && w.failure.code!=0));CHECK(w.usage.payload==(int64_t)p.count*72);
        if(prepared)++successes;else ++failures;
        for(size_t i=0;i<128;++i)CHECK(ube_gc_root_leave(&pressure[available-spare-1-i]));
        CHECK(st_dispose(&p,&w) && p.count==0 && w.usage.payload==0);
        for(size_t i=0;i<128;++i)CHECK(ube_gc_root_enter(&pressure[available-spare-1-i],&neutral));
        if(spare<32)CHECK(ube_gc_root_leave(&pressure[available-spare-1]));
    }
    CHECK(successes>0 && failures>0);for(size_t i=0;i<available-32;++i)CHECK(ube_gc_root_leave(&pressure[i]));free(pressure);
    for(int i=5;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));declarations=NULL;types=NULL;CHECK(ube_gc_collect() && ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);return 0;
}
static int storage_function(struct ll_writer* w,int type,int representation,struct st_target* global,int variant) {
    int64_t function,block;CHECK(ll_identity(w,&function) && ll_identity(w,&block));
    struct st_target param={0},alias={0},local={0},result={0};
    param.kind=4;param.scope=1;param.type=type;param.representation=representation;param.flags=4;
    alias=param;alias.flags=0;local=param;local.kind=2;local.flags=0;result=param;result.kind=6;result.flags=0;result.scope=0;
    if(variant==0) {CHECK(ll_identity(w,&param.value) && ll_identity(w,&param.address) && ll_identity(w,&alias.value) && ll_identity(w,&local.address) && ll_identity(w,&result.address));alias.address=alias.value;}
    if(variant==2)CHECK(ll_identity(w,&local.address));if(variant==3)CHECK(ll_identity(w,&result.address));
    const char* names[]={"touch","get","local_zero","result_zero"};
    CHECK(ll_text(w,"define ") && ll_type(w,representation,type>=6) && ll_text(w," @") && ll_text(w,names[variant]) && ll_number(w,type) && ll_text(w,"("));
    if(variant==0) {
        struct ll_operand incoming={2,type,representation,param.value};
        CHECK(ll_typed(w,&incoming) && ll_text(w,", ptr %v") && ll_number(w,alias.value));
    }
    CHECK(ll_line(w,") {") && ll_line(w,"entry:"));struct ll_operand value={0};
    if(variant==0) {
        CHECK(st_storage(w,&param,1) && st_storage(w,&alias,1) && st_storage(w,&local,1) && st_storage(w,&result,1));
        CHECK(st_load(w,&alias,1,&value) && st_store(w,&result,1,&value));
        CHECK(st_load(w,&param,1,&value) && st_store(w,&local,1,&value));
        value=(struct ll_operand){1,type,representation,1};CHECK(st_store(w,&param,1,&value));
        CHECK(st_load(w,&param,1,&value) && st_store(w,&alias,1,&value));
        CHECK(st_load(w,&local,1,&value) && st_store(w,global,1,&value));
        CHECK(st_load(w,&result,1,&value));
    }
    if(variant==1)CHECK(st_load(w,global,1,&value));
    if(variant==2)CHECK(st_storage(w,&local,1) && st_load(w,&local,1,&value));
    if(variant==3)CHECK(st_storage(w,&result,1) && st_load(w,&result,1,&value));
    CHECK(ll_text(w,"  ret ") && ll_typed(w,&value) && ll_line(w,"") && ll_line(w,"}"));return 0;
}
static int storage_cases(void) {
    CHECK(declaration_cases()==0);struct ll_writer w={0};em_defaults(&w.limits);struct ube_gc_root roots[3]={{0}};
    CHECK(ube_gc_root_enter(&roots[0],&w.output.buffer.bytes) && ube_gc_root_enter(&roots[1],&w.output.snapshot) && ube_gc_root_enter(&roots[2],&w.cancellation));
    w.failure=(struct em_failure){1509,0};CHECK(ll_begin(&w) && ll_line(&w,"target triple = \"x86_64-w64-windows-gnu\""));
    for(int type=1;type<=8;++type) {
        int representation=type<=5?type:type-4;struct st_target global={0};global.kind=2;global.scope=0;global.type=type;global.representation=representation;
        CHECK(ll_identity(&w,&global.address) && st_storage(&w,&global,1));
        for(int variant=0;variant<4;++variant)CHECK(storage_function(&w,type,representation,&global,variant)==0);
    }
    FILE* counts=fopen("storage-identities.txt","wb");CHECK(counts!=NULL && fprintf(counts,"%lld\n",(long long)w.usage.identities)>0 && fclose(counts)==0);
    CHECK(ll_snapshot(&w));int32_t failure=8,token=create_output(L"storage.ll");CHECK(token>0 && em_write(&w.output,token,NULL,&w.failure,&failure) && ube_file_try_close(&token,&failure) && ll_dispose(&w) && w.usage.payload==0);
    for(int i=2;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));CHECK(ube_gc_collect() && ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);return 0;
}
