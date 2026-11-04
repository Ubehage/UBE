#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include "bootstrap/runtime/error_support.c"
#include "guard-functions.h"
#ifndef REFERENCE
#define REFERENCE 0
#endif
#ifndef SCHEDULE_MODE
#define SCHEDULE_MODE 0
#endif
extern uint8_t states[3] __asm__("ube.module.states");
extern bool failed __asm__("ube.module.failed");
_Thread_local uint64_t schedule_floor __asm__("ube.stack.floor")=1;
const uint64_t schedule_reserve __asm__("ube.stack.reserve")=1;
#define F(I) ((SCHEDULE_MODE==1 && (I)==GUARD_C_FRAME)?UINT64_MAX:32)
const uint64_t schedule_frames[GUARD_FRAMES] __asm__("ube.stack.frames")={F(0),F(1),F(2),F(3),F(4),F(5),F(6),F(7),F(8),F(9),F(10),F(11),F(12),F(13),F(14),F(15),F(16),F(17)};
__attribute__((noreturn)) void schedule_abort(void) __asm__("ube.stack.abort");
void schedule_abort(void){exit(98);}
__attribute__((noreturn)) void schedule_wait(void) __asm__("ube.module.wait");
void schedule_wait(void){exit(98);}
#define EXPECT(C) do{if(!(C)){fprintf(stderr,"checked schedule oracle reference %d mode %d line %d: %s\n",REFERENCE,SCHEDULE_MODE,__LINE__,#C);return 1;}}while(0)
int main(void){ube_err_set(77,"prior","checked schedule");uint64_t revision=ube_thread_error.revision;
 if(SCHEDULE_MODE==2){EXPECT(guard_start(1) && states[0]==0 && states[1]==2 && states[2]==2);guard_value=44;}
 bool ok=guard_schedule();
 if(SCHEDULE_MODE==1){
  EXPECT(!ok && failed && states[0]==(REFERENCE?0:3) && states[1]==3 && states[2]==3);
  EXPECT(guard_first==0 && guard_tail==0 && guard_calls==0 && guard_value==12 && guard_initializations==1 && guard_cinitializations==0);
  EXPECT(ube_err_number()==28 && ube_thread_error.revision==revision+1 && !guard_schedule() && ube_thread_error.revision==revision+1);
 }else{
  int expected=SCHEDULE_MODE==2?44:12;
  EXPECT(ok && !failed && states[0]==2 && states[1]==2 && states[2]==2);
  EXPECT(guard_first==expected && guard_tail==9 && guard_main()==expected*10+9 && guard_calls==1 && guard_initializations==1 && guard_cinitializations==1);
  EXPECT(ube_err_number()==77 && ube_thread_error.revision==revision && guard_schedule() && guard_calls==1 && guard_initializations==1 && guard_cinitializations==1 && ube_thread_error.revision==revision);
 }
 return 0;
}
