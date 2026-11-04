/* Checked ordinary-call source and independent declaration/work inventory. */
static const char call_source[]=
 "UBE SOURCE 1 MODULE\n"
 "Attribute UBE_Name = \"CallInput\"\n"
 "Dim Calls As Long\n"
 "Type Token As Long\n"
 "End Type\n"
 "Intrinsic Function PackToken(ByVal Bits As Long) As Token\n"
 "Attribute PackToken.UBE_Primitive = \"Value.Pack\"\n"
 "End Function\n"
 "Intrinsic Function UnpackToken(ByVal Item As Token) As Long\n"
 "Attribute UnpackToken.UBE_Primitive = \"Value.Unpack\"\n"
 "End Function\n"
 "Function StepValue(ByRef Trace As Long, ByVal Digit As Long) As Long\n"
 " Trace = Trace * 10 + Digit\n"
 " StepValue = Digit\n"
 "End Function\n"
 "Function Combine(ByVal A As Long, ByVal B As Long, Optional ByVal C As Long = 7) As Long\n"
 " Calls = Calls + 1\n"
 " Combine = A * 100 + B * 10 + C\n"
 "End Function\n"
 "Function Ordered(ByRef Trace As Long) As Long\n"
 " Ordered = Combine(B:=StepValue(Trace, 2), A:=StepValue(Trace, 1))\n"
 "End Function\n"
 "Sub Alter(ByRef X As Long, Optional ByRef Y As Long = 5)\n"
 " X = X + Y\n"
 " Y = 99\n"
 "End Sub\n"
 "Function Temporary(ByRef Original As Long) As Long\n"
 " Call Alter((Original))\n"
 " Temporary = Original\n"
 "End Function\n"
 "Function Repeated() As Long\n"
 " Dim Total As Long = 0\n"
 " Dim I As Long = 0\n"
 " While I < 3\n"
 " Call Alter(Total)\n"
 " I = I + 1\n"
 " Wend\n"
 " Repeated = Total\n"
 "End Function\n"
 "Function Aliased(ByRef X As Long) As Long\n"
 " Call Alter(X, X)\n"
 " Aliased = X\n"
 "End Function\n"
 "Function SetValue(ByRef X As Long) As Long\n"
 " X = 8\n"
 " SetValue = 1\n"
 "End Function\n"
 "Function ReadWith(ByRef X As Long, ByVal Ignored As Long) As Long\n"
 " ReadWith = X\n"
 "End Function\n"
 "Function AliasOrder(ByRef X As Long) As Long\n"
 " AliasOrder = ReadWith(X, SetValue(X))\n"
 "End Function\n"
 "Function NativeEcho(ByVal X As Token) As Token\n"
 " NativeEcho = X\n"
 "End Function\n"
 "Function NativeRound(ByVal X As Long) As Long\n"
 " NativeRound = UnpackToken(NativeEcho(PackToken(X)))\n"
 "End Function\n"
 "Function Recursive(ByVal N As Long) As Long\n"
 " If N <= 0 Then\n"
 " Recursive = 1\n"
 " Else\n"
 " Recursive = N * Recursive(N - 1)\n"
 " End If\n"
 "End Function\n"
 "Function NarrowArgument(ByVal X As Long, ByRef Trace As Long) As Long\n"
 " NarrowArgument = ByteTarget(X, FaultValue(Trace))\n"
 "End Function\n"
 "Function ByteTarget(ByVal X As Byte, ByVal Y As Long) As Long\n"
 " ByteTarget = X + Y\n"
 "End Function\n"
 "Function FaultValue(ByRef Trace As Long) As Long\n"
 " Trace = Trace + 1\n"
 " Dim Zero As Long = 0\n"
 " FaultValue = 9 \\ Zero\n"
 "End Function\n"
 "Function RefusalEffects(ByRef Trace As Long) As Long\n"
 " RefusalEffects = Combine(StepValue(Trace, 1), StepValue(Trace, 2), StepValue(Trace, 3))\n"
 "End Function\n"
 "Function CallCount() As Long\n"
 " CallCount = Calls\n"
 "End Function\n"
 "Sub ResetCalls()\n"
 " Calls = 0\n"
 "End Sub\n"
 "Sub Main()\n"
 "End Sub\n"
 "Function GlobalAlias() As Long\n"
 " GlobalAlias = StepValue(Calls, 4)\n"
 "End Function\n"
 "Function ByValAlias(ByVal X As Long) As Long\n"
 " Call Alter(X)\n"
 " ByValAlias = X\n"
 "End Function\n"
 "Function NamedAlias() As Long\n"
 " Dim TempValue As Long = 2\n"
 " Call Alter(Y:=TempValue, X:=Calls)\n"
 " NamedAlias = Calls * 100 + TempValue\n"
 "End Function\n"
 "Function RecursiveAlias(ByRef X As Long, ByVal N As Long) As Long\n"
 " If N > 0 Then\n"
 " RecursiveAlias = RecursiveAlias(X, N - 1)\n"
 " Else\n"
 " RecursiveAlias = StepValue(X, 3)\n"
 " End If\n"
 "End Function\n";
static const char* call_prototypes[]={
 "int32_t call_step(int32_t*,int32_t,int32_t)",
 "int32_t call_combine(int32_t,int32_t,int32_t)",
 "int32_t call_ordered(int32_t*,int32_t)",
 "void call_alter(int32_t*,int32_t,int32_t*,int32_t)",
 "int32_t call_temporary(int32_t*,int32_t)",
 "int32_t call_repeated(void)",
 "int32_t call_aliased(int32_t*,int32_t)",
 "int32_t call_set(int32_t*,int32_t)",
 "int32_t call_read(int32_t*,int32_t,int32_t)",
 "int32_t call_alias_order(int32_t*,int32_t)",
 "struct call_native call_echo(struct call_native)",
 "int32_t call_round(int32_t)",
 "int32_t call_recursive(int32_t)",
 "int32_t call_narrow(int32_t,int32_t*,int32_t)",
 "int32_t call_byte(uint8_t,int32_t)",
 "int32_t call_fault(int32_t*,int32_t)",
 "int32_t call_effects(int32_t*,int32_t)",
 "int32_t call_count(void)",
 "void call_reset(void)",
 "void call_main(void)",
 "int32_t call_global_alias(void)",
 "int32_t call_byval_alias(int32_t)",
 "int32_t call_named_alias(void)",
 "int32_t call_recursive_alias(int32_t*,int32_t,int32_t)"};
static int call_body_cases(void) {
 void* bytes=NULL;void* checked=NULL;struct declarations declarations={0};struct plan plan={0};struct body body={0};struct writer w={0};
 struct ube_gc_root roots[15]={{0}};void** owners[]={&bytes,&checked,&declarations.targets,&plan.syntax,&plan.nodes,&plan.arguments,&plan.procedure_roots,&plan.import_marks,&plan.imports,&plan.cursor.frames,&body.values,&body.controls,&w.output.buffer.bytes,&w.output.snapshot,&w.cancellation};
 for(int i=0;i<15;++i)CHECK(ube_gc_root_enter(&roots[i],owners[i]));
 CHECK(ube_value_try_resize(&bytes,(int32_t)strlen(call_source),&ube_file_byte_layout,0));memcpy(data(bytes),call_source,strlen(call_source));
 const int jobs[]={1,2,4};unsigned char* prior=NULL;size_t prior_bytes=0;int64_t prior_work=-1,prior_ids=-1;
 for(int j=0;j<3;++j) {
  struct semantic_failure failure={5,1428,0,0,0,0,0,0};int ok=graph_check(&bytes,jobs[j],&checked,&failure);
  if(!ok)fprintf(stderr,"call source check jobs=%d kind=%d code=%d span=%d..%d\n",jobs[j],failure.kind,failure.code,failure.first,failure.last);
  CHECK(ok && checked);struct result* r=checked;struct module* m=*(struct module**)data(r->modules);CHECK(m && m->value_count>0);
  size_t vb=(size_t)m->value_count*sizeof(struct node),fb=(size_t)m->fact_count*sizeof(struct fact);void* original_values=malloc(vb);void* original_facts=malloc(fb);CHECK(original_values && original_facts);memcpy(original_values,data(m->values),vb);memcpy(original_facts,data(m->facts),fb);
  graph_defaults(&w.limits);w.usage=(struct usage){0};w.failure=(struct failure){1509,0};ube_err_set(77,"prior","call emission");
  CHECK(writer_begin(&w) && graph_declarations(&checked,&declarations,&w));
  /* One module/global/native type, two primitive declarations/parameters,
     twenty-four ordinary procedures, twenty-six parameters and four locals. */
  CHECK(declarations.count==61 && declarations.frames==24 && w.usage.work==61);
  CHECK(graph_plan(&checked,0,&declarations,&plan,&w.limits,&w.usage,&w.failure) && body_begin(&body,m->value_count,&w));
  CHECK(plan.argument_count==42);
  struct {int32_t scope,base,count,argument,temporaries;}* links=data(plan.nodes);
  struct {int32_t child,map,conversion,node,written,temporary;}* arguments=data(plan.arguments);
  for(int i=0;i<plan.argument_count;++i)CHECK(arguments[i].node>0 && arguments[i].node<=m->value_count && links[arguments[i].node-1].argument==i+1);
  CHECK(writer_line(&w,"target triple = \"x86_64-w64-windows-gnu\""));
  struct node* nodes=data(m->values);struct target* targets=data(declarations.targets);FILE* header=NULL;
  if(j==0){header=fopen("call-functions.h","wb");CHECK(header);CHECK(fputs("struct call_native { int32_t value; };\n#define CALL_FRAME_COUNT 26\n",header)>=0);}
  int temporary_count=0;for(int i=0;i<m->value_count;++i)temporary_count+=links[i].temporaries;CHECK(temporary_count==4);
  int globals=0;for(int i=0;i<declarations.count;++i)if(targets[i].kind==2 && targets[i].scope==0){CHECK(writer_storage(&w,&targets[i],1));++globals;}CHECK(globals==1);
  int procedures=0;int64_t emitted_work=0;
  for(int i=0;i<m->value_count;++i)if(nodes[i].kind==101 && targets[nodes[i].target].role==0) {
   int32_t indexed_root=-1;CHECK(graph_root(&plan,targets[nodes[i].target].frame,&indexed_root) && indexed_root==i);
   CHECK(procedures<24 && targets[nodes[i].target].frame==procedures);if(header)CHECK(fprintf(header,"extern %s __asm__(\"ube.f%lld\");\n",call_prototypes[procedures],(long long)targets[nodes[i].target].value)>0);
   int64_t before=w.usage.work;w.failure=(struct failure){1509,0};ok=body_emit(&checked,0,i,&body,&declarations,&plan,&w);
   if(!ok)fprintf(stderr,"call procedure=%d node=%d code=%d resource=%d work=%lld\n",procedures,i,w.failure.code,w.failure.resource,(long long)w.usage.work);
   CHECK(ok && body.status==1 && w.usage.pending==0 && w.usage.depth==0);emitted_work+=w.usage.work-before;++procedures;
  }
  CHECK(procedures==24 && body.error && body.overflow!=0 && body.calls);if(header)CHECK(fclose(header)==0);
  int live=0;for(int i=0;i<m->value_count;++i)if(links[i].scope){struct node n=nodes[links[i].scope-1];if(n.kind==101 && targets[n.target].role==0)++live;}
  /* Body events, 24 definitions + twice 26 parameters + four locals,
     and the second visit to 42 maps; the ByRef companion adds no visits. */
  CHECK(emitted_work==3*(int64_t)live-24+80+42);
  CHECK(body.initialization && writer_line(&w,"declare i1 @ube.module.require(i32, i32)") && writer_stack(&w,declarations.frames+2) && writer_overflow(&w,body.overflow) && writer_support(&w) && writer_snapshot(&w));
  CHECK(memcmp(original_values,data(m->values),vb)==0 && memcmp(original_facts,data(m->facts),fb)==0 && ube_err_number()==77);free(original_values);free(original_facts);
  if(j==0){prior_bytes=(size_t)w.output.snapshot_length;prior=malloc(prior_bytes);CHECK(prior);memcpy(prior,data(w.output.snapshot),prior_bytes);FILE* file=fopen("call-bodies.ll","wb");CHECK(file && fwrite(prior,1,prior_bytes,file)==prior_bytes && fclose(file)==0);prior_work=w.usage.work;prior_ids=w.usage.identities;}
  else CHECK((size_t)w.output.snapshot_length==prior_bytes && memcmp(prior,data(w.output.snapshot),prior_bytes)==0 && w.usage.work==prior_work && w.usage.identities==prior_ids);
  CHECK(body_dispose(&body,&w) && graph_dispose(&plan,&w.usage,&w.failure) && graph_release_declarations(&declarations,&w) && writer_dispose(&w) && w.usage.payload==0 && w.usage.pending==0 && w.usage.depth==0);
 }
 free(prior);for(int i=14;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));CHECK(ube_gc_collect() && ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);return 0;
}
