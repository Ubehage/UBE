struct gr_fact {int32_t source,syntax,kind,type;int64_t value;int32_t target,left,right,flags,auxiliary,extra;};
struct gr_syntax {int32_t left,right,condition,argument,expression;};
struct gr_node {int32_t scope,base,count,argument,temporaries;};
struct gr_argument {int32_t child,map,conversion,node,written,temporary;};
struct gr_target {int32_t kind,source,scope,type,representation,flags,role,first_parameter,parameter_count,first_member,last_member,next_member,frame,byref;int64_t value,address;};
struct gr_declarations {void* targets;int32_t count,status,frames,byrefs;};
struct gr_plan {void* syntax;void* nodes;void* arguments;struct tr_cursor cursor;int32_t syntax_count,node_count,argument_count,argument_capacity,status;void* procedure_roots;int32_t procedure_capacity,procedure_count,first_frame;void* import_marks;void* imports;int32_t import_mark_count,import_capacity,import_count;};
extern int32_t gr_targets(void**,int32_t),gr_make(void**,int32_t,bool),gr_dispose(struct gr_plan*,struct em_usage*,struct em_failure*);
extern int32_t gr_prepare(struct gr_plan*,void**,int32_t,int32_t,void**,int32_t,int32_t,struct gr_declarations*,struct em_limits*,struct em_usage*,void*,struct em_failure*);
extern int32_t gr_root(struct gr_plan*,int32_t,int32_t*);
static void* gr_data(void* owner){return ((struct ube_array*)owner)->data;}
static void graph_fixture(void* values,void* facts) {
    graph_shape(values,8,1);struct tr_node* n=graph_nodes(values);
    n[0].kind=100;n[1].kind=101;n[1].target=100;n[2].kind=102;
    n[3].kind=6;n[3].target=200;n[3].syntax=30;n[3].auxiliary=0;n[3].children=3;
    n[4].kind=6;n[4].target=300;n[4].syntax=31;n[4].auxiliary=1;n[4].next=6;
    n[5].kind=1;n[5].value=3;n[5].syntax=32;n[5].first=-1;n[5].children=0;
    n[6].kind=1;n[6].value=1;n[6].syntax=33;n[6].first=-1;n[6].children=0;n[6].next=7;
    n[7].kind=1;n[7].value=17;n[7].syntax=44;n[7].source=1;
    for(int i=3;i<8;++i)n[i].type=4;
    const struct gr_fact f[]={
        {0,30,5,4,0,200,5,3,0,2,-1},{0,31,5,4,0,300,4,1,0,1,-1},
        {0,32,3,4,3,400,4,6,2,0,-1},{0,31,3,4,0,502,4,6,0,2,-1},
        {0,32,6,4,0,400,1,32,0,0,0},
        {0,33,6,4,0,500,0,33,4,1,0},{0,30,6,4,17,501,0,-1,19,-1,1},{0,31,6,4,0,502,0,31,4,0,2},
        {0,33,3,4,1,500,4,6,2,0,-1},
        {0,42,3,3,0,40,2,1,1,0,-1},{0,43,3,3,0,40,3,2,0,1,-1},{0,45,3,1,0,41,4,7,1,-1,-1},
        {0,32,1,4,3,-1,0,0,1,5,32},{0,31,1,4,0,300,0,0,0,4,31},{0,33,1,4,1,-1,0,0,1,6,33}};
    memcpy(gr_data(facts),f,sizeof f);
}
static int graph_cases(void) {
    CHECK(sizeof(struct gr_plan)==136 && sizeof(struct gr_argument)==24 && sizeof(struct gr_fact)==48);
    struct gr_plan p={0};struct em_limits l;em_defaults(&l);struct em_usage u={0};struct em_failure f={1509,0};
    void* values=NULL;void* facts=NULL;void* cancel=NULL;struct gr_declarations declarations={0};struct ube_gc_root roots[11]={{0}};
    void** owners[]={&p.syntax,&p.nodes,&p.arguments,&p.procedure_roots,&p.import_marks,&p.imports,&p.cursor.frames,&values,&facts,&cancel,&declarations.targets};
    for(int i=0;i<11;++i)CHECK(ube_gc_root_enter(&roots[i],owners[i]));
    CHECK(gr_targets(&declarations.targets,503));declarations.count=503;declarations.status=1;declarations.frames=12;struct gr_target* parameters=gr_data(declarations.targets);
    parameters[100].kind=5;parameters[100].frame=5;
    const int parameter_ids[]={400,500,501,502};for(int i=0;i<4;++i){struct gr_target* parameter=&parameters[parameter_ids[i]];parameter->kind=4;parameter->type=4;parameter->representation=4;parameter->scope=i==0?300:200;parameter->flags=parameter_ids[i]==501?0:4;}
    CHECK(tr_make(&values,8,false) && gr_make(&facts,15,false));graph_fixture(values,facts);
    unsigned char original_values[8*48],original_facts[15*48];memcpy(original_values,gr_data(values),sizeof original_values);memcpy(original_facts,gr_data(facts),sizeof original_facts);
    for(int omitted=0;omitted<2;++omitted) {
        graph_fixture(values,facts);struct tr_node* n=gr_data(values);struct gr_fact* mf=gr_data(facts);
        if(omitted){n[3].first=6;n[6].next=4;n[4].next=7;mf[0].auxiliary=3;mf[5].auxiliary=0;mf[6].auxiliary=1;mf[6].flags=11;mf[7].auxiliary=2;}
        u=(struct em_usage){0};ube_err_set(77,"prior","graph");observe();
        CHECK(gr_prepare(&p,&values,8,0,&facts,15,64,&declarations,&l,&u,NULL,&f));observing=0;
        CHECK(f.code==0 && p.status==1 && p.argument_count==4 && p.argument_capacity==8 && u.work==42 && u.payload==2391 && copies==0 && ube_err_number()==77);
        CHECK(p.procedure_capacity==8 && p.procedure_count==1 && p.first_frame==5 && ((int32_t*)gr_data(p.procedure_roots))[0]==2);
        int32_t root=99;CHECK(gr_root(&p,5,&root) && root==1);
        for(int bad=-1;bad<=12;++bad)if(bad!=5){root=99;CHECK(!gr_root(&p,bad,&root) && root==99 && ube_err_number()==77);}
        int32_t saved_root=((int32_t*)gr_data(p.procedure_roots))[0];((int32_t*)gr_data(p.procedure_roots))[0]=9;root=99;CHECK(!gr_root(&p,5,&root) && root==99);((int32_t*)gr_data(p.procedure_roots))[0]=saved_root;
        struct gr_syntax* s=gr_data(p.syntax);struct gr_node* rows=gr_data(p.nodes);struct gr_argument* a=gr_data(p.arguments);
        CHECK(s[40].left==10 && s[40].right==11 && s[41].condition==12 && s[31].argument==4 && s[32].argument==3 && s[33].argument==9);
        CHECK(rows[0].scope==1 && rows[1].scope==2 && rows[3].scope==2 && rows[3].base==0 && rows[3].count==3 && rows[4].base==3 && rows[4].count==1);
        CHECK(a[0].map==6 && a[0].conversion==9 && a[0].node==7 && a[1].map==7 && a[1].conversion==0 && a[1].node==8 && a[2].map==8 && a[2].conversion==4 && a[2].node==5);
        CHECK(a[0].child==(omitted?7:5) && a[1].child==(omitted?5:7) && a[2].child==8 && a[3].node==6 && a[3].conversion==3);
        CHECK(rows[4].argument==3 && rows[5].argument==4 && rows[6].argument==1 && rows[7].argument==2 && rows[0].argument==0);
        CHECK(rows[1].temporaries==1 && a[1].temporary==1 && a[0].temporary==0 && a[2].temporary==0 && a[3].temporary==0);
        if(!omitted)CHECK(memcmp(gr_data(values),original_values,sizeof original_values)==0 && memcmp(gr_data(facts),original_facts,sizeof original_facts)==0);
        CHECK(gr_dispose(&p,&u,&f) && u.payload==0 && u.pending==0 && u.depth==0 && p.status==0);
    }
    /* Import discovery reuses node entries: typed foreign calls, globals used
       as values/addresses or destinations, deterministic first encounter,
       duplicate suppression, and no intrinsic/constant/local imports. */
    for(int variant=0;variant<6;++variant) {
        graph_fixture(values,facts);struct tr_node* n=gr_data(values);
        parameters[200].kind=6;parameters[200].source=1;parameters[300].kind=5;parameters[300].source=1;
        parameters[300].role=variant==1?1:variant==2?2:0;
        parameters[20].kind=1;parameters[21].kind=variant==3?3:2;parameters[21].source=1;parameters[21].scope=variant==4?100:20;
        n[5].kind=3;n[5].target=21;n[6].kind=variant==5?104:3;n[6].target=21;
        u=(struct em_usage){0};observe();
        CHECK(gr_prepare(&p,&values,8,0,&facts,15,64,&declarations,&l,&u,NULL,&f));observing=0;
        const int ordinary=variant!=1 && variant!=2,global=variant!=3 && variant!=4;
        CHECK(p.import_mark_count==503 && p.import_capacity==8 && p.import_count==1+ordinary+global && u.work==42 && u.payload==2391 && copies==0);
        int32_t* ids=gr_data(p.imports);unsigned char* marks=gr_data(p.import_marks);
        CHECK(ids[0]==201 && marks[200]);if(ordinary)CHECK(ids[1]==301 && marks[300]);else CHECK(!marks[300]);
        if(global)CHECK(ids[1+ordinary]==22 && marks[21]);else CHECK(!marks[21]);
        CHECK(gr_dispose(&p,&u,&f) && u.payload==0 && !p.imports && !p.import_marks && !p.import_count && !p.import_capacity && !p.import_mark_count);
    }
    parameters[200]=(struct gr_target){0};parameters[300]=(struct gr_target){0};
    for(int defect=0;defect<3;++defect) {
        graph_fixture(values,facts);struct tr_node* n=gr_data(values);n[5].kind=3;n[5].target=defect==0?-1:defect==1?503:21;
        parameters[21].kind=2;parameters[21].source=1;parameters[21].scope=503;u=(struct em_usage){0};
        CHECK(!gr_prepare(&p,&values,8,0,&facts,15,64,&declarations,&l,&u,NULL,&f) && f.code==1509 && p.status==4);
        CHECK(gr_dispose(&p,&u,&f) && u.payload==0 && !p.imports && !p.import_marks);
    }
    for(int defect=0;defect<4;++defect) {
        graph_fixture(values,facts);parameters[100].frame=defect==0?-1:defect==1?12:5;parameters[100].role=defect==2?1:0;parameters[100].kind=defect==3?2:5;u=(struct em_usage){0};
        CHECK(!gr_prepare(&p,&values,8,0,&facts,15,64,&declarations,&l,&u,NULL,&f) && f.code==1509 && p.status==4);
        CHECK(gr_dispose(&p,&u,&f) && u.payload==0 && p.procedure_roots==NULL && p.procedure_count==0 && p.procedure_capacity==0);
    }
    parameters[100].frame=5;parameters[100].role=0;parameters[100].kind=5;
    for(int frame=5;frame<=7;frame+=2) {
        graph_fixture(values,facts);graph_nodes(values)[2].kind=101;graph_nodes(values)[2].target=101;parameters[101].kind=5;parameters[101].frame=frame;u=(struct em_usage){0};
        CHECK(!gr_prepare(&p,&values,8,0,&facts,15,64,&declarations,&l,&u,NULL,&f) && f.code==1509 && p.procedure_count==1);
        CHECK(gr_dispose(&p,&u,&f) && u.payload==0 && p.procedure_roots==NULL);
    }
    graph_fixture(values,facts);graph_nodes(values)[1].kind=102;declarations.frames=0;u=(struct em_usage){0};
    CHECK(gr_prepare(&p,&values,8,0,&facts,15,64,&declarations,&l,&u,NULL,&f) && p.procedure_roots==NULL && p.procedure_count==0 && p.procedure_capacity==0 && p.first_frame==-1 && u.payload==2359);
    int32_t absent=99;CHECK(!gr_root(&p,0,&absent) && absent==99);CHECK(gr_dispose(&p,&u,&f) && u.payload==0);declarations.frames=12;
    /* Defaults use the resolved formal's mode, while forced ByRef expressions
       receive a distinct slot during the same retained map visit. */
    graph_fixture(values,facts);((struct gr_fact*)gr_data(facts))[7].flags=6;parameters[502].flags=0;
    u=(struct em_usage){0};CHECK(gr_prepare(&p,&values,8,0,&facts,15,64,&declarations,&l,&u,NULL,&f));
    struct gr_node* temporary_nodes=gr_data(p.nodes);struct gr_argument* temporary_arguments=gr_data(p.arguments);
    CHECK(temporary_nodes[1].temporaries==2 && temporary_arguments[2].temporary==1 && temporary_arguments[1].temporary==2 && u.work==42);
    CHECK(gr_dispose(&p,&u,&f) && u.payload==0);parameters[501].flags=4;
    u=(struct em_usage){0};CHECK(gr_prepare(&p,&values,8,0,&facts,15,64,&declarations,&l,&u,NULL,&f));
    temporary_nodes=gr_data(p.nodes);temporary_arguments=gr_data(p.arguments);
    CHECK(temporary_nodes[1].temporaries==1 && temporary_arguments[2].temporary==1 && temporary_arguments[1].temporary==0 && u.work==42);
    CHECK(gr_dispose(&p,&u,&f) && u.payload==0);parameters[501].flags=0;parameters[502].flags=4;
    for(int defect=0;defect<6;++defect) {
        graph_fixture(values,facts);struct gr_fact* mf=gr_data(facts);
        if(defect==0)mf[7].auxiliary=1;if(defect==1)mf[8].target=999;if(defect==2)mf[0].right=2;if(defect==3)mf[9].target=64;if(defect==4)mf[8].syntax=32;if(defect==5)mf[14].auxiliary=4;
        u=(struct em_usage){0};CHECK(!gr_prepare(&p,&values,8,0,&facts,15,64,&declarations,&l,&u,NULL,&f) && f.code==1509 && p.status==4);
        CHECK(gr_dispose(&p,&u,&f) && u.payload==0 && u.pending==0 && u.depth==0);
    }
    graph_fixture(values,facts);
    for(int category=0;category<3;++category)for(int delta=-1;delta<=1;++delta) {
        em_defaults(&l);int64_t* cap=category==0?&l.payload:category==1?&l.work:&l.depth;*cap=(category==0?2391:category==1?42:6)+delta;
        u=(struct em_usage){0};int ok=gr_prepare(&p,&values,8,0,&facts,15,64,&declarations,&l,&u,NULL,&f);
        if(delta<0)CHECK(!ok && f.code==1502 && f.resource==(category==0?1:category==1?5:6));else CHECK(ok && f.code==0);
        CHECK(gr_dispose(&p,&u,&f) && u.payload==0 && u.pending==0 && u.depth==0);
    }
    em_defaults(&l);u=(struct em_usage){0};ube_gc_test_fail_next_allocations(1000000);
    CHECK(!gr_prepare(&p,&values,8,0,&facts,15,64,&declarations,&l,&u,NULL,&f) && f.code==1502 && f.resource==1 && u.payload==0);
    ube_gc_test_fail_next_allocations(0);CHECK(gr_dispose(&p,&u,&f));
    CHECK(em_cancel_make(&cancel));em_cancel(cancel);u=(struct em_usage){0};observe();
    CHECK(!gr_prepare(&p,&values,8,0,&facts,15,64,&declarations,&l,&u,cancel,&f) && f.code==1507 && u.payload==0 && clean_cost());CHECK(gr_dispose(&p,&u,&f));
    /* Calls without arguments do not reserve an argument arena or invent a
       parameter map. Unreachable former children are not visited. */
    graph_fixture(values,facts);struct tr_node* n=gr_data(values);struct gr_fact* mf=gr_data(facts);
    n[3].children=0;n[3].first=-1;mf[0].right=0;mf[0].left=-1;mf[0].auxiliary=0;u=(struct em_usage){0};
    CHECK(gr_prepare(&p,&values,8,0,&facts,15,64,&declarations,&l,&u,NULL,&f) && p.argument_count==0 && p.argument_capacity==0 && p.arguments==NULL && u.work==26);
    CHECK(gr_dispose(&p,&u,&f) && u.payload==0);
    graph_fixture(values,facts);
    size_t available=UBE_GC_MAX_ROOTS-ube_gc_root_count;struct ube_gc_root* pressure=calloc(available,sizeof(*pressure));void* neutral=NULL;CHECK(pressure!=NULL);
    for(size_t i=0;i<available;++i)CHECK(ube_gc_root_enter(&pressure[i],&neutral));
    int successes=0,failures=0;
    for(size_t spare=0;spare<=64;++spare) {
        u=(struct em_usage){0};f=(struct em_failure){1509,0};int ok=gr_prepare(&p,&values,8,0,&facts,15,64,&declarations,&l,&u,NULL,&f);
        CHECK((ok && f.code==0 && p.status==1 && p.argument_count==4) || (!ok && f.code!=0));if(ok)++successes;else++failures;
        CHECK(u.pending==p.cursor.count && u.depth==p.cursor.count && u.payload==20*p.syntax_count+20*p.node_count+24*p.argument_capacity+24*p.cursor.capacity+4*p.procedure_capacity+p.import_mark_count+4*p.import_capacity && ube_gc_root_count==UBE_GC_MAX_ROOTS-spare);
        for(size_t i=0;i<128;++i)CHECK(ube_gc_root_leave(&pressure[available-spare-1-i]));
        CHECK(gr_dispose(&p,&u,&f) && u.payload==0 && u.pending==0 && u.depth==0 && p.status==0);
        for(size_t i=0;i<128;++i)CHECK(ube_gc_root_enter(&pressure[available-spare-1-i],&neutral));
        if(spare<64)CHECK(ube_gc_root_leave(&pressure[available-spare-1]));
    }
    CHECK(successes>0 && failures>0);for(size_t i=0;i<available-64;++i)CHECK(ube_gc_root_leave(&pressure[i]));free(pressure);
    CHECK(tr_make(&values,0,false) && gr_make(&facts,0,false));for(int i=10;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));
    CHECK(ube_gc_collect() && ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);return 0;
}
