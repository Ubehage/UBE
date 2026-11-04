extern int32_t graph_entry(void**,struct declarations*,struct writer*),writer_process_adapter(struct writer*);
static int entry_body_cases(const char* path,int reference) {
 void* bytes=NULL;void* checked=NULL;struct declarations declarations={0};struct writer w={0};struct ube_gc_root roots[6]={{0}};
 void** owners[]={&bytes,&checked,&declarations.targets,&w.output.buffer.bytes,&w.output.snapshot,&w.cancellation};for(int i=0;i<6;++i)CHECK(ube_gc_root_enter(&roots[i],owners[i]));
 CHECK(ube_value_try_resize(&bytes,(int32_t)strlen(path),&ube_file_byte_layout,0));memcpy(data(bytes),path,strlen(path));
 unsigned char* expected_prior=NULL;size_t expected_prior_bytes=0;
 unsigned char* prior=NULL;size_t length=0;int64_t prior_work=-1,prior_ids=-1;const int jobs[]={1,2,4};
 for(int j=0;j<3;++j){struct semantic_failure failure={0};CHECK(graph_project(&bytes,jobs[j],&checked,&failure));graph_defaults(&w.limits);w.usage=(struct usage){0};CHECK(writer_begin(&w) && graph_declarations(&checked,&declarations,&w));struct result* r=checked;CHECK(r->entry>=0 && r->entry<declarations.count);struct target* targets=data(declarations.targets);struct target saved=targets[r->entry];CHECK(saved.kind==6 && saved.type==4 && saved.frame==11);
  CHECK(checked_expectations(&declarations,r->entry,&w,reference,jobs[j],&expected_prior,&expected_prior_bytes)==0);
  for(int defect=0;defect<8;++defect){struct target* t=&targets[r->entry];if(defect==0)t->kind=2;if(defect==1)t->type=5;if(defect==2)t->role=1;if(defect==3)t->parameter_count=1;if(defect==4){t->source=reference?1:3;t->scope=t->source;}if(defect==5)t->scope=-1;if(defect==6)t->frame=-1;if(defect==7)t->value=-1;
   int64_t before=w.usage.work,ids=w.usage.identities;int accepted=graph_entry(&checked,&declarations,&w);*t=saved;CHECK(!accepted && w.failure.code==1509 && w.usage.work-before==4 && w.usage.identities==ids && w.output.length==0);
  }
  for(int defect=0;defect<2;++defect){int32_t old=r->entry;r->entry=defect?declarations.count:-1;int64_t work=w.usage.work;int accepted=graph_entry(&checked,&declarations,&w);r->entry=old;CHECK(!accepted && w.failure.code==1509 && w.output.length==0 && w.usage.work==work);}
  int64_t before=w.usage.work,ids=w.usage.identities;ube_err_set(77,"prior","checked entry");CHECK(graph_entry(&checked,&declarations,&w) && w.usage.work-before==7 && w.usage.identities-ids==86 && ube_err_number()==77 && memcmp(&targets[r->entry],&saved,sizeof saved)==0 && writer_snapshot(&w));
  if(j==0){length=(size_t)w.output.snapshot_length;prior=malloc(length);CHECK(prior);memcpy(prior,data(w.output.snapshot),length);char name[64];snprintf(name,sizeof name,"project-entry-%d.ll",reference);FILE* file=fopen(name,"wb");CHECK(file && fwrite(prior,1,length,file)==length && fclose(file)==0);prior_work=w.usage.work;prior_ids=w.usage.identities;}
  else CHECK((size_t)w.output.snapshot_length==length && memcmp(prior,data(w.output.snapshot),length)==0 && w.usage.work==prior_work && w.usage.identities==prior_ids);
  CHECK(graph_release_declarations(&declarations,&w) && writer_dispose(&w) && w.usage.payload==0);
 }
 free(expected_prior);free(prior);w.usage=(struct usage){0};CHECK(writer_begin(&w) && writer_process_adapter(&w) && writer_snapshot(&w));FILE* file=fopen("project-process.ll","wb");CHECK(file && fwrite(data(w.output.snapshot),1,(size_t)w.output.snapshot_length,file)==(size_t)w.output.snapshot_length && fclose(file)==0);CHECK(writer_dispose(&w) && w.usage.payload==0);
 if(!reference)CHECK(expected_support_outputs(&w)==0);
 for(int i=5;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));CHECK(ube_gc_collect() && !ube_gc_root_count && !ube_gc_live_allocation_bytes());return 0;
}
