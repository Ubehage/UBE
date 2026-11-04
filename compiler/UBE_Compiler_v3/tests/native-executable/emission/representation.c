extern int32_t ll_representation(struct ll_writer*,int32_t,struct ll_type*,int32_t,struct ll_operand*,struct ll_operand*);
static int representation_cases(void) {
 struct ll_writer w={0};em_defaults(&w.limits);struct ube_gc_root roots[3]={{0}};
 CHECK(ube_gc_root_enter(&roots[0],&w.output.buffer.bytes) && ube_gc_root_enter(&roots[1],&w.output.snapshot) && ube_gc_root_enter(&roots[2],&w.cancellation));
 w.failure=(struct em_failure){1509,0};CHECK(ll_begin(&w));ube_err_set(77,"prior","representation");
 const int64_t low[]={0,0,0,INT16_MIN,INT32_MIN},high[]={0,0,255,INT16_MAX,INT32_MAX};
 for(int rep=2;rep<=4;++rep)for(int upper=0;upper<=1;++upper) {
  struct ll_type type={0};type.kind=3;type.representation=rep;
  struct ll_operand value={1,rep,rep,upper?high[rep]:low[rep]},boxed={0};observe();
  CHECK(ll_representation(&w,1,&type,10,&value,&boxed) && boxed.kind==1 && boxed.type==10 && boxed.representation==rep && boxed.value==value.value);
  CHECK(ll_representation(&w,2,&type,10,&boxed,&boxed) && boxed.kind==1 && boxed.type==rep && boxed.value==value.value && w.output.length==0 && clean_cost());
 }
 struct ll_type type={0};type.kind=3;type.representation=3;
 struct ll_operand value={2,3,3,11},result={2,5,5,123};
 for(int defect=0;defect<6;++defect) {
  struct ll_type invalid=type;struct ll_operand original=value;int role=1,native=10;
  if(defect==0)role=3;if(defect==1)native=5;if(defect==2)invalid.kind=2;if(defect==3)invalid.representation=5;if(defect==4)original.type=10;if(defect==5)original.kind=0;
  observe();CHECK(!ll_representation(&w,role,&invalid,native,&original,&result) && w.failure.code==1509 && result.value==123 && result.type==5 && w.output.length==0 && clean_cost());
 }
 struct tr_node node={0};node.kind=5;node.children=2;node.type=1;node.auxiliary=15;
 struct ll_operand left={2,10,3,7},right={2,11,3,8};int32_t support=0;bool error=false;
 CHECK(!ll_binary(&w,&node,&type,&left,&right,&result,&support,&error) && w.failure.code==1509 && result.value==123 && w.output.length==0);
 right.type=10;node.auxiliary=17;
 CHECK(!ll_binary(&w,&node,&type,&left,&right,&result,&support,&error) && w.failure.code==1509 && result.value==123 && w.output.length==0);
 CHECK(ll_dispose(&w));
 for(int category=0;category<2;++category) {
  em_defaults(&w.limits);w.usage=(struct em_usage){0};if(category==0)w.limits.identities=0;else w.limits.llvm=0;
  CHECK(ll_begin(&w));
  CHECK(!ll_representation(&w,1,&type,10,&value,&result) && w.failure.code==1502 && w.failure.resource==(category==0?3:2) && result.value==123 && w.output.length==0);
  CHECK(ll_dispose(&w) && w.usage.payload==0);
 }
 em_defaults(&w.limits);w.usage=(struct em_usage){0};CHECK(ll_begin(&w));
 CHECK(ll_representation(&w,1,&type,10,&value,&result) && result.kind==2 && result.type==10 && result.value==0);
 CHECK(ll_representation(&w,2,&type,10,&result,&result) && result.kind==2 && result.type==3 && result.value==1);
 const char expected[]="  %v0 = insertvalue { i16 } zeroinitializer, i16 %v11, 0\n  %v1 = extractvalue { i16 } %v0, 0\n";
 CHECK(ll_snapshot(&w) && w.output.snapshot_length==(int32_t)strlen(expected) && memcmp(gr_data(w.output.snapshot),expected,strlen(expected))==0 && ube_err_number()==77 && !error && support==0);
 CHECK(ll_dispose(&w) && w.usage.payload==0);for(int i=2;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));
 CHECK(ube_gc_collect() && ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);return 0;
}
