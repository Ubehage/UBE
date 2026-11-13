# Source worker ownership gate

Run `powershell -NoProfile -File runtime/tests/callnew/check.ps1 -BootstrapExe <host>`.
With no executable argument the gate builds the VB6 bootstrap project first.
The gate compiles and executes source assertions at O0/O2, then runs the observed
allocation/startup failure matrix. Generated files and process output remain in
the printed temporary directories.

The source fixtures cover:

- Statement and expression `CallNew`, Sub targets, ignored Function results and trusted error operations.
- Creator-return aliases to locals, ByVal scalar parameters, whole records, dynamic/fixed array descriptors, fixed record fields and global indexed fields.
- An indexed alias retaining an old payload after nonpreserving array replacement.
- Ordinary transitive ByRef calls and independently owned grouped temporaries from the same call site in a loop.
- Earlier ByVal record/array snapshots preceding mutation in later argument evaluation.
- Repeated delivery of worker fresh FAIL with Err zero, normal return with stale Err, nested workers and ignored identifiers.
- Exactly 64 held live workers, refusal of the next admission with Err7, then joining every admitted owner.
- A changed expected scalar observation producing the prescribed failure exit.

`fault-check.ps1` wraps target allocation/release and native startup only in the
test image. It first measures the fixture's allocation sites (currently 11),
fails both native attempts at each site, verifies fresh failure and its error,
then reruns normally after every failure. Native thread creation failure receives
the same cleanup/recovery treatment. Every run must drain, dispose and reach zero
live allocations. This covers mixed scalar/record/array aliases, ByVal snapshots,
grouped captures, frame boxes, capture storage and runtime worker records.

Run `powershell -NoProfile -File bootstrap/tests/native-lowering/check.ps1 -CallNewOnly -BootstrapExe <host>`
for the same source behavior and allocation matrix emitted by actual UBE code.
The full native-lowering gate also includes these fixtures and the fault matrix.
The UBE driver supplies its own bound Exercise identity to the allocation harness;
bootstrap and UBE symbol numbers are not assumed interchangeable.
