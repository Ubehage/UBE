/* Copied beside the retained, instrumented probe by check-fixups.ps1. */
#include "probe.c"
#include "target-owners.h"
static int inspect_fixups(void** object,const char* object_path,const char* image_path,const char* expected_path,const char* instruction_path,const char* owner_path,int defect,const char* reference_path,const char* import_path,const char* thread_path){
 void* image=NULL;struct ube_gc_root root={0};CHECK(ube_gc_root_enter(&root,&image) && retention_load(object,object_path)==0 && retention_load(&image,image_path)==0);
 struct inventory_env a,b;struct layout ol,il;CHECK(retention_prepare(&a,object,&ol)==0 && retention_prepare(&b,&image,&il)==0);
 FILE* file=fopen(expected_path,"rb");int32_t count;CHECK(file && fread(&count,4,1,file)==1 && count>=0 && count<100000);
 FILE* instructions=NULL;if(instruction_path){int32_t n;instructions=fopen(instruction_path,"rb");CHECK(instructions && fread(&n,4,1,instructions)==1 && n==count);}
 struct generated_target_owner* owners=NULL;int32_t owner_count=0;
 if(owner_path){FILE* f=fopen(owner_path,"rb");CHECK(instructions && f && fread(&owner_count,4,1,f)==1 && owner_count>0 && owner_count<100000);owners=calloc(owner_count,sizeof *owners);CHECK(owners && fread(owners,160,owner_count,f)==(size_t)owner_count && fgetc(f)==EOF && fclose(f)==0);}
 struct reference_record {int32_t cell,referent,length;unsigned char* name;};struct reference_record* references=NULL;int32_t reference_count=0;void* names=NULL;struct ube_gc_root names_root={0};CHECK(ube_gc_root_enter(&names_root,&names));
 if(reference_path){FILE* f=fopen(reference_path,"rb");CHECK(owners && f && fread(&reference_count,4,1,f)==1 && reference_count>0 && reference_count<10000);references=calloc(reference_count,sizeof *references);CHECK(references);for(int j=0;j<reference_count;++j){struct reference_record* r=&references[j];CHECK(fread(&r->cell,4,1,f)==1 && fread(&r->referent,4,1,f)==1 && fread(&r->length,4,1,f)==1 && r->length>0 && r->length<4096);r->name=malloc(r->length);CHECK(r->name && fread(r->name,1,r->length,f)==(size_t)r->length);}CHECK(fgetc(f)==EOF && fclose(f)==0);}
 struct import_record {int32_t cell,library_length,procedure_length;unsigned char* names;};struct import_record* imports=NULL;int32_t import_count=0;
 if(import_path){FILE* f=fopen(import_path,"rb");CHECK(references && f && fread(&import_count,4,1,f)==1 && import_count>0 && import_count<10000);imports=calloc(import_count,sizeof *imports);CHECK(imports);for(int j=0;j<import_count;++j){struct import_record* r=&imports[j];CHECK(fread(&r->cell,4,1,f)==1 && fread(&r->library_length,4,1,f)==1 && fread(&r->procedure_length,4,1,f)==1 && r->library_length>0 && r->library_length<4096 && r->procedure_length>0 && r->procedure_length<4096);int size=r->library_length+r->procedure_length;r->names=malloc(size);CHECK(r->names && fread(r->names,1,size,f)==(size_t)size);}CHECK(fgetc(f)==EOF && fclose(f)==0);}
 int owned=0,referenced=0,imported=0,thread_indexes=0,thread_members=0,mutated=0;
 struct target_cache {int ready;struct definition_range target;};struct target_cache* cache=calloc((size_t)ol.symbol_count+1,sizeof *cache);CHECK(cache);
 struct inspection state;inspection_defaults(&state);struct failure failure;int observed=0;struct thread_storage thread_store;int32_t thread_symbol=-1;
 if(thread_path){struct thread_storage wanted;FILE* f=fopen(thread_path,"rb");CHECK(imports && f && fread(&wanted,sizeof wanted,1,f)==1 && fread(&thread_symbol,4,1,f)==1 && thread_symbol>=0 && fgetc(f)==EOF && fclose(f)==0);int ok=read_thread_storage(&image,&il,&state,&thread_store,NULL,&failure);if(!ok)fprintf(stderr,"thread metadata code=%d\n",failure.code);CHECK(ok && failure.code==0 && memcmp(&thread_store,&wanted,sizeof wanted)==0);}
 for(int si=0;si<ol.section_count;++si){
  struct section s;CHECK(read_section(object,&state,&ol,si,&s,NULL,&failure));if(!(s.characteristics&0x20000000))continue;
  for(int ri=0;ri<s.relocation_count;++ri){
   int32_t row[3];int64_t site;struct definition_range expected;
   CHECK(fread(row,sizeof row,1,file)==1 && fread(&site,8,1,file)==1 && fread(&expected,56,1,file)==1 && row[0]==si && row[1]==ri);
   struct object_relocation rel;CHECK(read_relocation(object,&state,&ol,&s,ri,&rel,NULL,&failure) && rel.target>=0 && rel.target<ol.symbol_count);
   struct target_cache* entry=&cache[rel.target];
   if(!entry->ready){
    struct object_symbol symbol;CHECK(inventory_read(&a.value,(int32_t)rel.target,&state,&symbol,NULL,&failure));
    if(symbol.storage==3 && symbol.auxiliary==1){struct retained_definition bound;CHECK(bind_constant((int32_t)rel.target,&a.value,object,&ol,&image,&il,&state,&bound,NULL,&failure) && bound.present==1);entry->target=bound.image;}
    else CHECK(resolve_named_relocation(&rel,&a.value,object,&ol,&b.value,&image,&il,&state,&entry->target,NULL,&failure));
    entry->ready=1;
   }
   CHECK(memcmp(&entry->target,&expected,56)==0 && rel.offset>=0 && rel.offset<=INT32_MAX-s.raw_first);
   int ok=validate_fixup(&rel,&entry->target,site,object,s.raw_first+(int32_t)rel.offset,&image,row[2],&state,NULL,&failure);
   if(!ok)fprintf(stderr,"relocation value section=%d index=%d code=%d\n",si,ri,failure.code);
   CHECK(ok && failure.code==0);
   if(instructions){int32_t header[2],image_first;int64_t instruction_offset,instruction_rva,expected_position,result=INT64_MAX;
    CHECK(fread(header,sizeof header,1,instructions)==1 && fread(&instruction_offset,8,1,instructions)==1 && fread(&image_first,4,1,instructions)==1 && fread(&instruction_rva,8,1,instructions)==1 && fread(&expected_position,8,1,instructions)==1);
    struct instruction ins;CHECK(read_instruction(object,header[0],header[1],&state,&ins,NULL,&failure) && ins.length==header[1]);
    ok=instruction_relocation_target(&ins,instruction_offset,&rel,&entry->target,instruction_rva,&image,image_first,&state,&result,NULL,&failure);
    if(!ok)fprintf(stderr,"instruction target section=%d index=%d code=%d\n",si,ri,failure.code);
    if(ok && result!=expected_position)fprintf(stderr,"instruction target mismatch section=%d index=%d\n",si,ri);
    CHECK(ok && result==expected_position && failure.code==0);
    if(owners){struct generated_target_owner* owner=NULL;for(int j=0;j<owner_count;++j)if(owners[j].retained.image.symbol==entry->target.symbol){CHECK(!owner);owner=&owners[j];}
     if(owner){struct instruction access=ins;struct definition_range anchor=entry->target;struct generated_target_owner bound=*owner;int64_t destination=result;
      if(defect>=1 && defect<=4 && !mutated){mutated=1;if(defect==1)destination=(rel.kind==11?bound.retained.image.offset:bound.retained.image.rva)+bound.retained.image.count;if(defect==2)++anchor.symbol;if(defect==3)++bound.retained.image.address;if(defect==4)access.memory_bytes=16;}
      ok=validate_generated_target(&access,&rel,&anchor,destination,&bound.expected,&bound.retained,&state,NULL,&failure);if(!ok)fprintf(stderr,"generated target section=%d index=%d code=%d\n",si,ri,failure.code);CHECK(ok && failure.code==0);++owned;
      if(thread_path && (owner->expected.family==12 || owner->expected.family==22)){struct generated_target_owner member=*owner;int changed_byte=0;if(defect>=15 && defect<=16 && !mutated){mutated=1;if(defect==15){((unsigned char*)payload(image))[member.retained.image.first]^=1;changed_byte=1;}if(defect==16)++member.retained.image.address;}ok=validate_thread_member(&member.expected,&member.retained,&image,&il,&thread_store,&state,NULL,&failure);if(changed_byte)((unsigned char*)payload(image))[member.retained.image.first]^=1;if(!ok)fprintf(stderr,"thread member section=%d index=%d code=%d\n",si,ri,failure.code);CHECK(ok && failure.code==0);++thread_members;}
     }
    }
    if(references){struct reference_record* association=NULL;for(int j=0;j<reference_count;++j)if(references[j].cell==entry->target.symbol){CHECK(!association);association=&references[j];}
     if(association){struct generated_target_owner* owner=NULL;for(int j=0;j<owner_count;++j)if(owners[j].retained.image.symbol==association->referent){CHECK(!owner);owner=&owners[j];}CHECK(owner && replace(&names,association->name,association->length)==0);struct generated_target_owner bound=*owner;bound.expected.name.first=0;bound.expected.name.count=association->length;struct definition_range cell,wanted=expected;wanted.count=wanted.initialized=8;int64_t destination=result;int changed_byte=0;
      if(defect>=5 && defect<=8 && !mutated){mutated=1;if(defect==5)++destination;if(defect==6){((unsigned char*)payload(image))[entry->target.first]^=1;changed_byte=1;}if(defect==7)++bound.retained.image.address;if(defect==8)((unsigned char*)payload(names))[0]^=1;}
      ok=bind_reference_pointer(&ins,&entry->target,destination,&bound.expected,&bound.retained,&names,&b.value,&image,&il,&state,&cell,NULL,&failure);if(changed_byte)((unsigned char*)payload(image))[entry->target.first]^=1;if(!ok)fprintf(stderr,"reference pointer section=%d index=%d code=%d\n",si,ri,failure.code);CHECK(ok && failure.code==0 && memcmp(&cell,&wanted,sizeof cell)==0);++referenced;
     }
    }
    if(imports){struct import_record* association=NULL;for(int j=0;j<import_count;++j)if(imports[j].cell==entry->target.symbol){CHECK(!association);association=&imports[j];}
     if(association){CHECK(replace(&names,association->names,association->library_length+association->procedure_length)==0);struct object_name library={0,association->library_length},procedure={association->library_length,association->procedure_length};struct definition_range cell,wanted=expected;wanted.count=wanted.initialized=8;int64_t destination=result;int changed_byte=0;
      if(defect>=9 && defect<=12 && !mutated){mutated=1;if(defect==9)((unsigned char*)payload(names))[0]^=1;if(defect==10)((unsigned char*)payload(names))[procedure.first]^=1;if(defect==11)++destination;if(defect==12){((unsigned char*)payload(image))[entry->target.first]^=1;changed_byte=1;}}
      ok=bind_import_target(&ins,&entry->target,destination,&names,&library,&procedure,&image,&il,&state,&cell,NULL,&failure);if(changed_byte)((unsigned char*)payload(image))[entry->target.first]^=1;if(!ok)fprintf(stderr,"import target section=%d index=%d code=%d\n",si,ri,failure.code);CHECK(ok && failure.code==0 && memcmp(&cell,&wanted,sizeof cell)==0);++imported;
     }
    }
    if(thread_path && entry->target.symbol==thread_symbol){struct definition_range anchor=entry->target,cell,wanted=expected;wanted.count=wanted.initialized=4;int64_t destination=result;if(defect>=13 && defect<=14 && !mutated){mutated=1;if(defect==13)++destination;if(defect==14)++anchor.address;}ok=bind_thread_index(&ins,&anchor,destination,&thread_store,&state,&cell,NULL,&failure);if(!ok)fprintf(stderr,"thread index section=%d index=%d code=%d\n",si,ri,failure.code);CHECK(ok && failure.code==0 && memcmp(&cell,&wanted,sizeof cell)==0);++thread_indexes;}
   }
   ++observed;
  }
 }
 CHECK(observed==count && fgetc(file)==EOF && fclose(file)==0);if(instructions){CHECK(fgetc(instructions)==EOF && fclose(instructions)==0);if(thread_path)printf("PASS %d relocated fields; %d signed instruction targets; %d generated owners; %d reference pointers; %d import targets; %d TLS indexes; %d TLS members\n",observed,observed,owned,referenced,imported,thread_indexes,thread_members);else if(imports)printf("PASS %d relocated fields; %d signed instruction targets; %d generated owners; %d reference pointers; %d import targets\n",observed,observed,owned,referenced,imported);else if(references)printf("PASS %d relocated fields; %d signed instruction targets; %d generated owners; %d reference pointers\n",observed,observed,owned,referenced);else if(owners)printf("PASS %d relocated fields; %d signed instruction targets; %d generated owners\n",observed,observed,owned);else printf("PASS %d relocated fields; %d signed instruction targets\n",observed,observed);}else printf("PASS %d relocated fields\n",observed);
 CHECK(!defect || mutated);for(int j=0;j<import_count;++j)free(imports[j].names);free(imports);for(int j=0;j<reference_count;++j)free(references[j].name);free(references);names=NULL;CHECK(ube_gc_root_leave(&names_root));free(owners);free(cache);CHECK(inventory_close(&b)==0 && inventory_close(&a)==0);image=NULL;CHECK(ube_gc_root_leave(&root));return 0;
}
int main(int argc,char** argv){
 CHECK(argc==4 || argc==5 || argc==7 || argc==8 || argc==9 || argc==10);void* object=NULL;struct ube_gc_root root={0};CHECK(ube_gc_root_enter(&root,&object));
 CHECK(inspect_fixups(&object,argv[1],argv[2],argv[3],argc>=5?argv[4]:NULL,argc>=7?argv[5]:NULL,argc>=7?atoi(argv[6]):0,argc>=8?argv[7]:NULL,argc>=9?argv[8]:NULL,argc==10?argv[9]:NULL)==0);object=NULL;
 CHECK(ube_gc_root_leave(&root) && ube_gc_collect() && ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);return 0;
}
