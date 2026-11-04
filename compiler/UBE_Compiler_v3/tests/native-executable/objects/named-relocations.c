extern int32_t resolve_named_relocation(struct object_relocation*,struct inventory*,void**,struct layout*,struct inventory*,void**,struct layout*,struct inspection*,struct definition_range*,void*,struct failure*);
static int named_relocation_cases(void** object,void** cancellation){
 void* image=NULL;struct ube_gc_root image_root={0};CHECK(ube_gc_root_enter(&image_root,&image));
 unsigned char ob[1024],ib[1024];struct definition_range result,saved;memset(&saved,0xa5,sizeof saved);struct inspection state;struct failure failure;struct layout ol,il;struct inventory_env a,b;struct object_relocation rel={0,0,4,4,4};
 for(int variant=0;variant<7;++variant){
  int function=variant==1 || variant==4 || variant==5;retention_bytes(ob,1,variant==1?1:variant==6?3:0);retention_bytes(ib,2,function?1:variant==6?3:0);put(ib,908,24,4);
  if(variant==2)put(ob,176,3,1);
  if(variant>=3 && variant<=5){put(ob,172,0,2);put(ob,168,0,4);if(variant==5)put(ob,174,32,2);}
  CHECK(replace(object,ob,1024)==0 && replace(&image,ib,1024)==0 && retention_prepare(&a,object,&ol)==0 && retention_prepare(&b,&image,&il)==0);
  inspection_defaults(&state);ube_err_set(77,"prior","relocation");inventory_observe(1);result=saved;
  CHECK(resolve_named_relocation(&rel,&a.value,object,&ol,&b.value,&image,&il,&state,&result,NULL,&failure));inventory_observation_end();
  CHECK(result.symbol==0 && result.section==0 && result.first==(variant==6?-1:536) && result.count==1 && result.initialized==(variant==6?0:1) && result.type==(function?32:0) && result.offset==24 && result.rva==4120 && result.address==0x140001018LL && result.characteristics==(function?0x60000020LL:variant==6?0xC0000080LL:0x40000040LL));
  CHECK(failure.code==0 && failure.resource==0 && state.bytes==byte_visits && state.bytes==inventory_bytes && state.events==inventory_events && inventory_allocation_visits==0 && copies==0 && ube_err_number()==77 && memcmp(payload(*object),ob,1024)==0 && memcmp(payload(image),ib,1024)==0);
  int64_t required_bytes=state.bytes,required_events=state.events;CHECK(required_bytes>0 && required_events>0);
  for(int domain=0;domain<2;++domain)for(int delta=-1;delta<=0;++delta){inspection_defaults(&state);if(domain)state.maximum_events=required_events+delta;else state.maximum_bytes=required_bytes+delta;result=saved;inventory_observe(0);int ok=resolve_named_relocation(&rel,&a.value,object,&ol,&b.value,&image,&il,&state,&result,NULL,&failure);inventory_observation_end();CHECK(ok==(delta==0) && state.bytes==inventory_bytes && state.bytes==byte_visits && state.events==inventory_events);if(!ok)CHECK(failure.code==1502 && failure.resource==7 && memcmp(&result,&saved,sizeof saved)==0);}
  CHECK(make_cancel(cancellation));inventory_cancel_flag=(bool*)*cancellation;
  for(int64_t at=1;at<=required_events;++at){inspection_defaults(&state);*inventory_cancel_flag=false;inventory_cancel_at=at;result=saved;inventory_observe(0);int ok=resolve_named_relocation(&rel,&a.value,object,&ol,&b.value,&image,&il,&state,&result,*cancellation,&failure);inventory_observation_end();CHECK(!ok && failure.code==1507 && state.events==at-1 && state.events==inventory_events && state.bytes==inventory_bytes && state.bytes==byte_visits && memcmp(&result,&saved,sizeof saved)==0);}
  inventory_cancel_flag=NULL;inventory_cancel_at=0;*cancellation=NULL;
  for(int defect=0;defect<8;++defect){struct layout old_ol=ol,old_il=il;int as=a.value.status,bs=b.value.status;switch(defect){case 0:ol.kind=2;break;case 1:il.kind=1;break;case 2:++ol.length;break;case 3:++il.length;break;case 4:++ol.symbol_count;break;case 5:++il.symbol_count;break;case 6:a.value.status=4;break;case 7:b.value.status=4;break;}inspection_defaults(&state);result=saved;CHECK(!resolve_named_relocation(&rel,&a.value,object,&ol,&b.value,&image,&il,&state,&result,NULL,&failure) && failure.code==1509 && memcmp(&result,&saved,sizeof saved)==0);ol=old_ol;il=old_il;a.value.status=as;b.value.status=bs;}
  if(variant==0){size_t n=UBE_GC_MAX_ROOTS-ube_gc_root_count;struct ube_gc_root* pressure=calloc(n,sizeof *pressure);void* nil=NULL;CHECK(pressure);for(size_t j=0;j<n;++j)CHECK(ube_gc_root_enter(&pressure[j],&nil));inspection_defaults(&state);result=saved;CHECK(!resolve_named_relocation(&rel,&a.value,object,&ol,&b.value,&image,&il,&state,&result,NULL,&failure) && memcmp(&result,&saved,sizeof saved)==0);for(size_t j=0;j<n;++j)CHECK(ube_gc_root_leave(&pressure[j]));free(pressure);}
  CHECK(inventory_close(&b)==0 && inventory_close(&a)==0);
 }
 for(int defect=0;defect<27;++defect){
  retention_bytes(ob,1,1);retention_bytes(ib,2,1);struct object_relocation changed=rel;
  switch(defect){
  case 0:put(ob,176,105,1);break;case 1:put(ob,176,0,1);break;case 2:put(ob,174,16,2);break;
  case 3:put(ob,172,65535,2);break;case 4:put(ob,172,65534,2);break;
  case 5:put(ob,172,0,2);put(ob,168,1,4);break;case 6:put(ob,172,0,2);put(ob,168,0,4);put(ob,176,3,1);break;
  case 7:case 8:put(ob,12,2,4);put(ob,177,1,1);memset(ob+178,0,18);put(ob,196,4,4);if(defect==8)changed.target=1;break;
  case 9:put(ob,12,2,4);memcpy(ob+178,ob+160,18);put(ob,196,4,4);break;
  case 10:changed.target=1;break;case 11:changed.target=-1;break;case 12:changed.kind=0;break;case 13:changed.kind=12;break;
  case 14:ib[900]='x';break;case 15:put(ib,80,2,4);memcpy(ib+918,ib+900,18);put(ib,936,4,4);break;
  case 16:put(ib,912,0,2);put(ib,908,0,4);break;case 17:put(ib,914,16,2);break;case 18:put(ib,914,0,2);break;
  case 19:put(ib,908,64,4);break;case 20:put(ib,364,0x40000020,4);break;case 21:put(ib,364,0xE0000020,4);break;
  case 22:put(ob,56,0x40000020,4);break;case 23:put(ob,56,0xE0000020,4);break;case 24:put(ob,168,64,4);break;
  case 25:put(ob,174,0,2);break;case 26:memset(ob+160,0,8);put(ob,164,4,4);put(ob,178,5,4);ob[182]=0;break;
  }
  CHECK(replace(object,ob,1024)==0 && replace(&image,ib,1024)==0 && retention_prepare(&a,object,&ol)==0 && retention_prepare(&b,&image,&il)==0);inspection_defaults(&state);result=saved;int ok=resolve_named_relocation(&changed,&a.value,object,&ol,&b.value,&image,&il,&state,&result,NULL,&failure);if(ok || failure.code!=1506)fprintf(stderr,"named target defect=%d accepted=%d code=%d\n",defect,ok,failure.code);CHECK(!ok && failure.code==1506 && memcmp(&result,&saved,sizeof saved)==0);CHECK(inventory_close(&b)==0 && inventory_close(&a)==0);
 }
 image=NULL;CHECK(ube_gc_root_leave(&image_root));unsigned char restore[256];symbol_bytes(restore);CHECK(replace(object,restore,sizeof restore)==0);return 0;
}
static int inspect_named_relocations(void** object,const char* object_path,const char* image_path,const char* expected_path){
 void* image=NULL;struct ube_gc_root root={0};CHECK(ube_gc_root_enter(&root,&image) && retention_load(object,object_path)==0 && retention_load(&image,image_path)==0);struct inventory_env a,b;struct layout ol,il;CHECK(retention_prepare(&a,object,&ol)==0 && retention_prepare(&b,&image,&il)==0);FILE* file=fopen(expected_path,"rb");int32_t count;CHECK(file && fread(&count,4,1,file)==1 && count>=0 && count<100000);
 struct inspection state;inspection_defaults(&state);struct failure failure;int accepted=0,rejected=0,observed=0;
 for(int si=0;si<ol.section_count;++si){struct section s;CHECK(read_section(object,&state,&ol,si,&s,NULL,&failure));if(!(s.characteristics&0x20000000))continue;for(int ri=0;ri<s.relocation_count;++ri){int32_t row[3];struct definition_range expected,result,saved;memset(&saved,0xa5,sizeof saved);result=saved;CHECK(fread(row,sizeof row,1,file)==1 && fread(&expected,sizeof expected,1,file)==1 && row[0]==si && row[1]==ri && (row[2]==0 || row[2]==1));struct object_relocation rel;CHECK(read_relocation(object,&state,&ol,&s,ri,&rel,NULL,&failure));int ok=resolve_named_relocation(&rel,&a.value,object,&ol,&b.value,&image,&il,&state,&result,NULL,&failure);if(ok!=row[2])fprintf(stderr,"named relocation section=%d index=%d code=%d expected=%d\n",si,ri,failure.code,row[2]);CHECK(ok==row[2]);if(ok){CHECK(memcmp(&result,&expected,sizeof expected)==0 && failure.code==0);++accepted;}else{CHECK(failure.code==1506 && memcmp(&result,&saved,sizeof saved)==0);++rejected;}++observed;}}
 CHECK(observed==count && fgetc(file)==EOF && fclose(file)==0);printf("PASS %d named targets; %d unsupported targets\n",accepted,rejected);CHECK(inventory_close(&b)==0 && inventory_close(&a)==0);image=NULL;CHECK(ube_gc_root_leave(&root));return 0;
}
