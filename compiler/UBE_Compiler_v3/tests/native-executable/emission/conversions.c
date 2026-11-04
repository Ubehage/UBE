struct ll_operand {int32_t kind,type,representation;int64_t value;};
struct ll_type {int32_t kind,declaration,representation,pack,unpack,bits;int64_t minimum,maximum;};
extern int32_t ll_operand(struct ll_writer*,struct ll_operand*),ll_typed(struct ll_writer*,struct ll_operand*);
extern int32_t ll_instruction(struct ll_writer*,int32_t,int32_t,struct ll_operand*);
extern int32_t ll_convert(struct ll_writer*,struct gr_fact*,struct ll_type*,struct ll_operand*,struct ll_operand*,bool*);
extern int32_t ll_error_support(struct ll_writer*);
static int conversion_cases(void) {
    CHECK(sizeof(struct ll_operand)==24 && sizeof(struct ll_type)==40);
    struct ll_writer w={0};em_defaults(&w.limits);struct ube_gc_root roots[3]={{0}};
    CHECK(ube_gc_root_enter(&roots[0],&w.output.buffer.bytes) && ube_gc_root_enter(&roots[1],&w.output.snapshot) && ube_gc_root_enter(&roots[2],&w.cancellation));
    const int64_t low[]={0,0,0,INT16_MIN,INT32_MIN,INT64_MIN},high[]={0,1,255,INT16_MAX,INT32_MAX,INT64_MAX};
    bool needs_error=false;w.failure=(struct em_failure){1509,0};ube_err_set(77,"prior","conversion emission");CHECK(ll_begin(&w));
    CHECK(ll_line(&w,"target triple = \"x86_64-w64-windows-gnu\""));
    for(int source=1;source<=5;++source)for(int destination=1;destination<=5;++destination) {
        int64_t function=-1,parameter=-1,block=-1;
        CHECK(ll_identity(&w,&function) && ll_identity(&w,&parameter) && ll_identity(&w,&block));
        struct ll_operand input={2,5,5,parameter};
        CHECK(ll_text(&w,"define i64 @convert") && ll_number(&w,source) && ll_text(&w,"to") && ll_number(&w,destination) && ll_text(&w,"(i64 ") && ll_operand(&w,&input) && ll_line(&w,") {") && ll_line(&w,"entry:"));
        struct ll_operand original=input;
        if(source!=5) {
            CHECK(ll_instruction(&w,source,source,&original) && ll_text(&w,"trunc ") && ll_typed(&w,&input) && ll_text(&w," to ") && ll_type(&w,source,false) && ll_line(&w,""));
        }
        struct gr_fact fact={0};fact.kind=3;fact.type=destination;fact.left=source;fact.flags=source!=destination;
        struct ll_type target={0};target.kind=destination==1?1:2;target.minimum=low[destination];target.maximum=high[destination];
        struct ll_operand result={0};int64_t before=w.usage.llvm;
        CHECK(ll_convert(&w,&fact,&target,&original,&result,&needs_error) && result.type==destination && result.representation==destination);
        if(source==destination)CHECK(w.usage.llvm==before && result.kind==original.kind && result.value==original.value);
        struct ll_operand returned=result;
        if(destination!=5) {
            CHECK(ll_instruction(&w,5,5,&returned) && ll_text(&w,destination<=2?"zext ":"sext ") && ll_typed(&w,&result) && ll_line(&w," to i64"));
        }
        CHECK(ll_text(&w,"  ret ") && ll_typed(&w,&returned) && ll_line(&w,"") && ll_line(&w,"}"));
    }
    CHECK(needs_error && ll_error_support(&w) && ube_err_number()==77);
    FILE* counts=fopen("conversion-identities.txt","wb");CHECK(counts!=NULL && fprintf(counts,"%lld\n",(long long)w.usage.identities)>0 && fclose(counts)==0);
    CHECK(ll_snapshot(&w));int32_t file_failure=8,token=create_output(L"conversions.ll");CHECK(token>0);
    CHECK(em_write(&w.output,token,NULL,&w.failure,&file_failure) && ube_file_try_close(&token,&file_failure) && ll_dispose(&w) && w.usage.payload==0);
    CHECK(ll_begin(&w));struct gr_fact fact={0};struct ll_type target={0};struct ll_operand original={1,1,1,1},result={0};
    fact.kind=3;fact.left=1;fact.type=4;fact.flags=3;fact.value=-1;
    CHECK(ll_convert(&w,&fact,&target,&original,&result,&needs_error) && result.kind==1 && result.type==4 && result.value==-1 && w.output.length==0);
    original=(struct ll_operand){2,10,4,44};fact.left=10;fact.type=10;fact.flags=0;
    CHECK(ll_convert(&w,&fact,&target,&original,&result,&needs_error) && result.kind==2 && result.type==10 && result.representation==4 && result.value==44 && w.output.length==0);
    struct ll_operand saved=result;fact.type=11;
    CHECK(!ll_convert(&w,&fact,&target,&original,&result,&needs_error) && w.failure.code==1509 && result.kind==saved.kind && result.type==saved.type && result.value==saved.value && w.output.length==0);
    CHECK(ll_dispose(&w) && w.usage.payload==0);
    for(int i=2;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));CHECK(ube_gc_collect() && ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);return 0;
}
