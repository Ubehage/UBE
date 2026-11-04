#define main retained_byte_key_main
#include "probe.c"
#undef main
struct budget {int64_t maximum_bytes,maximum_events,bytes,events;};
extern int32_t key_order_budgeted(void**,void**,int32_t,int32_t,void**,int32_t*,struct budget*,bool*);
extern int32_t key_find_budgeted(void**,void**,void**,void**,int32_t,int32_t,int32_t,int32_t*,int32_t*,int32_t*,struct budget*,bool*);
extern int32_t budget_admit(struct budget*,bool*,int32_t,int32_t*);
static int64_t admitted_events,admitted_bytes,polls,cancel_at;static bool* cancellation;
void budget_poll(void){++polls;if(cancellation && cancel_at && polls==cancel_at)*cancellation=true;}
void budget_event(int32_t bytes){
#ifndef OMIT_BUDGET_OBSERVATIONS
 ++admitted_events;admitted_bytes+=bytes;
#else
 (void)bytes;
#endif
}
static void begin_budget(struct budget* b,bool* cancel){*b=(struct budget){INT64_MAX,INT64_MAX,0,0};*cancel=false;cancellation=cancel;cancel_at=0;polls=admitted_events=admitted_bytes=0;}
static int balanced(struct budget b){CHECK(b.events==admitted_events && b.bytes==admitted_bytes && b.bytes==(int64_t)observed.byte_reads && observed.events[1]==observed.byte_reads);return 0;}
int main(void){
 struct environment env;CHECK(environment_open(&env,8,3)==0);struct budget b;bool cancel=false;int32_t failure=5;begin_budget(&b,&cancel);ube_err_set(77,"prior","budgeted sort");observation_start(0);
 CHECK(key_order_budgeted(&env.bytes,&env.keys,env.n,8,&env.order,&failure,&b,&cancel));observation_stop();CHECK(failure==0 && ube_err_number()==77 && balanced(b)==0 && order_equal(&env)==0);
 int64_t sort_bytes=b.bytes,sort_events=b.events;CHECK(sort_bytes>1000 && sort_events>100);
 for(int cap=0;cap<2;++cap)for(int delta=-1;delta<=0;++delta){env.order=env.old;(void)ube_gc_collect();begin_budget(&b,&cancel);if(cap)b.maximum_events=sort_events+delta;else b.maximum_bytes=sort_bytes+delta;failure=5;observation_start(0);int ok=key_order_budgeted(&env.bytes,&env.keys,8,8,&env.order,&failure,&b,&cancel);observation_stop();CHECK(ok==(delta==0) && balanced(b)==0 && ube_err_number()==77);if(ok)CHECK(order_equal(&env)==0);else CHECK(failure==2 && old_equal(&env)==0);}
 for(int64_t at=1;at<=sort_events;++at){env.order=env.old;(void)ube_gc_collect();begin_budget(&b,&cancel);cancel_at=at;failure=5;observation_start(0);int ok=key_order_budgeted(&env.bytes,&env.keys,8,8,&env.order,&failure,&b,&cancel);observation_stop();CHECK(!ok && failure==3 && cancel && b.events==at-1 && balanced(b)==0 && old_equal(&env)==0 && ube_err_number()==77);}
 for(size_t at=1;at<=4;++at){env.order=env.old;(void)ube_gc_collect();begin_budget(&b,&cancel);failure=5;observation_start(at);int ok=key_order_budgeted(&env.bytes,&env.keys,8,8,&env.order,&failure,&b,&cancel);observation_stop();CHECK(!ok && failure==5 && ube_err_number()==7 && old_equal(&env)==0 && balanced(b)==0);}
 begin_budget(&b,&cancel);CHECK(key_order_budgeted(&env.bytes,&env.keys,8,8,&env.order,&failure,&b,&cancel));void* sorted=env.order;
 void* query=NULL;root query_root={0};CHECK(ube_gc_root_enter(&query_root,&query) && ube_value_try_resize(&query,69,&byte_layout,0));memcpy(ube_array_element(query,1),env.byte_image+1+3*68,68);
 int32_t first=71,count=83;begin_budget(&b,&cancel);ube_err_set(77,"prior","cross arena");observation_start(0);CHECK(key_find_budgeted(&env.bytes,&query,&env.keys,&env.order,0,1,68,&first,&count,&failure,&b,&cancel));observation_stop();CHECK(first==4 && count==1 && failure==0 && balanced(b)==0 && observed.allocations==0 && observed.publication==0 && observed.events[2]==0 && ube_err_number()==77);
 int64_t find_bytes=b.bytes,find_events=b.events;
 for(int cap=0;cap<2;++cap)for(int delta=-1;delta<=0;++delta){begin_budget(&b,&cancel);if(cap)b.maximum_events=find_events+delta;else b.maximum_bytes=find_bytes+delta;first=71;count=83;failure=5;observation_start(0);int ok=key_find_budgeted(&env.bytes,&query,&env.keys,&env.order,0,1,68,&first,&count,&failure,&b,&cancel);observation_stop();CHECK(ok==(delta==0) && balanced(b)==0 && env.order==sorted && observed.allocations==0);if(ok)CHECK(first==4 && count==1 && failure==0);else CHECK(first==71 && count==83 && failure==2);}
 for(int64_t at=1;at<=find_events;++at){begin_budget(&b,&cancel);cancel_at=at;first=71;count=83;failure=5;observation_start(0);int ok=key_find_budgeted(&env.bytes,&query,&env.keys,&env.order,0,1,68,&first,&count,&failure,&b,&cancel);observation_stop();CHECK(!ok && first==71 && count==83 && failure==3 && b.events==at-1 && balanced(b)==0 && env.order==sorted);}
 begin_budget(&b,&cancel);first=71;count=83;CHECK(!key_find_budgeted(&env.bytes,&query,&env.keys,&env.order,0,70,0,&first,&count,&failure,&b,&cancel) && failure==1 && first==71 && count==83);
 begin_budget(&b,&cancel);CHECK(key_find_budgeted(&env.bytes,&query,&env.keys,&env.order,0,69,0,&first,&count,&failure,&b,&cancel) && first==0 && count==0);
 *(unsigned char*)ube_array_element(query,68)=0;begin_budget(&b,&cancel);CHECK(key_find_budgeted(&env.bytes,&query,&env.keys,&env.order,0,1,68,&first,&count,&failure,&b,&cancel) && first==0 && count==0);
 for(int field=0;field<4;++field){begin_budget(&b,&cancel);((int64_t*)&b)[field]=-1;struct budget old=b;first=71;count=83;CHECK(!key_find_budgeted(&env.bytes,&query,&env.keys,&env.order,0,1,68,&first,&count,&failure,&b,&cancel) && failure==1 && first==71 && count==83 && memcmp(&b,&old,sizeof b)==0);}
 begin_budget(&b,&cancel);b.bytes=b.events=INT64_MAX-1;CHECK(budget_admit(&b,&cancel,1,&failure) && b.bytes==INT64_MAX && b.events==INT64_MAX);struct budget old=b;CHECK(!budget_admit(&b,&cancel,1,&failure) && failure==2 && memcmp(&old,&b,sizeof b)==0);
 size_t available=storage_root_limit()-storage_root_count();root* pressure=calloc(available,sizeof *pressure);CHECK(pressure);void* nil=NULL;for(size_t i=0;i<available;++i)CHECK(ube_gc_root_enter(&pressure[i],&nil));begin_budget(&b,&cancel);old=b;failure=5;first=71;count=83;CHECK(!key_order_budgeted(&env.bytes,&env.keys,8,8,&env.order,&failure,&b,&cancel) && failure==5 && env.order==sorted && memcmp(&b,&old,sizeof b)==0);CHECK(!key_find_budgeted(&env.bytes,&query,&env.keys,&env.order,0,1,68,&first,&count,&failure,&b,&cancel) && failure==5 && first==71 && count==83 && b.bytes==0 && b.events==1 && admitted_events==1);for(size_t i=0;i<available;++i)CHECK(ube_gc_root_leave(&pressure[i]));free(pressure);
 CHECK(ube_gc_root_leave(&query_root));query=NULL;CHECK(environment_close(&env)==0);printf("PASS budgeted byte keys %u assertions; sort %lld bytes/%lld events; query %lld bytes/%lld events\n",assertions,(long long)sort_bytes,(long long)sort_events,(long long)find_bytes,(long long)find_events);return 0;
}
