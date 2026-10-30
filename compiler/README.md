# UBE compiler projects

[`UBE_Compiler_v3/`](UBE_Compiler_v3/README.md) is the fresh active compiler,
named by the owner on 2026-10-30. It starts with the shared
[`UBECore`](../std-lib/README.md) foundation, library-defined native datatype
mechanisms and a tested bounded bootstrap route. It currently contains design
and workplans only; there is no production compiler source or executable yet.

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
