# UBE compiler projects

The VB6 bootstrap in [../bootstrap](../bootstrap/README.md) now compiles the
admitted scalar language into native Windows x64 programs. This directory
holds the final UBE-written compiler's contracts, development plan and its
scanner, token helpers and [module parser](src/SourceParser.bas). They retain
UTF-8 source positions and independent syntax trees, including for their own
source files. The [parser gate](../bootstrap/tests/module-parsing/README.md)
records the bounded admission and native checks. The UBE-written
[declaration binder](src/DeclarationBinder.bas) now resolves scoped declarations,
declared types and signatures over ordered [project storage](src/ProjectSyntax.bas).
Its [acceptance gate](../bootstrap/tests/declaration-binding/README.md) covers
actual compiler modules, invalid references and independent results.
The [expression binder](src/ExpressionBinder.bas) now checks references, calls,
assignments and exact [typed constants](src/ConstantValues.bas), including actual
compiler/library bodies. Its [native gate](../bootstrap/tests/expression-binding/README.md)
records both optimization levels and controlled failure cases.
[PrimitiveRoles](src/PrimitiveRoles.bas) validates the exact declarations that
may invoke core operations; [AggregateLayout](src/AggregateLayout.bas) computes
bounded record and array storage facts. Their separate
[contract](../bootstrap/SEMANTIC-STORAGE.md) and
[native gate](../bootstrap/tests/semantic-storage/README.md) preserve the
authority/layout boundary. Native lowering from these facts remains ahead;
this is not self-hosting.

The final compiler will be written in UBE and use LLVM to produce native
64-bit programs. The owner selected VB6 as the bootstrap host if feasible.

See [Roadmap.md](Roadmap.md) for the development sequence and
[Progress.md](Progress.md) for the current handoff and bootstrap evidence.

The active definition work is the [compiler language surface](LANGUAGE-SURFACE.md)
and [VB6 runtime inventory](../std-lib/INVENTORY.md).
