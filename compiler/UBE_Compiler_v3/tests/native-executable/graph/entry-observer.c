#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include "bootstrap/runtime/error_support.c"
#include "guard-functions.h"
#ifndef REFERENCE
#define REFERENCE 0
#endif
#ifndef MODE
#define MODE 0
#endif
#ifndef ORDINARY_ADAPTER
#define ORDINARY_ADAPTER 0
#endif
extern int32_t program_run(void) __asm__("ube.program.run");
extern uint8_t states[3] __asm__("ube.module.states");extern bool failed __asm__("ube.module.failed");
_Thread_local uint64_t floor_value __asm__("ube.stack.floor")=1;
const uint64_t reserve_value __asm__("ube.stack.reserve")=1;
#define F(I) (((MODE==3 && (I)==16)||(MODE==4 && (I)==11))?UINT64_MAX:32)
const uint64_t frames[18] __asm__("ube.stack.frames")={F(0),F(1),F(2),F(3),F(4),F(5),F(6),F(7),F(8),F(9),F(10),F(11),F(12),F(13),F(14),F(15),F(16),F(17)};
static int setups;
bool setup(uint64_t sp,uint64_t first) __asm__("ube.stack.initialize");
bool setup(uint64_t sp,uint64_t first){if(!sp || first!=frames[REFERENCE?15:14] || setups || guard_initializations || guard_cinitializations || guard_calls)exit(98);++setups;return MODE!=1 && MODE!=2;}
__attribute__((noreturn)) void abort_stack(void) __asm__("ube.stack.abort");void abort_stack(void){exit(98);}
__attribute__((noreturn)) void wait_module(void) __asm__("ube.module.wait");void wait_module(void){exit(98);}
#if !ORDINARY_ADAPTER
#define EXPECT(C) do{if(!(C)){fprintf(stderr,"checked entry oracle reference %d mode %d line %d: %s\n",REFERENCE,MODE,__LINE__,#C);return 1;}}while(0)
int main(void){ube_err_set(77,"prior","checked entry");uint64_t revision=ube_thread_error.revision;int32_t result=program_run();int32_t error=ube_err_number();EXPECT(setups==1);
 if(MODE==1 || MODE==2){EXPECT(result==1 && error==77 && !failed && !guard_events && !guard_calls && !guard_initializations && !guard_cinitializations && states[0]==0 && states[1]==0 && states[2]==0 && ube_thread_error.revision==revision);}
 else if(MODE==3){EXPECT(result==1 && error==28 && failed && !guard_events && !guard_calls && guard_initializations==1 && !guard_cinitializations && states[0]==(REFERENCE?0:3) && states[1]==3 && states[2]==3 && ube_thread_error.revision==revision+1);}
 else{EXPECT(result==(MODE==4?0:129) && error==(MODE==4?28:77) && !failed && guard_calls==1 && guard_events==(MODE==4?0:1) && guard_first==12 && guard_tail==9 && guard_initializations==1 && guard_cinitializations==1 && states[0]==2 && states[1]==2 && states[2]==2 && ube_thread_error.revision==revision+(MODE==4));}
 printf("result\t%d\terr\t%d\n",result,error);return 0;}
#endif
