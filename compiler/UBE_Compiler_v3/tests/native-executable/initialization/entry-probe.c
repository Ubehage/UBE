extern int32_t entry_support(struct writer*,int32_t,int64_t,int32_t,int32_t,int32_t,int32_t),process_adapter(struct writer*);
static int save_entry(struct writer* w,const char* name){CHECK(snapshot(w));FILE* out=fopen(name,"wb");CHECK(out && fwrite(((struct ube_array*)w->output.snapshot)->data,1,(size_t)w->output.snapshot_length,out)==(size_t)w->output.snapshot_length && fclose(out)==0);return 0;}
static int entry_cases(struct writer* w) {
 for(int kind=5;kind<=6;++kind)for(int root=1;root<=3;root+=2){
  w->usage=(struct usage){0};defaults(&w->limits);CHECK(begin(w));visits=0;ube_err_set(77,"prior","entry emission");observe();
  CHECK(entry_support(w,kind,42,1,3,root,2) && w->usage.work==3 && visits==3 && w->usage.identities==85+(kind==6) && copies<=(size_t)w->output.capacity*2 && ube_err_number()==77);observing=0;
  int64_t bytes=w->usage.llvm,peak=w->usage.peak_payload,ids=w->usage.identities;char name[80];snprintf(name,sizeof name,"entry-%d-%d.ll",kind,root);CHECK(save_entry(w,name)==0 && dispose(w) && w->usage.payload==0);
  for(int category=0;category<4;++category)for(int delta=-1;delta<=0;++delta){w->usage=(struct usage){0};defaults(&w->limits);if(category==0)w->limits.work=3+delta;if(category==1)w->limits.identities=ids+delta;if(category==2)w->limits.llvm=bytes+delta;if(category==3)w->limits.payload=peak+delta;CHECK(begin(w));int ok=entry_support(w,kind,42,1,3,root,2);CHECK(ok==(delta==0));if(!ok)CHECK(w->failure.code==1502);CHECK(dispose(w) && w->usage.payload==0);}
  w->usage=(struct usage){0};defaults(&w->limits);CHECK(begin(w));ube_gc_test_fail_next_allocations(1000000);CHECK(!entry_support(w,kind,42,1,3,root,2) && w->failure.code!=0);ube_gc_test_fail_next_allocations(0);CHECK(dispose(w) && w->usage.payload==0);
  w->usage=(struct usage){0};CHECK(begin(w) && make_cancel(&w->cancellation));*(bool*)w->cancellation=true;observe();CHECK(!entry_support(w,kind,42,1,3,root,2) && w->failure.code==1507 && clean_cost());CHECK(dispose(w));w->cancellation=NULL;
 }
 const int bad[][6]={{4,42,1,3,1,2},{5,-1,1,3,1,2},{6,42,-1,3,1,2},{6,42,2,3,1,2},{6,42,0,0,1,2},{6,42,0,3,0,2},{6,42,0,3,4,2},{6,42,0,3,1,0},{6,42,0,3,1,INT32_MAX}};
 for(size_t i=0;i<sizeof bad/sizeof bad[0];++i){w->usage=(struct usage){0};defaults(&w->limits);CHECK(begin(w));observe();CHECK(!entry_support(w,bad[i][0],bad[i][1],bad[i][2],bad[i][3],bad[i][4],bad[i][5]) && w->failure.code==1509 && w->usage.llvm==0 && w->usage.identities==0 && clean_cost());CHECK(dispose(w));}
 w->usage=(struct usage){0};defaults(&w->limits);CHECK(begin(w) && process_adapter(w) && w->usage.identities==4 && w->usage.work==0);CHECK(save_entry(w,"process-adapter.ll")==0 && dispose(w) && w->usage.payload==0);return 0;
}
