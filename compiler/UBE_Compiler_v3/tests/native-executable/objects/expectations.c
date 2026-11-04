struct declaration_target {int32_t kind,source,scope,type,representation,flags,role,first_parameter,parameter_count,first_member,last_member,next_member,frame,byref;int64_t value,address;};
struct declaration_plan {void* targets;int32_t count,status,frames,byrefs;};
struct expected_definition {struct object_name name;int32_t unit,source,declaration,family,required,bytes,type,representation;};
struct expected_definitions {void* rows;void* names;int32_t capacity,count,name_capacity,name_length,sources,status;};
extern int32_t expectations_prepare(struct expected_definitions*,struct declaration_plan*,int32_t,int32_t,struct inspection*,struct inspection_storage*,struct native_limits*,struct native_usage*,void*,struct failure*);
extern int32_t expectations_dispose(struct expected_definitions*,struct inspection_storage*,struct native_usage*,struct failure*);
struct expectations_env {struct expected_definitions value;struct inspection_storage storage;struct native_limits limits;struct native_usage usage;struct ube_gc_root roots[2];};
static const struct ube_value_layout expected_target_layout={72,0,0,NULL,0,NULL};
static int expectations_open(struct expectations_env* e){memset(e,0,sizeof *e);inventory_storage_defaults(&e->storage);native_limits_defaults(&e->limits);CHECK(ube_gc_root_enter(&e->roots[0],&e->value.rows) && ube_gc_root_enter(&e->roots[1],&e->value.names));return 0;}
static int expectations_close(struct expectations_env* e){struct failure failure;CHECK(expectations_dispose(&e->value,&e->storage,&e->usage,&failure) && failure.code==0 && e->storage.payload==0 && e->usage.payload==0 && e->value.status==0 && !e->value.rows && !e->value.names);CHECK(ube_gc_root_leave(&e->roots[1]) && ube_gc_root_leave(&e->roots[0]));(void)ube_gc_collect();return 0;}
static void expected_targets(struct declaration_target* t){memset(t,0,9*sizeof *t);for(int i=0;i<9;++i){t[i].value=t[i].address=-1;t[i].frame=t[i].byref=-1;}
 t[0].kind=t[1].kind=1;t[0].scope=t[1].scope=-1;t[1].source=1;
 t[2].kind=2;t[2].type=t[2].representation=4;t[2].address=123;
 t[3].kind=6;t[3].type=t[3].representation=4;t[3].value=42;t[3].frame=0;
 t[4].kind=4;t[4].scope=3;t[4].type=t[4].representation=4;
 t[5].kind=2;t[5].scope=3;t[5].type=t[5].representation=4;t[5].address=999;
 t[6].kind=5;t[6].source=t[6].scope=1;t[6].value=17;t[6].frame=1;
 t[7].kind=6;t[7].source=t[7].scope=1;t[7].role=1;t[7].type=6;t[7].representation=2;
 t[8].kind=3;t[8].source=t[8].scope=1;t[8].type=t[8].representation=4;
}
struct expected_oracle {const char* name;int32_t unit,source,declaration,family,required,bytes,type,representation;};
static const struct expected_oracle expected_rows[]={
 {"ube.module.init0",0,0,0,3,1,0,0,0},{"ube.stack.admit",0,0,-1,4,0,0,0,0},{"ube.module.require",0,0,-1,5,0,0,0,0},
 {"ube.error.if",0,0,-1,23,0,0,0,0},
 {"ube.module.init1",0,1,1,3,1,0,0,0},{"ube.stack.admit",0,1,-1,4,0,0,0,0},{"ube.module.require",0,1,-1,5,0,0,0,0},
 {"ube.error.if",0,1,-1,23,0,0,0,0},
 {"ube.g123",0,0,2,2,0,4,4,4},{"ube.f42",0,0,3,1,1,0,4,4},{"ube.f17",0,1,6,1,0,0,0,0},
 {"ube.stack.admit",1,-1,-1,4,0,0,0,0},{"ube.module.require",1,-1,-1,5,0,0,0,0},{"ube.module.initialize",1,-1,-1,6,0,0,0,0},{"ube.program.run",1,-1,-1,7,1,0,0,0},{"main",2,-1,-1,8,1,0,0,0},
 {"ube.module.states",3,-1,-1,9,1,2,0,0},{"ube.module.failed",3,-1,-1,10,1,1,0,0},{"ube.module.initializers",3,-1,-1,11,1,16,0,0},
 {"ube.stack.floor",4,-1,-1,12,1,8,0,0},{"ube.stack.initialize",4,-1,-1,13,1,0,0,0},{"ube.stack.abort",4,-1,-1,14,1,0,0,0},{"ube.module.wait",4,-1,-1,15,1,0,0,0},
 {"ube.stack.reserve",5,-1,-1,16,1,8,0,0},{"ube.stack.frames",5,-1,-1,17,1,40,0,0},
 {"ube_err_set",6,-1,-1,18,1,0,0,0},{"ube_err_set_stack_exhausted",6,-1,-1,19,1,0,0,0},{"ube_err_number",6,-1,-1,20,1,0,0,0},{"ube_err_clear",6,-1,-1,21,1,0,0,0},{"ube_thread_error",6,-1,-1,22,1,784,0,0}
};
static int expectations_cases(void** cancellation){
 CHECK(sizeof(struct declaration_target)==72 && sizeof(struct expected_definition)==40 && sizeof(struct expected_definitions)==40);struct declaration_plan plan={0};struct ube_gc_root root={0};CHECK(ube_gc_root_enter(&root,&plan.targets) && ube_value_try_resize(&plan.targets,9,&expected_target_layout,0));plan.count=9;plan.status=1;plan.frames=2;expected_targets((struct declaration_target*)payload(plan.targets));unsigned char saved[9*72];memcpy(saved,payload(plan.targets),sizeof saved);
 struct expectations_env e;CHECK(expectations_open(&e)==0);struct inspection state;inspection_defaults(&state);struct failure failure;inventory_observe(0);ube_err_set(77,"prior","expectations");int prepared=expectations_prepare(&e.value,&plan,2,3,&state,&e.storage,&e.limits,&e.usage,NULL,&failure);inventory_observation_end();if(!prepared)fprintf(stderr,"expectations: code %d/%d status %d capacity %d count %d names %d work %lld events %lld allocations %zu\n",failure.code,failure.resource,e.value.status,e.value.capacity,e.value.count,e.value.name_length,(long long)e.usage.work,(long long)state.events,inventory_allocation_visits);CHECK(prepared);
 CHECK(failure.code==0 && e.value.status==1 && e.value.capacity==34 && e.value.count==30 && e.value.name_capacity==1632 && e.value.sources==2 && e.storage.payload==2992 && e.storage.peak==2992 && e.usage.payload==2992 && e.usage.work==9 && e.usage.llvm==0 && e.usage.identities==0 && inventory_allocation_visits==2 && copies==0 && state.bytes==0 && byte_visits==0 && state.events==inventory_events && ube_err_number()==77 && memcmp(saved,payload(plan.targets),sizeof saved)==0);
 int64_t events=state.events;struct expected_definition* rows=(struct expected_definition*)payload(e.value.rows);int position=0;for(int i=0;i<30;++i){const struct expected_oracle* o=&expected_rows[i];CHECK(rows[i].name.first==position && rows[i].name.count==(int32_t)strlen(o->name) && memcmp(payload(e.value.names)+position,o->name,strlen(o->name))==0 && rows[i].unit==o->unit && rows[i].source==o->source && rows[i].declaration==o->declaration && rows[i].family==o->family && rows[i].required==o->required && rows[i].bytes==o->bytes && rows[i].type==o->type && rows[i].representation==o->representation);position+=(int)strlen(o->name);}CHECK(e.value.name_length==position && events==position+42);CHECK(expectations_close(&e)==0);
 for(size_t at=1;at<=2;++at){CHECK(expectations_open(&e)==0);inspection_defaults(&state);inventory_observe(at);int ok=expectations_prepare(&e.value,&plan,2,3,&state,&e.storage,&e.limits,&e.usage,NULL,&failure);inventory_observation_end();CHECK(!ok && failure.code==1502 && failure.resource==7 && e.value.status==4 && e.storage.payload==40LL*e.value.capacity+e.value.name_capacity && e.usage.payload==e.storage.payload);CHECK(expectations_close(&e)==0);}
 for(int domain=0;domain<4;++domain)for(int delta=-1;delta<=0;++delta){CHECK(expectations_open(&e)==0);inspection_defaults(&state);if(domain==0)e.storage.maximum=2992+delta;if(domain==1)e.limits.payload=2992+delta;if(domain==2)e.limits.work=9+delta;if(domain==3)state.maximum_events=events+delta;int ok=expectations_prepare(&e.value,&plan,2,3,&state,&e.storage,&e.limits,&e.usage,NULL,&failure);CHECK(ok==(delta==0));if(!ok)CHECK(failure.code==1502 && failure.resource==(domain==1?1:domain==2?5:7) && e.value.status==4);CHECK(expectations_close(&e)==0);}
 CHECK(make_cancel(cancellation));inventory_cancel_flag=(bool*)*cancellation;
 for(int64_t at=1;at<=events;++at){CHECK(expectations_open(&e)==0);inspection_defaults(&state);*inventory_cancel_flag=false;inventory_cancel_at=at;inventory_observe(0);int ok=expectations_prepare(&e.value,&plan,2,3,&state,&e.storage,&e.limits,&e.usage,*cancellation,&failure);inventory_observation_end();CHECK(!ok && failure.code==1507 && e.value.status==4 && state.events==at-1 && state.events==inventory_events && state.bytes==0);CHECK(expectations_close(&e)==0);}
 inventory_cancel_flag=NULL;inventory_cancel_at=0;*cancellation=NULL;
 for(int mutation=0;mutation<4;++mutation){struct declaration_target* targets=(struct declaration_target*)payload(plan.targets);expected_targets(targets);int main_id=3;switch(mutation){case 0:main_id=7;break;case 1:targets[3].value=-1;break;case 2:targets[2].source=2;break;case 3:targets[2].scope=2;break;}CHECK(expectations_open(&e)==0);inspection_defaults(&state);CHECK(!expectations_prepare(&e.value,&plan,2,main_id,&state,&e.storage,&e.limits,&e.usage,NULL,&failure) && failure.code==1509 && e.value.status==4);CHECK(expectations_close(&e)==0);}
 /* The decimal name remains exact at the largest supported target identity. */
 struct declaration_target* targets=(struct declaration_target*)payload(plan.targets);expected_targets(targets);targets[3].value=INT64_MAX;CHECK(expectations_open(&e)==0);inspection_defaults(&state);CHECK(expectations_prepare(&e.value,&plan,2,3,&state,&e.storage,&e.limits,&e.usage,NULL,&failure));rows=(struct expected_definition*)payload(e.value.rows);CHECK(rows[9].name.count==24 && memcmp(payload(e.value.names)+rows[9].name.first,"ube.f9223372036854775807",24)==0);CHECK(expectations_close(&e)==0);
 plan.targets=NULL;CHECK(ube_gc_root_leave(&root));return 0;
}
