extern int32_t validate_code(struct retained_definition*,struct inventory*,void**,struct layout*,struct inventory*,void**,struct layout*,struct inspection*,struct retained_definition*,void*,struct failure*);
extern int32_t isolate_contribution(void**,struct layout*,struct definition_range*,struct inspection*,void*,struct failure*);
extern int32_t compare_native_bytes(void**,int32_t,void**,int32_t,int32_t,struct inspection*,bool*,void*,struct failure*);
static void code_bytes(unsigned char* ob,unsigned char* ib,int variant){
 retention_bytes(ob,1,1);retention_bytes(ib,2,1);memset(ib+1024,0,1024);put(ob,56,0x60500020,4);
 int base=variant==3?64:variant==5?0:32,anchor=variant==4?63:variant==5?0:16;
 put(ob,168,anchor,4);put(ib,908,base+anchor,4);put(ib,336,base+64,4);
 for(int j=0;j<64;++j)ob[60+j]=(unsigned char)(j*13+7);
 if(variant){put(ob,64,0,4);put(ob,72,0,4);put(ob,44,128,4);put(ob,52,variant==2?3:2,2);int first=128;if(variant==2){put(ob,128,UINT32_MAX,4);put(ob,132,UINT32_MAX,4);put(ob,136,0,2);first+=10;}put(ob,first,4,4);put(ob,first+4,0,4);put(ob,first+8,4,2);put(ob,first+10,12,4);put(ob,first+14,0,4);put(ob,first+18,11,2);}
 memcpy(ib+512+base,ob+60,64);
 if(variant){put(ib,512+base+4,variant==4?55:variant==5?0xfffffff8u:8,4);put(ib,512+base+12,variant==3?80:variant==4?95:variant==5?0:48,4);}
 if(variant==3)constant_extra_section(ib,0);
}
static int code_anchor(void** object,void** image,void** names,struct layout* ol,struct layout* il,struct inventory_env* a,struct inventory_env* b,struct retained_definition* anchor){
 CHECK(retention_prepare(a,object,ol)==0 && retention_prepare(b,image,il)==0);struct expected_definition expected={{0,5},0,0,3,1,1,0,0,0};struct inspection state;struct failure failure;inspection_defaults(&state);CHECK(bind_definition(&expected,names,&a->value,object,ol,&b->value,image,il,&state,anchor,NULL,&failure));return 0;
}
static int code_cases(void** object,void** cancellation){
 void* image=NULL;void* names=NULL;struct ube_gc_root roots[2]={{0}};CHECK(ube_gc_root_enter(&roots[0],&image) && ube_gc_root_enter(&roots[1],&names) && replace(&names,"table",5)==0);
 unsigned char ob[1024],ib[2048];struct layout ol,il;struct inventory_env a,b;struct inspection state;struct failure failure;struct retained_definition anchor,result,saved;memset(&saved,0xa5,sizeof saved);
 for(int variant=0;variant<6;++variant){
  code_bytes(ob,ib,variant);CHECK(replace(object,ob,sizeof ob)==0 && replace(&image,ib,sizeof ib)==0 && code_anchor(object,&image,&names,&ol,&il,&a,&b,&anchor)==0);struct retained_definition old_anchor=anchor;
  int base=variant==3?64:variant==5?0:32;inspection_defaults(&state);inventory_observe(1);ube_err_set(77,"prior","code");result=saved;
  CHECK(validate_code(&anchor,&a.value,object,&ol,&b.value,&image,&il,&state,&result,NULL,&failure));inventory_observation_end();
  CHECK(result.present==1 && result.object.symbol==-1 && result.object.section==0 && result.object.first==60 && result.object.count==64 && result.object.initialized==64 && result.object.type==32 && result.object.offset==0 && result.object.rva==0 && result.object.address==0 && result.object.characteristics==0x60500020);
  CHECK(result.image.symbol==-1 && result.image.section==0 && result.image.first==512+base && result.image.count==64 && result.image.initialized==64 && result.image.type==32 && result.image.offset==base && result.image.rva==4096+base && result.image.address==0x140001000LL+base && result.image.characteristics==0x60000020);
  CHECK(failure.code==0 && failure.resource==0 && state.bytes==byte_visits && state.bytes==inventory_bytes && state.events==inventory_events && inventory_allocation_visits==0 && copies==0 && ube_err_number()==77 && memcmp(payload(*object),ob,sizeof ob)==0 && memcmp(payload(image),ib,sizeof ib)==0 && memcmp(&anchor,&old_anchor,sizeof anchor)==0);
  int64_t required_bytes=state.bytes,required_events=state.events;CHECK(required_bytes>=248 && required_bytes<2000 && required_events<500);
  for(int byte=0;byte<64;++byte){payload(image)[512+base+byte]^=1;inspection_defaults(&state);result=saved;CHECK(!validate_code(&anchor,&a.value,object,&ol,&b.value,&image,&il,&state,&result,NULL,&failure) && failure.code==1506 && memcmp(&result,&saved,sizeof result)==0);payload(image)[512+base+byte]^=1;}
  for(int domain=0;domain<2;++domain)for(int delta=-1;delta<=0;++delta){inspection_defaults(&state);if(domain)state.maximum_events=required_events+delta;else state.maximum_bytes=required_bytes+delta;result=saved;inventory_observe(0);int ok=validate_code(&anchor,&a.value,object,&ol,&b.value,&image,&il,&state,&result,NULL,&failure);inventory_observation_end();CHECK(ok==(delta==0) && state.bytes==byte_visits && state.bytes==inventory_bytes && state.events==inventory_events);if(!ok)CHECK(failure.code==1502 && failure.resource==7 && memcmp(&result,&saved,sizeof result)==0);}
  CHECK(make_cancel(cancellation));inventory_cancel_flag=(bool*)*cancellation;
  for(int64_t at=1;at<=required_events;++at){inspection_defaults(&state);*inventory_cancel_flag=false;inventory_cancel_at=at;result=saved;inventory_observe(0);int ok=validate_code(&anchor,&a.value,object,&ol,&b.value,&image,&il,&state,&result,*cancellation,&failure);inventory_observation_end();CHECK(!ok && failure.code==1507 && state.events==at-1 && state.events==inventory_events && state.bytes==inventory_bytes && state.bytes==byte_visits && memcmp(&result,&saved,sizeof result)==0);}
  inventory_cancel_flag=NULL;inventory_cancel_at=0;*cancellation=NULL;
  for(int defect=0;defect<18;++defect){struct retained_definition wrong=anchor;struct layout old_ol=ol,old_il=il;int as=a.value.status,bs=b.value.status;
   switch(defect){case 0:wrong.present=0;break;case 1:wrong.object.type=0;break;case 2:wrong.image.type=0;break;case 3:wrong.object.count=2;break;case 4:wrong.image.count=2;break;case 5:wrong.object.initialized=0;break;case 6:wrong.image.initialized=0;break;case 7:ol.kind=2;break;case 8:il.kind=1;break;case 9:++ol.length;break;case 10:++il.length;break;case 11:a.value.status=4;break;case 12:b.value.status=4;break;case 13:++ol.symbol_count;break;case 14:++il.symbol_count;break;case 15:wrong.object.symbol=-1;break;case 16:wrong.image.symbol=-1;break;case 17:wrong.object.offset=-1;break;}
   inspection_defaults(&state);result=saved;CHECK(!validate_code(&wrong,&a.value,object,&ol,&b.value,&image,&il,&state,&result,NULL,&failure) && failure.code==1509 && memcmp(&result,&saved,sizeof result)==0);ol=old_ol;il=old_il;a.value.status=as;b.value.status=bs;
  }
  if(variant==0){size_t n=UBE_GC_MAX_ROOTS-ube_gc_root_count;struct ube_gc_root* pressure=calloc(n,sizeof *pressure);void* nil=NULL;CHECK(pressure);for(size_t j=0;j<n;++j)CHECK(ube_gc_root_enter(&pressure[j],&nil));inspection_defaults(&state);result=saved;CHECK(!validate_code(&anchor,&a.value,object,&ol,&b.value,&image,&il,&state,&result,NULL,&failure) && memcmp(&result,&saved,sizeof result)==0);for(size_t j=0;j<n;++j)CHECK(ube_gc_root_leave(&pressure[j]));free(pressure);}
  CHECK(inventory_close(&b)==0 && inventory_close(&a)==0);
 }
 for(int defect=0;defect<21;++defect){
  code_bytes(ob,ib,1);
  switch(defect){
  case 0:put(ob,138,6,4);break;case 1:put(ob,138,0,4);break;case 2:put(ob,128,61,4);break;
  case 3:put(ob,136,12,2);break;case 4:put(ob,132,1,4);break;case 5:ob[64]=1;break;
  case 6:put(ob,44,80,4);break;case 7:put(ob,56,0x60501020,4);break;case 8:put(ob,56,0x62500020,4);break;
  case 9:put(ob,56,0x60500220,4);break;case 10:put(ob,56,0x60500820,4);break;case 11:put(ob,56,0x60500060,4);break;
  case 12:put(ob,56,0x60000020,4);break;case 13:put(ob,56,0x60f00020,4);break;
  case 14:put(ib,908,49,4);break;case 15:put(ib,336,80,4);break;case 16:put(ib,364,0x62000020,4);break;
  case 17:constant_extra_section(ib,1);break;case 18:constant_extra_section(ib,2);break;
  case 19:put(ob,36,65,4);break;
  case 20:code_bytes(ob,ib,0);memcpy(ob+256,ob+60,64);memcpy(ob+512,ob+160,22);put(ob,8,512,4);put(ob,2,2,2);put(ob,40,256,4);memset(ob+60,0,40);memcpy(ob+60,".alias",6);put(ob,76,64,4);put(ob,80,256,4);put(ob,96,0x40000040,4);break;
  }
  CHECK(replace(object,ob,sizeof ob)==0 && replace(&image,ib,sizeof ib)==0 && code_anchor(object,&image,&names,&ol,&il,&a,&b,&anchor)==0);inspection_defaults(&state);result=saved;int ok=validate_code(&anchor,&a.value,object,&ol,&b.value,&image,&il,&state,&result,NULL,&failure);if(ok || failure.code!=1506)fprintf(stderr,"code defect=%d ok=%d code=%d\n",defect,ok,failure.code);CHECK(!ok && failure.code==1506 && memcmp(&result,&saved,sizeof result)==0);CHECK(inventory_close(&b)==0 && inventory_close(&a)==0);
 }
 /* Independent isolation checks include metadata aliases and caller overflow. */
 code_bytes(ob,ib,0);CHECK(replace(object,ob,sizeof ob)==0 && replace(&image,ib,sizeof ib)==0 && code_anchor(object,&image,&names,&ol,&il,&a,&b,&anchor)==0);
 struct definition_range range={-1,0,60,64,64,32,0,0,0,0x60500020};struct layout changed=ol;
 changed.symbols=120;changed.strings=120;changed.string_bytes=4;inspection_defaults(&state);CHECK(!isolate_contribution(object,&changed,&range,&state,NULL,&failure) && failure.code==1506);
 changed=ol;changed.strings=INT32_MAX;changed.string_bytes=INT32_MAX;inspection_defaults(&state);CHECK(!isolate_contribution(object,&changed,&range,&state,NULL,&failure) && failure.code==1509 && state.events==0);
 bool equal=false;inspection_defaults(&state);inventory_observe(1);CHECK(compare_native_bytes(object,60,&image,544,64,&state,&equal,NULL,&failure));inventory_observation_end();CHECK(equal && failure.code==0 && state.bytes==128 && state.events==16 && state.bytes==byte_visits && state.bytes==inventory_bytes && state.events==inventory_events && inventory_allocation_visits==0 && copies==0);
 equal=true;inspection_defaults(&state);CHECK(compare_native_bytes(object,60,&image,545,1,&state,&equal,NULL,&failure) && !equal && failure.code==0 && state.bytes==2 && state.events==2);
 equal=false;inspection_defaults(&state);CHECK(compare_native_bytes(object,1024,&image,2048,0,&state,&equal,NULL,&failure) && equal && failure.code==0 && state.bytes==0 && state.events==0);
 const int bad_spans[][3]={{-1,544,1},{60,-1,1},{1025,0,0},{0,2049,0},{1024,0,1},{0,2048,1},{0,0,-1},{INT32_MAX,INT32_MAX,INT32_MAX}};
 for(size_t i=0;i<sizeof bad_spans/sizeof bad_spans[0];++i){equal=true;inspection_defaults(&state);CHECK(!compare_native_bytes(object,bad_spans[i][0],&image,bad_spans[i][1],bad_spans[i][2],&state,&equal,NULL,&failure) && equal && failure.code==1509 && state.bytes==0 && state.events==0);}
 equal=true;inspection_defaults(&state);state.maximum_bytes=1;CHECK(!compare_native_bytes(object,60,&image,544,1,&state,&equal,NULL,&failure) && equal && failure.code==1502 && failure.resource==7 && state.bytes==1 && state.events==1);
 CHECK(make_cancel(cancellation));*(bool*)*cancellation=true;equal=true;inspection_defaults(&state);CHECK(!compare_native_bytes(object,60,&image,544,1,&state,&equal,*cancellation,&failure) && equal && failure.code==1507 && state.events==0);*cancellation=NULL;
 CHECK(inventory_close(&b)==0 && inventory_close(&a)==0);image=names=NULL;CHECK(ube_gc_root_leave(&roots[1]) && ube_gc_root_leave(&roots[0]));unsigned char restore[256];symbol_bytes(restore);CHECK(replace(object,restore,sizeof restore)==0);return 0;
}
