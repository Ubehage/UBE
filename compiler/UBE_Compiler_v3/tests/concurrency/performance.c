/* Measurement/assertion adapter only. Runtime and UBE workers are uninstrumented. */
#include "bootstrap_runtime.c"

struct position { int32_t byte, scalar, line, column; };
struct document { void *bytes; int32_t content, scalars, lines; };
struct token { int32_t kind; struct position first, last; };
struct node { int32_t kind, first, last, child, next, children; };
struct result { void *nodes; int32_t count, root, source; };
struct failure { int32_t kind, first, last; };
struct metrics { int32_t reads, actions, names, pending, depth; };
struct owner { struct document document; int32_t id; };
struct work {
    struct owner *owner;
    void *tokens, *syntax;
    struct failure failure;
    struct metrics metrics;
    int64_t id;
    int32_t state, maxtokens, maxnodes, maxpending, maxdepth;
};
struct set_failure { int32_t kind, source; struct failure unit; };
_Static_assert(sizeof(struct owner) == 32 && sizeof(struct work) == 88 &&
               sizeof(struct token) == 36 && sizeof(struct node) == 24,
               "independent source/work payload ABI");
extern int32_t perf_make(void **, int32_t, void **);
extern int32_t perf_sources(void **, int32_t, int32_t, int32_t, int32_t, int32_t,
                            void *, void **, struct set_failure *);
extern void perf_cancel(void **);
extern const struct ube_value_layout *perf_layout(int32_t);

static int fail(const char *message) { fprintf(stderr, "%s\n", message); return 0; }
static int32_t read_i32(FILE *file, int *ok) {
    int32_t value = 0;
    if (fread(&value, sizeof(value), 1, file) != 1) *ok = 0;
    return value;
}
static int stream_int(FILE *file, int create, int32_t value) {
    if (create) return fwrite(&value, sizeof(value), 1, file) == 1;
    int ok = 1;
    return read_i32(file, &ok) == value && ok;
}
static int stream_position(FILE *file, int create, struct position p) {
    return stream_int(file, create, p.byte) && stream_int(file, create, p.scalar) &&
           stream_int(file, create, p.line) && stream_int(file, create, p.column);
}
static int compare_complete(const char *path, int create, void *inputs, void *output, int count) {
    FILE *file = fopen(path, create ? "wb" : "rb");
    if (!file) return fail("reference stream unavailable");
    int ok = ube_value_array_length(&output) == count &&
             stream_int(file, create, 1) && stream_int(file, create, count);
    for (int i = 0; ok && i < count; ++i) {
        struct work *w = *(struct work **)ube_array_element(output, i);
        struct owner *o = *(struct owner **)ube_array_element(inputs, i);
        ok = w && w->owner == o && o->id == i && w->state == 1 && w->failure.kind == 0 &&
             w->id > 0 && w->maxtokens == 1048576 && w->maxnodes == 1048576 &&
             w->maxpending == 1048576 && w->maxdepth == 256 && ube_value_array_length(&w->syntax) == 1;
        if (!ok) break;
        ok = stream_int(file, create, w->failure.kind) && stream_int(file, create, w->failure.first) &&
             stream_int(file, create, w->failure.last) && stream_int(file, create, o->id) && stream_int(file, create, o->document.content) &&
             stream_int(file, create, o->document.scalars) && stream_int(file, create, o->document.lines);
        int bytes = ube_value_array_length(&o->document.bytes);
        ok = ok && stream_int(file, create, bytes);
        for (int b = 0; ok && b < bytes; ++b) {
            uint8_t value = *(uint8_t *)ube_array_element(o->document.bytes, b);
            ok = create ? fputc(value, file) != EOF : fgetc(file) == value;
        }
        int tokens = ube_value_array_length(&w->tokens);
        ok = ok && tokens > 0 && stream_int(file, create, tokens);
        for (int t = 0; ok && t < tokens; ++t) {
            struct token *token = ube_array_element(w->tokens, t);
            ok = stream_int(file, create, token->kind) && stream_position(file, create, token->first) &&
                 stream_position(file, create, token->last) && token->first.byte >= 0 &&
                 token->last.byte >= token->first.byte && token->last.byte <= bytes;
        }
        struct result *r = ube_array_element(w->syntax, 0);
        ok = ok && r->source == i && r->count > 0 && r->root >= 0 && r->root < r->count &&
             ube_value_array_length(&r->nodes) == r->count && stream_int(file, create, r->source) &&
             stream_int(file, create, r->count) && stream_int(file, create, r->root);
        for (int n = 0; ok && n < r->count; ++n) {
            struct node *node = ube_array_element(r->nodes, n);
            ok = stream_int(file, create, node->kind) && stream_int(file, create, node->first) &&
                 stream_int(file, create, node->last) && stream_int(file, create, node->child) &&
                 stream_int(file, create, node->next) && stream_int(file, create, node->children) &&
                 node->first >= 0 && node->last >= node->first && node->last <= bytes &&
                 node->child >= -1 && node->child < r->count && node->next >= -1 && node->next < r->count;
        }
        ok = ok && stream_int(file, create, w->metrics.reads) && stream_int(file, create, w->metrics.actions) &&
             stream_int(file, create, w->metrics.names) && stream_int(file, create, w->metrics.pending) &&
             stream_int(file, create, w->metrics.depth);
    }
    if (!create && ok) ok = fgetc(file) == EOF;
    if (fclose(file) != 0) ok = 0;
    return ok || fail("complete result/reference mismatch");
}
static int drained(void) {
    if (!ube_thread_enter_lock()) return 0;
    int ok = 1;
    for (struct ube_thread_record *p = ube_threads; p; p = p->next)
        if (p->is_worker) ok = 0;
    ube_thread_leave_lock();
    return ok;
}
static int load_inputs(const char *path, void **inputs) {
    FILE *file = fopen(path, "rb");
    if (!file) return 0;
    int ok = 1, count = read_i32(file, &ok);
    if (!ok || count < 1 || count > 256 || !ube_value_try_resize(inputs, count, perf_layout(0), 0)) {
        fclose(file); return 0;
    }
    void *bytes = NULL;
    struct ube_gc_root root = {0};
    if (!ube_gc_root_enter(&root, &bytes)) { fclose(file); return 0; }
    for (int i = 0; ok && i < count; ++i) {
        int length = read_i32(file, &ok);
        if (!ok || length < 0 || length > 16777216 ||
            !ube_value_try_resize(&bytes, length, perf_layout(1), 0)) { ok = 0; break; }
        for (int b = 0; b < length; ++b) {
            int value = fgetc(file);
            if (value == EOF) { ok = 0; break; }
            *(uint8_t *)ube_array_element(bytes, b) = (uint8_t)value;
        }
        if (ok) ok = perf_make(&bytes, i, ube_array_element(*inputs, i));
        if (ok) {
            struct owner *owner = *(struct owner **)ube_array_element(*inputs, i);
            ok = owner && owner->id == i && ube_value_array_length(&owner->document.bytes) == length;
            for (int b = 0; ok && b < length; ++b)
                ok = *(uint8_t *)ube_array_element(owner->document.bytes, b) ==
                     *(uint8_t *)ube_array_element(bytes, b);
        }
    }
    ok = ok && fgetc(file) == EOF;
    if (fclose(file) != 0) ok = 0;
    ube_gc_root_leave(&root);
    return ok ? count : 0;
}
static double now_seconds(void) {
    LARGE_INTEGER count, frequency;
    QueryPerformanceCounter(&count); QueryPerformanceFrequency(&frequency);
    return (double)count.QuadPart / (double)frequency.QuadPart;
}
static uint64_t file_time(FILETIME t) { return ((uint64_t)t.dwHighDateTime << 32) | t.dwLowDateTime; }
static double cpu_seconds(void) {
    FILETIME c, e, k, u;
    if (!GetProcessTimes(GetCurrentProcess(), &c, &e, &k, &u)) return -1;
    return (double)(file_time(k) + file_time(u)) / 10000000.;
}
static int parse(void **inputs, void **output, void *cancel, int jobs) {
    struct set_failure failure = {5, -1, {0}};
    int ok = perf_sources(inputs, jobs, 1048576, 1048576, 1048576, 256, cancel, output, &failure);
    if (!ok || failure.kind != 0 || !drained()) {
        fprintf(stderr, "parse failed: ok=%d kind=%d source=%d unit=%d\n",
                ok, failure.kind, failure.source, failure.unit.kind);
        return 0;
    }
    return 1;
}
static int physical_cores(void) {
    DWORD bytes = 0;
    if (GetLogicalProcessorInformation(NULL, &bytes) || GetLastError() != ERROR_INSUFFICIENT_BUFFER)
        return 0;
    SYSTEM_LOGICAL_PROCESSOR_INFORMATION *items = malloc(bytes);
    if (!items) return 0;
    int cores = 0;
    if (GetLogicalProcessorInformation(items, &bytes)) {
        size_t count = bytes / sizeof(*items);
        for (size_t i = 0; i < count; ++i)
            if (items[i].Relationship == RelationProcessorCore) ++cores;
    }
    free(items);
    return cores;
}
int main(int argc, char **argv) {
    if (argc != 6) return 2;
    int jobs = atoi(argv[3]), repeats = atoi(argv[4]), create = atoi(argv[5]);
    if ((jobs != 1 && jobs != 2 && jobs != 4) || repeats < 0 || repeats > 16384 ||
        (create != 0 && create != 1)) return 2;
    int cores = physical_cores();
    MEMORYSTATUSEX host_memory = {sizeof(host_memory)};
    if (!cores || !GlobalMemoryStatusEx(&host_memory)) return 1;
    double begin = now_seconds();
    if (ube_thread_current_id() <= 0) return 1;
    void *inputs = NULL, *output = NULL, *cancel = NULL;
    struct ube_gc_root roots[3] = {{0}};
    if (!ube_gc_root_enter(&roots[0], &inputs) || !ube_gc_root_enter(&roots[1], &output) ||
        !ube_gc_root_enter(&roots[2], &cancel)) return 1;
    int count = load_inputs(argv[1], &inputs);
    perf_cancel(&cancel);
    if (!count || !cancel) return !fail("input setup failed");
    ube_gc_collect();
    size_t steady_roots = ube_gc_root_count;
    if (!parse(&inputs, &output, cancel, 1) || !compare_complete(argv[2], create, inputs, output, count)) return 1;
    output = NULL;
    ube_gc_collect();
    double setup = now_seconds() - begin, wall = 0, cpu = 0;
    size_t input_payload = ube_gc_live_allocation_bytes();
    for (int i = 0; i < repeats; ++i) {
        struct set_failure failure = {5, -1, {0}};
        double c0 = cpu_seconds(), t0 = now_seconds();
        int ok = perf_sources(&inputs, jobs, 1048576, 1048576, 1048576, 256, cancel, &output, &failure);
        wall += now_seconds() - t0;
        cpu += cpu_seconds() - c0;
        if (!ok || failure.kind != 0 || !drained() || ube_gc_root_count != steady_roots ||
            !compare_complete(argv[2], 0, inputs, output, count)) return !fail("trial correctness failed");
        output = NULL;
        ube_gc_collect();
        if (ube_gc_live_allocation_bytes() != input_payload) return !fail("trial payload did not drain");
    }
    PROCESS_MEMORY_COUNTERS memory = {0};
    if (!GetProcessMemoryInfo(GetCurrentProcess(), &memory, sizeof(memory))) return 1;
    inputs = output = cancel = NULL;
    for (int i = 2; i >= 0; --i) ube_gc_root_leave(&roots[i]);
    ube_gc_collect();
    if (ube_gc_root_count || ube_gc_live_allocation_bytes() || !drained()) return !fail("final cleanup failed");
    double total = now_seconds() - begin;
    printf("{\"jobs\":%d,\"repeats\":%d,\"sources\":%d,\"workSeconds\":%.9f,"
           "\"cpuSeconds\":%.9f,\"setupWarmupSeconds\":%.9f,\"outsideWorkSeconds\":%.9f,"
           "\"totalSeconds\":%.9f,\"peakWorkingSetBytes\":%llu,\"physicalCores\":%d,"
           "\"physicalMemoryBytes\":%llu,\"completeResults\":true,\"cleanup\":true}\n",
           jobs, repeats, count, wall, cpu, setup, total - wall, total,
           (unsigned long long)memory.PeakWorkingSetSize, cores,
           (unsigned long long)host_memory.ullTotalPhys);
    return 0;
}
