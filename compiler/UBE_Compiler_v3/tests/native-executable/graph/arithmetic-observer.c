#include <stdint.h>
#include <stdio.h>
#include "bootstrap/runtime/error_support.c"
extern int64_t checked_op8(int64_t,int64_t),checked_op10(int64_t,int64_t),checked_op11(int64_t,int64_t),checked_op12(int64_t,int64_t),checked_op13(int64_t,int64_t),checked_op5(int64_t,int64_t);
typedef int64_t (*operation)(int64_t,int64_t);
struct row {operation run;int64_t a,b,value;int32_t error;};
/* Hand-authored expected results, including mixed LongLong/Long operands. */
static const struct row cases[]={
 {checked_op8,INT64_MAX,2,0,6},{checked_op8,INT64_MIN,-1,0,6},
 {checked_op8,INT64_MIN,1,INT64_MIN,0},{checked_op8,INT64_MAX,0,0,0},
 {checked_op8,-7,3,-21,0},{checked_op8,2,INT32_MIN,-INT64_C(4294967296),0},
 {checked_op10,INT64_MIN,-1,0,6},{checked_op10,INT64_MIN,1,INT64_MIN,0},
 {checked_op10,INT64_MAX,0,0,11},{checked_op10,0,0,0,11},
 {checked_op10,-7,3,-2,0},{checked_op10,7,-3,-2,0},{checked_op10,-7,-3,2,0},
 {checked_op10,INT64_MIN,INT32_MIN,INT64_C(4294967296),0},
 {checked_op11,INT64_MIN,-1,0,0},{checked_op11,INT64_MIN,1,0,0},
 {checked_op11,INT64_MIN,0,0,11},{checked_op11,0,0,0,11},
 {checked_op11,-7,3,-1,0},{checked_op11,7,-3,1,0},{checked_op11,-7,-3,-1,0},
 {checked_op12,INT64_MAX,1,0,6},{checked_op12,INT64_MIN,-1,0,6},
 {checked_op12,INT64_MAX,-1,INT64_MAX-1,0},{checked_op12,INT64_MIN,1,INT64_MIN+1,0},
 {checked_op12,INT32_MAX,1,INT64_C(2147483648),0},
 {checked_op13,INT64_MAX,-1,0,6},{checked_op13,INT64_MIN,1,0,6},
 {checked_op13,INT64_MAX,1,INT64_MAX-1,0},{checked_op13,INT64_MIN,-1,INT64_MIN+1,0},
 {checked_op13,0,INT32_MIN,INT64_C(2147483648),0},
 {checked_op5,INT64_MIN,0,0,6},{checked_op5,INT64_MAX,0,-INT64_MAX,0},
 {checked_op5,-1,0,1,0},{checked_op5,0,0,0,0},{checked_op5,1,0,-1,0}
};
int main(void) {
    const int32_t seeds[]={0,6,77};
    for(size_t i=0;i<sizeof(cases)/sizeof(cases[0]);++i)for(size_t s=0;s<sizeof(seeds)/sizeof(seeds[0]);++s) {
        const struct row* row=&cases[i];ube_err_set(seeds[s],"prior","checked operator observer");uint64_t revision=ube_thread_error.revision;
        int64_t value=row->run(row->a,row->b);int32_t wanted=row->error?row->error:seeds[s];
        if(value!=row->value || ube_err_number()!=wanted || ube_thread_error.revision!=revision+(row->error!=0)) {
            fprintf(stderr,"checked arithmetic case=%zu seed=%d value=%lld expected=%lld err=%d expected=%d\n",i,seeds[s],(long long)value,(long long)row->value,ube_err_number(),wanted);return 1;
        }
    }
    return 0;
}
