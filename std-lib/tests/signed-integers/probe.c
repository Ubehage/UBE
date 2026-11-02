#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <inttypes.h>
#include "value_storage.h"
typedef union {uint64_t alignment;uint8_t bytes[32];} root;
struct object_layout {size_t size,roots;const size_t* offsets;void (*finalizer)(void*);};
extern int32_t numeric_decode(void**,int32_t,int32_t,int32_t,int64_t,int64_t,int64_t*,int32_t*);
extern int32_t numeric_evaluate(int32_t,int64_t,int64_t,int64_t,int64_t,int64_t*,int32_t*),numeric_compare(int64_t,int64_t);
extern size_t ube_gc_root_storage_size(void),ube_gc_live_allocation_bytes(void);
extern int32_t ube_gc_root_enter(void*,void**),ube_gc_root_leave(void*),ube_gc_collect(void),ube_err_number(void);
extern void ube_err_set(int32_t,const char*,const char*);
extern void* ube_err_description(void);
extern void* ube_err_source(void);
extern int32_t ube_gc_publish(void*);
extern void* ube_array_element(void*,int32_t);
extern void* ube_gc_allocate(const struct object_layout*);
static unsigned assertions;
#define CHECK(value) do {++assertions;if(!(value)){fprintf(stderr,"signed integer assertion %u line %d: %s\n",assertions,__LINE__,#value);return 1;}} while(0)
/* Native public Err getters run after observation has stopped. They allocate
   their own test-only copies, independently of the candidate call. */
static int error_preserved(int32_t number,const char* description,const char* source){
 CHECK(ube_err_number()==number);const char* actual_description=ube_err_description();const char* actual_source=ube_err_source();
 CHECK(actual_description&&actual_source&&strcmp(actual_description,description)==0&&strcmp(actual_source,source)==0&&ube_err_number()==number);
 CHECK(ube_gc_publish((void*)actual_description)&&ube_gc_publish((void*)actual_source));return 0;
}
static const struct ube_value_layout byte_layout={1,0,0,NULL,0,NULL};
struct arithmetic_case {int operation;int64_t left,right,value;int32_t error;};
#include "arithmetic-cases.h"
#include "observation.h"
#include "arithmetic-tests.h"
#include "decimal-cases.h"

static int decimal_fixtures(void){
 void* bytes=NULL;root owner={0};CHECK(ube_gc_root_storage_size()<=sizeof owner&&ube_gc_root_enter(&owner,&bytes));
 for(size_t index=0;index<sizeof decimal_cases/sizeof decimal_cases[0];++index){const struct decimal_case* expected=decimal_cases+index;CHECK(ube_value_try_resize(&bytes,expected->length,&byte_layout,0));for(int32_t i=0;i<expected->length;++i)*(uint8_t*)ube_array_element(bytes,i)=(uint8_t)expected->bytes[i];
  for(int32_t seed=7;seed<=77;seed+=70){int64_t value=71;int32_t failure=5;ube_err_set(seed,"previous","decimal span");numeric_start();int ok=numeric_decode(&bytes,expected->first,expected->count,expected->negative,expected->minimum,expected->maximum,&value,&failure);size_t reads=observed.byte_reads;
   CHECK(numeric_stop(ok?expected->count:-1,0,8*reads+8)==0);
   CHECK(ok==(expected->failure==0)&&failure==expected->failure&&value==expected->value&&error_preserved(seed,"previous","decimal span")==0);
   CHECK(reads<=(size_t)(expected->count>0?expected->count:0));
   for(int32_t i=0;i<expected->length;++i)CHECK(*(uint8_t*)ube_array_element(bytes,i)==(uint8_t)expected->bytes[i]);
  }
 }
 const int32_t sizes[]={0,1,8,64,1024,16384};
 for(size_t c=0;c<sizeof sizes/sizeof sizes[0];++c){int32_t count=sizes[c];CHECK(ube_value_try_resize(&bytes,count,&byte_layout,0));for(int32_t i=0;i<count;++i)*(uint8_t*)ube_array_element(bytes,i)=(uint8_t)(i+1==count?'7':'0');int64_t value=71;int32_t failure=5;ube_err_set(77,"previous","decimal linear work");numeric_start();int ok=numeric_decode(&bytes,0,count,0,INT64_MIN,INT64_MAX,&value,&failure);CHECK(numeric_stop(count,0,8*(size_t)count+8)==0);
  CHECK(ok==(count>0)&&failure==(count>0?0:2)&&value==(count>0?7:71)&&error_preserved(77,"previous","decimal linear work")==0);
  for(int32_t i=0;i<count;++i)CHECK(*(uint8_t*)ube_array_element(bytes,i)==(uint8_t)(i+1==count?'7':'0'));
  printf("{\"phase\":\"decode\",\"n\":%d,\"actualByteReads\":%zu,\"actualReaderCalls\":%zu,\"actualMachineCalls\":%zu,\"allocations\":%zu,\"copied\":%zu,\"rootsBefore\":%zu,\"peakRoots\":%zu,\"heapBefore\":%zu,\"heapPeak\":%zu,\"passed\":true}\n",count,observed.byte_reads,observed.read_calls,observed.machine_calls,observed.allocations,observed.copies,observed.roots_before,observed.root_peak,observed.heap_before,observed.heap_peak);
 }
 CHECK(ube_gc_root_leave(&owner));(void)ube_gc_collect();CHECK(index_root_count()==0&&ube_gc_live_allocation_bytes()==0);printf("{\"suite\":\"decimal\",\"passed\":true,\"cases\":%zu,\"staleErrSeeds\":2,\"scalingCases\":6}\n",sizeof decimal_cases/sizeof decimal_cases[0]);return 0;
}
static int actual_helper_control(void){
 ube_err_set(77,"previous","numeric machine-helper observer");numeric_start();CHECK(numeric_checked_add_i64(1,2)==3&&numeric_checked_add_i32(3,4)==7);numeric_pause();CHECK(observed.machine_calls==2&&observed.allocations==0&&observed.copies==0&&observed.byte_reads==0&&observed.root_peak==observed.roots_before&&error_preserved(77,"previous","numeric machine-helper observer")==0);
 int64_t value=71;int32_t failure=5;numeric_start();CHECK(numeric_evaluate(1,20,22,INT64_MIN,INT64_MAX,&value,&failure));CHECK(numeric_stop(0,1,8)==0);CHECK(value==42&&failure==0&&observed.machine_calls>0&&error_preserved(77,"previous","numeric machine-helper observer")==0);
 printf("{\"suite\":\"machine-observer-control\",\"directCalls\":2,\"actualUbeCalls\":%zu,\"passed\":true}\n",observed.machine_calls);return 0;
}
static int heap_copy_control(void){
 void* object=NULL;void* source=NULL;void* destination=NULL;root roots[3]={0};CHECK(ube_gc_root_enter(&roots[0],&object)&&ube_gc_root_enter(&roots[1],&source)&&ube_gc_root_enter(&roots[2],&destination));static const struct object_layout layout={1024,0,NULL,NULL};numeric_start();object=ube_gc_allocate(&layout);CHECK(object&&ube_value_try_resize(&source,17,&byte_layout,0)&&ube_value_try_resize(&destination,17,&byte_layout,0));numeric_pause();size_t expected=observed.heap_before+1024+2*(17+index_array_header());CHECK(observed.heap_events==3&&observed.heap_callback_peak==expected&&observed.heap_peak==expected);CHECK(observed.allocations>=3&&observed.requested>=expected-observed.heap_before+3*index_gc_header()&&observed.zeroed>=expected-observed.heap_before+3*index_gc_header());size_t allocation_control=observed.allocations;
 for(int32_t i=0;i<17;++i)*(uint8_t*)ube_array_element(source,i)=(uint8_t)i;
 numeric_start();CHECK(ube_value_copy_bytes(&source,0,&destination,0,17));numeric_pause();CHECK(observed.copies==17&&observed.allocations==0&&observed.heap_events==0);
 for(int32_t i=0;i<17;++i)CHECK(*(uint8_t*)ube_array_element(destination,i)==(uint8_t)i);
#ifdef NEGATIVE_NUMERIC_COPY
 numeric_start();CHECK(ube_value_copy_bytes(&source,0,&destination,0,17));CHECK(numeric_stop(0,1,8)==0);
#endif
#ifdef NEGATIVE_NUMERIC_ALLOCATION
 numeric_start();void* forbidden=probe_malloc(1);CHECK(forbidden);probe_free(forbidden);CHECK(numeric_stop(0,1,8)==0);
#endif
 for(int i=2;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));(void)ube_gc_collect();CHECK(index_root_count()==0&&ube_gc_live_allocation_bytes()==0);printf("{\"suite\":\"heap-copy-observer-control\",\"actualCopiedBytes\":17,\"actualAllocatorCalls\":%zu,\"heapIncrementCallbacks\":3,\"ordinaryObjectPayload\":1024,\"arrayHeader\":%zu,\"gcHeader\":%zu,\"passed\":true}\n",allocation_control,index_array_header(),index_gc_header());return 0;
}
static int numeric_root_pressure(void){
 static const char digits[]="9223372036854775808";void* bytes=NULL;root owner={0};CHECK(ube_gc_root_enter(&owner,&bytes)&&ube_value_try_resize(&bytes,19,&byte_layout,0));for(int32_t i=0;i<19;++i)*(uint8_t*)ube_array_element(bytes,i)=(uint8_t)digits[i];
 int64_t value=71;int32_t failure=5;ube_err_set(77,"previous","decimal root requirement");numeric_start();CHECK(numeric_decode(&bytes,0,19,1,INT64_MIN,INT64_MAX,&value,&failure));CHECK(numeric_stop(19,0,160)==0);size_t required=observed.root_peak-observed.roots_before;CHECK(required>0&&required<=16&&value==INT64_MIN&&failure==0&&error_preserved(77,"previous","decimal root requirement")==0);
 (void)ube_gc_collect();size_t baseline_bytes=ube_gc_live_allocation_bytes(),capacity=index_root_limit()-index_root_count();root* backed=calloc(capacity,sizeof *backed);void** holders=calloc(capacity,sizeof *holders);CHECK(backed&&holders&&capacity>required+1);for(size_t i=0;i<capacity;++i)CHECK(ube_gc_root_enter(&backed[i],&holders[i]));CHECK(index_root_count()==index_root_limit());CHECK(arithmetic_cases()==0&&index_root_count()==index_root_limit());
 for(size_t available=0;available<=required+1;++available){if(available)CHECK(ube_gc_root_leave(&backed[capacity-available]));value=71;failure=5;size_t roots=index_root_count();ube_err_set(77,"previous","decimal actual root denial");numeric_start();int ok=numeric_decode(&bytes,0,19,1,INT64_MIN,INT64_MAX,&value,&failure);numeric_pause();CHECK(ok==(available>=required)&&index_root_count()==roots&&roots==index_root_limit()-available);CHECK(observed.allocations==0&&observed.copies==0&&observed.heap_events==0&&observed.byte_reads<=19);
  if(ok){CHECK(numeric_stop(19,0,160)==0);CHECK(failure==0&&value==INT64_MIN&&error_preserved(77,"previous","decimal actual root denial")==0);}else CHECK(failure==5&&value==71&&ube_err_number()==7);
  for(int32_t i=0;i<19;++i)CHECK(*(uint8_t*)ube_array_element(bytes,i)==(uint8_t)digits[i]);(void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==baseline_bytes);
  printf("{\"phase\":\"root-capacity\",\"available\":%zu,\"required\":%zu,\"actualRootsBefore\":%zu,\"actualRootPeak\":%zu,\"actualByteReads\":%zu,\"actualMachineCalls\":%zu,\"result\":%" PRId64 ",\"failure\":%d,\"err\":%d,\"passed\":true}\n",available,required,observed.roots_before,observed.root_peak,observed.byte_reads,observed.machine_calls,value,failure,ube_err_number());
 }
 for(size_t i=0;i<capacity-required-1;++i)CHECK(ube_gc_root_leave(&backed[i]));free(holders);free(backed);CHECK(index_root_count()==1&&ube_gc_root_leave(&owner));(void)ube_gc_collect();CHECK(index_root_count()==0&&ube_gc_live_allocation_bytes()==0);
 printf("{\"suite\":\"numeric-root-pressure\",\"required\":%zu,\"capacities\":%zu,\"realBacked\":true,\"scalarArithmeticAtFullRegistry\":true,\"oldOutputPreserved\":true,\"passed\":true}\n",required,required+2);return 0;
}
int main(int argc,char** argv){
 CHECK(sizeof cases/sizeof cases[0]==79&&sizeof decimal_cases/sizeof decimal_cases[0]==43);
 if(argc==3&&strcmp(argv[1],"--controls")==0){
  if(strcmp(argv[2],"heap")==0){CHECK(heap_copy_control()==0);return 0;}
  if(strcmp(argv[2],"machine")==0){CHECK(actual_helper_control()==0);return 0;}
  if(strcmp(argv[2],"decimal")==0){CHECK(decimal_fixtures()==0);return 0;}
  if(strcmp(argv[2],"arithmetic")==0){CHECK(arithmetic_cases()==0);return 0;}
  return 2;
 }
 if(argc!=1)return 2;
 CHECK(heap_copy_control()==0&&actual_helper_control()==0&&arithmetic_cases()==0&&decimal_fixtures()==0&&numeric_root_pressure()==0);printf("PASS signed integer native assertions:%u\n",assertions);return 0;
}
