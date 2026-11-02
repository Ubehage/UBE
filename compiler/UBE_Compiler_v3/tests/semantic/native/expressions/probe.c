#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include "value_storage.h"
struct limits {int32_t declarations,facts,pending,depth;};
struct failure {int32_t kind,code,source,first,last,related,rfirst,rlast;};
struct metrics {int64_t syntax,reads,writes,facts,nodes,transitions,scalars,bytes,lookups;int32_t pending,depth;};
struct work {void* catalog;void* source;void* cancellation;struct limits limits;int32_t maximum_facts,maximum_pending;void* facts;int32_t fact_count;void* values;int32_t value_count,root,scope;struct failure failure,diagnostic;struct metrics metrics;void* result;int64_t worker;int32_t state;};
struct info {int32_t source,syntax,type,flags;int64_t value;int32_t target,node,context,selection,annotation,origin;};
struct fact {int32_t source,syntax,kind,type;int64_t value;int32_t target,left,right,flags,auxiliary,extra;};
struct node {int32_t source,syntax,kind,type;int64_t value;int32_t target,first,next,count,flags,auxiliary;};
struct syntax {int32_t kind,first,last,child,next,count;};
struct declaration {int32_t kind,source,syntax,name,scope,type,flags,first_parameter,parameters,ordinal,initializer,known,auxiliary,body;int64_t value;};
typedef union {uint64_t alignment;uint8_t bytes[32];} root;
extern int32_t expression_check(void**,int32_t,int32_t,int32_t,int32_t,int32_t,bool,void**,struct info*,struct failure*);
extern int32_t expression_syntax(void*,int32_t,struct syntax*);
extern int32_t expression_pair(void**,void**,int32_t,int32_t,int32_t,int32_t,int32_t,bool,void**,struct info*,struct failure*);
extern int32_t expression_origin(void*,int32_t,int32_t,struct syntax*),expression_declaration(void*,int32_t,struct declaration*);
extern int32_t ube_gc_root_enter(void*,void**),ube_gc_root_leave(void*),ube_gc_collect(void);
extern size_t ube_gc_root_storage_size(void),ube_gc_live_allocation_bytes(void);
extern int32_t ube_err_number(void);
extern void ube_err_set(int32_t,const char*,const char*);
extern void* ube_array_element(void*,int32_t);
static const struct ube_value_layout byte_layout={1,0,0,NULL,0,NULL};
static const char* running;
static unsigned assertions;
#define CHECK(x) do{++assertions;if(!(x)){fprintf(stderr,"expression assertion %u case=%s line=%d: %s\n",assertions,running,__LINE__,#x);return 1;}}while(0)
#define H "UBE SOURCE 1 MODULE\nAttribute UBE_Name = \"A\"\n"
#define V(t,e) H "Sub Main()\nDim x As " t " = " e "\nEnd Sub\n"
#define TAKE "Sub Take(ByRef value As Long)\nEnd Sub\n"
#define CHANGE "Sub Change(Optional ByRef first As Long = 10, Optional ByVal amount As Long = 2)\nEnd Sub\n"
#define GIVE "Function Give() As Long\nEnd Function\n"
/* All expected values, types, codes and maps below are hand-authored literals.
   No checker output or alternate evaluator supplied an expected answer. */
struct specimen {const char* id;const char* source;const char* expression;int kind,context,destination,code;const char* error;int type,known;int64_t value,converted;int target,parameters;int slots[2],modes[2];int call_flags,children;};
static const struct specimen cases[]={
 {"owner-integer-fold",V("Integer","40000 - 10000"),"40000 - 10000",13,3,3,0,NULL,4,1,30000,30000,-1,-1,{0},{0},0,0},
 {"owner-wide-context",V("LongLong","2147483647 + 1"),"2147483647 + 1",12,5,5,0,NULL,5,1,INT64_C(2147483648),INT64_C(2147483648),-1,-1,{0},{0},0,0},
 {"default-long",V("Long","2147483647"),"2147483647",2,0,4,0,NULL,4,1,INT32_MAX,INT32_MAX,-1,-1,{0},{0},0,0},
 {"default-longlong",V("LongLong","2147483648"),"2147483648",2,0,5,0,NULL,5,1,INT64_C(2147483648),INT64_C(2147483648),-1,-1,{0},{0},0,0},
 {"signed-longlong-min",V("LongLong","-9223372036854775808"),"-9223372036854775808",5,0,5,0,NULL,5,1,INT64_MIN,INT64_MIN,-1,-1,{0},{0},0,0},
 {"byte-promotion",V("Byte","200 + 100 - 100"),"200 + 100 - 100",13,2,2,0,NULL,3,1,200,200,-1,-1,{0},{0},0,0},
 {"numeric-boolean",V("Boolean","2"),"2",2,0,1,0,NULL,4,1,2,1,-1,-1,{0},{0},0,0},
 {"boolean-numeric",V("Long","True"),"True",2,0,4,0,NULL,1,1,1,-1,-1,-1,{0},{0},0,0},
 {"required-suffix-overflow",V("LongLong","2147483647& + 1&"),"2147483647& + 1&",12,5,5,1410,"2147483647& + 1&",0,0,0,0,-1,-1,{0},{0},0,0},
 {"default-arithmetic-overflow",V("LongLong","2147483647 + 1"),"2147483647 + 1",12,0,5,1410,"2147483647 + 1",0,0,0,0,-1,-1,{0},{0},0,0},
 {"known-divzero",V("Long","5 \\ 0"),"5 \\ 0",10,0,4,1411,"5 \\ 0",0,0,0,0,-1,-1,{0},{0},0,0},
 {"skipped-andalso-fault",V("Boolean","False AndAlso (1 \\ 0 = 0)"),"False AndAlso (1 \\ 0 = 0)",25,0,1,0,NULL,1,1,0,0,-1,-1,{0},{0},0,0},
 {"skipped-orelse-fault",V("Boolean","True OrElse (1 \\ 0 = 0)"),"True OrElse (1 \\ 0 = 0)",27,0,1,0,NULL,1,1,1,1,-1,-1,{0},{0},0,0},
 {"known-final-narrowing",V("Integer","40000"),"40000",2,3,3,1410,"40000",0,0,0,0,-1,-1,{0},{0},0,0},
 {"byref-alias",H TAKE "Sub Main()\nDim a As Long\nCall Take(a)\nEnd Sub\n","Call Take(a)",44,0,0,0,NULL,0,0,0,0,1,1,{0},{1},0,1},
 {"byref-wrong-type",H TAKE "Sub Main()\nDim a As Integer\nCall Take(a)\nEnd Sub\n","Call Take(a)",44,0,0,1417,"a",0,0,0,0,-1,-1,{0},{0},0,0},
 {"byref-group-temporary",H TAKE "Sub Main()\nDim a As Integer\nCall Take((a))\nEnd Sub\n","Call Take((a))",44,0,0,0,NULL,0,0,0,0,1,1,{0},{2},0,1},
 {"byref-literal-rejected",H TAKE "Sub Main()\nCall Take(1)\nEnd Sub\n","Call Take(1)",44,0,0,1417,"1",0,0,0,0,-1,-1,{0},{0},0,0},
 {"byval-independent-context",H "Sub Take(ByVal value As LongLong)\nEnd Sub\nSub Main()\nCall Take(2147483647 + 1)\nEnd Sub\n","Call Take(2147483647 + 1)",44,0,0,0,NULL,0,0,0,0,1,1,{0},{0},0,2},
 {"named-source-order",H CHANGE "Sub Main()\nDim a As Long\nCall Change(amount:=3, first:=(a))\nEnd Sub\n","Call Change(amount:=3, first:=(a))",44,0,0,0,NULL,0,0,0,0,1,2,{1,0},{6,4},0,3},
 {"optional-missing",H CHANGE "Sub Main()\nCall Change()\nEnd Sub\n","Call Change()",44,0,0,0,NULL,0,0,0,0,1,2,{-1,-1},{19,19},0,4},
 {"optional-omitted",H CHANGE "Sub Main()\nCall Change(, amount:=4)\nEnd Sub\n","Call Change(, amount:=4)",44,0,0,0,NULL,0,0,0,0,1,2,{0,1},{11,4},0,5},
 {"unknown-named",H TAKE "Sub Main()\nCall Take(other:=1)\nEnd Sub\n","Call Take(other:=1)",44,0,0,1418,"other",0,0,0,0,-1,-1,{0},{0},0,0},
 {"duplicate-named",H "Sub Take(ByVal x As Long)\nEnd Sub\nSub Main()\nCall Take(x:=1, X:=2)\nEnd Sub\n","Call Take(x:=1, X:=2)",44,0,0,1418,"X",0,0,0,0,-1,-1,{0},{0},0,0},
 {"positional-after-named",H "Sub Take(ByVal x As Long, ByVal y As Long)\nEnd Sub\nSub Main()\nCall Take(x:=1, 2)\nEnd Sub\n","Call Take(x:=1, 2)",44,0,0,1418,"2",0,0,0,0,-1,-1,{0},{0},0,0},
 {"missing-required",H TAKE "Sub Main()\nCall Take()\nEnd Sub\n","Call Take()",44,0,0,1418,"Call Take()",0,0,0,0,-1,-1,{0},{0},0,0},
 {"wrong-local-shadows",H TAKE "Sub Main()\nDim Take As Long\nCall Take()\nEnd Sub\n","Call Take()",44,0,0,1409,"Take",0,0,0,0,-1,-1,{0},{0},0,0},
 {"zero-call-expression",H GIVE "Sub Main()\nDim x As Long = Give()\nEnd Sub\n","Give()",38,0,4,0,NULL,4,0,0,0,1,0,{0},{0},0,0},
 {"bare-function",H GIVE "Sub Main()\nDim x As Long = Give\nEnd Sub\n","Give",1,0,4,0,NULL,4,0,0,0,1,0,{0},{0},0,0},
 {"qualified-bare-function",H GIVE "Sub Main()\nDim x As Long = A.Give\nEnd Sub\n","A.Give",34,0,4,0,NULL,4,0,0,0,1,0,{0},{0},0,6},
 {"discard-function",H GIVE "Sub Main()\nCall Give()\nEnd Sub\n","Call Give()",44,0,0,0,NULL,4,0,0,0,1,0,{0},{0},1,0}
 ,{"named-integer-suffix-conflict",H TAKE "Sub Main()\nCall Take(value%:=1)\nEnd Sub\n","Call Take(value%:=1)",44,0,0,1403,"value%",0,0,0,0,-1,-1,{0},{0},0,0}
 ,{"named-string-suffix-conflict",H TAKE "Sub Main()\nCall Take(value$:=1)\nEnd Sub\n","Call Take(value$:=1)",44,0,0,1403,"value$",0,0,0,0,-1,-1,{0},{0},0,0}
 ,{"skipped-argument-narrowing",H "Function CheckByte(ByVal amount As Byte) As Boolean\nEnd Function\nSub Main()\nDim x As Boolean = False AndAlso CheckByte(300)\nEnd Sub\n","False AndAlso CheckByte(300)",25,0,1,0,NULL,1,1,0,0,-1,-1,{0},{0},0,7}
 ,{"skipped-boolean-numeric-value",H "Function CheckLong(ByVal amount As Long) As Boolean\nEnd Function\nSub Main()\nDim x As Boolean = False AndAlso CheckLong(True)\nEnd Sub\n","False AndAlso CheckLong(True)",25,0,1,0,NULL,1,1,0,0,-1,-1,{0},{0},0,8}
 ,{"real-family-before-integer-range",V("Long","999999999999999999999999999.0"),"999999999999999999999999999.0",2,4,4,1430,"999999999999999999999999999.0",0,0,0,0,-1,-1,{0},{0},0,0}
};
static const char* last_text(const char* text,const char* token){const char* found=NULL;for(const char* at=text;(at=strstr(at,token))!=NULL;++at)found=at;return found;}
static struct fact* fact(struct work* w,int32_t i){return ube_array_element(w->facts,i);}
static struct node* node(struct work* w,int32_t i){return ube_array_element(w->values,i);}
static int execute(const struct specimen* s,int32_t seed){
 running=s->id;void* bytes=NULL;void* retained=NULL;root roots[2]={0};CHECK(ube_gc_root_enter(&roots[0],&bytes)&&ube_gc_root_enter(&roots[1],&retained));size_t length=strlen(s->source);CHECK(ube_value_try_resize(&bytes,(int32_t)length,&byte_layout,0));memcpy(ube_array_element(bytes,0),s->source,length);
 const char* at=last_text(s->source,s->expression);CHECK(at);int32_t first=(int32_t)(at-s->source),last=first+(int32_t)strlen(s->expression);struct info info={0};struct failure f={.kind=5,.code=1428};ube_err_set(seed,"prior","expression fixture");int ok=expression_check(&bytes,first,last,s->kind,s->context,s->destination,s->kind==43||s->kind==44,&retained,&info,&f);CHECK(ube_err_number()==seed);
 if((ok!=0)!=(s->code==0)||(!ok&&f.code!=s->code))fprintf(stderr,"actual case=%s ok=%d kind=%d code=%d span=%d:%d expected=%d\n",s->id,ok,f.kind,f.code,f.first,f.last,s->code);
 CHECK((ok!=0)==(s->code==0));
 if(!ok){const char* error=last_text(s->expression,s->error);CHECK(error&&f.code==s->code&&(f.kind==3||f.kind==8)&&f.source==0&&f.first==first+(int32_t)(error-s->expression)&&f.last-f.first==(int32_t)strlen(s->error));}
 else {
  struct work* w=retained;CHECK(w&&f.kind==0&&f.code==0&&info.type==s->type&&((info.flags&1)!=0)==s->known&&info.target==s->target&&info.node>=0&&info.node<w->value_count);
  struct syntax root_syntax={0};CHECK(expression_syntax(w,info.syntax,&root_syntax)&&root_syntax.kind==s->kind&&root_syntax.first==first&&root_syntax.last==last&&info.annotation>=0&&info.annotation<w->fact_count);
  int64_t wanted=s->value;
#ifdef EXPRESSION_EXPECTED_CONTROL
  if(s==cases)++wanted;
#endif
  if(s->known)CHECK(info.value==wanted);
#ifdef EXPRESSION_MISSING_FACT_CONTROL
  if(s==cases)w->fact_count=0;
#endif
  int expression_facts=0,conversions=0,module_bindings=0,call_count=0;struct fact* call=NULL;
  for(int32_t i=0;i<w->fact_count;++i){struct fact* v=fact(w,i);CHECK(v->source==0);if(v->kind==1&&v->syntax==info.syntax){++expression_facts;CHECK(v->type==s->type&&v->auxiliary==info.node&&v->target==s->target);}if(v->kind==3&&v->right==4){++conversions;CHECK(v->left==s->type&&v->type==s->destination&&v->flags==((s->type!=s->destination?1:0)|(s->known?2:0)));if(s->known)CHECK(v->value==s->converted);}if(v->kind==2&&v->left==6)++module_bindings;if(v->kind==5&&v->syntax==info.syntax){call=v;++call_count;}}
  CHECK(expression_facts==1&&conversions==(s->destination>0));struct node* value=node(w,info.node);CHECK(value->type==s->type);
  if(s->known){CHECK(w->value_count==1&&value->kind==(s->type==1?2:1)&&value->value==wanted&&value->first==-1&&value->count==0);}
  if(s->children==7||s->children==8){int edges=0,static_calls=0,skipped_calls=0;for(int32_t i=0;i<w->fact_count;++i){struct fact* v=fact(w,i);if(v->kind==3&&v->target==2&&v->right==6){++edges;CHECK(v->type==(s->children==7?2:4)&&v->left==(s->children==7?3:1)&&v->flags==(s->children==7?1:3)&&v->value==(s->children==7?0:-1));}if(v->kind==5&&v->target==1)++static_calls;if(v->kind==1&&v->target==1&&(v->flags&64)){++skipped_calls;CHECK(v->auxiliary==-1&&(v->flags&1)==0);}}CHECK(edges==1&&static_calls==1&&skipped_calls==1);}
  if(s->parameters>=0){CHECK(call_count==1&&call&&call->target==s->target&&call->type==s->type&&call->right==s->parameters&&call->flags==s->call_flags&&value->kind==6&&value->target==s->target&&value->count==s->parameters&&value->flags==(s->call_flags?4:0));if(!s->parameters)CHECK(call->left==-1);for(int p=0;p<s->parameters;++p){CHECK(call->left+p<w->fact_count);struct fact* a=fact(w,call->left+p);CHECK(a->kind==6&&a->target==2+p&&a->extra==p&&a->auxiliary==s->slots[p]&&a->flags==s->modes[p]);int links=0;for(int32_t j=0;j<w->fact_count;++j){struct fact* c=fact(w,j);if(c->kind==3&&c->target==a->target&&c->auxiliary==p&&(c->right==6||c->right==10))++links;}CHECK(links==1);}if(s->children){if(s->children==6)CHECK(module_bindings==1);else{CHECK(value->first>=0);struct node* c=node(w,value->first);if(s->children==1)CHECK(c->kind==3);if(s->children==2)CHECK(c->kind==1&&c->type==5&&c->value==INT64_C(2147483648));if(s->children>=3){CHECK(c->kind==1&&c->value==(s->children==3?3:(s->children==4?10:4))&&c->next>=0);struct node* d=node(w,c->next);if(s->children==3)CHECK(d->kind==3);else CHECK(d->kind==1&&d->value==(s->children==4?2:10));}}}}
 }
 CHECK(ube_gc_root_leave(&roots[1])&&ube_gc_root_leave(&roots[0]));(void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==0&&ube_err_number()==seed);printf("{\"case\":\"%s\",\"errSeed\":%d,\"passed\":true}\n",s->id,seed);return 0;
}
static int pair_default(int32_t seed){
 running="cross-module-default-origin";
 static const char app[]=H "Sub Main()\nCall B.Change()\nEnd Sub\n";
 static const char library[]="UBE SOURCE 1 MODULE\nAttribute UBE_Name = \"B\"\nPublic Sub Change(Optional ByVal amount As Long = (1 + 1))\nEnd Sub\n";
 const char* expression="Call B.Change()";const char* at=strstr(app,expression);const char* origin=strstr(library,"(1 + 1)");CHECK(at&&origin);
 void* a=NULL;void* b=NULL;void* retained=NULL;root roots[3]={0};void** slots[]={&a,&b,&retained};for(int i=0;i<3;++i)CHECK(ube_gc_root_enter(&roots[i],slots[i]));CHECK(ube_value_try_resize(&a,(int32_t)strlen(app),&byte_layout,0)&&ube_value_try_resize(&b,(int32_t)strlen(library),&byte_layout,0));memcpy(ube_array_element(a,0),app,strlen(app));memcpy(ube_array_element(b,0),library,strlen(library));
 struct info info={0};struct failure f={.kind=5,.code=1428};ube_err_set(seed,"prior","expression fixture");int ok=expression_pair(&a,&b,(int32_t)(at-app),(int32_t)(at-app+strlen(expression)),44,0,0,true,&retained,&info,&f);if(!ok)fprintf(stderr,"pair actual kind=%d code=%d source=%d span=%d:%d\n",f.kind,f.code,f.source,f.first,f.last);CHECK(ok&&f.kind==0&&info.source==0&&info.type==0&&info.target==3&&ube_err_number()==seed);
 CHECK(ube_gc_root_leave(&roots[1])&&ube_gc_root_leave(&roots[0]));a=NULL;b=NULL;(void)ube_gc_collect();
 struct work* w=retained;CHECK(w&&info.node>=0&&info.node<w->value_count);struct node* call_node=node(w,info.node);CHECK(call_node->kind==6&&call_node->source==0&&call_node->target==3&&call_node->count==1&&call_node->first>=0);struct node* applied=node(w,call_node->first);CHECK(applied->kind==1&&applied->type==4&&applied->value==2&&applied->source==1&&applied->count==0&&applied->first==-1);
 struct declaration parameter={0};CHECK(expression_declaration(w,4,&parameter)&&parameter.kind==4&&parameter.source==1&&parameter.type==4&&parameter.known==1&&parameter.value==2&&applied->syntax==parameter.initializer);struct syntax syntax={0};CHECK(expression_origin(w,applied->source,applied->syntax,&syntax)&&syntax.kind==3&&syntax.first==(int32_t)(origin-library)&&syntax.last-syntax.first==7);
 int calls=0,arguments=0,conversions=0;for(int32_t i=0;i<w->fact_count;++i){struct fact* v=fact(w,i);if(v->kind==5){++calls;CHECK(v->source==0&&v->target==3&&v->right==1&&v->auxiliary==0&&v->left>=0);}if(v->kind==6){++arguments;CHECK(v->source==0&&v->target==4&&v->type==4&&v->right==-1&&v->auxiliary==-1&&v->extra==0&&v->flags==19&&v->value==2);}if(v->kind==3&&v->right==10){++conversions;CHECK(v->source==0&&v->syntax==info.syntax&&v->type==4&&v->left==4&&v->target==4&&v->auxiliary==0&&v->flags==2&&v->value==2);}}CHECK(calls==1&&arguments==1&&conversions==1&&ube_err_number()==seed);
 CHECK(ube_gc_root_leave(&roots[2]));(void)ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==0&&ube_err_number()==seed);printf("{\"case\":\"cross-module-default-origin\",\"errSeed\":%d,\"passed\":true}\n",seed);return 0;
}
int main(void){running="layout";CHECK(sizeof(struct work)==256&&sizeof(struct info)==48&&sizeof(struct fact)==48&&sizeof(struct node)==48&&sizeof(struct declaration)==64&&sizeof(root)>=ube_gc_root_storage_size());for(size_t i=0;i<sizeof cases/sizeof cases[0];++i)for(int seed=7;seed<=77;seed+=70)CHECK(execute(&cases[i],seed)==0);for(int seed=7;seed<=77;seed+=70)CHECK(pair_default(seed)==0);printf("PASS expression native cases:%zu seeds:2 assertions:%u\n",1+sizeof cases/sizeof cases[0],assertions);return 0;}
