# Native compilation acceptance gate

Run `rtk proxy powershell -NoProfile -File bootstrap/tests/native-compilation/check.ps1`.
An existing compiler can be supplied with `-BootstrapExe`. All generated source,
IR, native outputs and diagnostics remain in the printed temporary directory.

The gate compiles actual UBE source. Its test-only LLVM harness calls emitted
SourceOracle procedures through resolved symbol IDs with volatile runtime input.
The same emitted LLVM is compiled at O0 and O2. It does not replace source
procedures with the old hand-authored failure-flow prototype.

Each oracle call receives a freshly initialized explicit context. The harness
asserts both successful status and result zero; failure bits identify the eight
checks listed in `../failure-flow/source-oracles.json`. Input is loaded with
LLVM `volatile` from harness storage at execution time, so the UBE compiler
cannot replace the reusable procedures with a constant-input answer. This is
test harness plumbing, not an exposed source-level foreign API.
An O2 negative control changes only the harness input to zero; all eight source
checks must reject the changed conditions, producing failure mask 255.

The scalar executable checks cross-module initialized storage, source-order
operand evaluation, two aliases to one ByRef storage cell, grouped ByRef
temporaries, Boolean/Long conversion, runtime checked overflow, failed assignment
preservation, runtime LongLong-to-Long narrowing failure, and stale Err after
successful zero. It also checks local/module
failed initializers, on-access initialization of a later module, suppressed
later arguments/callee after argument failure, explicit continuation modes,
Err.Clear during an active handler, and the controlled recursion guard.
Its nonzero exit identifies
the failed assertion in `fixtures/Program.bas`. A separate executable verifies
that a user module named Err with a Raise procedure retains ordinary behavior.
Both run at optimization settings 0 and 2. The checked-in Demo must return 42.
The Sub Main entry form must return successful process status zero.

All native outputs must have an AMD64 PE header. Repeated source emission must
be byte-identical. Existing valid executables/IR must survive frontend errors,
missing backends, backend nonzero exit and false success without output.
An intentionally nonterminating fake backend must hit the driver's deadline
and preserve the prior executable; that invocation gets a 45-second harness
deadline to allow the driver's 30-second limit and bounded termination wait.
Invalid destinations and input/output collisions must fail without publication.
The preserved executable is executed again after these failures.

Every child has a bounded deadline and retained process handle. The gate checks
the approved initial scalar behavior only; this does not qualify arbitrary
UBECore facilities, root-entry failure delivery, threads, foreign callbacks,
module lifecycle hooks or self-hosting.
Root explicit Raise, potentially failing If headers and initializer dependency
cycles must be rejected explicitly until their deferred contracts are admitted.
