/* Complete scalar record dump for independent host-side targeted observations. */
#define main scalar_fixture_main
#include "probe.c"
#undef main
#include <inttypes.h>
#ifndef TARGETED_BEFORE_CHECK
#define TARGETED_BEFORE_CHECK(input) ((void)(input))
#define TARGETED_AFTER_CHECK() ((void)0)
#endif
extern int32_t statement_project_make(void**,int32_t,void*,void**,struct failure*),statement_project_check(void*,int32_t,struct limits*,void*,void**,struct failure*);
struct project_syntax {void* project;void* work;};
static uint64_t hash_project_work(const struct project_syntax* input){uint64_t hash=UINT64_C(1469598103934665603);int count=ube_value_array_length(&input->work);for(int i=0;i<count;++i){struct work* work=*(struct work**)ube_array_element(input->work,i);struct syntax* syntax=ube_array_element(work->syntax,0);hash=hash_array(hash,work->owner->document.bytes,1);hash=hash_array(hash,work->tokens,36);hash=hash_array(hash,work->syntax,24);hash=hash_array(hash,syntax->nodes,24);}return hash;}
static void dump_syntax_records(struct work* work){struct syntax* s=ube_array_element(work->syntax,0);putchar('[');for(int i=0;i<s->count;++i){struct syntax_node* n=ube_array_element(s->nodes,i);if(i)putchar(',');printf("[%d,%d,%d,%d,%d,%d]",n->kind,n->first,n->last,n->child,n->next,n->children);}putchar(']');}
static void dump_facts(void* values,int count){putchar('[');for(int i=0;i<count;++i){struct fact* f=ube_array_element(values,i);if(i)putchar(',');printf("[%d,%d,%d,%d,%" PRId64 ",%d,%d,%d,%d,%d,%d]",f->source,f->syntax,f->kind,f->type,f->value,f->target,f->left,f->right,f->flags,f->auxiliary,f->extra);}putchar(']');}
static void dump_values(void* values,int count){putchar('[');for(int i=0;i<count;++i){struct node* n=ube_array_element(values,i);if(i)putchar(',');printf("[%d,%d,%d,%d,%" PRId64 ",%d,%d,%d,%d,%d,%d]",n->source,n->syntax,n->kind,n->type,n->value,n->target,n->child,n->next,n->children,n->flags,n->auxiliary);}putchar(']');}
static void dump_result(const struct result* result){
 struct catalog* c=result->catalog;struct module* m=module(result);
 printf(",\"types\":[");for(int i=0;i<c->type_count;++i){int32_t* t=ube_array_element(c->types,i);if(i)putchar(',');printf("[%d,%d,%d,%d,%d,%d,%" PRId64 ",%" PRId64 "]",t[0],t[1],t[2],t[3],t[4],t[5],((int64_t*)t)[3],((int64_t*)t)[4]);}putchar(']');
 printf(",\"entry\":%d,\"root\":%d,\"declarations\":[",result->entry,m->root);
 for(int i=0;i<c->declaration_count;++i){struct declaration* d=declaration(result,i);if(i)putchar(',');printf("[%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%" PRId64 "]",d->kind,d->source,d->syntax,d->name,d->scope,d->type,d->flags,d->first_parameter,d->parameters,d->ordinal,d->initializer,d->known,d->auxiliary,d->body,d->value);}printf("],\"names\":[");
 for(int i=0;i<c->name_count;++i){struct name* n=ube_array_element(c->names,i);if(i)putchar(',');printf("[%d,%d,%d,%d,%d,%d]",n->source,n->syntax,n->first,n->last,n->byte_first,n->byte_count);}printf("],\"nameBytesHex\":\"");
 for(int i=0;i<c->name_bytes.count;++i)printf("%02x",*(uint8_t*)ube_array_element(c->name_bytes.bytes,i));
 printf("\",\"catalogFacts\":");dump_facts(c->facts,c->fact_count);printf(",\"catalogValues\":");dump_values(c->values,c->value_count);printf(",\"facts\":");dump_facts(m->facts,m->fact_count);printf(",\"values\":");dump_values(m->values,m->value_count);
 printf(",\"modules\":[");int modules=ube_value_array_length(&result->modules);for(int i=0;i<modules;++i){struct module* item=*(struct module**)ube_array_element(result->modules,i);if(i)putchar(',');printf("{\"source\":%d,\"root\":%d,\"facts\":",item->source,item->root);dump_facts(item->facts,item->fact_count);printf(",\"values\":");dump_values(item->values,item->value_count);putchar('}');}putchar(']');
}
#ifndef TARGETED_ENTRY_NAME
#define TARGETED_ENTRY_NAME main
#endif
int TARGETED_ENTRY_NAME(int argc,char** argv){
 int project=argc==4&&!strcmp(argv[1],"--project"),jobs=project?atoi(argv[3]):1;if(!project&&argc!=2)return 2;
 long bytes;char* text;if(project){bytes=(long)strlen(argv[2]);text=malloc((size_t)bytes+1);CHECK(text);memcpy(text,argv[2],(size_t)bytes+1);}else{FILE* file=fopen(argv[1],"rb");if(!file)return 2;CHECK(fseek(file,0,SEEK_END)==0);bytes=ftell(file);CHECK(bytes>=0&&bytes<=16777216&&fseek(file,0,SEEK_SET)==0);text=malloc((size_t)bytes+1);CHECK(text&&fread(text,1,(size_t)bytes,file)==(size_t)bytes&&fclose(file)==0);text[bytes]=0;}
 struct environment e={0};void** slots[]={&e.bytes,(void**)&e.input,&e.cancellation,(void**)&e.result,(void**)&e.old};for(int i=0;i<5;++i)CHECK(ube_gc_root_enter(&e.roots[i],slots[i]));CHECK(statement_cancel(&e.cancellation));
 CHECK(ube_value_try_resize(&e.bytes,(int32_t)bytes,&byte_layout,0));for(int i=0;i<bytes;++i)*(uint8_t*)ube_array_element(e.bytes,i)=(uint8_t)text[i];
 struct failure failure={5,1428,-1,0,0,-1,0,0};int setup=project?statement_project_make(&e.bytes,jobs,e.cancellation,(void**)&e.input,&failure):statement_make(&e.bytes,0,0,(void**)&e.input,&failure),ok=0;
 if(setup){uint64_t original=project?hash_project_work((void*)e.input):hash_input(e.input);failure=(struct failure){5,1428,-1,0,0,-1,0,0};TARGETED_BEFORE_CHECK(e.input);ok=project?statement_project_check(e.input,jobs,&generous,e.cancellation,(void**)&e.result,&failure):check(&e,1,&generous,&failure);TARGETED_AFTER_CHECK();CHECK(original==(project?hash_project_work((void*)e.input):hash_input(e.input)));if(!ok)CHECK(e.result==NULL);}
 printf("{\"setup\":%s,\"ok\":%s,\"failure\":[%d,%d,%d,%d,%d,%d,%d,%d]",setup?"true":"false",ok?"true":"false",failure.kind,failure.code,failure.source,failure.first,failure.last,failure.related,failure.rfirst,failure.rlast);
 if(setup){printf(",\"syntax\":");if(project){struct project_syntax* input=(void*)e.input;dump_syntax_records(*(struct work**)ube_array_element(input->work,0));printf(",\"sourceSyntax\":[");int count=ube_value_array_length(&input->work);for(int i=0;i<count;++i){if(i)putchar(',');dump_syntax_records(*(struct work**)ube_array_element(input->work,i));}putchar(']');}else{dump_syntax_records(e.input->input);}}
 if(ok){struct catalog* catalog=e.result->catalog;CHECK(catalog&&ube_value_array_length(&e.result->modules)==catalog->source_count);if(project){struct project_syntax* input=(void*)e.input;CHECK(catalog->input==input&&catalog->source_count==ube_value_array_length(&input->work));for(int i=0;i<catalog->source_count;++i){struct source* retained=*(struct source**)ube_array_element(catalog->sources,i);struct module* output=*(struct module**)ube_array_element(e.result->modules,i);CHECK(retained->input==*(struct work**)ube_array_element(input->work,i)&&retained->source==i&&output->source==i&&output->catalog==catalog);}}else{struct source* retained=*(struct source**)ube_array_element(catalog->sources,0);CHECK(catalog->source_count==1&&retained->input==e.input->input&&retained->source==0&&module(e.result)->catalog==catalog);}dump_result(e.result);}puts("}");free(text);
 for(int i=4;i>=0;--i)CHECK(ube_gc_root_leave(&e.roots[i]));(void)ube_gc_collect();CHECK(index_root_count()==0&&ube_gc_live_allocation_bytes()==0&&whole_worker_count()==0&&atomic_load(&capture_live)==0);return 0;
}
