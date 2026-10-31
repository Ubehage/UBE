/* Independent boundary assertions against the intact UBE coordinator. */
static int prove_source_schedules(void **inputs, void **output, void *cancellation, int count) {
    for (int schedule = 0; schedule < 2; ++schedule) {
        struct set_failure failure = {5, -1, {0}};
        begin_observation(count, 4, schedule ? MODE_REVERSE : MODE_SERIAL, cancellation);
        int ok = proof_sources(inputs, 4, 1048576, 1048576, 1048576, 256, cancellation, output,
                               &failure);
        end_observation();
        if (!require(ok && failure.kind == 0 && !infrastructure_error && workers_drained() &&
                         output_equal(*output, count),
                     "full results under serialized control/reversed native completion"))
            return 0;
        if (!schedule &&
            !require(
                maximum_active == 4 && op_switches == 0,
                "serialization negative control parks workers without actual operation overlap"))
            return 0;
        printf("{\"suite\":\"schedule\",\"serialControl\":%s,\"operationSwitches\":%ld,"
               "\"peakEntered\":%ld}\n",
               schedule ? "false" : "true", op_switches, maximum_active);
    }
    return 1;
}
static int replace_fixture(void **inputs, int index, int fixture) {
    void *bytes = NULL;
    struct ube_gc_root root = {0};
    if (!ube_gc_root_enter(&root, &bytes))
        return 0;
    int ok = bytes_array(&bytes, corpus[fixture].data, corpus[fixture].bytes) &&
             proof_make(&bytes, index, ube_array_element(*inputs, index));
    ube_gc_root_leave(&root);
    return ok;
}
static int prove_source_boundaries(void **inputs, void **output, void *cancellation, int count) {
    void *old = *output;
    struct set_failure failure;
    int ok;
    if (!require(make_inputs(inputs, 4, -1),
                 "focused boundary inputs retain the full earlier published graph"))
        return 0;
    /* Independent frozen reject witness: the complete End Type statement. */
    const struct corpus_case *bad = &corpus[corpus_count - 2];
    int bad_first = -1;
    for (int i = 0; i <= bad->bytes - 8; ++i)
        if (!memcmp(bad->data + i, "End Type", 8)) {
            bad_first = i;
            break;
        }
    if (!require(bad_first >= 0, "independent rejected source byte witness"))
        return 0;
    /* Lowest canonical source wins even when later work drains first. */
    for (int flip = 0; flip < 2; ++flip) {
        struct set_failure first_failure = {0};
        if (!require(replace_fixture(inputs, 1, corpus_count - 2 + flip) &&
                         replace_fixture(inputs, 2, corpus_count - 1 - flip),
                     "independent reject/deferred fixtures"))
            return 0;
        for (int jobs = 1; jobs <= 4; jobs *= 2) {
            failure = (struct set_failure){5, -1, {0}};
            begin_observation(4, jobs, jobs == 4 ? MODE_REVERSE : MODE_NORMAL, cancellation);
            ok = proof_sources(inputs, jobs, 1048576, 1048576, 1048576, 256, cancellation, output,
                               &failure);
            end_observation();
            if (!require(
                    !ok && failure.kind == 3 && failure.source == 1 &&
                        failure.unit.kind == (flip ? 3 : 104) && *output == old &&
                        workers_drained() && output_equal(*output, count) && !infrastructure_error,
                    "canonical complete first diagnostic independent of worker/reversed drain"))
                return 0;
            if (!flip &&
                !require(failure.unit.first == bad_first && failure.unit.last == bad_first + 8,
                         "independent complete reject diagnostic byte span"))
                return 0;
            if (jobs == 1)
                first_failure = failure;
            else if (!require(!memcmp(&first_failure, &failure, sizeof failure),
                              "full first kind/source/byte span identical across worker/reversed "
                              "completion schedules"))
                return 0;
            printf("{\"suite\":\"firstFailure\",\"jobs\":%d,\"source\":%d,\"kind\":%d,\"first\":%d,"
                   "\"last\":%d}\n",
                   jobs, failure.source, failure.unit.kind, failure.unit.first, failure.unit.last);
        }
    }
    if (!require(make_inputs(inputs, 4, -1), "restore focused valid boundary inputs"))
        return 0;
    /* Domain errors must not touch any source or output. */
    for (int jobs = 0; jobs <= 5; jobs += 5) {
        failure = (struct set_failure){5, -1, {0}};
        ok = proof_sources(inputs, jobs, 1048576, 1048576, 1048576, 256, cancellation, output,
                           &failure);
        if (!require(!ok && failure.kind == 1 && failure.source == -1 && *output == old &&
                         output_equal(*output, count),
                     "invalid worker budget domain"))
            return 0;
    }
    const int limits[4][4] = {{1, 1048576, 1048576, 256},
                              {1048576, 0, 1048576, 256},
                              {1048576, 1048576, 0, 256},
                              {1048576, 1048576, 1048576, 0}};
    for (int limit = 0; limit < 4; ++limit) {
        if (limit == 3 && !require(replace_fixture(inputs, 3, corpus_depth_case),
                                   "actual nested statement for depth-budget boundary"))
            return 0;
        failure = (struct set_failure){5, -1, {0}};
        ok = proof_sources(inputs, 2, limits[limit][0], limits[limit][1], limits[limit][2],
                           limits[limit][3], cancellation, output, &failure);
        int expected = limit == 0 ? 206 : 2;
        printf("{\"suite\":\"limit\",\"limit\":%d,\"status\":%d,\"kind\":%d,\"source\":%d,"
               "\"unitKind\":%d}\n",
               limit, ok, failure.kind, failure.source, failure.unit.kind);
        if (!require(!ok && failure.kind == 3 && failure.unit.kind == expected && *output == old &&
                         workers_drained() && output_equal(*output, count),
                     "source token/node/pending/depth resource boundary"))
            return 0;
    }
    /* Empty input succeeds for every allowed budget without dispatch. */
    void *empty = NULL;
    void *empty_result = *output;
    struct ube_gc_root root = {0};
    if (!require(ube_gc_root_enter(&root, &empty_result), "empty publication owner"))
        return 0;
    for (int jobs = 1; jobs <= 4; jobs *= 2) {
        failure = (struct set_failure){5, -1, {0}};
        begin_observation(0, jobs, MODE_NORMAL, cancellation);
        ok = proof_sources(&empty, jobs, 0, 0, 0, 0, cancellation, &empty_result, &failure);
        end_observation();
        if (!require(ok && failure.kind == 0 && failure.source == -1 && entered == 0 &&
                         capture_bytes == 0 && ube_value_array_length(&empty_result) == 0,
                     "empty set accepted without workers")) {
            ube_gc_root_leave(&root);
            return 0;
        }
    }
    if (!require(make_inputs(inputs, 1, -1), "one source for a larger worker budget")) {
        ube_gc_root_leave(&root);
        return 0;
    }
    failure = (struct set_failure){5, -1, {0}};
    begin_observation(1, 4, MODE_NORMAL, cancellation);
    published_slot = &empty_result;
    ok = proof_sources(inputs, 4, 1048576, 1048576, 1048576, 256, cancellation, &empty_result,
                       &failure);
    end_observation();
    if (!require(ok && failure.kind == 0 && entered == 1 && exited == 1 && maximum_active == 1 &&
                     workers_drained() && output_equal(empty_result, 1) && publication_bytes == 8,
                 "one-source Jobs4 dispatches one worker and publishes one reference")) {
        ube_gc_root_leave(&root);
        return 0;
    }
    void *one_result = empty_result;
    failure = (struct set_failure){5, -1, {0}};
    ok = proof_sources(inputs, 4, 0, 1048576, 1048576, 256, cancellation, &empty_result, &failure);
    if (!require(!ok && failure.kind == 3 && failure.source == 0 && failure.unit.kind == 207 &&
                     empty_result == one_result && output_equal(empty_result, 1) &&
                     *output == old && output_equal(*output, count) && workers_drained(),
                 "nonempty token-zero preserves established scanner domain207 and complete prior "
                 "output")) {
        ube_gc_root_leave(&root);
        return 0;
    }
    puts("{\"suite\":\"smallInputs\",\"oneSourceJobsFour\":true,\"zeroTokenKind\":207}");
    ube_gc_root_leave(&root);
    if (!require(make_inputs(inputs, count, -1),
                 "restore full production corpus after focused boundary cases"))
        return 0;
    puts("{\"suite\":\"boundaries\",\"canonicalFailures\":6,\"limits\":4,\"emptyBudgets\":3}");
    return 1;
}
