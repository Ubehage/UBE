/* Independent complete-table/RVA-order cases. No candidate symbol discovers
   an expected owner, and no observed production result supplies an oracle. */
extern int32_t validate_storage_ownership(void**,struct layout*,struct expected_definitions*,void**,void**,void**,struct inspection*,void*,struct failure*);
static const struct ube_value_layout storage_expected_layout={40,0,0,NULL,0,NULL};
static const struct ube_value_layout storage_retained_layout={120,0,0,NULL,0,NULL};
static const struct ube_value_layout storage_order_layout={4,0,0,NULL,0,NULL};
struct storage_fixture {
 struct expected_definitions expected;
 void* retained;void* order;void* protected;
 struct ube_gc_root roots[5];
};
static const int32_t storage_rva_order[]={5,2,9,0,4,8,7,1};
static const int64_t storage_protected_views[]={4160,16,4160,8,4168,8,4400,8};
static const struct expected_oracle storage_rows[]={
 {"ube.g0",0,0,3,2,0,8,5,5},
 {"ube_thread_error",6,-1,-1,22,1,784,0,0},
 {"ube.stack.reserve",5,-1,-1,16,1,8,0,0},
 {"ube.f1",0,0,4,1,1,0,0,0},
 {"ube.module.states",3,-1,-1,9,1,3,0,0},
 {"ube.module.initializers",3,-1,-1,11,1,24,0,0},
 {"ube.g2",0,1,5,2,0,1,2,2},
 {"ube.stack.floor",4,-1,-1,12,1,8,0,0},
 {"ube.module.failed",3,-1,-1,10,1,1,0,0},
 {"ube.stack.frames",5,-1,-1,17,1,16,0,0}
};
static const struct definition_range storage_ranges[]={
 {0,1,1152,8,8,0,128,8320,0x140002080LL,0xC0000040},
 {1,2,1552,784,784,0,16,12304,0x140003010LL,0xC0000040},
 {2,0,664,8,8,0,152,4248,0x140001098LL,0x40000040},
 {3,3,2560,1,1,32,0,16384,0x140004000LL,0x60000020},
 {4,1,1160,3,3,0,136,8328,0x140002088LL,0xC0000040},
 {5,0,640,24,24,0,128,4224,0x140001080LL,0x40000040},
 {0},
 {7,2,1544,8,8,0,8,12296,0x140003008LL,0xC0000040},
 {8,1,1163,1,1,0,139,8331,0x14000208BLL,0xC0000040},
 {9,0,672,16,16,0,160,4256,0x1400010A0LL,0x40000040}
};
static int storage_fixture_open(struct storage_fixture* f){
 memset(f,0,sizeof *f);
 CHECK(ube_gc_root_enter(&f->roots[0],&f->expected.rows));
 CHECK(ube_gc_root_enter(&f->roots[1],&f->expected.names));
 CHECK(ube_gc_root_enter(&f->roots[2],&f->retained));
 CHECK(ube_gc_root_enter(&f->roots[3],&f->order));
 CHECK(ube_gc_root_enter(&f->roots[4],&f->protected));return 0;
}
static int storage_fixture_reset(struct storage_fixture* f,unsigned char* bytes){
 thread_bytes(bytes);
 CHECK(ube_value_try_resize(&f->expected.rows,10,&storage_expected_layout,0));
 CHECK(ube_value_try_resize(&f->expected.names,480,&ube_file_byte_layout,0));
 CHECK(ube_value_try_resize(&f->retained,10,&storage_retained_layout,0));
 CHECK(ube_value_try_resize(&f->order,8,&storage_order_layout,0));
 CHECK(ube_value_try_resize(&f->protected,0,&binding_integer_layout,0));
 f->expected.capacity=f->expected.count=10;f->expected.name_capacity=480;
 f->expected.name_length=0;f->expected.sources=3;f->expected.status=1;
 memset(payload(f->expected.names),0,480);
 struct expected_definition* rows=(struct expected_definition*)payload(f->expected.rows);
 struct retained_definition* retained=(struct retained_definition*)payload(f->retained);
 memset(retained,0,10*sizeof *retained);
 for(int i=0;i<10;++i){
  const struct expected_oracle* o=&storage_rows[i];int n=(int)strlen(o->name);
  rows[i]=(struct expected_definition){{f->expected.name_length,n},o->unit,o->source,o->declaration,o->family,o->required,o->bytes,o->type,o->representation};
  memcpy(payload(f->expected.names)+f->expected.name_length,o->name,(size_t)n);f->expected.name_length+=n;
  if(i!=6){retained[i].present=1;retained[i].image=storage_ranges[i];retained[i].object=storage_ranges[i];retained[i].object.rva=retained[i].object.address=0;}
 }
 memcpy(payload(f->order),storage_rva_order,sizeof storage_rva_order);return 0;
}
static int storage_fixture_close(struct storage_fixture* f){
 f->expected.rows=f->expected.names=f->retained=f->order=f->protected=NULL;
 for(int i=4;i>=0;--i)CHECK(ube_gc_root_leave(&f->roots[i]));return 0;
}
static int storage_prepare_image(void** image,unsigned char* bytes,struct layout* layout){
 struct inspection state;struct failure failure;CHECK(replace(image,bytes,4096)==0);
 inspection_defaults(&state);CHECK(read_layout(image,&state,layout,NULL,&failure));return 0;
}
/* Add a logical .bss contribution without disturbing the four TLS fixture
   sections. Five section headers need 528 bytes, so relocate all raw bytes by
   512 and use HeaderBytes=1024. Partial initialization ends at offset 512. */
static void storage_zero_fill(unsigned char* bytes,struct storage_fixture* f,int partial){
 memmove(bytes+1024,bytes+512,2560);memset(bytes+512,0,512);
 put(bytes,70,5,2);put(bytes,144,24576,4);put(bytes,148,1024,4);
 const int starts[]={1024,1536,2048,3072};for(int i=0;i<4;++i)put(bytes,348+i*40,starts[i],4);
 int at=488;memset(bytes+at,0,40);memcpy(bytes+at,".bss",4);put(bytes,at+8,1024,4);put(bytes,at+12,20480,4);
 put(bytes,at+16,partial?512:0,4);put(bytes,at+20,partial?3584:0,4);put(bytes,at+36,partial?0xC0000040:0xC0000080,4);
 struct retained_definition* r=(struct retained_definition*)payload(f->retained);
 for(int i=0;i<10;++i)if(r[i].present)r[i].image.first+=512;
 r[0].image=(struct definition_range){0,4,partial?4092:-1,8,partial?4:0,0,508,20988,0x1400051FCLL,partial?0xC0000040:0xC0000080};
 const int32_t order[]={5,2,9,4,8,7,1,0};memcpy(payload(f->order),order,sizeof order);
}
static int storage_ownership_cases(void** image,void** cancellation){
 struct storage_fixture f;CHECK(storage_fixture_open(&f)==0);unsigned char bytes[4096];
 CHECK(storage_fixture_reset(&f,bytes)==0);struct layout layout;CHECK(storage_prepare_image(image,bytes,&layout)==0);
 struct inspection state;struct failure failure;
 /* TLS: directory 16/4, seven four-section locations 1120/287, six
    three-section isolation walks 720/186, fields40/6,index4/1,callbacks24/3:
    1924 bytes/487 events. Eight owner section+isolation checks add1280/328.
    TLS neutral reads add792/101. Ten expected and eight order visits add18.
    No protected pairs, no owned payload and no candidate symbol lookup. */
 const int64_t wanted_bytes=3996,wanted_events=934;
 unsigned char old_rows[400],old_names[480],old_retained[1200],old_order[32];
 memcpy(old_rows,payload(f.expected.rows),sizeof old_rows);memcpy(old_names,payload(f.expected.names),sizeof old_names);
 memcpy(old_retained,payload(f.retained),sizeof old_retained);memcpy(old_order,payload(f.order),sizeof old_order);
 struct expected_definitions old_expected=f.expected;struct layout old_layout=layout;
 inspection_defaults(&state);inventory_observe(1);ube_err_set(77,"prior","storage ownership");
 int ok=validate_storage_ownership(image,&layout,&f.expected,&f.retained,&f.order,&f.protected,&state,NULL,&failure);inventory_observation_end();
 if(!ok || state.bytes!=wanted_bytes || state.events!=wanted_events)fprintf(stderr,"storage baseline %d/%d bytes=%lld events=%lld expected=%lld/%lld\n",ok,failure.code,(long long)state.bytes,(long long)state.events,(long long)wanted_bytes,(long long)wanted_events);
 CHECK(ok && failure.code==0 && state.bytes==wanted_bytes && state.events==wanted_events);
 CHECK(state.bytes==byte_visits && state.bytes==inventory_bytes && state.events==inventory_events && inventory_allocation_visits==0 && copies==0 && ube_err_number()==77);
 CHECK(memcmp(&f.expected,&old_expected,sizeof old_expected)==0 && memcmp(&layout,&old_layout,sizeof layout)==0);
 CHECK(memcmp(payload(*image),bytes,sizeof bytes)==0 && memcmp(payload(f.expected.rows),old_rows,sizeof old_rows)==0 && memcmp(payload(f.expected.names),old_names,sizeof old_names)==0 && memcmp(payload(f.retained),old_retained,sizeof old_retained)==0 && memcmp(payload(f.order),old_order,sizeof old_order)==0);
 /* First negative independently defeats an always-true Boolean adapter. */
 ((int32_t*)payload(f.order))[1]=5;inspection_defaults(&state);
 ok=validate_storage_ownership(image,&layout,&f.expected,&f.retained,&f.order,&f.protected,&state,NULL,&failure);
 CHECK(!ok && failure.code==1506);memcpy(payload(f.order),storage_rva_order,sizeof storage_rva_order);
 for(int domain=0;domain<2;++domain)for(int delta=-1;delta<=0;++delta){
  inspection_defaults(&state);if(domain)state.maximum_events=wanted_events+delta;else state.maximum_bytes=wanted_bytes+delta;
  inventory_observe(0);ok=validate_storage_ownership(image,&layout,&f.expected,&f.retained,&f.order,&f.protected,&state,NULL,&failure);inventory_observation_end();
  CHECK(ok==(delta==0) && state.bytes==byte_visits && state.bytes==inventory_bytes && state.events==inventory_events);
  if(!ok)CHECK(failure.code==1502 && failure.resource==7);
  CHECK(memcmp(payload(*image),bytes,sizeof bytes)==0 && memcmp(payload(f.expected.rows),old_rows,sizeof old_rows)==0 && memcmp(payload(f.expected.names),old_names,sizeof old_names)==0 && memcmp(payload(f.retained),old_retained,sizeof old_retained)==0 && memcmp(payload(f.order),old_order,sizeof old_order)==0 && ube_err_number()==77);
 }
 CHECK(make_cancel(cancellation));inventory_cancel_flag=(bool*)*cancellation;
 for(int64_t at=1;at<=wanted_events;++at){
  inspection_defaults(&state);*inventory_cancel_flag=false;inventory_cancel_at=at;inventory_observe(0);
  ok=validate_storage_ownership(image,&layout,&f.expected,&f.retained,&f.order,&f.protected,&state,*cancellation,&failure);inventory_observation_end();
  CHECK(!ok && failure.code==1507 && state.events==at-1 && state.events==inventory_events && state.bytes==inventory_bytes && state.bytes==byte_visits);
  CHECK(memcmp(payload(*image),bytes,sizeof bytes)==0 && memcmp(payload(f.expected.rows),old_rows,sizeof old_rows)==0 && memcmp(payload(f.expected.names),old_names,sizeof old_names)==0 && memcmp(payload(f.retained),old_retained,sizeof old_retained)==0 && memcmp(payload(f.order),old_order,sizeof old_order)==0 && ube_err_number()==77);
 }
 inventory_cancel_flag=NULL;inventory_cancel_at=0;*cancellation=NULL;
 /* Exact adjacent spans, zero-fill tails and ordinary rows deliberately out
    of address order pass. Protected aliases describe views, not new owners. */
 for(int positive=0;positive<6;++positive){
  CHECK(storage_fixture_reset(&f,bytes)==0);
  struct retained_definition* r=(struct retained_definition*)payload(f.retained);
  if(positive==0){CHECK(ube_value_try_resize(&f.protected,8,&binding_integer_layout,0));memcpy(payload(f.protected),storage_protected_views,sizeof storage_protected_views);}
  if(positive==1 || positive==2)storage_zero_fill(bytes,&f,positive==2);
  if(positive==3){ /* Same owner may have another symbol label; no new extent. */r[0].image.symbol=99;}
  if(positive==4){ /* Identical protected views remain one exclusion union. */const int64_t same[]={4400,8,4400,8};CHECK(ube_value_try_resize(&f.protected,4,&binding_integer_layout,0));memcpy(payload(f.protected),same,sizeof same);}
  if(positive==5){ /* A protected view exactly abuts either end of a global. */const int64_t edges[]={8312,8,8332,8};CHECK(ube_value_try_resize(&f.protected,4,&binding_integer_layout,0));memcpy(payload(f.protected),edges,sizeof edges);}
  CHECK(storage_prepare_image(image,bytes,&layout)==0);inspection_defaults(&state);
  ok=validate_storage_ownership(image,&layout,&f.expected,&f.retained,&f.order,&f.protected,&state,NULL,&failure);
  if(!ok)fprintf(stderr,"storage positive %d: %d\n",positive,failure.code);CHECK(ok && failure.code==0);
 }
 /* These edits change candidate placement while retaining known positive
    dimensions; each is an ownership/geometry/residency mismatch, UBE1506. */
 for(int defect=0;defect<31;++defect){
  CHECK(storage_fixture_reset(&f,bytes)==0);struct retained_definition* r=(struct retained_definition*)payload(f.retained);
  struct expected_definition* e=(struct expected_definition*)payload(f.expected.rows);int32_t* order=(int32_t*)payload(f.order);
  switch(defect){
   case 0:put(bytes,404,0xC2000040,4);r[0].image.characteristics=r[4].image.characteristics=r[8].image.characteristics=0xC2000040;break;
   case 1:r[4].image=r[0].image;r[4].image.symbol=4;r[4].image.count=r[4].image.initialized=3;break;
   case 2:r[4].image.offset=135;r[4].image.first=1159;r[4].image.rva=8327;r[4].image.address=0x140002087LL;break;
   case 3:order[1]=order[0];break;
   case 4:order[0]=2;order[1]=5;break;
   case 5:++r[0].image.first;break;
   case 6:++r[0].image.offset;break;
   case 7:++r[0].image.rva;break;
   case 8:++r[0].image.address;break;
   case 9:r[0].image.initialized=7;break;
   case 10:r[0].image.characteristics=0xC0000080;break;
   case 11:r[0].image.section=0;break;
   case 12:r[0].image=r[7].image;r[0].image.symbol=0;order[3]=4;order[4]=8;order[5]=0;break;
   case 13:r[1].image.offset=8;r[1].image.first=1544;r[1].image.rva=12296;r[1].image.address=0x140003008LL;break;
   case 14:r[0].image.offset=0;r[0].image.first=1024;r[0].image.rva=8192;r[0].image.address=0x140002000LL;break;
   case 15:r[0].image.offset=64;r[0].image.first=1088;r[0].image.rva=8256;r[0].image.address=0x140002040LL;break;
   case 16:r[5].image.offset=0;r[5].image.first=512;r[5].image.rva=4096;r[5].image.address=0x140001000LL;break;
   case 17:put(bytes,388,512,4);r[0].image.first-=512;r[4].image.first-=512;r[8].image.first-=512;break;
   case 18:put(bytes,380,4096,4);r[0].image.rva-=4096;r[0].image.address-=4096;break;
   case 19:r[0].image.type=32;break;
   case 20:put(bytes,404,0xE0000040,4);r[0].image.characteristics=r[4].image.characteristics=r[8].image.characteristics=0xE0000040;break;
   case 21:put(bytes,364,0xC0000040,4);r[2].image.characteristics=r[5].image.characteristics=r[9].image.characteristics=0xC0000040;break;
   case 22:bytes[1544]=1;break;
   case 23:bytes[2335]=1;break;
   case 24:put(bytes,272,0,4);break;
   case 25:e[6].required=1;break;
   case 26:r[0].image.offset=508;r[0].image.first=1532;r[0].image.rva=8700;r[0].image.address=0x1400021FCLL;break;
   case 27:put(bytes,364,0x42000040,4);r[2].image.characteristics=r[5].image.characteristics=r[9].image.characteristics=0x42000040;break;
   case 28:put(bytes,404,0x80000040,4);r[0].image.characteristics=r[4].image.characteristics=r[8].image.characteristics=0x80000040;break;
   case 29:r[5].image.initialized=23;break;
   case 30:r[0].image.first=-1;r[0].image.initialized=0;break;
  }
  CHECK(storage_prepare_image(image,bytes,&layout)==0);inspection_defaults(&state);
  ok=validate_storage_ownership(image,&layout,&f.expected,&f.retained,&f.order,&f.protected,&state,NULL,&failure);
  if(ok || failure.code!=1506)fprintf(stderr,"storage candidate defect %d: %d/%d\n",defect,ok,failure.code);CHECK(!ok && failure.code==1506);
 }
 /* Descriptor/table malformations are rejected without inventing candidate
    ownership. Keep actual array capacities authoritative. */
 for(int defect=0;defect<29;++defect){
  CHECK(storage_fixture_reset(&f,bytes)==0);CHECK(storage_prepare_image(image,bytes,&layout)==0);
  struct expected_definition* e=(struct expected_definition*)payload(f.expected.rows);struct retained_definition* r=(struct retained_definition*)payload(f.retained);int32_t* order=(int32_t*)payload(f.order);
  switch(defect){
   case 0:f.expected.status=0;break;case 1:f.expected.count=11;break;case 2:f.expected.capacity=9;break;
   case 3:f.expected.name_capacity=479;break;case 4:f.expected.name_length=481;break;case 5:f.expected.sources=0;break;
   case 6:e[0].name.first=-1;break;case 7:e[0].name.count=0;break;case 8:e[0].name.first=480;break;
   case 9:e[0].family=24;break;case 10:e[0].unit=7;break;case 11:e[0].required=2;break;
   case 12:e[0].bytes=0;break;case 13:e[3].bytes=1;break;case 14:r[0].present=2;break;
   case 15:CHECK(ube_value_try_resize(&f.retained,9,&storage_retained_layout,0));memcpy(payload(f.retained),old_retained,1080);break;
   case 16:CHECK(ube_value_try_resize(&f.order,7,&storage_order_layout,0));memcpy(payload(f.order),storage_rva_order,28);break;
   case 17:order[0]=10;break;case 18:order[0]=-1;break;case 19:order[0]=6;break;case 20:order[0]=3;break;
   case 21:layout.kind=1;break;case 22:++layout.length;break;case 23:r[0].image.symbol=-1;break;
   case 24:r[0].image.count=7;break;case 25:r[0].image.rva=INT64_MAX;break;case 26:r[0].image.address=INT64_MAX;break;
   case 27:r[0].image.section=96;break;case 28:r[0].image.offset=-1;break;
  }
  int code=defect>=23?1506:1509;
  inspection_defaults(&state);ok=validate_storage_ownership(image,&layout,&f.expected,&f.retained,&f.order,&f.protected,&state,NULL,&failure);
  if(ok || failure.code!=code)fprintf(stderr,"storage shape defect %d: %d/%d expected %d\n",defect,ok,failure.code,code);CHECK(!ok && failure.code==code);
 }
 /* The all-zero range has no raw alias, but its virtual suffix must still
    exclude other sections. Initialized prefixes need independent file checks. */
 for(int defect=0;defect<6;++defect){
  CHECK(storage_fixture_reset(&f,bytes)==0);storage_zero_fill(bytes,&f,defect==2 || defect==5);
  struct retained_definition* r=(struct retained_definition*)payload(f.retained);
  if(defect==0 || defect==1){
   put(bytes,70,6,2);int at=528;memset(bytes+at,0,40);memcpy(bytes+at,".other",6);put(bytes,at+8,512,4);put(bytes,at+36,0xC0000080,4);
   if(defect==0)put(bytes,at+12,20480,4);
   else{put(bytes,144,28672,4);put(bytes,496,8192,4);put(bytes,at+12,24576,4);r[0].image.offset=4092;r[0].image.rva=24572;r[0].image.address=0x140005FFCLL;}
  }
  if(defect==2){put(bytes,70,6,2);put(bytes,144,28672,4);int at=528;memset(bytes+at,0,40);memcpy(bytes+at,".other",6);put(bytes,at+8,512,4);put(bytes,at+12,24576,4);put(bytes,at+16,512,4);put(bytes,at+20,3584,4);put(bytes,at+36,0x40000040,4);}
  if(defect==3)r[0].image.first=0; /* Zero-filled logical bytes have no file start. */
  if(defect==4 || defect==5){r[0].image.characteristics|=0x02000000;put(bytes,524,(uint64_t)r[0].image.characteristics,4);} /* Only the generated section is discardable. */
  CHECK(storage_prepare_image(image,bytes,&layout)==0);inspection_defaults(&state);
  ok=validate_storage_ownership(image,&layout,&f.expected,&f.retained,&f.order,&f.protected,&state,NULL,&failure);
  if(ok || failure.code!=1506)fprintf(stderr,"storage zero-fill defect %d: %d/%d\n",defect,ok,failure.code);CHECK(!ok && failure.code==1506);
 }
 for(int defect=0;defect<10;++defect){
  CHECK(storage_fixture_reset(&f,bytes)==0);CHECK(storage_prepare_image(image,bytes,&layout)==0);
  CHECK(ube_value_try_resize(&f.protected,8,&binding_integer_layout,0));memcpy(payload(f.protected),storage_protected_views,sizeof storage_protected_views);int64_t* p=(int64_t*)payload(f.protected);int code=1509;
  switch(defect){
   case 0:p[0]=8320;p[1]=1;p[2]=8320;p[4]=8320;p[6]=9000;code=1506;break;
   case 1:p[6]=8319;p[7]=2;code=1506;break;
   case 2:p[0]=4100;p[1]=9000;code=1506;break; /* Long earlier view contains a later owner. */
   case 3:p[6]=12303;p[7]=2;code=1506;break;
   case 4:p[1]=0;break;case 5:p[1]=-1;break;case 6:p[0]=-1;break;
   case 7:p[6]=4167;break;case 8:p[6]=INT64_MAX;p[7]=INT64_MAX;break;
   case 9:CHECK(ube_value_try_resize(&f.protected,7,&binding_integer_layout,0));memcpy(payload(f.protected),storage_protected_views,56);break;
  }
  inspection_defaults(&state);ok=validate_storage_ownership(image,&layout,&f.expected,&f.retained,&f.order,&f.protected,&state,NULL,&failure);
  if(ok || failure.code!=code)fprintf(stderr,"storage protected defect %d: %d/%d expected %d\n",defect,ok,failure.code,code);CHECK(!ok && failure.code==code);
 }
 CHECK(storage_fixture_reset(&f,bytes)==0);CHECK(storage_prepare_image(image,bytes,&layout)==0);
 ube_gc_test_fail_next_allocations(1000000);inspection_defaults(&state);inventory_observe(1);
 ok=validate_storage_ownership(image,&layout,&f.expected,&f.retained,&f.order,&f.protected,&state,NULL,&failure);inventory_observation_end();ube_gc_test_fail_next_allocations(0);
 CHECK(ok && inventory_allocation_visits==0 && copies==0 && ube_err_number()==77);
 CHECK(memcmp(payload(*image),bytes,sizeof bytes)==0 && memcmp(payload(f.expected.rows),old_rows,sizeof old_rows)==0 && memcmp(payload(f.expected.names),old_names,sizeof old_names)==0 && memcmp(payload(f.retained),old_retained,sizeof old_retained)==0 && memcmp(payload(f.order),old_order,sizeof old_order)==0);
 size_t available=UBE_GC_MAX_ROOTS-ube_gc_root_count;struct ube_gc_root* pressure=calloc(available,sizeof *pressure);void* nil=NULL;CHECK(pressure);
 for(size_t n=0;n<available;++n)CHECK(ube_gc_root_enter(&pressure[n],&nil));inspection_defaults(&state);
 CHECK(!validate_storage_ownership(image,&layout,&f.expected,&f.retained,&f.order,&f.protected,&state,NULL,&failure));
 for(size_t n=0;n<available;++n)CHECK(ube_gc_root_leave(&pressure[n]));free(pressure);
 CHECK(storage_fixture_close(&f)==0);return 0;
}
