#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
struct byte_value {uint8_t value;};struct integer_value {int16_t value;};struct long_value {int32_t value;};
#define DECLARE(N,T) extern T touch##N(T,T*),get##N(void),local_zero##N(void),result_zero##N(void)
DECLARE(1,bool);DECLARE(2,uint8_t);DECLARE(3,int16_t);DECLARE(4,int32_t);DECLARE(5,int64_t);
DECLARE(6,struct byte_value);DECLARE(7,struct integer_value);DECLARE(8,struct long_value);
#define SCALAR(N,T,V,A) do {T input=V,alias=A; if(get##N()!=0 || local_zero##N()!=0 || result_zero##N()!=0 || touch##N(input,&alias)!=(A) || alias!=1 || input!=(V) || get##N()!=(V)) {fprintf(stderr,"scalar storage %d failed\n",N);return 1;}}while(0)
#define NATIVE(N,T,V,A) do {T input={V},alias={A};if(get##N().value!=0 || local_zero##N().value!=0 || result_zero##N().value!=0 || touch##N(input,&alias).value!=(A) || alias.value!=1 || input.value!=(V) || get##N().value!=(V)) {fprintf(stderr,"native storage %d failed\n",N);return 1;}}while(0)
int main(void) {
    SCALAR(1,bool,true,false);SCALAR(2,uint8_t,255,77);SCALAR(3,int16_t,INT16_MIN,77);SCALAR(4,int32_t,INT32_MIN,77);SCALAR(5,int64_t,INT64_MIN,77);
    NATIVE(6,struct byte_value,255,77);NATIVE(7,struct integer_value,INT16_MIN,77);NATIVE(8,struct long_value,INT32_MIN,77);return 0;
}
