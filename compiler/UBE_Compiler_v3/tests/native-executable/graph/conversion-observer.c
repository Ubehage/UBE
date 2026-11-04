#include <stdint.h>
#include "bootstrap/runtime/error_support.c"
extern int64_t checked_narrow(int64_t),checked_bool_byte(int64_t);
int main(void) {
    const int64_t values[]={INT64_MIN,-1,0,1,127,128,255,256,INT64_MAX};
    for(size_t i=0;i<sizeof values/sizeof values[0];++i) {
        int failed=values[i]<0 || values[i]>255;ube_err_set(77,"prior","checked conversion");uint64_t revision=ube_thread_error.revision;
        if(checked_narrow(values[i])!=(failed?0:values[i]) || ube_err_number()!=(failed?6:77) || ube_thread_error.revision!=revision+(unsigned)failed)return 1;
    }
    ube_err_set(77,"prior","Boolean");uint64_t revision=ube_thread_error.revision;
    if(checked_bool_byte(0)!=0 || ube_err_number()!=77 || ube_thread_error.revision!=revision)return 2;
    if(checked_bool_byte(1)!=0 || ube_err_number()!=6 || ube_thread_error.revision!=revision+1)return 3;
    return 0;
}
