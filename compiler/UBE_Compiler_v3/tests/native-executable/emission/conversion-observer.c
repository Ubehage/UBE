#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include "bootstrap/runtime/error_support.c"
#define DECL(S,D) extern int64_t convert##S##to##D(int64_t);
#define ROW(S) DECL(S,1) DECL(S,2) DECL(S,3) DECL(S,4) DECL(S,5)
ROW(1) ROW(2) ROW(3) ROW(4) ROW(5)
#undef ROW
#define ROW(S) {convert##S##to1,convert##S##to2,convert##S##to3,convert##S##to4,convert##S##to5}
static int64_t (*const convert[5][5])(int64_t)={ROW(1),ROW(2),ROW(3),ROW(4),ROW(5)};
#undef ROW
static int matrix(void) {
    const int64_t minimum[]={0,0,INT16_MIN,INT32_MIN,INT64_MIN},maximum[]={1,255,INT16_MAX,INT32_MAX,INT64_MAX};
    const int64_t values[]={INT64_MIN,INT64_C(-2147483649),INT32_MIN,-32769,INT16_MIN,-257,-256,-129,-128,-1,0,1,127,128,255,256,INT16_MAX,32768,INT32_MAX,INT64_C(2147483648),INT64_MAX};
    const int seeds[]={0,6,77};
    for(int s=0;s<5;++s)for(int d=0;d<5;++d)for(size_t i=0;i<sizeof values/sizeof values[0];++i)for(size_t k=0;k<sizeof seeds/sizeof seeds[0];++k) {
        int64_t value=values[i];if(value<minimum[s] || value>maximum[s])continue;
        int64_t expected=d==0?(value!=0):(s==0 && value!=0?-1:value);int failed=expected<minimum[d] || expected>maximum[d];
        if(failed)expected=0;ube_err_set(seeds[k],"seed","observer");uint64_t revision=ube_thread_error.revision;
        int64_t actual=convert[s][d](value);int error=ube_err_number(),wanted=failed?6:seeds[k];
        if(actual!=expected || error!=wanted || ube_thread_error.revision!=revision+(unsigned)failed) {
            fprintf(stderr,"conversion %d to %d input=%lld result=%lld expected=%lld err=%d expected=%d revision=%llu expected=%llu\n",s+1,d+1,(long long)value,(long long)actual,(long long)expected,error,wanted,(unsigned long long)ube_thread_error.revision,(unsigned long long)(revision+(unsigned)failed));return 1;
        }
    }
    return 0;
}
struct job {HANDLE ready,release;int seed,passed;};
static DWORD WINAPI worker(void* argument) {
    struct job* j=argument;if(!SetEvent(j->ready) || WaitForSingleObject(j->release,5000)!=WAIT_OBJECT_0)return 1;
    for(int i=0;i<1024;++i) {
        ube_err_set(j->seed,"worker","observer");uint64_t before=ube_thread_error.revision;
        if(convert5to4(INT32_MIN)!=INT32_MIN || ube_err_number()!=j->seed || ube_thread_error.revision!=before)return 1;
        if(convert5to4(INT64_MIN)!=0 || ube_err_number()!=6 || ube_thread_error.revision!=before+1)return 1;
    }
    j->passed=1;return 0;
}
int main(void) {
    if(matrix())return 1;
    HANDLE release=CreateEventW(NULL,TRUE,FALSE,NULL);if(!release)return 2;
    struct job jobs[2]={{0}};HANDLE threads[2]={0};
    for(int i=0;i<2;++i){jobs[i].seed=70+i;jobs[i].release=release;jobs[i].ready=CreateEventW(NULL,TRUE,FALSE,NULL);if(!jobs[i].ready)return 3;threads[i]=CreateThread(NULL,0,worker,&jobs[i],0,NULL);if(!threads[i])return 4;}
    for(int i=0;i<2;++i)if(WaitForSingleObject(jobs[i].ready,5000)!=WAIT_OBJECT_0)return 5;
    if(!SetEvent(release))return 6;
    for(int i=0;i<2;++i){if(WaitForSingleObject(threads[i],5000)!=WAIT_OBJECT_0 || !jobs[i].passed)return 7;if(!CloseHandle(threads[i]) || !CloseHandle(jobs[i].ready))return 8;}
    return CloseHandle(release)?0:9;
}
