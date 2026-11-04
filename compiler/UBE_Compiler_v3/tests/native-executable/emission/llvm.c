struct ll_writer {struct em_failure failure;struct em_limits limits;struct em_usage usage;struct em_output output;void* cancellation;};
extern int32_t ll_begin(struct ll_writer*),ll_text(struct ll_writer*,const char*),ll_line(struct ll_writer*,const char*),ll_number(struct ll_writer*,int64_t);
extern int32_t ll_type(struct ll_writer*,int32_t,bool),ll_constant(struct ll_writer*,int32_t,bool,int64_t),ll_identity(struct ll_writer*,int64_t*),ll_snapshot(struct ll_writer*),ll_dispose(struct ll_writer*);
static int llvm_cases(void) {
    CHECK(sizeof(struct ll_writer)==184);
    struct ll_writer w={0};em_defaults(&w.limits);struct ube_gc_root roots[3]={{0}};
    CHECK(ube_gc_root_enter(&roots[0],&w.output.buffer.bytes) && ube_gc_root_enter(&roots[1],&w.output.snapshot) && ube_gc_root_enter(&roots[2],&w.cancellation));
    const int64_t lo[]={0,0,0,-32768,INT32_MIN,INT64_MIN},hi[]={0,1,255,32767,INT32_MAX,INT64_MAX};
    const char* types[]={"void","i1","i8","i16","i32","i64"};
    char expected[4096]={0};size_t length=0;ube_err_set(77,"prior","LLVM");
    w.failure=(struct em_failure){1509,0};CHECK(ll_begin(&w));
    CHECK(ll_line(&w,"target triple = \"x86_64-w64-windows-gnu\""));
    int appended=snprintf(expected,sizeof expected,"target triple = \"x86_64-w64-windows-gnu\"\n");CHECK(appended>0);length=(size_t)appended;
    int64_t sequence=0;
    for(int aggregate=0;aggregate<2;++aggregate)for(int rep=aggregate?2:1;rep<=(aggregate?4:5);++rep)for(int upper=0;upper<2;++upper) {
        int64_t value=upper?hi[rep]:lo[rep],function=-1,block=-1;
        CHECK(ll_identity(&w,&function) && function==sequence++ && ll_identity(&w,&block) && block==sequence++);
        CHECK(ll_text(&w,"define ") && ll_type(&w,rep,aggregate!=0) && ll_text(&w," @literal") && ll_number(&w,function) && ll_line(&w,"() {"));
        CHECK(ll_line(&w,"entry:") && ll_text(&w,"  ret ") && ll_type(&w,rep,aggregate!=0) && ll_text(&w," ") && ll_constant(&w,rep,aggregate!=0,value) && ll_line(&w,"") && ll_line(&w,"}"));
        if(aggregate)appended=snprintf(expected+length,sizeof expected-length,"define { %s } @literal%lld() {\nentry:\n  ret { %s } { %s %lld }\n}\n",types[rep],(long long)function,types[rep],types[rep],(long long)value);
        else appended=snprintf(expected+length,sizeof expected-length,"define %s @literal%lld() {\nentry:\n  ret %s %lld\n}\n",types[rep],(long long)function,types[rep],(long long)value);
        CHECK(appended>0 && (size_t)appended<sizeof expected-length);length+=(size_t)appended;
    }
    CHECK(sequence==32 && w.usage.identities==32 && w.usage.llvm==(int64_t)length && w.failure.code==1509 && ube_err_number()==77);
    CHECK(ll_snapshot(&w) && w.failure.code==0 && w.output.snapshot_length==(int32_t)length && memcmp(gr_data(w.output.snapshot),expected,length)==0);
    int32_t token=create_output(L"literals.ll"),file_failure=8;CHECK(token>0);
    CHECK(em_write(&w.output,token,NULL,&w.failure,&file_failure) && ube_file_try_close(&token,&file_failure));
    CHECK(contents(L"literals.ll",(unsigned char*)expected,(DWORD)length) && ll_dispose(&w) && w.usage.payload==0);
    const struct {int rep;bool aggregate;int64_t value;} invalid[]={
        {0,false,0},{6,false,0},{1,false,-1},{1,false,2},{2,false,-1},{2,false,256},{3,false,-32769},{3,false,32768},{4,false,INT64_C(-2147483649)},{4,false,INT64_C(2147483648)},{1,true,1},{5,true,0}};
    for(size_t i=0;i<sizeof invalid/sizeof invalid[0];++i) {
        CHECK(ll_begin(&w));observe();CHECK(!ll_constant(&w,invalid[i].rep,invalid[i].aggregate,invalid[i].value) && w.failure.code==1509 && w.output.length==0 && clean_cost());CHECK(ll_dispose(&w));
    }
    const struct {int rep;bool aggregate;} invalid_types[]={{-1,false},{6,false},{0,true},{1,true},{5,true}};
    for(size_t i=0;i<sizeof invalid_types/sizeof invalid_types[0];++i) {
        CHECK(ll_begin(&w));observe();CHECK(!ll_type(&w,invalid_types[i].rep,invalid_types[i].aggregate) && w.failure.code==1509 && w.output.length==0 && clean_cost());CHECK(ll_dispose(&w));
    }
    for(int maximum=6;maximum<=8;++maximum) {
        w.usage=(struct em_usage){0};w.limits.llvm=maximum;CHECK(ll_begin(&w));int ok=ll_type(&w,4,true);
        if(maximum==6)CHECK(!ok && w.failure.code==1502 && w.failure.resource==2 && w.output.length==5);
        else CHECK(ok && w.output.length==7);
        CHECK(ll_dispose(&w) && w.usage.payload==0);
    }
    em_defaults(&w.limits);w.usage=(struct em_usage){0};w.limits.identities=1;int64_t id=-1;
    CHECK(ll_identity(&w,&id) && id==0);id=99;CHECK(!ll_identity(&w,&id) && id==99 && w.failure.code==1502 && w.failure.resource==3 && w.usage.identities==1);
    CHECK(ube_err_number()==77);
    for(int i=2;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));CHECK(ube_gc_collect() && ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);return 0;
}
