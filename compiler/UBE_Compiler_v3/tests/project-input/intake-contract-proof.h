/* Finite independent metadata, request-domain and native-completion oracles. */
static const char contract_root_bytes[]=
    "\xEF\xBB\xBF' package metadata\r\nUBE-Project 1\r\nName = \"[\xC3\x85pp]\"\r\n"
    "Kind = \"Exe\"\r\nStartup = \"Main\"\r\nSource = \"src/Main.bas\"\r\n"
    "Source = \"src/Helper.bas\"\r\nReference = \"../core/UBECore.UBE\"\r\n"
    "Optimization = \"3\"\r\nDebugInformation = \"Line\"\r\n";
static const char contract_core_bytes[]="UBE-Project 1\nName = \"UBECore\"\nKind = \"Library\"\nSource = \"Core.bas\"\n";
static const char contract_main_bytes[]="UBE SOURCE 1 MODULE\nAttribute UBE_Name = \"Main\"\nFunction Main() As Long\n    Main = (0)\nEnd Function\n";
static const char contract_helper_bytes[]="UBE SOURCE 1 MODULE\nAttribute UBE_Name = \"Helper\"\nFunction Value() As Long\n    Value = 7\nEnd Function\n";
static const char contract_core_source_bytes[]="UBE SOURCE 1 MODULE\nAttribute UBE_Name = \"CoreValue\"\nFunction CoreValue() As Long\n    CoreValue = 1\nEnd Function\n";
static const struct manifest contract_root_metadata={45,53,1,63,66,80,84,3,1,NULL,2,NULL,1,0,0,0};
static const struct manifest contract_core_metadata={21,30,2,39,46,0,0,2,2,NULL,1,NULL,0,0,0,0};
static const struct declaration contract_root_sources[]={{87,93,97,109},{112,118,122,136}};
static const struct declaration contract_root_references[]={{139,148,152,171}};
static const struct declaration contract_core_sources[]={{48,54,58,66}};
static int contract_declarations_match(void* actual,const struct declaration* expected,int logical,int capacity){
    if(ube_value_array_length(&actual)!=capacity)return 0;
    const struct declaration zero={0};
    for(int i=0;i<capacity;++i)if(memcmp(ube_array_element(actual,i),i<logical?&expected[i]:&zero,sizeof(zero)))return 0;
    return 1;
}
static int contract_metadata_match(const struct manifest* actual,const struct manifest* expected,const struct declaration* sources,const struct declaration* references){
    return actual->name_first==expected->name_first&&actual->name_last==expected->name_last&&
        actual->kind==expected->kind&&actual->kind_first==expected->kind_first&&actual->kind_last==expected->kind_last&&
        actual->startup_first==expected->startup_first&&actual->startup_last==expected->startup_last&&
        actual->optimization==expected->optimization&&actual->debug==expected->debug&&
        actual->source_count==expected->source_count&&actual->reference_count==expected->reference_count&&
        actual->unsupported==expected->unsupported&&actual->unsupported_first==expected->unsupported_first&&actual->unsupported_last==expected->unsupported_last&&
        contract_declarations_match(actual->sources,sources,expected->source_count,256)&&
        contract_declarations_match(actual->references,references,expected->reference_count,2);
}
static int contract_path_bytes(void){
    return (int)(3*strlen(INTAKE_CONTRACT_MANIFEST)+strlen(INTAKE_WORKING_DIRECTORY)+
        3*strlen(INTAKE_CONTRACT_APP_DIRECTORY)+2*strlen(INTAKE_CONTRACT_CORE_MANIFEST)+
        2*strlen(INTAKE_CONTRACT_CORE_DIRECTORY)+162);
}
static int contract_totals_match(const struct input* input,int paths,int metadata){
    return input->source_bytes==315&&input->path_bytes==paths&&input->metadata_bytes==metadata;
}
static int contract_graph(struct syntax* value){
    CHECK(check_graph(value));
    struct input* input=value->input;
    CHECK(bytes_text(input->directory,INTAKE_WORKING_DIRECTORY));
    CHECK(bytes_text(input->invocation,INTAKE_CONTRACT_MANIFEST));
    CHECK(contract_totals_match(input,contract_path_bytes(),contract_path_bytes()+289));
    struct package* root=*(struct package**)ube_array_element(input->packages,0);
    struct package* core=*(struct package**)ube_array_element(input->packages,1);
    CHECK(bytes_text(root->document.bytes,contract_root_bytes)&&root->document.content==3&&root->document.scalars==217&&root->document.lines==11);
    CHECK(bytes_text(core->document.bytes,contract_core_bytes)&&core->document.content==0&&core->document.scalars==68&&core->document.lines==5);
    CHECK(contract_metadata_match(&root->metadata,&contract_root_metadata,contract_root_sources,contract_root_references));
    CHECK(contract_metadata_match(&core->metadata,&contract_core_metadata,contract_core_sources,NULL));
    CHECK(root->first==0&&root->last==0&&core->first==152&&core->last==171);
    CHECK(bytes_text(root->declared,INTAKE_CONTRACT_MANIFEST)&&bytes_text(root->resolved,INTAKE_CONTRACT_MANIFEST)&&bytes_text(root->directory,INTAKE_CONTRACT_APP_DIRECTORY));
    CHECK(bytes_text(core->declared,"../core/UBECore.UBE")&&bytes_text(core->resolved,INTAKE_CONTRACT_CORE_MANIFEST)&&bytes_text(core->directory,INTAKE_CONTRACT_CORE_DIRECTORY));
    CHECK(ube_value_array_length(&root->references)==1&&ube_value_array_length(&core->references)==0);
    struct path* reference=ube_array_element(root->references,0);
    CHECK(reference->first==152&&reference->last==171&&reference->parents==1);
    CHECK(bytes_text(reference->declared,"../core/UBECore.UBE")&&bytes_text(reference->normalized,"../core/UBECore.UBE")&&bytes_text(reference->resolved,INTAKE_CONTRACT_CORE_MANIFEST));
    const char* documents[]={contract_main_bytes,contract_helper_bytes,contract_core_source_bytes};
    const char* resolved[]={INTAKE_CONTRACT_MAIN,INTAKE_CONTRACT_HELPER,INTAKE_CONTRACT_CORE_SOURCE};
    const int first[]={97,122,58},last[]={109,136,66},identity_last[]={47,49,52};
    for(int i=0;i<3;++i){
        struct source* source=*(struct source**)ube_array_element(input->sources,i);
        CHECK(source->path.first==first[i]&&source->path.last==last[i]&&source->envelope.first==41&&source->envelope.last==identity_last[i]);
        CHECK(bytes_text(source->path.resolved,resolved[i]));
        CHECK(bytes_text(source->owner->document.bytes,documents[i]));
        CHECK(source->owner->document.content==0&&source->owner->document.scalars==(int32_t)strlen(documents[i])&&source->owner->document.lines==6);
    }
    struct manifest changed=contract_root_metadata;changed.debug=0;
    CHECK(!contract_metadata_match(&root->metadata,&changed,contract_root_sources,contract_root_references));
    struct declaration changed_sources[2];memcpy(changed_sources,contract_root_sources,sizeof(changed_sources));changed_sources[1].value_last++;
    CHECK(!contract_metadata_match(&root->metadata,&contract_root_metadata,changed_sources,contract_root_references));
    CHECK(!contract_totals_match(input,contract_path_bytes()+1,contract_path_bytes()+289));
    return 1;
}
struct contract_failure {const char* name;int32_t package,source,location,first,last,input,file,unit;};
static const struct contract_failure contract_failures[]={
    {"duplicate-normalized-source",0,-1,1,91,105,0,0,0},
    {"source-hard-link",0,1,1,91,104,0,0,0},
    {"identical-bytes-distinct-file",0,1,2,41,47,0,0,0},
    {"folded-source-name",0,1,2,41,49,0,0,0},
    {"unicode-folded-source-name",0,1,2,41,45,0,0,0},
    {"self-reference",0,-1,1,94,102,0,0,0},
    {"duplicate-reference",0,-1,1,128,149,0,0,0},
    {"ancestor-cycle",1,-1,1,81,97,0,0,0},
    {"package-collision",1,-1,1,21,28,0,0,0},
    {"source-missing",0,0,2,0,0,6,3,0},
    {"worker-scanner-failure",0,1,2,97,98,0,0,201}
};
static int contract_failure_match(const struct failure* actual,const struct contract_failure* expected){
    if(actual->package!=expected->package||actual->source!=expected->source||actual->location!=expected->location||actual->first!=expected->first||actual->last!=expected->last||actual->input.kind!=expected->input||actual->file!=expected->file||actual->unit.kind!=expected->unit||!actual->context)return 0;
    if(expected->input&&(actual->input.position.byte||actual->input.position.scalar||actual->input.position.line!=1||actual->input.position.column!=1))return 0;
    return !expected->unit||(actual->unit.first==expected->first&&actual->unit.last==expected->last);
}
static int contract_rejections(void** path,void* cancel,void** published,void* baseline,struct failure* failure){
    const int jobs[]={1,2,4};
    for(size_t oi=0;oi<sizeof(contract_failures)/sizeof(contract_failures[0]);++oi){
        const struct contract_failure* expected=&contract_failures[oi];const struct intake_case* test=NULL;
        for(size_t ci=0;ci<sizeof(intake_cases)/sizeof(intake_cases[0]);++ci)if(!strcmp(intake_cases[ci].name,expected->name)){test=&intake_cases[ci];break;}
        CHECK(test&&set_path(path,test->path));
        for(int j=0;j<3;++j){
            struct limits limits={0};intake_limits(&limits);int32_t token=0;seed_failure(failure);
            CHECK(!intake_parse(path,&limits,jobs[j],cancel,published,failure,&token));
            CHECK(failure->kind==test->kind&&failure->code==test->code&&contract_failure_match(failure,expected));
            struct contract_failure changed=*expected;changed.last++;
            CHECK(!contract_failure_match(failure,&changed));
            CHECK(token==0&&*published==baseline&&drained()&&contract_graph(baseline));
        }
    }
    return 1;
}
static int contract_invalid_requests(void** path,void* cancel,void** published,void* baseline,struct failure* failure){
    const int32_t maxima[]={1048576,2,256,16777216,67108864,131068,4194304,8388608,1048576,1048576,1048576,256};
    CHECK(set_path(path,INTAKE_CONTRACT_MANIFEST));
    for(int field=0;field<12;++field)for(int side=0;side<2;++side){
        struct limits limits={0};intake_limits(&limits);int32_t words[12];memcpy(words,&limits,sizeof(words));
        words[field]=side?maxima[field]+1:-1;memcpy(&limits,words,sizeof(words));
        int32_t token=0;unsigned entered=atomic_load(&intake_worker_entries);seed_failure(failure);
        CHECK(!intake_parse(path,&limits,4,cancel,published,failure,&token));
        CHECK(failure->kind==1&&failure->code==1320&&failure->package==-1&&failure->source==-1&&failure->context==NULL);
        CHECK(token==0&&*published==baseline&&atomic_load(&intake_worker_entries)==entered&&drained()&&contract_graph(baseline));
    }
    for(int jobs=0;jobs<=5;jobs+=5){
        struct limits limits={0};intake_limits(&limits);int32_t token=0;seed_failure(failure);
        unsigned entered=atomic_load(&intake_worker_entries);
        CHECK(!intake_parse(path,&limits,jobs,cancel,published,failure,&token));
        CHECK(failure->kind==1&&failure->code==1320&&failure->context==NULL&&token==0&&*published==baseline);
        CHECK(atomic_load(&intake_worker_entries)==entered&&drained()&&contract_graph(baseline));
    }
    const int jobs[]={1,2,4};
    for(int field=0;field<4;++field)for(int j=0;j<3;++j){
        struct limits limits={0};intake_limits(&limits);
        if(field==0)limits.total_path=0;if(field==1)limits.nodes=0;if(field==2)limits.pending=0;if(field==3)limits.depth=0;
        int32_t token=0;seed_failure(failure);unsigned entered=atomic_load(&intake_worker_entries);
        int32_t ok=intake_parse(path,&limits,jobs[j],cancel,published,failure,&token);
        if(ok)fprintf(stderr,"zero budget field %d jobs %d unexpectedly accepted\n",field,jobs[j]);
        CHECK(!ok);
        if(field==0){CHECK(failure->kind==2&&failure->code==1309&&atomic_load(&intake_worker_entries)==entered);}
        else{CHECK(failure->kind==7&&failure->code==0&&failure->source==0&&failure->unit.kind==2);}
        CHECK(token==0&&*published==baseline&&drained()&&contract_graph(baseline));
    }
    for(int j=0;j<3;++j)for(int boundary=0;boundary<3;++boundary){
        struct limits limits={0};intake_limits(&limits);
        limits.total_path=contract_path_bytes();limits.metadata=contract_path_bytes()+289;
        if(boundary==1)--limits.total_path;if(boundary==2)--limits.metadata;
        int32_t token=0;seed_failure(failure);unsigned entered=atomic_load(&intake_worker_entries);
        int32_t ok=intake_parse(path,&limits,jobs[j],cancel,published,failure,&token);
        CHECK(ok==(boundary==0)&&token==0&&drained());
        if(!boundary){CHECK(failure->kind==0&&contract_graph(*published)&&compare_graphs(baseline,*published));*published=baseline;}
        else{CHECK(failure->kind==2&&failure->code==1309&&failure->package==1&&failure->source==-1&&failure->location==1&&failure->first==58&&failure->last==66&&atomic_load(&intake_worker_entries)==entered);}
        CHECK(*published==baseline&&contract_graph(baseline));
    }
    return 1;
}
static int contract_schedules(void** path,void* cancel,void** published,void* baseline,struct failure* failure){
    const int jobs[]={1,2,4};
    const struct contract_failure first={"first parser body",0,0,2,67,75,0,0,104};
    for(int rejected=0;rejected<2;++rejected)for(int j=0;j<3;++j)for(int repeat=0;repeat<2;++repeat){
        CHECK(set_path(path,rejected?INTAKE_CONTRACT_REJECTED:INTAKE_CONTRACT_MANIFEST));
        struct limits limits={0};intake_limits(&limits);int32_t token=0;seed_failure(failure);
        intake_reverse_begin(rejected?2:3,jobs[j]);
        int32_t ok=intake_parse(path,&limits,jobs[j],cancel,published,failure,&token);
        atomic_store(&intake_schedule_enabled,0);
        CHECK(intake_reverse_matches(intake_schedule_order,intake_schedule_target));
        int changed[3];memcpy(changed,intake_schedule_order,sizeof(changed));changed[0]=3;
        CHECK(!intake_reverse_matches(changed,intake_schedule_target));
        CHECK(ok==!rejected&&token==0&&drained());
        if(rejected){CHECK(failure->kind==7&&failure->code==0&&contract_failure_match(failure,&first)&&*published==baseline);}
        else{CHECK(failure->kind==0&&contract_graph(*published)&&compare_graphs(baseline,*published));*published=baseline;}
        CHECK(contract_graph(baseline));
    }
    return 1;
}
static int run_contract_proof(void){
    (void)run;
    void *path=NULL,*cancel=NULL,*published=NULL,*baseline=NULL;struct failure failure={0};
    struct ube_gc_root roots[5]={{0}};
    CHECK(ube_gc_root_enter(&roots[0],&path)&&ube_gc_root_enter(&roots[1],&cancel)&&ube_gc_root_enter(&roots[2],&published)&&ube_gc_root_enter(&roots[3],&baseline)&&ube_gc_root_enter(&roots[4],(void**)&failure.context));
    CHECK(intake_size(8)==sizeof(struct limits)&&intake_size(9)==sizeof(struct failure));
    CHECK(ube_value_new_object(&cancel,intake_class(0))&&set_path(&path,INTAKE_CONTRACT_MANIFEST));
    struct limits limits={0};intake_limits(&limits);int32_t token=0;seed_failure(&failure);
    CHECK(intake_parse(&path,&limits,1,cancel,&published,&failure,&token)&&!token&&failure.kind==0);
    baseline=published;CHECK(contract_graph(baseline));
    CHECK(contract_rejections(&path,cancel,&published,baseline,&failure));
    CHECK(contract_invalid_requests(&path,cancel,&published,baseline,&failure));
    CHECK(contract_schedules(&path,cancel,&published,baseline,&failure));
    for(int i=4;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));
    ube_release_strings();ube_gc_collect();
    CHECK(ube_gc_root_count==0&&ube_gc_live_allocation_bytes()==0&&ube_string_allocations==NULL&&drained());
    printf("PASS project contract metadata:2 failures:11 invalid:26 zero:12 boundaries:9 schedules:12 negative-controls:5 assertions:%u\n",assertions);
    return 1;
}
