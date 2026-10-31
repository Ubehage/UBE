# Native parser storage and traversal evidence

Completed on 2026-10-31, following the focused probe item in `Roadmap.md` and
the predefined comparisons and budgets in [PARSER-PROBES.md](PARSER-PROBES.md).
The decision for the first bounded grammar consumer is **linked-child nodes and
explicit operator/operand and traversal stacks**. All candidate UBE remains
test-only. The production manifest still contains the source/scanner consumer;
no production parser or backend is implemented by this work.

## Executed gates and exact provenance

From the repository root:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-parser-probes.ps1
```

The fresh source build passed **501 grouped checks**: 136 core and the same 13
child proof families. The two former tracing/first-error termination expectations
were strengthened to require recoverable results, with four additional focused
regressions inside the existing managed-substrate group. Earlier accepted source
and artifact snapshots remain intact. The new build recorded 294 source inputs
and took 572628 ms on this machine; that is a complete bootstrap qualification
time, not production compiler throughput.

The probe gate passed **3828 assertions** through **both accepted source-built
v2 stages**, using intact UBE sources and the actual UBECore Reference. Both
storage and traversal raw LLVM pairs are byte-identical. Each stage runs exact
and observed runtime variants. The test-only ABI adapter checks concrete record
and procedure signatures and primitive descriptors before linking the C oracle.

| Record | SHA-256 |
|---|---|
| `bootstrap/out/v2/ff1bc5cd822f4991ab1a681488011907/manifest.json` | `CE4261D39F69CDA12EFFDA197B1D131FA1187A03C038842B048E450588CB3F66` |
| Same directory, `source-manifest.json` | `A7762C37942EA12CA53869A7828B912636BD7D575A41FABFAC343401B8462882` |
| Same directory, `ube-stage2-v2.exe` | `A8104CEE8D9E34E2569CDF7536C40E58329A6EF3C27109B8CCE965AE98482893` |
| Same directory, `bootstrap_runtime.o` | `A1B79A8CC00BB2446FD3AAD82BD461E1BD96227ED85C4B5E0E78385ACDBE1D6D` |
| `bootstrap/out/parser-probes/cce71deaa9654ae7852d2eb7a05fe52d/report.json` | `EF354B7B56F90914557C75C297F8B301F2DC050413512D462693B5094A3DB8EA` |
| `bootstrap/out/parser-contract/a61a2e37765f4563849ae7127e8ca38f/report.json` | `20CBEB0F64B1AB87487F85438ACE6D1F078A79546C437F4A814E42D90081530C` |

The strict definition gate again passed its original 11969 definition assertions
and 16 negative controls over the unchanged **116 cases**. Its complete current
report has 18337 assertions including the native-cohort audit. The probe gate
audits all 2331 accepted identities before and after execution; it does not
republish that production selection. Historical definition evidence remains in
[PARSER-EVIDENCE.md](PARSER-EVIDENCE.md).

## Independent native coverage

- All **77 syntax-shape** fixtures are independently serialized into postorder
  commands, built into each candidate graph and projected back by ordinary UBE
  readers. This proves representation/order/span behavior, not source parsing.
- The narrow traversal experiment has **41 expression witnesses**, including
  selected frozen syntax/rejection cases and focused extra controls. Omitted
  grammar is not mislabeled as rejected or implemented.
- The 37 independent storage-domain/budget vectors and corrupt-graph cases yield
  **84 native domain checks**. Four joined workers share immutable input and own
  private outputs; complete input data, results and cleanup are checked.
- Each observed stage exercises **49 storage** and **67 traversal** persistent
  allocator boundaries. Every malloc/calloc/realloc request is subject to denial
  from the selected boundary onward, including retries and tracing workspace.
  Failures preserve the complete old output and report fresh failure/Err7.
- Actual backed roots fill the one-million-record registry, then sweep remaining
  admission capacity. Storage performs **363** attempts and traversal **526** per
  observed stage. Both controlled failures and successful recovery are required.
  No root counter is artificially inflated.
- Every successful/failed scope must restore expected roots and live payload.
  Eight native kind/span corruption controls fail with the intended comparison
  assertion. Twelve mutated-measurement controls reject absent publication,
  hidden copies and excessive validation/sibling work across the two stages.

The observer inserts callbacks after all **four** precisely matched stores to
the actual runtime root count. Counts include transient generated/runtime roots.
Positive executed read/write/copy assertions prevent disconnected hooks from
passing with zeros. All 48 storage and 36 traversal cost rows per observed stage
pass the predefined linear-work, geometric-growth, exact-publication and zero
source-payload-copy budgets. Original plan/oracle inputs remain unchanged after
the qualified run; results are recorded here separately.

## Storage measurements and choice

Representative 16384-node tree measurements below are stage one's observed
results; stage two independently passes the same budgets and logical oracles.
Requested bytes are cumulative allocator requests during that operation, not
retained memory or physical writes. Peak roots include seven native caller roots.

| Shape / operation | Linked allocations / requested bytes | Edges allocations / requested bytes | Linked / edges peak roots |
|---|---:|---:|---:|
| Tall construction | 18 / 1575208 | 32 / 1577232 | 83 / 97 |
| Wide construction | 29 / 1707800 | 32 / 1642736 | 83 / 97 |
| Tall projection | 27 / 2100520 | 27 / 2100520 | 94 / 109 |
| Wide projection | 16 / 1050872 | 16 / 1050872 | 94 / 109 |

Retained node/edge plus wrapper payload is **393240 bytes linked** and
**393244 bytes with edges**. For a tree, E=N-1: 24N versus 20N+4E does not provide
a meaningful payload saving. The measured native array header is 16 bytes and
GC header 128 bytes. Linked output uses two arrays including the wrapper; edges
use three for a nontrivial tree. Derived retained array allocation requests are
393528 and 393676 bytes respectively, excluding source, roots, temporary storage,
the shared GC index and CRT allocator overhead. This is not total process memory.

Linked storage is selected for the first consumer because it has fewer owned
arrays, fewer construction allocations and lower root admission requirements.
Both readers perform bounded iterative walks with linear node/edge actions.
Edges do request fewer cumulative bytes on the synthetic wide construction;
linked storage is not universally smaller or faster. Contiguous-child random
access and later compiler passes were not measured. This choice establishes a
private first-consumer representation, not a public syntax-tree ABI.

## Traversal measurements and choice

A flat chain of 16384 operands yields 32767 commands. The stack candidate executes
32770 token reads and 147454 actions; the recursive candidate 32770 reads and
131071 actions. Their allocation counts are 18 and 16, with 82 and 95 peak roots.
Flat inputs alone therefore do not justify preferring the explicit candidate.

The predefined mixed-precedence source at depth 256 distinguishes them:

| Candidate | Result | Token reads / actions | Maximum pending / semantic depth | Peak roots |
|---|---|---:|---:|---:|
| Explicit stacks | Success, exact 5889 commands | 11780 / 45319 | 5889 / 256 | 82 |
| Recursive | Controlled budget failure at byte 1791..1792 | 1440 / 4479 | 384 / 31 | 10027 |

Both candidates pass the selected ordinary shapes, succeed at pure 255/256
group, unary and right-power depths, and return the expected budget rejection
at 257. The recursive candidate fails the
common mixed-depth requirement; its smaller failed-operation allocation cannot
be compared with the complete stack result as a memory advantage.

Before deep execution, assembly and linked PE inspection found a **1456-byte**
recursive frame and **1048576-byte** stack reserve. Mixed precedence can require
12D+1 recursive frames at semantic depth D. The test-only 384-frame guard is
checked before all three recursive call sites and reserves 489472 bytes beyond
those frames. Static accounting excludes other helper/CRT/driver usage; its
256 KiB external-stack allowance is not a measured complete bound. No process
stack increase or unsafe pre-fix deep execution was used. Explicit heap stacks
are selected to satisfy the common source limit without native recursion.

The experiment also retained focused regressions for illegal prefix `Not` after
arithmetic/comparison operands and the incorrect implicit `MaximumDepth+32`
operator-workspace ceiling. These are candidate corrections, not new syntax.

## Recoverable bootstrap prerequisite

The persistent fault sweep reproduced process exit 70 while GC tracing allocated
its worklist. An incomplete trace can safely preserve the entire heap, so that
termination was unnecessary. The focused correction resets partial marks and
collection state, unlocks, skips finalization/sweeping and returns failure.
Explicit collection records Err7. Automatic recovery preserves the incoming
error if a subsequent allocation retry succeeds.

First-error publication also used an allocating FLS record. It now uses a fixed
native thread-local error record; monitor/event/thread metadata retains its FLS
ownership. Every Err/revision user, including component-load checks, uses the
same canonical error record. The maintained runtime and file-test runtime variant
use the existing Clang Windows target: the installed GCC emits emulated TLS with
first-use allocation. Production LLVM is checked for native TLS and no emutls.

The small [runtime regressions](tests/parser/probes/runtime-regression/check.ps1)
independently cover first tracing-workspace failure, the second worklist growth
after 64 partial marks, successful allocation retry preserving Err77, and a fresh
native thread's first Err7 under persistent denial of all runtime allocators.
They assert text/revision recovery, thread isolation, no premature finalization,
value/root retention, released lock, retry and cleanup. The exact retained old
runtime independently exits 70 in all four modes:
`bootstrap/out/runtime-regression/b8a3d7dce554477aa6d24579abeaccec/report.json`.
The accepted managed proof is
`bootstrap/out/managed-storage/d7d1bb46a44c4d3bab1a4d8ee6fef226/report.json`,
SHA-256 `56316359469ED09B918E78153954648A8E0E68AE89AD3945CFBC52FDAC7C332C`;
it pins the successful four-mode report and its exact inputs. This does not
claim that every historical runtime termination path has been eliminated.

## Handoff and next production action

The maintained compile helper rebuilt `bootstrap/out/v3/ube.exe` (280064 bytes),
SHA-256 `5A78A0C38CDAB5E8491705A822387BE6E1E40C35FA4567173A83CD28F4BA157E`.
Its LLVM matches the qualified production source and four predefined exact CLI
oracles pass: `bootstrap/out/parser-runtime-scanner-publication.json`.
`bootstrap/tests/v2_usage_tests.ps1` also passes native execution, controlled
rejection, old-executable preservation/replacement and changed-header rejection;
report `bootstrap/out/v2-usage/8df6213d07f84424aa7032cbcb95bbfb/report.json`.
Archive integrity passes its 367 file checks, nine preview hashes and 28 previous
library files. Protected guidance and the frozen parser cases remain unchanged.

Final handoff checks also pass:

- `rtk proxy powershell -NoProfile -File bootstrap/out/audit-parser-probe-handoff.ps1`:
  2713 recorded identity comparisons after documentation updates, with the
  native3828/source501 reports and current selection unchanged. Result:
  `bootstrap/out/parser-probe-handoff.json`.
- `rtk proxy powershell -NoProfile -File bootstrap/out/audit-source-handoff.ps1`:
  34 PowerShell parses, 22 JSON parses, 62 Markdown documents and 176 local links,
  protected-guidance checks and tracked diff whitespace. These are structural
  checks, separate from native behavior.

Next implement the bounded production grammar consumer in
[PARSER-CONTRACT.md](PARSER-CONTRACT.md), using private indexed linked-child
nodes and explicit pending/control stacks over borrowed source/token views.
Construct pending nodes directly and publish the complete owned result once;
the probe's postorder command stream is a comparison protocol, not a required
production intermediate. Reuse the independent grouping/span/diagnostic oracles
and extend native coverage to the full contracted syntax/rejection/deferred
cohort, retaining resource, copy, failure-atomicity, ownership and cleanup gates.
Keep literal conversion, semantic validity, conditional/inactive-text behavior,
deferred grammar and code generation separate as already defined.

The probes do not prove full parsing, self-hosting, complete language checking,
compiler throughput, steady-state process footprint or a UBE worker scheduler.
Sampled working set includes the harness and million-root fault fixtures; no
production memory or speed promise is inferred from it.
