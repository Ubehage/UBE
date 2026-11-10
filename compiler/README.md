# UBE compiler projects

The VB6 bootstrap in [../bootstrap](../bootstrap/README.md) now compiles the
admitted scalar language into native Windows x64 programs. This directory
holds the final UBE-written compiler's contracts, development plan and first
source component: [SourceScanner.bas](src/SourceScanner.bas). It reads retained
UTF-8 bytes into tokens with physical source positions. Its bounded native
acceptance is in [the scanning gate](../bootstrap/tests/source-scanning/README.md).
A UBE-written parser and self-hosting compiler remain future work.

The final compiler will be written in UBE and use LLVM to produce native
64-bit programs. The owner selected VB6 as the bootstrap host if feasible.

See [Roadmap.md](Roadmap.md) for the development sequence and
[Progress.md](Progress.md) for the current handoff and bootstrap evidence.

The active definition work is the [compiler language surface](LANGUAGE-SURFACE.md)
and [VB6 runtime inventory](../std-lib/INVENTORY.md).
