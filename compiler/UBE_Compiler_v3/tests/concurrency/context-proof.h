/* Independent assertions for two simultaneous UBE coordinator invocations.
   Include after proof.c's snapshot/comparison/drain helpers. */
struct source_context {
    void *inputs;
    void *published;
    struct cancellation *cancellation;
    struct set_failure failure;
    int64_t id;
    int32_t state;
};
_Static_assert(sizeof(struct source_context) == 64 &&
                   offsetof(struct source_context, failure) == 24 &&
                   offsetof(struct source_context, id) == 48 &&
                   offsetof(struct source_context, state) == 56,
               "independent context payload ABI");
extern void proof_make_context(void **, void **);
extern int64_t proof_start_context(void *);

static void *context_observed[2];
static int64_t context_ids[2];
static DWORD context_native[2];
static volatile LONG context_arrived, context_gate, context_bad_hook;

/* Only a test rendezvous. Both intact UBE coordinators perform their real work
   after admission; the main source proof separately observes operation overlap. */
void observe_context_enter(void *context) {
    int index = context == context_observed[0] ? 0 : context == context_observed[1] ? 1 : -1;
    if (index < 0) {
        InterlockedExchange(&context_bad_hook, 1);
        InterlockedExchange(&context_gate, 1);
        return;
    }
    context_ids[index] = ube_thread_current_id();
    context_native[index] = GetCurrentThreadId();
    if (InterlockedIncrement(&context_arrived) == 2)
        InterlockedExchange(&context_gate, 1);
    while (!InterlockedCompareExchange(&context_gate, 0, 0))
        SwitchToThread();
}

static int prove_independent_contexts(void *inputs, int count) {
    void *contexts[2] = {NULL, NULL};
    struct ube_gc_root roots[2] = {{0}};
    int64_t ids[2] = {0, 0};
    size_t before_roots = ube_gc_root_count;
    DWORD before_handles = 0, after_handles = 0;
    int success = 1, root_count = 0;
    struct saved actual = {0};
    if (!require(!enabled, "independent contexts use separate observation state"))
        return 0;
    if (!require(proof_payload_size(4) == 64, "emitted context payload size"))
        return 0;
    const struct ube_value_layout *reference = proof_layout(5);
    if (!require(reference && reference->kind == 3 && reference->size == sizeof(void *) &&
                     reference->root_count == 1 && reference->root_offsets[0] == 0,
                 "emitted context reference uses the checked shared-owner layout"))
        return 0;
    if (!require(GetProcessHandleCount(GetCurrentProcess(), &before_handles),
                 "independent context handle baseline"))
        return 0;
    context_arrived = context_gate = context_bad_hook = 0;
    memset(context_ids, 0, sizeof context_ids);
    memset(context_native, 0, sizeof context_native);
    for (int i = 0; i < 2; ++i) {
        if (!require(ube_gc_root_enter(&roots[i], &contexts[i]), "private context root")) {
            success = 0;
            goto cleanup;
        }
        ++root_count;
        proof_make_context(&inputs, &contexts[i]);
        if (!require(contexts[i] != NULL, "actual UBE independent context allocation")) {
            success = 0;
            goto cleanup;
        }
        context_observed[i] = contexts[i];
    }
    struct source_context *first = contexts[0];
    struct source_context *second = contexts[1];
    if (!require(first != second && first->inputs != second->inputs && first->inputs != inputs &&
                     second->inputs != inputs && first->cancellation != NULL &&
                     second->cancellation != NULL && first->cancellation != second->cancellation &&
                     ube_value_array_length(&first->inputs) == count &&
                     ube_value_array_length(&second->inputs) == count,
                 "independent invocation vectors and cancellation state")) {
        success = 0;
        goto cleanup;
    }
    for (int i = 0; i < count; ++i) {
        void *owner = *(void **)ube_array_element(inputs, i);
        if (!require(*(void **)ube_array_element(first->inputs, i) == owner &&
                         *(void **)ube_array_element(second->inputs, i) == owner,
                     "independent callers retain identical immutable input owners")) {
            success = 0;
            goto cleanup;
        }
    }
    for (int i = 0; i < 2; ++i) {
        ids[i] = proof_start_context(contexts[i]);
        if (!require(ids[i] > 0, "actual UBE coordinator CallNew admission")) {
            success = 0;
            goto cleanup;
        }
    }
    for (int i = 0; i < 2; ++i) {
        if (!require(ube_thread_wait(ids[i], 120000), "actual UBE coordinator completion")) {
            success = 0;
            goto cleanup;
        }
    }
    if (!require(workers_drained() && context_arrived == 2 && !context_bad_hook &&
                     context_ids[0] == ids[0] && context_ids[1] == ids[1] &&
                     context_ids[0] != context_ids[1] && context_native[0] != context_native[1] &&
                     context_native[0] != GetCurrentThreadId() &&
                     context_native[1] != GetCurrentThreadId(),
                 "two distinct admitted UBE coordinators rendezvous and drain")) {
        success = 0;
        goto cleanup;
    }
    for (int i = 0; i < 2; ++i) {
        struct source_context *context = contexts[i];
        if (!require(context->state == 1 && context->id == ids[i] && context->failure.kind == 0 &&
                         context->failure.source == -1 && context->failure.unit.kind == 0 &&
                         context->failure.unit.first == 0 && context->failure.unit.last == 0 &&
                         !context->cancellation->requested &&
                         ube_value_array_length(&context->published) == count,
                     "each independent invocation reports complete fresh success")) {
            success = 0;
            goto cleanup;
        }
        for (int j = 0; j < count; ++j) {
            struct work *work = *(struct work **)ube_array_element(context->published, j);
            if (!require(work->owner == *(struct owner **)ube_array_element(inputs, j) &&
                             work->id > 0 && work->id != ids[i] && snapshot(&actual, work) &&
                             equal_saved(&actual, &baseline[j]) &&
                             graph_valid(&actual, corpus[j].bytes),
                         "each independent invocation equals full serial tokens, nodes, metrics "
                         "and source association")) {
                success = 0;
                goto cleanup;
            }
        }
    }
    if (!require(first->published != second->published,
                 "independent complete publication vectors")) {
        success = 0;
        goto cleanup;
    }
    for (int i = 0; i < count; ++i) {
        struct work *a = *(struct work **)ube_array_element(first->published, i);
        struct work *b = *(struct work **)ube_array_element(second->published, i);
        struct result *ar = ube_array_element(a->syntax, 0);
        struct result *br = ube_array_element(b->syntax, 0);
        if (!require(
                a != b && a->tokens != b->tokens && a->syntax != b->syntax &&
                    ar->nodes != br->nodes,
                "independent parser workers publish disjoint mutable work and result graphs")) {
            success = 0;
            goto cleanup;
        }
    }
cleanup:
    /* A failed second admission must release the first rendezvous before drain. */
    InterlockedExchange(&context_gate, 1);
    if (!success) {
        for (int i = 0; i < 2; ++i)
            if (contexts[i])
                __atomic_store_n(&((struct source_context *)contexts[i])->cancellation->requested,
                                 1, __ATOMIC_SEQ_CST);
        for (int i = 0; i < 2; ++i)
            if (ids[i] > 0)
                ube_thread_wait(ids[i], 120000);
    }
    if (!require(workers_drained(), "independent context cleanup drains every owned worker"))
        success = 0;
    clear_saved(&actual);
    while (root_count)
        ube_gc_root_leave(&roots[--root_count]);
    contexts[0] = contexts[1] = NULL;
    context_observed[0] = context_observed[1] = NULL;
    ube_gc_collect();
    /* Registry removal precedes final native record/event release. Observe the
       actual handle release instead of assuming it accompanies completion. */
    ULONGLONG handle_deadline = GetTickCount64() + 5000;
    while (GetProcessHandleCount(GetCurrentProcess(), &after_handles) &&
           after_handles != before_handles && GetTickCount64() < handle_deadline)
        Sleep(1);
    if (!require(ube_gc_root_count == before_roots &&
                     GetProcessHandleCount(GetCurrentProcess(), &after_handles) &&
                     after_handles == before_handles,
                 "independent contexts release procedure roots, captures and handles"))
        success = 0;
    if (success)
        puts("{\"suite\":\"independent-contexts\",\"coordinators\":2,\"jobsEach\":1,"
             "\"completeResultsEqual\":true}");
    return success;
}
