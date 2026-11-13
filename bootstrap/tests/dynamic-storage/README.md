# Dynamic storage acceptance gate

The gate compiles actual UBE array operations and portable UBECore declarations,
then executes generated native code with volatile input at O0 and O2. It tests
value copies, publication on successful allocation, record-only Try outcomes,
ordinary FAIL, and the approved original-storage pin lifetime for live aliases.

Allocation fault injection replaces only named allocator wrapper definitions
in a test copy of emitted LLVM. No production failure flags are added. Exact
wrapper and import linkage contracts are recorded with the implemented gate.

Run from the repository root:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File bootstrap/tests/dynamic-storage/check.ps1
```

An existing compiler can be supplied with `-BootstrapExe`. The runner retains
all generated manifests, LLVM, native executables and process output under a
unique temporary directory. On 2026-11-10 all 41 groups passed against the
VB6-built compiler in `ube dynamic storage cd871c2d-4cb0-40d5-aa6e-22bed7b6fd84/build`.
Final evidence is retained in temporary directory
`ube dynamic storage db0f711b-c22d-409d-b303-06d8ccb9e958`.

The checked-in UBE sources exercise:

- Empty arrays, resize preservation by logical-index intersection, neutral new
  elements, different-bound and unknown-shape copies, and independent records.
- Actual UTF-8 bytes and token records grown and traversed through source code.
- Earlier element arguments followed by replacement, replacement inside the
  callee, assignment receiver capture before index/RHS evaluation, and self-copy
  while an element alias remains live. Writes through the old alias leave the
  replacement unchanged.
- Local array cleanup after return and Err.Raise, failed later argument
  preparation, and context disposal of module owners.
- Ordinary ByVal record and array snapshots captured before later arguments,
  callee-private mutation and resize, and retained record-element aliases after
  replacement. Allocation failures in the first or second snapshot, a later
  argument raising an error, and callee depth refusal release caller-owned
  snapshots before recovery; exact allocator-attempt counts and zero live
  blocks after disposal are required at O0 and O2.
- False/Err7 without handler transfer for failed Try operations; ordinary copy
  failure enters the enabled handler and preserves the old destination.

Every native scenario executes the same emitted source IR at O0 and O2 with a
volatile runtime input. A changed-input negative control must reject its altered
captured bounds. Test wrappers count live allocations and require zero after
disposal. They force one allocation failure (successful retry), two failures
(Err7), a synthetic live-block quota, and failed target releases followed by a
successful later disposal. Production element-count limits and the actual
64MiB charged-page quota are checked. Fifteen 4MiB record payloads fit; the
sixteenth must fail because headers and page rounding also consume quota.
Exactly fifteen calls reach the target allocator, and all resulting blocks
must be released. The 4096-live-block quota is not exhausted by this suite.

Fault injection renames only definitions of `ube.target.allocate(i64)->ptr` and
`ube.target.release(ptr)->i1` in a test copy of LLVM; replacements delegate to
those original implementations on successful paths. Compiler algorithms and
source procedure bodies remain unchanged. `ube.context.dispose(ptr)->i1` is
observed directly. The shared NativeMemory helper supplies the Windows import
archive for VirtualAlloc/VirtualFree without adding a CRT dependency.

Binding negatives check exact signatures and nominal record identity. Qualified
and unqualified names for the same record must bind successfully. Invalid
bindings and missing/broken import tools must preserve an existing artifact.

The ordinary ByVal extension passed all 55 groups on 2026-11-13, with evidence
in `ube dynamic storage 781e3c89-d268-4f66-b3d3-84f5f4902261`.
The native-lowering gate supplies `-LoweredIR` for the exact same ordered
five-module corpus to run its 54 execution/binding groups against production
UBE-emitted bodies. That mode omits the bootstrap emission-determinism check;
the native-lowering gate separately compares its O0/O2 emitter output.
