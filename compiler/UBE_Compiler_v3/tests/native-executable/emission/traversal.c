/* Included after the independent native runtime/cost observer declarations. */
struct tr_node {int32_t source,syntax,kind,type;int64_t value;int32_t target,first,next,children,flags,auxiliary;};
struct tr_cursor {void* frames;int32_t capacity,count,status,pending,ordinal;};
struct tr_event {int32_t kind,node,parent,ordinal,depth;};
extern int32_t tr_make(void**,int32_t,bool);
extern int32_t tr_begin(struct tr_cursor*,void**,int32_t,int32_t,struct em_limits*,struct em_usage*,void*,struct em_failure*);
extern int32_t tr_next(struct tr_cursor*,void**,int32_t,struct em_limits*,struct em_usage*,void*,struct tr_event*,struct em_failure*);
extern int32_t tr_skip(struct tr_cursor*);
extern int32_t tr_dispose(struct tr_cursor*,struct em_usage*,struct em_failure*);

static struct tr_node* graph_nodes(void* owner) {return (struct tr_node*)((struct ube_array*)owner)->data;}
static void graph_shape(void* owner,int n,int chain) {
    struct tr_node* p=graph_nodes(owner);
    for(int i=0;i<n;++i){p[i]=(struct tr_node){0};p[i].source=11;p[i].syntax=100+i;p[i].kind=102;p[i].first=-1;p[i].next=-1;}
    if(chain)for(int i=0;i<n-1;++i){p[i].first=i+1;p[i].children=1;}
    else if(n>1){p[0].first=1;p[0].children=n-1;for(int i=1;i<n-1;++i)p[i].next=i+1;}
}
static int traversal_cases(void) {
    CHECK(sizeof(struct tr_node)==48 && sizeof(struct tr_cursor)==32 && sizeof(struct tr_event)==20);
    struct tr_cursor s={0};struct em_limits l;em_defaults(&l);struct em_usage u={0};struct em_failure f={1509,0};
    struct tr_event e={0};void* graph=NULL;void* cancel=NULL;struct ube_gc_root roots[3]={{0}};
    CHECK(ube_gc_root_enter(&roots[0],&s.frames) && ube_gc_root_enter(&roots[1],&graph) && ube_gc_root_enter(&roots[2],&cancel));
    CHECK(tr_make(&graph,6,false));graph_shape(graph,6,0);struct tr_node* p=graph_nodes(graph);
    p[0].first=1;p[0].children=2;p[1].next=4;p[1].first=2;p[1].children=2;
    p[2].next=3;p[3].next=-1;p[4].next=-1;p[4].first=5;p[4].children=1;p[5].next=-1;
    struct tr_node original[6];memcpy(original,p,sizeof original);
    const struct tr_event expected[]={
        {1,0,-1,-1,1},{2,1,0,0,1},{1,1,0,0,2},{2,2,1,0,2},{1,2,1,0,3},{3,2,1,0,3},
        {2,3,1,1,2},{1,3,1,1,3},{3,3,1,1,3},{3,1,0,0,2},
        {2,4,0,1,1},{1,4,0,1,2},{2,5,4,0,2},{1,5,4,0,3},{3,5,4,0,3},{3,4,0,1,2},{3,0,-1,-1,1}};
    for(int pass=0;pass<2;++pass) {
        ube_err_set(77,"prior","traversal");observe();
        CHECK(tr_begin(&s,&graph,6,0,&l,&u,NULL,&f));
        for(size_t i=0;i<sizeof expected/sizeof expected[0];++i) {
            CHECK(tr_next(&s,&graph,6,&l,&u,NULL,&e,&f) && f.code==0 && memcmp(&e,&expected[i],sizeof e)==0);
            CHECK(u.pending==s.count && u.depth==s.count);
        }
        CHECK(tr_next(&s,&graph,6,&l,&u,NULL,&e,&f) && e.kind==0 && e.node==0 && e.depth==0);
        CHECK(tr_next(&s,&graph,6,&l,&u,NULL,&e,&f) && e.kind==0);
        observing=0;CHECK(copies==0 && (pass==0 || allocations==0));
        CHECK(u.work==17*(pass+1) && u.pending==0 && u.depth==0 && u.peak_depth==3 && u.peak_pending==3);
        CHECK(u.payload==192 && s.capacity==8 && ube_err_number()==77 && memcmp(graph_nodes(graph),original,sizeof original)==0);
    }
    CHECK(tr_dispose(&s,&u,&f) && u.payload==0 && s.frames==NULL);
    /* Skip only an announced edge. Remaining siblings and parent exit keep
       their original identities, and deferred subtrees consume no frames. */
    for(int all=0;all<2;++all) {
        u=(struct em_usage){0};CHECK(!tr_skip(&s));CHECK(tr_begin(&s,&graph,6,0,&l,&u,NULL,&f));
        CHECK(!tr_skip(&s));int events=0;
        do {CHECK(tr_next(&s,&graph,6,&l,&u,NULL,&e,&f));if(!e.kind)break;++events;
            if(e.kind==2 && e.parent==0 && (all || e.node==1)){struct em_usage before=u;observe();CHECK(tr_skip(&s) && !tr_skip(&s) && clean_cost() && memcmp(&before,&u,sizeof u)==0);}
            if(e.kind==1 || e.kind==3)CHECK(e.node==0 || (!all && (e.node==4 || e.node==5)));
        } while(e.kind);
        CHECK(events==(all?4:9) && u.work==events && u.peak_depth==(all?1:3) && u.pending==0 && u.depth==0 && !tr_skip(&s));
        CHECK(memcmp(graph_nodes(graph),original,sizeof original)==0 && ube_err_number()==77);CHECK(tr_dispose(&s,&u,&f) && u.payload==0);
    }
    /* Width costs work, not live depth. Deep chains grow geometrically and
       retain no source payload copies: the only observed copies are frames. */
    for(int chain=0;chain<2;++chain) {
        u=(struct em_usage){0};int n=chain?33:70;CHECK(tr_make(&graph,n,false));graph_shape(graph,n,chain);observe();
        CHECK(tr_begin(&s,&graph,n,0,&l,&u,NULL,&f));int count=0;
        do{CHECK(tr_next(&s,&graph,n,&l,&u,NULL,&e,&f));if(e.kind)++count;}while(e.kind);
        observing=0;CHECK(count==3*n-1 && u.work==3*n-1 && u.peak_depth==(chain?n:2) && u.peak_pending==u.peak_depth);
        CHECK(s.capacity==(chain?64:8) && copies==(chain?24*(8+16+32):0));
        CHECK(u.payload==24*s.capacity && u.peak_payload==(chain?24*(32+64):192));
        CHECK(tr_dispose(&s,&u,&f) && u.payload==0 && u.pending==0 && u.depth==0);
    }
    /* Every independent limit, below/exact/above the six-node walk. */
    CHECK(tr_make(&graph,6,false));memcpy(graph_nodes(graph),original,sizeof original);
    for(int category=0;category<4;++category)for(int delta=-1;delta<=1;++delta) {
        em_defaults(&l);u=(struct em_usage){0};int64_t* cap=category==0?&l.payload:category==1?&l.pending:category==2?&l.depth:&l.work;
        *cap=(category==0?192:category==3?17:3)+delta;int ok=tr_begin(&s,&graph,6,0,&l,&u,NULL,&f);int events=0;
        while(ok){e=(struct tr_event){71,72,73,74,75};struct tr_event before=e;f=(struct em_failure){1509,0};ok=tr_next(&s,&graph,6,&l,&u,NULL,&e,&f);if(!ok){CHECK(memcmp(&e,&before,sizeof e)==0);break;}if(!e.kind)break;++events;}
        if(delta<0)CHECK(!ok && f.code==1502 && f.resource==(category==0?1:category==1?4:category==2?6:5));
        else CHECK(ok && events==17);
        CHECK(u.pending==s.count && u.depth==s.count && u.payload==24*s.capacity);
        CHECK(tr_dispose(&s,&u,&f) && u.payload==0 && u.pending==0 && u.depth==0);
    }
    em_defaults(&l);u=(struct em_usage){0};u.pending=5;u.depth=7;u.payload=101;
    CHECK(tr_begin(&s,&graph,6,0,&l,&u,NULL,&f));CHECK(tr_dispose(&s,&u,&f) && u.pending==5 && u.depth==7 && u.payload==101);
    /* Allocation denial at first reserve and at a later growth keeps existing
       scratch owned and accurately charged until explicit cleanup. */
    for(int grow=0;grow<2;++grow) {
        u=(struct em_usage){0};CHECK(tr_make(&graph,33,false));graph_shape(graph,33,1);
        if(grow){CHECK(tr_begin(&s,&graph,33,0,&l,&u,NULL,&f));while(s.count<8)CHECK(tr_next(&s,&graph,33,&l,&u,NULL,&e,&f));}
        ube_gc_test_fail_next_allocations(1000000);f=(struct em_failure){1509,0};int ok;
        if(grow){do{ok=tr_next(&s,&graph,33,&l,&u,NULL,&e,&f);}while(ok);}else ok=tr_begin(&s,&graph,33,0,&l,&u,NULL,&f);
        ube_gc_test_fail_next_allocations(0);CHECK(!ok && f.code==1502 && f.resource==1 && u.payload==24*s.capacity && u.pending==s.count && u.depth==s.count);
        CHECK(tr_dispose(&s,&u,&f) && u.payload==0 && u.pending==0 && u.depth==0);
    }
    /* A malformed child chain or child count reports internal failure. */
    for(int defect=0;defect<4;++defect) {
        u=(struct em_usage){0};CHECK(tr_make(&graph,6,false));memcpy(graph_nodes(graph),original,sizeof original);p=graph_nodes(graph);
        if(defect==0)p[0].first=6;if(defect==1)p[0].children=1;if(defect==2)p[0].children=3;if(defect==3)p[0].children=-1;
        int ok=tr_begin(&s,&graph,6,0,&l,&u,NULL,&f);int steps=0;while(ok && steps++<30){ok=tr_next(&s,&graph,6,&l,&u,NULL,&e,&f);if(ok && !e.kind)break;}
        CHECK(!ok && f.code==1509 && steps<30);CHECK(tr_dispose(&s,&u,&f) && u.pending==0 && u.depth==0 && u.payload==0);
    }
    /* Cancel within the counted-event interval, with no allocation at the
       observation point. Cleanup also succeeds while cancellation is set. */
    u=(struct em_usage){0};CHECK(tr_make(&graph,2000,false));graph_shape(graph,2000,0);CHECK(em_cancel_make(&cancel));
    CHECK(tr_begin(&s,&graph,2000,0,&l,&u,cancel,&f) && tr_next(&s,&graph,2000,&l,&u,cancel,&e,&f));em_cancel(cancel);observe();
    int ok;do{ok=tr_next(&s,&graph,2000,&l,&u,cancel,&e,&f);}while(ok && e.kind);
    CHECK(!ok && f.code==1507 && u.work==4096 && clean_cost());CHECK(tr_dispose(&s,&u,&f) && u.payload==0 && u.pending==0 && u.depth==0);
    CHECK(!tr_begin(&s,&graph,2000,0,&l,&u,cancel,&f) && f.code==1507 && tr_dispose(&s,&u,&f));
    /* Invalid edge immediately after a successful cancellation poll must not
       return False with that poll's success diagnostic. */
    u=(struct em_usage){0};graph_shape(graph,2000,0);p=graph_nodes(graph);p[1365].next=2000;
    CHECK(tr_begin(&s,&graph,2000,0,&l,&u,NULL,&f));
    do{ok=tr_next(&s,&graph,2000,&l,&u,NULL,&e,&f);}while(ok && e.kind);
    CHECK(!ok && u.work==4096 && f.code==1509 && tr_dispose(&s,&u,&f));
    /* Repeated reachable occurrences are not hidden by a unique-node set. */
    u=(struct em_usage){0};CHECK(tr_make(&graph,4,false));graph_shape(graph,4,0);p=graph_nodes(graph);
    p[0].children=2;p[1].next=3;p[1].first=2;p[1].children=1;p[2].next=-1;p[3].first=2;p[3].children=1;
    CHECK(tr_begin(&s,&graph,4,0,&l,&u,NULL,&f));int repeated=0,events=0;
    do{CHECK(tr_next(&s,&graph,4,&l,&u,NULL,&e,&f));if(e.kind)++events;if(e.kind==1 && e.node==2)++repeated;}while(e.kind);
    CHECK(repeated==2 && events==14 && u.work==14 && tr_dispose(&s,&u,&f));
    /* A subtree walk ignores the selected root's external sibling. */
    u=(struct em_usage){0};CHECK(tr_begin(&s,&graph,4,1,&l,&u,NULL,&f));events=0;
    do{CHECK(tr_next(&s,&graph,4,&l,&u,NULL,&e,&f));if(e.kind)++events;CHECK(e.kind==0 || e.node==1 || e.node==2);}while(e.kind);
    CHECK(events==5 && u.work==5 && tr_dispose(&s,&u,&f));
    /* A cyclic malformed graph reaches a configured boundary, never native
       recursion. Invalid root/length domains never access an array element. */
    p[0].first=0;p[0].children=1;u=(struct em_usage){0};l.depth=3;CHECK(tr_begin(&s,&graph,4,0,&l,&u,NULL,&f));events=0;
    do{ok=tr_next(&s,&graph,4,&l,&u,NULL,&e,&f);++events;}while(ok && events<20);
    CHECK(!ok && events<20 && f.code==1502 && f.resource==6 && u.depth==3 && tr_dispose(&s,&u,&f));em_defaults(&l);
    const int32_t invalid[][2]={{0,0},{5,0},{4,-1},{4,4}};
    for(size_t i=0;i<sizeof invalid/sizeof invalid[0];++i){CHECK(!tr_begin(&s,&graph,invalid[i][0],invalid[i][1],&l,&u,NULL,&f) && f.code==1509 && tr_dispose(&s,&u,&f));}
    CHECK(tr_make(&graph,33,false));graph_shape(graph,33,1);
    size_t available=UBE_GC_MAX_ROOTS-ube_gc_root_count;
    struct ube_gc_root* pressure=calloc(available,sizeof(*pressure));void* neutral=NULL;CHECK(pressure!=NULL);
    for(size_t i=0;i<available;++i)CHECK(ube_gc_root_enter(&pressure[i],&neutral));
    int successes=0,failures=0;
    for(size_t spare=0;spare<=32;++spare) {
        u=(struct em_usage){0};f=(struct em_failure){1509,0};ok=tr_begin(&s,&graph,33,0,&l,&u,NULL,&f);events=0;
        while(ok && events<100){f=(struct em_failure){1509,0};ok=tr_next(&s,&graph,33,&l,&u,NULL,&e,&f);if(ok && !e.kind)break;++events;}
        CHECK((ok && f.code==0 && events==98) || (!ok && f.code!=0));if(ok)++successes;else++failures;
        CHECK(u.pending==s.count && u.depth==s.count && u.payload==24*s.capacity && ube_gc_root_count==UBE_GC_MAX_ROOTS-spare);
        for(size_t i=0;i<128;++i)CHECK(ube_gc_root_leave(&pressure[available-spare-1-i]));
        CHECK(tr_dispose(&s,&u,&f) && u.payload==0 && u.pending==0 && u.depth==0);
        for(size_t i=0;i<128;++i)CHECK(ube_gc_root_enter(&pressure[available-spare-1-i],&neutral));
        if(spare<32)CHECK(ube_gc_root_leave(&pressure[available-spare-1]));
    }
    CHECK(successes>0 && failures>0);for(size_t i=0;i<available-32;++i)CHECK(ube_gc_root_leave(&pressure[i]));free(pressure);
    CHECK(tr_make(&graph,0,false));for(int i=2;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));
    CHECK(ube_gc_collect() && ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);return 0;
}
