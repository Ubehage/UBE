/* Separate LLVM outputs from the production module consumer. The independent
   runtime oracle is shared with combined-unit tests; no body text is split. */
extern int32_t body_module(void**,int32_t,struct body*,struct declarations*,struct plan*,struct writer*);
extern int32_t writer_imports(struct declarations*,struct plan*,int32_t,int32_t,struct writer*);
extern int32_t writer_release(struct output*,struct usage*,struct failure*);
static int module_body_cases(const char* path,int reference) {
 void* bytes=NULL;void* checked=NULL;struct declarations declarations={0};struct plan plan={0};struct body body={0};struct writer w={0};
 struct ube_gc_root roots[15]={{0}};void** owners[]={&bytes,&checked,&declarations.targets,&plan.syntax,&plan.nodes,&plan.arguments,&plan.procedure_roots,&plan.import_marks,&plan.imports,&plan.cursor.frames,&body.values,&body.controls,&w.output.buffer.bytes,&w.output.snapshot,&w.cancellation};
 for(int i=0;i<15;++i)CHECK(ube_gc_root_enter(&roots[i],owners[i]));
 CHECK(ube_value_try_resize(&bytes,(int32_t)strlen(path),&ube_file_byte_layout,0));memcpy(data(bytes),path,strlen(path));
 unsigned char* prior[4]={0};size_t lengths[4]={0};int64_t prior_work=-1,prior_ids=-1;const int jobs[]={1,2,4};
 for(int j=0;j<3;++j) {
  struct semantic_failure failure={0};CHECK(graph_project(&bytes,jobs[j],&checked,&failure));struct result* r=checked;
  graph_defaults(&w.limits);w.usage=(struct usage){0};CHECK(writer_begin(&w) && graph_declarations(&checked,&declarations,&w));
  CHECK(writer_snapshot(&w) && writer_release(&w.output,&w.usage,&w.failure));
  struct target* targets=data(declarations.targets);int imports=0;
  for(int source=0;source<4;++source) {
   CHECK(writer_begin(&w));ube_err_set(77,"prior","module emission");
   if(source<3) {
    struct module* m=((struct module**)data(r->modules))[source];CHECK(m && m->source==source);
    CHECK(graph_plan(&checked,source,&declarations,&plan,&w.limits,&w.usage,&w.failure) && body_begin(&body,m->value_count,&w));
    /* The independent expected set comes from checked node references and
       declaration ownership, not the production plan's marks or list. */
    bool* seen=calloc((size_t)declarations.count,sizeof(bool));CHECK(seen);int count=0,visits=0;struct node* nodes=data(m->values);
    for(int n=0;n<m->value_count;++n) {
     int kind=nodes[n].kind,id=nodes[n].target;if(kind!=3 && kind!=6 && kind!=104)continue;
     CHECK(id>=0 && id<declarations.count);struct target* t=&targets[id];
     bool needed=t->source!=source && ((kind==6 && (t->kind==5 || t->kind==6) && t->role==0) || (kind!=6 && t->kind==2 && t->scope>=0 && t->scope<3));
     if(needed && !seen[id]){seen[id]=true;++count;visits+=1+(kind==6?t->parameter_count:0);}
    }
    CHECK(count==plan.import_count);for(int i=0;i<plan.import_count;++i){int id=((int32_t*)data(plan.imports))[i]-1;CHECK(id>=0 && id<declarations.count && seen[id]);seen[id]=false;}free(seen);
    int64_t before=w.usage.work;CHECK(writer_imports(&declarations,&plan,source,3,&w) && w.usage.work-before==visits);imports+=visits;
    CHECK(writer_snapshot(&w) && writer_release(&w.output,&w.usage,&w.failure) && writer_begin(&w));
    CHECK(body_module(&checked,source,&body,&declarations,&plan,&w));
    CHECK(body_dispose(&body,&w) && graph_dispose(&plan,&w.usage,&w.failure) && w.usage.pending==0 && w.usage.depth==0);
   }else{
    CHECK(writer_line(&w,"target triple = \"x86_64-w64-windows-gnu\"") && graph_schedule(&checked,&w));
    CHECK(writer_stack(&w,18) && writer_initialization(&w,3,14) && writer_support(&w));
    CHECK(writer_line(&w,"define i1 @guard_start(i32 %owner) {\n %ok = call i1 @ube.module.require(i32 %owner, i32 -1)\n ret i1 %ok\n}"));
    CHECK(writer_line(&w,"define i1 @guard_schedule() {\n %ok = call i1 @ube.module.initialize()\n ret i1 %ok\n}"));
   }
   CHECK(writer_snapshot(&w) && ube_err_number()==77);
   if(j==0){lengths[source]=(size_t)w.output.snapshot_length;prior[source]=malloc(lengths[source]);CHECK(prior[source]);memcpy(prior[source],data(w.output.snapshot),lengths[source]);char name[80];snprintf(name,sizeof name,"module-%d-%d.ll",reference,source);FILE* file=fopen(name,"wb");CHECK(file && fwrite(prior[source],1,lengths[source],file)==lengths[source] && fclose(file)==0);}
   else CHECK((size_t)w.output.snapshot_length==lengths[source] && memcmp(prior[source],data(w.output.snapshot),lengths[source])==0);
   CHECK(writer_release(&w.output,&w.usage,&w.failure));
  }
  CHECK(imports>0);if(j==0){prior_work=w.usage.work;prior_ids=w.usage.identities;}else CHECK(w.usage.work==prior_work && w.usage.identities==prior_ids);
  CHECK(graph_release_declarations(&declarations,&w) && writer_dispose(&w) && w.usage.payload==0);
 }
 for(int i=0;i<4;++i)free(prior[i]);for(int i=14;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));CHECK(ube_gc_collect() && ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);return 0;
}
