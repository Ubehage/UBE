/* Real three-source checker results; one test-only combined unit avoids making
   any claim about the still-pending per-module import/output consumer. */
extern int32_t graph_project(void**,int32_t,void**,struct semantic_failure*);
extern int32_t writer_initialization(struct writer*,int32_t,int32_t),writer_initialization_data(struct writer*,int32_t);
extern int32_t graph_schedule(void**,struct writer*);
static int guard_body_cases(const char* path,int reference) {
 void* bytes=NULL;void* checked=NULL;struct declarations declarations={0};struct plan plan={0};struct body body={0};struct writer w={0};
 struct ube_gc_root roots[15]={{0}};void** owners[]={&bytes,&checked,&declarations.targets,&plan.syntax,&plan.nodes,&plan.arguments,&plan.procedure_roots,&plan.import_marks,&plan.imports,&plan.cursor.frames,&body.values,&body.controls,&w.output.buffer.bytes,&w.output.snapshot,&w.cancellation};
 for(int i=0;i<15;++i)CHECK(ube_gc_root_enter(&roots[i],owners[i]));
 CHECK(ube_value_try_resize(&bytes,(int32_t)strlen(path),&ube_file_byte_layout,0));memcpy(data(bytes),path,strlen(path));
 const char* globals[]={"guard_events","guard_first","guard_tail","guard_value","guard_initializations","guard_dependency","guard_calls","guard_cvalue","guard_cinitializations"};
 const char* prototypes[]={"int32_t guard_mark(int32_t)","int32_t guard_read(void)","void guard_write(void)","int32_t guard_call(void)","struct guard_native guard_native(void)","int32_t guard_alias_read(int32_t*,int32_t)","void guard_alias_write(int32_t*,int32_t)","int32_t guard_forward_read(int32_t*,int32_t)","int32_t guard_unused(int32_t*,int32_t)","int32_t guard_forward_unused(int32_t*,int32_t)","int32_t guard_unused_global(void)","int32_t guard_main(void)","int32_t guard_bread(void)","int32_t guard_accept(int32_t)"};
 unsigned char* prior=NULL;size_t prior_bytes=0;int64_t prior_work=-1,prior_ids=-1;const int jobs[]={1,2,4};
 for(int j=0;j<3;++j) {
  struct semantic_failure failure={0};int ok=graph_project(&bytes,jobs[j],&checked,&failure);
  if(!ok)fprintf(stderr,"guard check jobs=%d code=%d source=%d span=%d..%d\n",jobs[j],failure.code,failure.source,failure.first,failure.last);
  CHECK(ok && checked);struct result* r=checked;CHECK(((struct ube_array*)r->modules)->lower==0 && ((struct ube_array*)r->modules)->upper==2);
  graph_defaults(&w.limits);w.usage=(struct usage){0};w.failure=(struct failure){1509,0};ube_err_set(77,"prior","guard body emission");
  CHECK(writer_begin(&w) && graph_declarations(&checked,&declarations,&w));CHECK(declarations.frames==14);
  /* Fault only scalar metadata in this private fixture, restore immediately;
     malformed counts must fail before indexing an owner or emitting bytes. */
  struct catalog_prefix {void* syntax;void* sources;int32_t source_count,package_count;};
  struct catalog_prefix* catalog=r->catalog;CHECK(catalog->source_count==3 && catalog->package_count==(reference?2:1));
  int64_t checked_work=w.usage.work,checked_ids=w.usage.identities;
  for(int fault=0;fault<4;++fault){int32_t old_sources=catalog->source_count,old_packages=catalog->package_count;if(fault==0)catalog->source_count=0;if(fault==1)catalog->source_count=4;if(fault==2)catalog->package_count=0;if(fault==3)catalog->package_count=3;int accepted=graph_schedule(&checked,&w);catalog->source_count=old_sources;catalog->package_count=old_packages;CHECK(!accepted && w.failure.code==1509 && w.output.length==0 && w.usage.work==checked_work && w.usage.identities==checked_ids);}
  struct target* targets=data(declarations.targets);FILE* header=NULL;
  if(j==0 && !reference){header=fopen("guard-functions.h","wb");CHECK(header);CHECK(fputs("struct guard_native {int32_t value;};\n#define GUARD_FRAMES 18\n#define GUARD_C_FRAME 16\nextern bool guard_start(int32_t),guard_schedule(void);\n",header)>=0);}
  CHECK(writer_line(&w,"target triple = \"x86_64-w64-windows-gnu\""));int globals_seen=0,procedures_seen=0,overflow=0;
  for(int source=0;source<3;++source) {
   struct module* m=((struct module**)data(r->modules))[source];CHECK(m && m->source==source);
   size_t vb=(size_t)m->value_count*sizeof(struct node),fb=(size_t)m->fact_count*sizeof(struct fact);void* saved_values=malloc(vb);void* saved_facts=malloc(fb);CHECK(saved_values && saved_facts);memcpy(saved_values,data(m->values),vb);memcpy(saved_facts,data(m->facts),fb);
   CHECK(graph_plan(&checked,source,&declarations,&plan,&w.limits,&w.usage,&w.failure) && body_begin(&body,m->value_count,&w));
   for(int d=0;d<declarations.count;++d)if(targets[d].kind==2 && targets[d].scope<3 && targets[d].source==source){CHECK(globals_seen<9 && writer_storage(&w,&targets[d],3));if(header)CHECK(fprintf(header,"extern int32_t %s __asm__(\"ube.g%lld\");\n",globals[globals_seen],(long long)targets[d].address)>0);++globals_seen;}
   struct node* nodes=data(m->values);
   for(int i=0;i<plan.procedure_count;++i){int32_t node=-1;CHECK(graph_root(&plan,plan.first_frame+i,&node));CHECK(procedures_seen<14);if(header)CHECK(fprintf(header,"extern %s __asm__(\"ube.f%lld\");\n",prototypes[procedures_seen],(long long)targets[nodes[node].target].value)>0);CHECK(body_emit(&checked,source,node,&body,&declarations,&plan,&w));++procedures_seen;}
   CHECK(body_initializer(&checked,source,&body,&declarations,&plan,&w));overflow|=body.overflow;
   CHECK(memcmp(saved_values,data(m->values),vb)==0 && memcmp(saved_facts,data(m->facts),fb)==0 && ube_err_number()==77);free(saved_values);free(saved_facts);
   CHECK(body_dispose(&body,&w) && graph_dispose(&plan,&w.usage,&w.failure) && w.usage.pending==0 && w.usage.depth==0);
  }
  int64_t schedule_work=w.usage.work,schedule_ids=w.usage.identities;CHECK(graph_schedule(&checked,&w) && w.usage.work-schedule_work==6 && w.usage.identities-schedule_ids==9);
  CHECK(globals_seen==9 && procedures_seen==14 && writer_stack(&w,18) && writer_initialization(&w,3,14) && writer_overflow(&w,overflow) && writer_support(&w));
  CHECK(writer_line(&w,"define i1 @guard_start(i32 %owner) {\nentry:\n  %ok = call i1 @ube.module.require(i32 %owner, i32 -1)\n  ret i1 %ok\n}"));
  CHECK(writer_line(&w,"define i1 @guard_schedule() {\n %ok = call i1 @ube.module.initialize()\n ret i1 %ok\n}"));
  CHECK(writer_snapshot(&w));
  const unsigned char* schedule_bytes=data(w.output.snapshot);for(int i=0;i<3;++i){char expected[120];snprintf(expected,sizeof expected,"%%initialized%d = call i1 @ube.module.require(i32 %d, i32 -1)",i,reference?(i+1)%3:i);size_t length=strlen(expected);bool found=false;for(size_t at=0;at+length<=(size_t)w.output.snapshot_length;++at)if(memcmp(schedule_bytes+at,expected,length)==0){found=true;break;}CHECK(found);}
  if(header)CHECK(fclose(header)==0);
  if(j==0){prior_bytes=(size_t)w.output.snapshot_length;prior=malloc(prior_bytes);CHECK(prior);memcpy(prior,data(w.output.snapshot),prior_bytes);FILE* file=fopen(reference?"guard-reference-bodies.ll":"guard-bodies.ll","wb");CHECK(file && fwrite(prior,1,prior_bytes,file)==prior_bytes && fclose(file)==0);prior_work=w.usage.work;prior_ids=w.usage.identities;}
  else CHECK((size_t)w.output.snapshot_length==prior_bytes && memcmp(prior,data(w.output.snapshot),prior_bytes)==0 && w.usage.work==prior_work && w.usage.identities==prior_ids);
  CHECK(graph_release_declarations(&declarations,&w) && writer_dispose(&w) && w.usage.payload==0);
 }
 free(prior);graph_defaults(&w.limits);w.usage=(struct usage){0};CHECK(writer_begin(&w) && writer_line(&w,"target triple = \"x86_64-w64-windows-gnu\"") && writer_initialization_data(&w,3) && writer_snapshot(&w));FILE* file=fopen("guard-data.ll","wb");CHECK(file && fwrite(data(w.output.snapshot),1,(size_t)w.output.snapshot_length,file)==(size_t)w.output.snapshot_length && fclose(file)==0);CHECK(writer_dispose(&w) && w.usage.payload==0);
 for(int i=14;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));CHECK(ube_gc_collect() && ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);return 0;
}
