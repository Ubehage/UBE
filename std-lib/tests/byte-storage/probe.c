#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern void test_make_bytes(void);
extern void ube_err_set(int32_t, const char*, const char*);
extern int32_t ube_err_number(void), ube_gc_collect(void);
static int tracking, failures_remaining;
static void* pointers[1024];
static size_t sizes[1024], count, live, live_bytes;
static void observe(void* p, size_t n) {
    if (!tracking || p == NULL) return;
    if (count >= 1024) { fputs("probe bookkeeping exceeded\n",stderr); exit(2); }
    pointers[count] = p; sizes[count++] = n;
    ++live; live_bytes += n;
}
void* probe_malloc(size_t n) {
    if (tracking && failures_remaining) { --failures_remaining; return NULL; }
    void* p = malloc(n); observe(p,n); return p;
}
void* probe_calloc(size_t n, size_t s) {
    if (tracking && failures_remaining) { --failures_remaining; return NULL; }
    void* p = calloc(n,s); observe(p,n*s); return p;
}
void* probe_realloc(void* p, size_t n) {
    /* Realloc is not used by this focused fixture; avoid false measurements. */
    if (tracking) { fputs("unexpected realloc in storage probe\n",stderr); exit(2); }
    return realloc(p,n);
}
void probe_free(void* p) {
    for (size_t i = 0; p != NULL && i < count; ++i) {
        if (pointers[i] == p) { pointers[i] = NULL; --live; live_bytes -= sizes[i]; break; }
    }
    free(p);
}
int main(int argc, char** argv) {
    ube_err_set(77,"pre-existing","storage probe");
    tracking = 1;
    if (argc == 2 && (strcmp(argv[1],"oom") == 0 || strcmp(argv[1],"retry") == 0)) {
        failures_remaining = strcmp(argv[1],"retry") == 0 ? 1 : 2;
        test_make_bytes();
        tracking = 0;
        (void)ube_gc_collect();
        printf("returned err:%d live:%llu\n",ube_err_number(),(unsigned long long)live);
        return 0;
    }
    for (int i = 0; i < 1000; ++i) test_make_bytes();
    tracking = 0;
    const int32_t collected = ube_gc_collect();
    printf("allocations:%llu live-after-return-and-collect:%llu bytes:%llu collect:%d err:%d\n",
        (unsigned long long)count,(unsigned long long)live,(unsigned long long)live_bytes,
        collected,ube_err_number());
    return 0;
}
