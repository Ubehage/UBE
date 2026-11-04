/* Included after probe helpers: independent synthetic symbol/name oracles. */
struct object_name {int32_t first,count;};
struct object_symbol {struct object_name name;int64_t value;int32_t section,type,storage,auxiliary,auxiliary_first,next;};
struct object_relocation {int64_t offset,target;int32_t kind,width,relative_end;};
extern int32_t read_name(void**,struct inspection*,struct layout*,int32_t,struct object_name*,void*,struct failure*);
extern int32_t read_symbol(void**,struct inspection*,struct layout*,int32_t,struct object_symbol*,void*,struct failure*);
extern int32_t read_relocation(void**,struct inspection*,struct layout*,struct section*,int32_t,struct object_relocation*,void*,struct failure*);
static void symbol_bytes(unsigned char* bytes){
 object_bytes(bytes,256);put(bytes,8,96,4);put(bytes,12,4,4);put(bytes,168,88,4);memcpy(bytes+172,"very_long_symbol",17);
 memset(bytes+96,0,8);put(bytes,100,4,4);put(bytes,104,7,4);put(bytes,108,1,2);put(bytes,110,32,2);put(bytes,112,2,1);put(bytes,113,2,1);
 /* Two auxiliaries are opaque bytes, never interpreted as primary symbols. */
 memset(bytes+114,0xFF,36);memcpy(bytes+150,"short123",8);put(bytes,158,UINT32_MAX,4);put(bytes,162,65535,2);put(bytes,166,3,1);
}
static int symbol_cases(void** owner,void** cancellation){
 CHECK(sizeof(struct object_symbol)==40 && sizeof(struct object_relocation)==32);
 unsigned char bytes[256];symbol_bytes(bytes);CHECK(replace(owner,bytes,sizeof bytes)==0);
 struct inspection state;struct layout layout;struct failure failure;struct object_name name;struct object_symbol symbol;struct section section;struct object_relocation relocation;
 inspection_defaults(&state);CHECK(read_layout(owner,&state,&layout,NULL,&failure));
 byte_visits=0;inspection_defaults(&state);ube_err_set(77,"prior","symbols");observe();
 CHECK(read_name(owner,&state,&layout,0,&name,NULL,&failure) && name.first==20 && name.count==5 && state.bytes==7 && byte_visits==7 && state.events==7 && clean_cost() && ube_err_number()==77);
 CHECK(read_symbol(owner,&state,&layout,0,&symbol,NULL,&failure) && symbol.name.first==172 && symbol.name.count==16 && symbol.value==7 && symbol.section==1 && symbol.type==32 && symbol.storage==2 && symbol.auxiliary==2 && symbol.auxiliary_first==114 && symbol.next==3);
 CHECK(read_symbol(owner,&state,&layout,symbol.next,&symbol,NULL,&failure) && symbol.name.first==150 && symbol.name.count==8 && symbol.value==UINT32_MAX && symbol.section==-1 && symbol.auxiliary==0 && symbol.next==4);
 struct object_symbol saved=symbol;
 for(int section_number=-2;section_number<=1;++section_number){symbol_bytes(bytes);put(bytes,162,(uint16_t)section_number,2);CHECK(replace(owner,bytes,sizeof bytes)==0);inspection_defaults(&state);CHECK(read_symbol(owner,&state,&layout,3,&symbol,NULL,&failure) && symbol.section==section_number);}
 const struct change {int at,width;uint64_t value;} bad[]={{100,4,0},{100,4,3},{100,4,88},{100,4,UINT32_MAX},{108,2,2},{108,2,65533},{108,2,32768},{113,1,4},{113,1,255}};
 for(size_t i=0;i<sizeof bad/sizeof bad[0];++i){symbol_bytes(bytes);put(bytes,bad[i].at,bad[i].value,bad[i].width);CHECK(replace(owner,bytes,sizeof bytes)==0);inspection_defaults(&state);symbol=saved;CHECK(!read_symbol(owner,&state,&layout,0,&symbol,NULL,&failure) && failure.code==1506 && memcmp(&symbol,&saved,sizeof symbol)==0);}
 symbol_bytes(bytes);memset(bytes+172,'X',84);CHECK(replace(owner,bytes,sizeof bytes)==0);inspection_defaults(&state);symbol=saved;CHECK(!read_symbol(owner,&state,&layout,0,&symbol,NULL,&failure) && failure.code==1506 && memcmp(&symbol,&saved,sizeof symbol)==0);
 const char* valid[]={"/4","/000004","ABCDEFGH",".x"};const int lengths[]={16,16,8,2};
 for(size_t i=0;i<sizeof valid/sizeof valid[0];++i){symbol_bytes(bytes);memset(bytes+20,0,8);memcpy(bytes+20,valid[i],strlen(valid[i]));CHECK(replace(owner,bytes,sizeof bytes)==0);inspection_defaults(&state);CHECK(read_name(owner,&state,&layout,0,&name,NULL,&failure) && name.count==lengths[i] && memcmp(payload(*owner)+name.first,i<2?"very_long_symbol":valid[i],(size_t)name.count)==0);}
 struct object_name saved_name=name;const char* invalid[]={"/","/3","/88","/9999999","/4x","/-4","/+4","//4"};
 for(size_t i=0;i<sizeof invalid/sizeof invalid[0];++i){symbol_bytes(bytes);memset(bytes+20,0,8);memcpy(bytes+20,invalid[i],strlen(invalid[i]));CHECK(replace(owner,bytes,sizeof bytes)==0);inspection_defaults(&state);name=saved_name;CHECK(!read_name(owner,&state,&layout,0,&name,NULL,&failure) && failure.code==1506 && memcmp(&name,&saved_name,sizeof name)==0);}
 symbol_bytes(bytes);memcpy(bytes+20,"/87",4);bytes[255]=0;CHECK(replace(owner,bytes,sizeof bytes)==0);inspection_defaults(&state);CHECK(read_name(owner,&state,&layout,0,&name,NULL,&failure) && name.first==255 && name.count==0);
 bytes[255]='X';CHECK(replace(owner,bytes,sizeof bytes)==0);inspection_defaults(&state);CHECK(!read_name(owner,&state,&layout,0,&name,NULL,&failure) && failure.code==1506);
 symbol_bytes(bytes);CHECK(replace(owner,bytes,sizeof bytes)==0);
 /* Fixed primary fields (10), union prefix (8), 16-name bytes and terminator. */
 for(int resource=0;resource<2;++resource)for(int delta=-1;delta<=0;++delta){inspection_defaults(&state);if(resource)state.maximum_events=24+delta;else state.maximum_bytes=35+delta;symbol=saved;byte_visits=0;int ok=read_symbol(owner,&state,&layout,0,&symbol,NULL,&failure);CHECK(ok==(delta==0) && byte_visits==state.bytes);if(!ok)CHECK(failure.code==1502 && failure.resource==7 && memcmp(&symbol,&saved,sizeof symbol)==0);}
 inspection_defaults(&state);CHECK(!read_symbol(owner,&state,&layout,-1,&symbol,NULL,&failure) && failure.code==1509 && state.bytes==0);CHECK(!read_symbol(owner,&state,&layout,4,&symbol,NULL,&failure) && failure.code==1509 && state.bytes==0);
 /* One real patch at the last fitting byte, then one byte beyond it. */
 for(int kind=0;kind<=11;++kind){symbol_bytes(bytes);put(bytes,44,68,4);put(bytes,52,1,2);int width=kind==0?0:kind==1?8:kind==10?2:4;int relative=kind>=4 && kind<=9?kind:0;put(bytes,68,8-width,4);put(bytes,72,3,4);put(bytes,76,(unsigned)kind,2);CHECK(replace(owner,bytes,sizeof bytes)==0);inspection_defaults(&state);CHECK(read_section(owner,&state,&layout,0,&section,NULL,&failure));inspection_defaults(&state);byte_visits=0;observe();CHECK(read_relocation(owner,&state,&layout,&section,0,&relocation,NULL,&failure) && relocation.offset==8-width && relocation.target==3 && relocation.kind==kind && relocation.width==width && relocation.relative_end==relative && state.bytes==10 && state.events==3 && byte_visits==10 && clean_cost());
  struct object_relocation saved_relocation=relocation;if(kind){put(bytes,68,9-width,4);CHECK(replace(owner,bytes,sizeof bytes)==0);inspection_defaults(&state);CHECK(!read_relocation(owner,&state,&layout,&section,0,&relocation,NULL,&failure) && failure.code==1506 && memcmp(&relocation,&saved_relocation,sizeof relocation)==0);}
 }
 const struct change bad_relocations[]={{68,4,UINT32_MAX},{72,4,4},{72,4,UINT32_MAX},{76,2,12},{76,2,16},{76,2,65535}};
 for(size_t i=0;i<sizeof bad_relocations/sizeof bad_relocations[0];++i){put(bytes,68,0,4);put(bytes,72,0,4);put(bytes,76,1,2);put(bytes,bad_relocations[i].at,bad_relocations[i].value,bad_relocations[i].width);CHECK(replace(owner,bytes,sizeof bytes)==0);inspection_defaults(&state);CHECK(!read_relocation(owner,&state,&layout,&section,0,&relocation,NULL,&failure) && failure.code==1506);}
 put(bytes,68,UINT32_MAX,4);put(bytes,72,UINT32_MAX,4);put(bytes,76,0,2);CHECK(replace(owner,bytes,sizeof bytes)==0);inspection_defaults(&state);CHECK(read_relocation(owner,&state,&layout,&section,0,&relocation,NULL,&failure) && relocation.width==0 && relocation.target==UINT32_MAX);
 for(int resource=0;resource<2;++resource)for(int delta=-1;delta<=0;++delta){inspection_defaults(&state);if(resource)state.maximum_events=3+delta;else state.maximum_bytes=10+delta;int ok=read_relocation(owner,&state,&layout,&section,0,&relocation,NULL,&failure);CHECK(ok==(delta==0));if(!ok)CHECK(failure.code==1502 && failure.resource==7);}
 /* Each new public boundary preserves outputs and counters on cancellation. */
 CHECK(make_cancel(cancellation));*(bool*)*cancellation=true;inspection_defaults(&state);struct inspection prior=state;
 name=saved_name;symbol=saved;struct object_relocation saved_relocation=relocation;
 CHECK(!read_name(owner,&state,&layout,0,&name,*cancellation,&failure) && failure.code==1507 && memcmp(&name,&saved_name,sizeof name)==0 && memcmp(&state,&prior,sizeof state)==0);
 CHECK(!read_symbol(owner,&state,&layout,0,&symbol,*cancellation,&failure) && failure.code==1507 && memcmp(&symbol,&saved,sizeof symbol)==0 && memcmp(&state,&prior,sizeof state)==0);
 CHECK(!read_relocation(owner,&state,&layout,&section,0,&relocation,*cancellation,&failure) && failure.code==1507 && memcmp(&relocation,&saved_relocation,sizeof relocation)==0 && memcmp(&state,&prior,sizeof state)==0);*cancellation=NULL;
 inspection_defaults(&state);ube_gc_test_fail_next_allocations(1000000);ube_err_set(77,"prior","allocation");observe();
 CHECK(read_name(owner,&state,&layout,0,&name,NULL,&failure) && read_symbol(owner,&state,&layout,0,&symbol,NULL,&failure) && read_relocation(owner,&state,&layout,&section,0,&relocation,NULL,&failure) && clean_cost() && ube_err_number()==77);ube_gc_test_fail_next_allocations(0);
 return 0;
}
static void print_name(void* owner,struct object_name n){for(int i=0;i<n.count;++i)printf("%02x",payload(owner)[n.first+i]);}
static int inspect_symbols(void** owner,struct inspection* state,struct layout* layout,struct failure* failure){
 for(int i=0;i<layout->section_count;++i){struct object_name name;CHECK(read_name(owner,state,layout,i,&name,NULL,failure));printf("name\t%d\t",i);print_name(*owner,name);putchar('\n');struct section section;CHECK(read_section(owner,state,layout,i,&section,NULL,failure));
  uint64_t digest=14695981039346656037ULL;for(int j=0;j<section.relocation_count;++j){struct object_relocation r;CHECK(read_relocation(owner,state,layout,&section,j,&r,NULL,failure));const uint64_t values[]={(uint64_t)r.offset,(uint64_t)r.target,(uint64_t)r.kind};for(int k=0;k<3;++k){digest^=values[k];digest*=1099511628211ULL;}}
  printf("relocations\t%d\t%d\t%llu\n",i,section.relocation_count,(unsigned long long)digest);
 }
 for(int i=0;i<layout->symbol_count;){struct object_symbol s;CHECK(read_symbol(owner,state,layout,i,&s,NULL,failure));printf("symbol\t%d\t",i);print_name(*owner,s.name);printf("\t%lld\t%d\t%d\t%d\t%d\t%d\n",(long long)s.value,s.section,s.type,s.storage,s.auxiliary,s.next);i=s.next;}
 return 0;
}
