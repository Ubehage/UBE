#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include "bootstrap/runtime/error_support.c"
#include "guard-functions.h"
#ifndef GUARD_MODE
#define GUARD_MODE 0
#endif
extern uint8_t states[3] __asm__("ube.module.states");
extern bool failed __asm__("ube.module.failed");
_Thread_local uint64_t guard_floor __asm__("ube.stack.floor")=1;
const uint64_t guard_reserve __asm__("ube.stack.reserve")=1;
/* Controlled metadata only: C's initializer is refused in mode 1. */
#define F(I) ((GUARD_MODE==1 && (I)==GUARD_C_FRAME)?UINT64_MAX:32)
const uint64_t guard_frames[GUARD_FRAMES] __asm__("ube.stack.frames")={F(0),F(1),F(2),F(3),F(4),F(5),F(6),F(7),F(8),F(9),F(10),F(11),F(12),F(13),F(14),F(15),F(16),F(17)};
__attribute__((noreturn)) void guard_abort(void) __asm__("ube.stack.abort");
void guard_abort(void){exit(98);}
__attribute__((noreturn)) void guard_wait(void) __asm__("ube.module.wait");
void guard_wait(void){exit(GUARD_MODE==2 && states[0]==2 && states[1]==1 && states[2]==0 && !failed && guard_events==0 && ube_err_number()==77?97:98);}
#define EXPECT(C) do{if(!(C)){fprintf(stderr,"guard oracle mode %d line %d: %s\n",GUARD_MODE,__LINE__,#C);return 1;}}while(0)
static uint64_t reset(void){states[0]=2;states[1]=states[2]=0;failed=false;guard_events=guard_first=guard_tail=guard_value=guard_initializations=guard_dependency=guard_calls=guard_cvalue=guard_cinitializations=0;ube_err_set(77,"prior","guard observer");return ube_thread_error.revision;}
static int initialized(uint64_t revision){EXPECT(states[0]==2 && states[1]==2 && states[2]==2 && !failed && guard_initializations==1 && guard_dependency==3 && guard_cvalue==3 && guard_cinitializations==1 && ube_err_number()==77 && ube_thread_error.revision==revision);return 0;}
static int refused(uint64_t revision){EXPECT(states[0]==2 && states[1]==3 && states[2]==3 && failed && guard_initializations==1 && guard_dependency==0 && guard_cvalue==0 && guard_cinitializations==0 && ube_err_number()==28 && ube_thread_error.revision==revision+1);return 0;}
int main(void){uint64_t revision=reset();
 if(GUARD_MODE==2){states[1]=1;EXPECT(guard_forward_unused(&guard_value,1)==7 && guard_unused_global()==7 && guard_events==0 && states[1]==1 && states[2]==0 && !failed);(void)guard_forward_read(&guard_value,1);return 1;}
 EXPECT(guard_forward_unused(&guard_value,1)==7 && guard_unused_global()==7 && states[1]==0 && states[2]==0 && guard_events==0 && !failed && ube_thread_error.revision==revision);
 if(GUARD_MODE==0){
  EXPECT(guard_read()==12 && guard_events==9 && initialized(revision)==0);EXPECT(guard_read()==12 && guard_events==99 && initialized(revision)==0);
  revision=reset();guard_write();EXPECT(guard_value==4 && guard_events==49 && initialized(revision)==0);EXPECT(guard_read()==4 && guard_events==499 && initialized(revision)==0);
  revision=reset();EXPECT(guard_call()==17 && guard_events==59 && guard_calls==1 && initialized(revision)==0);
  revision=reset();EXPECT(guard_native().value==6 && guard_events==69 && initialized(revision)==0);
  revision=reset();EXPECT(guard_alias_read(&guard_value,1)==12 && guard_events==9 && initialized(revision)==0);
  revision=reset();guard_alias_write(&guard_value,1);EXPECT(guard_value==7 && guard_events==79 && initialized(revision)==0);
  revision=reset();EXPECT(guard_forward_read(&guard_value,1)==12 && guard_events==98 && initialized(revision)==0);
  revision=reset();int32_t local=8;EXPECT(guard_forward_read(&local,-1)==8 && local==8 && guard_events==98 && states[1]==0 && states[2]==0 && !failed && ube_thread_error.revision==revision);
  revision=reset();states[0]=0;EXPECT(guard_start(0) && guard_first==12 && guard_tail==9 && guard_calls==1 && guard_main()==129 && initialized(revision)==0);EXPECT(guard_start(0) && guard_calls==1 && guard_initializations==1);
 }else{
  EXPECT(guard_read()==0 && guard_events==0 && guard_value==12 && refused(revision)==0);
  revision=reset();guard_write();EXPECT(guard_value==12 && guard_events==4 && refused(revision)==0);
  revision=reset();EXPECT(guard_call()==0 && guard_events==5 && guard_calls==0 && refused(revision)==0);
  revision=reset();EXPECT(guard_native().value==0 && guard_events==6 && refused(revision)==0);
  revision=reset();EXPECT(guard_alias_read(&guard_value,1)==0 && guard_events==0 && refused(revision)==0);
  revision=reset();guard_alias_write(&guard_value,1);EXPECT(guard_value==12 && guard_events==7 && refused(revision)==0);
  revision=reset();EXPECT(guard_forward_read(&guard_value,1)==0 && guard_events==0 && refused(revision)==0);
  revision=reset();states[0]=0;EXPECT(!guard_start(0) && states[0]==3 && states[1]==3 && states[2]==3 && failed && guard_first==0 && guard_tail==0 && guard_calls==0 && ube_err_number()==28 && ube_thread_error.revision==revision+1);EXPECT(!guard_start(0) && guard_initializations==1 && ube_thread_error.revision==revision+1);
 }
 return 0;
}
