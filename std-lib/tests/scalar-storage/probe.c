#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
typedef union {uint64_t alignment;uint8_t bytes[32];} root;
extern int32_t plan_capacity(int32_t,int32_t,int32_t,int32_t*),encode_scalar(int32_t,uint8_t*,uint8_t*,uint8_t*,uint8_t*,int32_t*);
extern size_t ube_gc_root_storage_size(void),ube_gc_live_allocation_bytes(void);
extern int32_t ube_gc_root_enter(void*,void**),ube_gc_root_leave(void*),ube_gc_collect(void),ube_err_number(void);
extern void ube_err_set(int32_t,const char*,const char*);
#include "observation.h"
static unsigned assertions;
#define CHECK(test) do{++assertions;if(!(test)){fprintf(stderr,"capacity assertion %u line %d: %s\n",assertions,__LINE__,#test);return 1;}}while(0)
struct capacity_case {int32_t capacity,required,maximum,prepared,ok;size_t steps;};
static const struct capacity_case capacities[]={
 {0,0,0,0,1,0},{0,0,1,0,1,0},{0,1,1,1,1,0},{0,1,7,7,1,0},{0,7,7,7,1,0},
 {0,8,8,8,1,0},{0,9,9,9,1,1},{0,9,10,10,1,1},{0,9,15,15,1,1},{0,9,16,16,1,1},{0,17,17,17,1,2},
 {1,1,1,1,1,0},{1,2,2,2,1,1},{1,3,3,3,1,2},{2,3,100,4,1,1},{3,4,100,6,1,1},{3,7,100,12,1,2},
 {3,13,17,17,1,3},{5,6,6,6,1,1},{5,6,100,10,1,1},{7,8,8,8,1,1},{8,8,8,8,1,0},
 {8,9,8,71,0,0},{8,0,0,8,1,0},{8,3,3,8,1,0},{17,16,16,17,1,0},{10,11,10,71,0,0},
 {INT32_MAX,INT32_MAX,INT32_MAX,INT32_MAX,1,0},{INT32_MAX,0,0,INT32_MAX,1,0},
 {0,INT32_MAX,INT32_MAX,INT32_MAX,1,28},{1,INT32_MAX,INT32_MAX,INT32_MAX,1,31},
 {1073741823,1073741824,INT32_MAX,2147483646,1,1},{1073741823,INT32_MAX,INT32_MAX,INT32_MAX,1,2},
 {1073741824,INT32_MAX,INT32_MAX,INT32_MAX,1,1},{1073741823,1073741824,2147483646,2147483646,1,1},
 {1073741824,1073741825,2147483646,2147483646,1,1},{0,1073741824,INT32_MAX,1073741824,1,27},
 {1,1073741824,INT32_MAX,1073741824,1,30},{1,1073741824,1073741824,1073741824,1,30},
 {1,1073741825,1073741825,1073741825,1,31},{1073741825,1073741825,1,71,0,0},
 {INT32_MAX,INT32_MAX,2147483646,71,0,0},{-1,0,0,71,0,0},{0,-1,0,71,0,0},{0,0,-1,71,0,0},
 {0,1,0,71,0,0},{-1,-1,-1,71,0,0},{71,1,1,71,1,0}
};
static int zero_resource(void){
#ifdef NEGATIVE_SCALAR_COPY
 ++observed.copied;
#endif
 CHECK(observed.allocations==0&&observed.requested==0&&observed.zeroed==0&&observed.copied==0&&observed.heap_events==0&&observed.root_peak==observed.roots_before);return 0;
}
static int capacity_cases(void){size_t maximum_steps=0,maximum_operations=0;for(size_t i=0;i<sizeof capacities/sizeof capacities[0];++i){for(int32_t seed=7;seed<=77;seed+=70){int32_t prepared=71;ube_err_set(seed,"previous","scalar capacity");observation_start();int ok=plan_capacity(capacities[i].capacity,capacities[i].required,capacities[i].maximum,&prepared);observation_stop();int32_t expected=capacities[i].prepared;
#ifdef NEGATIVE_CAPACITY_OUTPUT
 if(i==0)expected=1;
#endif
#ifdef NEGATIVE_CAPACITY_COUNTER
 observed.steps=32;
#endif
 CHECK(ok==capacities[i].ok&&prepared==expected&&ube_err_number()==seed);CHECK(zero_resource()==0&&observed.steps==capacities[i].steps&&observed.steps<=31&&observed.operations<=2*observed.steps);if(observed.steps>maximum_steps)maximum_steps=observed.steps;if(observed.operations>maximum_operations)maximum_operations=observed.operations;
 }}printf("{\"suite\":\"capacity\",\"cases\":%zu,\"errSeeds\":2,\"maximumIterations\":%zu,\"maximumCheckedOperations\":%zu,\"passed\":true}\n",sizeof capacities/sizeof capacities[0],maximum_steps,maximum_operations);return 0;}
struct encoding {int32_t scalar,width;uint8_t bytes[4];};
static const struct encoding encodings[]={
 {0,1,{0,0,0,0}},{127,1,{127,0,0,0}},{128,2,{194,128,0,0}},{2047,2,{223,191,0,0}},
 {2048,3,{224,160,128,0}},{55295,3,{237,159,191,0}},{57344,3,{238,128,128,0}},
 {65535,3,{239,191,191,0}},{65536,4,{240,144,128,128}},{66560,4,{240,144,144,128}},
 {1114111,4,{244,143,191,191}},{-1,0,{0}},{55296,0,{0}},{56319,0,{0}},{56320,0,{0}},
 {57343,0,{0}},{1114112,0,{0}},{INT32_MAX,0,{0}}
};
static int encoding_cases(void){size_t maximum_operations=0;for(size_t i=0;i<sizeof encodings/sizeof encodings[0];++i){for(int32_t seed=7;seed<=77;seed+=70){uint8_t bytes[4]={232,233,234,235};int32_t width=77;ube_err_set(seed,"previous","final named scalar encoder");observation_start();int ok=encode_scalar(encodings[i].scalar,&bytes[0],&bytes[1],&bytes[2],&bytes[3],&width);observation_stop();CHECK(ok==(encodings[i].width>0)&&ube_err_number()==seed&&zero_resource()==0&&observed.steps==0&&observed.operations<=24);if(ok){CHECK(width==encodings[i].width&&memcmp(bytes,encodings[i].bytes,4)==0);}else{const uint8_t old[4]={232,233,234,235};CHECK(width==77&&memcmp(bytes,old,4)==0);}if(observed.operations>maximum_operations)maximum_operations=observed.operations;}}
 printf("{\"suite\":\"utf8-encoding\",\"cases\":18,\"errSeeds\":2,\"maximumCheckedOperations\":%zu,\"passed\":true}\n",maximum_operations);return 0;}
static int full_registry(void){CHECK(ube_gc_root_storage_size()<=sizeof(root)&&storage_root_count()==0);size_t capacity=storage_root_limit();root* backed=calloc(capacity,sizeof *backed);void** holders=calloc(capacity,sizeof *holders);CHECK(backed&&holders);for(size_t i=0;i<capacity;++i)CHECK(ube_gc_root_enter(&backed[i],&holders[i]));CHECK(storage_root_count()==capacity&&capacity_cases()==0&&encoding_cases()==0&&storage_root_count()==capacity);for(size_t i=0;i<capacity;++i)CHECK(ube_gc_root_leave(&backed[i]));free(backed);free(holders);(void)ube_gc_collect();CHECK(storage_root_count()==0&&ube_gc_live_allocation_bytes()==0);printf("{\"suite\":\"full-registry\",\"backedRoots\":%zu,\"bothScalarAPIsSucceeded\":true,\"passed\":true}\n",capacity);return 0;}
int main(void){CHECK(capacity_cases()==0&&encoding_cases()==0&&full_registry()==0);printf("PASS scalar storage native assertions:%u\n",assertions);return 0;}
