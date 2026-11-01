#include "bootstrap_runtime.c"
extern int32_t fixture_main(void);
int main(void){
    ube_gc_test_set_threshold(1);
    int32_t result=fixture_main();
    if(result || ube_gc_root_count || !ube_gc_collect() || ube_gc_live_allocation_bytes()){
        fprintf(stderr,"materialization fixture result/root/payload drain failed\n");
        return 1;
    }
    return 0;
}
