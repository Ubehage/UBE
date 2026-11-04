/* Retain the real runtime and the existing independent allocation/copy
   observers; the included file's original test main is not executed. */
#define main counted_output_reference_main
#include "std-lib/tests/file-output/native.c"
#undef main
struct limits {int64_t payload,llvm,identities,pending,work,depth,candidate;};
struct usage {int64_t payload,peak_payload,llvm,identities,pending,peak_pending,work,depth,peak_depth;};
struct failure {int32_t code,resource;};
struct semantic_failure {int32_t kind,code,source,first,last,related,rfirst,rlast;};
struct cursor {void* frames;int32_t capacity,count,status,pending,ordinal;};
struct plan {void* syntax;void* nodes;void* arguments;struct cursor cursor;int32_t syntax_count,node_count,argument_count,argument_capacity,status;void* procedure_roots;int32_t procedure_capacity,procedure_count,first_frame;void* import_marks;void* imports;int32_t import_mark_count,import_capacity,import_count;};
struct syntax_links {int32_t left,right,condition,argument,expression;};
struct node_links {int32_t scope,base,count,argument,temporaries;};
struct argument_links {int32_t child,map,conversion,node,written,temporary;};
struct node {int32_t source,syntax,kind,type;int64_t value;int32_t target,child,next,children,flags,auxiliary;};
struct fact {int32_t source,syntax,kind,type;int64_t value;int32_t target,left,right,flags,auxiliary,extra;};
struct metrics {int64_t syntax_reads,declaration_reads,declaration_writes,fact_writes,node_writes,transitions,scalars,bytes,lookups;int32_t pending,depth;};
struct module {void* catalog;int32_t source;void* facts;int32_t fact_count;void* values;int32_t value_count,root;struct metrics metrics;};
struct result {void* catalog;void* modules;int32_t entry;};
struct target_buffer {void* bytes;int32_t count;};
struct target_output {struct target_buffer buffer;void* snapshot;int32_t capacity,length,snapshot_length,status;};
struct writer {struct failure failure;struct limits limits;struct usage usage;struct target_output output;void* cancellation;};
struct operand {int32_t kind,type,representation;int64_t value;};
struct target {int32_t kind,source,scope,type,representation,flags,role,first_parameter,parameter_count,first_member,last_member,next_member,frame,byref;int64_t value,address;};
struct declarations {void* targets;int32_t count,status,frames,byrefs;};
extern int32_t graph_declarations(void**,struct declarations*,struct writer*),graph_release_declarations(struct declarations*,struct writer*);
extern int32_t graph_check(void**,int32_t,void**,struct semantic_failure*);
extern int32_t graph_plan(void**,int32_t,struct declarations*,struct plan*,struct limits*,struct usage*,struct failure*);
extern int32_t graph_dispose(struct plan*,struct usage*,struct failure*);
extern void graph_defaults(struct limits*);
extern int32_t writer_begin(struct writer*),writer_text(struct writer*,const char*),writer_line(struct writer*,const char*),writer_number(struct writer*,int64_t),writer_identity(struct writer*,int64_t*);
extern int32_t writer_operand(struct writer*,struct operand*),writer_typed(struct writer*,struct operand*),writer_instruction(struct writer*,int32_t,int32_t,struct operand*);
extern int32_t writer_snapshot(struct writer*),writer_dispose(struct writer*),writer_support(struct writer*);
extern int32_t graph_lower(void**,int32_t,int32_t,struct writer*,struct operand*,struct operand*,bool*);
extern int32_t graph_operator(void**,int32_t,int32_t,struct writer*,struct operand*,struct operand*,struct operand*,int32_t*,bool*);
extern int32_t writer_overflow(struct writer*,int32_t);
extern int32_t graph_root(struct plan*,int32_t,int32_t*);
static void* data(void* owner){return ((struct ube_array*)owner)->data;}
static const char source[]=
    "UBE SOURCE 1 MODULE\nAttribute UBE_Name = \"GraphInput\"\n"
    "Function Pick(ByVal A As Long, Optional ByRef B As Long = 17, Optional ByVal C As Long = 19) As Long\n"
    " B = B + 1\n Pick = A + B + C\nEnd Function\n"
    "Function Side(ByVal V As Long) As Long\n Side = V\nEnd Function\n"
    "Function Narrow(ByVal X As LongLong) As Byte\n Narrow = X\nEnd Function\n"
    "Function BoolByte(ByVal X As Boolean) As Byte\n BoolByte = X\nEnd Function\n"
    "Function Product(ByVal X As LongLong, ByVal Y As Long) As LongLong\n Product = X * Y\nEnd Function\n"
    "Function Quotient(ByVal X As LongLong, ByVal Y As Long) As LongLong\n Quotient = X \\ Y\nEnd Function\n"
    "Function Remainder(ByVal X As LongLong, ByVal Y As Long) As LongLong\n Remainder = X Mod Y\nEnd Function\n"
    "Function Sum(ByVal X As LongLong, ByVal Y As Long) As LongLong\n Sum = X + Y\nEnd Function\n"
    "Function Difference(ByVal X As LongLong, ByVal Y As Long) As LongLong\n Difference = X - Y\nEnd Function\n"
    "Function Negative(ByVal X As LongLong) As LongLong\n Negative = -X\nEnd Function\n"
    "Sub Main()\n Dim Sink As Long = Pick(C:=Side(3), A:=(1))\n Dim Other As Long = Pick(2,,4)\n"
    " Other = Pick(5,(Sink),6)\n Other = Pick(7,Sink,8)\n"
    " If Sink > 0 Then\n Other = Other + 1\n End If\nEnd Sub\n";
static int emit_checked_conversions(void** checked,struct module* m,struct writer* w) {
    int selected[2]={-1,-1};struct fact* facts=data(m->facts);
    for(int i=0;i<m->fact_count;++i)if(facts[i].kind==3 && facts[i].right==5 && facts[i].type==2 && (facts[i].left==5 || facts[i].left==1)) {
        int slot=facts[i].left==5?0:1;CHECK(selected[slot]==-1);selected[slot]=i;
    }
    CHECK(selected[0]>=0 && selected[1]>=0);graph_defaults(&w->limits);w->failure=(struct failure){1509,0};CHECK(writer_begin(w));
    CHECK(writer_line(w,"target triple = \"x86_64-w64-windows-gnu\""));bool needs_error=false;
    for(int i=0;i<2;++i) {
        int64_t function=-1,parameter=-1,block=-1;CHECK(writer_identity(w,&function) && writer_identity(w,&parameter) && writer_identity(w,&block));
        struct operand input={2,5,5,parameter},original=input,result={0},returned={0};
        CHECK(writer_text(w,i==0?"define i64 @checked_narrow(i64 ":"define i64 @checked_bool_byte(i64 ") && writer_operand(w,&input) && writer_line(w,") {") && writer_line(w,"entry:"));
        if(i==1)CHECK(writer_instruction(w,1,1,&original) && writer_text(w,"trunc ") && writer_typed(w,&input) && writer_line(w," to i1"));
        CHECK(graph_lower(checked,0,selected[i],w,&original,&result,&needs_error) && result.type==2 && result.representation==2);
        CHECK(writer_instruction(w,5,5,&returned) && writer_text(w,"zext ") && writer_typed(w,&result) && writer_line(w," to i64"));
        CHECK(writer_text(w,"  ret ") && writer_typed(w,&returned) && writer_line(w,"") && writer_line(w,"}"));
    }
    CHECK(needs_error && writer_support(w) && writer_snapshot(w));return 0;
}
static int emit_checked_arithmetic(void** checked,struct module* m,struct plan* p,struct writer* w) {
    const int operations[]={8,10,11,12,13,5};int selected[6]={-1,-1,-1,-1,-1,-1};struct node* nodes=data(m->values);
    for(int i=0;i<m->value_count;++i)if(nodes[i].type==5 && (nodes[i].kind==4 || nodes[i].kind==5)) {
        for(int k=0;k<6;++k)if(nodes[i].auxiliary==operations[k]){CHECK(selected[k]==-1);selected[k]=i;}
    }
    graph_defaults(&w->limits);w->failure=(struct failure){1509,0};CHECK(writer_begin(w));
    CHECK(writer_line(w,"target triple = \"x86_64-w64-windows-gnu\""));bool needs_error=false;int32_t overflow=0;
    struct syntax_links* links=data(p->syntax);struct fact* facts=data(m->facts);
    for(int k=0;k<6;++k) {
        CHECK(selected[k]>=0);struct node node=nodes[selected[k]];struct syntax_links link=links[node.syntax];
        CHECK(link.left>0 && facts[link.left-1].left==5 && facts[link.left-1].type==5);
        int64_t function,parameter,second,block;CHECK(writer_identity(w,&function) && writer_identity(w,&parameter) && writer_identity(w,&second) && writer_identity(w,&block));
        struct operand left={2,5,5,parameter},right={2,5,5,second},original_right=right,value={0};
        CHECK(writer_text(w,"define i64 @checked_op") && writer_number(w,operations[k]) && writer_text(w,"(i64 ") && writer_operand(w,&left) && writer_text(w,", i64 ") && writer_operand(w,&right) && writer_line(w,") {") && writer_line(w,"entry:"));
        CHECK(graph_lower(checked,0,link.left-1,w,&left,&left,&needs_error));
        if(node.kind==5) {
            CHECK(link.right>0 && facts[link.right-1].left==4 && facts[link.right-1].type==5);
            CHECK(writer_instruction(w,4,4,&original_right) && writer_text(w,"trunc ") && writer_typed(w,&right) && writer_line(w," to i32"));
            CHECK(graph_lower(checked,0,link.right-1,w,&original_right,&right,&needs_error));
        }
        CHECK(graph_operator(checked,0,selected[k],w,&left,&right,&value,&overflow,&needs_error) && value.type==5 && value.representation==5);
        CHECK(writer_text(w,"  ret ") && writer_typed(w,&value) && writer_line(w,"") && writer_line(w,"}"));
    }
    CHECK(overflow==448 && needs_error && writer_overflow(w,overflow) && writer_support(w) && writer_snapshot(w));return 0;
}
static int run(void) {
    void* bytes=NULL;void* result=NULL;struct plan p={0};struct writer w={0};struct declarations declarations={0};struct ube_gc_root roots[13]={{0}};
    void** owners[]={&bytes,&result,&p.syntax,&p.nodes,&p.arguments,&p.procedure_roots,&p.import_marks,&p.imports,&p.cursor.frames,&w.output.buffer.bytes,&w.output.snapshot,&w.cancellation,&declarations.targets};
    for(int i=0;i<13;++i)CHECK(ube_gc_root_enter(&roots[i],owners[i]));
    CHECK(ube_value_try_resize(&bytes,(int32_t)strlen(source),&ube_file_byte_layout,0));memcpy(data(bytes),source,strlen(source));
    unsigned char *prior_syntax=NULL,*prior_nodes=NULL,*prior_arguments=NULL;size_t syntax_bytes=0,node_bytes=0,argument_bytes=0;
    int32_t jobs[]={1,2,4};int64_t first_work=-1;
    unsigned char* prior_llvm=NULL;size_t llvm_bytes=0;
    unsigned char* prior_arithmetic=NULL;size_t arithmetic_bytes=0;
    struct target prior_targets[31];
    for(int j=0;j<3;++j) {
        struct semantic_failure sf={5,1428,0,0,0,0,0,0};
        int ok=graph_check(&bytes,jobs[j],&result,&sf);
        if(!ok)fprintf(stderr,"checker jobs=%d code=%d kind=%d span=%d..%d\n",jobs[j],sf.code,sf.kind,sf.first,sf.last);
        CHECK(ok && sf.code==0 && result!=NULL);
        struct result* checked=result;CHECK(ube_value_array_length(&checked->modules)==1);
        struct module* m=*(struct module**)data(checked->modules);CHECK(m!=NULL && m->value_count>0);
        graph_defaults(&w.limits);w.usage=(struct usage){0};w.failure=(struct failure){1509,0};
        CHECK(graph_declarations(&result,&declarations,&w) && declarations.status==1 && declarations.count==31 && w.usage.work==31 && w.usage.payload==31*72 && w.usage.identities==57);
        struct target* targets=data(declarations.targets);int functions=0,parameters=0,aliases=0,locals=0;
        for(int i=0;i<31;++i) {
            struct target target=targets[i];CHECK(target.source==0 && target.representation==target.type);
            if(target.kind==5 || target.kind==6){CHECK(target.frame==functions);++functions;CHECK(target.value>=0 && (target.kind==5 || target.address>=0));}
            if(target.kind==4){++parameters;CHECK(target.value>=0 && target.address>=0);if((target.flags&4)==0){CHECK(target.byref==aliases);++aliases;CHECK(target.address==target.value);}else CHECK(target.address!=target.value);}
            if(target.kind!=4 || (target.flags&4)!=0)CHECK(target.byref==-1);
            if(target.kind==2){++locals;CHECK(target.scope>0 && target.address>=0);}
        }
        CHECK(functions==11 && declarations.frames==11 && parameters==17 && aliases==1 && declarations.byrefs==1 && locals==2);
        if(j==0)memcpy(prior_targets,targets,sizeof prior_targets);else CHECK(memcmp(prior_targets,targets,sizeof prior_targets)==0);
        size_t vb=(size_t)m->value_count*sizeof(struct node),fb=(size_t)m->fact_count*sizeof(struct fact);
        unsigned char* before_values=malloc(vb);unsigned char* before_facts=malloc(fb);CHECK(before_values && before_facts);
        memcpy(before_values,data(m->values),vb);memcpy(before_facts,data(m->facts),fb);
        struct limits l;graph_defaults(&l);struct usage u={0};struct failure f={1509,0};
        ube_err_set(77,"prior","checked plan");observe();ok=graph_plan(&result,0,&declarations,&p,&l,&u,&f);observing=0;
        if(!ok)fprintf(stderr,"graph jobs=%d code=%d resource=%d work=%lld\n",jobs[j],f.code,f.resource,(long long)u.work);
        CHECK(graph_release_declarations(&declarations,&w) && w.usage.payload==0);
        CHECK(ok && f.code==0 && p.status==1 && p.argument_count==13 && u.pending==0 && u.depth==0 && ube_err_number()==77);
        CHECK(memcmp(before_values,data(m->values),vb)==0 && memcmp(before_facts,data(m->facts),fb)==0);
        CHECK(p.procedure_count==11 && p.procedure_capacity==11 && p.first_frame==0);
        struct node* nodes=data(m->values);struct fact* facts=data(m->facts);struct syntax_links* sl=data(p.syntax);struct node_links* nl=data(p.nodes);struct argument_links* al=data(p.arguments);
        int calls=0,named=0,omitted=0,temporary=0,alias=0,nested=0,operators=0,conditions=0;
        int seen_roots=0;for(int i=0;i<m->value_count;++i)if(((struct node*)data(m->values))[i].kind==101){int32_t found=-1;CHECK(graph_root(&p,seen_roots,&found) && found==i);++seen_roots;}CHECK(seen_roots==11);
        for(int i=0;i<m->value_count;++i) {
            if(!nl[i].scope)continue;
            struct node n=nodes[i];
            if(n.kind==4 || n.kind==5) {
                CHECK(n.syntax>=0 && n.syntax<p.syntax_count && sl[n.syntax].left>0);
                int operand_type=n.type==5?5:4;
                struct fact left=facts[sl[n.syntax].left-1];CHECK(left.kind==3 && left.target==n.syntax && left.right==1 && left.type==operand_type);
                if(n.kind==5){CHECK(sl[n.syntax].right>0);struct fact right=facts[sl[n.syntax].right-1];CHECK(right.kind==3 && right.target==n.syntax && right.right==2 && right.type==operand_type);}
                ++operators;
            }
            if(n.kind==106) {
                CHECK(sl[n.syntax].condition>0);struct fact condition=facts[sl[n.syntax].condition-1];CHECK(condition.kind==3 && condition.right==7 && condition.target==n.syntax && condition.type==1);++conditions;
            }
            if(n.kind!=6)continue;++calls;struct node_links link=nl[i];CHECK(link.count==n.children);
            for(int ordinal=0;ordinal<link.count;++ordinal){struct argument_links argument=al[link.base+ordinal];CHECK(argument.node>0 && argument.node<=m->value_count && nl[argument.node-1].argument==link.base+ordinal+1);}
            if(link.count==1){CHECK(nodes[al[link.base].node-1].value==3 && nodes[al[link.base].node-1].kind==1);++nested;continue;}
            CHECK(link.count==3);struct argument_links a=al[link.base],b=al[link.base+1],c=al[link.base+2];
            CHECK(a.node>0 && b.node>0 && c.node>0 && a.conversion>0 && c.conversion>0);
            int64_t first=nodes[a.node-1].value;struct fact bm=facts[b.map-1];
            if(first==1) {
                CHECK(nodes[b.node-1].kind==1 && nodes[b.node-1].value==17 && nodes[c.node-1].kind==6 && (bm.flags&3)==3 && b.conversion==0);
                CHECK(al[link.base].child==c.node && al[link.base+1].child==a.node && al[link.base+2].child==b.node);++named;
            } else if(first==2) {
                CHECK(nodes[b.node-1].value==17 && nodes[c.node-1].value==4 && (bm.flags&3)==3 && (bm.flags&8)!=0 && b.conversion==0);
                CHECK(al[link.base].child==a.node && al[link.base+1].child==c.node && al[link.base+2].child==b.node);++omitted;
            } else if(first==5) {
                CHECK(nodes[b.node-1].kind==3 && nodes[c.node-1].value==6 && (bm.flags&3)==2 && b.conversion>0);++temporary;
            } else if(first==7) {
                CHECK(nodes[b.node-1].kind==3 && nodes[c.node-1].value==8 && (bm.flags&3)==1 && b.conversion>0);++alias;
            } else CHECK(0);
        }
        CHECK(calls==5 && named==1 && omitted==1 && temporary==1 && alias==1 && nested==1 && operators==11 && conditions==1);
        w.usage=(struct usage){0};CHECK(emit_checked_conversions(&result,m,&w)==0);
        if(j==0) {
            llvm_bytes=(size_t)w.output.snapshot_length;prior_llvm=malloc(llvm_bytes);CHECK(prior_llvm!=NULL);memcpy(prior_llvm,data(w.output.snapshot),llvm_bytes);
            FILE* emitted=fopen("checked-conversions.ll","wb");CHECK(emitted!=NULL && fwrite(prior_llvm,1,llvm_bytes,emitted)==llvm_bytes && fclose(emitted)==0);
        } else CHECK((size_t)w.output.snapshot_length==llvm_bytes && memcmp(prior_llvm,data(w.output.snapshot),llvm_bytes)==0);
        CHECK(writer_dispose(&w) && w.usage.payload==0 && ube_err_number()==77);
        w.usage=(struct usage){0};CHECK(emit_checked_arithmetic(&result,m,&p,&w)==0);
        if(j==0) {
            arithmetic_bytes=(size_t)w.output.snapshot_length;prior_arithmetic=malloc(arithmetic_bytes);CHECK(prior_arithmetic!=NULL);memcpy(prior_arithmetic,data(w.output.snapshot),arithmetic_bytes);
            FILE* emitted=fopen("checked-arithmetic.ll","wb");CHECK(emitted!=NULL && fwrite(prior_arithmetic,1,arithmetic_bytes,emitted)==arithmetic_bytes && fclose(emitted)==0);
        } else CHECK((size_t)w.output.snapshot_length==arithmetic_bytes && memcmp(prior_arithmetic,data(w.output.snapshot),arithmetic_bytes)==0);
        CHECK(writer_dispose(&w) && w.usage.payload==0 && ube_err_number()==77);
        CHECK(memcmp(before_values,data(m->values),vb)==0 && memcmp(before_facts,data(m->facts),fb)==0);free(before_values);free(before_facts);
        if(j==0) {
            syntax_bytes=(size_t)p.syntax_count*sizeof(struct syntax_links);node_bytes=(size_t)p.node_count*sizeof(struct node_links);argument_bytes=(size_t)p.argument_count*sizeof(struct argument_links);
            prior_syntax=malloc(syntax_bytes);prior_nodes=malloc(node_bytes);prior_arguments=malloc(argument_bytes);CHECK(prior_syntax && prior_nodes && prior_arguments);
            memcpy(prior_syntax,data(p.syntax),syntax_bytes);memcpy(prior_nodes,data(p.nodes),node_bytes);memcpy(prior_arguments,data(p.arguments),argument_bytes);first_work=u.work;
        } else CHECK((size_t)p.syntax_count*sizeof(struct syntax_links)==syntax_bytes && (size_t)p.node_count*sizeof(struct node_links)==node_bytes && (size_t)p.argument_count*sizeof(struct argument_links)==argument_bytes && memcmp(prior_syntax,data(p.syntax),syntax_bytes)==0 && memcmp(prior_nodes,data(p.nodes),node_bytes)==0 && memcmp(prior_arguments,data(p.arguments),argument_bytes)==0 && u.work==first_work);
        CHECK(graph_dispose(&p,&u,&f) && u.payload==0 && u.pending==0 && u.depth==0);result=NULL;CHECK(ube_gc_collect());
    }
    free(prior_syntax);free(prior_nodes);free(prior_arguments);free(prior_llvm);free(prior_arithmetic);bytes=NULL;
    for(int i=12;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));CHECK(ube_gc_collect() && ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);return 0;
}
int main(void){if(run())return 1;printf("PASS checked native graph %d assertions\n",checks);return 0;}
