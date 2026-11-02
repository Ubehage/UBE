#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include "value_storage.h"
struct record {int32_t source,node,kind,type;int64_t value;int32_t left,right,flags,scope,first,last;};
struct result {void* records;int32_t count,root;int64_t total;};
struct work {int32_t writes,reads,transitions,pending,depth;};
typedef union {uint64_t align;uint8_t bytes[32];} root;
extern int32_t arena_build(void**,int32_t,int32_t,int32_t,int32_t,void**,int32_t*,struct work*);
extern int32_t arena_role(const struct ube_value_layout*);
extern size_t index_root_count(void),index_root_limit(void),index_array_header(void),index_gc_header(void),ube_gc_live_allocation_bytes(void),ube_gc_root_storage_size(void);
extern int32_t ube_gc_root_enter(void*,void**),ube_gc_root_leave(void*),ube_gc_collect(void),ube_err_number(void);
extern void ube_err_set(int32_t,const char*,const char*);
extern void* ube_array_element(void*,int32_t);
struct observation {bool active;int copy_class;size_t allocations,requested,zeroed,fail_at,copied[4],byte_copy,roots_before,root_peak,gc_before,gc_peak,events[4],capacity,heap_events;};
static _Thread_local struct observation observed;
static unsigned assertions;
#define CHECK(x) do{++assertions;if(!(x)){fprintf(stderr,"arena assertion %u line %d: %s\n",assertions,__LINE__,#x);return 1;}}while(0)
void index_root_changed(size_t count){if(observed.active&&count>observed.root_peak)observed.root_peak=count;}
void name_heap_changed(size_t bytes){
#ifndef NEGATIVE_ARENA_HEAP
 if(observed.active){++observed.heap_events;if(bytes>observed.gc_peak)observed.gc_peak=bytes;}
#else
 (void)bytes;
#endif
}
static bool deny(size_t bytes){if(!observed.active)return false;++observed.allocations;observed.requested+=bytes;return observed.fail_at&&observed.allocations>=observed.fail_at;}
void* probe_malloc(size_t bytes){if(deny(bytes))return NULL;return malloc(bytes);}
void* probe_calloc(size_t count,size_t bytes){if(bytes&&count>SIZE_MAX/bytes)return NULL;if(deny(count*bytes))return NULL;void* p=calloc(count,bytes);if(observed.active&&p)observed.zeroed+=count*bytes;return p;}
void* probe_realloc(void* old,size_t bytes){if(deny(bytes))return NULL;return realloc(old,bytes);}
void probe_free(void* p){free(p);}
void probe_value_copy(size_t bytes){if(observed.active){observed.copied[observed.copy_class]+=bytes;if(bytes==1)observed.byte_copy+=bytes;}}
void arena_event(int32_t kind){if(observed.active&&kind>0&&kind<4)++observed.events[kind];}
static void sample(void){if(observed.active){size_t n=ube_gc_live_allocation_bytes();if(n>observed.gc_peak)observed.gc_peak=n;}}
int32_t arena_resize(void** holder,int32_t count,const struct ube_value_layout* layout,int32_t keep){int previous=observed.copy_class;int32_t before=ube_value_array_length(holder);if(keep)observed.copy_class=count<before?2:1;int32_t ok=ube_value_try_resize(holder,count,layout,keep);if(observed.active&&ok&&arena_role(layout)==1&&(size_t)count>observed.capacity)observed.capacity=(size_t)count;sample();observed.copy_class=previous;return ok;}
int32_t arena_assign(void* destination,const void* source,const struct ube_value_layout* layout){int previous=observed.copy_class;observed.copy_class=3;int32_t ok=ube_value_assign(destination,source,layout);sample();observed.copy_class=previous;return ok;}
static void begin(size_t fail){observed=(struct observation){.active=true,.fail_at=fail};observed.root_peak=observed.roots_before=index_root_count();observed.gc_peak=observed.gc_before=ube_gc_live_allocation_bytes();}
static void end(void){sample();observed.active=false;}
static const struct ube_value_layout bytes_layout={1,0,0,NULL,0,NULL};
struct env {void* source;void* old_source;void* old;void* output;root roots[4];unsigned char old_wrapper[24];struct record old_records[3];};
static int make_bytes(void** slot,int32_t count){CHECK(ube_value_try_resize(slot,count,&bytes_layout,0));for(int32_t i=0;i<count;++i)*(uint8_t*)ube_array_element(*slot,i)=(uint8_t)(i%251);return 0;}
static int open_env(struct env* e,int32_t n){memset(e,0,sizeof *e);void** holders[]={&e->source,&e->old_source,&e->old,&e->output};for(int i=0;i<4;++i)CHECK(ube_gc_root_enter(&e->roots[i],holders[i]));CHECK(make_bytes(&e->source,2*n)==0&&make_bytes(&e->old_source,6)==0);int32_t failure=5;struct work work={0};CHECK(arena_build(&e->old_source,3,3,1,1,&e->output,&failure,&work)&&failure==0);e->old=e->output;struct result* old=ube_array_element(e->old,0);memcpy(e->old_wrapper,old,24);memcpy(e->old_records,ube_array_element(old->records,0),sizeof e->old_records);(void)ube_gc_collect();return 0;}
static int input_equal(struct env* e){int32_t n=ube_value_array_length(&e->source);for(int32_t i=0;i<n;++i)CHECK(*(uint8_t*)ube_array_element(e->source,i)==(uint8_t)(i%251));for(int i=0;i<6;++i)CHECK(*(uint8_t*)ube_array_element(e->old_source,i)==(uint8_t)i);return 0;}
static int old_equal(struct env* e){CHECK(e->output==e->old);struct result* old=ube_array_element(e->old,0);CHECK(memcmp(e->old_wrapper,old,24)==0&&memcmp(e->old_records,ube_array_element(old->records,0),sizeof e->old_records)==0);CHECK(input_equal(e)==0);return 0;}
static int result_equal(void* output,int32_t n){CHECK(ube_value_array_length(&output)==1);struct result* r=ube_array_element(output,0);CHECK(r->count==n&&r->root==n-1&&ube_value_array_length(&r->records)==n);int64_t total=(int64_t)n*INT64_C(2147483647)+(int64_t)n*(n-1)/2;CHECK(r->total==total);for(int32_t i=0;i<n;++i){struct record* v=ube_array_element(r->records,i);int64_t wanted=INT64_C(2147483647)+i;
#ifdef NEGATIVE_ARENA_VALUE
if(i==0)++wanted;
#endif
CHECK(v->source==7&&v->node==i&&v->kind==1+i%3&&v->type==5&&v->value==wanted&&v->left==i-1&&v->right==-1&&v->flags==i%2&&v->scope==2&&v->first==2*i&&v->last==2*i+1);}return 0;}
static int close_env(struct env* e){CHECK(input_equal(e)==0);for(int i=3;i>=0;--i)CHECK(ube_gc_root_leave(&e->roots[i]));(void)ube_gc_collect();CHECK(index_root_count()==0&&ube_gc_live_allocation_bytes()==0);return 0;}
static int costs(void){const int32_t counts[]={0,1,8,64,1024,16384};for(size_t c=0;c<6;++c){int32_t n=counts[c];struct env e;CHECK(open_env(&e,n)==0);int32_t failure=5;struct work w={0};ube_err_set(77,"prior","arena costs");begin(0);int ok=arena_build(&e.source,n,n,n?1:0,n?1:0,&e.output,&failure,&w);end();CHECK(ok&&failure==0&&ube_err_number()==77&&result_equal(e.output,n)==0&&input_equal(&e)==0);CHECK(w.writes==n&&w.reads==n&&w.transitions==2*n&&w.pending==(n>0)&&w.depth==(n>0)&&observed.events[1]==(size_t)n&&observed.events[2]==(size_t)n&&observed.events[3]==(size_t)(2*n));CHECK(observed.byte_copy==0&&observed.copied[0]==0&&observed.copied[1]<=2*(size_t)n*48+8*48&&observed.copied[2]<=(size_t)n*48&&observed.copied[3]==(size_t)n*48+16);size_t log=0,width=1;while(width<(size_t)n+1){width*=2;++log;}size_t limit=2*log+16,extra=6*(size_t)n*48+16*48+8*4+2*24;CHECK(observed.allocations<=limit&&observed.requested<=extra+8+limit*(index_array_header()+index_gc_header())&&observed.gc_peak<=observed.gc_before+extra+limit*index_array_header()&&observed.root_peak<=observed.roots_before+512&&observed.zeroed<=observed.requested);printf("{\"suite\":\"arena-cost\",\"n\":%d,\"writes\":%d,\"reads\":%d,\"transitions\":%d,\"capacity\":%zu,\"allocations\":%zu,\"requested\":%zu,\"callocZeroed\":%zu,\"growthCopied\":%zu,\"trimCopied\":%zu,\"publicationCopied\":%zu,\"sourceCopied\":%zu,\"gcBefore\":%zu,\"gcPeak\":%zu,\"rootDelta\":%zu,\"passed\":true}\n",n,w.writes,w.reads,w.transitions,observed.capacity,observed.allocations,observed.requested,observed.zeroed,observed.copied[1],observed.copied[2],observed.copied[3],observed.byte_copy,observed.gc_before,observed.gc_peak,observed.root_peak-observed.roots_before);CHECK(close_env(&e)==0);}return 0;}
static int failures(void){struct env e;CHECK(open_env(&e,64)==0);int32_t failure=5;struct work w={0};begin(0);CHECK(arena_build(&e.source,64,64,1,1,&e.output,&failure,&w));end();size_t sites=observed.allocations,required=observed.root_peak-observed.roots_before;e.output=e.old;(void)ube_gc_collect();size_t bytes=ube_gc_live_allocation_bytes(),roots=index_root_count();for(size_t site=1;site<=sites;++site){failure=5;w=(struct work){0};ube_err_set(77,"prior","arena fault");begin(site);int ok=arena_build(&e.source,64,64,1,1,&e.output,&failure,&w);end();CHECK(!ok&&failure==5&&ube_err_number()==7&&old_equal(&e)==0&&index_root_count()==roots);(void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==bytes);failure=5;w=(struct work){0};ube_err_set(77,"prior","arena recovery");CHECK(arena_build(&e.source,64,64,1,1,&e.output,&failure,&w)&&failure==0&&ube_err_number()==77&&result_equal(e.output,64)==0);e.output=e.old;(void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==bytes);}
printf("{\"suite\":\"arena-allocation-faults\",\"sites\":%zu,\"requiredRoots\":%zu,\"passed\":true}\n",sites,required);CHECK(close_env(&e)==0);return 0;}
static int budgets(void){struct env e;CHECK(open_env(&e,64)==0);const int32_t values[][4]={{64,-1,1,1},{64,1048577,1,1},{64,64,-1,1},{64,64,1,257},{65,65,1,1},{64,63,1,1},{64,64,0,1},{64,64,1,0},{64,64,1,1},{64,65,2,2}};for(size_t i=0;i<10;++i){int32_t f=5;struct work w={0};ube_err_set(77,"prior","arena budget");int ok=arena_build(&e.source,values[i][0],values[i][1],values[i][2],values[i][3],&e.output,&f,&w);if(i<5)CHECK(!ok&&f==1&&old_equal(&e)==0);else if(i<8)CHECK(!ok&&f==2&&old_equal(&e)==0);else{CHECK(ok&&f==0&&result_equal(e.output,64)==0);e.output=e.old;}(void)ube_gc_collect();CHECK(ube_err_number()==77);}CHECK(close_env(&e)==0);printf("{\"suite\":\"arena-budgets\",\"cases\":10,\"passed\":true}\n");return 0;}
static int root_pressure(void){struct env e;CHECK(open_env(&e,64)==0);int32_t f=5;struct work w={0};begin(0);CHECK(arena_build(&e.source,64,64,1,1,&e.output,&f,&w));end();size_t required=observed.root_peak-observed.roots_before;e.output=e.old;(void)ube_gc_collect();size_t bytes=ube_gc_live_allocation_bytes(),capacity=index_root_limit()-index_root_count();root* backed=calloc(capacity,sizeof *backed);void** slots=calloc(capacity,sizeof *slots);CHECK(backed&&slots&&required>0&&required<512);for(size_t i=0;i<capacity;++i)CHECK(ube_gc_root_enter(&backed[i],&slots[i]));for(size_t available=0;available<=required+1;++available){if(available)CHECK(ube_gc_root_leave(&backed[capacity-available]));e.output=e.old;(void)ube_gc_collect();f=5;w=(struct work){0};ube_err_set(77,"prior","arena roots");size_t roots=index_root_count();int ok=arena_build(&e.source,64,64,1,1,&e.output,&f,&w);CHECK(index_root_count()==roots&&ok==(available>=required));if(ok)CHECK(f==0&&ube_err_number()==77&&result_equal(e.output,64)==0);else{CHECK(f==5&&ube_err_number()==7&&old_equal(&e)==0);(void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==bytes);}}for(size_t i=0;i<capacity-required-1;++i)CHECK(ube_gc_root_leave(&backed[i]));free(backed);free(slots);printf("{\"suite\":\"arena-root-pressure\",\"required\":%zu,\"capacities\":%zu,\"realBacked\":true,\"passed\":true}\n",required,required+2);CHECK(close_env(&e)==0);return 0;}
static int focused_trim(void){
 struct env e;CHECK(open_env(&e,13)==0);int32_t f=5;struct work w={0};ube_err_set(7,"prior","arena exact trim");begin(0);int ok=arena_build(&e.source,13,64,1,1,&e.output,&f,&w);end();
#ifdef NEGATIVE_ARENA_METRIC
 ++w.reads;
#endif
 CHECK(ok&&f==0&&ube_err_number()==7&&result_equal(e.output,13)==0&&w.writes==13&&w.reads==13&&w.transitions==26&&observed.events[1]==13&&observed.events[2]==13&&observed.events[3]==26);
 CHECK(observed.capacity==16&&observed.copied[1]==8*48&&observed.copied[2]==13*48&&observed.copied[3]==13*48+16&&observed.byte_copy==0&&observed.copied[0]==0&&observed.heap_events>0);
 printf("{\"suite\":\"arena-exact-trim\",\"n\":13,\"capacity\":16,\"growthCopied\":%zu,\"trimCopied\":%zu,\"publicationCopied\":%zu,\"staleErr\":7,\"passed\":true}\n",observed.copied[1],observed.copied[2],observed.copied[3]);CHECK(close_env(&e)==0);return 0;
}
static int extra_domains(void){struct env e;CHECK(open_env(&e,64)==0);const int32_t cases[][4]={{-1,64,1,1},{1048577,1048576,1,1},{64,64,1048577,1},{64,64,1,-1},{64,0,1,1}};for(size_t i=0;i<5;++i){int32_t failure=5;struct work work={0};ube_err_set(7,"prior","arena fresh domain status");CHECK(!arena_build(&e.source,cases[i][0],cases[i][1],cases[i][2],cases[i][3],&e.output,&failure,&work)&&failure==(i==4?2:1)&&ube_err_number()==7&&old_equal(&e)==0);}CHECK(close_env(&e)==0);printf("{\"suite\":\"arena-extra-domains\",\"cases\":5,\"staleErr\":7,\"passed\":true}\n");return 0;}
int main(int argc,char**argv){CHECK(sizeof(struct record)==48&&sizeof(struct result)==24&&sizeof(root)>=ube_gc_root_storage_size());if(argc==2&&strcmp(argv[1],"roots")==0){CHECK(root_pressure()==0);}else{CHECK(costs()==0&&focused_trim()==0&&failures()==0&&budgets()==0&&extra_domains()==0);}printf("PASS arena native assertions:%u\n",assertions);return 0;}
