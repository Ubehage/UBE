extern int32_t bind_constant(int32_t,struct inventory*,void**,struct layout*,void**,struct layout*,struct inspection*,struct retained_definition*,void*,struct failure*);
static void constant_bytes(unsigned char* ob,unsigned char* ib,int length,int offset,int alignment){
 binding_bytes(ob,1);memcpy(ob+20,".rdata\0\0",8);memset(ob+160,0,36);memcpy(ob+160,".rdata",6);put(ob,12,2,4);put(ob,36,length,4);put(ob,56,0x40000040u|((unsigned)alignment<<20),4);put(ob,172,1,2);put(ob,176,3,1);put(ob,177,1,1);put(ob,178,length,4);put(ob,186,0x12345678,4);put(ob,190,1,2);put(ob,196,4,4);
 binding_bytes(ib,2);memset(ib+1024,0,1024);memcpy(ib+328,".rdata\0\0",8);memset(ib+512,0xcc,64);for(int j=0;j<length;++j){ob[60+j]=(unsigned char)(0x80+3*j);ib[512+offset+j]=ob[60+j];}
}
static void constant_extra_section(unsigned char* ib,int variant){
 put(ib,70,2,2);put(ib,144,12288,4);memcpy(ib+368,".other\0\0",8);put(ib,376,variant==0?0:64,4);put(ib,380,variant==0 || variant==2?4096:8192,4);put(ib,384,variant==0?0:512,4);put(ib,388,variant==0?0:variant==1?512:1024,4);put(ib,404,0xC0000040,4);
}
static int constant_binding_cases(void** object,void** cancellation){
 void* image=NULL;struct ube_gc_root image_root={0};CHECK(ube_gc_root_enter(&image_root,&image));unsigned char ob[1024],ib[2048];struct retained_definition result,saved;memset(&saved,0xa5,sizeof saved);struct inspection state;struct failure failure;struct layout ol,il;struct inventory_env a;
 const int lengths[]={1,7,8,9,31,9,9,9,9};
 for(int variant=0;variant<9;++variant){
  int length=lengths[variant],offset=variant==5?4:variant==8?64-length:3,align=variant==5?3:1;constant_bytes(ob,ib,length,offset,align);if(variant==6)put(ob,190,0,2);if(variant==7)constant_extra_section(ib,0);
  CHECK(replace(object,ob,sizeof ob)==0 && replace(&image,ib,sizeof ib)==0 && retention_prepare(&a,object,&ol)==0);inspection_defaults(&state);CHECK(read_layout(&image,&state,&il,NULL,&failure));
  inspection_defaults(&state);inventory_observe(1);ube_err_set(77,"prior","constant");result=saved;CHECK(bind_constant(0,&a.value,object,&ol,&image,&il,&state,&result,NULL,&failure));inventory_observation_end();
  CHECK(result.present==1 && result.object.symbol==0 && result.object.section==0 && result.object.first==60 && result.object.count==length && result.object.initialized==length && result.object.type==0 && result.object.offset==0 && result.object.rva==0 && result.object.address==0 && result.object.characteristics==(0x40000040LL|((int64_t)align<<20)));
  CHECK(result.image.symbol==-1 && result.image.section==0 && result.image.first==512+offset && result.image.count==length && result.image.initialized==length && result.image.type==0 && result.image.offset==offset && result.image.rva==4096+offset && result.image.address==0x140001000LL+offset && result.image.characteristics==0x40000040);
  CHECK(state.bytes==byte_visits && state.bytes==inventory_bytes && state.events==inventory_events && inventory_allocation_visits==0 && copies==0 && failure.code==0 && failure.resource==0 && ube_err_number()==77 && memcmp(payload(*object),ob,sizeof ob)==0 && memcmp(payload(image),ib,sizeof ib)==0);
  int64_t required_bytes=state.bytes,required_events=state.events;CHECK(required_bytes<=5000 && required_events<=500);
  for(int domain=0;domain<2;++domain)for(int delta=-1;delta<=0;++delta){inspection_defaults(&state);if(domain)state.maximum_events=required_events+delta;else state.maximum_bytes=required_bytes+delta;result=saved;inventory_observe(0);int ok=bind_constant(0,&a.value,object,&ol,&image,&il,&state,&result,NULL,&failure);inventory_observation_end();CHECK(ok==(delta==0) && state.bytes==byte_visits && state.bytes==inventory_bytes && state.events==inventory_events);if(!ok)CHECK(failure.code==1502 && failure.resource==7 && memcmp(&result,&saved,sizeof saved)==0);}
  CHECK(make_cancel(cancellation));inventory_cancel_flag=(bool*)*cancellation;
  for(int64_t at=1;at<=required_events;++at){inspection_defaults(&state);*inventory_cancel_flag=false;inventory_cancel_at=at;result=saved;inventory_observe(0);int ok=bind_constant(0,&a.value,object,&ol,&image,&il,&state,&result,*cancellation,&failure);inventory_observation_end();CHECK(!ok && failure.code==1507 && state.events==at-1 && state.events==inventory_events && state.bytes==inventory_bytes && state.bytes==byte_visits && memcmp(&result,&saved,sizeof saved)==0);}
  inventory_cancel_flag=NULL;inventory_cancel_at=0;*cancellation=NULL;
  for(int bad=0;bad<6;++bad){struct layout old_ol=ol,old_il=il;int status=a.value.status;switch(bad){case 0:ol.kind=2;break;case 1:il.kind=1;break;case 2:++ol.length;break;case 3:++il.length;break;case 4:++ol.symbol_count;break;case 5:a.value.status=4;break;}inspection_defaults(&state);result=saved;CHECK(!bind_constant(0,&a.value,object,&ol,&image,&il,&state,&result,NULL,&failure) && failure.code==1509 && memcmp(&result,&saved,sizeof saved)==0);ol=old_ol;il=old_il;a.value.status=status;}
  if(variant==0){size_t n=UBE_GC_MAX_ROOTS-ube_gc_root_count;struct ube_gc_root* pressure=calloc(n,sizeof *pressure);void* nil=NULL;CHECK(pressure);for(size_t j=0;j<n;++j)CHECK(ube_gc_root_enter(&pressure[j],&nil));inspection_defaults(&state);result=saved;CHECK(!bind_constant(0,&a.value,object,&ol,&image,&il,&state,&result,NULL,&failure) && memcmp(&result,&saved,sizeof saved)==0);for(size_t j=0;j<n;++j)CHECK(ube_gc_root_leave(&pressure[j]));free(pressure);}
  CHECK(inventory_close(&a)==0);
 }
 for(int defect=0;defect<33;++defect){
  constant_bytes(ob,ib,9,3,1);int target=0;
  switch(defect){
  case 0:put(ob,176,2,1);break;case 1:put(ob,174,32,2);break;case 2:put(ob,168,1,4);break;
  case 3:ob[160]='x';break;case 4:put(ob,178,8,4);break;case 5:put(ob,182,1,2);break;case 6:put(ob,184,1,2);break;case 7:put(ob,190,2,2);break;case 8:ob[192]=1;break;case 9:ob[195]=1;break;
  case 10:put(ob,56,0xC0100040,4);break;case 11:put(ob,56,0x60100040,4);break;case 12:put(ob,56,0x40100060,4);break;case 13:put(ob,56,0x401000c0,4);break;case 14:put(ob,56,0x40100240,4);break;case 15:put(ob,56,0x40100840,4);break;case 16:put(ob,56,0x40101040,4);break;case 17:put(ob,56,0x42100040,4);break;
  case 18:put(ob,56,0x40000040,4);break;case 19:put(ob,56,0x40F00040,4);break;case 20:put(ob,44,128,4);put(ob,52,1,2);put(ob,136,4,2);break;case 21:put(ob,36,0,4);put(ob,40,0,4);put(ob,178,0,4);break;
  case 22:ib[515]^=1;break;case 23:put(ib,364,0xC0000040,4);break;case 24:put(ib,364,0x42000040,4);break;
  case 25:memcpy(ib+592,ib+515,9);memset(ib+515,0xcc,9);break;case 26:memcpy(ib+540,ib+515,9);break;
  case 27:memset(ob+60,'A',9);memset(ib+515,'A',10);break;case 28:put(ob,56,0x40300040,4);break;
  case 29:constant_extra_section(ib,1);break;case 30:constant_extra_section(ib,2);break;case 31:target=1;break;case 32:target=2;break;
  }
  CHECK(replace(object,ob,sizeof ob)==0 && replace(&image,ib,sizeof ib)==0 && retention_prepare(&a,object,&ol)==0);inspection_defaults(&state);CHECK(read_layout(&image,&state,&il,NULL,&failure));result=saved;int ok=bind_constant(target,&a.value,object,&ol,&image,&il,&state,&result,NULL,&failure);if(ok || failure.code!=1506)fprintf(stderr,"constant defect=%d ok=%d code=%d\n",defect,ok,failure.code);CHECK(!ok && failure.code==1506 && memcmp(&result,&saved,sizeof saved)==0);CHECK(inventory_close(&a)==0);
 }
 image=NULL;CHECK(ube_gc_root_leave(&image_root));unsigned char restore[256];symbol_bytes(restore);CHECK(replace(object,restore,sizeof restore)==0);return 0;
}
static int inspect_constant_bindings(void** object,const char* object_path,const char* image_path,const char* expected_path){
 void* image=NULL;struct ube_gc_root root={0};CHECK(ube_gc_root_enter(&root,&image) && retention_load(object,object_path)==0 && retention_load(&image,image_path)==0);struct inventory_env a;struct layout ol,il;CHECK(retention_prepare(&a,object,&ol)==0);struct inspection state;struct failure failure;inspection_defaults(&state);CHECK(read_layout(&image,&state,&il,NULL,&failure));FILE* file=fopen(expected_path,"rb");int32_t count;CHECK(file && fread(&count,4,1,file)==1 && count>0 && count<=96);int references=0;
 for(int row=0;row<count;++row){int32_t index;struct definition_range expected_object,expected_image;CHECK(fread(&index,4,1,file)==1 && fread(&expected_object,56,1,file)==1 && fread(&expected_image,56,1,file)==1);struct retained_definition result;int ok=bind_constant(index,&a.value,object,&ol,&image,&il,&state,&result,NULL,&failure);if(!ok)fprintf(stderr,"constant binding row=%d code=%d\n",row,failure.code);CHECK(ok && result.present==1 && memcmp(&result.object,&expected_object,56)==0 && memcmp(&result.image,&expected_image,56)==0);
  for(int si=0;si<ol.section_count;++si){struct section s;CHECK(read_section(object,&state,&ol,si,&s,NULL,&failure));if(!(s.characteristics&0x20000000))continue;for(int ri=0;ri<s.relocation_count;++ri){struct object_relocation r;CHECK(read_relocation(object,&state,&ol,&s,ri,&r,NULL,&failure));if(r.target==index){CHECK(r.kind==4);++references;}}}
 }
 CHECK(fgetc(file)==EOF && fclose(file)==0);printf("PASS %d constant contributions; %d code references\n",count,references);CHECK(inventory_close(&a)==0);image=NULL;CHECK(ube_gc_root_leave(&root));return 0;
}
