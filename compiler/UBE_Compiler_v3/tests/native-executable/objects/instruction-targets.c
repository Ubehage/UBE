/* Literal signed-address regressions; linked encodings are independent oracles. */
extern int32_t instruction_relocation_target(struct instruction*,int64_t,struct object_relocation*,struct definition_range*,int64_t,void**,int32_t,struct inspection*,int64_t*,void*,struct failure*);
struct instruction_target_case {const char* name;int form,kind;int32_t original;uint32_t linked;int64_t site,rva,section_offset,expected;int valid,high_base;};
static const struct instruction_target_case instruction_target_vectors[]={
 {"call",0,4,0,0x1ffb,0x1000,0x3000,0x200,0x3000,1,0},
 {"relative end 5",0,5,0,0x1ffa,0x1000,0x3000,0x200,0x2fff,1,0},
 {"relative end 6",0,6,0,0x1ff9,0x1000,0x3000,0x200,0x2ffe,1,0},
 {"relative end 7",0,7,0,0x1ff8,0x1000,0x3000,0x200,0x2ffd,1,0},
 {"relative end 8",0,8,0,0x1ff7,0x1000,0x3000,0x200,0x2ffc,1,0},
 {"relative end 9",0,9,0,0x1ff6,0x1000,0x3000,0x200,0x2ffb,1,0},
 {"rip constant",1,4,19,0x200c,0x1000,0x3000,0x200,0x3013,1,0},
 {"trailing dword",2,4,-4,0x1ff6,0x1000,0x3000,0x200,0x3000,1,0},
 {"trailing byte",4,4,-1,0x1ff9,0x1000,0x3000,0x200,0x3000,1,0},
 {"negative addend",0,4,-8,0x1ff3,0x1000,0x3000,0x200,0x2ff8,1,0},
 {"positive limit",0,4,0,0x7fffffff,0x1000,0x80001004LL,0x200,0x80001004LL,1,0},
 {"positive overflow",0,4,0,0x80000000,0x1000,0x80001005LL,0x200,0,0,0},
 {"negative limit",0,4,0,0x80000000,0x80001000LL,0x1005,0x200,0x1005,1,0},
 {"negative overflow",0,4,0,0x7fffffff,0x80001000LL,0x1004,0x200,0,0,0},
 {"negative RVA",0,4,-1,0xffffeffa,0x1000,0,0,0,0,0},
 {"RVA overflow",0,4,2,0xffffeffb,0x1000,0xfffffffeLL,0,0,0,0},
 {"VA limit",0,4,1,0x1ffc,0x1000,0x3000,0x200,0x3001,1,1},
 {"VA overflow",0,4,2,0x1ffd,0x1000,0x3000,0x200,0,0,1},
 {"TLS zero",3,11,0,0,0x1000,0x3000,0,0,1,0},
 {"TLS member",3,11,-8,32,0x1000,0x3000,40,32,1,0},
 {"TLS positive limit",3,11,0,0x7fffffff,0x1000,0x80000fffLL,0x7fffffff,0x7fffffff,1,0},
 {"TLS signed overflow",3,11,0,0x80000000,0x1000,0x80001000LL,0x80000000LL,0,0,0},
 {"negative TLS offset",3,11,-1,0xffffffff,0x1000,0x3000,0,0,0,0}
};
static int instruction_target_cases(void** object,void** cancellation){
 void* image=NULL;struct ube_gc_root root={0};CHECK(ube_gc_root_enter(&root,&image));
 struct inspection state;struct failure failure;
 for(size_t vi=0;vi<sizeof instruction_target_vectors/sizeof instruction_target_vectors[0];++vi){
  const struct instruction_target_case* v=&instruction_target_vectors[vi];unsigned char bytes[16]={0xe8,0,0,0,0},linked[20]={0};int length=5,field=1;
  if(v->form==1 || v->form==3){const unsigned char b[]={0x48,0x8b,0x05,0,0,0,0};memcpy(bytes,b,7);length=7;field=3;if(v->form==3)bytes[2]=0x80;}
  if(v->form==2){const unsigned char b[]={0xc7,0x05,0,0,0,0,0x44,0x33,0x22,0x11};memcpy(bytes,b,10);length=10;field=2;}
  if(v->form==4){const unsigned char b[]={0x80,0x3d,0,0,0,0,1};memcpy(bytes,b,7);length=7;field=2;}
  put(bytes,field,(uint32_t)v->original,4);memcpy(linked+3,bytes,length);put(linked,3+field,v->linked,4);CHECK(replace(object,bytes,length)==0 && replace(&image,linked,sizeof linked)==0);
  inspection_defaults(&state);struct instruction ins;CHECK(read_instruction(object,0,length,&state,&ins,NULL,&failure));struct instruction old_ins=ins;
  struct object_relocation rel={100+field,0,v->kind,4,v->kind==11?0:v->kind},old_rel=rel;
  struct definition_range target=fixup_target(0);target.rva=v->rva;target.offset=v->section_offset;target.address=(v->high_base?INT64_MAX-v->rva-1:INT64_C(0x140000000))+v->rva;struct definition_range old_target=target;
  int64_t result=123;inspection_defaults(&state);ube_err_set(77,"prior","instruction target");inventory_observe(1);
  int ok=instruction_relocation_target(&ins,100,&rel,&target,v->site,&image,3,&state,&result,NULL,&failure);inventory_observation_end();
  if(ok!=v->valid || (ok && result!=v->expected))fprintf(stderr,"signed target vector=%s code=%d result=%lld\n",v->name,failure.code,(long long)result);
  CHECK(ok==v->valid && (ok?result==v->expected:result==123));
  CHECK(failure.code==(ok?0:1506) && failure.resource==0 && same_instruction(&ins,&old_ins) && memcmp(&rel,&old_rel,sizeof rel)==0 && memcmp(&target,&old_target,sizeof target)==0);
  CHECK(memcmp(payload(*object),bytes,length)==0 && memcmp(payload(image),linked,sizeof linked)==0 && state.events==(ok?2:1) && state.bytes==(ok?4:0) && state.events==inventory_events && state.bytes==inventory_bytes && byte_visits==state.bytes && inventory_allocation_visits==0 && copies==0 && ube_err_number()==77);
  /* The three diagnosed wrap cases still satisfy encoding equality. */
  if(vi==11 || vi==13 || vi==21){inspection_defaults(&state);CHECK(validate_fixup(&rel,&target,v->site+field,object,field,&image,3+field,&state,NULL,&failure));}
  if(!ok)continue;
  for(int byte=0;byte<4;++byte){payload(image)[3+field+byte]^=1;inspection_defaults(&state);result=123;CHECK(!instruction_relocation_target(&ins,100,&rel,&target,v->site,&image,3,&state,&result,NULL,&failure) && failure.code==1506 && result==123);payload(image)[3+field+byte]^=1;}
  for(int domain=0;domain<2;++domain)for(int delta=-1;delta<=0;++delta){inspection_defaults(&state);if(domain)state.maximum_events=2+delta;else state.maximum_bytes=4+delta;result=123;inventory_observe(0);ok=instruction_relocation_target(&ins,100,&rel,&target,v->site,&image,3,&state,&result,NULL,&failure);inventory_observation_end();CHECK(ok==(delta==0) && state.bytes==byte_visits && state.bytes==inventory_bytes && state.events==inventory_events);if(!ok)CHECK(failure.code==1502 && failure.resource==7 && result==123);}
  CHECK(make_cancel(cancellation));inventory_cancel_flag=(bool*)*cancellation;for(int at=1;at<=2;++at){*inventory_cancel_flag=false;inventory_cancel_at=at;inspection_defaults(&state);result=123;inventory_observe(0);ok=instruction_relocation_target(&ins,100,&rel,&target,v->site,&image,3,&state,&result,*cancellation,&failure);inventory_observation_end();CHECK(!ok && failure.code==1507 && result==123 && state.events==at-1 && state.bytes==0 && inventory_events==state.events);}inventory_cancel_flag=NULL;inventory_cancel_at=0;*cancellation=NULL;
  if(v->kind!=11){inspection_defaults(&state);result=123;CHECK(!instruction_relocation_target(&ins,100,&rel,&target,v->site+1,&image,3,&state,&result,NULL,&failure) && failure.code==1506 && result==123);}
 }
 const unsigned char call[]={0xe8,0,0,0,0};const unsigned char linked[]={0xe8,0xfb,0x1f,0,0};CHECK(replace(object,call,5)==0 && replace(&image,linked,5)==0);inspection_defaults(&state);struct instruction ins;CHECK(read_instruction(object,0,5,&state,&ins,NULL,&failure));struct object_relocation rel={1,0,4,4,4};struct definition_range target=fixup_target(0);struct instruction old_ins=ins;struct definition_range old_target=target;
 for(int defect=0;defect<17;++defect){ins=old_ins;target=old_target;int first=0;int64_t rva=0x1000;int expected=1509;
  if(defect==0)target.section=-1;if(defect==1)target.section=96;if(defect==2)target.count=0;if(defect==3)target.initialized=2;if(defect==4)target.offset=-1;if(defect==5)target.offset=target.rva+1;if(defect==6)target.rva=INT64_C(0x100000000);if(defect==7)target.address=target.rva-1;if(defect==8)target.address=INT64_MAX;
  if(defect==9)first=-1;if(defect==10)first=1;if(defect==11)first=INT32_MAX;if(defect==12)rva=-1;if(defect==13)rva=UINT32_MAX-4;if(defect==14)ins.length=0;if(defect==15)ins.length=16;if(defect==16){++target.rva;++target.address;expected=1506;}
  inspection_defaults(&state);int64_t result=123;CHECK(!instruction_relocation_target(&ins,0,&rel,&target,rva,&image,first,&state,&result,NULL,&failure) && failure.code==expected && result==123);if(expected==1509)CHECK(state.events==0 && state.bytes==0);
 }
 ins=old_ins;target=old_target;inspection_defaults(&state);int64_t result=123;ube_gc_test_fail_next_allocations(1000000);inventory_observe(0);CHECK(instruction_relocation_target(&ins,0,&rel,&target,0x1000,&image,0,&state,&result,NULL,&failure) && result==0x3000);inventory_observation_end();ube_gc_test_fail_next_allocations(0);CHECK(inventory_allocation_visits==0 && copies==0);
 size_t available=UBE_GC_MAX_ROOTS-ube_gc_root_count;struct ube_gc_root* pressure=calloc(available,sizeof *pressure);void* nil=NULL;CHECK(pressure);for(size_t n=0;n<available;++n)CHECK(ube_gc_root_enter(&pressure[n],&nil));inspection_defaults(&state);result=123;CHECK(!instruction_relocation_target(&ins,0,&rel,&target,0x1000,&image,0,&state,&result,NULL,&failure) && result==123);for(size_t n=0;n<available;++n)CHECK(ube_gc_root_leave(&pressure[n]));free(pressure);
 image=NULL;CHECK(ube_gc_root_leave(&root));unsigned char restore[256];symbol_bytes(restore);CHECK(replace(object,restore,sizeof restore)==0);return 0;
}
