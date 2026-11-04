#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include "bootstrap/runtime/error_support.c"
#include "guard-functions.h"
#include "expected-frames.h"
extern int32_t program_run(void) __asm__("ube.program.run");
extern _Thread_local uint64_t floor_value __asm__("ube.stack.floor");
extern const uint64_t frames[18] __asm__("ube.stack.frames");
extern const uint64_t reserve_value __asm__("ube.stack.reserve");
extern uint8_t states[3] __asm__("ube.module.states");
extern bool failed __asm__("ube.module.failed");
#define REQUIRE(C) do{if(!(C)){fprintf(stderr,"bound frame observer line %d: %s\n",__LINE__,#C);return 1;}}while(0)
int main(void){
 REQUIRE(floor_value==0 && reserve_value==256);
 for(int i=0;i<18;++i)REQUIRE(frames[i]==expected_frames[i] && frames[i]>=8);
 ube_err_set(77,"prior","bound frames");uint64_t revision=ube_thread_error.revision;
 int32_t result=program_run();REQUIRE(result==129 && ube_err_number()==77 && ube_thread_error.revision==revision);
 REQUIRE(floor_value!=0 && !failed && guard_events==1 && guard_calls==1 && guard_first==12 && guard_tail==9 && guard_initializations==1 && guard_cinitializations==1);
 for(int i=0;i<3;++i)REQUIRE(states[i]==2);
 puts("PASS bound frame metadata and actual checked entry");return 0;
}
