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
extern _Thread_local uint64_t floor_value __asm__("ube.stack.floor");
extern uint8_t states[3] __asm__("ube.module.states");
extern bool failed __asm__("ube.module.failed");
/* Deliberately controlled frame/reserve data: this tests real platform
   integration, not derived stack safety. No replacement setup/fatal/wait. */
const uint64_t reserve_value __asm__("ube.stack.reserve")=MODE==1?0:256;
#define FIRST (ROOT_COUNT==1?1:0)
#define REFUSED(I) ((MODE==2 && (I)==FIRST) || (MODE==3 && (I)==(ROOT_COUNT==1?0:2)))
const uint64_t frames[6] __asm__("ube.stack.frames")={32,MODE==4?UINT64_MAX:32,REFUSED(0)?UINT64_MAX:32,REFUSED(1)?UINT64_MAX:32,REFUSED(2)?UINT64_MAX:32,32};
static int trace,main_calls;static uint64_t first_floor;
static void require(bool c){if(!c){fprintf(stderr,"platform entry observer mode %d trace %d calls %d\n",MODE,trace,main_calls);exit(98);}}
static bool initialized(int id){require(floor_value!=0);if(!trace)first_floor=floor_value;require(first_floor==floor_value);trace=trace*10+id+1;return true;}
bool init_a(void) __asm__("ube.module.init0");bool init_b(void) __asm__("ube.module.init1");bool init_c(void) __asm__("ube.module.init2");
bool init_a(void){return initialized(0);}bool init_b(void){return initialized(1);}bool init_c(void){return initialized(2);}
static void main_effects(void){require(floor_value==first_floor && trace==(ROOT_COUNT==1?231:123) && !failed);++main_calls;}
#if MAIN_KIND==6
int32_t language_main(void) __asm__("ube.f42");int32_t language_main(void){main_effects();return INT32_MIN+47;}
#else
void language_main(void) __asm__("ube.f42");void language_main(void){main_effects();}
#endif
#if !ORDINARY_ADAPTER
int main(void){ube_err_set(77,"prior","platform entry");uint64_t revision=ube_thread_error.revision;int32_t result=program_run();
 if(MODE==1 || MODE==2){require(result==1 && trace==0 && main_calls==0 && floor_value==0 && !failed);for(int i=0;i<3;++i)require(states[i]==0);}
 else if(MODE==3){require(result==1 && main_calls==0 && trace==(ROOT_COUNT==1?23:12) && failed);}
 else {require(trace==(ROOT_COUNT==1?231:123) && !failed && main_calls==(MODE!=4));require(result==(MODE==4 || MAIN_KIND==5?0:INT32_MIN+47));for(int i=0;i<3;++i)require(states[i]==2);}
 require(ube_err_number()==(MODE>=3?28:77));require(ube_thread_error.revision==revision+(MODE>=3));
 printf("result\t%d\terr\t%d\n",result,ube_err_number());return 0;
}
#endif
