# Scalar arena and immutable UBE worker probe contract

Test-only candidates for the approved First semantic checking deliverable.
No production representation/API is selected here. Inputs are immutable and
caller-owned; pending arena/work/results have one owner. Existing std-lib Threads
supplies actual UBE CallNew execution; there is no production scheduler here.

Arena counts are 0, 1, 8, 64, 1024 and 16384. Records carry scalar source/node/type
identities, original spans, links and a LongLong payload. Preset 48-byte record
and 24-byte result-wrapper ABIs are checked against intact generated LLVM.
Each record's payload is 2147483647+i; a flat linked traversal sums the records
using an explicit one-entry work stack, never native recursion. Thus pending and
active depth requirements are one for any nonempty chain, zero for empty input.
Caller declaration budgets 0..1048576 and depth 0..256 are inclusive. Every fault
preserves the unrelated old complete result and both original source owners.

Preset successful work: N record writes, N record reads, 2*N work transitions,
maximum pending/depth one (or zero for N=0). Geometric arena capacity grows from
at most eight records; growth copies at most 2*N*48+8*48 payload bytes. Exact trim
copies at most N*48; final publication copies exactly N*48+16 metadata bytes.
The explicit stack has one live Long and at most eight allocated Longs. No
original source payload copies. Allocator calls are bounded by 2*ceil(log2(N+1))
+16; requested/zeroed bytes and physical collector headers/payload are observed
separately. Peak additional roots are at most 512, independent of N. Actual
allocation and real-backed root denial must preserve the old graph and owners,
release temporary storage after collection, and permit later recovery.
Before measurement, additionally preset requested bytes at most
6*N*48+16*48+8*4+2*24+8+L*(A+G), where L=2*ceil(log2(N+1))+16 and A/G are
the observed physical headers. Additional collector payload uses the same
bound without G and the 8-byte publication workspace. These deliberately include
unreclaimed geometric/trim/publication arrays, rather than treating a dropped
reference as immediately reclaimed. The baseline old graph/sources are separate.

Four UBE workers share one immutable owner with key bytes, sorted index and
numeric bytes. Only owner/work references and bounded IDs are captured; no source
or declaration payload clone is permitted. Each worker owns a complete output
vector. Repeated and reversed release orders, two simultaneous independent
contexts, exact per-slot answers, native thread identities, actual overlap,
capture sizes, zero source-payload copies and final root/heap cleanup are checked.
An unowned-borrow negative control observes reclamation without dereferencing
freed memory. No speedup claim is made.

Before shared-worker measurement: each success owns exactly 2*N+2 Long answer
slots and three folded-name bytes. Four complete rounds query every key's lower
and upper boundary, plus one absent-partition range. FINAL-SHAPE.md defines the
paired partition ordering and exact ranges. Numeric results are signed64 minimum
and 30000; arena total is
N*2147483647+N*(N-1)/2. Names `[K]]L]&` cook to bytes 107,93,108 using the
parser-supplied suffix/bracket metadata. Each worker captures one class reference:
exactly eight allocated capture-data bytes, one aggregate root offset zero, and
exactly eight actual capture-assignment bytes. The work object retains its owner.

Per completed worker allow at most16 allocator calls and at most
16*N+4096+12*(A+G) requested bytes, including fixed collector bookkeeping slack.
Actual copies are exactly 8*N+8 answer payload bytes plus six derived name bytes;
original source/key/index/arena payload copies and resizes are zero. The whole
four-worker context adds at most4096 live roots, independent of N. Exact root and
heap increment callbacks are scalar/TLS-only. Caller roots are deliberately
removed while all four admitted captures are gated; real collection must retain
the exact owner/input/work graph. Restore caller roots before completion so
results remain inspectable after captures drain. Cancellation, actual worker
allocation failure, capture/start failure, recovery and independent contexts
must leave an unrelated complete old graph unchanged and release all handles.
