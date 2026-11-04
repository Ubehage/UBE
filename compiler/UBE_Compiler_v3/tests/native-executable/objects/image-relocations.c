/* Literal pointer expectations are independent of the relocation reader. */
extern int32_t validate_image_relocations(void**,struct layout*,void**,struct inspection*,struct definition_range*,void*,struct failure*);
static int64_t image_relocation_bytes,image_relocation_events;
static const int64_t image_pointer_pairs[]={4096,12288,4104,13088,8256,16384};

/* Two blocks describe three eight-byte writes; the last WORD is padding. */
static void image_relocation_fixture(unsigned char* bytes){
 thread_bytes(bytes);
 put(bytes,240,4352,4);put(bytes,244,28,4);
 put(bytes,768,4096,4);put(bytes,772,12,4);put(bytes,776,0xA000,2);put(bytes,778,0xA008,2);
 put(bytes,780,8192,4);put(bytes,784,16,4);put(bytes,788,0xA040,2);put(bytes,790,0,2);put(bytes,792,0,2);put(bytes,794,0,2);
}

/* Assert complete output, failures, accounting and ownership on literal bytes. */
static int image_relocation_cases(void** image,void** cancellation){
 unsigned char bytes[4096];image_relocation_fixture(bytes);
 void* expected=NULL;struct ube_gc_root root_expected={0};
 CHECK(ube_gc_root_enter(&root_expected,&expected) && ube_value_try_resize(&expected,6,&binding_integer_layout,0));
 memcpy(payload(expected),image_pointer_pairs,sizeof image_pointer_pairs);
 CHECK(replace(image,bytes,sizeof bytes)==0);
 struct inspection state;struct layout layout;struct failure failure;struct definition_range result,stale;
 const struct definition_range wanted={-1,0,768,28,28,0,256,4352,0x140001100LL,0x40000040};
 inspection_defaults(&state);CHECK(read_layout(image,&state,&layout,NULL,&failure));memset(&stale,0xA5,sizeof stale);result=stale;
 inspection_defaults(&state);ube_err_set(77,"prior","image relocations");inventory_observe(1);
 int ok=validate_image_relocations(image,&layout,&expected,&state,&result,NULL,&failure);inventory_observation_end();
 CHECK(ok && failure.code==0);CHECK(memcmp(&result,&wanted,sizeof result)==0);
 CHECK(state.bytes==byte_visits && state.bytes==inventory_bytes && state.events==inventory_events && inventory_allocation_visits==0 && copies==0 && ube_err_number()==77);
 image_relocation_bytes=state.bytes;image_relocation_events=state.events;
 /* A changed target cannot pass even though its field still has a DIR64 entry. */
 ((unsigned char*)payload(*image))[512]^=1;inspection_defaults(&state);result=stale;
 ok=validate_image_relocations(image,&layout,&expected,&state,&result,NULL,&failure);
 CHECK(!ok && failure.code==1506 && memcmp(&result,&stale,sizeof result)==0);CHECK(replace(image,bytes,sizeof bytes)==0);
 for(int domain=0;domain<2;++domain)for(int delta=-1;delta<=0;++delta){
  inspection_defaults(&state);if(domain)state.maximum_events=image_relocation_events+delta;else state.maximum_bytes=image_relocation_bytes+delta;
  result=stale;inventory_observe(0);ok=validate_image_relocations(image,&layout,&expected,&state,&result,NULL,&failure);inventory_observation_end();
  CHECK(ok==(delta==0) && state.bytes==byte_visits && state.bytes==inventory_bytes && state.events==inventory_events);
  if(!ok)CHECK(failure.code==1502 && failure.resource==7 && memcmp(&result,&stale,sizeof result)==0);
 }
 CHECK(make_cancel(cancellation));inventory_cancel_flag=(bool*)*cancellation;
 for(int64_t at=1;at<=image_relocation_events;++at){
  inspection_defaults(&state);*inventory_cancel_flag=false;inventory_cancel_at=at;result=stale;inventory_observe(0);
  ok=validate_image_relocations(image,&layout,&expected,&state,&result,*cancellation,&failure);inventory_observation_end();
  CHECK(!ok && failure.code==1507 && memcmp(&result,&stale,sizeof result)==0 && state.events==at-1 && state.events==inventory_events && state.bytes==inventory_bytes && state.bytes==byte_visits);
 }
 inventory_cancel_flag=NULL;inventory_cancel_at=0;*cancellation=NULL;
 /* All mutations retain the originally qualified layout unless explicitly noted. */
 for(int defect=0;defect<33;++defect){
  image_relocation_fixture(bytes);memcpy(payload(expected),image_pointer_pairs,sizeof image_pointer_pairs);
  switch(defect){
   case 0:put(bytes,86,0x23,2);break; /* stripped */
   case 1:put(bytes,240,0,4);break;
   case 2:put(bytes,244,0,4);break;
   case 3:put(bytes,240,4353,4);break;
   case 4:put(bytes,244,27,4);break;
   case 5:put(bytes,244,512,4);break;
   case 6:put(bytes,772,4,4);break;
   case 7:put(bytes,772,32,4);break;
   case 8:put(bytes,772,10,4);break;
   case 9:put(bytes,768,4097,4);break;
   case 10:put(bytes,780,4096,4);break;
   case 11:put(bytes,776,0x3000,2);break;
   case 12:put(bytes,778,0xA000,2);break;
   case 13:put(bytes,778,0xA004,2);break;
   case 14:put(bytes,776,0xA1FC,2);break;
   case 15:put(bytes,776,0xA100,2);break; /* metadata */
   case 16:put(bytes,768,16384,4);break; /* executable storage */
   case 17:put(bytes,364,0x42000040,4);break; /* discardable field */
   case 18:put(bytes,776,0,2);break; /* missing write */
   case 19:put(bytes,790,0xA048,2);break; /* extra write */
   case 20:put(bytes,520,0x140003321LL,8);break;
   case 21:((int64_t*)payload(expected))[0]=4097;break;
   case 22:((int64_t*)payload(expected))[5]=16385;break;
   case 23:put(bytes,244,24,4);break; /* block exceeds directory */
   case 24:put(bytes,784,12,4);break; /* trailing incomplete block */
   case 25:put(bytes,768,0xFFFFF000ULL,4);break;
   case 26:put(bytes,364,0xC0000040,4);break; /* writable metadata */
   case 27:put(bytes,404,0xC2000040,4);break; /* discardable writable field */
   case 28:put(bytes,388,512,4);break; /* aliased raw bytes */
   case 29:put(bytes,380,4096,4);break; /* overlapping sections */
   case 30:put(bytes,776,0xA008,2);put(bytes,778,0xA000,2);break;
   case 31:put(bytes,788,0xB040,2);break;
   case 32:put(bytes,512,UINT64_MAX,8);break;
  }
  CHECK(replace(image,bytes,sizeof bytes)==0);inspection_defaults(&state);result=stale;
  ok=validate_image_relocations(image,&layout,&expected,&state,&result,NULL,&failure);
  if(ok || failure.code!=1506)fprintf(stderr,"image relocation defect %d: %d/%d\n",defect,ok,failure.code);
  CHECK(!ok && failure.code==1506 && memcmp(&result,&stale,sizeof result)==0);
 }
 for(int positive=0;positive<3;++positive){
  image_relocation_fixture(bytes);memcpy(payload(expected),image_pointer_pairs,sizeof image_pointer_pairs);
  if(positive==0){put(bytes,512,0x140000000LL,8);((int64_t*)payload(expected))[1]=0;}
  if(positive==1)put(bytes,790,0xFFF,2);
  if(positive==2){put(bytes,244,36,4);put(bytes,796,12288,4);put(bytes,800,8,4);}
  CHECK(replace(image,bytes,sizeof bytes)==0);inspection_defaults(&state);result=stale;
  CHECK(validate_image_relocations(image,&layout,&expected,&state,&result,NULL,&failure) && result.count==(positive==2?36:28));
 }
 image_relocation_fixture(bytes);CHECK(replace(image,bytes,sizeof bytes)==0);memcpy(payload(expected),image_pointer_pairs,sizeof image_pointer_pairs);
 for(int defect=0;defect<5;++defect){
  struct layout altered=layout;void* supplied=expected;
  if(defect==0)altered.kind=1;if(defect==1)++altered.length;if(defect==2)supplied=NULL;
  if(defect==3)((int64_t*)payload(expected))[1]=-1;if(defect==4)((int64_t*)payload(expected))[1]=layout.image_bytes+1;
  inspection_defaults(&state);result=stale;CHECK(!validate_image_relocations(image,&altered,&supplied,&state,&result,NULL,&failure) && failure.code==1509 && memcmp(&result,&stale,sizeof result)==0);
 }
 memcpy(payload(expected),image_pointer_pairs,sizeof image_pointer_pairs);struct layout old_layout=layout;
 ube_gc_test_fail_next_allocations(1000000);inventory_observe(1);inspection_defaults(&state);
 CHECK(validate_image_relocations(image,&layout,&expected,&state,&result,NULL,&failure));inventory_observation_end();ube_gc_test_fail_next_allocations(0);
 CHECK(inventory_allocation_visits==0 && copies==0 && memcmp(&layout,&old_layout,sizeof layout)==0 && memcmp(payload(*image),bytes,sizeof bytes)==0 && memcmp(payload(expected),image_pointer_pairs,sizeof image_pointer_pairs)==0);
 size_t available=UBE_GC_MAX_ROOTS-ube_gc_root_count;struct ube_gc_root* pressure=calloc(available,sizeof *pressure);void* nil=NULL;CHECK(pressure);
 for(size_t n=0;n<available;++n)CHECK(ube_gc_root_enter(&pressure[n],&nil));inspection_defaults(&state);result=stale;
 CHECK(!validate_image_relocations(image,&layout,&expected,&state,&result,NULL,&failure) && memcmp(&result,&stale,sizeof result)==0);
 for(size_t n=0;n<available;++n)CHECK(ube_gc_root_leave(&pressure[n]));free(pressure);
 expected=NULL;CHECK(ube_gc_root_leave(&root_expected));return 0;
}
