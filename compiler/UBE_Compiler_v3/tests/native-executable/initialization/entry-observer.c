#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include "bootstrap/runtime/error_support.c"
#ifndef MAIN_KIND
#define MAIN_KIND 6
#endif
#ifndef ROOT_COUNT
#define ROOT_COUNT 1
#endif
#ifndef MODE
#define MODE 0
#endif
#ifndef ORDINARY_ADAPTER
#define ORDINARY_ADAPTER 0
#endif
extern int32_t program_run(void) __asm__("ube.program.run");
extern uint8_t states[3] __asm__("ube.module.states");
extern bool failed __asm__("ube.module.failed");
_Thread_local uint64_t floor_value __asm__("ube.stack.floor")=1;
const uint64_t reserve_value __asm__("ube.stack.reserve")=1;
#define REFUSED(I) (MODE==3 && (I)==(ROOT_COUNT==1?0:2))
const uint64_t frames[6] __asm__("ube.stack.frames")={32,MODE==4?UINT64_MAX:32,REFUSED(0)?UINT64_MAX:32,REFUSED(1)?UINT64_MAX:32,REFUSED(2)?UINT64_MAX:32,32};
static int setups,trace,main_calls;static bool ready;
/* Controlled support verifies the compiler boundary. It does not query pages
   or establish a real startup invariant; platform qualification is separate. */
bool setup(uint64_t sp,uint64_t first) __asm__("ube.stack.initialize");
bool setup(uint64_t sp,uint64_t first){if(!sp || first!=frames[2+(ROOT_COUNT==1?1:0)] || setups || trace || main_calls)exit(98);++setups;ready=MODE!=1 && MODE!=2;return ready;}
bool init_a(void) __asm__("ube.module.init0");bool init_b(void) __asm__("ube.module.init1");bool init_c(void) __asm__("ube.module.init2");
static bool initialized(int id){if(!ready || setups!=1)exit(98);trace=trace*10+id+1;if(id==0 && MODE==5)ube_err_set(11,"division by zero","UBE.Runtime");return true;}
bool init_a(void){return initialized(0);}bool init_b(void){return initialized(1);}bool init_c(void){return initialized(2);}
__attribute__((noreturn)) void abort_stack(void) __asm__("ube.stack.abort");void abort_stack(void){exit(98);}
__attribute__((noreturn)) void wait_module(void) __asm__("ube.module.wait");void wait_module(void){exit(98);}
static void main_effects(void){if(!ready || setups!=1 || trace!=(ROOT_COUNT==1?231:123) || failed)exit(98);++main_calls;}
#if MAIN_KIND==6
int32_t language_main(void) __asm__("ube.f42");int32_t language_main(void){main_effects();return INT32_MIN+47;}
#else
void language_main(void) __asm__("ube.f42");void language_main(void){main_effects();}
#endif
#if !ORDINARY_ADAPTER
#define EXPECT(C) do{if(!(C)){fprintf(stderr,"entry oracle kind %d root %d mode %d line %d: %s\n",MAIN_KIND,ROOT_COUNT,MODE,__LINE__,#C);return 1;}}while(0)
int main(void){ube_err_set(77,"prior","entry observation");uint64_t revision=ube_thread_error.revision;
 int32_t result=program_run();int32_t error=ube_err_number();
 EXPECT(setups==1);
 if(MODE==1 || MODE==2){EXPECT(result==1 && error==77 && trace==0 && main_calls==0 && !failed && states[0]==0 && states[1]==0 && states[2]==0 && ube_thread_error.revision==revision);}
 else if(MODE==3){EXPECT(result==1 && error==28 && failed && !main_calls && trace==(ROOT_COUNT==1?23:12) && ube_thread_error.revision==revision+1);}
 else if(MODE==4){EXPECT(result==0 && error==28 && !failed && !main_calls && trace==(ROOT_COUNT==1?231:123) && ube_thread_error.revision==revision+1);}
 else{EXPECT(result==(MAIN_KIND==6?INT32_MIN+47:0) && error==(MODE==5?11:77) && !failed && main_calls==1 && trace==(ROOT_COUNT==1?231:123) && states[0]==2 && states[1]==2 && states[2]==2 && ube_thread_error.revision==revision+(MODE==5));}
 printf("result\t%d\terr\t%d\n",result,error);return 0;}
#endif
