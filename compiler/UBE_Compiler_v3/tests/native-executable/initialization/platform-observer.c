#include <windows.h>
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "bootstrap/runtime/error_support.c"
#ifndef RESERVE
#define RESERVE 256
#endif
_Static_assert(sizeof(MEMORY_BASIC_INFORMATION)==48,"query record size");
_Static_assert(offsetof(MEMORY_BASIC_INFORMATION,BaseAddress)==0,"base offset");
_Static_assert(offsetof(MEMORY_BASIC_INFORMATION,AllocationBase)==8,"allocation offset");
_Static_assert(offsetof(MEMORY_BASIC_INFORMATION,RegionSize)==24,"size offset");
_Static_assert(offsetof(MEMORY_BASIC_INFORMATION,State)==32,"state offset");
_Static_assert(offsetof(MEMORY_BASIC_INFORMATION,Protect)==36,"protect offset");
_Static_assert(offsetof(MEMORY_BASIC_INFORMATION,Type)==40,"type offset");
extern _Thread_local uint64_t floor_value __asm__("ube.stack.floor");
const uint64_t reserve_value __asm__("ube.stack.reserve")=RESERVE;
extern bool initialize(uint64_t,uint64_t) __asm__("ube.stack.initialize");
extern __attribute__((noreturn)) void fatal(void) __asm__("ube.stack.abort");
extern __attribute__((noreturn)) void wait_forever(void) __asm__("ube.module.wait");
static int assertions;
#define REQUIRE(C) do {++assertions;if(!(C)){fprintf(stderr,"platform observer line %d: %s\n",__LINE__,#C);exit(1);}}while(0)
static void check(uint64_t caller,uint64_t first,bool success,uint64_t expected) {
 floor_value=0xABCDEF;ube_err_set(77,"prior","platform");uint64_t revision=ube_thread_error.revision;
 REQUIRE(initialize(caller,first)==success);
 REQUIRE(floor_value==(success?expected:0xABCDEF));
 REQUIRE(ube_err_number()==77 && ube_thread_error.revision==revision);
}
#ifdef SYNTHETIC
static MEMORY_BASIC_INFORMATION regions[4],initial;
static int queries,fail_at,short_at;
static void prepare(void){
 queries=0;fail_at=short_at=-1;
 for(int i=0;i<4;++i)regions[i]=(MEMORY_BASIC_INFORMATION){.BaseAddress=(void*)(uintptr_t)(0x10000+i*0x1000),.AllocationBase=(void*)0x10000,.RegionSize=0x1000,.State=MEM_COMMIT,.Protect=PAGE_READWRITE,.Type=MEM_PRIVATE};
 regions[0].State=MEM_RESERVE;regions[0].Protect=0xCCCCCCCC;regions[0].Type=0xCCCCCCCC;
 regions[2].Protect=PAGE_READWRITE|PAGE_GUARD;initial=regions[3];
}
/* The response stream is independent of the production forward traversal.
   Every query address and buffer extent is checked before returning a record. */
uint64_t platform_query(void* address,void* record,uint64_t bytes){
 int q=queries++;REQUIRE(bytes==48 && q<5);
 REQUIRE((uintptr_t)address==(q?0x10000+(uintptr_t)(q-1)*0x1000:0x137FF));
 if(q==fail_at)return 0;if(q==short_at)return 47;
 memcpy(record,q?&regions[q-1]:&initial,48);return 48;
}
static void synthetic(void){
 prepare();check(0,1,false,0);REQUIRE(queries==0);
 prepare();check(0x13800,0,false,0);REQUIRE(queries==0);
#if RESERVE==0
 prepare();check(0x13800,1,false,0);REQUIRE(queries==0);return;
#elif RESERVE>0x800
 prepare();check(0x13800,1,false,0);REQUIRE(queries==5);return;
#endif
 prepare();check(0x13800,0x800-RESERVE,true,0x13000);REQUIRE(queries==5);
 prepare();check(0x13800,0x801-RESERVE,false,0);
 prepare();check(0x13800,UINT64_MAX,false,0);
 for(int q=0;q<5;++q){prepare();fail_at=q;check(0x13800,1,false,0);REQUIRE(queries==q+1);prepare();short_at=q;check(0x13800,1,false,0);REQUIRE(queries==q+1);}
 const DWORD states[]={MEM_FREE,MEM_RESERVE,0,0xFFFFFFFF};
 for(size_t i=0;i<sizeof states/sizeof states[0];++i){prepare();initial.State=states[i];initial.AllocationBase=(void*)UINTPTR_MAX;check(0x13800,1,false,0);REQUIRE(queries==1);}
 prepare();initial.AllocationBase=0;check(0x13800,1,false,0);REQUIRE(queries==1);
 prepare();initial.AllocationBase=(void*)0x13800;check(0x13800,1,false,0);REQUIRE(queries==1);
 for(int mutation=0;mutation<9;++mutation){prepare();
  switch(mutation){case 0:regions[1].RegionSize=0;break;case 1:regions[1].RegionSize=UINTPTR_MAX;break;case 2:regions[1].BaseAddress=(void*)0x11001;break;case 3:regions[1].BaseAddress=(void*)0x10000;regions[1].RegionSize=0x1000;break;case 4:regions[1].BaseAddress=(void*)0xFFFF;break;case 5:regions[1].State=MEM_FREE;regions[1].AllocationBase=(void*)UINTPTR_MAX;break;case 6:regions[1].State=0;break;case 7:regions[1].AllocationBase=(void*)0x20000;break;case 8:regions[1].Type=MEM_MAPPED;break;}
  check(0x13800,1,false,0);REQUIRE(queries==3);
 }
 const DWORD protection[]={PAGE_READONLY,PAGE_NOACCESS,PAGE_EXECUTE,PAGE_EXECUTE_READ,PAGE_WRITECOPY,PAGE_EXECUTE_WRITECOPY,PAGE_READWRITE|PAGE_GUARD,0,PAGE_READWRITE,PAGE_EXECUTE_READWRITE};
 for(size_t i=0;i<sizeof protection/sizeof protection[0];++i){prepare();regions[2].Protect=protection[i];check(0x13800,1,true,i<8?0x13000:0x11000);prepare();regions[3].Protect=protection[i];check(0x13800,1,i>=8,0x13000);}
 prepare();regions[2].State=MEM_RESERVE;regions[2].Protect=0xCCCCCCCC;regions[2].Type=0xCCCCCCCC;check(0x13800,1,true,0x13000);
 prepare();regions[3].State=MEM_RESERVE;check(0x13800,1,false,0);
}
#else
/* Independent oracle: inspect individual pages downwards, with the system's
   actual page size. It never consumes the candidate's reported floor. */
static uint64_t backward_floor(uint64_t caller){
 SYSTEM_INFO system;GetSystemInfo(&system);REQUIRE(system.dwPageSize!=0);
 uint64_t page=(caller-1)-(caller-1)%system.dwPageSize;MEMORY_BASIC_INFORMATION info;
 REQUIRE(VirtualQuery((void*)(uintptr_t)page,&info,sizeof info)==sizeof info);void* allocation=info.AllocationBase;
 for(;;){
  REQUIRE(info.State==MEM_COMMIT && info.Type==MEM_PRIVATE && !(info.Protect&PAGE_GUARD) && ((info.Protect&255)==PAGE_READWRITE || (info.Protect&255)==PAGE_EXECUTE_READWRITE));
  if(page<system.dwPageSize)return page;
  uint64_t previous=page-system.dwPageSize;
  REQUIRE(VirtualQuery((void*)(uintptr_t)previous,&info,sizeof info)==sizeof info);
  if(info.State!=MEM_COMMIT || info.AllocationBase!=allocation || info.Type!=MEM_PRIVATE || (info.Protect&PAGE_GUARD) || ((info.Protect&255)!=PAGE_READWRITE && (info.Protect&255)!=PAGE_EXECUTE_READWRITE))return page;
  page=previous;
 }
}
static void actual(void){
 uint64_t sp;__asm__ volatile("movq %%rsp,%0":"=r"(sp)::"memory");
 uint64_t expected=backward_floor(sp);REQUIRE(sp-expected>RESERVE+1);check(sp,1,true,expected);
 SYSTEM_INFO system;GetSystemInfo(&system);SIZE_T page=system.dwPageSize;
 unsigned char* area=VirtualAlloc(NULL,page*16,MEM_RESERVE,PAGE_NOACCESS);REQUIRE(area!=NULL);
 REQUIRE(VirtualAlloc(area+page*4,page*12,MEM_COMMIT,PAGE_READWRITE)==area+page*4);
 DWORD old;REQUIRE(VirtualProtect(area+page*8,page,PAGE_READWRITE|PAGE_GUARD,&old));
 REQUIRE(VirtualProtect(area+page*5,page,PAGE_READONLY,&old));
 uint64_t caller=(uintptr_t)(area+page*16);expected=(uintptr_t)(area+page*9);
 REQUIRE(backward_floor(caller)==expected);check(caller,caller-expected-RESERVE,true,expected);check(caller,caller-expected-RESERVE+1,false,0);
 MEMORY_BASIC_INFORMATION guard;REQUIRE(VirtualQuery(area+page*8,&guard,sizeof guard)==sizeof guard && (guard.Protect&PAGE_GUARD));
 REQUIRE(VirtualProtect(area+page*15,page,PAGE_NOACCESS,&old));check(caller,1,false,0);
 REQUIRE(VirtualFree(area,0,MEM_RELEASE));
}
#endif
#ifdef CONTROL_CALLS
int platform_terminate(void* process,uint32_t status){REQUIRE(process==(void*)UINTPTR_MAX && status==1);return 0;}
__attribute__((noreturn)) void platform_exit(uint32_t status){REQUIRE(status==1);exit(91);}
static int sleeps;
void platform_sleep(uint32_t duration){REQUIRE(duration==INFINITE);if(++sleeps==3)exit(92);}
#endif
int main(int argc,char** argv){
 if(argc==2){if(strcmp(argv[1],"fatal")==0)fatal();if(strcmp(argv[1],"wait")==0){puts("waiting");fflush(stdout);wait_forever();}return 98;}
#ifdef SYNTHETIC
 synthetic();
#else
 actual();
#endif
 printf("PASS platform %d assertions\n",assertions);return 0;
}
