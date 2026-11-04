#include "body-require.c"
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include "bootstrap/runtime/error_support.c"
#include "call-functions.h"
/* Ownership transport observes actual generated pointer/companion calls. The
   controlled floor/frames do not qualify startup or real machine footprints. */
_Thread_local uint64_t owner_floor __asm__("ube.stack.floor")=1;
const uint64_t owner_reserve __asm__("ube.stack.reserve")=1;
const uint64_t owner_frames[CALL_FRAME_COUNT] __asm__("ube.stack.frames")={32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32};
__attribute__((noreturn)) void owner_abort(void) __asm__("ube.stack.abort");
__attribute__((noreturn)) void owner_abort(void){exit(98);}
struct observed_owner {int32_t procedure,parameter,owner;};
static struct observed_owner observations[32];static int count;
void observe_owner(int32_t procedure,int32_t parameter,int32_t owner){if(count>=32)exit(98);observations[count++]=(struct observed_owner){procedure,parameter,owner};}
#define EXPECT(c) do{if(!(c)){fprintf(stderr,"owner oracle line %d: %s\n",__LINE__,#c);return 1;}}while(0)
static int owners(int procedure,int first,int second,int repetitions){EXPECT(count==repetitions*(procedure==3?2:1));int at=0;for(int r=0;r<repetitions;++r){EXPECT(observations[at].procedure==procedure && observations[at].parameter==0 && observations[at].owner==first);++at;if(procedure==3){EXPECT(observations[at].procedure==procedure && observations[at].parameter==1 && observations[at].owner==second);++at;}}count=0;return 0;}
int main(void){ube_err_set(77,"prior","owner transport");int32_t trace=0,x=3;
 call_reset();EXPECT(call_ordered(&trace,0)==127 && trace==21 && owners(0,0,0,2)==0);
 trace=0;EXPECT(call_ordered(&trace,-1)==127 && trace==21 && owners(0,-1,0,2)==0);
 EXPECT(call_temporary(&x,0)==3 && x==3 && owners(3,-1,-1,1)==0);
 EXPECT(call_repeated()==15 && owners(3,-1,-1,3)==0);
 EXPECT(call_aliased(&x,0)==99 && x==99 && owners(3,0,0,1)==0);
 call_reset();EXPECT(call_global_alias()==4 && call_count()==4 && owners(0,0,0,1)==0);
 EXPECT(call_byval_alias(3)==8 && owners(3,-1,-1,1)==0);
 call_reset();EXPECT(call_named_alias()==299 && owners(3,0,-1,1)==0);
 trace=0;EXPECT(call_recursive_alias(&trace,0,4)==3 && trace==3 && owners(0,0,0,1)==0);
 EXPECT(count==0 && ube_err_number()==77);puts("PASS ByRef module owners");return 0;}
