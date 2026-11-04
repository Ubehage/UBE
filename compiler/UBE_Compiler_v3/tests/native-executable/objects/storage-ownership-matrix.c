/* The bridge supplies runtime ABI and observers, never the storage oracle. */
#include "reader-probe.c"
extern int32_t validate_storage_ownership(void**,struct layout*,struct expected_definitions*,void**,void**,void**,struct inspection*,void*,struct failure*);
static const struct ube_value_layout sm_rows_layout={40,0,0,NULL,0,NULL};
static const struct ube_value_layout sm_retained_layout={120,0,0,NULL,0,NULL};
static const struct ube_value_layout sm_order_layout={4,0,0,NULL,0,NULL};
static int sm_path(FILE* f,char** result){int32_t n;CHECK(fread(&n,4,1,f)==1 && n>0 && n<=32768);char* p=malloc((size_t)n+1);CHECK(p && fread(p,1,n,f)==(size_t)n);p[n]=0;*result=p;return 0;}
static void sm_order(int32_t* order,int count,const struct retained_definition* retained){for(int i=1;i<count;++i){int32_t row=order[i];int j=i;while(j && retained[order[j-1]].image.rva>retained[row].image.rva){order[j]=order[j-1];--j;}order[j]=row;}}
static void sm_pairs(int64_t* pairs,int count){for(int i=1;i<count;++i){int64_t rva=pairs[2*i],bytes=pairs[2*i+1];int j=i;while(j && pairs[2*j-2]>rva){pairs[2*j]=pairs[2*j-2];pairs[2*j+1]=pairs[2*j-1];--j;}pairs[2*j]=rva;pairs[2*j+1]=bytes;}}
static int sm_call(void** image,struct layout* layout,struct expected_definitions* expected,void** retained,void** order,void** protected,int wanted,int code,int64_t* bytes,int64_t* events){
 struct inspection state;struct failure failure;inspection_defaults(&state);
 struct layout old_layout=*layout;struct expected_definitions old_expected=*expected;
 void* owners[]={*image,expected->rows,expected->names,*retained,*order,*protected};unsigned char* copies_saved[6];size_t lengths[6],element_sizes[6];int32_t lowers[6],uppers[6];
 for(int i=0;i<6;++i){struct ube_array* a=owners[i];lowers[i]=a->lower;uppers[i]=a->upper;element_sizes[i]=a->element_size;lengths[i]=(size_t)(a->upper-a->lower+1)*a->element_size;copies_saved[i]=malloc(lengths[i]?lengths[i]:1);CHECK(copies_saved[i]);memcpy(copies_saved[i],a->data,lengths[i]);}
 inventory_observe(1);ube_err_set(77,"prior","storage ownership matrix");
 int accepted=validate_storage_ownership(image,layout,expected,retained,order,protected,&state,NULL,&failure);inventory_observation_end();
 if(accepted!=wanted || failure.code!=code)fprintf(stderr,"storage wanted=%d/%d actual=%d/%d bytes=%lld events=%lld\n",wanted,code,accepted,failure.code,(long long)state.bytes,(long long)state.events);
 CHECK(accepted==wanted && failure.code==code && state.bytes==byte_visits && state.bytes==inventory_bytes && state.events==inventory_events && !inventory_allocation_visits && !copies && ube_err_number()==77);
 CHECK(memcmp(layout,&old_layout,sizeof *layout)==0 && memcmp(expected,&old_expected,sizeof *expected)==0);
 void* after[]={*image,expected->rows,expected->names,*retained,*order,*protected};for(int i=0;i<6;++i){struct ube_array* a=after[i];CHECK(after[i]==owners[i] && a->lower==lowers[i] && a->upper==uppers[i] && a->element_size==element_sizes[i] && memcmp(payload(after[i]),copies_saved[i],lengths[i])==0);free(copies_saved[i]);}
 if(bytes)*bytes=state.bytes;if(events)*events=state.events;return 0;
}
int main(int argc,char** argv){
 CHECK(argc==5);void* image=NULL;void* object=NULL;void* retained=NULL;void* order=NULL;void* protected=NULL;struct expected_definitions expected={0};
 struct ube_gc_root roots[7]={{0}};void** slots[]={&image,&object,&expected.rows,&expected.names,&retained,&order,&protected};for(int i=0;i<7;++i)CHECK(ube_gc_root_enter(&roots[i],slots[i]));
 struct expected_definition* frozen=NULL;int32_t count;CHECK(retention_load(&image,argv[1])==0 && retention_expected(&expected.names,argv[2],&frozen,&count)==0 && count==54);
 CHECK(ube_value_try_resize(&expected.rows,count,&sm_rows_layout,0) && ube_value_try_resize(&retained,count,&sm_retained_layout,0));memcpy(payload(expected.rows),frozen,(size_t)count*40);
 expected.count=expected.capacity=count;expected.name_length=expected.name_capacity=((struct ube_array*)expected.names)->upper+1;expected.sources=3;expected.status=1;
 struct inventory_env b;struct layout layout;CHECK(retention_prepare(&b,&image,&layout)==0);FILE* manifest=fopen(argv[3],"rb");int32_t units;CHECK(manifest && fread(&units,4,1,manifest)==1 && units==9);int assigned[54]={0};
 for(int u=0;u<units;++u){int32_t kind,source;char* file=NULL;CHECK(fread(&kind,4,1,manifest)==1 && fread(&source,4,1,manifest)==1 && sm_path(manifest,&file)==0 && retention_load(&object,file)==0);free(file);struct inventory_env a;struct layout ol;CHECK(retention_prepare(&a,&object,&ol)==0);struct inspection state;struct failure failure;inspection_defaults(&state);
  for(int i=0;i<count;++i)if(frozen[i].unit==kind && frozen[i].source==source){CHECK(!assigned[i]);assigned[i]=1;CHECK(bind_definition(&frozen[i],&expected.names,&a.value,&object,&ol,&b.value,&image,&layout,&state,&((struct retained_definition*)payload(retained))[i],NULL,&failure));}
  CHECK(inventory_close(&a)==0);object=NULL;
 }
 CHECK(fgetc(manifest)==EOF && fclose(manifest)==0 && inventory_close(&b)==0);for(int i=0;i<count;++i)CHECK(assigned[i]);
 FILE* oracle=fopen(argv[4],"rb");int32_t owners,pairs;CHECK(oracle && fread(&owners,4,1,oracle)==1 && fread(&pairs,4,1,oracle)==1 && owners==16 && pairs>100 && pairs<256);
 CHECK(ube_value_try_resize(&order,owners,&sm_order_layout,0) && ube_value_try_resize(&protected,pairs*2,&binding_integer_layout,0));
 struct retained_definition* bound=(struct retained_definition*)payload(retained);int32_t expected_order[16];int present_storage=0;
 for(int i=0;i<count;++i)if(frozen[i].bytes && bound[i].present)++present_storage;CHECK(present_storage==owners);
 for(int i=0;i<owners;++i){int32_t v[7];int64_t q[4];CHECK(fread(v,sizeof v,1,oracle)==1 && fread(q,sizeof q,1,oracle)==1 && v[0]>=0 && v[0]<count);struct definition_range wanted={v[1],v[2],v[3],v[4],v[5],v[6],q[0],q[1],q[2],q[3]};CHECK(bound[v[0]].present==1 && memcmp(&bound[v[0]].image,&wanted,sizeof wanted)==0);expected_order[i]=v[0];if(i)CHECK(q[1]>=bound[expected_order[i-1]].image.rva+bound[expected_order[i-1]].image.count);}
 memcpy(payload(order),expected_order,sizeof expected_order);CHECK(fread(payload(protected),16,(size_t)pairs,oracle)==(size_t)pairs && fgetc(oracle)==EOF && fclose(oracle)==0);
 int64_t* saved_pairs=malloc((size_t)(pairs+1)*16);CHECK(saved_pairs);memcpy(saved_pairs,payload(protected),(size_t)pairs*16);
 struct retained_definition saved[54];memcpy(saved,payload(retained),sizeof saved);unsigned char* image_saved=malloc((size_t)layout.length);CHECK(image_saved);memcpy(image_saved,payload(image),(size_t)layout.length);
 int64_t required_bytes,required_events;CHECK(sm_call(&image,&layout,&expected,&retained,&order,&protected,1,0,&required_bytes,&required_events)==0);int rejected=0;
 /* Controls modify a single owner's descriptor, preserving the full catalogue. */
 for(int n=0;n<owners;++n){int row=expected_order[n];
  for(int defect=0;defect<12;++defect){memcpy(payload(retained),saved,sizeof saved);memcpy(payload(image),image_saved,(size_t)layout.length);memcpy(payload(order),expected_order,sizeof expected_order);bound=(struct retained_definition*)payload(retained);struct definition_range* r=&bound[row].image;
   if(defect<2){int peer=-1;for(int j=0;j<owners;++j){int other=expected_order[j];if(other!=row && saved[other].image.section==r->section){peer=other;break;}}CHECK(peer>=0);int64_t to=saved[peer].image.rva+(defect?1:0),delta=to-r->rva;r->rva+=delta;r->address+=delta;r->offset+=delta;r->first+=(int32_t)delta;sm_order((int32_t*)payload(order),owners,bound);}
   if(defect==2){int section=r->section;put(payload(image),layout.sections+40*section+36,(uint64_t)(r->characteristics|0x02000000),4);for(int i=0;i<count;++i)if(bound[i].present && bound[i].image.section==section)bound[i].image.characteristics|=0x02000000;}
   if(defect==3)++r->first;if(defect==4)++r->offset;if(defect==5)++r->rva;if(defect==6)++r->address;if(defect==7)--r->initialized;if(defect==8)--r->count;if(defect==9)++r->section;if(defect==10)r->rva=INT64_MAX;if(defect==11)r->characteristics^=0x80;
   if(sm_call(&image,&layout,&expected,&retained,&order,&protected,0,1506,NULL,NULL)){fprintf(stderr,"storage row=%d defect=%d\n",row,defect);return 1;}++rejected;
  }
  memcpy(payload(retained),saved,sizeof saved);memcpy(payload(image),image_saved,(size_t)layout.length);memcpy(payload(order),expected_order,sizeof expected_order);
  CHECK(ube_value_try_resize(&protected,(pairs+1)*2,&binding_integer_layout,0));memcpy(payload(protected),saved_pairs,(size_t)pairs*16);int64_t* spans=(int64_t*)payload(protected);spans[pairs*2]=saved[row].image.rva;spans[pairs*2+1]=1;sm_pairs(spans,pairs+1);CHECK(sm_call(&image,&layout,&expected,&retained,&order,&protected,0,1506,NULL,NULL)==0);++rejected;CHECK(ube_value_try_resize(&protected,pairs*2,&binding_integer_layout,0));memcpy(payload(protected),saved_pairs,(size_t)pairs*16);
 }
 /* Order completeness is enforced by count and disjoint ascending ownership. */
 int function=-1,absent=-1;for(int i=0;i<count;++i){if(!frozen[i].bytes && saved[i].present)function=i;if(!saved[i].present)absent=i;}CHECK(function>=0 && absent>=0);
 for(int defect=0;defect<7;++defect){CHECK(ube_value_try_resize(&order,defect==0?owners-1:owners,&sm_order_layout,0));memcpy(payload(order),expected_order,(size_t)(defect==0?owners-1:owners)*4);int32_t* indices=(int32_t*)payload(order);
  if(defect==1)indices[1]=indices[0];if(defect==2){int32_t t=indices[0];indices[0]=indices[1];indices[1]=t;}if(defect==3)indices[0]=function;if(defect==4)indices[0]=absent;if(defect==5)indices[0]=count;if(defect==6)indices[0]=-1;
  CHECK(sm_call(&image,&layout,&expected,&retained,&order,&protected,0,(defect==1 || defect==2)?1506:1509,NULL,NULL)==0);++rejected;
 }
 CHECK(ube_value_try_resize(&order,owners,&sm_order_layout,0));memcpy(payload(order),expected_order,sizeof expected_order);
 /* Protected completeness is the caller's independently enumerated precondition;
    arbitrary omissions cannot be detected from these borrowed intervals alone. */
 for(int defect=0;defect<5;++defect){CHECK(ube_value_try_resize(&protected,pairs*2-(defect==0),&binding_integer_layout,0));memcpy(payload(protected),saved_pairs,(size_t)(pairs*2-(defect==0))*8);int64_t* spans=(int64_t*)payload(protected);if(defect==1)spans[1]=0;if(defect==2)spans[0]=-1;if(defect==3)spans[0]=INT64_MAX;if(defect==4){spans[0]=saved_pairs[2]+1;}
  CHECK(sm_call(&image,&layout,&expected,&retained,&order,&protected,0,1509,NULL,NULL)==0);++rejected;
 }
 CHECK(ube_value_try_resize(&protected,pairs*2,&binding_integer_layout,0));memcpy(payload(protected),saved_pairs,(size_t)pairs*16);
 /* Repeated qualified views are legal; they do not create generated owners. */
 CHECK(ube_value_try_resize(&protected,(pairs+1)*2,&binding_integer_layout,0));memcpy(payload(protected),saved_pairs,(size_t)pairs*16);((int64_t*)payload(protected))[pairs*2]=saved_pairs[0];((int64_t*)payload(protected))[pairs*2+1]=saved_pairs[1];sm_pairs((int64_t*)payload(protected),pairs+1);CHECK(sm_call(&image,&layout,&expected,&retained,&order,&protected,1,0,NULL,NULL)==0);
 printf("PASS storage ownership %d rows; %d owners; %d protected; rejected %d; bytes %lld; events %lld\n",count,owners,pairs,rejected,(long long)required_bytes,(long long)required_events);
 free(frozen);free(saved_pairs);free(image_saved);image=object=expected.rows=expected.names=retained=order=protected=NULL;for(int i=6;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));CHECK(ube_gc_collect() && !ube_gc_root_count && !ube_gc_live_allocation_bytes());return 0;
}
