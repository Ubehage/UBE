/* Independent exact ScalarApp body stream, resolved by original parser spans.
   All values/types/roles/conversions/edges below are authored expectations.
   Actual indexes only normalize references; no candidate value supplies an answer. */
static int scalar_expr(const struct module* m,int syntax,int type,int64_t value,int target,int context,int selection,int flags,int node){return expect_fact(m,(struct fact){0,syntax,1,type,value,target,context,selection,flags,node,syntax});}
static int scalar_binding(const struct module* m,int syntax,int type,int target,int role,int level){return expect_fact(m,(struct fact){0,syntax,2,type,0,target,role,level,0,-1,-1});}
static int scalar_conversion(const struct module* m,int syntax,int destination,int64_t value,int target,int original,int place,int flags,int ordinal){return expect_fact(m,(struct fact){0,syntax,3,destination,value,target,original,place,flags,ordinal,-1});}
static int scalar_complete(const struct environment* e){
 const char* source=scalar_source;struct result* r=e->result;struct module* m=module(r);
 CHECK(r->entry==4&&r->catalog->declaration_count==8&&r->catalog->type_count==6&&m->value_count==20&&m->fact_count==41);
 const int type_kinds[]={0,1,2,2,2,2},type_bits[]={0,0,8,16,32,64};
 const int64_t minima[]={0,0,0,-32768,INT32_MIN,INT64_MIN},maxima[]={0,1,255,32767,INT32_MAX,INT64_MAX};
 for(int i=0;i<6;++i){struct semantic_type* t=ube_array_element(r->catalog->types,i);CHECK(t->kind==type_kinds[i]&&t->declaration==-1&&t->representation==-1&&t->pack==-1&&t->unpack==-1&&t->bits==type_bits[i]&&t->minimum==minima[i]&&t->maximum==maxima[i]);}
 const int kinds[]={1,3,6,4,6,2,2,2},types[]={0,4,4,4,4,3,5,4},scopes[]={-1,0,0,2,0,4,4,4};
 const char* names[]={"scalarapp","offset","addoffset","value","main","small","wide","self"};
 for(int i=0;i<8;++i){struct declaration* d=declaration(r,i);CHECK(d->kind==kinds[i]&&d->type==types[i]&&d->scope==scopes[i]&&d->source==0);struct name* n=ube_array_element(r->catalog->names,d->name);CHECK(n->byte_count==(int)strlen(names[i]));for(int j=0;j<n->byte_count;++j)CHECK(*(uint8_t*)ube_array_element(r->catalog->name_bytes.bytes,n->byte_first+j)==(uint8_t)names[i][j]);}
 CHECK(declaration(r,1)->known==1&&declaration(r,1)->value==2&&declaration(r,2)->parameters==1&&declaration(r,2)->first_parameter==3&&declaration(r,3)->ordinal==0&&(declaration(r,3)->flags&4)&&declaration(r,4)->parameters==0);
 int ar=text_syntax(e->input,source,1,"AddOffset","AddOffset = value + Offset");
 int av=text_syntax(e->input,source,1,"value","value + Offset");
 int ao=text_syntax(e->input,source,1,"Offset","value + Offset");
 int add=text_syntax(e->input,source,12,"value + Offset",NULL);
 int aa=text_syntax(e->input,source,40,"AddOffset = value + Offset",NULL);
 int sl=text_syntax(e->input,source,2,"40000",NULL),sr=text_syntax(e->input,source,2,"10000",NULL),sub=text_syntax(e->input,source,13,"40000 - 10000",NULL);
 int wl=text_syntax(e->input,source,2,"2147483647",NULL),wr=text_syntax(e->input,source,2,"1","+ 1"),wide=text_syntax(e->input,source,12,"2147483647 + 1",NULL);
 int self=text_syntax(e->input,source,1,"self","self + Offset"),so=text_syntax(e->input,source,1,"Offset","self + Offset"),sum=text_syntax(e->input,source,12,"self + Offset",NULL);
 int mr=text_syntax(e->input,source,1,"Main","Main = AddOffset(small)"),ct=text_syntax(e->input,source,1,"AddOffset","AddOffset(small)"),sm=text_syntax(e->input,source,1,"small","AddOffset(small)"),call=text_syntax(e->input,source,38,"AddOffset(small)",NULL),ma=text_syntax(e->input,source,40,"Main = AddOffset(small)",NULL);
 CHECK(ar>=0&&av>=0&&ao>=0&&add>=0&&aa>=0&&sl>=0&&sr>=0&&sub>=0&&wl>=0&&wr>=0&&wide>=0&&self>=0&&so>=0&&sum>=0&&mr>=0&&ct>=0&&sm>=0&&call>=0&&ma>=0);
 /* Every declaration/signature scalar, including original identity spans. */
 const char* proc_texts[]={"Private Function AddOffset(ByVal value As Long) As Long","Public Function Main() As Long"};
 int proc_syntax[2],body_syntax[2];
 for(int i=0;i<2;++i){const char* start=strstr(source,proc_texts[i]);CHECK(start);const char* end=strstr(start,"End Function");const char* body=strchr(start,'\n');CHECK(end&&body);proc_syntax[i]=syntax_at(e->input,65,(int)(start-source),(int)(end-source+12));body_syntax[i]=syntax_at(e->input,46,(int)(body-source+1),(int)(end-source));CHECK(proc_syntax[i]>=0&&body_syntax[i]>=0);}
 const int decl_syntax[]={-1,text_syntax(e->input,source,77,"Offset As Long = 2",NULL),proc_syntax[0],text_syntax(e->input,source,56,"ByVal value As Long",NULL),proc_syntax[1],text_syntax(e->input,source,77,"small As Integer = 40000 - 10000",NULL),text_syntax(e->input,source,77,"wide As LongLong = 2147483647 + 1",NULL),text_syntax(e->input,source,77,"self As Long = self + Offset",NULL)};
 const int flags[]={1,66,66,70,65,66,66,66},first_parameters[]={-1,-1,3,-1,-1,-1,-1,-1},parameter_counts[]={0,0,1,0,0,0,0,0};
 const int initializers[]={-1,text_syntax(e->input,source,2,"2","Offset As Long = 2"),-1,-1,-1,sub,wide,sum};
 const int bodies[]={-1,-1,body_syntax[0],-1,body_syntax[1],-1,-1,-1};
 const char* written_names[]={"\"ScalarApp\"","Offset","AddOffset","value","Main","small","wide","self"};
 const char* name_contexts[]={NULL,"Const Offset","Function AddOffset","ByVal value","Function Main","Dim small","Dim wide","Dim self"};
 for(int i=0;i<8;++i){struct declaration* d=declaration(r,i);CHECK(i==0||decl_syntax[i]>=0);CHECK(d->syntax==decl_syntax[i]&&d->flags==flags[i]&&d->first_parameter==first_parameters[i]&&d->parameters==parameter_counts[i]&&d->ordinal==0&&d->initializer==initializers[i]&&d->known==(i==1)&&d->auxiliary==0&&d->body==bodies[i]&&d->value==(i==1?2:0));
  struct name* n=ube_array_element(r->catalog->names,d->name);const char* context=name_contexts[i]?strstr(source,name_contexts[i]):source;CHECK(context);const char* start=strstr(context,written_names[i]);CHECK(start);int first=(int)(start-source),last=first+(int)strlen(written_names[i]);CHECK(n->source==0&&n->first==first&&n->last==last);CHECK(n->syntax==(i==0?-1:syntax_at(e->input,1,first,last)));
 }
 int module_root=input_syntax(e->input)->root;struct declaration* ad=declaration(r,2);struct declaration* main=declaration(r,4);
 int nmod=node_id(m,100,module_root),nap=node_id(m,101,ad->syntax),nab=node_id(m,102,ad->body),naa=node_id(m,104,aa),nav=node_id(m,3,av),nao=node_id(m,1,ao),nadd=node_id(m,5,add);
 int nmp=node_id(m,101,main->syntax),nmb=node_id(m,102,main->body),ns=node_id(m,103,declaration(r,5)->syntax),nsv=node_id(m,1,sub),nw=node_id(m,103,declaration(r,6)->syntax),nwv=node_id(m,1,wide),nself=node_id(m,103,declaration(r,7)->syntax),nselfv=node_id(m,5,sum),nread=node_id(m,3,self),nso=node_id(m,1,so),nma=node_id(m,104,ma),ncall=node_id(m,6,call),nsm=node_id(m,3,sm);
 int ca=conversion(m,add,5,2),cs=conversion(m,sub,4,5),cw=conversion(m,wide,4,6),cf=conversion(m,sum,4,7),cm=conversion(m,call,5,4);
 int call_fact=-1,arg_fact=-1;for(int i=0;i<m->fact_count;++i){if(fact(m,i)->kind==5){CHECK(call_fact==-1);call_fact=i;}if(fact(m,i)->kind==6){CHECK(arg_fact==-1);arg_fact=i;}}
 CHECK(nmod>=0&&nap>=0&&nab>=0&&naa>=0&&nav>=0&&nao>=0&&nadd>=0&&nmp>=0&&nmb>=0&&ns>=0&&nsv>=0&&nw>=0&&nwv>=0&&nself>=0&&nselfv>=0&&nread>=0&&nso>=0&&nma>=0&&ncall>=0&&nsm>=0&&ca>=0&&cs>=0&&cw>=0&&cf>=0&&cm>=0&&call_fact>=0&&arg_fact>=0&&m->root==nmod);
 CHECK(expect_node(m,100,module_root,0,0,0,nap,-1,2,0,-1)==0);
 CHECK(expect_node(m,101,ad->syntax,4,0,2,nab,nmp,1,0,-1)==0);
 CHECK(expect_node(m,102,ad->body,0,0,2,naa,-1,1,0,-1)==0);
 CHECK(expect_node(m,104,aa,4,0,2,nadd,-1,1,0,ca)==0);
 CHECK(expect_node(m,5,add,4,0,-1,nav,-1,2,1,12)==0);
 CHECK(expect_node(m,3,av,4,0,3,-1,nao,0,0,-1)==0);
 CHECK(expect_node(m,1,ao,4,2,1,-1,-1,0,0,-1)==0);
 CHECK(expect_node(m,101,main->syntax,4,0,4,nmb,-1,1,0,-1)==0);
 CHECK(expect_node(m,102,main->body,0,0,4,ns,-1,4,0,-1)==0);
 CHECK(expect_node(m,103,declaration(r,5)->syntax,3,0,5,nsv,nw,1,3,cs)==0);
 CHECK(expect_node(m,1,sub,4,30000,-1,-1,-1,0,0,-1)==0);
 CHECK(expect_node(m,103,declaration(r,6)->syntax,5,0,6,nwv,nself,1,3,cw)==0);
 CHECK(expect_node(m,1,wide,5,INT64_C(2147483648),-1,-1,-1,0,0,-1)==0);
 CHECK(expect_node(m,103,declaration(r,7)->syntax,4,0,7,nselfv,nma,1,3,cf)==0);
 CHECK(expect_node(m,5,sum,4,0,-1,nread,-1,2,1,12)==0);
 CHECK(expect_node(m,3,self,4,0,7,-1,nso,0,0,-1)==0);
 CHECK(expect_node(m,1,so,4,2,1,-1,-1,0,0,-1)==0);
 CHECK(expect_node(m,104,ma,4,0,4,ncall,-1,1,0,cm)==0);
 CHECK(expect_node(m,6,call,4,0,2,nsm,-1,1,0,call_fact)==0);
 CHECK(expect_node(m,3,sm,3,0,5,-1,-1,0,0,-1)==0);
 CHECK(scalar_expr(m,av,4,0,3,4,0,2,nav)==0&&scalar_expr(m,ao,4,2,1,4,0,1,nao)==0&&scalar_expr(m,add,4,0,-1,4,0,128,nadd)==0);
 CHECK(scalar_expr(m,sl,4,40000,-1,3,2,9,-1)==0&&scalar_expr(m,sr,3,10000,-1,3,1,9,-1)==0&&scalar_expr(m,sub,4,30000,-1,3,0,25,nsv)==0);
 CHECK(scalar_expr(m,wl,5,2147483647,-1,5,1,9,-1)==0&&scalar_expr(m,wr,5,1,-1,5,1,9,-1)==0&&scalar_expr(m,wide,5,INT64_C(2147483648),-1,5,0,25,nwv)==0);
 CHECK(scalar_expr(m,self,4,0,7,4,0,2,nread)==0&&scalar_expr(m,so,4,2,1,4,0,1,nso)==0&&scalar_expr(m,sum,4,0,-1,4,0,128,nselfv)==0);
 CHECK(scalar_expr(m,sm,3,0,5,4,0,2,nsm)==0&&scalar_expr(m,call,4,0,2,4,0,0,ncall)==0);
 CHECK(scalar_binding(m,ar,4,2,4,2)==0&&scalar_binding(m,av,4,3,1,1)==0&&scalar_binding(m,ao,4,1,2,3)==0);
 CHECK(scalar_binding(m,self,4,7,1,1)==0&&scalar_binding(m,so,4,1,2,3)==0&&scalar_binding(m,mr,4,4,4,2)==0&&scalar_binding(m,ct,4,2,5,3)==0&&scalar_binding(m,sm,3,5,1,1)==0);
 CHECK(scalar_conversion(m,av,4,0,add,4,1,0,0)==0&&scalar_conversion(m,ao,4,2,add,4,2,2,1)==0&&scalar_conversion(m,add,4,0,2,4,5,0,-1)==0);
 CHECK(scalar_conversion(m,sl,4,40000,sub,4,1,2,0)==0&&scalar_conversion(m,sr,4,10000,sub,3,2,3,1)==0&&scalar_conversion(m,sub,3,30000,5,4,4,3,-1)==0);
 CHECK(scalar_conversion(m,wl,5,2147483647,wide,5,1,2,0)==0&&scalar_conversion(m,wr,5,1,wide,5,2,2,1)==0&&scalar_conversion(m,wide,5,INT64_C(2147483648),6,5,4,2,-1)==0);
 CHECK(scalar_conversion(m,self,4,0,sum,4,1,0,0)==0&&scalar_conversion(m,so,4,2,sum,4,2,2,1)==0&&scalar_conversion(m,sum,4,0,7,4,4,0,-1)==0);
 CHECK(scalar_conversion(m,sm,4,0,3,3,6,1,0)==0&&scalar_conversion(m,call,4,0,4,4,5,0,-1)==0);
 CHECK(expect_fact(m,(struct fact){0,sub,9,3,0,5,nsv,cs,0,-1,-1})==0&&expect_fact(m,(struct fact){0,wide,9,5,0,6,nwv,cw,0,-1,-1})==0&&expect_fact(m,(struct fact){0,sum,9,4,0,7,nselfv,cf,0,-1,-1})==0);
 CHECK(expect_fact(m,(struct fact){0,call,5,4,0,2,arg_fact,1,0,1,-1})==0&&expect_fact(m,(struct fact){0,sm,6,4,0,3,call_fact,sm,0,0,0})==0);
 /* Catalog observations are part of the result too: one module attribute,
    Explicit option, seven written type references and the complete Const2. */
 struct module catalog_view={0};catalog_view.facts=r->catalog->facts;catalog_view.fact_count=r->catalog->fact_count;catalog_view.values=r->catalog->values;catalog_view.value_count=r->catalog->value_count;
 CHECK(catalog_view.fact_count==12&&catalog_view.value_count==1);
 int literal=text_syntax(e->input,source,2,"2","Offset As Long = 2"),option=text_syntax(e->input,source,51,"Option Explicit",NULL),header=syntax_node(e->input,module_root)->child;
 CHECK(literal>=0&&option>=0&&header>=0&&syntax_node(e->input,header)->kind==50&&syntax_node(e->input,header)->first==0);
 int constant_node=node_id(&catalog_view,1,literal),constant_conversion=conversion(&catalog_view,literal,8,1);CHECK(constant_node>=0&&constant_conversion>=0&&declaration(r,1)->initializer==literal);
 CHECK(expect_node(&catalog_view,1,literal,4,2,-1,-1,-1,0,0,-1)==0);
 CHECK(expect_fact(&catalog_view,(struct fact){0,literal,1,4,2,-1,4,1,9,constant_node,literal})==0);
 CHECK(expect_fact(&catalog_view,(struct fact){0,literal,3,4,2,1,4,8,2,-1,-1})==0);
 CHECK(expect_fact(&catalog_view,(struct fact){0,literal,9,4,0,1,constant_node,constant_conversion,0,-1,-1})==0);
 CHECK(expect_fact(&catalog_view,(struct fact){0,header,8,-1,0,0,1,0,0,-1,-1})==0);
 CHECK(expect_fact(&catalog_view,(struct fact){0,option,7,-1,0,-1,1,1,0,-1,0})==0);
 const char* type_words[]={"Long","Long","Long","Long","Integer","LongLong","Long"};
 const char* type_contexts[]={"Const Offset As Long","ByVal value As Long",") As Long","Public Function Main() As Long","Dim small As Integer","Dim wide As LongLong","Dim self As Long"};
 const int type_owners[]={1,3,2,4,5,6,7},type_ids[]={4,4,4,4,3,5,4};
 for(int i=0;i<7;++i){int typed=text_syntax(e->input,source,74,type_words[i],type_contexts[i]);CHECK(typed>=0);CHECK(expect_fact(&catalog_view,(struct fact){0,typed,4,type_ids[i],0,-1,type_owners[i],0,1,-1,0})==0);}
 return 0;
}
