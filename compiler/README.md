# UBE compiler projects

[`UBE_Compiler_v3/`](UBE_Compiler_v3/README.md) is the fresh active compiler,
named by the owner on 2026-10-30. Its qualified foundations include bounded
compiler-owned parallel source processing through actual UBE workers with
budgets 1, 2 and 4. Immutable owners, private results, canonical failures,
atomic publication and cancellation/drain preserve earlier output on failure.
UBECore retains reusable byte, Unicode, file and thread facilities.

[CONCURRENCY-EVIDENCE.md](UBE_Compiler_v3/CONCURRENCY-EVIDENCE.md) records current
qualification, retained earlier gates and measured limits. Instrumented
four-worker execution was slower; collector contention needs focused follow-up,
and no speedup is claimed. Full grammar, semantics, code generation and project/
jobs CLI integration remain incomplete.

The [development plan](../project-docs/Development-Plan.md) preserves the owner's
layer and naming requirements. Its first owner-requested concurrency objective
is complete. All later rows, including proposed bounded project/frontend input,
need their own contract and owner review before implementation. Current handoff
is in [`UBE_Compiler_v3/Progress.md`](UBE_Compiler_v3/Progress.md).

[`archived/`](archived/README.md) preserves the previous v3/v4 source, plans,
tests and v3 release previews. Historical names, source hashes and build output
identify that old line; they must not be mistaken for the fresh v3's status.

[`UBE_Compiler_v1/`](UBE_Compiler_v1/README.md) and
[`UBE_Compiler_v2/`](UBE_Compiler_v2/README.md) remain preserved. Existing
stage-zero/v2 tools may be used temporarily after their required subset passes
independent tests. `bootstrap/build.ps1` still exercises the historical chain
and explicitly selects archived v3 source; it does not build the fresh v3.

Use [`Roadmap.md`](Roadmap.md) and [`Progress.md`](Progress.md) for the current
handoff. Previous compiler-wide documents are preserved in
[`archived/compiler-history/`](archived/compiler-history/README.md).
