# Compiler-private caller-retained ByRef roots: owner-review proposal

STATUS: ADOPTED IN SCOPE by the owner on 2026-11-01 (option 1 in the explicit
review question). The calling obligation and scoped implementation/test-bridge
changes below are authorized. Implementation was applied after the expanded
pre-optimization baseline was frozen. Focused lifetime tests pass; full combined
qualification and the stated performance gates remain pending.

Adopted decision

The adopted compiler-private calling obligation is: before a
synchronous UBE call, its caller keeps each managed ByRef writable location (or
its precisely traced containing owner) live throughout the call, including new
managed values written to that location. Retaining only its old referent is not
sufficient. A forwarded ByRef aliases the same retained location. Owners of
interior array/member addresses and neutral fallbacks remain retained separately.

Under this obligation, omit only the callee registration whose storage is exactly
%root.arg.N and whose value address is exactly its pointer parameter %arg.N,
plus exactly its matching cleanup. Keep every private root, ByVal incoming/copy,
result/output temporary, capture, array/member borrow owner, fallback and native
runtime root. Preserve initialization, errors, common cleanup, result publication,
32-byte root ABI, capacity 1048576, GC/barriers, language value semantics and
caller argument evaluation. No trusted-call flag or alternate exported ABI.

Existing approval boundary

MANAGED-STORAGE-PROPOSAL.md requires live local/parameter/result/temporary
locations before calls/safe points. v2 DESIGN.md explicitly describes parameter
roots. BORROWED-ROOT-PROBE.md proposes caller-retained duplicate omission, but
is diagnostic evidence, not blanket adoption. The owner explicitly accepted
the above private obligation on 2026-11-01. Generated UBE calls
already retain their locations/owners mechanically; the decision records that
as an invariant, not a new reference or aliasing feature.

Native boundaries

Raw compiler-private entry adapters are tests, not public foreign exports. Their
C caller must admit checked roots for writable managed holders before entry and
retain containing managed owners through return. Acquire all needed adapter
roots before invoking UBE; on partial admission failure unwind and return the
existing controlled test/entry failure without user work. Root empty output
holders too, since a callee may publish a new value before another collection.

The production native Main has no source parameters. CallNew permits explicit
ByVal scalars/references only and retains its capture until worker cleanup;
asynchronous ByRef still rejects. Source-library references use ordinary UBE
calls. General Public Export/callback ABI remains separate: opaque handles,
library-owned roots/leases, validated adapters and native transition metadata.
No caller may pass an unrooted raw managed address under that public ABI.

Small missing proof

Use two exact accepted b064 source-built tools, raw LLVM equality and both
original/elided root variants. Actual UBE nested callees assign array/record
outputs, return (dropping private New/borrow roots), then the outer callee performs
actual GC BEFORE any new read or borrow. Cover direct output, record output,
forwarding/exact alias, array-of-record element and class-array field while the
original owner holder is replaced. Root exact C locations or containing owners.
Post-sweep watches are NOT roots: check a containing allocation before touching
an interior watched location; then check the new value is live, not pending or
pinned. Observe full mark/sweep completion and zero mark failures, ordinary and
collection-before-managed-allocation modes. Verify independent contents and
zero remaining roots/payload/observations.

Required controls

Remove only the native caller root for a direct output. Original callee roots
should retain the new array; elided code must produce a dead-watch exit before
dereference at the explicit post-nested-return collection. This proves neither
pending publication nor a private New/borrow root masks the obligation. Separately
remove the containing-owner root for an interior output: both variants must
reject the dead owner before reading a freed field. No unrooted negative case
is proposed as a supported foreign call.

Native adapter alignment

The diagnostic OOM adapter now roots document.bytes before filling the real
registry. Its exact controls distinguish necessary helper-root admission
failure, native caller-location admission failure and the genuinely rootless
empty fallback. The fallback preserves Err without allocation or root changes;
the registry capacity remains 1048576. No artificial production root or failure
waiver is used.

The finite native-adapter audit covers all v2 test C/LLVM-generation sites,
all v3 native proof helpers and the standard-library C/LLVM/inline bridges.
The performance harness already retains its writable holders and containing
input-array owners. Two concurrency helpers needed roots for their copied
input holder and neutral empty-input holder. Two library worker adapters
needed independent unwind after partial root admission; the corresponding
main-only native adapters receive the same cleanup correction. These are
test-bridge changes under the adopted contract, with no runtime, collector,
capacity, language or public foreign-ABI change. Actual registry-denial and
cleanup regressions supplement the unchanged retained qualification gates.

Focused proof result

Report: `bootstrap/out/caller-rooted-byref-review/6fd0be192840404ab935acdd2810bfb7/report.json`.
SHA-256: `68EA4E012E56F789CBD4DD371D9400F9CF69D71F13CEE75C1D1D79128999806F`.
Both accepted tools emit identical raw LLVM. Forty positive executions pass
(five cases, two stages, original/elided roots, ordinary/forced collection),
including 40 actual post-nested-return collections before a fresh borrow/read.
There are zero pending/pinned masks or mark failures. Twenty dead-watch controls
and four original-callee unrooted-slot contrasts pass. Contents and cleanup are
independently checked. These are focused lifetime proofs, not performance or
production qualification.

Remaining production prerequisites

These focused proofs supplement, not replace, the earlier56 lifetime/watch runs.
Before adoption audit every actual native adapter/call-emission path, rerun both
source-built stages and retained managed/admission/GC/failure/parser/CLI/thread
gates on the same cohort, and preserve negative controls. Foreign ABI remains
unqualified by private LLVM tests. Expanded serial baseline/performance gates
remain separate and unchanged. Owner approval authorizes this scoped work;
it does not waive any adoption gate or authorize unrelated ABI changes.
