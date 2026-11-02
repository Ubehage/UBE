#define main catalog_base_main
#define name_heap_changed catalog_original_heap_changed
#include "probe.c"
#undef name_heap_changed
#undef main
static _Thread_local size_t syntax_entries,syntax_reads,scalar_entries;
void catalog_observe(int32_t kind){if(observed.active){if(kind==1)++syntax_entries;if(kind==2)++syntax_reads;if(kind==3)++scalar_entries;}}
void name_heap_changed(size_t count){
#ifdef NEGATIVE_CATALOG_HEAP
 (void)count;
#else
 catalog_original_heap_changed(count);
#endif
}
static size_t logarithm(size_t n){size_t l=0,p=1;while(p<n){p*=2;++l;}return l;}
static int costs(void){const int counts[]={0,1,8,64,1024,16384};for(size_t test=0;test<6;++test){int n=counts[test];size_t capacity=(size_t)(n+8)*64+256;char* source=malloc(capacity);CHECK(source);size_t used=(size_t)snprintf(source,capacity,"UBE SOURCE 1 MODULE\nAttribute UBE_Name = \"A\"\n");for(int i=0;i<n;++i)used+=(size_t)snprintf(source+used,capacity-used,"Dim v%05d As Long\n",i);used+=(size_t)snprintf(source+used,capacity-used,"Sub Main()\nEnd Sub\n");CHECK(used<capacity);struct environment e;CHECK(open(&e,source,NULL,0)==0);free(source);struct catalog* c=e.input;source_observation(c);(void)ube_gc_collect();syntax_entries=syntax_reads=scalar_entries=0;struct failure f={.kind=5,.code=1428};begin(0);
#ifdef NEGATIVE_CATALOG_SOURCE_COPY
 const struct ube_value_field field={0,&byte_layout};const size_t offset=0;const struct ube_value_layout array_layout={sizeof(void*),1,1,&field,1,&offset};void* clone=NULL;CHECK(catalog_assign(&clone,&borrowed_sources[0],&array_layout));
#endif
 int ok=catalog_build(c,&f);end();CHECK(ok&&f.kind==0&&f.code==0);
#ifdef NEGATIVE_CATALOG_METRIC
 ++syntax_reads;
#endif
 size_t d=(size_t)n+2,nn=(size_t)2*n+2,k=(size_t)n+3,ff=(size_t)n+1,b=(size_t)10*n+5;
#ifdef NEGATIVE_CATALOG_EXTRA
 ++d;
#endif
 CHECK((size_t)c->declaration_count==d&&(size_t)c->name_count==nn&&c->type_count==6&&(size_t)c->key_count==k&&(size_t)c->fact_count==ff&&c->value_count==0&&(size_t)c->name_bytes.count==b&&ube_value_array_length(&c->declarations)==c->declaration_count&&ube_value_array_length(&c->names)==c->name_count&&ube_value_array_length(&c->name_bytes.bytes)==c->name_bytes.count);CHECK(syntax_entries>0&&syntax_entries==syntax_reads&&scalar_entries==b&&c->metrics.scalars==(int64_t)b&&c->metrics.bytes==(int64_t)b);for(int i=0;i<n;++i){struct declaration* v=decl(c,i+1);char wanted[16];(void)snprintf(wanted,sizeof wanted,"v%05d",i);CHECK(v->kind==2&&v->source==0&&v->scope==0&&v->type==4&&v->flags==66&&v->initializer==-1&&v->known==0&&v->value==0&&named(c,v->name,wanted)==0);}struct declaration* main_decl=decl(c,n+1);int main_type=0;
#ifdef NEGATIVE_CATALOG_TYPE
 main_type=1;
#endif
 CHECK(main_decl->kind==5&&main_decl->type==main_type&&main_decl->scope==0&&main_decl->parameters==0&&named(c,main_decl->name,"main")==0);CHECK(*(int32_t*)ube_array_element(c->order,0)==0&&*(int32_t*)ube_array_element(c->order,1)==n+1);for(int i=0;i<n;++i)CHECK(*(int32_t*)ube_array_element(c->order,i+2)==i+1);CHECK(*(int32_t*)ube_array_element(c->order,n+2)==n+2);void* association=*(void**)ube_array_element(c->sources,0);void* work=*(void**)association;void* syntax=*(void**)((uint8_t*)work+16);int32_t vcount=*(int32_t*)((uint8_t*)ube_array_element(syntax,0)+8);size_t l=logarithm(d+nn+k+2)+1,a=observed.managed_calls,p=(size_t)c->metrics.pending;size_t q=5*d*64+5*nn*24+6*40+5*k*16+3*k*4+4*ff*48+5*b+4*(size_t)vcount+4*p*12+4096;size_t copy_limit=q-3*k*4;size_t headers=index_array_header()+index_gc_header();CHECK(a<=64*(syntax_entries+scalar_entries+d+2)+256&&observed.managed_allocations<=a+4*l&&observed.allocations-observed.managed_allocations<=32+16*l+8&&observed.managed_requested<=8*a+4*k+headers+64);if(observed.gc_peak>observed.gc_before+q+(32+20*l+8)*index_array_header())fprintf(stderr,"catalog heap n=%d actualAdditional=%zu bound=%zu q=%zu keyCount=%zu\n",n,observed.gc_peak-observed.gc_before,q+(32+20*l+8)*index_array_header(),q,k);CHECK(observed.requested<=8*a+q+(32+20*l+8)*headers&&observed.zeroed<=observed.requested&&observed.copied<=copy_limit&&observed.gc_peak>observed.gc_before&&observed.gc_peak<=observed.gc_before+q+(32+20*l+8)*index_array_header()&&observed.roots_peak<=observed.roots_before+512&&observed.source_copies==0&&observed.source_resizes==0);printf("{\"suite\":\"catalog-cost\",\"n\":%d,\"declarations\":%d,\"names\":%d,\"keys\":%d,\"facts\":%d,\"syntaxReadEntries\":%zu,\"canonicalScalarEntries\":%zu,\"managedAssignments\":%zu,\"managedAllocations\":%zu,\"otherAllocations\":%zu,\"requested\":%zu,\"zeroed\":%zu,\"arrayPayloadCopied\":%zu,\"rootDelta\":%zu,\"peakAdditionalGcPayload\":%zu,\"sourceCopied\":%zu,\"passed\":true}\n",n,c->declaration_count,c->name_count,c->key_count,c->fact_count,syntax_entries,scalar_entries,a,observed.managed_allocations,observed.allocations-observed.managed_allocations,observed.requested,observed.zeroed,observed.copied,observed.roots_peak-observed.roots_before,observed.gc_peak-observed.gc_before,observed.source_copies);CHECK(close_env(&e)==0);}return 0;}
int main(void){CHECK(sizeof(struct catalog)==240&&sizeof(struct declaration)==64&&sizeof(struct fact)==48&&sizeof(struct native_type)==40&&sizeof(struct name)==24&&sizeof(root)>=ube_gc_root_storage_size());CHECK(costs()==0);printf("PASS catalog cost assertions:%u\n",assertions);return 0;}
