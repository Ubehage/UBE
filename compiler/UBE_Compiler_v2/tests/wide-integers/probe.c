#include <stdint.h>
#include <stdio.h>
#include <limits.h>
#include <inttypes.h>
extern int64_t wide_add(int64_t,int64_t),wide_subtract(int64_t,int64_t),wide_multiply(int64_t,int64_t),wide_divide(int64_t,int64_t),wide_remainder(int64_t,int64_t),wide_negate(int64_t);
extern int32_t wide_to_long(int64_t),ube_err_number(void);
extern int16_t wide_to_integer(int64_t);
extern uint8_t wide_to_byte(int64_t);
extern void ube_err_set(int32_t,const char*,const char*);
struct arithmetic_case { int operation;int64_t left,right,value;int32_t error; };
static const struct arithmetic_case cases[]={
 {0,0,0,0,77},{0,INT64_MAX,0,INT64_MAX,77},{0,INT64_MIN,0,INT64_MIN,77},
 {0,INT64_MAX,1,0,6},{0,INT64_MIN,-1,0,6},{0,-1,1,0,77},
 {0,INT64_C(2147483647),1,INT64_C(2147483648),77},
 {0,INT64_MIN,INT64_MAX,-1,77},{0,INT64_MAX,INT64_MIN,-1,77},
 {0,INT64_C(-9223372036854775807),-1,INT64_MIN,77},
 {1,0,0,0,77},{1,INT64_MIN,1,0,6},{1,INT64_MAX,-1,0,6},
 {1,INT64_MIN,-1,INT64_C(-9223372036854775807),77},
 {1,INT64_MAX,1,INT64_C(9223372036854775806),77},
 {1,-1,INT64_MIN,INT64_MAX,77},{1,INT64_MIN,INT64_MIN,0,77},
 {1,INT64_MAX,INT64_MAX,0,77},{1,0,INT64_MIN,0,6},
 {2,0,INT64_MIN,0,77},{2,INT64_MIN,0,0,77},{2,INT64_MIN,1,INT64_MIN,77},
 {2,INT64_MIN,-1,0,6},{2,-1,INT64_MIN,0,6},{2,INT64_MAX,1,INT64_MAX,77},
 {2,INT64_MAX,2,0,6},{2,INT64_MIN,2,0,6},{2,INT64_MIN,INT64_MIN,0,6},
 {2,INT64_MAX,-1,INT64_C(-9223372036854775807),77},
 {2,INT64_C(3037000499),INT64_C(3037000499),INT64_C(9223372030926249001),77},
 {2,INT64_C(3037000500),INT64_C(3037000500),0,6},
 {2,INT64_C(-3037000500),INT64_C(3037000500),0,6},
 {2,INT64_C(-2147483648),INT64_C(4294967296),INT64_MIN,77},
 {2,INT64_C(2147483647),INT64_C(2147483647),INT64_C(4611686014132420609),77},
 {3,0,1,0,77},{3,1,0,0,11},{3,INT64_MIN,-1,0,6},
 {3,INT64_MIN,1,INT64_MIN,77},{3,INT64_MIN,2,INT64_C(-4611686018427387904),77},
 {3,INT64_MAX,-1,INT64_C(-9223372036854775807),77},
 {3,-9,2,-4,77},{3,9,-2,-4,77},{3,-9,-2,4,77},
 {3,INT64_MIN,INT64_MIN,1,77},{3,INT64_MAX,INT64_MIN,0,77},
 {4,1,0,0,11},{4,INT64_MIN,-1,0,77},{4,INT64_MIN,1,0,77},
 {4,-9,2,-1,77},{4,9,-2,1,77},{4,-9,-2,-1,77},
 {4,INT64_MIN,INT64_MAX,-1,77},{4,INT64_MAX,INT64_MIN,INT64_MAX,77},
 {4,0,-1,0,77},{4,INT64_MIN,INT64_MIN,0,77},
 {5,0,0,0,77},{5,1,0,-1,77},{5,-1,0,1,77},{5,INT64_MIN,0,0,6},
 {5,INT64_MAX,0,INT64_C(-9223372036854775807),77},
 {5,INT64_C(-9223372036854775807),0,INT64_MAX,77},
 {6,INT32_MAX,0,INT32_MAX,77},{6,INT32_MIN,0,INT32_MIN,77},
 {6,INT64_C(2147483648),0,0,6},{6,INT64_C(-2147483649),0,0,6},
 {6,INT64_MAX,0,0,6},{6,INT64_MIN,0,0,6},
 {7,32767,0,32767,77},{7,-32768,0,-32768,77},{7,32768,0,0,6},{7,-32769,0,0,6},
 {7,INT64_MAX,0,0,6},{7,INT64_MIN,0,0,6},
 {8,0,0,0,77},{8,255,0,255,77},{8,256,0,0,6},{8,-1,0,0,6},
 {8,INT64_MAX,0,0,6},{8,INT64_MIN,0,0,6}
};
int main(void){
 unsigned assertions=0;
 for(size_t index=0;index<sizeof cases/sizeof cases[0];++index){
  const struct arithmetic_case* expected=cases+index;int64_t value=0;
  ube_err_set(77,"previous","wide integer regression");
  switch(expected->operation){
   case 0:value=wide_add(expected->left,expected->right);break;
   case 1:value=wide_subtract(expected->left,expected->right);break;
   case 2:value=wide_multiply(expected->left,expected->right);break;
   case 3:value=wide_divide(expected->left,expected->right);break;
   case 4:value=wide_remainder(expected->left,expected->right);break;
   case 5:value=wide_negate(expected->left);break;
   case 6:value=wide_to_long(expected->left);break;
   case 7:value=wide_to_integer(expected->left);break;
   case 8:value=wide_to_byte(expected->left);break;
   default:return 2;
  }
  int32_t error=ube_err_number();int64_t expected_value=expected->value;
#ifdef NEGATIVE_WIDE_VALUE
  if(index==0)expected_value=1;
#endif
  ++assertions;if(value!=expected_value){fprintf(stderr,"wide integer assertion: case %zu value %" PRId64 " expected %" PRId64 "\n",index,value,expected_value);return 1;}
  ++assertions;if(error!=expected->error){fprintf(stderr,"wide integer assertion: case %zu Err %" PRId32 " expected %" PRId32 "\n",index,error,expected->error);return 1;}
 }
 printf("PASS wide integer native assertions:%u cases:%zu\n",assertions,sizeof cases/sizeof cases[0]);
 return 0;
}
