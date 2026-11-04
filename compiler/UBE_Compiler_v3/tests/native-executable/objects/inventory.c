struct inventory {void* symbols;void* keys;void* order;int32_t symbol_capacity,key_capacity,order_capacity,primary_count,length,status;};
struct inspection_storage {int64_t maximum,payload,peak;};
struct native_limits {int64_t payload,llvm,identities,pending,work,depth,candidate;};
struct native_usage {int64_t payload,peak,llvm,identities,pending,peak_pending,work,depth,peak_depth;};
extern void inventory_storage_defaults(struct inspection_storage*),native_limits_defaults(struct native_limits*);
extern int32_t inventory_prepare(struct inventory*,void**,struct layout*,struct inspection*,struct inspection_storage*,struct native_limits*,struct native_usage*,void*,struct failure*);
extern int32_t inventory_dispose(struct inventory*,struct inspection_storage*,struct native_usage*,struct failure*);
extern int32_t inventory_read(struct inventory*,int32_t,struct inspection*,struct object_symbol*,void*,struct failure*);
extern int32_t inventory_find(struct inventory*,void**,void**,struct object_name*,struct inspection*,int32_t*,int32_t*,void*,struct failure*);
extern int32_t inventory_definition(struct inventory*,void**,void**,struct object_name*,struct inspection*,struct object_symbol*,int32_t*,void*,struct failure*);
extern int32_t inventory_targets(struct inventory*,void**,struct layout*,struct inspection*,void*,struct failure*);
struct inventory_env {struct inventory value;struct inspection_storage storage;struct native_limits limits;struct native_usage usage;struct ube_gc_root roots[3];};
static int inventory_open(struct inventory_env* e){memset(e,0,sizeof *e);inventory_storage_defaults(&e->storage);native_limits_defaults(&e->limits);CHECK(ube_gc_root_enter(&e->roots[0],&e->value.symbols) && ube_gc_root_enter(&e->roots[1],&e->value.keys) && ube_gc_root_enter(&e->roots[2],&e->value.order));return 0;}
static int inventory_close(struct inventory_env* e){struct failure f;CHECK(inventory_dispose(&e->value,&e->storage,&e->usage,&f) && f.code==0 && e->storage.payload==0 && e->usage.payload==0 && e->value.status==0 && !e->value.symbols && !e->value.keys && !e->value.order);for(int i=2;i>=0;--i)CHECK(ube_gc_root_leave(&e->roots[i]));(void)ube_gc_collect();return 0;}
static int64_t inventory_polls,inventory_events,inventory_bytes,inventory_cancel_at;
static bool* inventory_cancel_flag;
void inventory_poll(void){if(inventory_observing){++inventory_polls;if(inventory_cancel_flag && inventory_cancel_at==inventory_polls)*inventory_cancel_flag=true;}}
void inventory_event(int32_t bytes){
#ifndef OMIT_INVENTORY_EVENT_CONTROL
 if(inventory_observing){++inventory_events;inventory_bytes+=bytes;}
#else
 (void)bytes;
#endif
}
static int64_t inventory_required_bytes,inventory_required_events;
static void inventory_observe(size_t fail){inventory_observing=1;inventory_fail_at=fail;inventory_allocation_visits=0;byte_visits=0;inventory_polls=inventory_events=inventory_bytes=0;observe();}
static void inventory_observation_end(void){inventory_observing=0;observing=0;}
static int inventory_cases(void** owner,void** cancellation){
 CHECK(sizeof(struct inventory)==48 && sizeof(struct native_limits)==56 && sizeof(struct native_usage)==72);unsigned char bytes[256];symbol_bytes(bytes);CHECK(replace(owner,bytes,sizeof bytes)==0);
 struct layout layout;struct inspection state;struct failure failure;inspection_defaults(&state);CHECK(read_layout(owner,&state,&layout,NULL,&failure));
 struct inventory_env e;CHECK(inventory_open(&e)==0);inspection_defaults(&state);ube_err_set(77,"prior","inventory");inventory_observe(0);CHECK(inventory_prepare(&e.value,owner,&layout,&state,&e.storage,&e.limits,&e.usage,NULL,&failure));inventory_observation_end();
 int64_t required_bytes=state.bytes,required_events=state.events;size_t required_allocations=inventory_allocation_visits;inventory_required_bytes=required_bytes;inventory_required_events=required_events;
 CHECK(e.value.status==1 && e.value.symbol_capacity==4 && e.value.key_capacity==4 && e.value.order_capacity==2 && e.value.primary_count==2 && e.storage.payload==232 && e.storage.peak==240 && e.usage.payload==232 && e.usage.peak==240 && failure.code==0 && copies==8 && byte_visits==required_bytes && inventory_bytes==required_bytes && inventory_events==required_events && required_allocations==6 && ube_err_number()==77);
 const int32_t expected_order[]={1,0};CHECK(memcmp(payload(e.value.order),expected_order,sizeof expected_order)==0);
 struct object_symbol symbol;CHECK(inventory_read(&e.value,0,&state,&symbol,NULL,&failure) && symbol.next==3 && symbol.name.count==16);struct object_symbol saved=symbol;
 for(int index=-1;index<=4;++index)if(index!=0 && index!=3){symbol=saved;CHECK(!inventory_read(&e.value,index,&state,&symbol,NULL,&failure) && failure.code==1506 && memcmp(&symbol,&saved,sizeof symbol)==0);}
 struct object_name name={172,16};int32_t first=99,count=88,index=77;CHECK(inventory_find(&e.value,owner,owner,&name,&state,&first,&count,NULL,&failure) && first==1 && count==1);
 CHECK(inventory_definition(&e.value,owner,owner,&name,&state,&symbol,&index,NULL,&failure) && index==0 && symbol.value==7 && symbol.section==1);
 /* Lookups share the same observed ledger and publish only after success. */
 inspection_defaults(&state);inventory_observe(0);CHECK(inventory_find(&e.value,owner,owner,&name,&state,&first,&count,NULL,&failure));inventory_observation_end();int64_t query_bytes=state.bytes,query_events=state.events;CHECK(query_bytes==inventory_bytes && query_bytes==byte_visits && query_events==inventory_events && inventory_allocation_visits==0 && copies==0);
 for(int domain=0;domain<2;++domain)for(int delta=-1;delta<=0;++delta){inspection_defaults(&state);if(domain)state.maximum_events=query_events+delta;else state.maximum_bytes=query_bytes+delta;first=99;count=88;inventory_observe(0);int ok=inventory_find(&e.value,owner,owner,&name,&state,&first,&count,NULL,&failure);inventory_observation_end();CHECK(ok==(delta==0) && state.bytes==inventory_bytes && state.events==inventory_events && state.bytes==byte_visits);if(!ok)CHECK(failure.code==1502 && failure.resource==7 && first==99 && count==88);}
 CHECK(make_cancel(cancellation));inventory_cancel_flag=(bool*)*cancellation;
 for(int64_t at=1;at<=query_events;++at){inspection_defaults(&state);*inventory_cancel_flag=false;inventory_cancel_at=at;first=99;count=88;inventory_observe(0);int ok=inventory_find(&e.value,owner,owner,&name,&state,&first,&count,*cancellation,&failure);inventory_observation_end();CHECK(!ok && failure.code==1507 && first==99 && count==88 && state.events==at-1 && state.events==inventory_events && state.bytes==inventory_bytes && state.bytes==byte_visits);}
 inventory_cancel_flag=NULL;inventory_cancel_at=0;*cancellation=NULL;
 name=(struct object_name){150,8};symbol=saved;index=77;CHECK(!inventory_definition(&e.value,owner,owner,&name,&state,&symbol,&index,NULL,&failure) && failure.code==1506 && index==77 && memcmp(&symbol,&saved,sizeof symbol)==0);
 /* Absolute, auxiliary and undefined entries cannot satisfy a definition. */
 CHECK(inventory_close(&e)==0);
 for(size_t at=1;at<=required_allocations;++at){CHECK(inventory_open(&e)==0);inspection_defaults(&state);inventory_observe(at);int ok=inventory_prepare(&e.value,owner,&layout,&state,&e.storage,&e.limits,&e.usage,NULL,&failure);inventory_observation_end();CHECK(!ok && failure.code==1502 && failure.resource==7 && e.value.status==4 && e.storage.payload==40LL*e.value.symbol_capacity+16LL*e.value.key_capacity+4LL*e.value.order_capacity && e.usage.payload==e.storage.payload);CHECK(inventory_close(&e)==0);}
 for(int domain=0;domain<4;++domain)for(int delta=-1;delta<=0;++delta){CHECK(inventory_open(&e)==0);inspection_defaults(&state);if(domain==0)e.storage.maximum=240+delta;if(domain==1)e.limits.payload=240+delta;if(domain==2)state.maximum_bytes=required_bytes+delta;if(domain==3)state.maximum_events=required_events+delta;int ok=inventory_prepare(&e.value,owner,&layout,&state,&e.storage,&e.limits,&e.usage,NULL,&failure);CHECK(ok==(delta==0));if(!ok)CHECK(failure.code==1502 && failure.resource==(domain==1?1:7) && e.value.status==4);CHECK(inventory_close(&e)==0);}
 CHECK(inventory_open(&e)==0);CHECK(make_cancel(cancellation));*(bool*)*cancellation=true;inspection_defaults(&state);CHECK(!inventory_prepare(&e.value,owner,&layout,&state,&e.storage,&e.limits,&e.usage,*cancellation,&failure) && failure.code==1507 && e.storage.payload==0 && e.usage.payload==0 && state.bytes==0 && state.events==0);*cancellation=NULL;CHECK(inventory_close(&e)==0);
 CHECK(make_cancel(cancellation));inventory_cancel_flag=(bool*)*cancellation;
 for(int64_t at=1;at<=required_events;++at){CHECK(inventory_open(&e)==0);inspection_defaults(&state);*inventory_cancel_flag=false;inventory_cancel_at=at;inventory_observe(0);int ok=inventory_prepare(&e.value,owner,&layout,&state,&e.storage,&e.limits,&e.usage,*cancellation,&failure);inventory_observation_end();CHECK(!ok && failure.code==1507 && state.events==at-1 && state.events==inventory_events && state.bytes==inventory_bytes && state.bytes==byte_visits && e.value.status==4);CHECK(inventory_close(&e)==0);}
 inventory_cancel_flag=NULL;inventory_cancel_at=0;*cancellation=NULL;
 /* Add a relocation to each raw record index: only 0 and 3 are primary. */
 for(int target=0;target<4;++target){symbol_bytes(bytes);put(bytes,44,68,4);put(bytes,52,1,2);put(bytes,68,0,4);put(bytes,72,(unsigned)target,4);put(bytes,76,1,2);CHECK(replace(owner,bytes,sizeof bytes)==0);CHECK(inventory_open(&e)==0);inspection_defaults(&state);CHECK(inventory_prepare(&e.value,owner,&layout,&state,&e.storage,&e.limits,&e.usage,NULL,&failure));int ok=inventory_targets(&e.value,owner,&layout,&state,NULL,&failure);CHECK(ok==(target==0 || target==3));if(!ok)CHECK(failure.code==1506);CHECK(inventory_close(&e)==0);}
 /* Distinct query owner, duplicate defined name, then undefined-name shadow. */
 void* query=NULL;struct ube_gc_root query_root={0};CHECK(ube_gc_root_enter(&query_root,&query));CHECK(replace(&query,"very_long_symbol",16)==0);name=(struct object_name){0,16};
 for(int duplicate=0;duplicate<2;++duplicate){symbol_bytes(bytes);memset(bytes+150,0,8);put(bytes,154,4,4);put(bytes,162,(unsigned)(duplicate?0:1),2);put(bytes,166,2,1);CHECK(replace(owner,bytes,sizeof bytes)==0);CHECK(inventory_open(&e)==0);inspection_defaults(&state);CHECK(inventory_prepare(&e.value,owner,&layout,&state,&e.storage,&e.limits,&e.usage,NULL,&failure));symbol=saved;index=77;int ok=inventory_definition(&e.value,owner,&query,&name,&state,&symbol,&index,NULL,&failure);CHECK(ok==(duplicate==1));if(ok)CHECK(index==0 && symbol.value==7);else CHECK(failure.code==1506 && index==77 && memcmp(&symbol,&saved,sizeof symbol)==0);CHECK(inventory_close(&e)==0);}
 CHECK(ube_gc_root_leave(&query_root));query=NULL;
 /* A valid object with no symbols needs no owned inventory payload. */
 object_bytes(bytes,sizeof bytes);CHECK(replace(owner,bytes,sizeof bytes)==0);struct layout empty_layout;inspection_defaults(&state);CHECK(read_layout(owner,&state,&empty_layout,NULL,&failure));CHECK(inventory_open(&e)==0);CHECK(inventory_prepare(&e.value,owner,&empty_layout,&state,&e.storage,&e.limits,&e.usage,NULL,&failure) && e.value.status==1 && e.value.primary_count==0 && e.storage.payload==0 && e.usage.payload==0);name=(struct object_name){0,0};first=99;count=88;CHECK(inventory_find(&e.value,owner,owner,&name,&state,&first,&count,NULL,&failure) && first==0 && count==0);index=77;symbol=saved;CHECK(!inventory_definition(&e.value,owner,owner,&name,&state,&symbol,&index,NULL,&failure) && failure.code==1506 && index==77 && memcmp(&symbol,&saved,sizeof symbol)==0);CHECK(inventory_close(&e)==0);
 /* Malformed primary data leaves only a disposable incomplete inventory. */
 symbol_bytes(bytes);put(bytes,113,255,1);CHECK(replace(owner,bytes,sizeof bytes)==0);CHECK(inventory_open(&e)==0);inspection_defaults(&state);CHECK(!inventory_prepare(&e.value,owner,&layout,&state,&e.storage,&e.limits,&e.usage,NULL,&failure) && failure.code==1506 && e.value.status==4);CHECK(inventory_close(&e)==0);
 symbol_bytes(bytes);CHECK(replace(owner,bytes,sizeof bytes)==0);CHECK(inventory_open(&e)==0);inspection_defaults(&state);CHECK(inventory_prepare(&e.value,owner,&layout,&state,&e.storage,&e.limits,&e.usage,NULL,&failure));
 size_t available=UBE_GC_MAX_ROOTS-ube_gc_root_count;struct ube_gc_root* pressure=calloc(available,sizeof *pressure);void* nil=NULL;CHECK(pressure);for(size_t i=0;i<available;++i)CHECK(ube_gc_root_enter(&pressure[i],&nil));CHECK(inventory_dispose(&e.value,&e.storage,&e.usage,&failure) && failure.code==0 && e.storage.payload==0 && e.usage.payload==0 && e.value.status==0);for(size_t i=0;i<available;++i)CHECK(ube_gc_root_leave(&pressure[i]));free(pressure);CHECK(inventory_close(&e)==0);
 return 0;
}
static int inspect_inventory(void** owner,struct layout* layout){
 struct inventory_env e;CHECK(inventory_open(&e)==0);struct inspection state;inspection_defaults(&state);struct failure failure;CHECK(inventory_prepare(&e.value,owner,layout,&state,&e.storage,&e.limits,&e.usage,NULL,&failure));
 for(int index=0;index<layout->symbol_count;){struct object_symbol raw,cached;CHECK(read_symbol(owner,&state,layout,index,&raw,NULL,&failure) && inventory_read(&e.value,index,&state,&cached,NULL,&failure) && memcmp(&raw,&cached,sizeof raw)==0);int32_t first=-1,count=-1;CHECK(inventory_find(&e.value,owner,owner,&raw.name,&state,&first,&count,NULL,&failure) && count>0);int found=0;for(int n=0;n<count;++n){int32_t key;memcpy(&key,payload(e.value.order)+4*(first+n),4);int32_t value;memcpy(&value,payload(e.value.keys)+16*key+12,4);if(value==index)++found;}CHECK(found==1);for(int auxiliary=index+1;auxiliary<raw.next;++auxiliary)CHECK(!inventory_read(&e.value,auxiliary,&state,&cached,NULL,&failure) && failure.code==1506);index=raw.next;}
 if(layout->kind==1)CHECK(inventory_targets(&e.value,owner,layout,&state,NULL,&failure));
 CHECK(e.storage.payload==56LL*layout->symbol_count+4LL*e.value.primary_count);CHECK(inventory_close(&e)==0);return 0;
}
