# UBE native lowering acceptance

## Complete source-to-native qualification

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/native-lowering/check.ps1 -BootstrapExe <bootstrap-executable>
```

The bootstrap builds the actual UBE compiler modules and a test driver. That
native driver reads original source files at runtime, appends their scanner/parser
results to `ProjectSyntax`, and invokes `NativeLowering.TryEmit`. The latter
rebuilds declaration, expression, primitive, aggregate and native planning facts
before writing a complete LLVM module to the caller's private file. The test
closes the file and compiles it with Clang/lld. No host-emitted user procedure
bodies are inserted into this output.

At O0 and O2, the generated program runs 18 existing source-level checks covering
integer arithmetic/conversions/ByRef behavior, finite records and indexed arrays,
independent copies, original-payload aliases during resize, cleanup, counted byte
operations, and conditional/loop failure behavior. It then performs the existing
256-byte file roundtrip check; the runner independently compares the file with
bytes 0 through 255. Each result must be freshly successful, context disposal must
succeed, and the program must return zero. Changing a volatile runtime seed from
1 to 2 must produce exact assertion exit 101 at both optimization levels.

A separate fully generated executable checks forward module-initializer
dependencies and one-time initialization, a recoverable failing initializer
followed by successful initialization, real Main result transport, recursion depth
refusal with Err 28, and successful recursion after unwinding. Its exact native
exit is 42. Both projects must produce identical LLVM bytes when the UBE emitter
itself runs at O0 and O2, and generated source-location comments are required.

Finally, the actual compiler and portable library source bodies are themselves
lowered by UBE, then compiled into native objects at O0 and O2. Undefined symbols
must be only the ten explicit Windows memory/file API imports. This rejects hidden
`__chkstk`, `memcpy`, `memmove`, `memset`, or other unavailable helpers. Object
compilation verifies complete LLVM/code generation for those bodies; it does not
claim the resulting compiler object was used to bootstrap a further executable.

The unchanged generated bridge deliberately contains hundreds of argument
preparations and scalar assignments. It retains the regression that originally
required an unavailable O0 stack probe: pure checked constant arguments now
materialize after module ensuring, while direct local scalar assignment addresses
materialize after the RHS. Indexed/global/aggregate address evaluation keeps its
original ordering. The test does not supply a stack-probe shim or split away that
regression.

Every child has a deadline, native executables must have AMD64 PE headers, and
process outputs, source inputs, complete LLVM, objects, and executables remain in
the printed temporary evidence directory. These are private staging files; public
destination publication remains a separate driver/backend responsibility.

Final main-gate evidence (2026-11-13):

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/native-lowering/check.ps1 -BootstrapExe "C:\Users\Ubehage\AppData\Local\Temp\ube emission scopes 6d5a8c9e-4fb3-4bfd-9f36-88882244ddca\build\UBE-Bootstrap.exe"
```

Passed both generated-program executions, both exact changed-input controls,
both executable entry/initialization/depth checks, deterministic text and exact
source-coordinate assertions, and both actual-compiler object/undefined-symbol
checks. Evidence is retained at
`C:\Users\Ubehage\AppData\Local\Temp\ube native lowering 2f0ff2cf-a03a-4576-83af-0bdf3d39cc10`.

## Failure and ownership qualification

Run the companion gate with the same bootstrap used for the main integration
gate:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/native-lowering/allocation-check.ps1 -BootstrapExe <bootstrap-executable>
```

This compiles the actual complete UBE lowering pipeline, then supplies runtime
source bytes containing scalar arguments, a grouped ByRef call, finite records,
record assignment and equality. Source pools and installation assets are prepared
before fault injection. The caller opens each private staging token before the
observed emission, and closes it explicitly after success or failure.

The successful path measures 64 target allocations for this specific fixture.
Every observed allocation site and its one retry are failed at both O0 and O2.
The rejected operation must return False with latched failure and a fresh
diagnostic, retain only the pre-existing owners, and permit a new stage to emit
successfully. Each recovered file must have exactly the baseline SHA-256 hash.
Both complete baseline LLVM files are independently compiled by Clang, and their
hashes must agree across optimization levels. Only named target allocator/release
definitions are instrumented; frontend and emission functions remain unchanged.

Additional cases corrupt a token span, root parent link, node count, template
catalog and runtime text separately. Seeded stale diagnostic fields must not
survive rejection. Named target write and flush wrappers inject real staging
I/O failures; FileFailure and Err are asserted separately, then a fresh stage
must recover with the baseline bytes. Depth probes use 0, 192, 224, 240, 248,
252, 254, 255 and 256 active frames. They distinguish refusal before the public
boundary is entered from a controlled diagnostic after entry. Caller close and
context disposal must leave zero observed live allocations in every case.

The final snapshot passed 160 cases plus two baseline measurements:
128 allocation cases, ten malformed-input cases, four I/O cases and eighteen
depth cases. Evidence is `ube lowering failures
2adbba20-0fae-4f23-b5c6-4c5cb1e7ae0b` under the system temporary directory, using
the bootstrap in `ube emission scopes
6d5a8c9e-4fb3-4bfd-9f36-88882244ddca/build`. This includes the target header,
constant-conversion, shared initializer lookup and operand/address scheduling changes, with the final
114-entry, 15,641-byte catalog.

These counts cover observed allocations in the stated fixture, not every
possible path through every compiler construct. Failed private stages may
contain accepted prefixes and are never treated as completed output. The gate
does not claim atomic publication or preservation of a public destination;
that remains the driver/backend's responsibility. All child processes have
bounded deadlines, and generated files and process diagnostics are retained.
