extern int32_t platform_support(struct writer*);
static int platform_cases(struct writer* w) {
 w->usage=(struct usage){0};defaults(&w->limits);CHECK(begin(w));ube_err_set(77,"prior","platform emission");observe();
 CHECK(platform_support(w) && w->usage.identities==103 && w->usage.work==0 && w->usage.pending==0 && w->usage.depth==0 && ube_err_number()==77 && copies<=(size_t)w->output.capacity*2);observing=0;
 int64_t bytes=w->usage.llvm,peak=w->usage.peak_payload;
 CHECK(save_entry(w,"platform.ll")==0 && dispose(w) && w->usage.payload==0);
 for(int category=0;category<3;++category)for(int delta=-1;delta<=0;++delta){
  w->usage=(struct usage){0};defaults(&w->limits);if(category==0)w->limits.identities=103+delta;if(category==1)w->limits.llvm=bytes+delta;if(category==2)w->limits.payload=peak+delta;
  CHECK(begin(w));int ok=platform_support(w);CHECK(ok==(delta==0));if(!ok)CHECK(w->failure.code==1502);CHECK(dispose(w) && w->usage.payload==0);
 }
 w->usage=(struct usage){0};defaults(&w->limits);CHECK(begin(w));ube_gc_test_fail_next_allocations(1000000);CHECK(!platform_support(w) && w->failure.code!=0);ube_gc_test_fail_next_allocations(0);CHECK(dispose(w) && w->usage.payload==0);
 w->usage=(struct usage){0};CHECK(begin(w) && make_cancel(&w->cancellation));*(bool*)w->cancellation=true;observe();CHECK(!platform_support(w) && w->failure.code==1507 && clean_cost());CHECK(dispose(w));w->cancellation=NULL;
 return 0;
}
