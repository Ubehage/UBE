#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdatomic.h>
#include <string.h>
extern int cli_actual_main(int,char**);
extern size_t index_root_count(void),index_root_limit(void),ube_gc_root_storage_size(void),ube_gc_live_allocation_bytes(void);
extern int32_t ube_gc_root_enter(void*,void**),ube_gc_root_leave(void*),ube_gc_collect(void);
extern int32_t ube_file_test_open_handles(void),ube_file_test_payloads(void);
extern void ube_file_test_inject(int32_t);
typedef union {uint64_t alignment;uint8_t bytes[32];} root;
static _Atomic size_t sites;
static _Atomic bool active;
static size_t failure_site;
static bool denied(void){if(!atomic_load(&active))return false;size_t n=atomic_fetch_add(&sites,1)+1;return failure_site&&n>=failure_site;}
void* probe_malloc(size_t n){return denied()?NULL:malloc(n);}
void* probe_calloc(size_t n,size_t s){return denied()?NULL:calloc(n,s);}
void* probe_realloc(void* p,size_t n){return denied()?NULL:realloc(p,n);}
void probe_free(void* p){free(p);}
void probe_value_copy(size_t n){(void)n;}
void index_root_changed(size_t n){(void)n;}
void name_heap_changed(size_t n){(void)n;}
static size_t number(const char* name,size_t fallback){const char* s=getenv(name);return s?(size_t)strtoull(s,NULL,10):fallback;}
int main(int argc,char** argv){
 if(sizeof(root)<ube_gc_root_storage_size()||index_root_count()!=0)return 91;
 size_t available=number("UBE_SEMANTIC_CLI_ROOTS",SIZE_MAX),fill=0;
 root* roots=NULL;void** slots=NULL;
 if(available!=SIZE_MAX){
  if(available>index_root_limit())return 92;
  fill=index_root_limit()-available;roots=calloc(fill?fill:1,sizeof *roots);slots=calloc(fill?fill:1,sizeof *slots);
  if(!roots||!slots)return 93;
  for(size_t i=0;i<fill;++i)if(!ube_gc_root_enter(&roots[i],&slots[i]))return 94;
 }
 ube_file_test_inject((int32_t)number("UBE_SEMANTIC_CLI_FILE",0));
 failure_site=number("UBE_SEMANTIC_CLI_ALLOC",0);
 atomic_store(&active,true);
 int status=cli_actual_main(argc,argv);
 atomic_store(&active,false);
 size_t count=atomic_load(&sites),root_count=index_root_count();
 int handles=ube_file_test_open_handles(),payloads=ube_file_test_payloads();
 if(root_count!=fill||handles!=0){fprintf(stderr,"CLI resource leak roots%zu/%zu handles%d\n",root_count,fill,handles);return 95;}
 for(size_t i=fill;i>0;--i)if(!ube_gc_root_leave(&roots[i-1]))return 96;
 free(roots);free(slots);(void)ube_gc_collect();
 if(index_root_count()!=0||ube_gc_live_allocation_bytes()!=0){fprintf(stderr,"CLI managed leak roots%zu heap%zu\n",index_root_count(),ube_gc_live_allocation_bytes());return 97;}
 fprintf(stderr,"MEASURE CLI sites:%zu roots:0 heap:0 handles:0 fileAllocations:%d\n",count,payloads);
 return status;
}
