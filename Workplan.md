# UBE workplan

This is the repository-wide resumable checklist for active goals and handoffs.
Owner-defined release requirements live in `Release-Requirements.md`; long-term
sequencing lives in `project-docs/Roadmap.md`; module-specific work may use a
nearer roadmap or progress file.

## Status markers

- `[ ]` not started
- `[~]` in progress
- `[x]` complete and verified
- `[!]` blocked, with the reason and required decision recorded

## Current priority — 2026-10-31

The first UBECore byte/text foundation is implemented and independently tested:
an incremental UTF-8 decoder and owned ByteBuffer with geometric growth,
failure-atomic operations and independent snapshots. The owner approved the
managed-storage scope and permits extending v2 as necessary for bootstrap.
`bootstrap/build-v2.ps1` now passes 501 grouped assertions, retaining the earlier
foundation gates and adding the fresh scanner/envelope consumer and exhaustive
Unicode qualification. Current runtime/bootstrap and production-parser results
are in `compiler/UBE_Compiler_v3/PARSER-NATIVE-EVIDENCE.md`; representation probes
remain in `compiler/UBE_Compiler_v3/PARSER-PROBE-EVIDENCE.md`. The earlier
scanner snapshot remains in `compiler/UBE_Compiler_v3/SCANNER-EVIDENCE.md`.

Completed: implement the smallest compiler source-ingestion consumer of these APIs.
`compiler/UBE_Compiler_v3/SOURCE-INPUT-CONTRACT.md` defines exact byte preservation,
streaming UTF-8/newline validation, scalar positions and independent publication.
The minimal fresh source and manifest pass independent native, failure, cleanup,
position and actual cost oracles through both source-built stages. Necessary
bootstrap prerequisites include recoverable byte-file/Unicode argument primitives
and bounded direct source-library references with envelope validation.
Source policy and diagnostics remain compiler responsibilities. Full shared
Library output, builtin String and language checking remain unqualified. No
archived implementation or restored compiler is required.

Completed next: define scanner/native-or-legacy envelope acceptance over exact
source snapshots. `compiler/UBE_Compiler_v3/SCANNER-CONTRACT.md` and its 102
hand-authored vectors/174 word roles pass 2286 data-consistency assertions.
This established the independent definition before production implementation.
Its historical readiness probes remain in the scanner evidence.

Completed: implement that defined consumer in UBE, with narrow reserved-name
renames, official pinned Unicode 18 data, ordinary UBE lookup/cursor helpers,
exact token/envelope spans, controlled diagnostics and failure-atomic results.
Both source-built stages pass native fixtures, real root/allocator failures,
cleanup, four private-worker comparisons and measured scanner copy/work budgets.
The complete gate passes 501 assertions; the scanner's observed executable
executes 2274484 native assertions per stage. Legacy recognition and raw date/
directive tokens do not establish their full grammar or semantics. `--check`
still reports checking unavailable after a successful scan.

Completed: define the first grammar consumer over qualified token/envelope views.
`compiler/UBE_Compiler_v3/PARSER-CONTRACT.md` has 116 hand-authored cases covering
grouping, source spans, structural rejection, later semantic obligations and
explicit deferred families. The definition gate passes 11969 new consistency
assertions and 16 negative controls; a separate identity audit preserves the
existing 501-check native cohort. That definition did not qualify an
implementation. Exact results and limits are in
`compiler/UBE_Compiler_v3/PARSER-EVIDENCE.md`.

Completed: focused native UBE storage/traversal probes pass 3828 assertions through
both accepted source-built stages. The measured choice is linked-child nodes and
explicit stacks. Persistent allocator denial exposed and fixed recoverable GC
tracing/first-error publication; the complete fresh source gate passes 501 grouped
checks with stronger recovery regressions. Exact identities, costs, tradeoffs and
limits are in `compiler/UBE_Compiler_v3/PARSER-PROBE-EVIDENCE.md`.

Completed: implement and independently qualify the bounded production grammar
consumer in `compiler/UBE_Compiler_v3/PARSER-CONTRACT.md`, using that representation,
borrowed source/token views, private pending nodes and atomic complete-result
publication. Native acceptance covers the full frozen syntax/rejection/deferred
cohort while preserving ownership, diagnostics, budgets, cleanup and measured
work/copy obligations. No UBECore API expansion was needed.
The refreshed bootstrap passes all 501 checks. The unrestricted parser gate
passes 4049 grouped checks through both source-built stages, all 188 independent
cases, 10412 actual root capacities and 102 cost rows, including complete failure
retention and cleanup. Strict CLI acceptance passes 82 cases and 54 diagnostic
controls; the rebuilt local executable passes all 41 process oracles. Exact
commands, hashes, limits and handoff are in
`compiler/UBE_Compiler_v3/PARSER-NATIVE-EVIDENCE.md`. No generic collection or worker
scheduler was added. The next bounded contract is not selected by this checklist.

The owner chose to establish a fresh UBECore in `std-lib/` before further
compiler feature expansion. Grow the library with concrete compiler needs;
do not import the previous implementation or assume its APIs are the new base.
The existing v3/v4 plans below are preserved history and do not define the
next active implementation task.

The owner subsequently approved early library-defined native datatype
mechanisms and investigation of the smallest stage-zero/v2 bootstrap route.
The fresh compiler is named v3. Previous v3/v4 implementations, previews and
compiler-wide handoffs are now under `compiler/archived/`, with exact original
working-tree snapshots and recorded relocation-only integration edits. Resume
from `compiler/UBE_Compiler_v3/Progress.md` and `std-lib/ROADMAP.md`.

- [x] Move the entire previous library to `archive/source-library/`, preserving
  all 28 files byte-for-byte, including working-tree changes and instructions.
  `archive/source-library.snapshot.json` records sizes and SHA-256 values.
- [x] Establish `std-lib/UBECore.UBE`, its empty identity module, design,
  contributor guidance, and `std-lib/ROADMAP.md`.
- [x] Retarget historical build/test paths to the archived library; keep them
  separate from the fresh project.
- [x] Build the owner's requested finished-library inventory for VB6, VBA7,
  and UBE additions in `std-lib/INVENTORY.md`; keep planned scope distinct
  from implemented or frozen APIs. Its documentary gate covers 175 reference
  function/alias names and 73 historical private intrinsic names; detailed
  component-member/signature/value reconciliation remains explicitly open.
- [x] Select and test the bounded bootstrap tool/subset and define the first
  library contracts before implementation. Resume from `std-lib/ROADMAP.md`.
  The shared ledger and independent cases are in `std-lib/FOUNDATION.md`.
  The source-built seed and two restored v2 artifacts pass all 18 diagnostic-
  subset checks, but nine target probes fail. Exact results/provenance are in
  `std-lib/FOUNDATION-EVIDENCE.md`. The subsequent v2 and native-value goals
  resolve the scalar prerequisites. The approved managed extension and byte/text
  body qualification now pass the combined 296-assertion gate; initial failed
  probes remain historical evidence rather than acceptance results.
- [x] Complete the owner's bounded usable-v2 prerequisite: current-source build,
  fixed point and 130 independent acceptance assertions, with exact provenance
  and a maintained compile helper. No archived implementation was imported.
- [x] Archive previous v3/v4 and their preview/history material, preserve exact
  original bytes for 367 files, and establish the fresh v3 design/workplan.
- [x] Record the owner's native-datatype and temporary-bootstrap decisions;
  adopt and prove opaque scalar representation, explicit binding, zero/copy,
  equality and rejection behavior under delegated design authority.

Structural setup and archive-integrity checks do not constitute compiler or
library execution verification. Library module bodies now have independent
execution proofs; a full native Library project build remains unqualified.

## Preserved compiler checkpoint

- [x] Preserve and verify the self-hosting UBE Compiler v2.
- [x] Add ordered multi-module compilation and cross-module resolution to v2.
- [x] Reorganize documentation into public, normative-language, and project
  documentation areas.
- [x] Complete and statically verify the public documentation snapshot for the
  frozen UBE 1.0 definition, with specified behavior separated from verified
  Compiler v2 behavior and unresolved public APIs represented by status pages.
- [x] Define and freeze the UBE 1.0 language contract for Compiler v3.
- [x] Create the previous `compiler/archived/UBE_Compiler_v3/` with its architecture, roadmap, and
  v2-buildable project scaffold.
- [x] Establish the previous `source-library/` root (now archived) for UBE library source,
  with preview, portability, ownership, and resumable-work boundaries.
- [~] Develop and compile v3 using the preserved v2 compiler.
  - [x] Preserve the explicit RP0 scaffold baseline.
  - [x] Complete RP1: bounded multi-module compiler shell, project/source
    validation, host/target descriptions, compatibility identities, and the
    API-empty `UBECore` project boundary.
  - [x] Complete RP2: native and compatibility source envelopes, frozen UBE
    1.0 tokenization, conditional compilation, stable source mapping,
    deterministic token output, bounded recovery, and malformed-input tests.
  - [x] Complete RP3: embedded frozen grammar, complete bounded parser, owned
    syntax records, deterministic syntax output, recovery, and grammar-wide
    coverage.
  - [x] Complete RP4: bounded scopes and Unicode-folded symbols, semantic type
    and expression records, entry-point and declaration validation, stable
    semantic diagnostics, deterministic semantic output, and focused rejection
    tests.
  - [x] Complete RP5: verified typed IR, native LLVM output, compiler-owned
    toolchain handoff, and deterministic self-compilation.
  - [x] Complete RP6: managed values, objects/interfaces, tracing collection,
    project references, callable `UBECore`, and the foreign ownership ABI.
  - [x] Complete RP7: structured errors, threads and synchronization, events,
    forms/controls, and component lifetime with deterministic failure gates.
  - [x] Complete RP8 with project-group orchestration, bounded hashed resource
    and library bundles, explicit remaining-language compatibility diagnostics,
    optimization/debug controls, the minimum public `UBECore` API, and a
    verified Linux x86-64 ELF object boundary.
  - [ ] After the RP8 gate, execute the Beta 1 compiler parallelization plan in
    `compiler/archived/UBE_Compiler_v3/MULTITHREADED_COMPILER_PLAN.md`: preserve the
    v2-built sequential seed, add deterministic `--jobs` execution in measured
    phases, keep one job as the default, and require explicit caller-selected
    parallelism after reproducibility, failure, memory, and performance gates
    pass.
    - [x] Phase 0: add opt-in sequential compiler profiling, publish repeatable
      self/UBECore/source/procedure baselines, and remove the measured
      superlinear semantic and IR lookup paths.
    - [x] Phase 1: freeze and prove the sequential seed/production bootstrap
      split and record seed/executor identities.
    - [x] Phase 2: implement the bounded executor API with one-job behavior,
      deterministic failure injection, cancellation, drain, and cleanup gates.
    - [x] Phase 3: run independent source preprocessing, lexing, and parsing in
      a bounded worker pump with manifest-order deterministic merge.
    - [x] Phase 4: freeze declarations and types, analyze independent procedure
      bodies with private worker state, and merge semantic results canonically.
    - [~] Phase 5: the v3 audit removed quadratic whole-edge IR verification,
      per-function whole-program LLVM scans, and repeated folded grammar-rule
      dispatch, reducing the verified self-host from 800.7 to 400.7 seconds.
      V3 is now retained as the reference/bootstrap bridge for the planned v4
      design; do not extend its whole-project worker transport architecture.
- [~] Define Compiler v4 as a clean architectural generation while preserving
  v3 as its bootstrap compiler and differential oracle.
  - [x] Draft the v4 ownership model, reuse/retire classification, ordered
    milestone roadmap, and task-specific agent instructions under
    `compiler/archived/UBE_Compiler_v4/`.
  - [x] Obtain owner approval for the Task 0 architecture, parser decision
    process, library/compiler-support split, and task ordering.
  - [x] Run the approved bounded design prototypes and freeze phase interfaces
    before creating the v4 manifest or production source scaffold.
  - [x] Freeze and enforce the v4 verified-build policy: every roadmap step and
    claimed working build needs small purpose-built success, rejection,
    boundary, stress, failure, regression, differential, native, and
    determinism programs plus every applicable earlier test.
  - [x] Implement the Task 1 reusable foundation and exact dependency manifest
    before creating the Task 2 production scaffold.
  - [x] Build the Task 2 production session shell on the frozen Task 1 support
    boundary and permanent sequential reference path.
  - [x] Implement the Task 3 minimal genuine vertical slice through every
    compiler phase before adding broader language coverage.

## Handoff protocol

For active work, record:

- the exact objective and authoritative specification;
- current status and completed checklist items;
- decisions and assumptions;
- files changed;
- verification commands and results;
- remaining failures or blockers;
- the exact next action.

Update this file when repository-wide work changes state. Do not duplicate a
detailed module checklist here; link to the module's roadmap or progress file.
