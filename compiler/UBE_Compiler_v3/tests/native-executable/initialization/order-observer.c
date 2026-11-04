#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include "bootstrap/runtime/error_support.c"
#ifndef ROOT_COUNT
#define ROOT_COUNT 2
#endif
#ifndef MODE
#define MODE 0
#endif
extern bool schedule_run(void),schedule_require(int32_t,int32_t);
extern uint8_t states[3] __asm__("ube.module.states");
extern bool failed __asm__("ube.module.failed");
_Thread_local uint64_t floor_value __asm__("ube.stack.floor")=1;
const uint64_t reserve_value __asm__("ube.stack.reserve")=1;
const uint64_t frames[6] __asm__("ube.stack.frames")={32,32,MODE==2?UINT64_MAX:32,32,32,32};
static int events,counts[3];
bool init_a(void) __asm__("ube.module.init0");
bool init_b(void) __asm__("ube.module.init1");
bool init_c(void) __asm__("ube.module.init2");
bool init_a(void){++counts[0];events=events*10+1;return true;}
bool init_b(void){++counts[1];events=events*10+2;return true;}
bool init_c(void){++counts[2];events=events*10+3;return MODE==1?schedule_require(0,2):true;}
__attribute__((noreturn)) void fail(void) __asm__("ube.stack.abort");
void fail(void){exit(98);}
__attribute__((noreturn)) void wait_forever(void) __asm__("ube.module.wait");
void wait_forever(void){exit(98);}
#define EXPECT(C) do{if(!(C)){fprintf(stderr,"schedule oracle root %d mode %d line %d: %s\n",ROOT_COUNT,MODE,__LINE__,#C);return 1;}}while(0)
int main(void){ube_err_set(77,"prior","normal schedule");uint64_t revision=ube_thread_error.revision;
 if(MODE==3)states[1]=2;
 bool ok=schedule_run();
 if(MODE==2){
  int expected=ROOT_COUNT==1?23:ROOT_COUNT==2?3:0;
  EXPECT(!ok && failed && events==expected && counts[0]==0 && counts[1]==(ROOT_COUNT==1) && counts[2]==(ROOT_COUNT<3));
  EXPECT(states[0]==3 && states[1]==(ROOT_COUNT==1?2:0) && states[2]==(ROOT_COUNT<3?2:0));
  EXPECT(ube_err_number()==28 && ube_thread_error.revision==revision+1 && !schedule_run() && events==expected && ube_thread_error.revision==revision+1);
 }else{
  int expected=ROOT_COUNT==1?231:ROOT_COUNT==2?312:123;if(MODE==3)expected=ROOT_COUNT==3?13:31;
  EXPECT(ok && !failed && events==expected && counts[0]==1 && counts[1]==(MODE!=3) && counts[2]==1);
  EXPECT(states[0]==2 && states[1]==2 && states[2]==2 && ube_err_number()==77 && ube_thread_error.revision==revision);
  EXPECT(schedule_run() && events==expected && counts[0]==1 && counts[1]==(MODE!=3) && counts[2]==1 && ube_thread_error.revision==revision);
 }
 return 0;
}
