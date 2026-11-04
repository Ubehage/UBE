extern int32_t validate_generated_target(struct instruction*,struct object_relocation*,struct definition_range*,int64_t,struct expected_definition*,struct retained_definition*,struct inspection*,void*,struct failure*);
struct generated_target_case {int family,bytes,initialized,width,write,flow,kind,delta,valid;};
static const struct generated_target_case generated_target_vectors[]={
 {1,0,1,0,0,4,4,0,1},{1,0,1,0,0,3,4,0,1},{1,0,1,0,0,2,9,0,1},
 {1,0,1,0,0,4,4,1,0},{1,0,1,8,0,5,4,0,0},
 {2,16,16,1,0,0,4,0,1},{2,16,16,1,0,0,4,15,1},
 {2,16,16,2,0,0,4,15,0},{2,16,16,0,0,0,4,15,1},{2,16,16,0,0,0,4,16,0},
 {2,16,16,4,1,0,4,12,1},{2,16,0,8,1,0,4,8,1},
 {17,16,16,8,0,0,4,8,1},{17,16,16,8,1,0,4,8,0},{17,16,0,8,0,0,4,0,0},
 {12,8,8,4,1,0,11,4,1},{22,784,784,8,0,0,11,776,1},{22,784,784,1,0,0,11,784,0},
 {12,8,8,4,0,0,4,0,0},{2,16,16,4,0,0,11,0,0},{2,16,16,0,0,4,4,0,0},
 {11,24,24,8,0,5,4,16,1},{11,24,24,8,0,6,4,16,1},{11,24,24,4,0,5,4,0,0},
 {2,16,16,8,0,0,4,-1,0},{2,16,16,0,1,0,4,0,0}
};
static void generated_target_fixture(const struct generated_target_case* v,struct instruction* ins,struct object_relocation* rel,struct definition_range* target,struct expected_definition* expected,struct retained_definition* retained,int64_t* position){
 memset(ins,0,sizeof *ins);ins->length=7;ins->flow=v->flow;ins->memory_bytes=v->width;ins->memory_write=v->write;ins->base=v->kind==11?0:-2;ins->index=-1;ins->scale=1;ins->target=-1;ins->displacement_first=3;ins->displacement_bytes=4;
 if(v->flow>=2 && v->flow<=4){ins->length=5;ins->base=-1;ins->displacement_first=ins->displacement_bytes=0;ins->immediate_first=1;ins->immediate_bytes=4;}
 memset(expected,0,sizeof *expected);expected->name.count=4;expected->family=v->family;expected->bytes=v->bytes;expected->required=1;
 memset(retained,0,sizeof *retained);retained->present=1;retained->image=(struct definition_range){3,2,v->initialized?100:-1,v->bytes?v->bytes:1,v->initialized,v->bytes?0:32,0x200,0x3200,0x140003200LL,v->bytes?((v->family==11 || v->family==16 || v->family==17)?0x40000040:0xC0000040):0x60000020};
 if(v->bytes && !v->initialized)retained->image.characteristics=(retained->image.characteristics&~0x40LL)|0x80;
 retained->object=retained->image;retained->object.rva=retained->object.address=0;
 *target=retained->image;target->count=1;target->initialized=target->initialized?1:0;
 *rel=(struct object_relocation){3,0,v->kind,4,v->kind==11?0:v->kind};
 *position=(v->kind==11?target->offset:target->rva)+v->delta;
}
static int generated_target_cases(void** cancellation){
 struct instruction ins;struct object_relocation rel;struct definition_range target;struct expected_definition expected;struct retained_definition retained;int64_t position;struct inspection state;struct failure failure;
 for(size_t i=0;i<sizeof generated_target_vectors/sizeof generated_target_vectors[0];++i){const struct generated_target_case* v=&generated_target_vectors[i];generated_target_fixture(v,&ins,&rel,&target,&expected,&retained,&position);struct instruction old_ins=ins;struct object_relocation old_rel=rel;struct definition_range old_target=target;struct expected_definition old_expected=expected;struct retained_definition old_retained=retained;
  inspection_defaults(&state);state.maximum_bytes=0;state.maximum_events=1;ube_err_set(77,"prior","generated target");inventory_observe(1);int ok=validate_generated_target(&ins,&rel,&target,position,&expected,&retained,&state,NULL,&failure);inventory_observation_end();
  if(v->valid){CHECK(ok && failure.code==0);}else{CHECK(!ok && failure.code==1506);}
  CHECK(state.bytes==0 && state.events==1 && inventory_events==1 && inventory_bytes==0 && byte_visits==0 && inventory_allocation_visits==0 && copies==0 && ube_err_number()==77);
  CHECK(same_instruction(&ins,&old_ins) && memcmp(&rel,&old_rel,sizeof rel)==0 && memcmp(&target,&old_target,sizeof target)==0 && memcmp(&expected,&old_expected,sizeof expected)==0 && memcmp(&retained,&old_retained,sizeof retained)==0);
  if(v->valid){int64_t end=(v->kind==11?retained.image.offset:retained.image.rva)+retained.image.count;inspection_defaults(&state);ok=validate_generated_target(&ins,&rel,&target,end,&expected,&retained,&state,NULL,&failure);CHECK(!ok && failure.code==1506);}
  inspection_defaults(&state);state.maximum_events=0;CHECK(!validate_generated_target(&ins,&rel,&target,position,&expected,&retained,&state,NULL,&failure) && failure.code==1502 && failure.resource==7 && state.events==0);
  CHECK(make_cancel(cancellation));*(bool*)*cancellation=true;inspection_defaults(&state);CHECK(!validate_generated_target(&ins,&rel,&target,position,&expected,&retained,&state,*cancellation,&failure) && failure.code==1507 && state.events==0);*cancellation=NULL;
 }
 const struct generated_target_case good={2,16,16,4,0,0,4,0,1};
 /* The retained owner and instruction anchor still agree. Residency must
    reject discardability itself, independently of TLS metadata inspection. */
 generated_target_fixture(&good,&ins,&rel,&target,&expected,&retained,&position);
 target.characteristics|=0x02000000;retained.image.characteristics|=0x02000000;
 inspection_defaults(&state);inventory_observe(1);
 int discardable=validate_generated_target(&ins,&rel,&target,position,&expected,&retained,&state,NULL,&failure);inventory_observation_end();
 CHECK(!discardable && failure.code==1506 && state.bytes==0 && state.events==1 && inventory_events==1 && inventory_allocation_visits==0 && copies==0);
 for(int defect=0;defect<34;++defect){generated_target_fixture(&good,&ins,&rel,&target,&expected,&retained,&position);int code=1509;
  if(defect==0)expected.family=24;if(defect==1)expected.unit=7;if(defect==2)expected.required=2;if(defect==3)expected.bytes=-1;if(defect==4)expected.name.first=-1;if(defect==5)expected.name.count=0;if(defect==6)expected.bytes=0;if(defect==7)retained.present=0;if(defect==8)target.count=2;if(defect==9)retained.image.count=15;if(defect==10)target.symbol=-1;if(defect==11)retained.image.symbol=-1;if(defect==12)target.section=96;if(defect==13)retained.image.first=-1;if(defect==14)retained.image.characteristics=INT64_C(0x100000000);if(defect==15)position=-1;if(defect==16)position=INT64_C(0x100000000);if(defect==17)ins.length=16;if(defect==18)ins.flow=8;if(defect==19)ins.memory_bytes=3;if(defect==20)ins.memory_write=2;
  if(defect>=21)code=1506;
  if(defect==21)++target.symbol;if(defect==22)++target.section;if(defect==23)++target.first;if(defect==24)target.initialized=0;if(defect==25)target.type=32;if(defect==26)++target.offset;if(defect==27)++target.rva;if(defect==28)++target.address;if(defect==29)target.characteristics^=0x80;if(defect==30)rel.width=8;if(defect==31)rel.relative_end=5;if(defect==32)ins.index=1;if(defect==33)ins.segment=101;
  inspection_defaults(&state);int ok=validate_generated_target(&ins,&rel,&target,position,&expected,&retained,&state,NULL,&failure);CHECK(!ok && failure.code==code && state.bytes==0 && state.events==(code==1509?0:1));
 }
 generated_target_fixture(&good,&ins,&rel,&target,&expected,&retained,&position);inspection_defaults(&state);ube_gc_test_fail_next_allocations(1000000);inventory_observe(0);CHECK(validate_generated_target(&ins,&rel,&target,position,&expected,&retained,&state,NULL,&failure));inventory_observation_end();ube_gc_test_fail_next_allocations(0);CHECK(inventory_allocation_visits==0 && copies==0);
 size_t available=UBE_GC_MAX_ROOTS-ube_gc_root_count;struct ube_gc_root* pressure=calloc(available,sizeof *pressure);void* nil=NULL;CHECK(pressure);for(size_t n=0;n<available;++n)CHECK(ube_gc_root_enter(&pressure[n],&nil));inspection_defaults(&state);CHECK(!validate_generated_target(&ins,&rel,&target,position,&expected,&retained,&state,NULL,&failure));for(size_t n=0;n<available;++n)CHECK(ube_gc_root_leave(&pressure[n]));free(pressure);return 0;
}
