extern int32_t body_initializer(void**,int32_t,struct body*,struct declarations*,struct plan*,struct writer*);
static const char initializer_source[]=
 "UBE SOURCE 1 MODULE\nAttribute UBE_Name = \"InitializerInput\"\n"
 "Public Events As Long = 0\nPublic First As Long = PrepareValue()\nPublic Later As Long = Later + 1\n"
 "Public Quotient As Long = 10 \\ ZeroValue()\nPublic Forced As Long = Touch((Later))\nPublic Defaulted As Long = Touch()\nPublic Snapshot As Long = Events\n"
 "Public Function PrepareValue() As Long\n Later = 8\n Events = Events * 10 + 1\n PrepareValue = 4\nEnd Function\n"
 "Public Function ZeroValue() As Long\n Events = Events * 10 + 2\n ZeroValue = 0\nEnd Function\n"
 "Public Function Touch(Optional ByRef Value As Long = 3) As Long\n Events = Events * 10 + 3\n Value = Value + 2\n Touch = Value\nEnd Function\n"
 "Function Main() As Long\n Main = First * 10000 + Later * 1000 + Forced * 100 + Defaulted * 10 + Quotient\nEnd Function\n";
static int initializer_body_cases(void) {
 void* bytes=NULL;void* checked=NULL;struct declarations declarations={0};struct plan plan={0};struct body body={0};struct writer w={0};
 struct ube_gc_root roots[15]={{0}};void** owners[]={&bytes,&checked,&declarations.targets,&plan.syntax,&plan.nodes,&plan.arguments,&plan.procedure_roots,&plan.import_marks,&plan.imports,&plan.cursor.frames,&body.values,&body.controls,&w.output.buffer.bytes,&w.output.snapshot,&w.cancellation};
 for(int i=0;i<15;++i)CHECK(ube_gc_root_enter(&roots[i],owners[i]));
 CHECK(ube_value_try_resize(&bytes,(int32_t)strlen(initializer_source),&ube_file_byte_layout,0));memcpy(data(bytes),initializer_source,strlen(initializer_source));
 const char* global_names[]={"init_events","init_first","init_later","init_quotient","init_forced","init_defaulted","init_snapshot"};
 const int jobs[]={1,2,4};unsigned char* prior=NULL;size_t prior_bytes=0;int64_t prior_work=-1,prior_ids=-1;
 for(int j=0;j<3;++j) {
  struct semantic_failure failure={5,1428,0,0,0,0,0,0};int ok=graph_check(&bytes,jobs[j],&checked,&failure);
  if(!ok)fprintf(stderr,"initializer source jobs=%d code=%d span=%d..%d\n",jobs[j],failure.code,failure.first,failure.last);
  CHECK(ok && checked);struct result* r=checked;struct module* m=*(struct module**)data(r->modules);CHECK(m && m->value_count>0);
  size_t vb=(size_t)m->value_count*sizeof(struct node),fb=(size_t)m->fact_count*sizeof(struct fact);void* saved_values=malloc(vb);void* saved_facts=malloc(fb);CHECK(saved_values && saved_facts);memcpy(saved_values,data(m->values),vb);memcpy(saved_facts,data(m->facts),fb);
  graph_defaults(&w.limits);w.usage=(struct usage){0};w.failure=(struct failure){1509,0};ube_err_set(77,"prior","initializer emission");
  CHECK(writer_begin(&w) && graph_declarations(&checked,&declarations,&w));CHECK(declarations.count==13 && declarations.frames==4 && w.usage.work==13);
  CHECK(graph_plan(&checked,0,&declarations,&plan,&w.limits,&w.usage,&w.failure) && body_begin(&body,m->value_count,&w));CHECK(plan.procedure_count==4 && plan.first_frame==0 && plan.argument_count==2);
  struct node* nodes=data(m->values);struct target* targets=data(declarations.targets);struct {int32_t scope,base,count,argument,temporaries;}* links=data(plan.nodes);
  CHECK(links[m->root].temporaries==2);CHECK(writer_line(&w,"target triple = \"x86_64-w64-windows-gnu\""));
  FILE* header=NULL;if(j==0){header=fopen("initializer-functions.h","wb");CHECK(header);CHECK(fputs("extern bool checked_initializer(void) __asm__(\"ube.module.init0\");\n",header)>=0);}
  int globals=0;for(int d=0;d<declarations.count;++d)if(targets[d].kind==2 && targets[d].scope==0){CHECK(globals<7 && writer_storage(&w,&targets[d],1));if(header)CHECK(fprintf(header,"extern int32_t %s __asm__(\"ube.g%lld\");\n",global_names[globals],(long long)targets[d].address)>0);++globals;}CHECK(globals==7);
  for(int frame=0;frame<4;++frame){int32_t node=-1;CHECK(graph_root(&plan,frame,&node) && node>=0 && nodes[node].kind==101 && targets[nodes[node].target].frame==frame);CHECK(body_emit(&checked,0,node,&body,&declarations,&plan,&w));if(header && frame==3)CHECK(fprintf(header,"extern int32_t initializer_main(void) __asm__(\"ube.f%lld\");\n",(long long)targets[nodes[node].target].value)>0);}
  int initializer_nodes=0;for(int n=0;n<m->value_count;++n)if(links[n].scope==m->root+1)++initializer_nodes;
  /* 2V enter/exit + V-1 initializer-tree edges + four deferred procedure
     edges + one definition visit + two emitted argument maps. */
  int64_t required=3*(int64_t)initializer_nodes+6;int64_t before=w.usage.work;
  CHECK(body_initializer(&checked,0,&body,&declarations,&plan,&w) && body.status==1 && body.temporary_count==2 && w.usage.work-before==required && w.usage.pending==0 && w.usage.depth==0);
  CHECK(body.calls && body.error && body.initialization && writer_line(&w,"declare i1 @ube.module.require(i32, i32)") && writer_stack(&w,6) && writer_overflow(&w,body.overflow) && writer_support(&w) && writer_snapshot(&w));
  CHECK(memcmp(saved_values,data(m->values),vb)==0 && memcmp(saved_facts,data(m->facts),fb)==0 && ube_err_number()==77);free(saved_values);free(saved_facts);
  if(header)CHECK(fclose(header)==0);
  if(j==0){prior_bytes=(size_t)w.output.snapshot_length;prior=malloc(prior_bytes);CHECK(prior);memcpy(prior,data(w.output.snapshot),prior_bytes);FILE* file=fopen("initializer-bodies.ll","wb");CHECK(file && fwrite(prior,1,prior_bytes,file)==prior_bytes && fclose(file)==0);prior_work=w.usage.work;prior_ids=w.usage.identities;}
  else CHECK((size_t)w.output.snapshot_length==prior_bytes && memcmp(prior,data(w.output.snapshot),prior_bytes)==0 && w.usage.work==prior_work && w.usage.identities==prior_ids);
  CHECK(body_dispose(&body,&w) && graph_dispose(&plan,&w.usage,&w.failure) && graph_release_declarations(&declarations,&w) && writer_dispose(&w) && w.usage.payload==0 && w.usage.pending==0 && w.usage.depth==0);
  if(j==0){const int64_t caps[]={0,1,2,required-1,required,required+1};for(int c=0;c<6;++c){
    graph_defaults(&w.limits);w.usage=(struct usage){0};w.failure=(struct failure){1509,0};
    CHECK(writer_begin(&w) && graph_declarations(&checked,&declarations,&w) && graph_plan(&checked,0,&declarations,&plan,&w.limits,&w.usage,&w.failure) && body_begin(&body,m->value_count,&w));
    int64_t initial=w.usage.work;w.limits.work=initial+caps[c];int emitted=body_initializer(&checked,0,&body,&declarations,&plan,&w);
    if(caps[c]<required)CHECK(!emitted && body.status==4 && w.failure.code==1502 && w.failure.resource==5 && w.usage.work==w.limits.work);
    else CHECK(emitted && body.status==1 && w.failure.code==0 && w.usage.work==initial+required);
    CHECK(w.usage.pending==plan.cursor.count && w.usage.depth==plan.cursor.count);
    CHECK(body_dispose(&body,&w) && graph_dispose(&plan,&w.usage,&w.failure) && graph_release_declarations(&declarations,&w) && writer_dispose(&w) && w.usage.payload==0 && w.usage.pending==0 && w.usage.depth==0);
  }}
 }
 free(prior);for(int i=14;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));CHECK(ube_gc_collect() && ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);return 0;
}
