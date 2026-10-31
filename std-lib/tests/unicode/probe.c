/* Independent raw-UCD oracle; never use the bootstrap generated headers. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include "../../../runtime/value_storage.h"
extern int32_t test_letter(int32_t),test_fold(int32_t);
extern int32_t test_cursor(void**,int32_t,int32_t*,int32_t*);
extern void* ube_array_element(void*,int32_t);
extern void ube_err_set(int32_t,const char*,const char*);
extern int32_t ube_err_number(void),ube_gc_collect(void),ube_gc_root_enter(void*,void**),ube_gc_root_leave(void*);
extern size_t ube_gc_live_allocation_bytes(void),ube_gc_root_storage_size(void);
static unsigned char expected_letters[0x110000];
static int32_t expected_fold[0x110000];
static _Thread_local size_t feeds,comparisons;
static volatile LONG measuring;
static volatile LONG64 allocations;
static volatile LONG64 copied_bytes;
void unicode_feed_called(void) { ++feeds; }
void unicode_comparison(void) { ++comparisons; }
void* probe_malloc(size_t n) { if(measuring)InterlockedIncrement64(&allocations);return malloc(n); }
void* probe_calloc(size_t n,size_t s) { if(measuring)InterlockedIncrement64(&allocations);return calloc(n,s); }
void* probe_realloc(void* p,size_t n) { if(measuring)InterlockedIncrement64(&allocations);return realloc(p,n); }
void probe_free(void* p) { free(p); }
void probe_value_copy(size_t n) { if(measuring)InterlockedAdd64(&copied_bytes,(LONG64)n); }
#define CHECK(x) do{if(!(x)){fprintf(stderr,"Unicode acceptance line %d: %s\n",__LINE__,#x);return 1;}}while(0)
static const struct ube_value_layout byte_type={1,0,0,NULL,0,NULL};
typedef union { uint64_t alignment; unsigned char bytes[32]; } root;
static int load(const char* folding,const char* categories) {
    FILE* f=fopen(folding,"rb"); if(!f)return 0;
    for(int32_t cp=0;cp<0x110000;++cp)expected_fold[cp]=cp;
    char line[2048];unsigned first,last,target;char status;
    while(fgets(line,sizeof line,f)) {
        if(sscanf(line,"%x; %c; %x;",&first,&status,&target)==3&&(status=='C'||status=='S')) {
            if(first>=0x110000||target>=0x110000||expected_fold[first]!=(int32_t)first){fclose(f);return 0;}
            expected_fold[first]=(int32_t)target;
        }
    }
    if(ferror(f)){fclose(f);return 0;}fclose(f);
    f=fopen(categories,"rb");if(!f)return 0;
    while(fgets(line,sizeof line,f)) {
        char* semicolon=strchr(line,';');if(!semicolon)continue;
        char category[3]={0};if(sscanf(semicolon+1," %2s",category)!=1||category[0]!='L'||!strchr("ultmo",category[1]))continue;
        if(sscanf(line,"%x..%x",&first,&last)!=2){if(sscanf(line,"%x",&first)!=1){fclose(f);return 0;}last=first;}
        if(first>last||last>=0x110000){fclose(f);return 0;}
        for(unsigned cp=first;cp<=last;++cp)expected_letters[cp]=1;
    }
    if(ferror(f)){fclose(f);return 0;}fclose(f);return 1;
}
static unsigned encode(uint32_t cp,uint8_t* p) {
    if(cp<128){p[0]=(uint8_t)cp;return 1;}
    if(cp<2048){p[0]=0xc0|(cp>>6);p[1]=0x80|(cp&63);return 2;}
    if(cp<65536){p[0]=0xe0|(cp>>12);p[1]=0x80|((cp>>6)&63);p[2]=0x80|(cp&63);return 3;}
    p[0]=0xf0|(cp>>18);p[1]=0x80|((cp>>12)&63);p[2]=0x80|((cp>>6)&63);p[3]=0x80|(cp&63);return 4;
}
/* Whole-prefix oracle uses bit masks and shortest-length classification rather
   than the implementation's incremental state. Extra trailing bytes ignored. */
static int reference(const uint8_t* p,int32_t n,int32_t offset,int32_t* scalar,int32_t* width) {
    *scalar=*width=0;if(offset<0||offset>=n)return 0;
    uint32_t first=p[offset],cp;unsigned extra;
    if(first<128){cp=first;extra=0;}
    else if((first&0xe0)==0xc0){cp=first&31;extra=1;}
    else if((first&0xf0)==0xe0){cp=first&15;extra=2;}
    else if((first&0xf8)==0xf0){cp=first&7;extra=3;}
    else return 0;
    if(n-offset-1<(int32_t)extra)return 0;
    for(unsigned i=1;i<=extra;++i){uint32_t b=p[offset+(int32_t)i];if((b&0xc0)!=0x80)return 0;cp=cp*64+(b&63);}
    unsigned shortest=cp<128?0:cp<2048?1:cp<65536?2:3;
    if(extra!=shortest||cp>0x10ffff||(cp>=0xd800&&cp<=0xdfff))return 0;
    *scalar=(int32_t)cp;*width=(int32_t)extra+1;return 1;
}
static int check_sequence(void** array,const uint8_t* p,int32_t n,int32_t offset) {
    if(!ube_value_try_resize(array,n,&byte_type,0))return 0;
    for(int32_t i=0;i<n;++i)__atomic_store_n((uint8_t*)ube_array_element(*array,i),p[i],__ATOMIC_SEQ_CST);
    int32_t expected,ew,actual=-9,aw=-9;int wanted=reference(p,n,offset,&expected,&ew);
    size_t before=feeds;measuring=1;
    int got=test_cursor(array,offset,&actual,&aw);measuring=0;
    if(got!=wanted||actual!=expected||aw!=ew||feeds-before>4||(!wanted&&(actual||aw)))return 0;
    if(wanted&&feeds-before!=(size_t)ew)return 0;
    for(int32_t i=0;i<n;++i)if(*(uint8_t*)ube_array_element(*array,i)!=p[i])return 0;
    return 1;
}
struct worker_input {void** bytes;int32_t error;};
static DWORD WINAPI worker(void* argument) {
    const struct worker_input* input=argument;
    void** bytes=input->bytes;ube_err_set(input->error,"worker","Unicode");
    for(int32_t cp=0;cp<0x110000;cp+=13) {
        if(test_letter(cp)!=expected_letters[cp]||test_fold(cp)!=expected_fold[cp])return 1;
        int32_t scalar=-9,width=-9;
        if(!test_cursor(bytes,0,&scalar,&width)||scalar!=0x1f600||width!=4)return 1;
    }
    return ube_err_number()!=input->error;
}
int main(int argc,char** argv) {
    CHECK(argc==3&&load(argv[1],argv[2]));
    CHECK(ube_gc_root_storage_size()<=sizeof(root));
    (void)ube_gc_collect();size_t baseline=ube_gc_live_allocation_bytes();
    void* array=NULL;root r={0};CHECK(ube_gc_root_enter(&r,&array));
    CHECK(ube_value_try_resize(&array,4,&byte_type,0));
    ube_err_set(77,"existing","Unicode");size_t max_comparisons=0;
    for(int32_t cp=0;cp<0x110000;++cp) {
        size_t before=comparisons;
        measuring=1;int letter=test_letter(cp);int32_t fold=test_fold(cp);measuring=0;
        CHECK(letter==expected_letters[cp]&&fold==expected_fold[cp]);
        size_t work=comparisons-before;CHECK(work<=44);if(work>max_comparisons)max_comparisons=work;
        if(cp>=0xd800&&cp<=0xdfff)continue;
        uint8_t p[4]={0};unsigned width=encode((uint32_t)cp,p);
        for(int i=0;i<4;++i)__atomic_store_n((uint8_t*)ube_array_element(array,i),p[i],__ATOMIC_SEQ_CST);
        int32_t scalar=-9,actual_width=-9;before=feeds;measuring=1;
        int valid=test_cursor(&array,0,&scalar,&actual_width);measuring=0;
        CHECK(valid&&scalar==cp&&actual_width==(int32_t)width&&feeds-before==width);
    }
    const int32_t invalid[]={INT_MIN,-1,0x110000,INT_MAX};
    for(size_t i=0;i<sizeof invalid/sizeof invalid[0];++i)CHECK(!test_letter(invalid[i])&&test_fold(invalid[i])==invalid[i]);
    uint8_t p[4];
    for(unsigned a=0;a<256;++a){p[0]=(uint8_t)a;CHECK(check_sequence(&array,p,1,0));for(unsigned b=0;b<256;++b){p[1]=(uint8_t)b;CHECK(check_sequence(&array,p,2,0));}}
    uint32_t random=0x4c203a9d;
    for(unsigned i=0;i<50000;++i){for(unsigned j=0;j<4;++j){random=random*1664525+1013904223;p[j]=(uint8_t)(random>>24);}CHECK(check_sequence(&array,p,4,0));}
    const uint8_t bad[][4]={{0xe0,0x80,0x80,0},{0xed,0xa0,0x80,0},{0xf4,0x90,0x80,0x80},{0xf0,0x80,0x80,0x80},{0xf0,0x9f,0x98,0x80}};
    for(size_t i=0;i<sizeof bad/sizeof bad[0];++i)for(int32_t n=0;n<=4;++n)for(int32_t offset=-1;offset<=n;++offset)CHECK(check_sequence(&array,bad[i],n,offset));
    CHECK(check_sequence(&array,bad[0],4,INT_MAX));CHECK(ube_err_number()==77);
    const uint8_t shared[]={0xf0,0x9f,0x98,0x80};CHECK(ube_value_try_resize(&array,4,&byte_type,0));
    for(int i=0;i<4;++i)__atomic_store_n((uint8_t*)ube_array_element(array,i),shared[i],__ATOMIC_SEQ_CST);
    struct worker_input arguments[4];HANDLE threads[4];
    for(unsigned i=0;i<4;++i){arguments[i].bytes=&array;arguments[i].error=90+(int32_t)i;threads[i]=CreateThread(NULL,0,worker,&arguments[i],0,NULL);CHECK(threads[i]);}
    CHECK(WaitForMultipleObjects(4,threads,TRUE,30000)==WAIT_OBJECT_0);
    for(unsigned i=0;i<4;++i){DWORD result=1;CHECK(GetExitCodeThread(threads[i],&result)&&!result);CHECK(CloseHandle(threads[i]));}
    CHECK(ube_err_number()==77);CHECK(allocations==0&&copied_bytes==0);
    CHECK(ube_gc_root_leave(&r));array=NULL;(void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==baseline);
    printf("PASS Unicode18 all-codepoint letter/fold; all-scalar UTF8; malformed/bounds/neutral/immutable/Err; four workers; cleanup\n");
    printf("MEASURE comparisons-max:%zu feeds:%zu allocations:%lld copied-bytes:%lld\n",max_comparisons,feeds,(long long)allocations,(long long)copied_bytes);
    return 0;
}
