#include "body-require.c"
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include "bootstrap/runtime/error_support.c"
#include "call-functions.h"
#ifndef REFUSE_MODE
#define REFUSE_MODE 0
#endif
/* Controlled test metadata exercises the real generated guard. These values
   do not measure a committed interval, frame footprints or recovery R. */
_Thread_local uint64_t test_floor __asm__("ube.stack.floor") = REFUSE_MODE==6?0:1;
const uint64_t test_reserve __asm__("ube.stack.reserve") = 1;
#define FOOTPRINT(I) (((REFUSE_MODE==1 && (I)==1) || (REFUSE_MODE==2 && (I)==10) || (REFUSE_MODE==3 && (I)==3) || (REFUSE_MODE==4 && (I)==12) || (REFUSE_MODE==5 && (I)==14))?UINT64_MAX:32)
const uint64_t test_frames[CALL_FRAME_COUNT] __asm__("ube.stack.frames") = {
 FOOTPRINT(0),FOOTPRINT(1),FOOTPRINT(2),FOOTPRINT(3),FOOTPRINT(4),
 FOOTPRINT(5),FOOTPRINT(6),FOOTPRINT(7),FOOTPRINT(8),FOOTPRINT(9),
 FOOTPRINT(10),FOOTPRINT(11),FOOTPRINT(12),FOOTPRINT(13),FOOTPRINT(14),
 FOOTPRINT(15),FOOTPRINT(16),FOOTPRINT(17),FOOTPRINT(18),FOOTPRINT(19),
 FOOTPRINT(20),FOOTPRINT(21),FOOTPRINT(22),FOOTPRINT(23),32,32};
static int32_t fatal_trace;
__attribute__((noreturn)) void test_abort(void) __asm__("ube.stack.abort");
__attribute__((noreturn)) void test_abort(void) {
 /* 97 is a test transport marker; production fatal status remains 1. */
 exit(REFUSE_MODE==6 && fatal_trace==0 && call_count()==0?97:98);
}
#define EXPECT(C) do{if(!(C)){fprintf(stderr,"call observer mode %d line %d: %s\n",REFUSE_MODE,__LINE__,#C);return 1;}}while(0)
_Static_assert(sizeof(struct call_native)==4 && _Alignof(struct call_native)==4,"native call ABI");
int main(void) {
 if(REFUSE_MODE==6){call_reset();(void)call_ordered(&fatal_trace,-1);return 1;}
 const int seeds[]={0,6,77};
 for(int s=0;s<3;++s) {
  int32_t trace=0,x=9;call_reset();ube_err_set(seeds[s],"prior","ordinary call");uint64_t revision=ube_thread_error.revision;
  if(REFUSE_MODE==0) {
   EXPECT(call_ordered(&trace,-1)==127 && trace==21 && call_count()==1);
   call_reset();trace=0;EXPECT(call_effects(&trace,-1)==123 && trace==123 && call_count()==1);
   EXPECT(call_temporary(&x,-1)==9 && x==9 && call_repeated()==15);
   x=3;EXPECT(call_aliased(&x,-1)==99 && x==99);
   x=3;EXPECT(call_alias_order(&x,-1)==8 && x==8);
   EXPECT(call_round(INT32_MIN)==INT32_MIN && call_recursive(5)==120);
   call_main();EXPECT(ube_err_number()==seeds[s] && ube_thread_error.revision==revision);
   trace=0;EXPECT(call_narrow(256,&trace,-1)==0 && trace==1 && ube_err_number()==11 && ube_thread_error.revision==revision+2);
   ube_err_set(seeds[s],"prior","one fault");revision=ube_thread_error.revision;trace=0;
   EXPECT(call_narrow(5,&trace,-1)==5 && trace==1 && ube_err_number()==11 && ube_thread_error.revision==revision+1);
  } else if(REFUSE_MODE==1) {
   EXPECT(call_ordered(&trace,-1)==0 && trace==21 && call_count()==0 && ube_err_number()==28 && ube_thread_error.revision==revision+1);
   ube_err_set(seeds[s],"prior","refused effects");revision=ube_thread_error.revision;trace=0;
   EXPECT(call_effects(&trace,-1)==0 && trace==123 && call_count()==0 && ube_err_number()==28 && ube_thread_error.revision==revision+1);
  } else if(REFUSE_MODE==2) {
   EXPECT(call_round(42)==0 && ube_err_number()==28 && ube_thread_error.revision==revision+1);
  } else if(REFUSE_MODE==3) {
   EXPECT(call_temporary(&x,-1)==9 && x==9 && ube_err_number()==28 && ube_thread_error.revision==revision+1);
   ube_err_set(seeds[s],"prior","repeated refusal");revision=ube_thread_error.revision;
   EXPECT(call_repeated()==0 && ube_err_number()==28 && ube_thread_error.revision==revision+3);
   ube_err_set(seeds[s],"prior","alias refusal");revision=ube_thread_error.revision;x=3;
   EXPECT(call_aliased(&x,-1)==3 && x==3 && ube_err_number()==28 && ube_thread_error.revision==revision+1);
  } else if(REFUSE_MODE==4) {
   EXPECT(call_recursive(5)==0 && ube_err_number()==28 && ube_thread_error.revision==revision+1);
  } else if(REFUSE_MODE==5) {
   EXPECT(call_narrow(256,&trace,-1)==0 && trace==1 && ube_err_number()==28 && ube_thread_error.revision==revision+3);
  }
 }
 return 0;
}
