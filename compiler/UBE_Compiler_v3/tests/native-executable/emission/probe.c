/* Reuse the qualified file-token producer, actual runtime observers and native
   short/failure I/O controls. Its original suite is retained but not rerun here. */
#define main counted_output_reference_main
#include "std-lib/tests/file-output/native.c"
#undef main

struct em_limits { int64_t payload,llvm,identities,pending,work,depth,candidate; };
struct em_usage { int64_t payload,peak_payload,llvm,identities,pending,peak_pending,work,depth,peak_depth; };
struct em_failure { int32_t code,resource; };
struct em_buffer { void* bytes; int32_t count; };
struct em_output { struct em_buffer buffer; void* snapshot; int32_t capacity,length,snapshot_length,status; };
struct integer_encoder { int64_t remaining,divisor; bool sign; };
extern void em_defaults(struct em_limits*), integer_begin(int64_t,struct integer_encoder*,int32_t*), em_cancel(void*);
extern int32_t integer_next(struct integer_encoder*,uint8_t*,bool*), em_cancel_make(void**);
extern int32_t em_begin(struct em_output*,void*,struct em_failure*);
extern int32_t em_ascii(struct em_output*,struct em_limits*,struct em_usage*,const char*,void*,struct em_failure*);
extern int32_t em_integer(struct em_output*,struct em_limits*,struct em_usage*,int64_t,void*,struct em_failure*);
extern int32_t em_byte(struct em_output*,struct em_limits*,struct em_usage*,uint8_t,void*,struct em_failure*);
extern int32_t em_range(struct em_output*,struct em_limits*,struct em_usage*,void**,int32_t,int32_t,void*,struct em_failure*);
extern int32_t em_snapshot(struct em_output*,struct em_limits*,struct em_usage*,void*,struct em_failure*);
extern int32_t em_write(struct em_output*,int32_t,void*,struct em_failure*,int32_t*);
extern int32_t em_release(struct em_output*,struct em_usage*,struct em_failure*), em_dispose(struct em_output*,struct em_usage*,struct em_failure*);

static int integer_case(int64_t value,const char* expected) {
    struct integer_encoder e={0};int32_t count=-1;uint8_t byte=201;bool has=false;
    observe();integer_begin(value,&e,&count);
    CHECK(count==(int32_t)strlen(expected));
    for(int32_t i=0;i<count;++i) CHECK(integer_next(&e,&byte,&has)==1 && has && byte==(unsigned char)expected[i]);
    byte=201;has=true;CHECK(integer_next(&e,&byte,&has)==1 && !has && byte==201);
    has=true;CHECK(integer_next(&e,&byte,&has)==1 && !has && byte==201);
    CHECK(clean_cost());
    return 0;
}
static int integer_cases(void) {
    const struct {int64_t value;const char* text;} cases[]={
        {0,"0"},{1,"1"},{-1,"-1"},{32767,"32767"},{-32768,"-32768"},
        {INT32_MAX,"2147483647"},{INT32_MIN,"-2147483648"},
        {INT64_MAX,"9223372036854775807"},{INT64_MIN,"-9223372036854775808"}};
    for(int seed=7;seed<=77;seed+=70) {
        ube_err_set(seed,"prior","decimal");
        for(size_t i=0;i<sizeof cases/sizeof cases[0];++i) CHECK(integer_case(cases[i].value,cases[i].text)==0);
        int64_t power=1;
        for(int n=0;n<19;++n) {
            for(int delta=-1;delta<=1;++delta) for(int sign=-1;sign<=1;sign+=2) {
                int64_t value=(power+delta)*sign;char text[32];
                CHECK(snprintf(text,sizeof text,"%lld",(long long)value)>0);
                CHECK(integer_case(value,text)==0);
            }
            if(n!=18)power*=10;
        }
        CHECK(ube_err_number()==seed);
    }
    struct integer_encoder e={0};uint8_t byte=211;bool has=true;
    CHECK(integer_next(&e,&byte,&has)==1 && !has && byte==211);
    const struct integer_encoder invalid[]={{1,1,false},{0,-1,false},{-1,0,false},{0,0,true},{-10,1,false}};
    for(size_t i=0;i<sizeof invalid/sizeof invalid[0];++i) {
        e=invalid[i];struct integer_encoder before=e;byte=212;has=true;
        CHECK(integer_next(&e,&byte,&has)==0 && byte==212 && has && memcmp(&e,&before,sizeof e)==0);
    }
    struct integer_encoder first={0},second={0};int32_t count=0;
    integer_begin(-12,&first,&count);CHECK(count==3);
    integer_begin(34,&second,&count);CHECK(count==2);
    CHECK(integer_next(&first,&byte,&has) && has && byte=='-');
    CHECK(integer_next(&second,&byte,&has) && has && byte=='3');
    integer_begin(0,&first,&count);CHECK(count==1 && integer_next(&first,&byte,&has) && has && byte=='0');
    CHECK(integer_next(&second,&byte,&has) && has && byte=='4');
    return 0;
}
struct decimal_job { HANDLE ready,release; int id,passed; };
static DWORD WINAPI decimal_worker(void* argument) {
    struct decimal_job* job=argument;
    if(!SetEvent(job->ready) || WaitForSingleObject(job->release,5000)!=WAIT_OBJECT_0)return 1;
    ube_err_set(71+job->id,"worker","decimal");observe();
    for(int i=0;i<256;++i) {
        int64_t value=INT64_MIN+i+job->id;char expected[32];
        if(snprintf(expected,sizeof expected,"%lld",(long long)value)<=0)return 1;
        struct integer_encoder e={0};int32_t count=0;integer_begin(value,&e,&count);
        if(count!=(int32_t)strlen(expected))return 1;
        for(int32_t at=0;at<count;++at) {
            uint8_t byte=0;bool has=false;
            if(!integer_next(&e,&byte,&has) || !has || byte!=(uint8_t)expected[at])return 1;
        }
        bool has=true;uint8_t byte=203;
        if(!integer_next(&e,&byte,&has) || has || byte!=203)return 1;
    }
    job->passed=clean_cost() && ube_err_number()==71+job->id;
    return job->passed?0:1;
}
static int decimal_workers(void) {
    struct decimal_job jobs[4]={{0}};HANDLE threads[4]={0};
    HANDLE release=CreateEventW(NULL,TRUE,FALSE,NULL);CHECK(release!=NULL);
    for(int i=0;i<4;++i) {
        jobs[i].id=i;jobs[i].release=release;jobs[i].ready=CreateEventW(NULL,TRUE,FALSE,NULL);
        CHECK(jobs[i].ready!=NULL);
        threads[i]=CreateThread(NULL,0,decimal_worker,&jobs[i],0,NULL);CHECK(threads[i]!=NULL);
    }
    for(int i=0;i<4;++i)CHECK(WaitForSingleObject(jobs[i].ready,5000)==WAIT_OBJECT_0);
    CHECK(SetEvent(release));
    for(int i=0;i<4;++i) {
        CHECK(WaitForSingleObject(threads[i],5000)==WAIT_OBJECT_0 && jobs[i].passed);
        CHECK(CloseHandle(threads[i]) && CloseHandle(jobs[i].ready));
    }
    CHECK(CloseHandle(release));return 0;
}
static int emission_cases(void) {
    struct em_limits l;em_defaults(&l);struct em_usage u={0};struct em_failure f={1509,0};
    struct em_output s={0};struct ube_gc_root roots[4]={{0}};void* cancel=NULL;void* source=NULL;
    CHECK(ube_gc_root_enter(&roots[0],&s.buffer.bytes) && ube_gc_root_enter(&roots[1],&s.snapshot));
    CHECK(ube_gc_root_enter(&roots[2],&cancel) && ube_gc_root_enter(&roots[3],&source));
    CHECK(em_begin(&s,NULL,&f) && f.code==0);
    const char* prefix="target triple = \"x86_64-w64-windows-gnu\"\ndefine i32 @main() {\nentry:\n  ret i32 ";
    const char* expected="target triple = \"x86_64-w64-windows-gnu\"\ndefine i32 @main() {\nentry:\n  ret i32 37\n}\n";
    ube_err_set(77,"prior","emission");
    CHECK(em_ascii(&s,&l,&u,prefix,NULL,&f) && em_integer(&s,&l,&u,37,NULL,&f) && em_ascii(&s,&l,&u,"\n}\n",NULL,&f));
    CHECK(s.length==(int32_t)strlen(expected) && u.llvm==s.length && u.payload==s.capacity && s.capacity==128);
    CHECK(ube_value_array_length(&s.buffer.bytes)==s.capacity);
    observe();CHECK(em_snapshot(&s,&l,&u,NULL,&f));observing=0;
    CHECK(copies==2*strlen(expected) && s.snapshot_length==s.length && u.payload==128+s.length && u.peak_payload==128+2*s.length);
    CHECK(ube_value_array_length(&s.snapshot)==s.snapshot_length);
    CHECK(memcmp(((struct ube_array*)s.snapshot)->data,expected,strlen(expected))==0);
    struct em_usage before=u;CHECK(!em_snapshot(&s,&l,&u,NULL,&f) && f.code==1509 && memcmp(&u,&before,sizeof u)==0);
    CHECK(!em_byte(&s,&l,&u,0,NULL,&f) && f.code==1509 && memcmp(&u,&before,sizeof u)==0);
    int32_t file_failure=0,token=create_output(L"program.ll");CHECK(token>0);
    write_mode=1;observe();CHECK(em_write(&s,token,NULL,&f,&file_failure));
    CHECK(clean_cost() && writes>1 && flushes==1 && s.status==5 && ube_err_number()==77);
    CHECK(!em_write(&s,token,NULL,&f,&file_failure) && f.code==1509);
    CHECK(ube_file_try_close(&token,&file_failure) && contents(L"program.ll",(const unsigned char*)expected,(DWORD)strlen(expected)));
    write_mode=0;CHECK(em_release(&s,&u,&f) && s.snapshot==NULL && u.payload==128);
    CHECK(em_begin(&s,NULL,&f));observe();CHECK(em_integer(&s,&l,&u,INT64_MIN,NULL,&f));
    CHECK(clean_cost() && s.length==20 && s.capacity==128 && u.llvm==(int64_t)strlen(expected)+20);
    CHECK(em_snapshot(&s,&l,&u,NULL,&f) && memcmp(((struct ube_array*)s.snapshot)->data,"-9223372036854775808",20)==0);
    CHECK(em_release(&s,&u,&f) && em_dispose(&s,&u,&f) && u.payload==0 && s.buffer.bytes==NULL);

    u=(struct em_usage){0};CHECK(em_begin(&s,NULL,&f));observe();
    for(int i=0;i<256;++i) CHECK(em_byte(&s,&l,&u,(uint8_t)i,NULL,&f));
    observing=0;
    CHECK(copies==248 && allocations>0 && allocations<=24 && s.capacity==256 && u.payload==256 && u.peak_payload==384 && u.llvm==256);
    CHECK(em_dispose(&s,&u,&f) && u.payload==0);

    /* Cumulative bytes cross module boundaries, while retained capacity and
       snapshot ownership each have independent exact-limit obligations. */
    u=(struct em_usage){0};l.llvm=8;l.payload=24;
    CHECK(em_begin(&s,NULL,&f) && em_ascii(&s,&l,&u,"12345678",NULL,&f));
    before=u;CHECK(!em_byte(&s,&l,&u,'9',NULL,&f) && f.code==1502 && f.resource==2 && memcmp(&u,&before,sizeof u)==0 && s.length==8);
    CHECK(em_dispose(&s,&u,&f) && u.payload==0 && u.llvm==8);
    u=(struct em_usage){0};em_defaults(&l);l.payload=23;
    CHECK(em_begin(&s,NULL,&f) && em_ascii(&s,&l,&u,"12345678",NULL,&f));
    CHECK(!em_byte(&s,&l,&u,'9',NULL,&f) && f.code==1502 && f.resource==1 && u.payload==8 && u.llvm==8 && s.capacity==8);
    CHECK(em_dispose(&s,&u,&f) && u.payload==0);
    u=(struct em_usage){0};CHECK(em_begin(&s,NULL,&f) && em_ascii(&s,&l,&u,"12345678",NULL,&f));
    CHECK(!em_snapshot(&s,&l,&u,NULL,&f) && f.code==1502 && f.resource==1 && s.snapshot==NULL && u.payload==8);
    CHECK(em_dispose(&s,&u,&f) && u.payload==0);
    l.payload=24;u=(struct em_usage){0};CHECK(em_begin(&s,NULL,&f) && em_ascii(&s,&l,&u,"12345678",NULL,&f));
    CHECK(em_snapshot(&s,&l,&u,NULL,&f) && u.payload==16 && u.peak_payload==24);
    CHECK(em_dispose(&s,&u,&f) && u.payload==0);

    /* All raw byte values and a 65536 boundary use the actual range appender. */
    em_defaults(&l);u=(struct em_usage){0};CHECK(ube_value_try_resize(&source,65540,&ube_file_byte_layout,0));
    for(int i=0;i<65540;++i)((struct ube_array*)source)->data[i]=(unsigned char)i;
    CHECK(em_begin(&s,NULL,&f) && em_range(&s,&l,&u,&source,1,65539,NULL,&f));
    CHECK(em_snapshot(&s,&l,&u,NULL,&f) && s.snapshot_length==65539 && memcmp(((struct ube_array*)s.snapshot)->data,((struct ube_array*)source)->data+1,65539)==0);
    CHECK(em_dispose(&s,&u,&f) && u.payload==0);

    /* A zero-progress write cannot hang; failures retain the file owner and
       snapshot until their caller explicitly releases each one. */
    for(int mode=2;mode<=5;++mode) {
        wchar_t path[32];CHECK(swprintf(path,32,L"failed%d.bin",mode)>0);
        CHECK(em_begin(&s,NULL,&f) && em_ascii(&s,&l,&u,"payload",NULL,&f) && em_snapshot(&s,&l,&u,NULL,&f));
        token=create_output(path);CHECK(token>0);int32_t old=token;
        write_mode=mode==5?0:mode;flush_mode=mode==5;
        CHECK(!em_write(&s,token,NULL,&f,&file_failure) && f.code==1508 && file_failure==(mode==5?16:15) && token==old && s.snapshot!=NULL && s.status==4);
        CHECK(ube_file_try_close(&token,&file_failure) && em_dispose(&s,&u,&f) && u.payload==0);
        write_mode=0;flush_mode=0;
    }
    CHECK(em_cancel_make(&cancel));em_cancel(cancel);
    CHECK(!em_begin(&s,cancel,&f) && f.code==1507 && em_dispose(&s,&u,&f));
    CHECK(em_begin(&s,NULL,&f) && em_ascii(&s,&l,&u,"cancel before snapshot",NULL,&f));
    CHECK(!em_snapshot(&s,&l,&u,cancel,&f) && f.code==1507 && s.snapshot==NULL && em_dispose(&s,&u,&f));
    CHECK(em_begin(&s,NULL,&f) && em_ascii(&s,&l,&u,"cancel before write",NULL,&f) && em_snapshot(&s,&l,&u,NULL,&f));
    token=create_output(L"cancel.bin");CHECK(token>0);observe();
    CHECK(!em_write(&s,token,cancel,&f,&file_failure) && f.code==1507 && s.snapshot!=NULL);
    if(allocations || copies || writes || flushes) fprintf(stderr,"cancellation observation allocations=%zu copies=%zu writes=%zu flushes=%zu\n",allocations,copies,writes,flushes);
    CHECK(clean_cost() && writes==0 && flushes==0);
    CHECK(ube_file_try_close(&token,&file_failure) && em_dispose(&s,&u,&f) && u.payload==0);
    CHECK(em_begin(&s,NULL,&f));ube_gc_test_fail_next_allocations(1000000);
    CHECK(!em_ascii(&s,&l,&u,"allocation denied",NULL,&f) && f.code==1502 && f.resource==1 && s.capacity==0 && u.payload==0);
    ube_gc_test_fail_next_allocations(0);CHECK(em_dispose(&s,&u,&f));
    CHECK(em_begin(&s,NULL,&f) && em_ascii(&s,&l,&u,"snapshot allocation denied",NULL,&f));
    before=u;ube_gc_test_fail_next_allocations(1000000);
    CHECK(!em_snapshot(&s,&l,&u,NULL,&f) && f.code==1502 && f.resource==1 && s.snapshot==NULL && u.payload==before.payload);
    ube_gc_test_fail_next_allocations(0);CHECK(em_dispose(&s,&u,&f) && u.payload==0);

    /* Empty module still flushes its owned token, takes one snapshot and can
       release all storage without confusing zero bytes with an absent owner. */
    CHECK(em_begin(&s,NULL,&f) && em_snapshot(&s,&l,&u,NULL,&f));token=create_output(L"empty.ll");CHECK(token>0);
    observe();CHECK(em_write(&s,token,NULL,&f,&file_failure));CHECK(clean_cost() && writes==0 && flushes==1);
    CHECK(ube_file_try_close(&token,&file_failure) && contents(L"empty.ll",(const unsigned char*)"",0) && em_dispose(&s,&u,&f) && u.payload==0);

    size_t available=UBE_GC_MAX_ROOTS-ube_gc_root_count;
    struct ube_gc_root* pressure=calloc(available,sizeof(*pressure));void* neutral=NULL;CHECK(pressure!=NULL);
    for(size_t i=0;i<available;++i) CHECK(ube_gc_root_enter(&pressure[i],&neutral));
    ube_err_set(77,"prior","full roots");ube_gc_test_fail_next_allocations(1000000);
    CHECK(integer_case(INT64_MIN,"-9223372036854775808")==0 && ube_err_number()==77);
    ube_gc_test_fail_next_allocations(0);
    /* Leave each real root capacity 0..32 available. A failed nested helper
       must never return False with a stale success diagnostic or lose charges.
       Temporarily open extra capacity only for explicit cleanup, then refill. */
    int successes=0,failures=0;
    for(size_t spare=0;spare<=32;++spare) {
        u=(struct em_usage){0};f=(struct em_failure){1509,0};
        int ok=em_begin(&s,NULL,&f);
        if(ok){f=(struct em_failure){1509,0};ok=em_ascii(&s,&l,&u,"root admission",NULL,&f);}
        CHECK((ok && f.code==0 && s.length==14) || (!ok && f.code!=0));
        if(ok)++successes;else++failures;
        CHECK(s.buffer.count==s.length && u.llvm==s.length && u.payload==s.capacity && ube_gc_root_count==UBE_GC_MAX_ROOTS-spare);
        for(size_t i=0;i<128;++i)CHECK(ube_gc_root_leave(&pressure[available-spare-1-i]));
        CHECK(em_dispose(&s,&u,&f) && u.payload==0 && s.status==0);
        for(size_t i=0;i<128;++i)CHECK(ube_gc_root_enter(&pressure[available-spare-1-i],&neutral));
        if(spare<32)CHECK(ube_gc_root_leave(&pressure[available-spare-1]));
    }
    CHECK(successes>0 && failures>0);
    for(size_t i=0;i<available-32;++i) CHECK(ube_gc_root_leave(&pressure[i]));
    free(pressure);
    for(int i=3;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));cancel=NULL;source=NULL;
    CHECK(ube_gc_collect() && ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0 && ube_file_test_open_handles()==0);
    return 0;
}
#include "traversal.c"
#include "graph.c"
#include "llvm.c"
#include "conversions.c"
#include "arithmetic.c"
#include "representation.c"
#include "storage.c"
int main(void) {
    CHECK(sizeof(struct em_limits)==56 && sizeof(struct em_usage)==72 && sizeof(struct em_output)==40 && sizeof(struct integer_encoder)==24);
    CHECK(integer_cases()==0 && decimal_workers()==0 && traversal_cases()==0 && graph_cases()==0 && emission_cases()==0 && llvm_cases()==0 && conversion_cases()==0 && arithmetic_cases()==0 && representation_cases()==0 && storage_cases()==0);
    printf("PASS native emission %d assertions\n",checks);
    return 0;
}
