extern int32_t bind_reference_pointer(struct instruction*,struct definition_range*,int64_t,struct expected_definition*,struct retained_definition*,void**,struct inventory*,void**,struct layout*,struct inspection*,struct definition_range*,void*,struct failure*);
static void reference_pointer_bytes(unsigned char* bytes){
 image_bytes(bytes,1024);put(bytes,76,900,4);put(bytes,80,2,4);put(bytes,336,64,4);put(bytes,364,0x40000040,4);
 put(bytes,904,4,4);put(bytes,912,1,2);put(bytes,916,2,1);memcpy(bytes+918,"table",5);put(bytes,926,32,4);put(bytes,930,1,2);put(bytes,934,2,1);put(bytes,936,18,4);memcpy(bytes+940,".refptr.table",14);put(bytes,512,0x140001020ULL,8);
}
static void reference_pointer_descriptors(struct instruction* ins,struct definition_range* target,struct expected_definition* expected,struct retained_definition* retained){
 memset(ins,0,sizeof *ins);ins->length=7;ins->memory_bytes=8;ins->base=-2;ins->index=-1;ins->scale=1;ins->target=-1;ins->displacement_first=3;ins->displacement_bytes=4;
 *target=(struct definition_range){0,0,512,1,1,0,0,4096,0x140001000LL,0x40000040};
 *expected=(struct expected_definition){{0,5},5,0,0,17,1,16,0,0};memset(retained,0,sizeof *retained);retained->present=1;retained->image=(struct definition_range){1,0,544,16,16,0,32,4128,0x140001020LL,0x40000040};retained->object=retained->image;
}
static int reference_pointer_cases(void** image,void** cancellation){
 void* names=NULL;struct ube_gc_root root={0};CHECK(ube_gc_root_enter(&root,&names) && replace(&names,"table",5)==0);
 unsigned char bytes[1024];reference_pointer_bytes(bytes);CHECK(replace(image,bytes,1024)==0);struct inventory_env e;struct layout layout;CHECK(retention_prepare(&e,image,&layout)==0);
 struct instruction ins;struct definition_range target,result,saved;struct expected_definition expected;struct retained_definition retained;reference_pointer_descriptors(&ins,&target,&expected,&retained);memset(&saved,0xA5,sizeof saved);struct inspection state;struct failure failure;
 struct instruction old_ins=ins;struct definition_range old_target=target;struct expected_definition old_expected=expected;struct retained_definition old_retained=retained;
 inspection_defaults(&state);inventory_observe(1);ube_err_set(77,"prior","reference pointer");result=saved;int ok=bind_reference_pointer(&ins,&target,4096,&expected,&retained,&names,&e.value,image,&layout,&state,&result,NULL,&failure);inventory_observation_end();CHECK(ok && failure.code==0);
 CHECK(result.symbol==0 && result.section==0 && result.first==512 && result.count==8 && result.initialized==8 && result.type==0 && result.offset==0 && result.rva==4096 && result.address==0x140001000LL && result.characteristics==0x40000040 && failure.code==0);
 CHECK(state.bytes==byte_visits && state.bytes==inventory_bytes && state.events==inventory_events && inventory_allocation_visits==0 && copies==0 && ube_err_number()==77 && memcmp(payload(*image),bytes,1024)==0 && memcmp(payload(names),"table",5)==0 && same_instruction(&ins,&old_ins) && memcmp(&target,&old_target,sizeof target)==0 && memcmp(&expected,&old_expected,sizeof expected)==0 && memcmp(&retained,&old_retained,sizeof retained)==0);
 int64_t required_bytes=state.bytes,required_events=state.events;
 /* Candidate refusal precedes budget tests so forced success cannot hide. */
 inspection_defaults(&state);result=saved;ok=bind_reference_pointer(&ins,&target,4097,&expected,&retained,&names,&e.value,image,&layout,&state,&result,NULL,&failure);CHECK(!ok && failure.code==1506 && memcmp(&result,&saved,sizeof result)==0);
 for(int domain=0;domain<2;++domain)for(int delta=-1;delta<=0;++delta){inspection_defaults(&state);if(domain)state.maximum_events=required_events+delta;else state.maximum_bytes=required_bytes+delta;result=saved;inventory_observe(0);int ok=bind_reference_pointer(&ins,&target,4096,&expected,&retained,&names,&e.value,image,&layout,&state,&result,NULL,&failure);inventory_observation_end();CHECK(ok==(delta==0) && state.bytes==byte_visits && state.bytes==inventory_bytes && state.events==inventory_events);if(!ok)CHECK(failure.code==1502 && failure.resource==7 && memcmp(&result,&saved,sizeof result)==0);}
 CHECK(make_cancel(cancellation));inventory_cancel_flag=(bool*)*cancellation;
 for(int64_t at=1;at<=required_events;++at){inspection_defaults(&state);*inventory_cancel_flag=false;inventory_cancel_at=at;result=saved;inventory_observe(0);int ok=bind_reference_pointer(&ins,&target,4096,&expected,&retained,&names,&e.value,image,&layout,&state,&result,*cancellation,&failure);inventory_observation_end();CHECK(!ok && failure.code==1507 && memcmp(&result,&saved,sizeof result)==0 && state.events==at-1 && state.events==inventory_events && state.bytes==inventory_bytes && state.bytes==byte_visits);}
 inventory_cancel_flag=NULL;inventory_cancel_at=0;*cancellation=NULL;
 for(int defect=0;defect<26;++defect){reference_pointer_descriptors(&ins,&target,&expected,&retained);int code=defect<10?1509:1506;
  if(defect==0)expected.family=24;if(defect==1)expected.unit=7;if(defect==2)expected.required=2;if(defect==3)expected.bytes=0;if(defect==4)expected.name.first=6;if(defect==5)expected.name.count=0;if(defect==6)retained.present=0;if(defect==7)retained.image.count=15;if(defect==8)target.count=2;if(defect==9)ins.length=16;
  if(defect==10)ins.flow=5;if(defect==11)ins.memory_bytes=4;if(defect==12)ins.memory_bytes=0;if(defect==13)ins.memory_write=1;if(defect==14)ins.base=0;if(defect==15)ins.index=1;if(defect==16)ins.segment=101;if(defect==17)expected.family=12;if(defect==18)++target.first;if(defect==19)++target.offset;if(defect==20)++target.address;if(defect==21)target.initialized=0;if(defect==22)target.type=32;if(defect==23)target.characteristics^=0x80;if(defect==24)++retained.image.address;if(defect==25)expected.name.count=4;
  inspection_defaults(&state);result=saved;CHECK(!bind_reference_pointer(&ins,&target,4096,&expected,&retained,&names,&e.value,image,&layout,&state,&result,NULL,&failure) && failure.code==code && memcmp(&result,&saved,sizeof result)==0);
 }
 reference_pointer_descriptors(&ins,&target,&expected,&retained);inspection_defaults(&state);ube_gc_test_fail_next_allocations(1000000);inventory_observe(0);CHECK(bind_reference_pointer(&ins,&target,4096,&expected,&retained,&names,&e.value,image,&layout,&state,&result,NULL,&failure));inventory_observation_end();ube_gc_test_fail_next_allocations(0);CHECK(inventory_allocation_visits==0 && copies==0);
 size_t available=UBE_GC_MAX_ROOTS-ube_gc_root_count;struct ube_gc_root* pressure=calloc(available,sizeof *pressure);void* nil=NULL;CHECK(pressure);for(size_t n=0;n<available;++n)CHECK(ube_gc_root_enter(&pressure[n],&nil));inspection_defaults(&state);result=saved;CHECK(!bind_reference_pointer(&ins,&target,4096,&expected,&retained,&names,&e.value,image,&layout,&state,&result,NULL,&failure) && memcmp(&result,&saved,sizeof result)==0);for(size_t n=0;n<available;++n)CHECK(ube_gc_root_leave(&pressure[n]));free(pressure);
 CHECK(inventory_close(&e)==0);
 for(int defect=0;defect<12;++defect){reference_pointer_bytes(bytes);reference_pointer_descriptors(&ins,&target,&expected,&retained);
  if(defect==0)bytes[940]='!';if(defect==1)bytes[952]='x';if(defect==2)bytes[512]^=1;
  if(defect>=3 && defect<=7){uint32_t flags=defect==3?0xC0000040:defect==4?0x60000040:defect==5?0x42000040:defect==6?0x40000060:0x40;put(bytes,364,flags,4);target.characteristics=flags;}
  if(defect==8)put(bytes,336,7,4);
  if(defect==9){put(bytes,908,57,4);target.offset=57;target.rva+=57;target.address+=57;target.first+=57;}
  if(defect==10){put(bytes,70,2,2);memcpy(bytes+368,bytes+328,40);put(bytes,376,8,4);put(bytes,380,4096,4);put(bytes,384,512,4);put(bytes,388,512,4);}
  if(defect==11)put(bytes,914,32,2);
  CHECK(replace(image,bytes,1024)==0 && retention_prepare(&e,image,&layout)==0);inspection_defaults(&state);result=saved;CHECK(!bind_reference_pointer(&ins,&target,target.rva,&expected,&retained,&names,&e.value,image,&layout,&state,&result,NULL,&failure) && failure.code==1506 && memcmp(&result,&saved,sizeof result)==0);CHECK(inventory_close(&e)==0);
 }
 names=NULL;CHECK(ube_gc_root_leave(&root));return 0;
}
