extern int32_t ll_binary(struct ll_writer*,struct tr_node*,struct ll_type*,struct ll_operand*,struct ll_operand*,struct ll_operand*,int32_t*,bool*);
extern int32_t ll_unary(struct ll_writer*,struct tr_node*,struct ll_operand*,struct ll_operand*,int32_t*,bool*);
extern int32_t ll_overflow_declarations(struct ll_writer*,int32_t);

static int arithmetic_function(struct ll_writer* w,int type,int operation,bool unary,int32_t* support,bool* needs_error) {
    int64_t function,parameter,second,block;
    CHECK(ll_identity(w,&function) && ll_identity(w,&parameter) && ll_identity(w,&second) && ll_identity(w,&block));
    struct ll_operand input={2,5,5,parameter},right_input={2,5,5,second};
    CHECK(ll_text(w,"define i64 @") && ll_text(w,unary?"unary":"arith") && ll_number(w,type) && ll_text(w,"op") && ll_number(w,operation));
    CHECK(ll_text(w,"(i64 ") && ll_operand(w,&input) && ll_text(w,", i64 ") && ll_operand(w,&right_input) && ll_line(w,") {") && ll_line(w,"entry:"));
    struct ll_operand left=input,right=right_input;
    if(type!=5) {
        CHECK(ll_instruction(w,type,type,&left) && ll_text(w,"trunc ") && ll_typed(w,&input) && ll_text(w," to ") && ll_type(w,type,false) && ll_line(w,""));
        CHECK(ll_instruction(w,type,type,&right) && ll_text(w,"trunc ") && ll_typed(w,&right_input) && ll_text(w," to ") && ll_type(w,type,false) && ll_line(w,""));
    }
    const int64_t minimum[]={0,0,0,INT16_MIN,INT32_MIN,INT64_MIN};
    const int64_t maximum[]={0,1,255,INT16_MAX,INT32_MAX,INT64_MAX};
    struct tr_node node={0};node.kind=unary?4:5;node.type=operation>=15&&operation<=20?1:type;node.children=unary?1:2;node.auxiliary=operation;
    struct ll_type operand_type={0};operand_type.kind=type==1?1:2;operand_type.minimum=minimum[type];operand_type.maximum=maximum[type];
    struct ll_operand result={0};
    if(unary)CHECK(ll_unary(w,&node,&left,&result,support,needs_error));
    else CHECK(ll_binary(w,&node,&operand_type,&left,&right,&result,support,needs_error));
    CHECK(result.type==node.type && result.representation==node.type);
    struct ll_operand returned=result;
    if(result.representation!=5) {
        CHECK(ll_instruction(w,5,5,&returned) && ll_text(w,result.representation==1?"zext ":"sext ") && ll_typed(w,&result) && ll_line(w," to i64"));
    }
    CHECK(ll_text(w,"  ret ") && ll_typed(w,&returned) && ll_line(w,"") && ll_line(w,"}"));
    return 0;
}

static int arithmetic_cases(void) {
    struct ll_writer w={0};em_defaults(&w.limits);struct ube_gc_root roots[3]={{0}};
    CHECK(ube_gc_root_enter(&roots[0],&w.output.buffer.bytes) && ube_gc_root_enter(&roots[1],&w.output.snapshot) && ube_gc_root_enter(&roots[2],&w.cancellation));
    w.failure=(struct em_failure){1509,0};CHECK(ll_begin(&w));bool needs_error=false;int32_t support=0;
    CHECK(ll_line(&w,"target triple = \"x86_64-w64-windows-gnu\""));
    const int operations[]={8,10,11,12,13,15,16,17,18,19,20,24,26,28,29,30};
    for(int type=3;type<=5;++type) {
        for(size_t i=0;i<sizeof(operations)/sizeof(operations[0]);++i)CHECK(arithmetic_function(&w,type,operations[i],false,&support,&needs_error)==0);
        for(int operation=4;operation<=6;++operation)CHECK(arithmetic_function(&w,type,operation,true,&support,&needs_error)==0);
    }
    const int boolean_operations[]={15,16,24,26,28,29,30};
    for(size_t i=0;i<sizeof(boolean_operations)/sizeof(boolean_operations[0]);++i)CHECK(arithmetic_function(&w,1,boolean_operations[i],false,&support,&needs_error)==0);
    CHECK(arithmetic_function(&w,1,6,true,&support,&needs_error)==0);
    CHECK(support==511 && needs_error && ll_overflow_declarations(&w,support) && ll_error_support(&w));
    FILE* counts=fopen("arithmetic-identities.txt","wb");CHECK(counts!=NULL && fprintf(counts,"%lld\n",(long long)w.usage.identities)>0 && fclose(counts)==0);
    CHECK(ll_snapshot(&w));int32_t file_failure=8,token=create_output(L"arithmetic.ll");CHECK(token>0);
    CHECK(em_write(&w.output,token,NULL,&w.failure,&file_failure) && ube_file_try_close(&token,&file_failure) && ll_dispose(&w) && w.usage.payload==0);
    CHECK(ll_begin(&w));struct tr_node node={0};node.kind=5;node.type=1;node.children=2;node.auxiliary=25;
    struct ll_type type={0};struct ll_operand left={1,1,1,0},right={1,1,1,1},result={2,5,5,123};
    CHECK(!ll_binary(&w,&node,&type,&left,&right,&result,&support,&needs_error) && w.failure.code==1509 && result.value==123 && w.output.length==0);
    node.type=3;node.auxiliary=12;left=(struct ll_operand){1,3,3,1};right=left;w.limits.identities=0;
    CHECK(!ll_binary(&w,&node,&type,&left,&right,&result,&support,&needs_error) && w.failure.code==1502 && result.value==123 && w.output.length==0);
    CHECK(ll_dispose(&w) && w.usage.payload==0);
    for(int i=2;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));CHECK(ube_gc_collect() && ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);
    return 0;
}
