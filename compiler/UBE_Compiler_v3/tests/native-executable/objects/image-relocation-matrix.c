/* Reuse the maintained runtime/ABI observer bridge, not its expected answers. */
#include "reader-probe.c"

/* Match changed expectations too, so range/permission refusals cannot be hidden
   behind the earlier field-equality check. Check array shape independently. */
static int image_relocation_edge_cases(void){
 void* image=NULL;void* expected=NULL;struct ube_gc_root roots[2]={{0}};
 CHECK(ube_gc_root_enter(&roots[0],&image) && ube_gc_root_enter(&roots[1],&expected));
 unsigned char bytes[4096];struct layout layout;struct inspection state;struct failure failure;
 struct definition_range result,stale;memset(&stale,0xA5,sizeof stale);
 for(int defect=0;defect<8;++defect){
  image_relocation_fixture(bytes);int count=defect==5?5:defect==6?4:defect==7?8:6;
  CHECK(ube_value_try_resize(&expected,count,&binding_integer_layout,0));
  int64_t values[8]={4096,12288,4104,13088,8256,16384,8264,16385};
  if(defect==0){values[0]=4352;put(bytes,776,0xA100,2);}
  if(defect==1){values[0]=4604;put(bytes,776,0xA1FC,2);}
  if(defect==2){values[0]=16384;put(bytes,768,16384,4);}
  if(defect==3){values[0]=0;put(bytes,768,0,4);}
  if(defect==4){values[0]=8192;put(bytes,768,8192,4);put(bytes,404,0xC2000040,4);}
  memcpy(payload(expected),values,(size_t)count*8);CHECK(replace(&image,bytes,sizeof bytes)==0);
  inspection_defaults(&state);CHECK(read_layout(&image,&state,&layout,NULL,&failure));inspection_defaults(&state);result=stale;
  CHECK(!validate_image_relocations(&image,&layout,&expected,&state,&result,NULL,&failure) && failure.code==(defect==5?1509:1506) && memcmp(&result,&stale,sizeof result)==0);
 }
 image=expected=NULL;CHECK(ube_gc_root_leave(&roots[1]) && ube_gc_root_leave(&roots[0]) && ube_gc_collect() && ube_gc_live_allocation_bytes()==0);return 0;
}

/* Load a frozen independent pointer table and compare one complete linked image. */
int main(int argc,char** argv){
 if(argc==2){CHECK(binary_reader_main(argc,argv)==0);CHECK(image_relocation_bytes==1198 && image_relocation_events==311);CHECK(image_relocation_edge_cases()==0);return 0;}
 CHECK(argc==3);FILE* f=fopen(argv[1],"rb");CHECK(f && fseek(f,0,SEEK_END)==0);long length=ftell(f);CHECK(length>0 && fseek(f,0,SEEK_SET)==0);
 unsigned char* bytes=malloc((size_t)length);CHECK(bytes && fread(bytes,1,(size_t)length,f)==(size_t)length && fclose(f)==0);
 f=fopen(argv[2],"r");CHECK(f);int count;CHECK(fscanf(f,"%d",&count)==1 && count==49);
 int64_t values[98];int32_t sites[49],fields[49];
 for(int i=0;i<count;++i){long long field,target;CHECK(fscanf(f,"%lld %lld %d %d",&field,&target,&fields[i],&sites[i])==4);values[2*i]=field;values[2*i+1]=target;CHECK(fields[i]>=0 && fields[i]<=length-8 && sites[i]>=0 && sites[i]<=length-2);}
 CHECK(fclose(f)==0);void* image=NULL;void* expected=NULL;struct ube_gc_root roots[2]={{0}};
 CHECK(ube_gc_root_enter(&roots[0],&image) && ube_gc_root_enter(&roots[1],&expected));
 CHECK(replace(&image,bytes,length)==0 && ube_value_try_resize(&expected,count*2,&binding_integer_layout,0));memcpy(payload(expected),values,sizeof values);
 struct layout layout;struct inspection state;struct failure failure;struct definition_range result,stale;memset(&stale,0xA5,sizeof stale);
 inspection_defaults(&state);CHECK(read_layout(&image,&state,&layout,NULL,&failure));inspection_defaults(&state);inventory_observe(1);
 CHECK(validate_image_relocations(&image,&layout,&expected,&state,&result,NULL,&failure));inventory_observation_end();
 CHECK(failure.code==0 && state.bytes==byte_visits && state.bytes==inventory_bytes && state.events==inventory_events && inventory_allocation_visits==0 && copies==0);
 int64_t required_bytes=state.bytes,required_events=state.events;
 /* All three changes are targeted using independent file mappings. */
 for(int i=0;i<count;++i)for(int mutation=0;mutation<3;++mutation){
  CHECK(replace(&image,bytes,length)==0);unsigned char* changed=payload(image);
  if(mutation==0){changed[sites[i]]=changed[sites[i]+1]=0;}
  if(mutation==1)changed[sites[i]]^=1;
  if(mutation==2)changed[fields[i]]^=1;
  inspection_defaults(&state);result=stale;
  CHECK(!validate_image_relocations(&image,&layout,&expected,&state,&result,NULL,&failure) && failure.code==1506 && memcmp(&result,&stale,sizeof result)==0);
 }
 /* A controlled rebased copy validates the numeric base-plus-target relation. */
 for(int sign=-1;sign<=1;sign+=2){
  CHECK(replace(&image,bytes,length)==0);unsigned char* changed=payload(image);struct layout moved=layout;int64_t delta=(int64_t)sign*0x1000000;
  uint32_t pe;memcpy(&pe,changed+60,4);CHECK(pe<=(uint32_t)length-56);
  uint64_t moved_base=(uint64_t)(layout.image_base+delta);memcpy(changed+pe+48,&moved_base,8);
  for(int i=0;i<count;++i){uint64_t value;memcpy(&value,changed+fields[i],8);value+=(uint64_t)delta;memcpy(changed+fields[i],&value,8);}
  inspection_defaults(&state);CHECK(read_layout(&image,&state,&moved,NULL,&failure) && moved.image_base==(int64_t)moved_base);
  CHECK(validate_image_relocations(&image,&moved,&expected,&state,&result,NULL,&failure));
 }
 CHECK(memcmp(payload(expected),values,sizeof values)==0);
 printf("PASS image pointer associations %d; rejected %d; bytes %lld; events %lld\n",count,count*3,(long long)required_bytes,(long long)required_events);
 free(bytes);image=expected=NULL;CHECK(ube_gc_root_leave(&roots[1]) && ube_gc_root_leave(&roots[0]) && ube_gc_collect() && ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);return 0;
}
