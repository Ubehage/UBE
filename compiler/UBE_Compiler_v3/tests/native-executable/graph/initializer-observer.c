#include "body-require.c"
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <windows.h>
#include "bootstrap/runtime/error_support.c"
#include "initializer-functions.h"
#ifndef REFUSE_MODE
#define REFUSE_MODE 0
#endif
_Thread_local uint64_t init_floor __asm__("ube.stack.floor")=1;
const uint64_t init_reserve __asm__("ube.stack.reserve")=1;
#if REFUSE_MODE
const uint64_t init_frames[6] __asm__("ube.stack.frames")={UINT64_MAX,UINT64_MAX,UINT64_MAX,UINT64_MAX,32,32};
#else
const uint64_t init_frames[6] __asm__("ube.stack.frames")={32,32,32,32,32,32};
#endif
__attribute__((noreturn)) void init_abort(void) __asm__("ube.stack.abort");
void init_abort(void){ExitProcess(98);}
#define EXPECT(C) do{if(!(C)){fprintf(stderr,"initializer oracle line %d: %s\n",__LINE__,#C);return 1;}}while(0)
int main(void) {
 ube_err_set(77,"prior","initializer observer");uint64_t revision=ube_thread_error.revision;
 EXPECT(checked_initializer());
#if REFUSE_MODE
 EXPECT(init_events==0 && init_first==0 && init_later==1 && init_quotient==0 && init_forced==0 && init_defaulted==0 && init_snapshot==0);
 EXPECT(initializer_main()==1000 && ube_err_number()==28 && ube_thread_error.revision==revision+5);
#else
 EXPECT(init_events==1233 && init_first==4 && init_later==1 && init_quotient==0 && init_forced==3 && init_defaulted==5 && init_snapshot==1233);
 EXPECT(initializer_main()==41350 && ube_err_number()==11 && ube_thread_error.revision==revision+1);
#endif
 return 0;
}
