# Independent project contexts and identity coverage

`intake.c` calls the actual UBE `TryParseProject` entry. Native threads are
test callers; production discovery still calls `TryParseSources` once per
request and that function retains the entire request's worker budget.

Four callers share one rooted, immutable invocation byte array. Each has a
private cancellation object, published output, retained older result, failure
context/status, open-token variable and thread-local Err seed. All four signal
readiness before one start event releases them. A test counter requires at
least two overlapping native call intervals. It does not measure production
worker overlap, scheduling fairness or performance.

Each caller executes budgets 1,2,4,4,2,1. A different round cancels each caller
before intake; every other request must succeed. This is 20 successful parses
and four controlled cancellations. Success must replace only that caller's
output; cancellation must preserve it. Every round compares its current and
first successful graphs against the separately rooted serial baseline. Explicit
collection during concurrent work must retain those older graphs. Each caller
keeps a distinct Err seed. Final checks require distinct native thread IDs,
cancellation objects, published graphs and status contexts, followed by native
handle closure, no remaining UBE workers or file readers, and zero live payload
after the enclosing roots are released and collected.

The successful identity/order fixtures have independent C expectation tables:

- Root sources retain `Main`, then `Helper`; the direct library retains
  `CoreValue` after those root sources.
- The normalized path spelling retains the original declaration while resolving
  `src/./unused/../Main.bas` to `src/Main.bas`.
- Reversed root declarations produce `Helper`, then `Main`, followed by the
  direct library's `CoreValue`, with new canonical source/declaration IDs.
- A direct UBECore module named `Main` coexists with the root module named
  `Main`; identity is package-local.
- Distinct root files declaring Greek uppercase/lowercase omega are rejected
  as a Unicode-folded module-name collision at the second source.
- The optional case-sensitive fixture keeps physical files `Main.bas` and
  `main.bas` distinct, preserving their exact declared/normalized paths and
  independently expected module names `UpperValue` and `LowerValue`. Native
  identities must differ, and each retained identity is checked against a
  separate host file open and `GetFileInformationByHandle` query.

The graph comparator checks invocation/directory bytes and byte accounting;
every package's document, paths, opened-file identity, scalar metadata, complete
declaration vectors and reference paths; every source's paths, document,
identity, envelope and package/declaration association; and the complete ordered
token/node graphs, parser metrics, work limits and failure records. Per-request
worker IDs are required to be positive but are not compared for equality across
requests. Documents are also compared with the fixture files.

The runner executes all 35 ordinary cases under six budgets through both accepted
source-built tools, in ordinary, native-fault and allocator-denial variants.
Supplying `-CaseSensitiveRoot <already-enabled-directory>` adds one case to all
six groups. The runner queries that parent with `fsutil file queryCaseSensitiveInfo`,
creates a unique child, and requires the child's query to confirm inherited case
sensitivity before writing either file. It never changes filesystem settings.
Failure to inherit stops the run; it cannot become a skipped or passed case.
Native `fsutil file queryFileID` outputs, parent/child queries, fixture paths,
and exact fixture input hashes are retained in the report. The two native file
IDs must differ before production intake runs. The optional case precedes the
ordinary cases, preserving the original final baseline and all 375 allocation
denial positions. Without this parameter the normal run is self-contained and
explicitly leaves case-sensitive physical-path coverage outstanding.

All variants execute the four-context test after their sequential controls.
Allocator observation remains disabled during concurrent-context tests: denial
qualification separately observes and denies every executed calloc position
for the actual one-worker request, including its UBE worker.

Use `tools/check-project-intake.ps1 -DiagnosticOnly -ReuseRun <prior-run>` to
relink the C assertions without recompiling an unchanged production source set.
The runner checks the exact cached UBE/import/tool/raw-LLVM identities and hashes
all inputs again at completion. Its report preserves native output and commands.
Diagnostic reuse is development evidence, not refreshed source qualification.

This proof does not establish exhaustive independent metadata/span oracles,
every allocator family/root capacity, CLI
qualification or the final performance gate. Those remain separate acceptance
obligations. The earlier root/read/close/cancellation/start/wait and all-position
calloc controls remain required and are not replaced by this context test.
