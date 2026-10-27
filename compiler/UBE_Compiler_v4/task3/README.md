# Compiler v4 Task 3 evidence

`run-task3.ps1` builds v4 with the preserved v3 compiler, proves deterministic
compiler LLVM, compiles the minimal source through all seven real phase
envelopes, validates and links v4-produced LLVM, compares native behavior with
v3, rejects malformed token/syntax/declaration inputs, mutation-tests every
phase validator, runs a 100,000-byte bounded stress literal, and writes the
verified-build record below `bootstrap/out/v4-task3/`.

Run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File compiler/UBE_Compiler_v4/task3/run-task3.ps1
```
