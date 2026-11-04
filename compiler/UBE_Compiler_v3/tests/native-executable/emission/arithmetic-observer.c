#include <stdint.h>
#include <inttypes.h>
#include <stdio.h>
#include "bootstrap/runtime/error_support.c"

#define DECLARE(T) \
 extern int64_t arith##T##op8(int64_t,int64_t),arith##T##op10(int64_t,int64_t),arith##T##op11(int64_t,int64_t),arith##T##op12(int64_t,int64_t),arith##T##op13(int64_t,int64_t); \
 extern int64_t arith##T##op15(int64_t,int64_t),arith##T##op16(int64_t,int64_t),arith##T##op17(int64_t,int64_t),arith##T##op18(int64_t,int64_t),arith##T##op19(int64_t,int64_t),arith##T##op20(int64_t,int64_t); \
 extern int64_t arith##T##op24(int64_t,int64_t),arith##T##op26(int64_t,int64_t),arith##T##op28(int64_t,int64_t),arith##T##op29(int64_t,int64_t),arith##T##op30(int64_t,int64_t); \
 extern int64_t unary##T##op4(int64_t,int64_t),unary##T##op5(int64_t,int64_t),unary##T##op6(int64_t,int64_t);
DECLARE(3)
DECLARE(4)
DECLARE(5)
extern int64_t arith1op15(int64_t,int64_t),arith1op16(int64_t,int64_t),arith1op24(int64_t,int64_t),arith1op26(int64_t,int64_t),arith1op28(int64_t,int64_t),arith1op29(int64_t,int64_t),arith1op30(int64_t,int64_t),unary1op6(int64_t,int64_t);
typedef int64_t (*operation)(int64_t,int64_t);
struct row {int type,op;operation run;};
#define ROW(T,O) {T,O,arith##T##op##O}
#define ROWS(T) ROW(T,8),ROW(T,10),ROW(T,11),ROW(T,12),ROW(T,13),ROW(T,15),ROW(T,16),ROW(T,17),ROW(T,18),ROW(T,19),ROW(T,20),ROW(T,24),ROW(T,26),ROW(T,28),ROW(T,29),ROW(T,30),{T,4,unary##T##op4},{T,5,unary##T##op5},{T,6,unary##T##op6}
static const struct row rows[]={ROWS(3),ROWS(4),ROWS(5),ROW(1,15),ROW(1,16),ROW(1,24),ROW(1,26),ROW(1,28),ROW(1,29),ROW(1,30),{1,6,unary1op6}};

/* Independent wide mathematical oracle; never execute undefined C division or
   signed overflow. Narrow bitwise results are sign-extended by C promotion. */
static int observe(const struct row* row,int64_t a,int64_t b,int32_t seed) {
    const int64_t lo[]={0,0,0,INT16_MIN,INT32_MIN,INT64_MIN};
    const int64_t hi[]={0,1,255,INT16_MAX,INT32_MAX,INT64_MAX};
    __int128 wide=0;int32_t failure=0;
    switch(row->op) {
    case 4:wide=a;break;
    case 5:wide=-(__int128)a;break;
    case 6:wide=row->type==1?!a:~a;break;
    case 8:wide=(__int128)a*b;break;
    case 10:case 11:
        if(b==0)failure=11;
        else if(a==lo[row->type] && b==-1) {if(row->op==10)failure=6;}
        else wide=row->op==10?a/b:a%b;
        break;
    case 12:wide=(__int128)a+b;break;
    case 13:wide=(__int128)a-b;break;
    case 15:wide=a==b;break;
    case 16:wide=a!=b;break;
    case 17:wide=a<b;break;
    case 18:wide=a<=b;break;
    case 19:wide=a>b;break;
    case 20:wide=a>=b;break;
    case 24:wide=a&b;break;
    case 26:wide=a|b;break;
    case 28:wide=a^b;break;
    case 29:wide=row->type==1?a==b:~(a^b);break;
    case 30:wide=row->type==1?(!a)|b:(~a)|b;break;
    default:return 1;
    }
    if(wide<lo[row->type] || wide>hi[row->type])failure=6;
    int64_t expected=failure?0:(int64_t)wide;
    if(seed)ube_err_set(seed,"before","arithmetic observer");else ube_err_clear();
    uint64_t revision=ube_thread_error.revision;int64_t actual=row->run(a,b);
    if(actual!=expected || ube_err_number()!=(failure?failure:seed) || ube_thread_error.revision!=revision+(failure!=0)) {
        fprintf(stderr,"arithmetic type=%d op=%d a=%" PRId64 " b=%" PRId64 " value=%" PRId64 " expected=%" PRId64 " err=%d expected=%d revision=%" PRIu64 " expected=%" PRIu64 "\n",row->type,row->op,a,b,actual,expected,ube_err_number(),failure?failure:seed,ube_thread_error.revision,revision+(failure!=0));return 1;
    }
    return 0;
}
int main(void) {
    const int64_t values[]={INT64_MIN,INT64_MIN+1,INT32_MIN,INT32_MIN+1,INT16_MIN,INT16_MIN+1,-32767,-256,-3,-2,-1,0,1,2,3,255,256,32766,INT16_MAX,32768,INT32_MAX-1,INT32_MAX,INT64_C(2147483648),INT64_MAX-1,INT64_MAX};
    const int64_t lo[]={0,0,0,INT16_MIN,INT32_MIN,INT64_MIN};
    const int64_t hi[]={0,1,255,INT16_MAX,INT32_MAX,INT64_MAX};
    const int32_t seeds[]={0,6,77};
    for(size_t r=0;r<sizeof(rows)/sizeof(rows[0]);++r)for(size_t a=0;a<sizeof(values)/sizeof(values[0]);++a)for(size_t b=0;b<sizeof(values)/sizeof(values[0]);++b) {
        if(values[a]<lo[rows[r].type] || values[a]>hi[rows[r].type] || values[b]<lo[rows[r].type] || values[b]>hi[rows[r].type])continue;
        for(size_t s=0;s<sizeof(seeds)/sizeof(seeds[0]);++s)if(observe(&rows[r],values[a],values[b],seeds[s]))return 1;
    }
    return 0;
}
