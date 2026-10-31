/* Independent assertions around actual UBE token-parser workers. Include after
   proof.c's snapshot/graph/wait helpers and before main. This witness does not
   claim operation overlap: its UBE workers have no work-operation hooks. The
   caller keeps Published rooted throughout, so collection survival below proves
   explicit retained references, not sole ownership by a worker. */
#ifndef UBE_SOURCE_SHARED_PROOF_H
#define UBE_SOURCE_SHARED_PROOF_H

static int shared_wait_for_worker(int64_t id) {
    ULONGLONG deadline = GetTickCount64() + 60000;
    for (;;) {
        uint64_t revision = ube_current_error_state()->revision;
        if (ube_thread_wait(id, 10))
            return 1;
        if (ube_current_error_state()->revision != revision)
            return 0;
        if (GetTickCount64() >= deadline)
            return 0;
    }
}

static int shared_snapshot(struct saved *destination, const struct shared_work *shared) {
    struct work view = {0};
    view.owner = shared->owner->owner;
    view.tokens = shared->owner->tokens;
    view.syntax = shared->syntax;
    view.failure = shared->failure;
    view.metrics = shared->metrics;
    view.id = shared->id;
    view.state = shared->state;
    return snapshot(destination, &view);
}

static int shared_original_equal(const struct work *owner, void *tokens, void *source_bytes,
                                 const unsigned char *original, int bytes, int content, int scalars,
                                 int lines) {
    if (owner->tokens != tokens || owner->owner->document.bytes != source_bytes ||
        owner->owner->document.content != content || owner->owner->document.scalars != scalars ||
        owner->owner->document.lines != lines ||
        ube_value_array_length(&owner->owner->document.bytes) != bytes)
        return 0;
    for (int index = 0; index < bytes; ++index) {
        if (*(unsigned char *)ube_array_element(source_bytes, index) != original[index])
            return 0;
    }
    return 1;
}

static int prove_shared_tokens(void *published, int count) {
    int success = 0, selected_index = -1, selected_bytes = -1;
    struct work *selected = NULL;
    void *selected_slot = NULL;
    void *slots[4] = {0};
    struct ube_gc_root selected_root = {0}, roots[4] = {{0}};
    int selected_rooted = 0, rooted[4] = {0};
    int64_t ids[4] = {0}, admitted_ids[4] = {0};
    struct saved expected = {0}, actual = {0};
    unsigned char *original = NULL;
    void *token_identity = NULL;
    void *byte_identity = NULL;
    int content = 0, scalars = 0, lines = 0;
    size_t before_roots = ube_gc_root_count;
    const int64_t caller_id = ube_thread_current_id();

#define SHARED_CHECK(condition, message)                                                           \
    do {                                                                                           \
        if (!require((condition), (message)))                                                      \
            goto cleanup;                                                                          \
    } while (0)

    SHARED_CHECK(count > 0 && ube_value_array_length(&published) == count,
                 "shared-token source set exists");
    SHARED_CHECK(!enabled && workers_drained(),
                 "shared-token witness begins after source workers drain");
    SHARED_CHECK(proof_layout(3)->size == sizeof(void *) && proof_layout(3)->kind == 3 &&
                     proof_layout(3)->root_count == 1,
                 "shared-token reference descriptor ABI");
    /* Exercise a substantial actual source rather than only the empty fixture. */
    for (int index = 0; index < count; ++index) {
        struct work *candidate = *(struct work **)ube_array_element(published, index);
        SHARED_CHECK(candidate && candidate->state == 1 && candidate->owner,
                     "shared-token selected source is complete");
        int bytes = ube_value_array_length(&candidate->owner->document.bytes);
        if (bytes > selected_bytes) {
            selected = candidate;
            selected_index = index;
            selected_bytes = bytes;
        }
    }
    selected_slot = selected;
    SHARED_CHECK(ube_gc_root_enter(&selected_root, &selected_slot),
                 "shared-token explicit source-work root");
    selected_rooted = 1;
    SHARED_CHECK(snapshot(&expected, selected) && graph_valid(&expected, selected_bytes),
                 "shared-token complete baseline graph");
    token_identity = selected->tokens;
    byte_identity = selected->owner->document.bytes;
    content = selected->owner->document.content;
    scalars = selected->owner->document.scalars;
    lines = selected->owner->document.lines;
    original = malloc(selected_bytes ? (size_t)selected_bytes : 1);
    SHARED_CHECK(original != NULL, "shared-token original-byte snapshot");
    for (int index = 0; index < selected_bytes; ++index)
        original[index] = *(unsigned char *)ube_array_element(byte_identity, index);

    for (int jobs = 1; jobs <= 4; jobs *= 2) {
        for (int index = 0; index < jobs; ++index) {
            SHARED_CHECK(ube_gc_root_enter(&roots[index], &slots[index]),
                         "shared-token private result root");
            rooted[index] = 1;
            proof_make_shared(selected, &slots[index]);
            struct shared_work *work = slots[index];
            SHARED_CHECK(work && work->owner == selected && work->state == 0 &&
                             work->owner->tokens == token_identity && work->syntax == NULL,
                         "actual UBE shared-token work creation retains owner identity");
            for (int prior = 0; prior < index; ++prior)
                SHARED_CHECK(slots[prior] != slots[index], "shared-token fresh work identities");
        }
        /* CallNew is inside the intact UBE StartSharedSyntax function. */
        for (int index = 0; index < jobs; ++index) {
            ids[index] = proof_start_shared(slots[index]);
            admitted_ids[index] = ids[index];
            SHARED_CHECK(ids[index] > 0 && ids[index] != caller_id,
                         "actual UBE shared-token worker admission");
            for (int prior = 0; prior < index; ++prior)
                SHARED_CHECK(ids[prior] != ids[index], "shared-token distinct program identities");
        }
        for (int index = 0; index < jobs; ++index) {
            SHARED_CHECK(shared_wait_for_worker(ids[index]), "shared-token actual completion wait");
            ids[index] = 0;
        }
        SHARED_CHECK(workers_drained(), "shared-token native workers drain");
        for (int index = 0; index < jobs; ++index) {
            struct shared_work *work = slots[index];
            SHARED_CHECK(work->owner == selected && work->owner->tokens == token_identity &&
                             work->state == 1 && work->failure.kind == 0 &&
                             work->id == admitted_ids[index] && work->id != caller_id,
                         "shared-token worker accepts with retained immutable identity");
            SHARED_CHECK(shared_snapshot(&actual, work) && equal_saved(&expected, &actual) &&
                             graph_valid(&actual, selected_bytes) &&
                             !memcmp(&work->metrics, &selected->metrics, sizeof work->metrics),
                         "shared-token complete nodes/tokens/failures/metrics match baseline");
            SHARED_CHECK(work->syntax != selected->syntax,
                         "shared-token private syntax array differs from original");
            struct result *result = ube_array_element(work->syntax, 0);
            struct result *source = ube_array_element(selected->syntax, 0);
            SHARED_CHECK(result->nodes != source->nodes,
                         "shared-token private graph differs from original");
            for (int prior = 0; prior < index; ++prior) {
                struct shared_work *other = slots[prior];
                struct result *other_result = ube_array_element(other->syntax, 0);
                SHARED_CHECK(work->syntax != other->syntax && result->nodes != other_result->nodes,
                             "shared-token worker result graphs are independent");
            }
            clear_saved(&actual);
        }
        SHARED_CHECK(shared_original_equal(selected, token_identity, byte_identity, original,
                                           selected_bytes, content, scalars, lines),
                     "shared-token workers preserve all original document bytes");

        /* Retain the first private work, release all other local owners, then
           collect. Published remains an additional owner held by the caller. */
        for (int index = jobs - 1; index > 0; --index) {
            ube_gc_root_leave(&roots[index]);
            rooted[index] = 0;
            slots[index] = NULL;
        }
        ube_gc_root_leave(&selected_root);
        selected_rooted = 0;
        selected_slot = NULL;
        ube_gc_collect();
        struct shared_work *retained = slots[0];
        SHARED_CHECK(retained->owner == selected && retained->owner->tokens == token_identity &&
                         shared_snapshot(&actual, retained) && equal_saved(&expected, &actual) &&
                         shared_original_equal(selected, token_identity, byte_identity, original,
                                               selected_bytes, content, scalars, lines),
                     "shared-token retained result and owner survive collection");
        clear_saved(&actual);
        ube_gc_root_leave(&roots[0]);
        rooted[0] = 0;
        slots[0] = NULL;
        ube_gc_collect();
        SHARED_CHECK(snapshot(&actual, selected) && equal_saved(&expected, &actual),
                     "shared-token original published result remains unchanged");
        clear_saved(&actual);
        SHARED_CHECK(ube_gc_root_count == before_roots,
                     "shared-token private roots return to baseline");
        printf("{\"suite\":\"shared-tokens\",\"jobs\":%d,\"source\":%d,"
               "\"bytes\":%d,\"tokens\":%d,\"nodes\":%d,"
               "\"completeEqual\":true,\"privateGraphs\":true,"
               "\"collectionSurvival\":true,\"operationOverlapClaimed\":false}\n",
               jobs, selected_index, selected_bytes, expected.tokens, expected.count);
        if (jobs < 4) {
            selected_slot = selected;
            SHARED_CHECK(ube_gc_root_enter(&selected_root, &selected_slot),
                         "shared-token next batch source-work root");
            selected_rooted = 1;
        }
    }
    success = 1;

cleanup:
    /* Even an assertion failure keeps admitted captures/owners rooted to drain. */
    for (int index = 0; index < 4; ++index)
        if (ids[index] > 0)
            (void)ube_thread_request_stop(ids[index]);
    for (int index = 0; index < 4; ++index) {
        if (ids[index] > 0 && !shared_wait_for_worker(ids[index]))
            success = 0;
    }
    if (!workers_drained())
        success = 0;
    for (int index = 3; index >= 0; --index) {
        if (rooted[index])
            ube_gc_root_leave(&roots[index]);
        slots[index] = NULL;
    }
    if (selected_rooted)
        ube_gc_root_leave(&selected_root);
    selected_slot = NULL;
    clear_saved(&expected);
    clear_saved(&actual);
    free(original);
    ube_gc_collect();
    if (!require(ube_gc_root_count == before_roots,
                 "shared-token witness releases every private root"))
        success = 0;
#undef SHARED_CHECK
    return success;
}
#endif
