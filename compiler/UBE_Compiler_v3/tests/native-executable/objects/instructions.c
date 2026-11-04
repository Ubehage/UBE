struct instruction {int32_t length,flow,writes,memory_bytes,base,index,scale,memory_write,segment,displacement_first,displacement_bytes,immediate_first,immediate_bytes,target;int64_t relative,displacement;};
extern int32_t read_instruction(void**,int32_t,int32_t,struct inspection*,struct instruction*,void*,struct failure*);
static int same_instruction(const struct instruction* a,const struct instruction* b){return memcmp(a,b,14*4)==0 && a->relative==b->relative && a->displacement==b->displacement;}
struct instruction_case {const char* name;unsigned char bytes[16];int length;struct instruction expected;};
static const struct instruction_case instruction_vectors[]={
 {"immediate eax",{0xb8,0x7,0x0,0x0,0x0},5,{5,0,1,0,-1,-1,0,0,0,0,0,1,4,-1,0LL,0LL}},
 {"return",{0xc3},1,{1,1,0,0,-1,-1,0,0,0,0,0,0,0,-1,0LL,0LL}},
 {"register move",{0x89,0xc1},2,{2,0,2,0,-1,-1,0,0,0,0,0,0,0,-1,0LL,0LL}},
 {"tls address",{0x65,0x48,0x8b,0x4,0x25,0x58,0x0,0x0,0x0},9,{9,0,1,8,-3,-1,1,0,101,5,4,0,0,-1,0LL,88LL}},
 {"extended sib",{0x4d,0x8b,0xc,0xc1},4,{4,0,512,8,9,0,8,0,0,0,0,0,0,-1,0LL,0LL}},
 {"rip store",{0xc7,0x5,0xfc,0xff,0xff,0xff,0x3,0x0,0x0,0x0},10,{10,0,0,4,-2,-1,1,1,0,2,4,6,4,-1,0LL,-4LL}},
 {"ah immediate",{0xb4,0x3},2,{2,0,1,0,-1,-1,0,0,0,0,0,1,1,-1,0LL,0LL}},
 {"spl immediate",{0x40,0xb4,0x3},3,{3,0,16,0,-1,-1,0,0,0,0,0,2,1,-1,0LL,0LL}},
 {"r12b immediate",{0x41,0xb4,0x3},3,{3,0,4096,0,-1,-1,0,0,0,0,0,2,1,-1,0LL,0LL}},
 {"maximum nop",{0x66,0x66,0x66,0x66,0x66,0x66,0x2e,0xf,0x1f,0x84,0x0,0x0,0x0,0x0,0x0},15,{15,0,0,0,0,0,1,0,46,11,4,0,0,-1,0LL,0LL}},
 {"backward jump",{0xeb,0xb2},2,{2,3,0,0,-1,-1,0,0,0,0,0,1,1,-1,-78LL,0LL}},
 {"short condition",{0x74,0x72},2,{2,2,0,0,-1,-1,0,0,0,0,0,1,1,-1,114LL,0LL}},
 {"long condition",{0xf,0x85,0x20,0x0,0x0,0x0},6,{6,2,0,0,-1,-1,0,0,0,0,0,2,4,-1,32LL,0LL}},
 {"positive call",{0xe8,0xff,0xff,0xff,0x7f},5,{5,4,16,0,-1,-1,0,0,0,0,0,1,4,-1,2147483647LL,0LL}},
 {"negative jump",{0xe9,0x0,0x0,0x0,0x80},5,{5,3,0,0,-1,-1,0,0,0,0,0,1,4,-1,-2147483648LL,0LL}},
 {"increment",{0x48,0xff,0xc1},3,{3,0,2,0,-1,-1,0,0,0,0,0,0,0,-1,0LL,0LL}},
 {"indirect call",{0xff,0xd0},2,{2,5,16,0,-1,-1,0,0,0,0,0,0,0,0,0LL,0LL}},
 {"r13 indirect call",{0x41,0xff,0xd5},3,{3,5,16,0,-1,-1,0,0,0,0,0,0,0,13,0LL,0LL}},
 {"rsi indirect call",{0xff,0xd6},2,{2,5,16,0,-1,-1,0,0,0,0,0,0,0,6,0LL,0LL}},
 {"r11 indirect jump",{0x41,0xff,0xe3},3,{3,6,0,0,-1,-1,0,0,0,0,0,0,0,11,0LL,0LL}},
 {"rip indirect call",{0xff,0x15,0,0,0,0},6,{6,5,16,8,-2,-1,1,0,0,2,4,0,0,-1,0LL,0LL}},
 {"indirect jump",{0xff,0xe0},2,{2,6,0,0,-1,-1,0,0,0,0,0,0,0,0,0LL,0LL}},
 {"push memory",{0xff,0x30},2,{2,0,16,8,0,-1,1,0,0,0,0,0,0,-1,0LL,0LL}},
 {"pop memory",{0x8f,0x0},2,{2,0,16,8,0,-1,1,1,0,0,0,0,0,-1,0LL,0LL}},
 {"push word memory",{0x66,0xff,0x30},3,{3,0,16,2,0,-1,1,0,0,0,0,0,0,-1,0LL,0LL}},
 {"pop word memory",{0x66,0x8f,0x0},3,{3,0,16,2,0,-1,1,1,0,0,0,0,0,-1,0LL,0LL}},
 {"word immediate",{0x66,0xc7,0x0,0x34,0x12},5,{5,0,0,2,0,-1,1,1,0,0,0,3,2,-1,0LL,0LL}},
 {"sign extended immediate",{0x48,0xc7,0xc0,0xff,0xff,0xff,0xff},7,{7,0,1,0,-1,-1,0,0,0,0,0,3,4,-1,0LL,0LL}},
 {"wide immediate",{0x48,0xb8,0xff,0xff,0xc3,0xff,0xff,0xff,0xff,0xff},10,{10,0,1,0,-1,-1,0,0,0,0,0,2,8,-1,0LL,0LL}},
 {"absolute word load",{0xf,0xb7,0x4,0x25,0xff,0xff,0xff,0xff},8,{8,0,1,2,-3,-1,1,0,0,4,4,0,0,-1,0LL,-1LL}},
 {"r13 shift",{0x49,0xc1,0xe5,0x4},4,{4,0,8192,0,-1,-1,0,0,0,0,0,3,1,-1,0LL,0LL}},
 {"conditional move",{0xf,0x45,0xc1},3,{3,0,1,0,-1,-1,0,0,0,0,0,0,0,-1,0LL,0LL}},
 {"set ah",{0xf,0x95,0xc4},3,{3,0,1,0,-1,-1,0,0,0,0,0,0,0,-1,0LL,0LL}},
 {"set spl",{0x40,0xf,0x95,0xc4},4,{4,0,16,0,-1,-1,0,0,0,0,0,0,0,-1,0LL,0LL}},
 {"word divide",{0xf7,0xf9},2,{2,0,5,0,-1,-1,0,0,0,0,0,0,0,-1,0LL,0LL}},
 {"byte divide",{0xf6,0xf9},2,{2,0,1,0,-1,-1,0,0,0,0,0,0,0,-1,0LL,0LL}},
 {"breakpoint trap",{0xcc},1,{1,7,0,0,-1,-1,0,0,0,0,0,0,0,-1,0LL,0LL}},
 {"undefined trap",{0xf,0xb},2,{2,7,0,0,-1,-1,0,0,0,0,0,0,0,-1,0LL,0LL}},
 {"push register",{0x50},1,{1,0,16,0,-1,-1,0,0,0,0,0,0,0,-1,0LL,0LL}},
 {"pop register",{0x5b},1,{1,0,24,0,-1,-1,0,0,0,0,0,0,0,-1,0LL,0LL}},
 {"leave",{0xc9},1,{1,0,48,0,-1,-1,0,0,0,0,0,0,0,-1,0LL,0LL}},
 {"subtract stack",{0x48,0x83,0xec,0x28},4,{4,0,16,0,-1,-1,0,0,0,0,0,3,1,-1,0LL,0LL}},
 {"accumulator subtract",{0x48,0x2d,0x7,0x0,0x0,0x0},6,{6,0,1,0,-1,-1,0,0,0,0,0,2,4,-1,0LL,0LL}},
 {"register add",{0x48,0x1,0xc8},3,{3,0,1,0,-1,-1,0,0,0,0,0,0,0,-1,0LL,0LL}},
 {"exchange stack",{0x94},1,{1,0,17,0,-1,-1,0,0,0,0,0,0,0,-1,0LL,0LL}},
 {"lea displacement",{0x49,0x8d,0x42,0x1},4,{4,0,1,0,10,-1,1,0,0,3,1,0,0,-1,0LL,1LL}},
 {"byte indexed store",{0x44,0x88,0x4c,0x8,0x10},5,{5,0,0,1,0,1,1,1,0,4,1,0,0,-1,0LL,16LL}},
 {"byte extend load",{0x44,0xf,0xb6,0xc,0xa},5,{5,0,512,1,2,1,1,0,0,0,0,0,0,-1,0LL,0LL}},
 {"sign extend register",{0x48,0x63,0xc1},3,{3,0,1,0,-1,-1,0,0,0,0,0,0,0,-1,0LL,0LL}},
 {"test immediate",{0xf6,0xc1,0x1},3,{3,0,0,0,-1,-1,0,0,0,0,0,2,1,-1,0LL,0LL}},
 {"negate memory",{0x48,0xf7,0x18},3,{3,0,0,8,0,-1,1,1,0,0,0,0,0,-1,0LL,0LL}},
 {"multiply immediate",{0x6b,0xc1,0x3},3,{3,0,1,0,-1,-1,0,0,0,0,0,2,1,-1,0LL,0LL}},
 {"shift count register",{0xd3,0xe0},2,{2,0,1,0,-1,-1,0,0,0,0,0,0,0,-1,0LL,0LL}},
 {"test accumulator",{0xa9,0xff,0xff,0xff,0xff},5,{5,0,0,0,-1,-1,0,0,0,0,0,1,4,-1,0LL,0LL}},
 {"extend accumulator",{0x48,0x98},2,{2,0,1,0,-1,-1,0,0,0,0,0,0,0,-1,0LL,0LL}},
 {"extend dividend",{0x48,0x99},2,{2,0,4,0,-1,-1,0,0,0,0,0,0,0,-1,0LL,0LL}},
 {"sib extended index",{0x4a,0x8b,0x4,0x20},4,{4,0,1,8,0,12,1,0,0,0,0,0,0,-1,0LL,0LL}},
};
static int instruction_cases(void** owner,void** cancellation){
 CHECK(sizeof(struct instruction)==72 && offsetof(struct instruction,relative)==56);unsigned char bytes[64];struct inspection state;struct failure failure;struct instruction result,saved;memset(&saved,0xA5,sizeof saved);
 for(size_t i=0;i<sizeof instruction_vectors/sizeof instruction_vectors[0];++i){memset(bytes,0xCC,sizeof bytes);memcpy(bytes+3,instruction_vectors[i].bytes,instruction_vectors[i].length);CHECK(replace(owner,bytes,sizeof bytes)==0);inspection_defaults(&state);inventory_observe(1);ube_err_set(77,"prior","instruction");CHECK(read_instruction(owner,3,instruction_vectors[i].length,&state,&result,NULL,&failure));inventory_observation_end();if(!same_instruction(&result,&instruction_vectors[i].expected))fprintf(stderr,"instruction oracle case=%s length=%d flow=%d writes=%d base=%d index=%d memory=%d segment=%d\n",instruction_vectors[i].name,result.length,result.flow,result.writes,result.base,result.index,result.memory_bytes,result.segment);if(!same_instruction(&result,&instruction_vectors[i].expected)){int32_t actual[14],wanted[14];memcpy(actual,&result,sizeof actual);memcpy(wanted,&instruction_vectors[i].expected,sizeof wanted);for(int k=0;k<14;++k)fprintf(stderr," field%d=%d expected=%d",k,actual[k],wanted[k]);fprintf(stderr," rel=%lld/%lld disp=%lld/%lld\n",(long long)result.relative,(long long)instruction_vectors[i].expected.relative,(long long)result.displacement,(long long)instruction_vectors[i].expected.displacement);}CHECK(same_instruction(&result,&instruction_vectors[i].expected));int64_t required_bytes=instruction_vectors[i].length,required_events=required_bytes-(result.displacement_bytes?result.displacement_bytes-1:0)-(result.immediate_bytes?result.immediate_bytes-1:0);CHECK(failure.code==0 && state.bytes==required_bytes && state.events==required_events && byte_visits==required_bytes && inventory_bytes==required_bytes && inventory_events==required_events && inventory_allocation_visits==0 && copies==0 && ube_err_number()==77 && memcmp(payload(*owner),bytes,sizeof bytes)==0);
  for(int n=1;n<instruction_vectors[i].length;++n){inspection_defaults(&state);result=saved;inventory_observe(0);CHECK(!read_instruction(owner,3,n,&state,&result,NULL,&failure));inventory_observation_end();CHECK(failure.code==1506 && memcmp(&result,&saved,sizeof result)==0 && state.bytes<=n && state.bytes==byte_visits && state.bytes==inventory_bytes && state.events==inventory_events);}
  for(int domain=0;domain<2;++domain)for(int delta=-1;delta<=0;++delta){inspection_defaults(&state);if(domain)state.maximum_events=required_events+delta;else state.maximum_bytes=required_bytes+delta;result=saved;inventory_observe(0);int ok=read_instruction(owner,3,instruction_vectors[i].length,&state,&result,NULL,&failure);inventory_observation_end();CHECK(ok==(delta==0) && state.bytes==byte_visits && state.bytes==inventory_bytes && state.events==inventory_events);if(!ok)CHECK(failure.code==1502 && failure.resource==7 && memcmp(&result,&saved,sizeof result)==0);}
  CHECK(make_cancel(cancellation));inventory_cancel_flag=(bool*)*cancellation;for(int64_t at=1;at<=required_events;++at){inspection_defaults(&state);*inventory_cancel_flag=false;inventory_cancel_at=at;result=saved;inventory_observe(0);int ok=read_instruction(owner,3,instruction_vectors[i].length,&state,&result,*cancellation,&failure);inventory_observation_end();CHECK(!ok && failure.code==1507 && memcmp(&result,&saved,sizeof result)==0 && state.events==at-1 && state.events==inventory_events && state.bytes==inventory_bytes && state.bytes==byte_visits);}inventory_cancel_flag=NULL;inventory_cancel_at=0;*cancellation=NULL;
 }
 const unsigned char bad[][20]={{0x66,0xcc},{0x40,0xcc},{0x48,0xcc},{0x65,0xcc},{0x2e,0xcc},{0xf3,0xcc},{0xf0,0xcc},{0xcd,3},{0xF0,0x90},{0xF3,0xC3},{0x67,0x8B,0},{0x0F,0xFF},{0x0F,0x1F,0xC8},{0xC6,0xC8,1},{0xF6,0xC8},{0xD1,0xF0},{0xFF,0xD8},{0xFF,0xE8},{0xFE,0xE0},{0x8F,0xC8},{0x48,0x8D,0xC0},{0x44,0x83,0xC0,1},{0x44,0x48,0x90},{0x48,0x66,0x90},{0x65,0x65,0x90},{0x65,0x90},{0x2E,0x8B,0xC0},{0x66,0xE9,0,0,0,0},{0x63,0xC0},{0xEF},{0xC2,0,0},{0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x90}};
 for(size_t i=0;i<sizeof bad/sizeof bad[0];++i){CHECK(replace(owner,bad[i],sizeof bad[i])==0);inspection_defaults(&state);result=saved;CHECK(!read_instruction(owner,0,sizeof bad[i],&state,&result,NULL,&failure) && failure.code==1506 && memcmp(&result,&saved,sizeof result)==0 && state.bytes<=15);}
 memset(bytes,0x90,sizeof bytes);CHECK(replace(owner,bytes,sizeof bytes)==0);const int bounds[][2]={{-1,1},{0,0},{64,1},{0,65},{INT32_MAX,1},{1,INT32_MAX}};for(size_t i=0;i<sizeof bounds/sizeof bounds[0];++i){inspection_defaults(&state);result=saved;CHECK(!read_instruction(owner,bounds[i][0],bounds[i][1],&state,&result,NULL,&failure) && failure.code==1509 && memcmp(&result,&saved,sizeof result)==0);}
 size_t available=UBE_GC_MAX_ROOTS-ube_gc_root_count;struct ube_gc_root* pressure=calloc(available,sizeof *pressure);void* nil=NULL;CHECK(pressure);for(size_t n=0;n<available;++n)CHECK(ube_gc_root_enter(&pressure[n],&nil));inspection_defaults(&state);result=saved;CHECK(!read_instruction(owner,0,1,&state,&result,NULL,&failure) && memcmp(&result,&saved,sizeof result)==0);for(size_t n=0;n<available;++n)CHECK(ube_gc_root_leave(&pressure[n]));free(pressure);
 unsigned char restore[256];symbol_bytes(restore);CHECK(replace(owner,restore,sizeof restore)==0);return 0;
}
static int inspect_instructions(void** owner,const char* object_path,const char* expected_path,int leaf_only){
 CHECK(retention_load(owner,object_path)==0);FILE* file=fopen(expected_path,"rb");int32_t count;CHECK(file && fread(&count,sizeof count,1,file)==1 && count>0 && count<=1000000);struct inspection state;struct failure failure;inspection_defaults(&state);
 for(int i=0;i<count;++i){int32_t fields[3],target;int64_t relative;CHECK(fread(fields,sizeof fields,1,file)==1 && fread(&relative,sizeof relative,1,file)==1 && fread(&target,4,1,file)==1);struct instruction result;int ok=read_instruction(owner,fields[0],fields[1],&state,&result,NULL,&failure);if(!ok)fprintf(stderr,"instruction failure index=%d first=%d count=%d code=%d\n",i,fields[0],fields[1],failure.code);if(ok && (result.length!=fields[1] || result.flow!=fields[2] || result.relative!=relative || result.target!=target))fprintf(stderr,"instruction mismatch index=%d first=%d\n",i,fields[0]);CHECK(ok && result.length==fields[1] && result.flow==fields[2] && result.relative==relative && result.target==target && (!leaf_only || (result.writes&0xF0F8)==0));}
 CHECK(fgetc(file)==EOF && fclose(file)==0);printf("PASS %d independently decoded %s instructions\n",count,leaf_only?"leaf":"code");return 0;
}
