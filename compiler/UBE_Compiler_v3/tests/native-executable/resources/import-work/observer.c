#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include "bootstrap/runtime/error_support.c"
#include "import-functions.h"
/* Deliberately controlled completed-module state and frame metadata. The
   three-module gate separately qualifies actual initializer execution. */
uint8_t states[11] __asm__("ube.module.states")={2,2,2,2,2,2,2,2,2,2,2};
bool failed __asm__("ube.module.failed");
bool (*initializers[11])(void) __asm__("ube.module.initializers");
_Thread_local uint64_t floor_value __asm__("ube.stack.floor")=1;
const uint64_t reserve_value __asm__("ube.stack.reserve")=1;
const uint64_t frames[23] __asm__("ube.stack.frames")={32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32};
__attribute__((noreturn)) void abort_stack(void) __asm__("ube.stack.abort");
void abort_stack(void){exit(98);}
__attribute__((noreturn)) void wait_module(void) __asm__("ube.module.wait");
void wait_module(void){exit(98);}
int main(void){ube_err_set(77,"prior","import work");uint64_t revision=ube_thread_error.revision;
 if(imported_main()!=21 || imported_main()!=21 || failed || ube_err_number()!=77 || ube_thread_error.revision!=revision)return 1;
 return 0;
}
