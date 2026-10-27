# Compiler v4 Task 0 decisions

## Status and evidence

Task 0 is frozen from the owner-approved architecture direction and the
reproducible measurements produced by `task0/run-task0.ps1`. The checked-in
inputs and prototype are non-production architecture evidence. Generated
records belong under `bootstrap/out/v4-task0/` and are not bootstrap inputs.

The decision run uses the preserved v3 RP8 executable as the acceptance oracle,
compiles the prototype with the repository's C++17 bootstrap prerequisite, and
runs each parser mode three times over valid, malformed, depth-boundary, and
100/1,000/5,000-statement inputs. Stable counters, spans, normalized meaning,
and diagnostics must be identical on every repetition. Wall time and peak
working set are recorded as evidence but do not select the design by themselves.

## Syntax and parser decision

**Accepted:** a deliberate hybrid parser with compact selective syntax owned
per source. It is hand-written where UBE's contextual and compatibility syntax
benefits from direct recovery control, while a generated grammar inventory and
coverage checker prevent drift from `lang-doc/grammar/ube.ebnf`. Dispatch and
stored node identity use generated numeric production/kind IDs rather than
folded production-name strings.

The immutable source snapshot remains the lossless authority. Tokens retain
kind, exact byte span, source ID, decoded value only when needed, and explicit
links for preprocessing/source mapping. Trivia remains recoverable from source
gaps and is not represented by one syntax node per grammar wrapper. Selective
syntax stores only structural constructs, expressions, declarations, and
recovery boundaries required by later phases. Every node has an exact source
span. A phase that needs original spelling reads the immutable source through
the span; it may not cache a second source copy in the syntax arena.

Measured evidence supports the choice:

| Fixture | Full table nodes/bytes | Selective hybrid nodes/bytes | Result |
|---|---:|---:|---|
| Minimal module, 23 tokens | 25 / 568 | 6 / 72 | Same acceptance, spans, meaning, and diagnostics |
| Representative module, 97 tokens | 119 / 2,684 | 40 / 480 | Hybrid uses 82.1% fewer syntax bytes |
| 5,000 statements, 30,025 tokens | 45,026 / 1,000,596 | 20,005 / 240,060 | Hybrid stays at 7.996 syntax bytes/token |
| Malformed/truncated, 30 tokens | 35 / 792 | 10 / 120 | Same two recovery diagnostics and locations |

Both modes accept depth 32 and reject depth 65 under the prototype's deliberate
64-frame experimental limit without crashing. Both remain approximately linear:
work per token stays within the runner's 1.20 normalized bound across the three
scale sizes. The representative prototype covers 15 deliberately selected
production families. That coverage is sufficient to compare representation and
recovery costs; it is not evidence of complete UBE grammar support. Task 5 must
reach complete generated inventory coverage before its gate can pass.

The production language-facing parenthesis limit initially remains v3's frozen
limit of 10. The prototype's 64-frame limit proves that the selected explicit,
bounded technique need not depend on the native call stack; it does not silently
change the UBE 1.0 compatibility limit.

## Rejected syntax alternatives

- **Full lossless green CST with a node for every grammar wrapper and token:**
  rejected as the default. It preserved the required observations but used
  4.17 times the syntax bytes of the hybrid representation on the largest
  scale fixture and recreated the wrapper-node growth already measured in v3.
- **V3 generic grammar engine and global syntax arrays:** rejected. It remains
  valuable as an oracle, but 1,249,321 self-host syntax nodes, repeated grammar
  identity work, translated global offsets, and worker copying conflict with
  per-source ownership and local parallel work.
- **Unvalidated fully hand-written recursive descent:** rejected. Direct code
  is useful for recovery, but production coverage must be generated/checked
  against every normative production and recursion must have explicit bounds.
- **Generated table parser selected only for speed:** rejected. The prototype
  showed comparable deterministic work; wall time was too small and noisy to
  justify the much larger representation or its maintenance surface.
- **Concrete-syntax text copying:** rejected. Exact source bytes already have
  one immutable owner; duplicating spelling/trivia into nodes increases memory
  and complicates worker ownership without improving fidelity.

## Frozen phase interfaces

Every result is an immutable published envelope after construction. Construction
storage is private to its phase. A result contains its input identities/hashes,
completion status, ordered diagnostics, deterministic record/work counts, and a
release operation for external resources. `0` is the invalid ID for every ID
domain; valid IDs are one-based, nonnegative 32-bit `Long` values checked before
indexing. Counts and byte offsets use checked nonnegative `LongLong` arithmetic
at file/package boundaries and are narrowed only after a limit check.

| Producer | Published result | Stable identity and owned data | Consumer |
|---|---|---|---|
| Driver | `BuildSession` | configuration, limits, host, target, cancellation, source/project order | Project/source loader |
| Source loader | `SourceSet` | `ProjectId`, `SourceId`, immutable bytes, content hash, line index, source-map links | Lexer/preprocessor |
| Lexer | `TokenUnit` per source | `(SourceId, TokenId)`, token kind/span/value, preprocessing links | Parser |
| Parser | `SyntaxUnit` per source | `(SourceId, SyntaxId)`, selective nodes, child/range indexes, recovery boundaries | Declaration collection and procedure slicing |
| Declaration/type owner | `FrozenUniverse` | `DeclarationId`, `ScopeId`, `NameId`, `TypeId`, canonical lookup indexes and layouts | Procedure semantics |
| Procedure analyzer | `ProcedureResult` | `ProcedureId` plus local binding/expression/CFG IDs and compact program-summary records | Whole-program checks and IR lowering |
| IR builder/verifier | `VerifiedFunction` | `FunctionId` plus local block/value/instruction/edge/root/location IDs | Program-link verifier and backend |
| Backend worker | `BackendFragment` | target identity, `FunctionId`, LLVM/debug fragment and relocation/metadata requests | Canonical backend merge |
| Publisher | `ArtifactSet` | canonical artifact identities, hashes, cleanup/publication status | Caller and verified-build recorder |

Phases exchange these envelopes through versioned APIs, never through another
phase's mutable arrays. Debug snapshots serialize public envelopes only. An
invalid, cancelled, or limit-exceeded result may contain diagnostics but cannot
be published as a successful input to the next phase.

## Stable identity and merge rules

- `ProjectId` follows declared dependency order after validated graph
  canonicalization. The root project is first; ties use normalized project
  identity, never discovery completion.
- `SourceId` follows each project's manifest source order.
- `DeclarationId` follows `(ProjectId, SourceId, declaration start byte,
  declaration kind, ordinal-at-same-start)` after duplicate validation.
- `ProcedureId` and `FunctionId` derive from the owning declaration identity.
- `TokenId` and `SyntaxId` are local to one source. Semantic and IR local IDs
  are local to one procedure/function. Cross-arena references are composite
  owner ID plus local ID; global offset translation is forbidden.
- `NameId` is assigned when the single declaration owner freezes ordinal
  folded spellings. `TypeId` is assigned by canonical structural/type-declaration
  order. Hash buckets accelerate lookup but never allocate IDs or define order.
- Workers return private results keyed by stable owner identity. Coordinators
  merge by the rules above and assign final metadata numbers serially.
- Diagnostics order by project, source, start byte, byte length, severity,
  stable code, phase rank, and phase-local emission ordinal. Worker or hash
  order is never a tie breaker.

## Initial limits contract

Task 0 freezes the initial compatibility ceilings below. They are centralized
immutable session values, checked before allocation/growth, included in build
records, and exercised at inside/outside boundaries. Raising one later requires
measurements and a documented compatibility decision; lowering one requires
owner approval because it rejects formerly accepted input.

| Limit | Initial value |
|---|---:|
| Diagnostics per compilation | 100 |
| Project manifest bytes / lines | 1,048,576 / 100,000 |
| Sources / resources / references per project | 1,024 / 1,024 / 256 |
| Bytes per source / combined source bytes | 16,777,216 / 67,108,864 |
| Combined resource bytes | 67,108,864 |
| Tokens per compilation package | 300,000 |
| Parenthesis nesting / conditional depth | 10 / 256 |
| Grammar productions / generated grammar records | 512 / 16,384 |
| Selective syntax nodes | 1,250,000, additionally budgeted at `2 * tokens + 4,096` |
| Scopes / declarations / types | 100,000 / 250,000 / 65,536 |
| Semantic/CFG traversal depth | 512 explicit frames |
| Generated textual artifact bytes | 268,435,456 |
| Process arguments / captured stdout / captured stderr | 4,096 / 16,777,216 / 16,777,216 bytes |
| Worker count | 1 reference; later bounded to `min(requested, runnable, 32)` only after Task 11 gates |

No record count may reach the invalid/sentinel values of its ID type. Aggregate
allocation uses a separate checked byte calculation even when record counts are
within limits. Limit failure emits one primary controlled diagnostic, stops the
affected phase, drains owned work, and publishes no success artifact.

## Diagnostic comparison policy

Differential levels are those in `REUSE_PLAN.md`. At level 1, v3/v4 compare
acceptance, exit status, artifact presence, diagnostic code, severity, source
identity/span, notes, and deterministic order exactly. Public diagnostic text
also compares exactly when the frozen ledger marks it stable. Internal phase
details and intentionally improved secondary recovery may differ only through a
named, reviewed normalizer recorded in the case and build record.

Token and syntax comparisons use stable kind/production IDs, exact spans, and a
normalized tree/event form that omits representation-only wrappers. Semantic,
IR, ABI, LLVM, native, package, and fixed-point comparisons add their respective
observable decisions without weakening earlier levels. A normalizer may remove
only fields declared non-semantic before the test is run; it may not erase a
diagnostic, reorder observable results, or bless a new mismatch.

V4-only limit, corruption, or infrastructure diagnostics receive stable v4
codes and focused cases. They do not masquerade as v3 parity. Every rejected
input must still compare exit status and absence of false-success artifacts.

## Library and compiler-support boundary

The first vertical slice has no unclassified facility:

| Capability | Owner before v4 use |
|---|---|
| Token kinds, grammar IDs/tables, recovery, syntax nodes | Compiler |
| Diagnostic codes, phase validation, semantic/IR/backend policy | Compiler |
| UTF-8 scalar decoding and Unicode 18 simple folding | UBECore text/Unicode |
| Bounded vectors, hash maps/sets, stable sort, text/chunk builder | UBECore collections/text |
| SHA-256 and bounded binary encoding | UBECore hashing/serialization |
| Lexical portable path operations | UBECore paths |
| File reading and atomic replacement contract | UBECore files with platform adapter |
| Separate-argument process execution, bounded capture, timeout/cancel | Versioned compiler-support package with platform adapter |
| Monotonic measurement and peak-memory query | Compiler-support measurement adapter; evidence only |
| Thread/task executor | UBECore concurrency after its Task 1 contract; not required by the sequential first slice |
| Native file/process/clock/thread primitives | Explicit platform substrate |

Task 1 may choose concrete API names only after focused library tests. It may
not move compiler policy into a library, expose compiler records publicly, add
a third-party dependency, or hide these facilities behind new intrinsics.
The Task 2 shell and Task 3 vertical slice remain sequential and may use only
the exact versioned subset recorded in their dependency manifest.

## Test contract decision

`task0/TEST_FORMATS.md` is the frozen input/output contract. `UBE-Test-Case 1`
is the dependency-minimal checked-in case format; `ube-v4-verified-build-1` is
the generated evidence format. The cumulative runner validates all manifests
before execution, uses separate arguments, isolates outputs, merges by case ID,
records exact skips/reasons and deterministic counters, checks cleanup, and
publishes atomically only after the complete gate passes.

For every capability the inventory must account for positive, interaction,
rejection, boundary, stress, failure injection, regression, differential,
native, and determinism. Task 0 marks native behavior not applicable because no
code is generated, and records the reason in its manifest. The Task 0 runner
covers manifest acceptance/rejection/path escape, valid and malformed syntax,
depth boundaries, scaling, publication failure, repeated identity, v3
acceptance, and cleanup. Task 2 creates the production cumulative hierarchy and
runner from this contract; it does not redesign the format implicitly.

## Other rejected architecture choices

- Copying or gradually renaming v3 modules: rejected; contracts and cases are
  reused, while implementation is admitted only by the narrower reuse audit.
- Whole-program global syntax/semantic/IR numbering during worker work:
  rejected in favor of owner-local IDs and canonical merge.
- Parallelism in the first slice: rejected until sequential work counters,
  ownership, cleanup, parity, and memory budgets pass.
- Compiler-private replacements for ordinary collections, Unicode, hashing,
  files, paths, process, or executor facilities: rejected by the frozen
  ownership table.
- Shell command construction and publish-in-place artifacts: rejected; process
  arguments are separate and publication is validated then atomic.
- Choosing designs from self-host success alone: rejected; small phase-local
  positive/failure cases and scaling counters are permanent prerequisites.
