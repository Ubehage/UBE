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
  compiler target. It is currently a v2-buildable design scaffold.

The generation-wide roadmap is [Roadmap.md](Roadmap.md), and the active handoff
record is [Progress.md](Progress.md). Generated artifacts belong under
`../bootstrap/out/`, not in generation source directories.
