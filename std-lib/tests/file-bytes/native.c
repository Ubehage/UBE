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
extern void ube_err_set(int32_t,const char*,const char*);
extern int32_t ube_err_number(void),ube_gc_collect(void),ube_gc_root_enter(void*,void**),ube_gc_root_leave(void*);
extern size_t ube_gc_root_storage_size(void),ube_gc_live_allocation_bytes(void);
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
    void* bytes = NULL;
    void* root = calloc(1,ube_gc_root_storage_size());
    if (root == NULL || !ube_gc_root_enter(root,&bytes) || !ube_value_try_resize(&bytes,257,&byte_layout,0)) { state->failed = 1; free(root); return 0; }
    for (int round = 0; round < 20; ++round) {
        int32_t token=0,length=0,failure=0,got=0;
        ube_err_set(state->marker,"worker","byte-file oracle");
        if (!ube_file_try_open(&state->path,257,&token,&length,&failure) || length != 257 ||
            !ube_file_try_read(token,&bytes,0,257,&got,&failure) || got != 257 ||
            at(bytes,0) != 0 || at(bytes,255) != 255 || at(bytes,256) != 0 ||
            !ube_file_try_close(&token,&failure) || token != 0 || ube_err_number() != state->marker) { state->failed = 2; break; }
    }
    (void)ube_gc_root_leave(root); free(root);
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
    CHECK(ube_value_try_resize(&bytes,300,&byte_layout,0));
    for(int item=0;item<300;++item) put(bytes,item,91);
    seed(); CHECK(ube_file_try_open(&path,257,&token,&length,&failure)); CHECK(token>0 && length==257 && failure==0 && ube_err_number()==77);
    CHECK(ube_file_test_hold(token,1));
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
