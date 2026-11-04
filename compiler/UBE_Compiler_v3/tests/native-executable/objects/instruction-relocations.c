/* Independent bytes and target-relative addends, not decoder-derived expectations. */
extern int32_t instruction_relocation_offset(struct instruction*,int64_t,struct object_relocation*,struct inspection*,int64_t*,void*,struct failure*);
struct instruction_relocation_case {const char* name;unsigned char bytes[16];int length,field,kind;int64_t offset;};
static const struct instruction_relocation_case instruction_relocation_vectors[]={
 {"call",{0xe8,0,0,0,0},5,1,4,0},
 {"tail",{0xe9,0xff,0xff,0xff,0xff},5,1,4,-1},
 {"conditional",{0x0f,0x85,0xf0,0xff,0xff,0xff},6,2,4,-16},
 {"constant member",{0x48,0x8b,0x05,19,0,0,0},7,3,4,19},
 {"trailing dword",{0xc7,0x05,0xfc,0xff,0xff,0xff,0x44,0x33,0x22,0x11},10,2,4,0},
 {"trailing byte",{0x80,0x3d,0xff,0xff,0xff,0xff,1},7,2,4,0},
 {"import cell",{0xff,0x15,0,0,0,0},6,2,4,0},
 {"tls member",{0x48,0x8b,0x80,40,0,0,0},7,3,11,40},
 {"tls store",{0xc7,0x80,40,0,0,0,0x44,0x33,0x22,0x11},10,2,11,40},
 {"negative member",{0x48,0x8b,0x80,0xf8,0xff,0xff,0xff},7,3,11,-8},
 {"minimum addend",{0xe8,0,0,0,0x80},5,1,4,INT32_MIN},
 {"maximum addend",{0xe8,0xff,0xff,0xff,0x7f},5,1,4,INT32_MAX},
 {"maximum with tail",{0xc7,0x05,0xff,0xff,0xff,0x7f,1,0,0,0},10,2,4,INT64_C(2147483651)}
};
static int instruction_relocation_cases(void** owner,void** cancellation){
 struct inspection state;struct failure failure;
 for(size_t i=0;i<sizeof instruction_relocation_vectors/sizeof instruction_relocation_vectors[0];++i){
  const struct instruction_relocation_case* v=&instruction_relocation_vectors[i];
  CHECK(replace(owner,v->bytes,v->length)==0);inspection_defaults(&state);struct instruction ins;
  CHECK(read_instruction(owner,0,v->length,&state,&ins,NULL,&failure) && ins.length==v->length);
  struct instruction original=ins;
  for(int kind=v->kind;kind<=(v->kind==11?11:9);++kind){
   int64_t first=UINT32_MAX-v->length;struct object_relocation rel={first+v->field,UINT32_MAX,kind,4,kind==11?0:kind};struct object_relocation saved=rel;
   int64_t expected=v->offset-(kind==11?0:kind-4),result=INT64_C(0x123456789ABCDEF);
   inspection_defaults(&state);state.maximum_bytes=0;state.maximum_events=1;ube_err_set(77,"prior","instruction relocation");inventory_observe(0);
   int ok=instruction_relocation_offset(&ins,first,&rel,&state,&result,NULL,&failure);inventory_observation_end();
   CHECK(ok && result==expected && failure.code==0 && failure.resource==0);
   CHECK(state.bytes==0 && state.events==1 && inventory_events==1 && inventory_bytes==0 && byte_visits==0 && inventory_allocation_visits==0 && copies==0 && ube_err_number()==77);
   CHECK(same_instruction(&ins,&original) && memcmp(&rel,&saved,sizeof rel)==0 && memcmp(payload(*owner),v->bytes,v->length)==0);
   inspection_defaults(&state);state.maximum_events=0;result=123;CHECK(!instruction_relocation_offset(&ins,first,&rel,&state,&result,NULL,&failure) && failure.code==1502 && failure.resource==7 && result==123 && state.events==0);
   CHECK(make_cancel(cancellation));*(bool*)*cancellation=true;inspection_defaults(&state);result=123;CHECK(!instruction_relocation_offset(&ins,first,&rel,&state,&result,*cancellation,&failure) && failure.code==1507 && result==123 && state.events==0);*cancellation=NULL;
   for(int defect=0;defect<8;++defect){rel=saved;int64_t start=first;int code=1506;
    if(defect==0)--rel.offset;if(defect==1)++rel.offset;if(defect==2)rel.width=3;
    if(defect==3){rel.kind=kind==11?4:11;rel.relative_end=kind==11?4:0;}
    if(defect==4)++rel.relative_end;if(defect==5){rel.kind=0;rel.relative_end=0;}
    if(defect==6){start=-1;code=1509;}if(defect==7){rel.target=-1;code=1509;}if(rel.offset>UINT32_MAX-4)code=1509;
    inspection_defaults(&state);result=123;CHECK(!instruction_relocation_offset(&ins,start,&rel,&state,&result,NULL,&failure) && failure.code==code && result==123);
   }
  }
 }
 /* Reject forged descriptor shapes and incompatible bases independently of bytes. */
 const unsigned char code[]={0x48,0x8b,0x05,0,0,0,0};CHECK(replace(owner,code,sizeof code)==0);inspection_defaults(&state);struct instruction ins;CHECK(read_instruction(owner,0,7,&state,&ins,NULL,&failure));struct instruction saved=ins;
 struct object_relocation rel={103,1,4,4,4};
 for(int defect=0;defect<17;++defect){ins=saved;int expected=1509;int64_t first=100;
  if(defect==0)ins.length=0;if(defect==1)ins.length=16;if(defect==2)ins.flow=8;
  if(defect==3)ins.displacement_bytes=3;if(defect==4)ins.displacement_first=0;if(defect==5)ins.displacement_first=4;
  if(defect==6)ins.immediate_bytes=3;if(defect==7)ins.immediate_first=1;
  if(defect==8){ins.immediate_bytes=4;ins.immediate_first=3;}
  if(defect==9)ins.displacement=INT64_C(2147483648);if(defect==10)ins.displacement=INT64_C(-2147483649);
  if(defect==11){ins.index=1;expected=1506;}if(defect==12){ins.base=0;expected=1506;}
  if(defect==13){ins.segment=101;expected=1506;}if(defect==14){ins.flow=1;expected=1506;}
  if(defect==15)first=UINT32_MAX-6;if(defect==16)first=INT64_MAX;
  inspection_defaults(&state);int64_t result=123;CHECK(!instruction_relocation_offset(&ins,first,&rel,&state,&result,NULL,&failure) && failure.code==expected && result==123);
 }
 ins=saved;inspection_defaults(&state);int64_t result=123;ube_gc_test_fail_next_allocations(1000000);inventory_observe(0);CHECK(instruction_relocation_offset(&ins,100,&rel,&state,&result,NULL,&failure) && result==0);inventory_observation_end();ube_gc_test_fail_next_allocations(0);CHECK(inventory_allocation_visits==0 && copies==0);
 size_t available=UBE_GC_MAX_ROOTS-ube_gc_root_count;struct ube_gc_root* pressure=calloc(available,sizeof *pressure);void* nil=NULL;CHECK(pressure);for(size_t n=0;n<available;++n)CHECK(ube_gc_root_enter(&pressure[n],&nil));inspection_defaults(&state);result=123;CHECK(!instruction_relocation_offset(&ins,100,&rel,&state,&result,NULL,&failure) && result==123);for(size_t n=0;n<available;++n)CHECK(ube_gc_root_leave(&pressure[n]));free(pressure);
 unsigned char restore[256];symbol_bytes(restore);CHECK(replace(owner,restore,sizeof restore)==0);return 0;
}
static int inspect_instruction_relocations(void** owner,const char* object_path,const char* expected_path){
 CHECK(retention_load(owner,object_path)==0);FILE* file=fopen(expected_path,"rb");int32_t count;CHECK(file && fread(&count,4,1,file)==1 && count>0 && count<=1000000);
 struct inspection state;struct failure failure;struct layout layout;inspection_defaults(&state);CHECK(read_layout(owner,&state,&layout,NULL,&failure));
 for(int i=0;i<count;++i){int32_t fields[4];int64_t start,expected,result=INT64_MAX;CHECK(fread(fields,sizeof fields,1,file)==1 && fread(&start,8,1,file)==1 && fread(&expected,8,1,file)==1);
  struct section section;struct object_relocation rel;struct instruction ins;
  CHECK(read_section(owner,&state,&layout,fields[0],&section,NULL,&failure));
  CHECK(read_relocation(owner,&state,&layout,&section,fields[1],&rel,NULL,&failure));
  CHECK((int64_t)section.raw_first+start==fields[2]);
  CHECK(read_instruction(owner,fields[2],fields[3],&state,&ins,NULL,&failure) && ins.length==fields[3]);
  int ok=instruction_relocation_offset(&ins,start,&rel,&state,&result,NULL,&failure);
  if(!ok)fprintf(stderr,"instruction relocation failure index=%d code=%d\n",i,failure.code);
  if(ok && result!=expected)fprintf(stderr,"instruction relocation mismatch index=%d actual=%lld expected=%lld\n",i,(long long)result,(long long)expected);
  CHECK(ok && result==expected);
 }
 CHECK(fgetc(file)==EOF && fclose(file)==0);printf("PASS %d independently paired instruction relocations\n",count);return 0;
}
