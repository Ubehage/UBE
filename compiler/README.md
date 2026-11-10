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
Expression checking, constants, layout and code generation remain future work;
this is not self-hosting.

The final compiler will be written in UBE and use LLVM to produce native
64-bit programs. The owner selected VB6 as the bootstrap host if feasible.

See [Roadmap.md](Roadmap.md) for the development sequence and
[Progress.md](Progress.md) for the current handoff and bootstrap evidence.

The active definition work is the [compiler language surface](LANGUAGE-SURFACE.md)
and [VB6 runtime inventory](../std-lib/INVENTORY.md).
