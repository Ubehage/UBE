#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include "bootstrap/runtime/error_support.c"
#ifndef MODE
#define MODE 0
#endif
extern int32_t initialization_require_other(int32_t,int32_t);
extern int32_t initialization_require(int32_t,int32_t),initialization_state(int32_t),initialization_failed(void);
_Thread_local uint64_t floor_value __asm__("ube.stack.floor")=1;
const uint64_t reserve_value __asm__("ube.stack.reserve")=1;
const uint64_t frame_values[6] __asm__("ube.stack.frames")={32,32,MODE==2?UINT64_MAX:32,MODE==3?UINT64_MAX:32,32,MODE==7?UINT64_MAX:32};
static int entered[3],completed[3],order,own_ok;
__attribute__((noreturn)) void abort_support(void) __asm__("ube.stack.abort");
__attribute__((noreturn)) void wait_support(void) __asm__("ube.module.wait");
__attribute__((noreturn)) void abort_support(void){exit((MODE==7 && entered[0]==1 && entered[1]==1 && !completed[0] && !completed[1]) || (MODE==8 && order==0)?97:98);}
__attribute__((noreturn)) void wait_support(void){if((MODE!=6 && MODE!=7)||entered[0]!=1||entered[1]!=1||completed[0]||completed[1])exit(98);puts("waiting:A");fflush(stdout);for(;;)Sleep(INFINITE);}
bool init_a(void) __asm__("ube.module.init0");
bool init_b(void) __asm__("ube.module.init1");
bool init_c(void) __asm__("ube.module.init2");
bool init_a(void){++entered[0];own_ok=initialization_require(0,0);if(!initialization_require(1,0))return MODE==5;completed[0]=1;order=order*10+1;return true;}
bool init_b(void){++entered[1];if(MODE==4||MODE==5){ube_err_set(11,"failure","module cannot complete");return false;}if(MODE==6||MODE==7)if(!initialization_require_other(0,1))return false;if(MODE==1)ube_err_set(11,"expression","neutral result continues");completed[1]=1;order=order*10+2;return true;}
bool init_c(void){++entered[2];completed[2]=1;order=order*10+3;return true;}
#define EXPECT(c) do{if(!(c)){fprintf(stderr,"initialization observer mode %d line %d: %s\n",MODE,__LINE__,#c);return 1;}}while(0)
int main(void){ube_err_set(77,"prior","startup");uint64_t revision=ube_thread_error.revision;
 if(MODE==8){(void)initialization_require(3,-1);return 1;}
 EXPECT(initialization_require(-1,0) && order==0);if(MODE==9)EXPECT(initialization_require(1,-1) && order==2 && entered[0]==0);int ok=initialization_require(0,-1);
 if(MODE==0||MODE==1||MODE==9){EXPECT(ok && own_ok && order==21 && entered[0]==1 && entered[1]==1 && initialization_state(0)==2 && initialization_state(1)==2 && !initialization_failed());EXPECT(initialization_require(0,-1) && initialization_require(1,-1) && order==21);EXPECT(initialization_require_other(1,-1) && order==21 && entered[1]==1);EXPECT(initialization_require(2,-1) && order==213 && entered[2]==1);EXPECT(ube_err_number()==(MODE==1?11:77) && ube_thread_error.revision==revision+(MODE==1));}
 else {EXPECT(!ok && initialization_failed() && order==0 && initialization_state(0)==3);EXPECT(initialization_state(1)==(MODE==2?0:3) && initialization_state(2)==0);EXPECT(entered[0]==(MODE!=2) && entered[1]==(MODE==4||MODE==5));EXPECT(!initialization_require(2,-1) && !initialization_require(-1,0) && entered[2]==0);EXPECT(ube_err_number()==(MODE==2||MODE==3?28:11));EXPECT(!initialization_require(0,-1) && entered[0]==(MODE!=2));}
 puts("PASS initialization runtime");return 0;}
