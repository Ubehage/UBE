/* Literal encoding oracles: no production relocation arithmetic is reused. */
extern int32_t validate_fixup(struct object_relocation*,struct definition_range*,int64_t,void**,int32_t,void**,int32_t,struct inspection*,void*,struct failure*);
struct fixup_vector {int kind;uint64_t original,linked;int target_variant;int64_t site;};
static const struct fixup_vector fixup_vectors[]={
 {1,0,0x140003000ULL,0,0x1000},{1,1,0x140003001ULL,0,0x1000},
 {1,UINT64_MAX,0x140002fffULL,0,0x1000},
 {1,0x8000000000000000ULL,0x8000000140003000ULL,0,0x1000},
 {1,0x7fffffffffffffffULL,0x8000000140002fffULL,0,0x1000},
 {1,2,0x8000000000000000ULL,1,0x1000},
 {2,0,0x40003000,0,0x1000},{2,0xffffffff,0x40002fff,0,0x1000},
 {3,0,0x3000,0,0x1000},{3,0xffffffff,0x2fff,0,0x1000},
 {4,0,0x1ffc,0,0x1000},{5,0,0x1ffb,0,0x1000},
 {6,0,0x1ffa,0,0x1000},{7,0,0x1ff9,0,0x1000},
 {8,0,0x1ff8,0,0x1000},{9,0,0x1ff7,0,0x1000},
 {4,19,0x200f,0,0x1000},{4,0,0xffffdffc,2,0x3000},
 {4,0,0xffffffdc,3,0x10},{4,0,0x100c,2,0xfffffff0LL},
 {10,0,6,0,0x1000},{10,0xffff,5,0,0x1000},{10,0,96,4,0x1000},
 {11,0,0x200,0,0x1000},{11,0xffffffff,0x1ff,0,0x1000},
 {11,2,0,5,0x1000},{3,0,0x3000,6,0x1000}
};
static struct definition_range fixup_target(int variant){
 struct definition_range t={0,5,0,1,1,0,0x200,0x3000,0x140003000LL,0x40000040};
 if(variant==1)t.address=INT64_MAX-1;
 if(variant==2){t.rva=0x1000;t.address=0x140001000LL;}
 if(variant==3){t.rva=0xfffffff0LL;t.address=0xfffffff0LL;}
 if(variant==4)t.section=95;
 if(variant==5){t.offset=0xfffffffeLL;t.rva=0xfffffffeLL;t.address=0xfffffffeLL;}
 if(variant==6){t.initialized=0;t.first=-1;}
 return t;
}
static int fixup_cases(void** object,void** cancellation){
 void* image=NULL;struct ube_gc_root root={0};CHECK(ube_gc_root_enter(&root,&image));
 unsigned char ob[19],ib[23];struct inspection state;struct failure failure;
 for(size_t vi=0;vi<sizeof fixup_vectors/sizeof fixup_vectors[0];++vi){
  const struct fixup_vector* v=&fixup_vectors[vi];int width=v->kind==1?8:v->kind==10?2:4;
  struct object_relocation rel={0,0,v->kind,width,v->kind>=4 && v->kind<=9?v->kind:0},old_rel=rel;
  struct definition_range target=fixup_target(v->target_variant),old_target=target;
  memset(ob,0xa5,sizeof ob);memset(ib,0x5a,sizeof ib);put(ob,3,v->original,width);put(ib,5,v->linked,width);
  CHECK(replace(object,ob,sizeof ob)==0 && replace(&image,ib,sizeof ib)==0);
  inspection_defaults(&state);ube_err_set(77,"prior","fixup");inventory_observe(1);
  int ok=validate_fixup(&rel,&target,v->site,object,3,&image,5,&state,NULL,&failure);inventory_observation_end();
  if(!ok)fprintf(stderr,"fixup vector=%zu code=%d\n",vi,failure.code);
  CHECK(ok && failure.code==0 && failure.resource==0);
  CHECK(state.bytes==2*width && state.events==2*width+1 && byte_visits==state.bytes && inventory_bytes==state.bytes && inventory_events==state.events && inventory_allocation_visits==0 && copies==0 && ube_err_number()==77);
  CHECK(memcmp(&rel,&old_rel,sizeof rel)==0 && memcmp(&target,&old_target,sizeof target)==0 && memcmp(payload(*object),ob,sizeof ob)==0 && memcmp(payload(image),ib,sizeof ib)==0);
  /* Every linked field byte must participate in the decision. */
  for(int byte=0;byte<width;++byte){payload(image)[5+byte]^=1;inspection_defaults(&state);ok=validate_fixup(&rel,&target,v->site,object,3,&image,5,&state,NULL,&failure);CHECK(!ok && failure.code==1506);payload(image)[5+byte]^=1;}
  for(int domain=0;domain<2;++domain)for(int delta=-1;delta<=0;++delta){inspection_defaults(&state);if(domain)state.maximum_events=2*width+1+delta;else state.maximum_bytes=2*width+delta;inventory_observe(0);ok=validate_fixup(&rel,&target,v->site,object,3,&image,5,&state,NULL,&failure);inventory_observation_end();CHECK(ok==(delta==0) && state.bytes==byte_visits && state.bytes==inventory_bytes && state.events==inventory_events);if(!ok)CHECK(failure.code==1502 && failure.resource==7);}
  CHECK(make_cancel(cancellation));inventory_cancel_flag=(bool*)*cancellation;
  for(int at=1;at<=2*width+1;++at){inspection_defaults(&state);*inventory_cancel_flag=false;inventory_cancel_at=at;inventory_observe(0);ok=validate_fixup(&rel,&target,v->site,object,3,&image,5,&state,*cancellation,&failure);inventory_observation_end();CHECK(!ok && failure.code==1507 && state.events==at-1 && state.events==inventory_events && state.bytes==inventory_bytes && state.bytes==byte_visits);}
  inventory_cancel_flag=NULL;inventory_cancel_at=0;*cancellation=NULL;
  if(vi==0){size_t n=UBE_GC_MAX_ROOTS-ube_gc_root_count;struct ube_gc_root* pressure=calloc(n,sizeof *pressure);void* nil=NULL;CHECK(pressure);for(size_t j=0;j<n;++j)CHECK(ube_gc_root_enter(&pressure[j],&nil));inspection_defaults(&state);CHECK(!validate_fixup(&rel,&target,v->site,object,3,&image,5,&state,NULL,&failure));for(size_t j=0;j<n;++j)CHECK(ube_gc_root_leave(&pressure[j]));free(pressure);}
 }
 for(int defect=0;defect<25;++defect){
  struct object_relocation rel={0,0,4,4,4};struct definition_range target=fixup_target(0);int of=3,imf=5,expected=1509;int64_t site=0x1000;
  switch(defect){
  case 0:rel.kind=-1;expected=1506;break;case 1:rel.kind=12;expected=1506;break;
  case 2:rel.width=8;break;case 3:rel.relative_end=5;break;
  case 4:of=-1;break;case 5:of=INT32_MAX;break;case 6:of=16;break;
  case 7:imf=-1;break;case 8:imf=INT32_MAX;break;case 9:imf=20;break;
  case 10:target.section=-1;break;case 11:target.section=96;break;case 12:target.count=0;break;
  case 13:target.initialized=-1;break;case 14:target.initialized=2;break;
  case 15:target.offset=-1;break;case 16:target.offset=target.rva+1;break;
  case 17:target.rva=0x100000000LL;break;case 18:target.address=target.rva-1;break;
  case 19:target.rva=0xffffffffLL;target.address=target.rva;break;
  case 20:target.address=INT64_MAX;break;case 21:site=-1;break;
  case 22:site=0xfffffffcLL;break;case 23:rel.kind=9;rel.relative_end=9;site=0xfffffff7LL;break;
  case 24:target.count=INT32_MAX;target.rva=0xffff0000LL;target.address=target.rva;break;
  }
  inspection_defaults(&state);inventory_observe(0);int ok=validate_fixup(&rel,&target,site,object,of,&image,imf,&state,NULL,&failure);inventory_observation_end();CHECK(!ok && failure.code==expected && state.bytes==0 && state.events==0 && byte_visits==0 && inventory_allocation_visits==0 && copies==0);
 }
 /* ABSOLUTE ignores the unused spans, site and target but still admits work. */
 struct object_relocation rel={0,0,0,0,0};struct definition_range target;memset(&target,0xa5,sizeof target);*object=NULL;image=NULL;inspection_defaults(&state);inventory_observe(1);CHECK(validate_fixup(&rel,&target,INT64_MIN,object,-1,&image,INT32_MAX,&state,NULL,&failure));inventory_observation_end();CHECK(failure.code==0 && state.bytes==0 && state.events==1 && inventory_events==1 && byte_visits==0 && inventory_allocation_visits==0 && copies==0);
 inspection_defaults(&state);state.maximum_events=0;CHECK(!validate_fixup(&rel,&target,0,object,0,&image,0,&state,NULL,&failure) && failure.code==1502 && failure.resource==7);
 CHECK(make_cancel(cancellation));*(bool*)*cancellation=true;inspection_defaults(&state);CHECK(!validate_fixup(&rel,&target,0,object,0,&image,0,&state,*cancellation,&failure) && failure.code==1507 && state.events==0);*cancellation=NULL;
 rel.width=4;inspection_defaults(&state);CHECK(!validate_fixup(&rel,&target,0,object,0,&image,0,&state,NULL,&failure) && failure.code==1509 && state.events==0);
 CHECK(ube_gc_root_leave(&root));unsigned char restore[256];symbol_bytes(restore);CHECK(replace(object,restore,sizeof restore)==0);return 0;
}
