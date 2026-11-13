# Native context emission acceptance

Run:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/native-context/check.ps1 -BootstrapExe <bootstrap-executable>
```

The gate host-compiles the actual UBE NativeContext module and dependencies.
That native program reads the current template catalog at runtime, emits context
and entry bytes through LLVMWriter into real files, and closes the files.
The generated fragments are combined with the reviewed runtime asset and small
independently authored ensure/procedure definitions, then compiled and executed
at O0 and O2. No context or entry implementation is copied from host-generated
program IR. Both source-derived asset parity commands run before compilation.

The fixture supplies two modules and nine context storage cells: two owned
array descriptors separated by a scalar, plus a non-context array declaration.
Assertions check the exact 2,688-byte context size, all 336 neutralized words
after dirty initialization, manifest-order module calls, both array releases,
scalar preservation, independent contexts and idempotent disposal. Active call
depth or a live file-registry token must refuse disposal without losing owners.
Real runtime allocations supply the array payloads; successful disposal must
collect them. The fake live token is reset by the test, not silently closed.

Entry scenarios require process result 42 on successful source return, status 1
on fresh FAIL, and status 1 when disposal refuses an active context. Emission
at both optimization levels must produce byte-identical fragments. A changed
module-order observation must fail the unchanged native oracle at assertion 3.
All processes have retained handles, bounded deadlines and preserved evidence.

All eight generated-code executions, four source-emitter runs and the exact
negative control passed using the host executable in
`ube project loading dbd30a59-26f6-43b5-a9d9-e3b4c6143261/build`.
Evidence: `ube native context 115be311-df0f-42a6-aefc-1bbe78a4aac1` under the
system temporary directory. The catalog had 23 entries and 3,182 bytes.

This gate qualifies context/entry lowering only. It does not qualify source
procedure emission, initialization dependency analysis, a public ABI, threads,
atomic artifact publication or the complete compiler. Planning facts are the
private validated-input contract, deliberately constructed by the probe.
