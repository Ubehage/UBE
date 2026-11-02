# UBE Compiler v3

This is the fresh compiler line designated by the owner on 2026-10-30. The
previous v3 and v4 implementations are preserved under
[`../archived/`](../archived/README.md). Their code, phase interfaces, version
claims and release-preview identities are not inherited by this project.

The compiler and [`UBECore`](../../std-lib/README.md) are developed together
from tested foundations, with reusable functionality implemented in UBECore.
The compiler owns language enforcement and a small machine/storage primitive
boundary. Higher-level datatype behavior belongs in library source wherever
practical. The datatype-definition mechanism must be demonstrated early.

## Current state

Production code is kept separately from plans and definitions:

| Location | Contents |
| --- | --- |
| `src/` | Production UBE modules and classes, including `Main.bas` |
| `UBE_Compiler_v3.UBE` | Project manifest with ordered `src/` source entries |
| `tests/` | Fixtures, independent expectations and native test adapters |
| `tools/` | Build, checking and measurement scripts |
| Root Markdown files | Reader and contributor guidance, design, plans, contracts and evidence |

The source relocation preserves every production file's bytes and source order.
Earlier reports retain their original paths and hashes as historical evidence.

This directory contains source input, scanner, source-header, bounded grammar
and compiler-owned source-set orchestration. `TryParseSources` runs actual UBE
source workers with budgets 1, 2 and 4, shared immutable owners, private results
and deterministic complete publication. The earlier source-qualified frontend checkpoint
passes 785 grouped assertions, including bounded project intake, explicit
UBECore references, the project/jobs CLI sources, expanded consumer proofs and
the approved caller-retention/materialization regressions.
Retained parser/CLI/lifetime/concurrency gates also pass on that cohort.
Both complete timing sessions retain 252 trials and pass all serial and
small-input guards. Main-corpus gains are 1.21-1.29x at two workers and
1.30-1.42x at four. These initial results are accepted under the owner's
2026-11-01 revision; the original 1.5x/2x targets remain optimization goals.
UBECore supplies reusable storage, Unicode, file and thread facilities without
compiler source policy.

The approved address-owned root synchronization and coordinator wait correction
resolve the earlier measured contention sufficiently for this initial acceptance.
Exact commands, identities, retained failures and limitations are in
[frontend evidence](FRONTEND-PERFORMANCE-EVIDENCE.md).
The production check path now performs the approved bounded scalar/native MODULE
semantic check after frontend admission, qualified on accepted source-built
cohort 88d through its maintained gates. Successful checks return exit 0 with
empty stdout/stderr and
create no executable or intermediate output. Invalid/deferred inputs retain
their specified diagnostics, and earlier frontend failures pass through unchanged.

The full production compiler and actual UBECore source exceed this subset and
remain deferred. Full grammar and native code generation remain unfinished.
Current scope and exact proof status are in [semantic evidence](SEMANTIC-EVIDENCE.md);
[project evidence](PROJECT-INPUT-EVIDENCE.md) retains the earlier intake checkpoint.

## Earlier foundation and parser checkpoints

The first [foundation contract](../../std-lib/FOUNDATION.md) and
[bounded bootstrap investigation](../../std-lib/FOUNDATION-EVIDENCE.md) are
recorded. The subsequent [source-built v2 repair](../UBE_Compiler_v2/FOUNDATION-VERIFICATION.md)
passes its bounded byte/scalar acceptance gate and provides the temporary tool
for further work. The adopted opaque native scalar mechanism now passes its
focused proof. The first UBECore byte/text foundation now has tested managed
storage, incremental UTF-8 decoding and ByteBuffer growth/snapshots; the complete
source-only foundation snapshot passed 296 assertions. See
[that checkpoint's evidence](../../std-lib/BYTE-BUFFER-EVIDENCE.md).
The consumer extends this foundation using recoverable byte-file input and
actual direct UBECore source references. At that checkpoint, successful intake returned the
explicit unavailable-check diagnostic; it did not claim a source program passed.

The scanner/source-header implementation passes its 102 original hand-authored
vectors, 12 focused regressions and 174 word roles through both source-built
stages, including failure, ownership and measured-copy checks. Unicode helpers
use pinned official data and ordinary UBE implementations. See
[the contract](SCANNER-CONTRACT.md) and [native evidence](SCANNER-EVIDENCE.md).
Legacy recognition preserves metadata without claiming full designer grammar;
raw dates/directives do not establish their semantics.

At the earlier parser checkpoint, the [parser acceptance contract](PARSER-CONTRACT.md) is now defined with
116 hand-authored cases. Its consistency gate passes; [the definition evidence](PARSER-EVIDENCE.md)
keeps that result separate from native execution. The subsequent
[native probes](PARSER-PROBE-EVIDENCE.md) pass 3828 assertions through both stages
and select linked-child storage with explicit stacks. The necessary recoverable
memory-failure correction also passed that fresh complete 501-check gate.
The subsequent bounded production parser is implemented with that representation.
Its unrestricted native gate passes 4049 grouped checks through both stages:
188 independent syntax/rejection/deferred cases, complete old-result retention,
all 10412 real-root capacities, allocator failures, private workers, cleanup and
102 cost rows satisfy the predefined bounds. Strict CLI tests pass 82 process
cases and 54 diagnostic controls; the local `bootstrap/out/v3/ube.exe` passes the
same 41 process oracles. Both native-test and production raw LLVM pairs are
byte-identical. See [implementation details](PARSER-IMPLEMENTATION.md) and
[exact evidence and limits](PARSER-NATIVE-EVIDENCE.md). At that checkpoint, successful syntax
reported semantic checking unavailable; complete-language parsing and code
generation remain unimplemented. The subsequent bounded concurrency, project input and initial parallel frontend
deliverables are qualified. The owner-approved [semantic contract](SEMANTIC-CONTRACT.md)
is implemented and qualified in production for its bounded scope.
Definition-only records remain historical prerequisites; they are distinct from
the later native/process checker evidence. The [development plan](../../project-docs/Development-Plan.md)
keeps the next native-executable contract review separate from this checker.

An existing stage-zero/v2 route may be used temporarily after its required
language subset passes independent small tests. This permission does not
approve existing implementations or transfer their assumptions into the new
architecture. A VB6 bootstrap port remains a deferred owner idea.

## Read next

- [`DESIGN.md`](DESIGN.md): approved direction and unresolved mechanisms.
- [`Roadmap.md`](Roadmap.md): ordered prerequisite checklist.
- [`Progress.md`](Progress.md): current handoff and evidence limits.
- [`../../std-lib/FOUNDATION.md`](../../std-lib/FOUNDATION.md): shared primitive
  ledger, native-type proposal and independent acceptance obligations.
- [`AGENTS.md`](AGENTS.md): implementation boundaries.
- [`../../std-lib/INVENTORY.md`](../../std-lib/INVENTORY.md): target library scope.
