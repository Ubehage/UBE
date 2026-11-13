# Native intrinsic wrapper acceptance

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/native-intrinsics/check.ps1 -BootstrapExe <bootstrap-executable>
```

The gate compiles actual NativeIntrinsics and its UBE frontend dependencies.
The resulting native emitter reads a declaration module and template catalog
from files at runtime, parses the module and runs declaration binding, primitive
authority and aggregate layout. Only those validated facts select wrappers.
Thirteen arbitrarily named attributed procedures cover all eleven roles and
two additional two-cell record specializations. An ordinary function called
TryRead must produce no primitive wrapper.

Generated wrapper bytes are combined with the source-derived runtime asset and
an independent LLVM harness. Both emission and generated execution run at O0
and O2. Wrapper output must be byte-identical across emitter optimization.
No source procedure is copied from a host-emitted program. Templates were
authored from the literal branches of EmitArrayIntrinsic/EmitFileIntrinsic,
with canonical positional private ABI parameter names. Catalog and runtime
source parity checks precede the gate.

Assertions cover fresh success independently of payload, sticky Error.Set(57),
array length, both overlap directions, whole-span rejection, negative counts,
record-stride resize preservation, independent array copies and retained
nonzero bounds. File create/write/flush/close/open/read executes real OS I/O;
the host independently compares exact output bytes. Native checks verify file
length, progress, cleared token and fresh Failure. All arrays are released and
the context leaf-block list must become empty.

A changed volatile payload seed must fail the unchanged native content oracle
at exact assertion 104. Hidden processes are bounded and all source, generated
IR, native output and diagnostics remain in the printed evidence directory.
Final O0/O2 runs and exact negative control passed with the host executable in
`ube project loading dbd30a59-26f6-43b5-a9d9-e3b4c6143261/build`.
Evidence: `ube native intrinsics 2b107e99-fd30-46d1-852b-1bf54917c9df` under
the system temporary directory; the tested catalog has 49 entries/11,311 bytes.

This qualifies identity-bound wrapper emission, not ordinary procedure lowering,
source call conversion, public exports, atomic publication or the entire compiler.
