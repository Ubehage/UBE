/* Test-only readonly state observations. The included runtime body is intact. */
#ifndef UBE_REGRESSION_RUNTIME_SOURCE
#define UBE_REGRESSION_RUNTIME_SOURCE "../../../../../../runtime/bootstrap_runtime.c"
#endif
#include UBE_REGRESSION_RUNTIME_SOURCE

size_t runtime_regression_roots(void) {
    ube_gc_enter_lock();size_t count=ube_gc_root_count;ube_gc_leave_lock();return count;
}
size_t runtime_regression_marked(void) {
    ube_gc_enter_lock();size_t count=0;
    for(struct ube_gc_header* item=ube_gc_allocations;item!=NULL;item=item->next)if(item->marked)++count;
    ube_gc_leave_lock();return count;
}
int runtime_regression_collecting(void) {return ube_gc_collecting;}
int runtime_regression_try_gc_lock(void) {
    /* Main initialized the lock before creating the checking thread. */
    if(!TryEnterCriticalSection(&ube_gc_lock))return 0;
    LeaveCriticalSection(&ube_gc_lock);return 1;
}
void runtime_regression_error_snapshot(int32_t* number,uint64_t* revision,char* description,size_t dc,char* source,size_t sc) {
#ifdef UBE_REGRESSION_ERROR_STATE
    const struct ube_error_state* error=UBE_REGRESSION_ERROR_STATE;
#else
    struct ube_thread_local_state* state=ube_tls_get(0);
    const struct ube_error_state* error=state!=NULL?&state->error:NULL;
#endif
    *number=error!=NULL?error->number:0;
    *revision=error!=NULL?error->revision:0;
    ube_error_copy_text(description,dc,error!=NULL?error->description:"");
    ube_error_copy_text(source,sc,error!=NULL?error->source:"");
}
