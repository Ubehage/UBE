# Compiler v4 Task 0 evidence

This directory contains bounded architecture experiments and checked-in inputs
for Compiler v4 Task 0. Nothing here is production compiler source, belongs to
`UBE_Compiler_v4.UBE`, or changes the preserved bootstrap chain.

Contents:

- `TEST_FORMATS.md` freezes the dependency-minimal test-case input and generated
  verified-build record contracts.
- `cases/` contains manifest-format validation cases and parser fixtures.
- `prototype/` contains the two syntax/parser approaches compared by Task 0.
- `run-task0.ps1` validates inputs, builds and runs the prototypes, and writes
  generated evidence beneath `bootstrap/out/v4-task0/`.

All commands are offline. The runner may use only PowerShell and the C++17
compiler already required by the bootstrap. Generated files never appear next
to the checked-in Task 0 inputs.
