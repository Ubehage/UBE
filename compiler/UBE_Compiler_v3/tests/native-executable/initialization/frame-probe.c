extern int32_t frame_data(struct writer*,void**,int32_t,int32_t,int64_t);
static const struct ube_value_layout frame_scalar_layout={8,0,0,NULL,0,NULL};
static int frame_cases(struct writer* w){
 void* values=NULL;struct ube_gc_root root={0};CHECK(ube_gc_root_enter(&root,&values));
 CHECK(ube_value_try_resize(&values,6,&frame_scalar_layout,0));int64_t* v=(int64_t*)((struct ube_array*)values)->data;for(int i=0;i<6;++i)v[i]=8+i*16;
 w->usage=(struct usage){0};defaults(&w->limits);CHECK(begin(w));visits=0;ube_err_set(77,"prior","frame metadata");observe();
 CHECK(frame_data(w,&values,2,3,48) && w->usage.work==6 && visits==6 && w->usage.identities==2 && w->usage.pending==0 && w->usage.depth==0 && ube_err_number()==77);observing=0;
 int64_t bytes=w->usage.llvm,peak=w->usage.peak_payload;CHECK(save_entry(w,"frame-data.ll")==0);
 const char* expected="target triple = \"x86_64-w64-windows-gnu\"\n@ube.stack.reserve = constant i64 48, align 8\n@ube.stack.frames = constant [6 x i64] [\n  i64 8,\n  i64 24,\n  i64 40,\n  i64 56,\n  i64 72,\n  i64 88] , align 8\n";
 CHECK(w->output.snapshot_length==(int32_t)strlen(expected) && memcmp(((struct ube_array*)w->output.snapshot)->data,expected,strlen(expected))==0 && dispose(w) && w->usage.payload==0);
 for(int category=0;category<4;++category)for(int delta=-1;delta<=0;++delta){w->usage=(struct usage){0};defaults(&w->limits);if(category==0)w->limits.work=6+delta;if(category==1)w->limits.identities=2+delta;if(category==2)w->limits.llvm=bytes+delta;if(category==3)w->limits.payload=peak+delta;CHECK(begin(w));int ok=frame_data(w,&values,2,3,48);CHECK(ok==(delta==0));if(!ok)CHECK(w->failure.code==1502);CHECK(dispose(w) && w->usage.payload==0);}
 const int invalid[][3]={{0,3,48},{2,0,48},{2,3,7},{INT32_MAX,3,48},{3,3,48},{1,3,48},{-1,3,48}};
 for(size_t i=0;i<sizeof invalid/sizeof invalid[0];++i){w->usage=(struct usage){0};defaults(&w->limits);CHECK(begin(w));observe();CHECK(!frame_data(w,&values,invalid[i][0],invalid[i][1],invalid[i][2]) && w->failure.code==1509 && w->usage.llvm==0 && w->usage.work==0 && clean_cost());CHECK(dispose(w));}
 for(int i=0;i<6;++i){int64_t prior=v[i];v[i]=i?7:INT64_MIN;w->usage=(struct usage){0};CHECK(begin(w));visits=0;CHECK(!frame_data(w,&values,2,3,48) && w->failure.code==1509 && visits==i+1);v[i]=prior;CHECK(dispose(w) && w->usage.payload==0);}
 w->usage=(struct usage){0};CHECK(begin(w));ube_gc_test_fail_next_allocations(1000000);CHECK(!frame_data(w,&values,2,3,48) && w->failure.code!=0);ube_gc_test_fail_next_allocations(0);CHECK(dispose(w) && w->usage.payload==0);
 w->usage=(struct usage){0};CHECK(begin(w) && make_cancel(&w->cancellation));*(bool*)w->cancellation=true;observe();CHECK(!frame_data(w,&values,2,3,48) && w->failure.code==1507 && clean_cost());CHECK(dispose(w));w->cancellation=NULL;
 CHECK(ube_value_try_resize(&values,4097,&frame_scalar_layout,0));v=(int64_t*)((struct ube_array*)values)->data;for(int i=0;i<4097;++i)v[i]=8;
 w->usage=(struct usage){0};CHECK(begin(w) && make_cancel(&w->cancellation));cancel_at_visit=w->cancellation;visits=0;CHECK(!frame_data(w,&values,4095,1,8) && w->failure.code==1507 && visits==4097 && w->usage.work==4096);cancel_at_visit=NULL;CHECK(dispose(w) && w->usage.payload==0);w->cancellation=NULL;
 values=NULL;CHECK(ube_gc_root_leave(&root));return 0;
}
