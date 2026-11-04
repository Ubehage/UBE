#define INITIALIZATION_PROBE_ENTRY retained_initialization_probe_main
#include "probe.c"
/* Test-only transport of measured fixed footprints to the exact UBE emitter.
   The binding harness, not this transport, owns object/metadata verification. */
int main(int argc,char** argv){
 CHECK(argc==3);FILE* input=fopen(argv[1],"rb");CHECK(input);
 int32_t counts[2];int64_t reserve;CHECK(fread(counts,4,2,input)==2 && fread(&reserve,8,1,input)==1 && counts[0]>0 && counts[1]>0 && counts[0]<=4094 && counts[1]<=4094-counts[0]);
 int32_t count=counts[0]+counts[1]+1;void* values=NULL;struct writer w={0};struct ube_gc_root roots[4]={{0}};void** owners[]={&values,&w.output.buffer.bytes,&w.output.snapshot,&w.cancellation};for(int i=0;i<4;++i)CHECK(ube_gc_root_enter(&roots[i],owners[i]));
 CHECK(ube_value_try_resize(&values,count,&frame_scalar_layout,0));void* v=((struct ube_array*)values)->data;CHECK(fread(v,8,(size_t)count,input)==(size_t)count && fgetc(input)==EOF && fclose(input)==0);
 unsigned char* prior=malloc((size_t)count*8);CHECK(prior);memcpy(prior,v,(size_t)count*8);defaults(&w.limits);CHECK(begin(&w));visits=0;ube_err_set(77,"prior","bound frames");
 CHECK(frame_data(&w,&values,counts[0],counts[1],reserve) && w.usage.work==count && visits==count && w.usage.identities==2 && memcmp(v,prior,(size_t)count*8)==0 && ube_err_number()==77);
 CHECK(save_entry(&w,argv[2])==0 && dispose(&w) && w.usage.payload==0);free(prior);values=NULL;for(int i=3;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));CHECK(ube_gc_collect() && ube_gc_root_count==0 && ube_gc_live_allocation_bytes()==0);printf("PASS frame metadata %d slots\n",count);return 0;
}
