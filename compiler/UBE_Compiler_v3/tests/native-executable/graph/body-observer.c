#include "body-require.c"
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include "bootstrap/runtime/error_support.c"
#include "body-functions.h"
#define EXPECT(C) do{if(!(C)){fprintf(stderr,"body observer line %d: %s\n",__LINE__,#C);return 1;}}while(0)
int main(void) {
 const int seeds[]={0,6,77};
 for(int s=0;s<3;++s) {
  for(int x=-2;x<=12;++x) {
   int expected=x+2,seen=100;while(expected<10){++expected;seen+=expected==7?1:expected==8?2:3;if(expected==9)break;}
   int32_t actual_seen=100;ube_err_set(seeds[s],"prior","observer");uint64_t revision=ube_thread_error.revision;
   EXPECT(body_compute(x,&actual_seen,-1)==expected && actual_seen==seen && ube_err_number()==seeds[s] && ube_thread_error.revision==revision);
   EXPECT(body_branches(x)==(x<0?-3:x==0?17:x<10?23:31));
   EXPECT(body_early(x)==x && ube_err_number()==seeds[s] && ube_thread_error.revision==revision);
   int n=x>0?x:0;EXPECT(body_sum(x)==n*(n+1)/2);
   EXPECT(body_reset(x)==(x>0?1:0) && ube_err_number()==seeds[s] && ube_thread_error.revision==revision);
  }
  for(int gate=0;gate<=1;++gate)for(int z=-2;z<=2;++z) {
   ube_err_set(seeds[s],"prior","short observer");uint64_t revision=ube_thread_error.revision;
   int error=gate && z==0?11:seeds[s];bool expected=gate && z!=0 && (10/z)>0;
   EXPECT(body_short(gate!=0,z)==expected && ube_err_number()==error && ube_thread_error.revision==revision+(gate && z==0));
  }
  for(int a=0;a<=1;++a)for(int b=0;b<=1;++b)for(int z=-2;z<=2;++z) {
   ube_err_set(seeds[s],"prior","nested observer");uint64_t revision=ube_thread_error.revision;bool expected=(a && b) || (z!=0 && 10/z>0);
   EXPECT(body_nested(a!=0,b!=0,z)==expected && ube_err_number()==seeds[s] && ube_thread_error.revision==revision);
  }
  int32_t changed=10;ube_err_set(seeds[s],"prior","sub observer");uint64_t revision=ube_thread_error.revision;body_change(&changed,-1);body_main();
  EXPECT(changed==11 && ube_err_number()==seeds[s] && ube_thread_error.revision==revision);
 }
 return 0;
}
