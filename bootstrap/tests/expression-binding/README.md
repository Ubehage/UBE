# UBE expression binding acceptance

Run `rtk proxy powershell -NoProfile -File bootstrap/tests/expression-binding/check.ps1 -BootstrapExe <executable>`.
The host builds the actual UBE expression binder, checked constant helpers,
declaration binder, syntax pipeline and UBECore. Test projects are then read from
files at native runtime. No host-generated replacement facts serve as the oracle.

The main gate asserts selected declaration identities, lexical scopes, primitive
and nominal types, rank, writable storage, field/index access, ByVal/direct ByRef/
grouped temporary modes, surrounding conversions, trusted Err roles and label
targets. Decimal constants include exact signed 64-bit extrema, operation-width
overflow, destination contexts, bitwise intermediates, earlier dependencies and
converted Boolean/Byte values. Cross-module required constant dependencies remain
explicitly unsupported, while ordinary reads of later-module constants succeed.

Rejected cases must publish zero count while preserving older expression output.
The gate also exercises malformed pools, semantic depth, independent projects,
actual compiler/library bodies, and successful recovery. It does not claim code
generation from the new bound representation or runtime behavior of test bodies.

O0/O2 use the same emitted library. A changed on-disk grouped argument must fail
the exact unchanged type assertion. Production-only assembly must not reference
the large assertion driver's test-only Windows stack-page helper. Hidden child
processes have deadlines; source snapshots, IR, numbered assertions and logs are
retained in a temporary `ube expression binding <guid>` directory.

Acceptance passed 60 cases and 22,697 assertions at each of O0/O2, both
production-only assembly checks, and the exact changed-input negative control
(assertion 759). Many assertions check path setup and fresh status in addition
to the semantic facts. Recursive same-nominal record comparisons are checked as
Boolean expressions without making a runtime-layout claim.

Evidence: `ube expression binding 47b8d878-83be-4ba2-b731-6c066df3c009`.
The command above used `UBE-Bootstrap.exe` from the temporary directory
`ube project loading 4512f340-a4e4-4aaf-98c4-de2e5192b324/build`.
The large native assertion driver has a 60-second compilation deadline;
native executions are also bounded at 60 seconds. A prior 30-second harness
compilation deadline expired during O2 compilation and was increased only for
this test driver; production limits were unchanged.

Run the companion with `rtk proxy powershell -NoProfile -File bootstrap/tests/expression-binding/allocation-check.ps1 -BootstrapExe <executable>`.
It measures a 303-symbol fixture, then fails each of its 15 observed allocation
sites and retries. All 15 fields of the older output must survive failure;
temporary storage must be released and final disposal must leave zero live
allocations. Selected native call-depth probes from 0 through 256 test success
and controlled exhaustion. Both optimization levels passed 48 fault/depth checks
plus two baseline measurements. Evidence:
`ube expression allocation daa221f0-e029-4454-af07-082d01fe9b90`.
