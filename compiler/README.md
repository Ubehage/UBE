# UBE compiler projects

[`UBE_Compiler_v3/`](UBE_Compiler_v3/README.md) is the fresh active compiler,
named by the owner on 2026-10-30. It includes project/reference intake,
source/scanner/parser processing and bounded scalar/native MODULE semantic
checking through the existing check command. The production implementation is
qualified for that bounded scope; exact final reports are in semantic evidence.

Compiler-owned orchestration keeps immutable inputs, private results, canonical
diagnostics and complete publication under one worker budget. UBECore supplies
reusable Unicode, numeric, storage, file and thread facilities. Earlier qualified
frontend performance results remain recorded separately; no semantic speedup
claim follows from them.

The exact checking scope, retained gates and completion status are in
[SEMANTIC-EVIDENCE.md](UBE_Compiler_v3/SEMANTIC-EVIDENCE.md) and
[Progress.md](UBE_Compiler_v3/Progress.md). Successful supported checks create no
executable; the real compiler/Core source, full grammar and native code generation
remain outside this bounded subset.

The [development plan](../project-docs/Development-Plan.md) keeps the next existing
row, First checked native executable, dependent on a qualified semantic result
and reviewed bounded lowering/backend/tool contracts. It is not started here.
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
