#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "value_storage.h"
#include "expected.h"
struct failure {int32_t kind,code,source,first,last,related,rfirst,rlast;};
struct position {int32_t byte,scalar,line,column;};
struct token {int32_t kind;struct position first,last;};
struct syntax {void* nodes;int32_t count,root,source;};
struct work {void* owner;void* tokens;void* syntax;uint8_t rest[64];};
struct document {void* bytes;int32_t content,scalars,lines;};
struct owner {struct document document;int32_t source;};
struct project_syntax {void* project;void* works;};
struct project {void* invocation;void* cwd;void* packages;void* sources;int32_t package_count,source_count,source_bytes,path_bytes,metadata_bytes;bool validated;};
struct path {void* declared;void* normalized;void* resolved;int32_t parents,first,last;};
struct project_source {void* owner;struct path path;void* identity;uint8_t envelope[20];int32_t package,index;};
typedef union {uint64_t align;uint8_t bytes[32];} root;
extern int32_t formatter_make(void**,void**,void**),formatter_source(void*,struct failure*,void**),formatter_project(void**,void*,struct failure*,void**),formatter_print_source(void*,struct failure*),formatter_print_project(void**,void*,struct failure*),formatter_position(void*,int32_t,struct position*);
extern void formatter_fallback(void);
extern size_t index_root_count(void),index_root_limit(void),ube_gc_live_allocation_bytes(void),ube_gc_root_storage_size(void);
extern int32_t ube_gc_root_enter(void*,void**),ube_gc_root_leave(void*),ube_gc_collect(void);
extern void* ube_array_element(void*,int32_t);
static unsigned assertions;
#define CHECK(x) do{++assertions;if(!(x)){fprintf(stderr,"formatter assertion %u line %d: %s\n",assertions,__LINE__,#x);return 1;}}while(0)
static struct {bool active;size_t sites,fail,root_before,root_peak,heap_peak;} observed;
void index_root_changed(size_t n){if(observed.active&&n>observed.root_peak)observed.root_peak=n;}
void name_heap_changed(size_t n){if(observed.active&&n>observed.heap_peak)observed.heap_peak=n;}
static bool denied(void){if(!observed.active)return false;++observed.sites;return observed.fail&&observed.sites>=observed.fail;}
void* probe_malloc(size_t n){return denied()?NULL:malloc(n);}
void* probe_calloc(size_t n,size_t s){return denied()?NULL:calloc(n,s);}
void* probe_realloc(void* p,size_t n){return denied()?NULL:realloc(p,n);}
void probe_free(void* p){free(p);}
void probe_value_copy(size_t n){(void)n;}
static char capture[4096];static size_t captured,capture_calls;
void formatter_capture_string(const char* s){++capture_calls;if(!s)return;
#ifdef FORMATTER_PARTIAL_FALLBACK
if(strcmp(s,"error UBE1428: insufficient semantic storage")==0){memcpy(capture+captured,"partial\n",8);captured+=8;}
#endif
size_t n=strlen(s);if(n>=sizeof capture-captured){fputs("capture overflow\n",stderr);abort();}memcpy(capture+captured,s,n);captured+=n;capture[captured]=0;}
void formatter_capture_newline(void){++capture_calls;if(captured+1>=sizeof capture)abort();capture[captured++]='\n';capture[captured]=0;}
static void begin(size_t fail){observed=(__typeof__(observed)){.active=true,.fail=fail,.root_before=index_root_count(),.root_peak=index_root_count(),.heap_peak=ube_gc_live_allocation_bytes()};captured=capture_calls=0;capture[0]=0;}
static void end(void){observed.active=false;}
static const struct ube_value_layout byte_layout={1,0,0,NULL,0,NULL};
struct env {void* bytes;void* path;void* input;void* output;void* invocation;root roots[5];};
static int put(void** p,const char* s){size_t n=strlen(s);CHECK(ube_value_try_resize(p,(int32_t)n,&byte_layout,0));for(size_t i=0;i<n;++i)*(uint8_t*)ube_array_element(*p,(int32_t)i)=(uint8_t)s[i];return 0;}
static struct work* work(struct env* e){return *(void**)ube_array_element(((struct project_syntax*)e->input)->works,0);}
static const char source[]="\xEF\xBB\xBF" "UBE SOURCE 1 MODULE\r\nAttribute UBE_Name = \"FormatApp\"\r\n'\xCE\xB1\xF0\x9F\x98\x80\r\nSub Main()\r\nDim caf\xC3\xA9 As Long: caf\xC3\xA9 = 1\r\nEnd Sub\r\n";
static const char escaped_path[]="\"C:\\\\src\\x0A\\x09\\x01\\x7F\\\"\xC3\xA9.bas\"";
static const char raw_path[]="C:\\src\n\t\x01\x7F\"\xC3\xA9.bas";
static const char raw_invocation[]="D:\\root.UBE";
static const char escaped_invocation[]="\"D:\\\\root.UBE\"";
static const char old_text[]="unchanged older display";
static int open_env(struct env* e){
memset(e,0,sizeof *e);void** slots[]={&e->bytes,&e->path,&e->input,&e->output,&e->invocation};
for(int i=0;i<5;++i)CHECK(ube_gc_root_enter(&e->roots[i],slots[i]));
CHECK(put(&e->invocation,raw_invocation)==0);
CHECK(put(&e->bytes,source)==0&&put(&e->path,raw_path)==0&&formatter_make(&e->bytes,&e->path,&e->input));
struct project_syntax* input=e->input;struct project* project=input->project;struct project_source* association=*(void**)ube_array_element(project->sources,0);
CHECK(association->owner==work(e)->owner&&ube_value_array_length(&e->path)==(int32_t)strlen(raw_path)&&ube_value_array_length(&association->path.resolved)==(int32_t)strlen(raw_path));
for(size_t i=0;i<strlen(raw_path);++i)CHECK(*(uint8_t*)ube_array_element(association->path.resolved,(int32_t)i)==(uint8_t)raw_path[i]);
e->output=(void*)old_text;return 0;}
static int close_env(struct env* e){for(int i=4;i>=0;--i)CHECK(ube_gc_root_leave(&e->roots[i]));(void)ube_gc_collect();CHECK(index_root_count()==0&&ube_gc_live_allocation_bytes()==0);return 0;}
static uint64_t hash(uint64_t h,const void* data,size_t n){const uint8_t* p=data;for(size_t i=0;i<n;++i){h^=p[i];h*=UINT64_C(1099511628211);}return h;}
static uint64_t hash_array(uint64_t h,void* array,size_t stride){int32_t n=ube_value_array_length(&array);h=hash(h,&array,sizeof array);h=hash(h,&n,sizeof n);for(int32_t i=0;i<n;++i)h=hash(h,ube_array_element(array,i),stride);return h;}
static uint64_t owners(struct env* e){struct project_syntax* input=e->input;struct work* w=work(e);struct owner* o=w->owner;struct project* p=input->project;struct project_source* ps=*(void**)ube_array_element(p->sources,0);uint64_t h=UINT64_C(1469598103934665603);h=hash(h,input,16);h=hash(h,w,88);h=hash(h,o,32);h=hash_array(h,o->document.bytes,1);h=hash_array(h,w->tokens,36);h=hash_array(h,w->syntax,24);struct syntax* s=ube_array_element(w->syntax,0);h=hash_array(h,s->nodes,24);h=hash(h,p,56);h=hash(h,ps,88);h=hash_array(h,ps->path.resolved,1);h=hash_array(h,e->bytes,1);h=hash_array(h,e->path,1);return h;}
static struct failure diagnostic(int code,int source_id,int first){return (struct failure){.kind=3,.code=code,.source=source_id,.first=first,.last=first+4,.related=0,.rfirst=91,.rlast=97};}
static void expected(char* text,size_t size,int code,int line,int column,int first,bool project,bool independent){snprintf(text,size,"%s%serror UBE%d: %s (next lines: line, column, byte)\n%d\n%d\n%d",project?(independent?escaped_invocation:escaped_path):"",project?"\n":"",code,messages[code-1400],line,column,first);}
static int32_t invoke(struct env* e,int mode,struct failure* f){
int32_t ok;if(mode<2){ok=mode==0?formatter_source(work(e),f,&e->output):formatter_project(&e->invocation,e->input,f,&e->output);
#ifdef FORMATTER_WRONG_TEXT
if(ok)((char*)e->output)[0]='?';
#endif
}else{ok=mode==2?formatter_print_source(work(e),f):formatter_print_project(&e->invocation,e->input,f);if(!ok)formatter_fallback();}
#ifdef FORMATTER_CHANGED_FAILURE
f->last++;
#endif
return ok;}
static int coordinates(void){struct env e;CHECK(open_env(&e)==0);struct work* w=work(&e);int32_t count=ube_value_array_length(&w->tokens);CHECK(count>10);for(int32_t i=0;i<count;++i){struct token* t=ube_array_element(w->tokens,i);int line=1,column=1;for(int32_t at=3;at<t->first.byte;){uint8_t b=(uint8_t)source[at];if(b=='\r'){++line;column=1;at+=source[at+1]=='\n'?2:1;}else if(b=='\n'){++line;column=1;++at;}else{++column;at+=(b<128?1:b<224?2:b<240?3:4);}}struct position p={-71,-72,-73,-74};CHECK(formatter_position(w,t->first.byte,&p));CHECK(p.line==line&&p.column==column&&p.byte==t->first.byte);}struct position p={7,8,9,10},old=p;CHECK(!formatter_position(w,-1,&p)&&memcmp(&p,&old,16)==0);CHECK(!formatter_position(w,4,&p)&&memcmp(&p,&old,16)==0);CHECK(close_env(&e)==0);printf("{\"suite\":\"formatter-coordinates\",\"tokens\":%d,\"passed\":true}\n",count);return 0;}
static int compare_text(const char* actual,const char* wanted){int result=strcmp(actual,wanted);if(result)fprintf(stderr,"actual=[%s]\nwanted=[%s]\n",actual,wanted);return result;}
#define strcmp compare_text
static int messages_case(void){struct env e;CHECK(open_env(&e)==0);const char* at=strstr(source,"caf\xC3\xA9 =");CHECK(at);int first=(int)(at-source);uint64_t identity=owners(&e);for(int code=1400;code<=1437;++code){for(int mode=0;mode<4;++mode){struct failure f=diagnostic(code,0,first),old=f;char wanted[2048];expected(wanted,sizeof wanted,code,5,19,first,mode&1,false);begin(0);int ok=invoke(&e,mode,&f);end();CHECK(ok&&memcmp(&f,&old,sizeof f)==0&&owners(&e)==identity);if(mode<2){CHECK(strcmp(e.output,wanted)==0&&captured==0);e.output=(void*)old_text;}else{strcat(wanted,"\n");CHECK(strcmp(capture,wanted)==0&&capture_calls==2);}(void)ube_gc_collect();}}CHECK(close_env(&e)==0);printf("{\"suite\":\"formatter-all-messages\",\"messages\":38,\"forms\":4,\"passed\":true}\n");return 0;}
static int faults(void){for(int mode=0;mode<4;++mode){struct env e;CHECK(open_env(&e)==0);int first=(int)(strstr(source,"caf\xC3\xA9 =")-source);struct failure f=diagnostic(1402,0,first);uint64_t identity=owners(&e);begin(0);CHECK(invoke(&e,mode,&f));end();size_t sites=observed.sites,need=observed.root_peak-observed.root_before;CHECK(sites>0&&sites<2048&&need>0&&need<256);e.output=(void*)old_text;(void)ube_gc_collect();size_t baseline=ube_gc_live_allocation_bytes();for(size_t site=1;site<=sites;++site){struct failure old=f;begin(site);int ok=invoke(&e,mode,&f);end();if(ok)fprintf(stderr,"mode%d site%zu unexpected success\n",mode,site);CHECK(!ok&&memcmp(&f,&old,sizeof f)==0&&owners(&e)==identity);CHECK(e.output==old_text);if(mode<2)CHECK(captured==0);else CHECK(strcmp(capture,"error UBE1428: insufficient semantic storage\n")==0&&capture_calls==2);(void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==baseline);begin(0);CHECK(invoke(&e,mode,&f));end();e.output=(void*)old_text;(void)ube_gc_collect();CHECK(owners(&e)==identity&&ube_gc_live_allocation_bytes()==baseline);}printf("{\"suite\":\"formatter-allocation-faults\",\"mode\":%d,\"sites\":%zu,\"rootNeed\":%zu,\"passed\":true}\n",mode,sites,need);CHECK(close_env(&e)==0);}return 0;}
static int roots(void){for(int mode=0;mode<4;++mode){struct env e;CHECK(open_env(&e)==0);int first=(int)(strstr(source,"caf\xC3\xA9 =")-source);struct failure f=diagnostic(1402,0,first);begin(0);CHECK(invoke(&e,mode,&f));end();size_t need=observed.root_peak-observed.root_before;e.output=(void*)old_text;(void)ube_gc_collect();size_t baseline=ube_gc_live_allocation_bytes();uint64_t identity=owners(&e);size_t fill=index_root_limit()-index_root_count();root* roots=calloc(fill,sizeof *roots);void** slots=calloc(fill,sizeof *slots);CHECK(roots&&slots);for(size_t i=0;i<fill;++i)CHECK(ube_gc_root_enter(&roots[i],&slots[i]));for(size_t available=0;available<=need+1;++available){if(available)CHECK(ube_gc_root_leave(&roots[fill-available]));struct failure old=f;begin(0);int ok=invoke(&e,mode,&f);end();if(ok!=(available>=need))fprintf(stderr,"roots mode%d available%zu need%zu ok%d\n",mode,available,need,ok);CHECK(ok==(available>=need)&&memcmp(&f,&old,sizeof f)==0&&owners(&e)==identity);if(ok){e.output=(void*)old_text;}else{CHECK(e.output==old_text);if(mode<2)CHECK(captured==0);else CHECK(strcmp(capture,"error UBE1428: insufficient semantic storage\n")==0&&capture_calls==2);}(void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==baseline);}for(size_t i=fill-need-1;i>0;--i)CHECK(ube_gc_root_leave(&roots[i-1]));free(roots);free(slots);CHECK(close_env(&e)==0);printf("{\"suite\":\"formatter-root-capacities\",\"mode\":%d,\"need\":%zu,\"passed\":true}\n",mode,need);}return 0;}
static int domains(void){struct env e;CHECK(open_env(&e)==0);uint64_t identity=owners(&e);for(int mode=0;mode<4;++mode){struct failure f=diagnostic(1427,-1,987),old=f;begin(0);CHECK(invoke(&e,mode,&f));end();CHECK(memcmp(&f,&old,sizeof f)==0&&owners(&e)==identity);char wanted[2048];expected(wanted,sizeof wanted,1427,1,1,0,mode&1,true);if(mode<2){CHECK(strcmp(e.output,wanted)==0);e.output=(void*)old_text;}else{strcat(wanted,"\n");CHECK(strcmp(capture,wanted)==0);}(void)ube_gc_collect();}
for(int which=0;which<6;++which){struct failure f=diagnostic(1402,0,3),old;switch(which){case 0:f.code=1399;break;case 1:f.code=1438;break;case 2:f.source=-2;break;case 3:f.source=1;break;case 4:f.first=-1;break;case 5:f.first=4;break;}old=f;for(int mode=0;mode<4;++mode){begin(0);CHECK(!invoke(&e,mode,&f));end();CHECK(memcmp(&f,&old,sizeof f)==0&&e.output==old_text&&owners(&e)==identity);if(mode<2)CHECK(captured==0);else CHECK(strcmp(capture,"error UBE1428: insufficient semantic storage\n")==0);(void)ube_gc_collect();}}
struct failure f=diagnostic(1402,0,3),old=f;CHECK(!formatter_source(NULL,&f,&e.output)&&!formatter_project(&e.path,NULL,&f,&e.output)&&memcmp(&f,&old,sizeof f)==0&&e.output==old_text);CHECK(close_env(&e)==0);printf("{\"suite\":\"formatter-domain-infrastructure\",\"passed\":true}\n");return 0;}
int main(void){CHECK(sizeof(root)>=ube_gc_root_storage_size()&&sizeof(struct failure)==32&&sizeof(struct work)==88&&sizeof(struct project_source)==88);CHECK(coordinates()==0&&messages_case()==0&&domains()==0&&faults()==0&&roots()==0);printf("PASS semantic formatter assertions:%u\n",assertions);return 0;}
