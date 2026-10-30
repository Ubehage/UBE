# Compiler v3 performance baselines

Phase 0 baselines are produced by
`bootstrap/tools/measure-v3-performance.ps1`. The harness uses the compiler's
opt-in `--profile` mode, repeats each build, requires identical LLVM hashes,
and records raw runs plus field-wise medians.

The fixed workloads are Compiler v3 compiling itself, the checked-in
`UBECore` project, generated 32/64/128-source projects, and generated
128/256/512-procedure projects. The size series exposes superlinear behavior
before parallel work can hide it. Generated fixtures and transient profiles
stay beneath `bootstrap/out`; the reviewed host baseline is preserved here.

Run from the repository root after building Compiler v3:

```powershell
./bootstrap/tools/measure-v3-performance.ps1 `
    -CompilerPath ./bootstrap/out/v3-rp5-self-stage2.exe `
    -OutputPath ./bootstrap/out/v3-phase0-baseline.json
```

Timings are observations, not portable promises. Compare a regression only on
equivalent hardware, power settings, toolchain, inputs, and job count.
