/* Independent assertions/observations. All compiler work and scheduling is UBE. */
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>
static void observe_copy(size_t);
static void *observed_malloc(size_t);
static void *observed_calloc(size_t, size_t);
static void *observed_realloc(void *, size_t);
static void observed_free(void *);
static void observe_root_count(size_t);
static void observe_payload_count(size_t);
static void observe_lock_before(void);
static void observe_lock_after(void);
static void observe_lock_release(void);
#define malloc observed_malloc
#define calloc observed_calloc
#define realloc observed_realloc
#define free observed_free
#define UBE_VALUE_OBSERVE_COPY(n) observe_copy(n)
#include "observed_runtime.c"
#undef malloc
#undef calloc
#undef realloc
#undef free

struct position {
    int32_t byte, scalar, line, column;
};
struct document {
    void *bytes;
    int32_t content, scalars, lines;
};
struct token {
    int32_t kind;
    struct position first, last;
};
struct node {
    int32_t kind, first, last, child, next, children;
};
struct result {
    void *nodes;
    int32_t count, root, source;
};
struct failure {
    int32_t kind, first, last;
};
struct metrics {
    int32_t reads, actions, names, pending, depth;
};
struct owner {
    struct document document;
    int32_t id;
};
struct work {
    struct owner *owner;
    void *tokens;
    void *syntax;
    struct failure failure;
    struct metrics metrics;
    int64_t id;
    int32_t state, maxtokens, maxnodes, maxpending, maxdepth;
};
struct set_failure {
    int32_t kind, source;
    struct failure unit;
};
struct cancellation {
    uint8_t requested;
};
struct shared_work {
    struct work *owner;
    void *syntax;
    struct failure failure;
    struct metrics metrics;
    int64_t id;
    int32_t state;
};
_Static_assert(sizeof(struct owner) == 32 && sizeof(struct work) == 88 &&
                   sizeof(struct shared_work) == 64,
               "independent class payload ABI");
extern int32_t proof_make(void **, int32_t, void **);
extern int32_t proof_sources(void **, int32_t, int32_t, int32_t, int32_t, int32_t, void *, void **,
                             struct set_failure *);
extern void proof_new_cancel(void **);
extern void proof_make_shared(void *, void **);
extern int64_t proof_start_shared(void *);
extern const struct ube_value_layout *proof_layout(int32_t);
extern size_t proof_payload_size(int32_t);
extern const struct ube_gc_layout *proof_object_layout(int32_t);
extern void proof_make_context(void **, void **);
extern int64_t proof_start_context(void *);
#include "corpus.h"

enum { MAX_UNITS = 256 };
struct saved {
    int state;
    struct failure failure;
    struct metrics metrics;
    int count, root;
    struct node *nodes;
    int tokens;
    struct token *token_data;
};
struct row {
    int64_t id;
    DWORD native;
    ULONGLONG begin, end, cpu;
    uint64_t bytes, allocations, requested, copies, lock_count, lock_wait, lock_hold;
};
static struct row rows[MAX_UNITS];
static struct saved saved[MAX_UNITS], baseline[MAX_UNITS];
static _Thread_local struct work *current;
static _Thread_local int copy_role;
static _Thread_local int publication_scope;
static _Thread_local int lock_depth, lock_tracked;
static _Thread_local LONGLONG lock_requested, lock_acquired;
static volatile LONG enabled, active, maximum_active, entered, exited, op_switches,
    operation_active[MAX_UNITS];
static volatile LONG gate_target, gate_open, last_reader = -1;
static volatile LONG mode, deny_all, fail_work_allocations;
static volatile LONG64 allocation_calls, requested_bytes, copy_bytes, source_copies, capture_bytes;
static void *volatile capture_slots[32];
static void *volatile record_slots[32];
static volatile LONG capture_live, record_live;
static volatile LONG publication_cancel_fired;
static volatile LONG starts_after_request;
static volatile LONG publication_events;
static volatile LONG64 publication_bytes;
static struct cancellation *active_cancel;
static void **published_slot;
static size_t root_baseline, root_peak;
static volatile LONG64 payload_peak;
static size_t payload_baseline;
static int observed_count;
static volatile LONG infrastructure_error;
static SRWLOCK observation_lock = SRWLOCK_INIT;
enum {
    MODE_NORMAL,
    MODE_ENTER_CANCEL,
    MODE_WORK_CANCEL,
    MODE_BEFORE_PUBLISH,
    MODE_AFTER_ADMISSION,
    MODE_START_FAIL,
    MODE_WAIT_FAIL,
    MODE_WORK_ALLOC_FAIL,
    MODE_SERIAL,
    MODE_PUBLICATION_ROOT,
    MODE_PUBLICATION_ALLOC,
    MODE_REVERSE,
    MODE_WORKER_ROOT
};
static int reverse_jobs;
static void reverse_completion(int id) {
    if (mode != MODE_REVERSE || id >= reverse_jobs - 1)
        return;
    ULONGLONG until = GetTickCount64() + 60000;
    while (!ube_thread_wait(rows[id + 1].id, 100)) {
        if (GetTickCount64() > until) {
            InterlockedExchange(&infrastructure_error, 1);
            break;
        }
    }
}
static SRWLOCK serial_lock = SRWLOCK_INIT;
static LONGLONG tick_now(void) {
    LARGE_INTEGER value;
    QueryPerformanceCounter(&value);
    return value.QuadPart;
}
static void observe_lock_before(void) {
    if (!lock_depth && enabled && current)
        lock_requested = tick_now();
}
static void observe_lock_after(void) {
    if (lock_depth++ == 0 && enabled && current) {
        lock_acquired = tick_now();
        ++rows[current->owner->id].lock_count;
        rows[current->owner->id].lock_wait += (uint64_t)(lock_acquired - lock_requested);
        lock_tracked = 1;
    }
}
static void observe_lock_release(void) {
    if (--lock_depth == 0 && lock_tracked) {
        rows[current->owner->id].lock_hold += (uint64_t)(tick_now() - lock_acquired);
        lock_tracked = 0;
    }
}
static void observe_root_count(size_t n) {
    if (enabled) {
        LONG64 old = InterlockedCompareExchange64((volatile LONG64 *)&root_peak, 0, 0);
        while (n > (size_t)old) {
            LONG64 found =
                InterlockedCompareExchange64((volatile LONG64 *)&root_peak, (LONG64)n, old);
            if (found == old)
                break;
            old = found;
        }
    }
}
static void observe_payload_count(size_t n) {
    if (enabled) {
        LONG64 old = InterlockedCompareExchange64(&payload_peak, 0, 0);
        while (n > (size_t)old) {
            LONG64 found = InterlockedCompareExchange64(&payload_peak, (LONG64)n, old);
            if (found == old)
                break;
            old = found;
        }
    }
}
static struct ube_gc_root *pressure;
static size_t pressure_count;
static void *neutral;
static void retain_native(void *volatile *slots, void *p, volatile LONG *count) {
    for (int i = 0; i < 32; ++i)
        if (!InterlockedCompareExchangePointer(&slots[i], p, NULL)) {
            InterlockedIncrement(count);
            return;
        }
    InterlockedExchange(&infrastructure_error, 1);
}

static uint64_t cpu_now(void) {
    FILETIME a, b, c, d;
    ULARGE_INTEGER x, y;
    if (!GetThreadTimes(GetCurrentThread(), &a, &b, &c, &d))
        return 0;
    x.LowPart = c.dwLowDateTime;
    x.HighPart = c.dwHighDateTime;
    y.LowPart = d.dwLowDateTime;
    y.HighPart = d.dwHighDateTime;
    return x.QuadPart + y.QuadPart;
}
static void update_peak(void) {
    ube_gc_enter_lock();
    observe_root_count(ube_gc_root_count);
    ube_gc_leave_lock();
}
static int reject_allocation(size_t bytes) {
    if (!enabled)
        return 0;
    InterlockedIncrement64(&allocation_calls);
    InterlockedExchangeAdd64(&requested_bytes, (LONG64)bytes);
    if (current) {
        ++rows[current->owner->id].allocations;
        rows[current->owner->id].requested += bytes;
    }
    return deny_all || (current && fail_work_allocations);
}
static void *observed_malloc(size_t n) { return reject_allocation(n) ? NULL : malloc(n); }
static void *observed_calloc(size_t n, size_t w) {
    if (w && n > SIZE_MAX / w)
        return NULL;
    int capture = enabled && n == 1 && w == sizeof(struct ube_thread_capture) + 8;
    int record = enabled && n == 1 && w == sizeof(struct ube_thread_record);
    void *p = reject_allocation(n * w) ? NULL : calloc(n, w);
    if (p && capture) {
        InterlockedExchangeAdd64(&capture_bytes, 8);
        retain_native(capture_slots, p, &capture_live);
    }
    if (p && record)
        retain_native(record_slots, p, &record_live);
    return p;
}
static void *observed_realloc(void *p, size_t n) {
    return reject_allocation(n) ? NULL : realloc(p, n);
}
static void observed_free(void *p) {
    if (p)
        for (int i = 0; i < 32; ++i) {
            if (InterlockedCompareExchangePointer(&capture_slots[i], NULL, p) == p)
                InterlockedDecrement(&capture_live);
            if (InterlockedCompareExchangePointer(&record_slots[i], NULL, p) == p)
                InterlockedDecrement(&record_live);
        }
    free(p);
}
static void observe_copy(size_t n) {
    if (!enabled)
        return;
    InterlockedExchangeAdd64(&copy_bytes, (LONG64)n);
    if (publication_scope)
        InterlockedExchangeAdd64(&publication_bytes, (LONG64)n);
    if (copy_role == 1)
        InterlockedExchangeAdd64(&source_copies, (LONG64)n);
    if (current)
        rows[current->owner->id].copies += n;
}

/* Redirected calls retain the actual runtime operation; only observations differ. */
int32_t observed_resize(void **p, int32_t n, const struct ube_value_layout *l, int32_t keep) {
    int old = copy_role;
    copy_role = l == proof_layout(4) ? 1 : 0;
    int32_t ok = ube_value_try_resize(p, n, l, keep);
    copy_role = old;
    return ok;
}
int32_t observed_assign(void *to, const void *from, const struct ube_value_layout *l) {
    int old = copy_role, prior_publication = publication_scope;
    publication_scope = enabled && to == published_slot;
    if (publication_scope) {
        InterlockedIncrement(&publication_events);
        if (l->kind != 1 || l->field_count != 1 || !l->fields || l->fields[0].layout->kind != 3 ||
            l->fields[0].layout->size != 8)
            InterlockedExchange(&infrastructure_error, 1);
    }
    copy_role = (l->kind == 1 && l->fields && l->fields[0].layout == proof_layout(4)) ? 1 : 0;
    if (enabled && to == published_slot && mode == MODE_AFTER_ADMISSION) {
        InterlockedIncrement(&publication_cancel_fired);
        __atomic_store_n(&active_cancel->requested, 1, __ATOMIC_SEQ_CST);
    }
    int32_t ok = ube_value_assign(to, from, l);
    publication_scope = prior_publication;
    copy_role = old;
    return ok;
}
void *observed_element(void *const *holder, int32_t index, void **keep, void *fallback,
                       const struct ube_value_layout *l) {
    void *result = ube_value_array_element(holder, index, keep, fallback, l);
    if (enabled && current && l == proof_layout(4)) {
        int id = current->owner->id;
        ++rows[id].bytes;
        AcquireSRWLockExclusive(&observation_lock);
        if (last_reader >= 0 && last_reader != id && operation_active[last_reader])
            ++op_switches;
        operation_active[id] = 1;
        last_reader = id;
        ReleaseSRWLockExclusive(&observation_lock);
        if (mode == MODE_WORK_CANCEL && rows[id].bytes == 1)
            __atomic_store_n(&active_cancel->requested, 1, __ATOMIC_SEQ_CST);
    }
    return result;
}

static void clear_saved(struct saved *s) {
    free(s->nodes);
    free(s->token_data);
    memset(s, 0, sizeof *s);
}
static int snapshot(struct saved *out, struct work *work) {
    clear_saved(out);
    out->state = work->state;
    out->failure = work->failure;
    out->metrics = work->metrics;
    out->tokens = ube_value_array_length(&work->tokens);
    if (out->tokens) {
        out->token_data = malloc((size_t)out->tokens * sizeof(struct token));
        if (!out->token_data)
            return 0;
        for (int i = 0; i < out->tokens; ++i)
            out->token_data[i] = *(struct token *)ube_array_element(work->tokens, i);
    }
    if (work->state == 1) {
        if (ube_value_array_length(&work->syntax) != 1)
            return 0;
        struct result *result = ube_array_element(work->syntax, 0);
        out->count = result->count;
        out->root = result->root;
        if (result->source != work->owner->id || out->count < 1 || out->root < 0 ||
            out->root >= out->count || ube_value_array_length(&result->nodes) != out->count)
            return 0;
        out->nodes = malloc((size_t)out->count * sizeof(struct node));
        if (!out->nodes)
            return 0;
        for (int i = 0; i < out->count; ++i)
            out->nodes[i] = *(struct node *)ube_array_element(result->nodes, i);
    }
    return 1;
}
static int equal_saved(const struct saved *a, const struct saved *b) {
    return a->state == b->state && !memcmp(&a->failure, &b->failure, sizeof a->failure) &&
           !memcmp(&a->metrics, &b->metrics, sizeof a->metrics) &&
           !memcmp(&a->metrics, &b->metrics, sizeof a->metrics) && a->count == b->count &&
           a->root == b->root && a->tokens == b->tokens &&
           (!a->count || !memcmp(a->nodes, b->nodes, (size_t)a->count * sizeof(struct node))) &&
           (!a->tokens ||
            !memcmp(a->token_data, b->token_data, (size_t)a->tokens * sizeof(struct token)));
}
static int output_equal(void *output, int count) {
    if (ube_value_array_length(&output) != count)
        return 0;
    struct saved actual = {0};
    for (int i = 0; i < count; ++i) {
        struct work *w = *(struct work **)ube_array_element(output, i);
        int original = ube_value_array_length(&w->owner->document.bytes) == corpus[i].bytes;
        for (int j = 0; original && j < corpus[i].bytes; ++j)
            original =
                *(uint8_t *)ube_array_element(w->owner->document.bytes, j) == corpus[i].data[j];
        if (!original || !snapshot(&actual, w) || !equal_saved(&baseline[i], &actual)) {
            clear_saved(&actual);
            return 0;
        }
    }
    clear_saved(&actual);
    return 1;
}
static int graph_valid(const struct saved *s, int bytes) {
    if (s->state != 1)
        return 1;
    uint8_t *seen = calloc((size_t)s->count, 1);
    int32_t *stack = malloc((size_t)s->count * sizeof(*stack));
    if (!seen || !stack) {
        free(seen);
        free(stack);
        return 0;
    }
    int count = 1, total = 0, valid = 1;
    stack[0] = s->root;
    while (count && valid) {
        int i = stack[--count];
        if (i < 0 || i >= s->count || seen[i]) {
            valid = 0;
            break;
        }
        seen[i] = 1;
        ++total;
        struct node n = s->nodes[i];
        if (n.kind < 1 || n.first < 0 || n.last < n.first || n.last > bytes || n.children < 0 ||
            n.children >= s->count) {
            valid = 0;
            break;
        }
        int child = n.child, previous = n.first;
        for (int j = 0; j < n.children; ++j) {
            if (child < 0 || child >= s->count || count >= s->count) {
                valid = 0;
                break;
            }
            struct node c = s->nodes[child];
            if (c.first < previous || c.last > n.last) {
                valid = 0;
                break;
            }
            previous = c.last;
            stack[count++] = child;
            child = c.next;
        }
        if (child != -1)
            valid = 0;
    }
    free(seen);
    free(stack);
    return valid && total == s->count;
}

/* Hooks are inserted after actual Sub admission and before its root cleanup. */
void observe_work_enter(struct work *work) {
    if (!enabled)
        return;
    current = work;
    int id = work->owner->id;
    rows[id].id = ube_thread_current_id();
    rows[id].native = GetCurrentThreadId();
    LONG n = InterlockedIncrement(&active), peak = maximum_active;
    while (n > peak) {
        LONG old = InterlockedCompareExchange(&maximum_active, n, peak);
        if (old == peak)
            break;
        peak = old;
    }
    LONG arrived = InterlockedIncrement(&entered);
    if (mode == MODE_ENTER_CANCEL && arrived == 1)
        __atomic_store_n(&active_cancel->requested, 1, __ATOMIC_SEQ_CST);
    if (arrived >= gate_target)
        InterlockedExchange(&gate_open, 1);
    while (!InterlockedCompareExchange(&gate_open, 0, 0))
        SwitchToThread();
    if (mode == MODE_WAIT_FAIL) {
        ULONGLONG deadline = GetTickCount64() + 60000;
        for (;;) {
            ube_thread_enter_lock();
            uint32_t pending = ube_thread_test_wait_failures;
            ube_thread_leave_lock();
            if (!pending)
                break;
            if (GetTickCount64() > deadline) {
                InterlockedExchange(&infrastructure_error, 1);
                break;
            }
            SwitchToThread();
        }
    }
    if (mode == MODE_SERIAL)
        AcquireSRWLockExclusive(&serial_lock);
    rows[id].begin = GetTickCount64();
    rows[id].cpu = cpu_now();
    update_peak();
}
void observe_work_exit(struct work *work) {
    if (!enabled || current != work)
        return;
    int id = work->owner->id;
    reverse_completion(id);
    rows[id].cpu = cpu_now() - rows[id].cpu;
    rows[id].end = GetTickCount64();
    AcquireSRWLockExclusive(&observation_lock);
    operation_active[id] = 0;
    ReleaseSRWLockExclusive(&observation_lock);
    if (!snapshot(&saved[id], work))
        InterlockedExchange(&infrastructure_error, 1);
    if (mode == MODE_SERIAL)
        ReleaseSRWLockExclusive(&serial_lock);
    InterlockedDecrement(&active);
    InterlockedIncrement(&exited);
    current = NULL;
}
static void fill_root_pressure(void) {
    ube_gc_enter_lock();
    size_t available = UBE_GC_MAX_ROOTS - ube_gc_root_count;
    ube_gc_leave_lock();
    for (size_t i = 0; i < available; ++i) {
        if (!ube_gc_root_enter(&pressure[i], &neutral)) {
            InterlockedExchange(&infrastructure_error, 1);
            break;
        }
        ++pressure_count;
    }
}
void observe_publication(struct cancellation *cancellation) {
    if (!enabled)
        return;
    if (mode == MODE_BEFORE_PUBLISH)
        __atomic_store_n(&cancellation->requested, 1, __ATOMIC_SEQ_CST);
    if (mode == MODE_PUBLICATION_ALLOC)
        deny_all = 1;
    if (mode == MODE_PUBLICATION_ROOT)
        fill_root_pressure();
}
void observe_publication_end(void) {
    deny_all = 0;
    while (pressure_count)
        ube_gc_root_leave(&pressure[--pressure_count]);
}
int64_t observed_start(ube_thread_entry entry, void *capture,
                       ube_thread_capture_destructor destroy) {
    if (enabled && active_cancel && __atomic_load_n(&active_cancel->requested, __ATOMIC_SEQ_CST))
        InterlockedIncrement(&starts_after_request);
    int pressure_here = enabled && mode == MODE_WORKER_ROOT;
    if (pressure_here)
        fill_root_pressure();
    int64_t id = ube_thread_start_checked(entry, capture, destroy);
    if (pressure_here)
        observe_publication_end();
    return id;
}

static long assertion_count;
static int require(int test, const char *message) {
    if (test) {
        ++assertion_count;
        return 1;
    }
    fprintf(stderr, "FAIL source proof: %s (Err=%d)\n", message, ube_err_number());
    return 0;
}
#define REQUIRE(x, msg)                                                                            \
    do {                                                                                           \
        if (!require((x), (msg)))                                                                  \
            return 1;                                                                              \
    } while (0)
static int bytes_array(void **slot, const uint8_t *data, int n) {
    if (!ube_value_try_resize(slot, n, proof_layout(4), 0))
        return 0;
    for (int i = 0; i < n; ++i)
        *(uint8_t *)ube_array_element(*slot, i) = data[i];
    return 1;
}
static int make_inputs(void **inputs, int count, int bad_at) {
    if (!ube_value_try_resize(inputs, count, proof_layout(0), 0))
        return 0;
    void *bytes = NULL;
    struct ube_gc_root root = {0};
    if (!ube_gc_root_enter(&root, &bytes))
        return 0;
    for (int i = 0; i < count; ++i) {
        const struct corpus_case *c = &corpus[i];
        if (i == bad_at)
            c = &corpus[corpus_count - 2];
        if (!bytes_array(&bytes, c->data, c->bytes) ||
            !proof_make(&bytes, i, ube_array_element(*inputs, i))) {
            ube_gc_root_leave(&root);
            return 0;
        }
    }
    ube_gc_root_leave(&root);
    return 1;
}
static int originals_equal(void *inputs, int count, int bad_at) {
    for (int i = 0; i < count; ++i) {
        struct owner *o = *(struct owner **)ube_array_element(inputs, i);
        const struct corpus_case *c = &corpus[i];
        if (i == bad_at)
            c = &corpus[corpus_count - 2];
        if (o->id != i || ube_value_array_length(&o->document.bytes) != c->bytes)
            return 0;
        for (int j = 0; j < c->bytes; ++j)
            if (*(uint8_t *)ube_array_element(o->document.bytes, j) != c->data[j])
                return 0;
    }
    return 1;
}
static int workers_drained(void) {
    ULONGLONG deadline = GetTickCount64() + 5000;
    for (;;) {
        int found = 0;
        if (!ube_thread_enter_lock())
            return 0;
        for (struct ube_thread_record *p = ube_threads; p; p = p->next)
            if (p->is_worker)
                found = 1;
        ube_thread_leave_lock();
        if (!found && !record_live && !capture_live)
            return active == 0;
        if (GetTickCount64() > deadline)
            return 0;
        Sleep(1);
    }
}
static void begin_observation(int count, int jobs, int mode_value,
                              struct cancellation *cancellation) {
    for (int i = 0; i < MAX_UNITS; ++i) {
        clear_saved(&saved[i]);
        memset(&rows[i], 0, sizeof rows[i]);
        operation_active[i] = 0;
    }
    observed_count = count;
    active = maximum_active = entered = exited = op_switches = 0;
    last_reader = -1;
    gate_target =
        (mode_value == MODE_NORMAL || mode_value == MODE_SERIAL || mode_value == MODE_REVERSE)
            ? (jobs < count ? jobs : count)
            : 1;
    reverse_jobs = jobs < count ? jobs : count;
    gate_open = gate_target <= 1;
    mode = mode_value;
    active_cancel = cancellation;
    allocation_calls = requested_bytes = copy_bytes = source_copies = capture_bytes = 0;
    publication_events = 0;
    publication_bytes = 0;
    infrastructure_error = 0;
    publication_cancel_fired = 0;
    starts_after_request = 0;
    root_baseline = ube_gc_root_count;
    root_peak = root_baseline;
    payload_baseline = ube_gc_live_allocation_bytes();
    payload_peak = payload_baseline;
    enabled = 1;
}
static void end_observation(void) {
    enabled = 0;
    current = NULL;
}

#include "boundary-proof.h"
#include "context-proof.h"
#include "shared-proof.h"
static int prove_fixture_positions(void) {
    const struct saved *tiny = &baseline[0];
    const struct saved *bom = &baseline[1];
    if (!require(tiny->count == 2 && tiny->nodes[tiny->root].kind == 45 &&
                     tiny->nodes[tiny->root].children == 1 &&
                     tiny->nodes[tiny->nodes[tiny->root].child].kind == 50,
                 "independent empty MODULE graph expectation"))
        return 0;
    if (!require(bom->tokens >= 2, "BOM and following content tokens retained"))
        return 0;
    struct token prefix = bom->token_data[0], first = bom->token_data[1],
                 last = bom->token_data[bom->tokens - 1];
    if (!require(prefix.kind == 12 && prefix.first.byte == 0 && prefix.last.byte == 3 &&
                     prefix.first.scalar == 0 && prefix.last.scalar == 0 &&
                     prefix.first.line == 1 && prefix.first.column == 1 && prefix.last.line == 1 &&
                     prefix.last.column == 1,
                 "independent preserved BOM token: bytes0..3, zero content scalars"))
        return 0;
    if (!require(first.first.byte == 3 && first.first.scalar == 0 && first.first.line == 1 &&
                     first.first.column == 1,
                 "first content token begins after BOM at scalar0 line1 column1"))
        return 0;
    int comment_at = -1, matched = 0;
    for (int i = 0; i < corpus[1].bytes - 1; ++i)
        if (corpus[1].data[i] == 39 && corpus[1].data[i + 1] == 32) {
            comment_at = i;
            break;
        }
    if (!require(comment_at >= 0, "independent original non-ASCII comment witness"))
        return 0;
    for (int i = 1; i < bom->tokens; ++i) {
        struct token token = bom->token_data[i];
        if (token.first.byte == comment_at && token.last.byte == comment_at + 14 &&
            token.last.scalar - token.first.scalar == 6 && token.first.line == 3 &&
            token.first.column == 1 && token.last.line == 3 && token.last.column == 7)
            matched = 1;
    }
    if (!require(matched, "non-ASCII comment has14 original bytes and6 scalars including prefix"))
        return 0;
    if (!require(last.last.byte == corpus[1].bytes && last.last.scalar == corpus[1].bytes - 3 - 8 &&
                     last.last.line == 4 && last.last.column == 1,
                 "independent CRLF and Unicode EOF coordinates"))
        return 0;
    puts("{\"suite\":\"fixturePositions\",\"bomToken\":true,\"unicodeScalars\":true,\"crlfEof\":"
         "true}");
    return 1;
}
int main(int argc, char **argv) {
    setvbuf(stdout, NULL, _IONBF, 0);
    REQUIRE(proof_payload_size(0) == 32 && proof_payload_size(1) == 88 &&
                proof_payload_size(2) == 1 && proof_payload_size(3) == 64,
            "independent emitted class sizes");
    const size_t root_counts[5] = {1, 3, 0, 2, 3};
    for (int object = 0; object < 5; ++object) {
        const struct ube_gc_layout *layout = proof_object_layout(object);
        REQUIRE(layout && layout->size == proof_payload_size(object) &&
                    layout->slot_count == root_counts[object] && !layout->finalizer,
                "actual immutable class GC descriptor");
        for (size_t slot = 0; slot < layout->slot_count; ++slot)
            REQUIRE(layout->slot_offsets[slot] == slot * 8, "actual class managed-root offsets");
    }
    int64_t main_id = ube_thread_current_id();
    REQUIRE(main_id > 0, "caller program identity");
    pressure = calloc(UBE_GC_MAX_ROOTS, sizeof(*pressure));
    REQUIRE(pressure != NULL, "real root pressure storage");
    void *inputs = NULL;
    void *output = NULL;
    void *cancellation = NULL;
    struct ube_gc_root roots[3] = {{0}};
    REQUIRE(ube_gc_root_enter(&roots[0], &inputs) && ube_gc_root_enter(&roots[1], &output) &&
                ube_gc_root_enter(&roots[2], &cancellation),
            "test owner roots");
    const int count = corpus_count - 2;
    begin_observation(count, 1, MODE_NORMAL, NULL);
    REQUIRE(make_inputs(&inputs, count, -1), "actual UBE source intake");
    end_observation();
    size_t source_bytes = 0;
    for (int i = 0; i < count; ++i)
        source_bytes += (size_t)corpus[i].bytes;
    REQUIRE(source_copies >= (LONG64)source_bytes,
            "positive control observes actual required source intake copies");
    printf("{\"suite\":\"intake\",\"sourceBytes\":%zu,\"copiedSourceBytes\":%lld,\"allocations\":%"
           "lld,\"requestedBytes\":%lld}\n",
           source_bytes, (long long)source_copies, (long long)allocation_calls,
           (long long)requested_bytes);
    ube_gc_collect();
    size_t shared_payload = ube_gc_live_allocation_bytes();
    REQUIRE(shared_payload == (size_t)count * 32 + source_bytes + (size_t)count * 8 +
                                  (size_t)(count + 1) * sizeof(struct ube_array),
            "exact actual shared input owner/byte/vector payload independent of workers");
    proof_new_cancel(&cancellation);
    REQUIRE(cancellation != NULL, "actual cancellation allocation");
    size_t steady_roots = ube_gc_root_count;
    DWORD steady_handles = 0;
    REQUIRE(GetProcessHandleCount(GetCurrentProcess(), &steady_handles),
            "initialized handle baseline");
    if (argc == 2 && !strcmp(argv[1], "--fixtures")) {
        REQUIRE(make_inputs(&inputs, 2, -1), "focused original-position fixtures");
        struct set_failure failure = {5, -1, {0}};
        REQUIRE(proof_sources(&inputs, 4, 1048576, 1048576, 1048576, 256, cancellation, &output,
                              &failure),
                "actual two-fixture UBE source parsing");
        for (int i = 0; i < 2; ++i)
            REQUIRE(snapshot(&baseline[i], *(struct work **)ube_array_element(output, i)),
                    "focused complete fixture graph/tokens");
        REQUIRE(prove_fixture_positions(), "focused original-position acceptance");
        goto cleanup;
    }
    if (argc == 2) {
        REQUIRE(!strcmp(argv[1], "--boundaries") || !strcmp(argv[1], "--faults"),
                "known focused diagnostic suite");
        struct set_failure failure = {5, -1, {0}};
        REQUIRE(proof_sources(&inputs, 1, 1048576, 1048576, 1048576, 256, cancellation, &output,
                              &failure),
                "diagnostic complete earlier result");
        for (int i = 0; i < count; ++i)
            REQUIRE(snapshot(&baseline[i], *(struct work **)ube_array_element(output, i)),
                    "diagnostic complete baseline");
        if (!strcmp(argv[1], "--boundaries")) {
            REQUIRE(prove_source_boundaries(&inputs, &output, cancellation, count),
                    "focused boundary diagnosis");
            goto cleanup;
        }
        goto fault_cases;
    }
    for (int repetition = 0; repetition < 2; ++repetition)
        for (int jobs = 1; jobs <= 4; jobs *= 2) {
            ube_gc_collect();
            struct set_failure failure = {5, -1, {0}};
            __atomic_store_n(&((struct cancellation *)cancellation)->requested, 0,
                             __ATOMIC_SEQ_CST);
            begin_observation(count, jobs, MODE_NORMAL, cancellation);
            published_slot = &output;
            ube_err_set(77, "seed", "source proof");
            ULONGLONG start = GetTickCount64();
            int ok = proof_sources(&inputs, jobs, 1048576, 1048576, 1048576, 256, cancellation,
                                   &output, &failure);
            ULONGLONG elapsed = GetTickCount64() - start;
            end_observation();
            REQUIRE(ok && failure.kind == 0 && failure.source == -1 && ube_err_number() == 77,
                    "complete UBE source-set status and stale Err preservation");
            DWORD handles = 0;
            REQUIRE(workers_drained() && ube_gc_root_count == steady_roots &&
                        GetProcessHandleCount(GetCurrentProcess(), &handles) &&
                        handles == steady_handles,
                    "all worker roots, records, captures and native handles drain");
            REQUIRE(!infrastructure_error && entered == count && exited == count &&
                        maximum_active <= jobs,
                    "one bounded worker budget and exact unit count");
            REQUIRE(source_copies == 0 && capture_bytes == (LONG64)count * 8,
                    "observed reference captures copy zero source payload");
            REQUIRE(root_peak - root_baseline <= (size_t)(256 + jobs * (128 + 4096 + 1)),
                    "predefined root bound");
            REQUIRE(originals_equal(inputs, count, -1) && ube_value_array_length(&output) == count,
                    "input bytes and result association retained");
            for (int i = 0; i < count; ++i) {
                struct work *w = *(struct work **)ube_array_element(output, i);
                REQUIRE(w->state == 1 &&
                            w->owner == *(struct owner **)ube_array_element(inputs, i) &&
                            w->id == rows[i].id && w->id != main_id,
                        "real UBE identity, shared owner and private accepted work");
                REQUIRE(graph_valid(&saved[i], corpus[i].bytes),
                        "complete ordered graph/span validation");
                if (repetition == 0 && jobs == 1) {
                    printf("{\"suite\":\"unitCost\",\"source\":%d,\"bytes\":%d,\"byteReads\":%llu,"
                           "\"allocations\":%llu,\"requestedBytes\":%llu,\"copyBytes\":%llu,"
                           "\"tokens\":%d,\"nodes\":%d}\n",
                           i, corpus[i].bytes, (unsigned long long)rows[i].bytes,
                           (unsigned long long)rows[i].allocations,
                           (unsigned long long)rows[i].requested,
                           (unsigned long long)rows[i].copies, saved[i].tokens, saved[i].count);
                    baseline[i] = saved[i];
                    memset(&saved[i], 0, sizeof saved[i]);
                } else
                    REQUIRE(equal_saved(&baseline[i], &saved[i]),
                            "full tokens/graphs/failures equal one-worker baseline");
            }
            REQUIRE(publication_events == 1 && publication_bytes == (LONG64)count * 8,
                    "measured atomic publication copies exactly 8N reference payload bytes");
            for (int i = 0; i < jobs; ++i) {
                REQUIRE(rows[i].native && rows[i].native != GetCurrentThreadId(),
                        "actual native source worker differs from caller");
                for (int j = 0; j < i; ++j)
                    REQUIRE(rows[i].native != rows[j].native,
                            "first-wave simultaneous native source workers are distinct");
            }
            printf("{\"suite\":\"publication\",\"jobs\":%d,\"bytes\":%lld,\"events\":%ld,"
                   "\"firstNativeIds\":[",
                   jobs, (long long)publication_bytes, publication_events);
            for (int i = 0; i < jobs; ++i)
                printf("%s%lu", i ? "," : "", (unsigned long)rows[i].native);
            puts("]}");
            if (repetition == 0 && jobs == 1)
                REQUIRE(prove_fixture_positions(),
                        "original-position fixtures before expanded worker matrix");
            if (jobs > 1)
                REQUIRE(maximum_active == jobs && op_switches > 0,
                        "actual interleaved operations overlap on distinct UBE workers");
            size_t result_payload =
                (size_t)count * (88 + 24 + 8) + (size_t)(3 * count + 1) * sizeof(struct ube_array);
            uint64_t lock_count = 0, lock_wait = 0, lock_hold = 0;
            for (int i = 0; i < count; ++i) {
                struct work *w = *(struct work **)ube_array_element(output, i);
                struct result *r = ube_array_element(w->syntax, 0);
                result_payload +=
                    (size_t)ube_value_array_length(&w->tokens) * sizeof(struct token) +
                    (size_t)r->count * sizeof(struct node);
                lock_count += rows[i].lock_count;
                lock_wait += rows[i].lock_wait;
                lock_hold += rows[i].lock_hold;
            }
            ube_gc_collect();
            REQUIRE(ube_gc_live_allocation_bytes() == shared_payload + 1 + result_payload,
                    "exact retained shared input plus private completed results after collection");
            REQUIRE(
                lock_count > 0 && payload_peak > (LONG64)payload_baseline,
                "positive witnesses for collector synchronization and payload peak observations");
            LARGE_INTEGER frequency;
            QueryPerformanceFrequency(&frequency);
            printf("{\"suite\":\"ownership\",\"sharedBytes\":%zu,\"completedBytes\":%zu,"
                   "\"nativeCaptureHeader\":%zu,\"nativeRecord\":%zu,\"nativeTls\":%zu,"
                   "\"collectorAcquisitions\":%llu,\"collectorWaitTicks\":%llu,"
                   "\"collectorHoldTicks\":%llu,\"ticksPerSecond\":%lld}\n",
                   shared_payload, result_payload, sizeof(struct ube_thread_capture),
                   sizeof(struct ube_thread_record), sizeof(struct ube_thread_local_state),
                   (unsigned long long)lock_count, (unsigned long long)lock_wait,
                   (unsigned long long)lock_hold, (long long)frequency.QuadPart);
            uint64_t cpu = 0, reads = 0;
            for (int i = 0; i < count; ++i) {
                cpu += rows[i].cpu;
                reads += rows[i].bytes;
                for (int j = 0; j < i; ++j)
                    REQUIRE(rows[i].id != rows[j].id, "unique program IDs");
            }
            printf(
                "{\"suite\":\"sources\",\"jobs\":%d,\"repetition\":%d,\"units\":%d,\"elapsedMs\":%"
                "llu,\"cpu100ns\":%llu,\"byteReads\":%llu,\"operationSwitches\":%ld,\"peakActive\":"
                "%ld,\"allocations\":%lld,\"requestedBytes\":%lld,\"copyBytes\":%lld,"
                "\"sourceCopies\":%lld,\"captureBytes\":%lld,\"rootDelta\":%zu}\n",
                jobs, repetition, count, (unsigned long long)elapsed, (unsigned long long)cpu,
                (unsigned long long)reads, op_switches, maximum_active, (long long)allocation_calls,
                (long long)requested_bytes, (long long)copy_bytes, (long long)source_copies,
                (long long)capture_bytes, root_peak - root_baseline);
            printf("{\"suite\":\"memory\",\"jobs\":%d,\"retainedBaseBytes\":%zu,"
                   "\"peakGcPayloadBytes\":%lld,\"peakAdditionalBytes\":%lld}\n",
                   jobs, payload_baseline, (long long)payload_peak,
                   (long long)(payload_peak - payload_baseline));
        }
    REQUIRE(prove_source_schedules(&inputs, &output, cancellation, count),
            "serial-control and reversed schedules");
    REQUIRE(prove_source_boundaries(&inputs, &output, cancellation, count),
            "source boundary cases");
    REQUIRE(prove_shared_tokens(output, count), "actual UBE shared-token workers");
    REQUIRE(prove_independent_contexts(inputs, count),
            "independent simultaneous UBE source contexts");
    /* A corrupted result must fail the same full comparison. */
    struct saved corrupt = baseline[0];
    struct node *changed = malloc((size_t)corrupt.count * sizeof(*changed));
    REQUIRE(changed != NULL, "negative control storage");
    memcpy(changed, corrupt.nodes, (size_t)corrupt.count * sizeof(*changed));
    corrupt.nodes = changed;
    changed[corrupt.root].last ^= 1;
    REQUIRE(!equal_saved(&baseline[0], &corrupt), "corrupted graph comparison negative control");
    free(changed);
fault_cases:;
    void *original_output = output;
    struct set_failure failure = {5, -1, {0}};
    int ok = 0;
    REQUIRE(make_inputs(&inputs, 4, -1), "focused faults retain full earlier published graph");
    for (int fault = MODE_ENTER_CANCEL; fault <= MODE_WORK_ALLOC_FAIL; ++fault) {
        int fault_count = fault == MODE_AFTER_ADMISSION ? count : 4;
        if (fault == MODE_AFTER_ADMISSION)
            REQUIRE(make_inputs(&inputs, count, -1), "full input at publication commit control");
        __atomic_store_n(&((struct cancellation *)cancellation)->requested, 0, __ATOMIC_SEQ_CST);
        failure = (struct set_failure){5, -1, {0}};
        if (fault == MODE_START_FAIL)
            ube_thread_test_fail_starts(1);
        if (fault == MODE_WAIT_FAIL)
            ube_thread_test_fail_waits(1);
        fail_work_allocations = fault == MODE_WORK_ALLOC_FAIL;
        begin_observation(fault_count, 4, fault, cancellation);
        published_slot = &output;
        ok = proof_sources(&inputs, 4, 1048576, 1048576, 1048576, 256, cancellation, &output,
                           &failure);
        end_observation();
        fail_work_allocations = 0;
        ube_thread_test_fail_waits(0);
        if (fault == MODE_AFTER_ADMISSION)
            REQUIRE(ok && failure.kind == 0 && publication_cancel_fired == 1 &&
                        active_cancel->requested,
                    "cancellation after witnessed publication admission does not undo commit");
        else {
            const int expected_kinds[8] = {0, 4, 4, 4, 0, 2, 6, 5};
            REQUIRE(!ok && failure.kind == expected_kinds[fault] && output == original_output,
                    "exact fresh fault/cancellation kind retains complete old output");
        }
        if (fault == MODE_ENTER_CANCEL || fault == MODE_WORK_CANCEL)
            REQUIRE(active_cancel->requested && starts_after_request <= 1,
                    "at most one already-admitted start straddles the final cancellation check");
        REQUIRE(workers_drained() && ube_gc_root_count == steady_roots &&
                    originals_equal(inputs, fault_count, -1) && output_equal(output, count),
                "fault drain, roots, full earlier graphs and original bytes");
        original_output = output;
        if (fault == MODE_AFTER_ADMISSION)
            REQUIRE(make_inputs(&inputs, 4, -1), "restore focused fault inputs");
        printf("{\"suite\":\"fault\",\"mode\":%d,\"failure\":%d,\"source\":%d,\"entered\":%ld}\n",
               fault, failure.kind, failure.source, entered);
    }
    __atomic_store_n(&((struct cancellation *)cancellation)->requested, 1, __ATOMIC_SEQ_CST);
    failure = (struct set_failure){5, -1, {0}};
    ok = proof_sources(&inputs, 4, 1048576, 1048576, 1048576, 256, cancellation, &output, &failure);
    REQUIRE(!ok && failure.kind == 4 && output == original_output, "cancellation before dispatch");
    __atomic_store_n(&((struct cancellation *)cancellation)->requested, 0, __ATOMIC_SEQ_CST);
    failure = (struct set_failure){5, -1, {0}};
    deny_all = 1;
    begin_observation(4, 4, MODE_WORK_ALLOC_FAIL, cancellation);
    ok = proof_sources(&inputs, 4, 1048576, 1048576, 1048576, 256, cancellation, &output, &failure);
    end_observation();
    deny_all = 0;
    REQUIRE(!ok && failure.kind == 5 && output == original_output && workers_drained() &&
                output_equal(output, count),
            "persistent all-allocator denial preserves old graph and drains");
    for (int fault = MODE_PUBLICATION_ROOT; fault <= MODE_PUBLICATION_ALLOC; ++fault) {
        failure = (struct set_failure){5, -1, {0}};
        begin_observation(4, 4, fault, cancellation);
        published_slot = &output;
        ok = proof_sources(&inputs, 4, 1048576, 1048576, 1048576, 256, cancellation, &output,
                           &failure);
        end_observation();
        REQUIRE(!ok && failure.kind == 5 && failure.source == -1 && output == original_output &&
                    workers_drained(),
                "publication admission/storage failure has fresh status and preserves graph");
    }
    failure = (struct set_failure){5, -1, {0}};
    int64_t before_id = ube_thread_high_water;
    begin_observation(4, 4, MODE_WORKER_ROOT, cancellation);
    ok = proof_sources(&inputs, 4, 1048576, 1048576, 1048576, 256, cancellation, &output, &failure);
    end_observation();
    REQUIRE(!ok && failure.kind == 2 && failure.source == 0 && entered == 0 &&
                ube_thread_high_water == before_id && output == original_output &&
                workers_drained() && output_equal(output, count),
            "actual source Sub root-admission rejection issues no ID, enters no body and drains");
cleanup:
    for (int i = 0; i < MAX_UNITS; ++i) {
        clear_saved(&saved[i]);
        clear_saved(&baseline[i]);
    }
    free(pressure);
    for (int i = 2; i >= 0; --i)
        ube_gc_root_leave(&roots[i]);
    inputs = output = cancellation = NULL;
    ube_gc_collect();
    REQUIRE(ube_gc_root_count == 0 && ube_gc_live_allocation_bytes() == 0 && workers_drained(),
            "zero residual owned roots/payload/workers");
    printf("{\"suite\":\"result\",\"assertions\":%ld,\"passed\":true}\n", assertion_count);
    puts("PASS actual UBE source-set proof");
    return 0;
}
