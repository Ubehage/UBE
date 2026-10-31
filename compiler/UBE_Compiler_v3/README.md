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

This directory contains source input, scanner, source-header, bounded grammar
and compiler-owned source-set orchestration. `TryParseSources` runs actual UBE
source workers with budgets 1, 2 and 4, shared immutable owners, private results
and deterministic complete publication. The current bootstrap passes 592 grouped
assertions; [concurrency evidence](CONCURRENCY-EVIDENCE.md) records its 5652 native
assertions, retained parser/CLI gates and exact current identities and limits.
UBECore supplies reusable storage, Unicode, file and thread facilities without
compiler source policy.

Instrumented four-worker execution was slower than one-worker execution;
collector contention is recorded follow-up work, and no speedup is claimed.
Full grammar, semantic validation, code generation and project/jobs CLI
integration remain unfinished.

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
actual direct UBECore source references. A successful intake still returns the
explicit unavailable-check diagnostic; it never claims a source program passed.

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
[exact evidence and limits](PARSER-NATIVE-EVIDENCE.md). Successful syntax still
reports semantic checking unavailable; complete-language parsing and code
generation remain unimplemented. The subsequent bounded concurrency objective is now complete. The
[development plan](../../project-docs/Development-Plan.md) proposes bounded
project input and parallel frontend integration next. That row and every later
row require their own contract and owner review; their gates are not current
capabilities.

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
