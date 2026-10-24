# UBE compiler generations

Each preserved UBE compiler generation lives in a numbered directory with a
matching project manifest and `Main.bas` startup module. Bootstrap stages and
compiler versions are different: several stages may compile the same source to
prove reproducibility and self-hosting.

- [`UBE_Compiler_v1/`](UBE_Compiler_v1/README.md) is the first small executable
  proof written in UBE.
- [`UBE_Compiler_v2/`](UBE_Compiler_v2/README.md) is the stable, self-hosting
  transitional compiler. It supports ordered multi-module projects and is the
  compiler used to build v3.
- [`UBE_Compiler_v3/`](UBE_Compiler_v3/README.md) is the first public-release
  compiler target. Release Preview 8 is the current verified baseline, built
  on the permanent RP5 self-build fixed point.

The generation-wide roadmap is [Roadmap.md](Roadmap.md), and the active handoff
record is [Progress.md](Progress.md). Intermediate generated artifacts belong
under `../bootstrap/out/`, not in generation source directories. Stable
release-preview executables are preserved with hashes in
[`release-previews/`](release-previews/README.md) and committed with the source
that passed their preview gates.
