#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "value_storage.h"

extern int32_t ube_file_try_open(void* const*,int32_t,int32_t*,int32_t*,int32_t*);
extern int32_t ube_file_try_read(int32_t,void* const*,int32_t,int32_t,int32_t*,int32_t*);
extern int32_t ube_file_try_close(int32_t*,int32_t*);
extern int32_t ube_process_try_argument(int32_t,void**,int32_t*);
extern int32_t ube_process_try_current_directory(void**,int32_t*);
extern int32_t ube_file_try_identity(int32_t,void**,int32_t*);
extern void ube_err_set(int32_t,const char*,const char*);
extern int32_t ube_err_number(void),ube_gc_collect(void),ube_gc_root_enter(void*,void**),ube_gc_root_leave(void*);
extern size_t ube_gc_root_storage_size(void),ube_gc_live_allocation_bytes(void);
extern void ube_gc_test_fail_next_allocations(uint32_t);
extern void* ube_array_element(void*,int32_t);
extern void ube_file_test_inject(int32_t);
extern int32_t ube_file_test_open_handles(void),ube_file_test_payloads(void),ube_file_test_reads(void);
extern int32_t ube_file_test_hold(int32_t,int32_t);
extern int64_t ube_file_test_bytes_read(void),ube_file_test_bytes_published(void);
static const struct ube_value_layout byte_layout = {1,0,0,NULL,0,NULL};
static int assertions;
#define CHECK(condition) do { ++assertions; if (!(condition)) { fprintf(stderr,"file oracle line %d\n",__LINE__); return 1; } } while (0)
static unsigned char at(void* array,int32_t index) { return *(unsigned char*)ube_array_element(array,index); }
static void put(void* array,int32_t index,unsigned char value) { *(unsigned char*)ube_array_element(array,index) = value; }
static void seed(void) { ube_err_set(77,"existing","byte-file oracle"); }
struct worker { void* path; int failed; int marker; };
static DWORD WINAPI work(LPVOID argument) {
    struct worker* state = argument;
    void* bytes = NULL; void* identity = NULL; void* directory = NULL;
    void** holders[3]={&bytes,&identity,&directory};
    size_t stride=ube_gc_root_storage_size(),registered=0;
    unsigned char* roots=calloc(3,stride);
    if(roots==NULL) {state->failed=1;return 0;}
    while(registered<3 && ube_gc_root_enter(roots+registered*stride,holders[registered])) ++registered;
    if(registered!=3 || !ube_value_try_resize(&bytes,257,&byte_layout,0)) {state->failed=1;goto finished;}
    for (int round = 0; round < 20; ++round) {
        int32_t token=0,length=0,failure=0,got=0;
        ube_err_set(state->marker,"worker","byte-file oracle");
        if (!ube_file_try_open(&state->path,257,&token,&length,&failure) || length != 257 ||
            !ube_file_try_identity(token,&identity,&failure) || ube_value_array_length(&identity)!=16 || at(identity,0)!=1 ||
            !ube_process_try_current_directory(&directory,&failure) || ube_value_array_length(&directory)<1 ||
            !ube_file_try_read(token,&bytes,0,257,&got,&failure) || got != 257 ||
            at(bytes,0) != 0 || at(bytes,255) != 255 || at(bytes,256) != 0 ||
            !ube_file_try_close(&token,&failure) || token != 0 || ube_err_number() != state->marker) {
            state->failed = 2;
            if(token!=0) (void)ube_file_try_close(&token,&failure);
            break;
        }
    }
finished:
    while(registered) (void)ube_gc_root_leave(roots+(--registered)*stride);
    free(roots);
    return 0;
}
int main(void) {
    void* path=NULL; void* bytes=NULL; void* arg=NULL; void* bad=NULL;
    void* roots[4]; void** holders[4]={&path,&bytes,&arg,&bad};
    for (int item=0;item<4;++item) { roots[item]=calloc(1,ube_gc_root_storage_size()); CHECK(roots[item] != NULL); CHECK(ube_gc_root_enter(roots[item],holders[item])); }
    int32_t token=0,length=0,failure=0,got=0;
    seed(); CHECK(ube_process_try_argument(0,&path,&failure)); CHECK(failure==0 && ube_err_number()==77);
    CHECK(ube_process_try_argument(1,&arg,&failure));
    static const unsigned char unicode[]={0xc3,0xa9,0xf0,0x9f,0x99,0x82};
    CHECK(ube_value_array_length(&arg)==6);
    for(int item=0;item<6;++item) CHECK(at(arg,item)==unicode[item]);
    void* prior=arg; CHECK(!ube_process_try_argument(2,&arg,&failure)); CHECK(failure==12 && arg==prior && ube_err_number()==5);
    CHECK(!ube_process_try_argument(-1,&arg,&failure)); CHECK(failure==1 && arg==prior);
    /* The fixture's absolute path is beneath the separately supplied working
       directory. This independently checks counted UTF-8 directory transport. */
    seed(); CHECK(ube_process_try_current_directory(&bad,&failure));
    CHECK(failure==0 && ube_err_number()==77);
    int32_t directory_bytes=ube_value_array_length(&bad);
    CHECK(directory_bytes>0 && ube_value_array_length(&path)>directory_bytes+1);
    for(int32_t item=0;item<directory_bytes;++item) CHECK(at(bad,item)==at(path,item));
    CHECK(at(path,directory_bytes)=='\\' || at(path,directory_bytes)=='/');
    prior=bad;
    CHECK(!ube_process_try_current_directory(NULL,&failure)); CHECK(failure==1 && bad==prior);
    CHECK(!ube_process_try_current_directory(&bad,NULL)); CHECK(bad==prior);
    ube_gc_test_fail_next_allocations(2);
    CHECK(!ube_process_try_current_directory(&bad,&failure));
    CHECK(failure==8 && bad==prior && ube_err_number()==7);
    bad=NULL;
    CHECK(ube_value_try_resize(&bytes,300,&byte_layout,0));
    for(int item=0;item<300;++item) put(bytes,item,91);
    seed(); CHECK(ube_file_try_open(&path,257,&token,&length,&failure)); CHECK(token>0 && length==257 && failure==0 && ube_err_number()==77);
    const int identity_handles=ube_file_test_open_handles(),identity_payloads=ube_file_test_payloads();
    CHECK(ube_file_try_identity(token,&arg,&failure));
    CHECK(failure==0 && ube_err_number()==77 && ube_value_array_length(&arg)==16);
    unsigned char identity[16];
    for(int item=0;item<16;++item) identity[item]=at(arg,item);
    CHECK(identity[0]==1 && identity[1]==0 && identity[2]==0 && identity[3]==0);
    prior=arg; CHECK(ube_file_try_identity(token,&arg,&failure)); CHECK(arg!=prior);
    for(int item=0;item<16;++item) CHECK(at(arg,item)==identity[item]);
    CHECK(ube_file_test_open_handles()==identity_handles && ube_file_test_payloads()==identity_payloads);
    prior=arg; ube_gc_test_fail_next_allocations(2);
    CHECK(!ube_file_try_identity(token,&arg,&failure)); CHECK(failure==8 && arg==prior && ube_err_number()==7);
    CHECK(ube_file_try_identity(token,&arg,&failure)); CHECK(failure==0 && ube_err_number()==7);
    CHECK(!ube_file_try_identity(token,NULL,&failure)); CHECK(failure==1);
    CHECK(!ube_file_try_identity(token,&arg,NULL));
    /* Existing-file identity, not path spelling or content, defines equality. */
    HANDLE other=CreateFileW(L"other.bin",GENERIC_WRITE,FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,NULL,CREATE_NEW,FILE_ATTRIBUTE_NORMAL,NULL);
    CHECK(other!=INVALID_HANDLE_VALUE);
    DWORD written=0; int wrote=WriteFile(other,"A",1,&written,NULL)!=0 && written==1;
    CHECK(CloseHandle(other)); CHECK(wrote);
    CHECK(ube_value_try_resize(&bad,9,&byte_layout,0));
    for(int item=0;item<9;++item) put(bad,item,(unsigned char)"other.bin"[item]);
    int32_t other_token=0,other_length=0;
    CHECK(ube_file_try_open(&bad,257,&other_token,&other_length,&failure));
    CHECK(ube_file_try_identity(other_token,&arg,&failure));
    int different=0; for(int item=0;item<16;++item) different|=at(arg,item)!=identity[item];
    CHECK(different); CHECK(ube_file_try_close(&other_token,&failure));
    const wchar_t fixture_name[]={0x00e9,0xd83d,0xde42,L'.',L'b',L'i',L'n',0};
    CHECK(CreateHardLinkW(L"alias.bin",fixture_name,NULL));
    for(int item=0;item<9;++item) put(bad,item,(unsigned char)"alias.bin"[item]);
    CHECK(ube_file_try_open(&bad,257,&other_token,&other_length,&failure));
    CHECK(ube_file_try_identity(other_token,&arg,&failure));
    for(int item=0;item<16;++item) CHECK(at(arg,item)==identity[item]);
    CHECK(ube_file_try_close(&other_token,&failure)); bad=NULL;
    /* Exhaust the real registration capacity; do not fake a failed return. */
    size_t root_stride=ube_gc_root_storage_size(),entered=0;
    unsigned char* pressure=calloc(1048576,root_stride); void* neutral=NULL;
    CHECK(pressure!=NULL);
    while(entered<1048576 && ube_gc_root_enter(pressure+entered*root_stride,&neutral)) ++entered;
    CHECK(entered==1048576-4);
    prior=arg;
    CHECK(!ube_process_try_current_directory(&arg,&failure)); CHECK(failure==8 && arg==prior);
    CHECK(!ube_file_try_identity(token,&arg,&failure)); CHECK(failure==8 && arg==prior);
    while(entered) CHECK(ube_gc_root_leave(pressure+(--entered)*root_stride));
    free(pressure);
    CHECK(ube_file_try_identity(token,&arg,&failure));
    CHECK(ube_file_test_hold(token,1));
    prior=arg; CHECK(!ube_file_try_identity(token,&arg,&failure)); CHECK(failure==13 && arg==prior);
    CHECK(!ube_file_try_read(token,&bytes,0,1,&got,&failure)); CHECK(failure==13 && got==0);
    CHECK(!ube_file_try_close(&token,&failure)); CHECK(failure==13 && token>0);
    CHECK(ube_file_test_hold(token,0));
    seed();
    const int64_t before_read=ube_file_test_bytes_read(),before_publish=ube_file_test_bytes_published();
    CHECK(ube_file_try_read(token,&bytes,3,257,&got,&failure)); CHECK(got==257 && failure==0 && ube_err_number()==77);
    CHECK(ube_file_test_bytes_read()-before_read==257 && ube_file_test_bytes_published()-before_publish==257);
    for(int item=0;item<257;++item) CHECK(at(bytes,item+3)==(unsigned char)item);
    CHECK(at(bytes,2)==91 && at(bytes,260)==91);
    CHECK(ube_file_try_read(token,&bytes,0,1,&got,&failure)); CHECK(got==0);
    CHECK(!ube_file_try_read(token,&bytes,-1,1,&got,&failure)); CHECK(failure==1 && got==0);
    const int32_t stale=token; CHECK(ube_file_try_close(&token,&failure)); CHECK(token==0 && failure==0);
    prior=arg; CHECK(!ube_file_try_identity(stale,&arg,&failure)); CHECK(failure==9 && arg==prior);
    CHECK(!ube_file_try_identity(-1,&arg,&failure)); CHECK(failure==9 && arg==prior);
    CHECK(ube_file_try_close(&token,&failure));
    CHECK(!ube_file_try_read(stale,&bytes,0,1,&got,&failure)); CHECK(failure==9);
    token=stale; CHECK(!ube_file_try_close(&token,&failure)); CHECK(token==stale && failure==9); token=0;
    const int payloads=ube_file_test_payloads(), reads=ube_file_test_reads();
    CHECK(!ube_file_try_open(&path,256,&token,&length,&failure)); CHECK(token==0 && length==0 && failure==4 && ube_err_number()==6);
    CHECK(ube_file_test_payloads()==payloads && ube_file_test_reads()==reads && ube_file_test_open_handles()==0);
    ube_file_test_inject(7); CHECK(!ube_file_try_open(&path,256,&token,&length,&failure));
    CHECK(token>0 && length==0 && failure==7 && ube_file_test_open_handles()==1);
    CHECK(ube_file_try_close(&token,&failure)); CHECK(token==0 && ube_file_test_open_handles()==0);
    CHECK(!ube_file_try_open(&bad,257,&token,&length,&failure)); CHECK(failure==2);
    CHECK(ube_value_try_resize(&bad,1,&byte_layout,0)); put(bad,0,0); CHECK(!ube_file_try_open(&bad,257,&token,&length,&failure)); CHECK(failure==2);
    put(bad,0,255); CHECK(!ube_file_try_open(&bad,257,&token,&length,&failure)); CHECK(failure==2);
    put(bad,0,1); CHECK(!ube_file_try_open(&bad,257,&token,&length,&failure)); CHECK(failure==3);
    ube_file_test_inject(1); CHECK(!ube_file_try_open(&path,257,&token,&length,&failure)); CHECK(failure==8 && token==0 && ube_err_number()==7 && ube_file_test_open_handles()==0);
    CHECK(ube_file_try_open(&path,257,&token,&length,&failure)); CHECK(token>stale);
    for(int item=0;item<300;++item) put(bytes,item,91);
    ube_file_test_inject(2); CHECK(!ube_file_try_read(token,&bytes,0,257,&got,&failure)); CHECK(got==0 && failure==5 && ube_err_number()==57);
    for(int item=0;item<300;++item) CHECK(at(bytes,item)==91);
    ube_file_test_inject(4); CHECK(ube_file_try_read(token,&bytes,0,257,&got,&failure)); CHECK(got==128);
    ube_file_test_inject(0); CHECK(ube_file_try_read(token,&bytes,128,129,&got,&failure)); CHECK(got==129);
    for(int item=0;item<257;++item) CHECK(at(bytes,item)==(unsigned char)item);
    ube_file_test_inject(6); CHECK(!ube_file_try_close(&token,&failure)); CHECK(token>0 && failure==7 && ube_file_test_open_handles()==1);
    CHECK(ube_file_try_close(&token,&failure)); CHECK(token==0 && ube_file_test_open_handles()==0);
    CHECK(ube_file_try_open(&path,257,&token,&length,&failure));
    ube_file_test_inject(3); CHECK(ube_file_try_read(token,&bytes,0,257,&got,&failure)); CHECK(got==0);
    ube_file_test_inject(5); CHECK(!ube_file_try_close(&token,&failure)); CHECK(token==0 && failure==7 && ube_file_test_open_handles()==0);
    /* Cancellation is caller-owned control flow between bounded operations:
       abandon before reading, and abandon after one byte of a larger file. */
    seed(); CHECK(ube_file_try_open(&path,257,&token,&length,&failure));
    const int32_t abandoned_before=token;
    const int reads_before_cancel=ube_file_test_reads();
    CHECK(ube_file_try_close(&token,&failure));
    CHECK(token==0 && failure==0 && ube_file_test_open_handles()==0 && ube_err_number()==77);
    CHECK(ube_file_test_reads()==reads_before_cancel);
    CHECK(!ube_file_try_read(abandoned_before,&bytes,0,1,&got,&failure));
    CHECK(failure==9 && got==0 && ube_file_test_reads()==reads_before_cancel);
    seed(); CHECK(ube_file_try_open(&path,257,&token,&length,&failure));
    CHECK(ube_file_try_read(token,&bytes,0,1,&got,&failure));
    CHECK(got==1 && at(bytes,0)==0 && length==257 && ube_err_number()==77);
    const int32_t abandoned_partial=token;
    const int reads_after_partial=ube_file_test_reads();
    CHECK(ube_file_try_close(&token,&failure));
    CHECK(token==0 && failure==0 && ube_file_test_open_handles()==0 && ube_err_number()==77);
    CHECK(!ube_file_try_read(abandoned_partial,&bytes,0,1,&got,&failure));
    CHECK(failure==9 && got==0 && ube_file_test_reads()==reads_after_partial);
    /* Four callers share only an immutable rooted path. */
    struct worker workers[4]; HANDLE threads[4];
    for(int item=0;item<4;++item) { workers[item]=(struct worker){path,0,100+item}; threads[item]=CreateThread(NULL,0,work,&workers[item],0,NULL); CHECK(threads[item]!=NULL); }
    CHECK(WaitForMultipleObjects(4,threads,TRUE,20000)==WAIT_OBJECT_0);
    for(int item=0;item<4;++item) { CHECK(CloseHandle(threads[item])); CHECK(workers[item].failed==0); }
    CHECK(ube_file_test_open_handles()==0);
    for(int item=0;item<4;++item) { CHECK(ube_gc_root_leave(roots[item])); free(roots[item]); }
    (void)ube_gc_collect(); CHECK(ube_gc_live_allocation_bytes()==0);
    printf("PASS file primitives %d assertions\n",assertions);
    return 0;
}
