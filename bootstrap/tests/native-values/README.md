# Checked native scalar helpers

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/native-values/check.ps1 -BootstrapExe "C:\path\to\UBE-Bootstrap.exe"
```

Omit `-BootstrapExe` to build the VB6 bootstrap. The runner builds the actual UBE `NativeValues` and `NativeEmission` helpers, executes them at O0 and O2 to generate 38 instruction fragments, then compiles those fragments into independent assertion executables at the corresponding optimization level. Child processes have deadlines and retained stdout/stderr; executables must have AMD64 PE headers.

The 119 vectors cover all 25 conversions between Boolean, Byte, Integer, Long, and LongLong at source-domain extrema and zero; signed 16/32/64-bit addition and subtraction; signed-minimum negation overflow; logical and exact-width complements; and materialization of both signed 64-bit extrema. Expected values are independent decimal strings, with exact decimal arithmetic used only for the test oracle. Operands for successful arithmetic are loaded through a volatile runtime input.

Every vector checks fresh success/failure, the result slot, and sticky `Err`. Successful operations preserve a stale error number. Failed arithmetic/conversion sets error 6 and leaves the result slot unchanged. The UBE probe also asserts that guards register the current source node once with its owning procedure and continuation, while infallible conversions/complements register no failure edge.

Five compiler-side refusal paths check zero returned SSA identity and latched unusable output: an already-failed writer, invalid operand identity, exhausted emission work budget, invalid current source node, and a failing access to missing guard bookkeeping arrays. The last case retains runtime error 9 and the current source node. All request-owned arrays must dispose successfully after the emission driver finishes.

The changed-input control replaces the runtime value 12 with 13 and must fail at exact vector 76 at both optimization levels. Generated fragments, drivers, native executables, and subprocess evidence remain in the printed temporary directory.

This gate proves these scalar LLVM helpers and their failure-edge registration. The fragment's enclosing function, failure-dispatch stub, input parameters, and result slot are authored by the test harness; it does not claim complete source-procedure lowering or handler dispatch qualification. Production scalar storage and canonical input types are frontend preconditions. Arithmetic Byte operands must already have their bound Integer promotion.
