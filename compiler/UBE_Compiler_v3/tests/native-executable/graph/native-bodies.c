/* Actual checked native-value procedure source; C supplies only transport and independent inventory checks. */
static const char native_source[]=
 "UBE SOURCE 1 MODULE\n"
 "Attribute UBE_Name = \"NativeBodyInput\"\n"
 "Type Octet As Byte\n"
 "End Type\n"
 "Intrinsic Function PackByte(ByVal Bits As Byte) As Octet\n"
 "Attribute PackByte.UBE_Primitive = \"Value.Pack\"\n"
 "End Function\n"
 "Intrinsic Function UnpackByte(ByVal Item As Octet) As Byte\n"
 "Attribute UnpackByte.UBE_Primitive = \"Value.Unpack\"\n"
 "End Function\n"
 "Function BoxByte(ByVal X As Byte) As Octet\n"
 " BoxByte = PackByte(X)\n"
 "End Function\n"
 "Function ReadByte(ByVal X As Octet) As Byte\n"
 " ReadByte = UnpackByte(X)\n"
 "End Function\n"
 "Function EqualByte(ByVal X As Octet, ByVal Y As Octet) As Boolean\n"
 " EqualByte = X = Y\n"
 "End Function\n"
 "Function UnequalByte(ByVal X As Octet, ByVal Y As Octet) As Boolean\n"
 " UnequalByte = X <> Y\n"
 "End Function\n"
 "Function CycleByte(ByVal X As Long) As Long\n"
 " CycleByte = UnpackByte(PackByte(X))\n"
 "End Function\n"
 "Sub WriteByte(ByRef X As Octet, ByVal Y As Byte)\n"
 " X = PackByte(Y)\n"
 "End Sub\n"
 "Type SmallValue As Integer\n"
 "End Type\n"
 "Intrinsic Function PackSmall(ByVal Bits As Integer) As SmallValue\n"
 "Attribute PackSmall.UBE_Primitive = \"Value.Pack\"\n"
 "End Function\n"
 "Intrinsic Function UnpackSmall(ByVal Item As SmallValue) As Integer\n"
 "Attribute UnpackSmall.UBE_Primitive = \"Value.Unpack\"\n"
 "End Function\n"
 "Function BoxSmall(ByVal X As Integer) As SmallValue\n"
 " BoxSmall = PackSmall(X)\n"
 "End Function\n"
 "Function ReadSmall(ByVal X As SmallValue) As Integer\n"
 " ReadSmall = UnpackSmall(X)\n"
 "End Function\n"
 "Function EqualSmall(ByVal X As SmallValue, ByVal Y As SmallValue) As Boolean\n"
 " EqualSmall = X = Y\n"
 "End Function\n"
 "Function UnequalSmall(ByVal X As SmallValue, ByVal Y As SmallValue) As Boolean\n"
 " UnequalSmall = X <> Y\n"
 "End Function\n"
 "Function CycleSmall(ByVal X As Long) As Long\n"
 " CycleSmall = UnpackSmall(PackSmall(X))\n"
 "End Function\n"
 "Sub WriteSmall(ByRef X As SmallValue, ByVal Y As Integer)\n"
 " X = PackSmall(Y)\n"
 "End Sub\n"
 "Type WideValue As Long\n"
 "End Type\n"
 "Intrinsic Function PackWide(ByVal Bits As Long) As WideValue\n"
 "Attribute PackWide.UBE_Primitive = \"Value.Pack\"\n"
 "End Function\n"
 "Intrinsic Function UnpackWide(ByVal Item As WideValue) As Long\n"
 "Attribute UnpackWide.UBE_Primitive = \"Value.Unpack\"\n"
 "End Function\n"
 "Function BoxWide(ByVal X As Long) As WideValue\n"
 " BoxWide = PackWide(X)\n"
 "End Function\n"
 "Function ReadWide(ByVal X As WideValue) As Long\n"
 " ReadWide = UnpackWide(X)\n"
 "End Function\n"
 "Function EqualWide(ByVal X As WideValue, ByVal Y As WideValue) As Boolean\n"
 " EqualWide = X = Y\n"
 "End Function\n"
 "Function UnequalWide(ByVal X As WideValue, ByVal Y As WideValue) As Boolean\n"
 " UnequalWide = X <> Y\n"
 "End Function\n"
 "Function CycleWide(ByVal X As Long) As Long\n"
 " CycleWide = UnpackWide(PackWide(X))\n"
 "End Function\n"
 "Sub WriteWide(ByRef X As WideValue, ByVal Y As Long)\n"
 " X = PackWide(Y)\n"
 "End Sub\n"
 "Sub Main()\n"
 "End Sub\n";
static const char* native_prototypes[]={
 "struct native_byte native_box_byte(uint8_t)",
 "uint8_t native_read_byte(struct native_byte)",
 "bool native_equal_byte(struct native_byte,struct native_byte)",
 "bool native_unequal_byte(struct native_byte,struct native_byte)",
 "int32_t native_cycle_byte(int32_t)",
 "void native_write_byte(struct native_byte*,int32_t,uint8_t)",
 "struct native_small native_box_small(int16_t)",
 "int16_t native_read_small(struct native_small)",
 "bool native_equal_small(struct native_small,struct native_small)",
 "bool native_unequal_small(struct native_small,struct native_small)",
 "int32_t native_cycle_small(int32_t)",
 "void native_write_small(struct native_small*,int32_t,int16_t)",
 "struct native_wide native_box_wide(int32_t)",
 "int32_t native_read_wide(struct native_wide)",
 "bool native_equal_wide(struct native_wide,struct native_wide)",
 "bool native_unequal_wide(struct native_wide,struct native_wide)",
 "int32_t native_cycle_wide(int32_t)",
 "void native_write_wide(struct native_wide*,int32_t,int32_t)",
 "void native_main(void)"};
static int native_body_cases(void) {
 void* bytes=NULL;void* checked=NULL;struct declarations declarations={0};struct plan plan={0};struct body body={0};struct writer w={0};
 struct ube_gc_root roots[15]={{0}};void** owners[]={&bytes,&checked,&declarations.targets,&plan.syntax,&plan.nodes,&plan.arguments,&plan.procedure_roots,&plan.import_marks,&plan.imports,&plan.cursor.frames,&body.values,&body.controls,&w.output.buffer.bytes,&w.output.snapshot,&w.cancellation};
 for(int i=0;i<15;++i)CHECK(ube_gc_root_enter(&roots[i],owners[i]));
 CHECK(ube_value_try_resize(&bytes,(int32_t)strlen(native_source),&ube_file_byte_layout,0));memcpy(data(bytes),native_source,strlen(native_source));
 const int jobs[]={1,2,4};unsigned char* prior=NULL;size_t prior_bytes=0;int64_t prior_work=-1,prior_ids=-1;
 for(int j=0;j<3;++j) {
  struct semantic_failure failure={5,1428,0,0,0,0,0,0};int ok=graph_check(&bytes,jobs[j],&checked,&failure);
  if(!ok)fprintf(stderr,"native source check jobs=%d kind=%d code=%d span=%d..%d\n",jobs[j],failure.kind,failure.code,failure.first,failure.last);
  CHECK(ok && checked);struct result* r=checked;struct module* m=*(struct module**)data(r->modules);CHECK(m && m->value_count>0);
  size_t vb=(size_t)m->value_count*sizeof(struct node),fb=(size_t)m->fact_count*sizeof(struct fact);void* original_values=malloc(vb);void* original_facts=malloc(fb);CHECK(original_values && original_facts);memcpy(original_values,data(m->values),vb);memcpy(original_facts,data(m->facts),fb);
  graph_defaults(&w.limits);w.usage=(struct usage){0};w.failure=(struct failure){1509,0};ube_err_set(77,"prior","native value emission");
  CHECK(writer_begin(&w) && graph_declarations(&checked,&declarations,&w));
  /* One module and Main; per representation one type, two primitive
     declarations/parameters and six ordinary procedures/nine parameters. */
  CHECK(declarations.count==62 && w.usage.work==62);
  CHECK(graph_plan(&checked,0,&declarations,&plan,&w.limits,&w.usage,&w.failure) && body_begin(&body,m->value_count,&w));
  CHECK(plan.argument_count==15);
  struct {int32_t scope,base,count,argument,temporaries;}* links=data(plan.nodes);
  struct {int32_t child,map,conversion,node,written,temporary;}* arguments=data(plan.arguments);
  for(int i=0;i<plan.argument_count;++i)CHECK(arguments[i].node>0 && arguments[i].node<=m->value_count && links[arguments[i].node-1].argument==i+1);
  CHECK(writer_line(&w,"target triple = \"x86_64-w64-windows-gnu\""));
  struct node* nodes=data(m->values);struct target* targets=data(declarations.targets);FILE* header=NULL;
  if(j==0){header=fopen("native-functions.h","wb");CHECK(header);CHECK(fputs("struct native_byte { uint8_t value; };\nstruct native_small { int16_t value; };\nstruct native_wide { int32_t value; };\n",header)>=0);}
  int procedures=0;int64_t emitted_work=0;
  for(int i=0;i<m->value_count;++i)if(nodes[i].kind==101 && targets[nodes[i].target].role==0) {
   int32_t indexed_root=-1;CHECK(graph_root(&plan,targets[nodes[i].target].frame,&indexed_root) && indexed_root==i);
   CHECK(procedures<19);if(header)CHECK(fprintf(header,"extern %s __asm__(\"ube.f%lld\");\n",native_prototypes[procedures],(long long)targets[nodes[i].target].value)>0);
   int64_t before=w.usage.work;w.failure=(struct failure){1509,0};ok=body_emit(&checked,0,i,&body,&declarations,&plan,&w);
   if(!ok)fprintf(stderr,"native procedure=%d node=%d code=%d resource=%d work=%lld\n",procedures,i,w.failure.code,w.failure.resource,(long long)w.usage.work);
   CHECK(ok && body.status==1 && w.usage.pending==0 && w.usage.depth==0);emitted_work+=w.usage.work-before;++procedures;
  }
  CHECK(procedures==19 && body.error && body.overflow==0);if(header)CHECK(fclose(header)==0);
  int live=0;for(int i=0;i<m->value_count;++i)if(links[i].scope){struct node n=nodes[links[i].scope-1];if(n.kind==101 && targets[n.target].role==0)++live;}
  /* Body events, nineteen definitions + twice twenty-seven parameters,
     and the second visit to each of the fifteen intrinsic argument maps. */
  CHECK(emitted_work==3*(int64_t)live-19+73+15);
  CHECK(body.initialization && writer_line(&w,"declare i1 @ube.module.require(i32, i32)") && writer_support(&w) && writer_snapshot(&w));
  CHECK(memcmp(original_values,data(m->values),vb)==0 && memcmp(original_facts,data(m->facts),fb)==0 && ube_err_number()==77);free(original_values);free(original_facts);
  if(j==0){prior_bytes=(size_t)w.output.snapshot_length;prior=malloc(prior_bytes);CHECK(prior);memcpy(prior,data(w.output.snapshot),prior_bytes);FILE* file=fopen("native-bodies.ll","wb");CHECK(file && fwrite(prior,1,prior_bytes,file)==prior_bytes && fclose(file)==0);prior_work=w.usage.work;prior_ids=w.usage.identities;}
  else CHECK((size_t)w.output.snapshot_length==prior_bytes && memcmp(prior,data(w.output.snapshot),prior_bytes)==0 && w.usage.work==prior_work && w.usage.identities==prior_ids);
  CHECK(body_dispose(&body,&w) && graph_dispose(&plan,&w.usage,&w.failure) && graph_release_declarations(&declarations,&w) && writer_dispose(&w) && w.usage.payload==0 && w.usage.pending==0 && w.usage.depth==0);
 }
 free(prior);for(int i=14;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));CHECK(ube_gc_collect() && ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);return 0;
}
