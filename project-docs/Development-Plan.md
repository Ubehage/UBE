# UBE development plan

Date: 2026-10-31.

**Status: the first owner-requested concurrency objective is complete; every
later deliverable remains proposed.** This plan preserves the owner's vision,
adopted language rules, established names and separate UBECore/compiler
responsibilities. It does not approve new language rules, representations,
phase interfaces or general scheduler APIs.

The owner-approved bounded contracts, bootstrap prerequisites and actual
compiler-owned `TryParseSources` proof are qualified. Existing UBE source,
scanner and parser bodies run with budgets 1, 2 and 4 over shared immutable
owners and private results. Exact current gates and limits are in
[CONCURRENCY-EVIDENCE.md](../compiler/UBE_Compiler_v3/CONCURRENCY-EVIDENCE.md).
This does not complete normal `.UBE` project/reference input or its CLI.

The proposed next deliverable is bounded `.UBE`/direct-UBECore input and parallel
frontend integration. It needs its own contract and owner review before
implementation. Instrumented four-worker execution was slower than one-worker
execution; measured collector contention is focused follow-up work. Later
semantic/backend and product rows remain proposed as well.

On 2026-10-31 the owner approved making useful parallel speedup an explicit
acceptance requirement. The [parallel performance gate](#parallel-performance-acceptance)
below belongs to the existing frontend work; its optimization and measurement
remain unfinished. The completed concurrency correctness proof stays complete.

## Why this plan exists

The owner identified three failures in the earlier attempts: UBECore and compiler
responsibilities became mixed, agents changed function-naming conventions during
development, and the closest implementation could not support multithreading
satisfactorily and is now archived. These are requirements for the new plan to
address, not permission to import the archived architecture.

The proposed order therefore proves actual compiler concurrency while the fresh
implementation is small, before substantial semantic/backend growth. A large
sequential implementation followed by a concurrency retrofit is not this plan.
The existing component tests with native workers do not qualify a production
compiler scheduler or UBE-language thread capture.

## Product direction that stays fixed

| Commitment | Consequence for development | Existing authority |
| --- | --- | --- |
| A native, fully 64-bit compiler written in UBE | Ordinary production compiler and library logic stays in UBE; GCC/C++ serves bootstrapping, with explicit temporary substrate exceptions and removal conditions | [Project guidance](../AGENTS.md), [architecture](architecture.md) |
| Classic VB6 textual syntax with defined modern behavior | Implement the frozen language, preserve original source information, and distinguish an unimplemented valid feature from an invalid program | [Core specification](../lang-doc/language-spec.md), [grammar](../lang-doc/grammar/ube.ebnf) |
| Strict declarations and types, with the specified convenient conversions | No implicit Variant mode, overload invention, name-based builtin shortcuts or host-language conversion rules | [Core specification](../lang-doc/language-spec.md), [conversion table](../lang-doc/conversion-table.md) |
| UBECore and compiler are separate | Reusable algorithms and datatype behavior belong in UBECore; syntax, binding, diagnostics, target and backend policy belong in the compiler | [Library boundary](../std-lib/DESIGN.md), [compiler boundary](../compiler/UBE_Compiler_v3/DESIGN.md) |
| Library-defined native datatypes | Use the adopted opaque native-value mechanism; additional representations/lifecycle mechanisms require contracts and evidence rather than hidden compiler implementations | [Native-value contract](../std-lib/NATIVE-TYPE-PROPOSAL.md) |
| Small, fast native output and an efficient compiler | Measure real work, copying, allocation and memory; maintain reproducible output and prevent whole-project replication per worker | [Architecture](architecture.md), [compiler guidance](../compiler/UBE_Compiler_v3/AGENTS.md) |
| Multithreaded compilation | Design ownership and publication now, prove real parallel compiler work early, and keep one bounded budget with a deterministic one-job reference | [Compiler guidance](../compiler/UBE_Compiler_v3/AGENTS.md), [threading semantics](../lang-doc/threading.md) |
| Recoverable failures preserve work | No panic paths, uncontrolled recursion, partial publication or automatic error dialogs; exercise resource exhaustion and cleanup | [Project guidance](../AGENTS.md), [managed memory](../lang-doc/managed-memory.md) |
| Portable, dependency-minimal implementation | Keep OS details in adapters; no npm, install-time downloads, Tauri, Electron or webview shells | [Dependency policy](../Dependencies.md), [architecture](architecture.md) |
| Debugging and a native IDE with VB6-like ease of use | Preserve original spans and source identities throughout the compiler; plan debug metadata and tooling without replacing the native product vision | [Project vision](Project-Vision.md), [root README](../README.md) |

The primary specification and focused normative contracts outrank conflicting
expanded wording. The approved native-value addition remains in force. A roadmap
can defer implementation; it cannot silently redefine language behavior.

## Verified parser checkpoint before concurrency

The active compiler is the fresh `compiler/UBE_Compiler_v3/`; the previous v3/v4
trees remain historical. No new compiler generation is proposed.

- The then-current source-built v2/bootstrap gate passed 501 grouped checks.
- UBECore provides the qualified byte storage, UTF-8, Unicode/cursor and bounded
  file-input facilities. General String, collection and library-packaging support
  must not be inferred from that result.
- Fresh v3 preserves source bytes, scans and recognizes envelopes, and implements
  the bounded native MODULE grammar in its parser contract.
- The production parser gate passes 4049 checks, 188 cases and 10412 real-root
  capacities through both source-built stages. Its 102 measured cost rows,
  independent-instance workers and failure retention pass their stated gates.
- Strict CLI acceptance passes 82 cases and 54 diagnostic controls. The local
  artifact passes 41 process oracles; the relevant raw LLVM pairs are identical.

Exact commands, identities, scope and failure evidence are in
[PARSER-NATIVE-EVIDENCE.md](../compiler/UBE_Compiler_v3/PARSER-NATIVE-EVIDENCE.md).
These preserve the plan's starting point. Current source-cohort qualification
and retained earlier-gate reruns are in `CONCURRENCY-EVIDENCE.md`. The fresh
compiler does not yet semantically check or compile programs. The parser is not
the full grammar: pending conditionals, other source kinds, designer syntax and
the other deferred families remain explicit unfinished work.

## Where decisions and status live

| Information | Maintained source |
| --- | --- |
| Product vision and owner requirements | Root guidance/README, [Project-Vision.md](Project-Vision.md), owner-maintained release requirements |
| Language and observable behavior | `lang-doc/language-spec.md`, focused normative contracts and grammars |
| Proposed dependency order and reasons | This document |
| Approved current item and exact next action | Root [Workplan.md](../Workplan.md), compiler [Roadmap.md](../compiler/UBE_Compiler_v3/Roadmap.md) and [Progress.md](../compiler/UBE_Compiler_v3/Progress.md) |
| Library contracts and current needs | `std-lib/` contracts and [ROADMAP.md](../std-lib/ROADMAP.md) |
| Completion claims | Maintained gates and evidence identifying the exact source/tool/artifact cohort |
| Earlier compiler plans and results | Archives and explicitly dated historical evidence; no inherited implementation approval |

The project-wide roadmap remains the long-term feature inventory. Module roadmaps
link here rather than maintaining competing detailed execution orders. Historical
contract introductions describe their original checkpoint; current capability
claims come from current evidence. Conflicting current-state statements must be
corrected in the affected current documents instead of being copied into new plans.

## Naming and API continuity

The proposal is to preserve established names and use the same conventions for
new declarations. This applies to private helpers as well as library operations.

- Continue PascalCase and lasting domain names, following the surrounding module.
  Types name their domain, such as `SourceDocument` and `SyntaxResult`; modules
  have functional names, such as `ByteBuffer` and `FileBytes`.
- Reuse exact existing declarations: for example `ByteBufferLength`,
  `TryAppendBytes`, `TryOpenByteFile`, `TryReadSourceScalar` and `BeginSourceInput`.
  Do not rename an existing function to make its spelling fit a personal style.
- New fallible operations follow established fresh-status conventions, normally
  `Try...` where consistent with the relevant API. This is not a blanket rename
  of existing Boolean functions. Success must not be inferred from stale `Err`.
- Agree callable names, passing modes, result/failure meaning and ownership in
  the selected contract before implementation. Keep declarations, call sites,
  primitive bindings, tests, documentation and manifest/module identities aligned.
- No task/phase/session/generation prefixes in production identifiers. Do not
  introduce a new prefix or abbreviated naming scheme midway through a feature.
- A necessary rename is a separately identified compatibility change with a
  reason and complete call-site/API review. An agent's preferred style is not a
  reason. Check existing declarations against the agreed contract at acceptance.

The authoritative signatures remain in the relevant contracts/source declarations;
this plan does not create a competing copy of the entire API catalog.

## Ownership and responsibility checks

Classify each planned facility before adding code:

| Work | Owner |
| --- | --- |
| General byte/text operations, numeric text parsing/formatting, collections, sorting, hashing and reusable file/process/concurrency facilities | UBECore, after a demonstrated need and a focused contract |
| Project/reference policy, source mapping, grammar, name resolution, semantic types, diagnostics, lowering and backend policy | Compiler |
| Irreducible storage, allocation/rooting, atomics, thread transitions and target ABI mechanisms | Small documented compiler/substrate boundary, with exact bindings and tests |
| OS handles, platform constants and native calls | Platform adapter behind the relevant contract |

A spelling such as `Len` or `Mid$` never grants special parser/backend status.
Compiler-specific types and policies do not enter UBECore. General algorithms
do not acquire a duplicate implementation inside the compiler to avoid a missing
library facility. A shared facility starts small: neither a general collection
framework nor all 710 library inventory entries are prerequisites to one consumer.

Before selecting worker parameters, document the actual lifetime and sharing of
sources, tokens, syntax, declarations and output. In particular, ordinary array/
record value copies and `CallNew` ByVal capture cannot be treated as free aliases.
Prove an approved way to share immutable backing while keeping the owner alive
and GC-safe until workers drain. The plan does not choose a handle type, reference
layout, raw-address escape or new primitive to accomplish this.

## Proposed dependency order

These are deliverables in existing compiler/library responsibilities, not new
compiler generations or frozen phase APIs. Each row must be split into its own
bounded contract and acceptance cases before implementation. Work can overlap
only when its stated dependencies and ownership contracts permit it.

| Deliverable | Prerequisites and bounded result | Completion evidence |
| --- | --- | --- |
| Boundary, naming and compiler-concurrency contracts | Current qualified parser; classify required facilities, preserve naming, specify shared-input/private-result lifetimes, fresh status, cancellation and one worker budget | Reviewed contracts, named decisions, independent expectations and preset work/copy bounds; no production scheduling claim |
| Qualified UBE threading/sharing prerequisites | Small actual UBE programs compiled through both selected v2 stages; prove the precise thread, sharing, roots and error mechanisms the compiler will use | Actual overlap and bounded admission, visibility, TLS Err, immutable lifetime, capture/copy measurements, failures, cancellation/drain and cleanup; extend the bootstrap only for a reproduced missing prerequisite |
| Bounded project input and parallel frontend | Normal `.UBE` input, ordered native MODULE sources and direct explicit UBECore source references; existing source/scanner/parser bodies perform real work in one compiler process | Same complete graphs/diagnostics in one-job and multi-job runs, original spans, no whole-project/job copies, actual overlap, bounded resources and cleanup; pass the parallel performance gate below |
| First semantic checking | Qualified frontend/ownership path and passed parallel performance gate; contract for declaration details, scopes, explicit types and selected scalar expressions/statements | Independent binding/type/diagnostic cases, primitive/native-type boundaries, exact spans, failure atomicity and deterministic private body results; not a whole-language checker |
| First checked native executable | Normal project/reference path, bounded semantic result and reviewed lowering/backend/tool-handoff contracts | Real fresh-v3 compilation of small programs; exact exit/results, ABI and runtime error oracles, validated LLVM, deterministic output, full-disk/tool/cancel failures preserving an old artifact |
| Compiler-required managed values and library facilities | Concrete programs expose missing array/record/String or conversion/storage needs; adopted native-value mechanism remains authoritative | Library and compiler tests for ordinary user-defined native types, deep value copies, roots, neutral/Err behavior, no hidden String/Decimal/Date/Variant backend implementations |
| Fresh compiler rebuilds itself | Exact feature/dependency coverage of the real compiler and UBECore source; qualified parallel execution retained as code grows | Reproducible fresh build chain from checked-in source, successive raw LLVM comparison under an agreed policy, independent native/rejection/failure tests and equivalent worker-count results |
| Remaining language and source coverage | Incremental contracts for conditional selection/inactive text and each deferred grammar/semantic family | A production-by-production coverage ledger, exact positive/reject/deferred cases and integration with earlier native/parallel gates; no claim that the current parser already covers it |
| Complete type/library/foreign boundaries | Required representations and lifecycle/ABI decisions, explicit source/binary Library contracts, scope from the normative language and library inventory | Public callable contracts, independently tested conversions/types/resources/exports, reference boundaries, reproducibility and platform availability |
| Debugger, product tooling and native IDE | Preserve locations from the first semantic/native work; build debugger/tooling against stable reviewed compiler outputs | Breakpoints, stepping, locals/stacks, errors and native UI/resource lifecycle tests; VB6-like workflow without a webview shell |
| Wider targets and release preparation | Explicit owner-selected host/target and release scope, measured compiler/library maturity | Per-target ABI/native/debug evidence, packaging/offline rebuilds, maintained manual, approved samples and the owner's release requirements |

Performance, compiler parallelism, documentation, diagnostic quality, ownership
and failure tests apply to every row. They are not cleanup tasks reserved for the
end. Source locations and debug requirements likewise constrain early designs.
Conditional selection must precede any claimed support for programs needing it;
it cannot be implemented by requiring a successful raw scan of inactive text.
Additional grammar/types needed by compiler sources move earlier as explicit
dependencies, rather than silently being implemented under a different item.

A first native executable or self-hosting result is an engineering checkpoint,
not automatic full-language, library, multithreading or public-release acceptance.
The native IDE follows a dependable compiler/debugging foundation; its exact
release placement is not fixed here. Existing owner release requirements remain
in the owner-maintained file; this proposal does not add requirements to it.

## Parallel performance acceptance

Correct concurrent results and useful parallel speedup are separate requirements.
The existing correctness proof passed; its instrumented timings do not pass this
performance gate. Pass this gate before declaring the parallel frontend complete
or beginning substantial semantic/backend growth. It is an exit requirement for
the existing frontend deliverable, not a new compiler phase or subsystem.

Initial engineering targets, measured against the optimized one-worker path:

| Workload | Required median result |
| --- | --- |
| Representative real source corpus, two workers | At least 1.5 times the one-worker throughput: `T1 / T2 >= 1.5` |
| Representative real source corpus, four workers | At least twice the one-worker throughput: `T1 / T4 >= 2.0` |
| Larger balanced source corpus, two/four workers | Meet the same 1.5/2.0 speedup targets |
| Optimized one-worker execution | No more than 5% slower than the frozen pre-optimization one-worker baseline |
| Small source sets, including one source with budget four | No more than 10% slower than the optimized one-worker path; the budget is a maximum, not a requirement to start unnecessary workers |

Freeze corpus bytes/hashes, expected complete results, build flags, commands,
hardware and timing boundaries before optimization. The real corpus must include
every currently supported production MODULE, with unsupported source kinds
reported explicitly. The larger corpus must contain at least 32 independent,
representative MODULE inputs; include a separate uneven-size workload to expose
load imbalance. Do not select only easy synthetic cases or discard slow files.
Make timed batches long enough for the one-worker median to exceed one second;
every repetition must perform fresh scan/parse work, without reusing parsed results.

Use matching optimized native builds without observers, forced rendezvous,
schedule controls or profiler hooks in the timed path. Measure from admission of
the qualified source set through complete publication and worker drain, including
thread startup and synchronization. Source intake, process launch and fixture
setup are outside this CPU-work interval and must be reported separately; record
end-to-end project timing once that driver exists. Preserve the same entry point,
language behavior and work at budgets one, two and four.

Use an otherwise idle machine with at least four physical cores available and
record CPU/core counts, OS, power configuration, tool/source identities and memory.
Run at least seven trials per budget in interleaved order in each of two complete
sessions. Report every trial, medians, ranges, CPU time and peak memory. Establish
a repeatable warm-cache and pre-trial heap state outside the timer. If variation
prevents a reliable comparison, report inconclusive and repeat the complete
session; do not cherry-pick favorable trials or change thresholds after failure.

Run the existing instrumented correctness, copy, root, cancellation and failure
gates separately against the same candidate sources. Retain their predefined
memory/ownership bounds, zero worker source-payload copies, complete deterministic
outputs and cleanup. Report allocation, copying and collector/coordination costs
to explain the result; extra memory or duplicated work is not a substitute for
speedup. Investigate the measured collector contention with the smallest focused
sample before changing shared behavior. Reusable mechanisms stay in UBECore;
compiler policy stays in the compiler. Architectural changes still require the
owner's explicit approval.

Completion requires both sessions to meet the targets on both main corpora,
the single-worker/small-input guards to pass, and all correctness/resource gates
to remain qualified. Record evidence in the current workplan before marking this
requirement complete. A failed or inconclusive result remains unfinished; changing
the gate requires an explicit owner decision. Approval of this requirement does
not itself start an optimization goal or approve the other proposed plan rows.

## Proposed next contract: bounded project input and parallel frontend

The first concurrency objective is complete. `TryParseSources` establishes the
compiler-owned work, sharing, private-output, ordering, cancellation and
publication path; UBECore retains reusable mechanisms. Its concrete limits and
observed costs are in `CONCURRENCY-CONSUMER.md` and `CONCURRENCY-EVIDENCE.md`.

The proposed successor is the smallest normal `.UBE` input with ordered native
MODULE sources and direct explicit UBECore source references. Define source
identity, relative-path/reference policy, bounded failures, ownership,
diagnostics and CLI behavior in its own contract for owner review before coding.
Feed one canonical source set to the existing operation; do not introduce
another driver, executor, model copy or independent budget.

Acceptance must compare complete one-worker/multi-worker results and first
diagnostics, original spans, empty/invalid/reference cases, cancellation,
allocation/admission failures, old-output retention and cleanup. Preserve the
concurrency and earlier parser gates. Investigate measured collector contention
with focused reproductions and recorded costs; do not infer a speedup or change
architecture from instrumented timings alone. This row and all later rows
remain proposed; no successor implementation is authorized by completing the
concurrency goal. Semantic work remains the later bounded proposal below.
The owner-approved parallel performance gate above is part of this row's exit
criteria and must pass before substantial semantic/backend growth.

## Semantic work prepared next

The first semantic contract should remain small enough to assess independently.
The proposed starting scope is native MODULE declarations, procedure/local scope,
mandatory explicit types, selected Boolean/integer expressions, simple assignments,
procedure results and carefully bounded calls. Exact supported types/operators and
call forms must be enumerated before implementation; this paragraph is not that
acceptance contract.

Before choosing semantic storage, check what the qualified parser actually retains.
Some declaration/parameter/Header nodes intentionally keep opaque original spans
after validating and discarding private detail. Inventory the name, suffix, type,
modifier, default, argument-parenthesis and attribute information binding needs.
Make any required syntax-detail extension explicit and rerun its gates; do not
guess declarations from node kinds, change witnesses silently, or create a second
independent source parser inside the checker.

Name resolution must follow the frozen declaration regions and lookup order,
Unicode simple folding, bracket/suffix identity, accessibility and ambiguity rules.
Block placement must not accidentally create C-style declaration regions; source
or reference order never breaks an ambiguous-name tie. Exact ByRef identity,
parenthesized temporaries and ordinary library calls remain the specified behavior.

Literal syntax, invariant value decoding, constant evaluation and target range
checking are distinct obligations. Reusable numeric/text algorithms belong in
UBECore; language literal grammar, operator selection and compile-time diagnostics
remain compiler policy. No host locale, bootstrap permissiveness or LLVM undefined
behavior supplies a language rule. Required constant failure is a diagnostic;
runtime-dependent failure retains neutral-result/Err semantics.

Define valid, invalid and deferred cases before implementation: folded duplicate
names, undeclared names, implicit typing, `Option Explicit Off`, suffix conflicts,
nonassignable targets, type/constant range boundaries, wrong call arguments and
procedure-result/terminator rules as the selected scope requires. Invalid syntax,
semantic error, valid-but-deferred feature, domain/resource failure and storage
failure must remain distinguishable.

Declaration publication and body work must be designed for the qualified shared
budget and deterministic result ownership. A second executor or a mutable global
semantic model is not an implicit consequence of adding a checker.

## How each item becomes complete

Before coding, record its objective, authoritative rules, exact included/deferred
behavior, dependencies, owning layer, agreed identifiers, lifetime/copy/failure
contracts, independent expected cases, measurement bounds and acceptance commands.
Resolve a semantic or representation decision before depending on it. Temporary
bootstrap exceptions need a bounded purpose, evidence and a removal condition.

Completion requires the relevant exact native results, rejects, malformed and
boundary cases, allocation/admission/cancellation behavior, cleanup, deterministic
worker results and actual cost comparisons. Preserve applicable earlier gates.
Every crash fix includes the small synthetic regression that reproduced it.
Compilation, informal inspection, a test count, self-hosting or an agent's report
does not replace the relevant assertions.

Record source/tool/artifact identities, commands, passed gates, failed attempts,
measured work, supported limits, unresolved decisions and the next action. Update
current workplans and public documentation in the same change. A completion marker
must name its evidence; an implemented but unqualified item remains incomplete.

## Review and handoff

The first concurrency objective has its own completed qualification. Planning
completion does not mean that future contracts are approved or future gates
have passed.
Before adopting the next execution item, the owner should review:

- retaining the qualified compiler-concurrency gate as semantic work grows;
- the preserved naming conventions and separate UBECore/compiler responsibilities;
- the first semantic/native scope and the decisions deliberately left open.

The first owner-requested concurrency contract and prerequisite proof are now
qualified. Review the proposed project/frontend input contract before depending
on new policy or APIs. Keep every later row proposed until its own contract,
dependencies and owner review are ready. No implementation, push, release or new
compiler generation is authorized merely by adding this planning document.
