#include "body-require.c"
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include "bootstrap/runtime/error_support.c"
#include "native-functions.h"
#define EXPECT(C) do{if(!(C)){fprintf(stderr,"native observer line %d: %s\n",__LINE__,#C);return 1;}}while(0)
_Static_assert(sizeof(struct native_byte)==1 && _Alignof(struct native_byte)==1,"Byte native layout");
_Static_assert(sizeof(struct native_small)==2 && _Alignof(struct native_small)==2,"Integer native layout");
_Static_assert(sizeof(struct native_wide)==4 && _Alignof(struct native_wide)==4,"Long native layout");
int main(void) {
 const int seeds[]={0,6,77};
 const int32_t values[]={INT32_MIN,INT32_MIN+1,-32769,-32768,-32767,-1,0,1,127,128,254,255,256,32766,32767,32768,INT32_MAX-1,INT32_MAX};
 for(int s=0;s<3;++s) {
  for(size_t i=0;i<sizeof values/sizeof values[0];++i) {
   int32_t x=values[i];
   ube_err_set(seeds[s],"prior","byte conversion");uint64_t revision=ube_thread_error.revision;bool bad=x<0 || x>255;
   EXPECT(native_cycle_byte(x)==(bad?0:x) && ube_err_number()==(bad?6:seeds[s]) && ube_thread_error.revision==revision+bad);
   ube_err_set(seeds[s],"prior","small conversion");revision=ube_thread_error.revision;bad=x<INT16_MIN || x>INT16_MAX;
   EXPECT(native_cycle_small(x)==(bad?0:x) && ube_err_number()==(bad?6:seeds[s]) && ube_thread_error.revision==revision+bad);
   ube_err_set(seeds[s],"prior","wide identity");revision=ube_thread_error.revision;
   EXPECT(native_cycle_wide(x)==x && ube_err_number()==seeds[s] && ube_thread_error.revision==revision);
   struct native_wide wide=native_box_wide(x),wide_copy=wide,other_wide={x==INT32_MAX?INT32_MIN:x+1};
   EXPECT(wide.value==x && native_read_wide(wide)==x && native_equal_wide(wide,wide_copy) && !native_unequal_wide(wide,wide_copy));
   EXPECT(!native_equal_wide(wide,other_wide) && native_unequal_wide(wide,other_wide));
   native_write_wide(&wide,-1,other_wide.value);EXPECT(wide.value==other_wide.value && wide_copy.value==x);
   if(x>=INT16_MIN && x<=INT16_MAX) {
    struct native_small small=native_box_small((int16_t)x),small_copy=small,other_small={(int16_t)(x==INT16_MAX?INT16_MIN:x+1)};
    EXPECT(small.value==x && native_read_small(small)==x && native_equal_small(small,small_copy) && !native_unequal_small(small,small_copy));
    EXPECT(!native_equal_small(small,other_small) && native_unequal_small(small,other_small));
    native_write_small(&small,-1,other_small.value);EXPECT(small.value==other_small.value && small_copy.value==x);
   }
   if(x>=0 && x<=255) {
    struct native_byte byte=native_box_byte((uint8_t)x),byte_copy=byte,other_byte={(uint8_t)(x==255?0:x+1)};
    EXPECT(byte.value==x && native_read_byte(byte)==x && native_equal_byte(byte,byte_copy) && !native_unequal_byte(byte,byte_copy));
    EXPECT(!native_equal_byte(byte,other_byte) && native_unequal_byte(byte,other_byte));
    native_write_byte(&byte,-1,other_byte.value);EXPECT(byte.value==other_byte.value && byte_copy.value==x);
   }
   native_main();EXPECT(ube_err_number()==seeds[s] && ube_thread_error.revision==revision);
  }
 }
 return 0;
}
