# UBE Compiler v3 instructions

This directory is the first public-release compiler generation. The nearest
instructions in this file supplement `../AGENTS.md`.

- V3 must be developed and compiled with the preserved UBE Compiler v2.
- Keep `UBE_Compiler_v3.UBE` buildable by v2 throughout development.
- Keep startup in `Main.bas`; add ordered modules through the project manifest.
- Do not copy standard-library algorithms or platform policy into the compiler.
- Compiler-only intrinsics must remain small, versioned, and documented.
- Host and target are separate concepts. Do not introduce Windows assumptions
  into target-independent compiler phases.
- Garbage collection manages memory only. Compiler source must explicitly
  release files, processes, pipes, locks, temporary artifacts, and other
  external resources on every exit path.
- Implement only semantics recorded in
  `../../lang-doc/v3-language-definition.md`; unresolved items require a
  recorded decision before implementation.
- Preserve v1 and v2 and their complete verification paths.
- Keep generated files outside this directory.

Update `ROADMAP.md` and the repository/compiler progress records whenever a
v3 milestone changes state.
