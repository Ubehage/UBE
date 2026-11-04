struct leaf {void* marks;void* pending;int32_t mark_capacity,pending_capacity,first,code_bytes,instructions,status;};
struct leaf_env {struct leaf value;struct inspection_storage storage;struct native_limits limits;struct native_usage usage;struct ube_gc_root roots[2];};
extern int32_t inspect_leaf(struct leaf*,void**,int32_t,int32_t,struct inspection*,struct inspection_storage*,struct native_limits*,struct native_usage*,void*,struct failure*);
extern int32_t dispose_leaf(struct leaf*,struct inspection_storage*,struct native_usage*,struct failure*);
static int leaf_open(struct leaf_env* e){memset(e,0,sizeof *e);inventory_storage_defaults(&e->storage);native_limits_defaults(&e->limits);CHECK(ube_gc_root_enter(&e->roots[0],&e->value.marks) && ube_gc_root_enter(&e->roots[1],&e->value.pending));return 0;}
static int leaf_close(struct leaf_env* e){struct failure f;CHECK(dispose_leaf(&e->value,&e->storage,&e->usage,&f) && f.code==0 && e->storage.payload==0 && e->usage.payload==0 && !e->value.marks && !e->value.pending && e->value.status==0);for(int i=1;i>=0;--i)CHECK(ube_gc_root_leave(&e->roots[i]));(void)ube_gc_collect();return 0;}
struct leaf_case {const char* name;unsigned char bytes[24];int count,extent,instructions,reads,events;unsigned char marks[24];};
static const struct leaf_case leaf_vectors[]={
 {"return with padding",{0xc3,0x62,0xff},3,1,1,1,5,{2,0,0}},
 {"immediate and return",{0xb8,7,0,0,0,0xc3,0x90},7,6,2,6,13,{2,3,3,3,3,2,0}},
 {"two returns",{0x74,1,0xc3,0xc3,0x90},5,4,3,4,13,{2,3,2,2,0}},
 {"backward loop",{0x90,0xeb,0xfd},3,3,2,3,11,{2,2,3}},
 {"self loop",{0xeb,0xfe},2,2,1,2,8,{2,3}},
 {"unreachable unsupported bytes",{0xeb,2,0x62,0xff,0xc3,0x90},6,5,2,3,10,{2,3,0,0,2,0}},
 {"merged branch",{0x74,4,0xb0,1,0xeb,2,0xb0,2,0xc3},9,9,5,9,26,{2,3,2,3,2,3,2,3,2}},
 {"conditional self loop",{0x75,0xfe,0xc3},3,3,2,3,11,{2,3,2}},
 {"embedded return byte",{0xb8,0xc3,0,0,0,0xc3},6,6,2,6,13,{2,3,3,3,3,2}},
 {"maximum instruction",{0x66,0x66,0x66,0x66,0x66,0x66,0x2e,0xf,0x1f,0x84,0,0,0,0,0,0xc3},16,16,2,16,33,{2,3,3,3,3,3,3,3,3,3,3,3,3,3,3,2}}
};
static int leaf_cases(void** owner,void** cancellation){
 CHECK(sizeof(struct leaf)==40);struct inspection state;struct failure failure;struct leaf_env e;unsigned char bytes[64];
 for(size_t i=0;i<sizeof leaf_vectors/sizeof leaf_vectors[0];++i){const struct leaf_case* v=&leaf_vectors[i];memset(bytes,0xcc,sizeof bytes);memcpy(bytes+3,v->bytes,v->count);CHECK(replace(owner,bytes,sizeof bytes)==0 && leaf_open(&e)==0);inspection_defaults(&state);ube_err_set(77,"prior","leaf");inventory_observe(0);CHECK(inspect_leaf(&e.value,owner,3,v->count,&state,&e.storage,&e.limits,&e.usage,NULL,&failure));inventory_observation_end();
  if(e.value.code_bytes!=v->extent || state.events!=v->events)fprintf(stderr,"leaf oracle %s extent=%d events=%lld expected=%d\n",v->name,e.value.code_bytes,(long long)state.events,v->events);
  CHECK(e.value.code_bytes==v->extent && e.value.instructions==v->instructions && e.value.first==3 && e.value.status==1 && memcmp(payload(e.value.marks),v->marks,v->count)==0);
  CHECK(failure.code==0 && state.bytes==v->reads && state.events==v->events && inventory_bytes==state.bytes && byte_visits==state.bytes && inventory_events==state.events && inventory_allocation_visits==2 && copies==0 && e.storage.payload==5*v->count && e.storage.peak==e.storage.payload && e.usage.payload==e.storage.payload && e.usage.peak==e.storage.payload && ube_err_number()==77 && memcmp(payload(*owner),bytes,sizeof bytes)==0);
  struct leaf saved=e.value;CHECK(!inspect_leaf(&e.value,owner,3,v->count,&state,&e.storage,&e.limits,&e.usage,NULL,&failure) && failure.code==1509 && memcmp(&e.value,&saved,sizeof saved)==0);CHECK(leaf_close(&e)==0);
  for(int domain=0;domain<4;++domain)for(int delta=-1;delta<=0;++delta){CHECK(leaf_open(&e)==0);inspection_defaults(&state);if(domain==0)state.maximum_bytes=v->reads+delta;if(domain==1)state.maximum_events=v->events+delta;if(domain==2)e.storage.maximum=5*v->count+delta;if(domain==3)e.limits.payload=5*v->count+delta;inventory_observe(0);int ok=inspect_leaf(&e.value,owner,3,v->count,&state,&e.storage,&e.limits,&e.usage,NULL,&failure);inventory_observation_end();CHECK(ok==(delta==0) && state.bytes==byte_visits && state.bytes==inventory_bytes && state.events==inventory_events);if(!ok)CHECK(failure.code==1502 && e.value.status==4 && e.value.code_bytes==0 && e.value.instructions==0 && e.value.first==0);CHECK(leaf_close(&e)==0);}
  for(size_t at=1;at<=2;++at){CHECK(leaf_open(&e)==0);inspection_defaults(&state);inventory_observe(at);int ok=inspect_leaf(&e.value,owner,3,v->count,&state,&e.storage,&e.limits,&e.usage,NULL,&failure);inventory_observation_end();CHECK(!ok && failure.code==1502 && failure.resource==7 && e.value.status==4 && e.value.code_bytes==0 && inventory_allocation_visits>=at && inventory_allocation_visits<=at+2 && e.storage.payload==e.value.mark_capacity+4LL*e.value.pending_capacity && e.storage.payload==e.usage.payload);CHECK(leaf_close(&e)==0);}
  CHECK(make_cancel(cancellation));inventory_cancel_flag=(bool*)*cancellation;for(int64_t at=1;at<=v->events;++at){CHECK(leaf_open(&e)==0);inspection_defaults(&state);*inventory_cancel_flag=false;inventory_cancel_at=at;inventory_observe(0);int ok=inspect_leaf(&e.value,owner,3,v->count,&state,&e.storage,&e.limits,&e.usage,*cancellation,&failure);inventory_observation_end();CHECK(!ok && failure.code==1507 && e.value.status==4 && e.value.code_bytes==0 && e.value.instructions==0 && e.value.first==0 && state.events==at-1 && state.events==inventory_events && state.bytes==inventory_bytes && state.bytes==byte_visits);CHECK(leaf_close(&e)==0);}inventory_cancel_flag=NULL;inventory_cancel_at=0;*cancellation=NULL;
 }
 /* Linear straight-line and deeply pending multi-return branch graphs. */
 for(int shape=0;shape<2;++shape){int n=shape?3073:4096;unsigned char* code=malloc(n);unsigned char* marks=malloc(n);CHECK(code && marks);memset(code,0x90,n);memset(marks,2,n);if(shape)for(int j=0;j<1024;++j){code[3*j]=0x74;code[3*j+1]=1;code[3*j+2]=0xc3;marks[3*j+1]=3;}code[n-1]=0xc3;CHECK(replace(owner,code,n)==0 && leaf_open(&e)==0);inspection_defaults(&state);inventory_observe(0);CHECK(inspect_leaf(&e.value,owner,0,n,&state,&e.storage,&e.limits,&e.usage,NULL,&failure));inventory_observation_end();CHECK(e.value.code_bytes==n && e.value.instructions==(shape?2049:4096) && memcmp(payload(e.value.marks),marks,n)==0 && state.bytes==n && state.events==(shape?8197:12290) && state.bytes==byte_visits && state.events==inventory_events && e.storage.payload==5*n && inventory_allocation_visits==2 && copies==0);CHECK(leaf_close(&e)==0);free(marks);free(code);}
 const struct {unsigned char bytes[24];int count;} bad[]={
  {{0x90},1},{{0xeb,0},2},{{0xeb,0xfd},2},{{0xe9,0xff,0xff,0xff,0x7f},5},{{0xe9,0,0,0,0x80},5},{{0xeb,0xff},2},
  {{0x74,1,0xb8,0,0,0,0,0xc3},8},{{0x74,2,0xb8,0,0,0,0,0xc3},8},{{0xb8,0,0,0,0,0xeb,0xfa},7},
  {{0xe8,0,0,0,0,0xc3},6},{{0xff,0xd0},2},{{0xff,0xe0},2},{{0x0f,0x0b},2},{{0xcc},1},{{0x74,1,0xc3,0xcc},4},{{0x53,0xc3},2},{{0x5b,0xc3},2},{{0x40,0xb4,3,0xc3},4},
  {{0xbb,0,0,0,0,0xc3},6},{{0xbd,0,0,0,0,0xc3},6},{{0xbe,0,0,0,0,0xc3},6},{{0xbf,0,0,0,0,0xc3},6},
  {{0x41,0xbc,0,0,0,0,0xc3},7},{{0x41,0xbd,0,0,0,0,0xc3},7},{{0x41,0xbe,0,0,0,0,0xc3},7},{{0x41,0xbf,0,0,0,0,0xc3},7},
  {{0x48,0x83,0xec,0x28,0xc3},5},{{0x62},1},{{0xb8,0,0,0},4},{{0x75,0},2}
 };
 for(size_t i=0;i<sizeof bad/sizeof bad[0];++i){CHECK(replace(owner,bad[i].bytes,bad[i].count)==0 && leaf_open(&e)==0);inspection_defaults(&state);CHECK(!inspect_leaf(&e.value,owner,0,bad[i].count,&state,&e.storage,&e.limits,&e.usage,NULL,&failure) && failure.code==1506 && e.value.status==4 && e.value.code_bytes==0 && e.value.instructions==0);CHECK(leaf_close(&e)==0);}
 CHECK(replace(owner,bytes,sizeof bytes)==0);const int bounds[][2]={{-1,1},{0,0},{64,1},{0,65},{INT32_MAX,1},{1,INT32_MAX}};for(size_t i=0;i<sizeof bounds/sizeof bounds[0];++i){CHECK(leaf_open(&e)==0);struct leaf saved=e.value;inspection_defaults(&state);CHECK(!inspect_leaf(&e.value,owner,bounds[i][0],bounds[i][1],&state,&e.storage,&e.limits,&e.usage,NULL,&failure) && failure.code==1509 && memcmp(&e.value,&saved,sizeof saved)==0 && state.events==0);CHECK(leaf_close(&e)==0);}
 /* Actual root refusal before entry and inside allocating/nested calls. */
 bytes[0]=0xc3;CHECK(replace(owner,bytes,sizeof bytes)==0 && leaf_open(&e)==0);size_t n=UBE_GC_MAX_ROOTS-ube_gc_root_count;struct ube_gc_root* pressure=calloc(n,sizeof *pressure);void* nil=NULL;CHECK(pressure);for(size_t j=0;j<n;++j)CHECK(ube_gc_root_enter(&pressure[j],&nil));
 for(size_t free_roots=0;free_roots<20;++free_roots){inspection_defaults(&state);int ok=inspect_leaf(&e.value,owner,0,1,&state,&e.storage,&e.limits,&e.usage,NULL,&failure);if(ok)CHECK(e.value.status==1 && e.value.code_bytes==1);else CHECK(e.value.status!=1 && e.value.code_bytes==0 && e.value.instructions==0);CHECK(dispose_leaf(&e.value,&e.storage,&e.usage,&failure) && failure.code==0 && e.storage.payload==0 && e.usage.payload==0 && e.value.status==0);CHECK(ube_gc_root_leave(&pressure[--n]));}
 for(size_t j=0;j<n;++j)CHECK(ube_gc_root_leave(&pressure[j]));free(pressure);CHECK(leaf_close(&e)==0);
 unsigned char restore[256];symbol_bytes(restore);CHECK(replace(owner,restore,sizeof restore)==0);return 0;
}

/* Frozen independent map transport: count; first,fence,extent,instructions;
   fence bytes of expected boundary marks for each function. */
static int inspect_leaves(void** owner,const char* object_path,const char* expected_path){
 CHECK(retention_load(owner,object_path)==0);FILE* file=fopen(expected_path,"rb");int32_t count;CHECK(file && fread(&count,4,1,file)==1 && count>0 && count<=10000);struct inspection state;struct failure failure;inspection_defaults(&state);
 for(int i=0;i<count;++i){int32_t fields[4];CHECK(fread(fields,sizeof fields,1,file)==1 && fields[1]>0 && fields[1]<=1000000);unsigned char* marks=malloc(fields[1]);CHECK(marks && fread(marks,1,fields[1],file)==(size_t)fields[1]);struct leaf_env e;CHECK(leaf_open(&e)==0);int ok=inspect_leaf(&e.value,owner,fields[0],fields[1],&state,&e.storage,&e.limits,&e.usage,NULL,&failure);if(!ok)fprintf(stderr,"leaf failure index=%d first=%d code=%d\n",i,fields[0],failure.code);CHECK(ok && e.value.status==1 && e.value.first==fields[0] && e.value.code_bytes==fields[2] && e.value.instructions==fields[3] && memcmp(payload(e.value.marks),marks,fields[1])==0);free(marks);CHECK(leaf_close(&e)==0);}
 CHECK(fgetc(file)==EOF && fclose(file)==0);printf("PASS %d independently traversed leaf functions\n",count);return 0;
}
