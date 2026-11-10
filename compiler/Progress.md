# Compiler development handoff

## Current handoff: bounded source buffers and finite records

The latest dependency increment adds finite scalar-field Type records and fixed
rank-one arrays, including arrays of records, checked field/index access,
ByRef borrowing and independent record/same-known-bounds array copies.
`../bootstrap/AGGREGATES.md` defines the admission boundary. The source fixture
retains and traverses bytes and token/tree records, with failure and copy
assertions at O0/O2. Dynamic resizing, managed text, array fields and aggregate
value-call/result paths remain explicit later dependencies. This work extends
the existing pipeline and does not implement new loop-header semantics.

The completed incremental bootstrap dependency is Byte, Integer and LongLong
storage, parameters and results, including checked conversions and authoritative
integer suffixes. `../bootstrap/DEPENDENCIES.md` records the evidence from the
existing pipeline and the remaining array/text/library prerequisites. The
existing parser, semantic pass and emitter were extended, retaining all earlier
error-flow and multi-module gates. The new gate is
`../bootstrap/tests/integer-types/check.ps1`.

Next measure growing source/token buffers and counted input/output, including
the dynamic storage and text capabilities needed by actual compiler source,
then admit those dependencies incrementally under the existing development plan. The complete
UBE-written compiler and its self-hosting subset are not yet established.

Owner clarification, 2026-11-10: the final UBE-written compiler must be
multithreaded and all compiler code thread-safe. The bootstrap may remain
sequential. Apply explicit ownership and synchronization from the first UBE
compiler implementation; do not postpone this architecture until IDE work.
The development plan and ACCEPTANCE.md now state the requirement and its
pending concurrency gate. Current bootstrap evidence does not verify concurrency.

The owner authorized the restart sequence in
`../project-docs/Development-Plan.md`. The planned scalar source boundary is
`../lang-doc/bootstrap-profile.md`; exact gates are in [ACCEPTANCE.md](ACCEPTANCE.md).
The error contract is reconciled in the normative documents and affected public
articles. `rtk proxy powershell -NoProfile -File docs/assets/tools/validate-docs.ps1`
passed for 274 HTML files; browser verification and source-example execution
remain unverified. Remaining boundary choices are tracked
in `../project-docs/Error-Handling.md` rather than inferred during coding.

The repository-owned VB6 bootstrap now loads `.UBE` projects and retains
multiple source modules in manifest order in a caller-owned ProjectContext.
The owner explicitly requires this from the outset. No separate single-file
compiler precedes it.

The bounded lexer/parser retains syntax trees, and the semantic pass now
resolves symbols, checks scalar types and constants, validates Main and binds
the trusted error-support declarations described in `../bootstrap/SEMANTICS.md`.
The emitter now lowers those bound trees into LLVM and the bounded backend
builds Windows x64 executables. Actual SourceOracle.bas execution qualifies
the approved scalar FAIL protocol. Conversions, argument modes, exact constants
and trusted declaration roles feed lowering directly; behavior is not inferred
from fixture names or ordinary user procedure spellings.

Next follow the existing development-plan item **Extend bootstrap dependencies**:
measure the UBE-written compiler's required source/storage/library dependencies,
then extend and test the admitted profile incrementally. Byte/Integer/LongLong
storage and bounded arrays/records are now implemented; text, dynamic storage,
broader loops and explicit library I/O
remain candidates in the profile, not an all-at-once implementation. Self-hosting and
full-language support remain incomplete.

Adaptive context inference, assembly lowering and compound-header failure
continuations are outside this first implementation. The runtime inventory in
`../std-lib/INVENTORY.md` remains a planning input, not a support claim.

## Bounded source-buffer and record gate

On 2026-11-10, this command built the final bootstrap with VB6 6.00.9782 outside
the sandbox and passed **38 aggregate-storage assertion groups**:

`rtk proxy powershell -NoProfile -File bootstrap/tests/aggregate-storage/check.ps1`

Build, generated IR, native executables and process evidence:
`C:\Users\Ubehage\AppData\Local\Temp\ube aggregate storage 464b9387-76b0-4159-b3ff-459aa6113b20`.

Actual UBE source retains ASCII/UTF-8 bytes, token spans and linked tree records,
traverses them, copies independent values and exercises nested fields, record
equality, aliases and parameter bounds. Four checks run at O0/O2 with volatile
input; changing the tree-start input returns the exact negative-control mask 1.
Invalid reads, destination indexes and ByRef arguments record Err 9 and preserve
destinations while skipping remaining operands/arguments. Enabled and active
handlers are exercised. Singleton arrays at both LongLong extremes remain
usable through ByRef with runtime indexes.

Inspection asserts nominal identities, field ownership/offsets and declaration
scopes, array shapes and resolved accesses. Bracketed intrinsic-name types remain
nominal, and escaped type names preserve AST/SYMBOL/BOUND record framing. Negative
cases reject unsupported aggregate paths and qualify array-element, flattened
record, recursive-layout-visit, total module storage and copy-snapshot frame
limits. Failed emission preserves the previous artifact.

The following commands passed on the same unchanged executable:

```powershell
$verifiedBootstrap = 'C:\Users\Ubehage\AppData\Local\Temp\ube aggregate storage 464b9387-76b0-4159-b3ff-459aa6113b20\build\UBE-Bootstrap.exe'
rtk proxy powershell -NoProfile -File bootstrap/tests/integer-types/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/native-compilation/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/source-semantics/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/source-parsing/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/project-loading/check.ps1 -BootstrapExe $verifiedBootstrap
```

Evidence directories under `C:\Users\Ubehage\AppData\Local\Temp`:

- `ube integer types 6f4df1d6-f82f-49c2-aef2-8e30726ffcae`: **46 groups**.
- `ube native compilation 74cd89fe-fbdc-47e7-9a5c-dad218cfdbb8`: **23 groups**.
- `ube source semantics 6dc1d0bc-ef54-4a82-9dff-a1fd1e26dc9c`: **76 cases**.
- `ube source parsing 5571ff58-197b-4ed8-8e6d-26e1ddbad1e9`: **37 cases**.
- `ube project loading d7bb71ef-b6d2-43fc-8044-6440a0fe7b18`: **54 cases**.

Native tools remain Clang 23.1.3 and LLD. The extension uses fixed owned storage,
not runtime heap allocation: dynamic resizing, managed text, aggregate
ByVal/results, public layouts, self-hosting and concurrency remain unqualified.
The next dependency assessment should cover growing source/token buffers and
counted input/output before choosing the next implementation boundary.

## Integer storage and conversion gate

On 2026-11-10, the updated bootstrap built with VB6 6.00.9782 and passed all
76 existing semantic cases using:

`rtk proxy powershell -NoProfile -File bootstrap/tests/source-semantics/check.ps1`

Build and semantic evidence:
`C:\Users\Ubehage\AppData\Local\Temp\ube source semantics 76b57bdc-1612-43b6-9cc7-c918a8fcff02`.

The following commands all passed on that same unchanged executable:

```powershell
$verifiedBootstrap = 'C:\Users\Ubehage\AppData\Local\Temp\ube source semantics 76b57bdc-1612-43b6-9cc7-c918a8fcff02\build\UBE-Bootstrap.exe'
rtk proxy powershell -NoProfile -File bootstrap/tests/integer-types/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/native-compilation/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/source-parsing/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/project-loading/check.ps1 -BootstrapExe $verifiedBootstrap
```

Final evidence under `C:\Users\Ubehage\AppData\Local\Temp`:

- `ube integer types caa47339-8e01-4b4e-9ec8-30e0f0d02268`: **46 groups**.
- `ube native compilation 0fbc7a2e-a36b-496c-aa46-0047aa5ff8d3`: **23 groups**.
- `ube source parsing f9c4eef5-2c1e-46bb-80cf-2a232ad95d32`: **37 cases**.
- `ube project loading 9b50c4f8-661c-4017-9f12-d4293ce134f2`: **54 cases**.

The integer gate checks exact bounds, destination-context constant typing,
authoritative %, & and ^ literal suffixes, declaration/use suffix agreement,
Byte-to-Integer promotion, and typed ByRef alias/temporary bindings. Actual
source-generated native code runs at O0 and O2 using volatile harness input.
The 25-cell scalar matrix covers assignment, ByVal and result conversions;
113 additional runtime boundary cases cover source minima/maxima/zero and
destination bounds plus/minus one where representable by the source type.
Failures must preserve the destination sentinel and record Err 6; success
must report fresh success. The four-check input-zero negative control returns
exact mask 15. Known invalid constants and all 20 incompatible direct ByRef
pairs are rejected, and a failed emission preserves prior LLVM output.

Native tools remain Clang 23.1.3 and LLD. No new tool dependency, target ABI,
operator family or compiler generation was introduced. Public memory layouts,
arrays/records, source text, foreign interfaces and concurrent compiler execution
remain unqualified. The final compiler's concurrency requirement and pending
gate are recorded separately from these sequential bootstrap results.

## Scalar source-to-native gate

On 2026-11-10, the following command built the final VB6 bootstrap outside the
sandbox and passed all **23 native assertion groups**:

`rtk proxy powershell -NoProfile -File bootstrap/tests/native-compilation/check.ps1`

Tools: VB6 6.00.9782 and Clang 23.1.3 (LLVM revision
`0d261d1ca552c95a8f007e061c787ac7132fbcbc`), with the installed LLD linker.
Evidence and the tested executable are retained under:
`C:\Users\Ubehage\AppData\Local\Temp\ube native compilation 7ad953f1-5dfb-4994-b557-cbcc35084c7d`.

The gate compiles actual SourceOracle.bas and invokes all eight public checks
independently with volatile input 1, requiring fresh success and result zero
at O0 and O2. The same generated source code with harness input zero must
return exactly mask 255. Multi-module executable fixtures assert forward and
once-only initialization, neutral failed initializers, expression/argument
order, direct ByRef aliases, discarded grouped temporaries, declaration
reexecution, Boolean/Long conversions, runtime arithmetic and narrowing
failures, sticky Err, consumed callee failures, explicit handler modes,
Err.Clear while a handler is active, and guarded recursion (Err 28).
An ordinary user module Err remains ordinary. Demo returns 42; Sub Main returns 0.

The runner checks AMD64 PE output and repeatable LLVM, then proves prior-output
hash preservation for source failure, missing Clang, nonzero backend exit,
false-success backend with missing output, a timed-out backend, input/output
collision and unsupported/over-limit emission. A preserved executable still
returns 42 afterward. The timeout backend is contained and terminated by the
driver. The initial harness used dynamic alloca and exposed a missing __chkstk
link dependency; test-owned static context storage removed that dependency.
No production workaround or external runtime was added.

The same final executable passed all earlier gates:

```powershell
$verifiedBootstrap = 'C:\Users\Ubehage\AppData\Local\Temp\ube native compilation 7ad953f1-5dfb-4994-b557-cbcc35084c7d\build\UBE-Bootstrap.exe'
rtk proxy powershell -NoProfile -File bootstrap/tests/source-semantics/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/source-parsing/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/project-loading/check.ps1 -BootstrapExe $verifiedBootstrap
```

Final regression evidence under `C:\Users\Ubehage\AppData\Local\Temp`:

- `ube source semantics caeef0c8-282b-4399-ba0b-a2a1a321d70c`: 76 cases.
- `ube source parsing 3b0ff74d-767a-41cf-bd18-f130087b9a43`: 37 cases.
- `ube project loading 0962dc36-0c0d-42e1-b218-d600eb31a143`: 54 cases.

`../bootstrap/LOWERING.md` records the internal result/context ABI, numerical
limits and deferred cases. Frame/parameter limits are exercised; exact IR-size,
scan-budget and log-size thresholds are defensive and not separately qualified.
Root Raise, potentially failing If headers, lifecycle hooks and potential
initializer cycles are explicitly rejected. Native libraries/foreign ABI,
threads, full Err metadata, arbitrary OS stack exhaustion, managed resources,
debug-info emission and self-hosting remain unqualified. Manifest debug settings
do not yet produce Line/Full native debug information.

## Semantic gate (historical isolated step)

On 2026-11-10 this command built with VB6 6.00.9782 outside the sandbox and
passed all 76 semantic cases:

`rtk proxy powershell -NoProfile -File bootstrap/tests/source-semantics/check.ps1`

Build and initial evidence directory:
`C:\Users\Ubehage\AppData\Local\Temp\ube source semantics 2642cea7-48b2-4d25-9412-86e46fce5061`.

The final runner added exact label-target and 64-bit And intermediate assertions.
It passed all 76 cases against that unchanged executable. The parser and loader
regressions also passed against the same executable, using these commands:

```powershell
$verifiedBootstrap = 'C:\Users\Ubehage\AppData\Local\Temp\ube source semantics 2642cea7-48b2-4d25-9412-86e46fce5061\build\UBE-Bootstrap.exe'
rtk proxy powershell -NoProfile -File bootstrap/tests/source-semantics/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/source-parsing/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/project-loading/check.ps1 -BootstrapExe $verifiedBootstrap
```

Final artifacts under `C:\Users\Ubehage\AppData\Local\Temp`:

- Semantic: `ube source semantics b8a3d49e-8c97-424b-8183-c6067f684306` (76 cases).
- Parser: `ube source parsing 373323ab-d6e2-48fa-934f-ec567849554a` (37 cases).
- Loader: `ube project loading 595feb50-3001-4be7-815b-fd3f1c6a79ef` (54 cases).

Assertions cover declaration/entry identities, module/package visibility and
ambiguity, shadowing, duplicate/undeclared names, exact signatures, conversions,
ByRef aliases versus temporaries, constant boundaries, labels/handlers and
trusted Err roles. The actual source oracle binds to trusted error operations;
an ordinary user module Err does not. Negative diagnostics assert locations,
failed analyses publish no partial bound result, and semantic symbol/depth
limits fail cleanly. The lookup-work guard is not separately threshold-tested.

No source procedure is executed by these commands. Deferred cases remain
explicit in `../bootstrap/SEMANTICS.md`: hex/octal interpretation, mixed
Boolean/integer operator domains, cross-module required-constant dependencies,
and colliding package/module three-part qualifiers. Full Err signatures remain
future work; runtime behavior is covered only to the extent of the newer native gate above.
Actual concurrent compilation and editor
multi-error recovery are not qualified.

## Lexer/parser gate

On 2026-11-10, this command built with VB6 6.00.9782 outside the sandbox and
passed all 37 source-parsing cases:

`rtk proxy powershell -NoProfile -File bootstrap/tests/source-parsing/check.ps1`

Evidence directory:
`C:\Users\Ubehage\AppData\Local\Temp\ube source parsing b3e2053c-36d1-42da-8be2-e7571af6f13e`.

The same executable passed all 54 existing loading cases with:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/project-loading/check.ps1 -BootstrapExe 'C:\Users\Ubehage\AppData\Local\Temp\ube source parsing b3e2053c-36d1-42da-8be2-e7571af6f13e\build\UBE-Bootstrap.exe'
```

Loading evidence directory:
`C:\Users\Ubehage\AppData\Local\Temp\ube project loading 695107e3-81eb-42f6-a388-cb08c0537975`.

The syntax gate asserts tree ownership/reachability, operator precedence and
associativity, positional arguments, parameter modes, If branch structure,
exact source spans, comments/continuations, bracket escaping, multi-module
order and qualified-call syntax. The actual failure-flow source oracle parses
with all eight public checks represented. It is not executed.

Negative cases assert diagnostic categories/locations, no partial success on a
second-module error, and bounded token length/count, aggregate tokens, nodes
and expression nesting. An independent valid invocation succeeds after invalid
ones; this does not qualify reuse within one process or concurrent compilation.

`--parse` validates admitted syntax; `--dump-ast` additionally emits inspection
records. Limits, source ownership and UTF-16 span conventions are documented
in `../bootstrap/DESIGN.md`. One diagnostic ends a failed request; editor
multi-error recovery is unimplemented. This historical gate qualifies syntax;
the semantic gate above now covers its admitted name/type/entry checks.
Native execution is covered separately by the newer gate above.

## Project-loading gate

On 2026-11-10, this command passed outside the restricted sandbox with
VB6 6.00.9782:

`rtk proxy powershell -NoProfile -File bootstrap/tests/project-loading/check.ps1`

The build succeeded and all 54 cases passed: exact ordered output for multiple
modules and the checked-in sample; repeated loading; Unicode/BOM input and
Unicode paths; required fields; duplicate keys, paths and identities; malformed
text/headers; path and junction escapes; input bounds; unsupported features;
and exact CLI exit codes. Selected syntax/header errors assert filename/line.
Artifacts and logs were retained at
`C:\Users\Ubehage\AppData\Local\Temp\ube project loading f88b5979-2db4-4aa6-b985-d626e3b334d1`.

The sandbox blocks VB6 registry access; the outside-sandbox run made no registry
changes. An initial compile error was resolved by preserving CRLF in VB6 source
and project files, now specified by `.gitattributes`.

`--check` validates manifest metadata and source envelopes only. Procedure syntax
is handled by the separate parse commands; the analysis commands check Main
and cross-module call binding. Native commands now extend the same pipeline.
It emits no target artifact. Full Unicode identifiers, references/resources and
non-MODULE source kinds are explicitly outside the current admission boundary.
See `../bootstrap/README.md` for input bounds. The gate does not qualify reuse
of a context within one process or actual concurrent compilation.

## Native failure-flow gate

On 2026-11-10 this command passed with Clang 23.1.3:

`rtk proxy powershell -NoProfile -File bootstrap/tests/failure-flow/check.ps1`

O0 and O2 each produced a PE x64 image and exited with exactly 0 after eight
behavior assertions: successful zero with stale Err, raise exit, default
assignment preservation/skipped operand, caller handler, active-handler
failure, explicit cleanup ordering, preserved ByRef effect and repeated equal
error numbers. O2 negative controls were rejected with exact masks 158 and 4.

These are hand-authored native test calls, not UBE compiler output. Full Err
metadata, TLS, actual OS resource release, source parsing/lowering and public
ABI are not qualified. SourceOracle.bas and source-oracles.json define the
matching source gate, now executed separately by the native compiler runner above.

## Completed bootstrap feasibility experiment

Owner direction on 2026-11-10: restart the implementation and use VB6 for the
bootstrap if possible. The final compiler remains written in UBE, producing
native 64-bit programs through LLVM.

The compiler directory currently contains documentation only. The previous
bootstrap and standard-library implementation files are removed in the working
tree. Do not restore them wholesale or inherit their verification claims.

Acceptance gate used:

1. Locate an owner-provided VB6 installation and record its version.
2. Compile and run a minimal repository-owned VB6 project without interactive
   error dialogs; exercise a deliberate failure with an asserted result.
3. Locate and pin the LLVM tools used for the experiment.
4. Have the VB6 executable emit a minimal LLVM module, compile/link it for
   Windows x64, assert the PE machine type and the expected process exit code.
5. Record exact commands and results before declaring the bootstrap viable.

VB6's 32-bit host does not require a 32-bit generated target. Emit textual LLVM
IR and invoke the backend out of process; do not attempt to load a 64-bit LLVM
library into VB6. Target integers must not inherit VB6 host overflow behavior.

On 2026-11-10 the following command passed outside the restricted sandbox:

`rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File bootstrap/tests/vb6-llvm/check.ps1`

Tools: VB6 6.00.9782 and Clang 23.1.3. Assertions passed for IR emission,
invalid-path exit 3, x64 PE machine 0x8664 and generated-program exit 42.
The sandboxed invocation failed on registry access; the outside-sandbox build
succeeded without a registry change. This proves the fixed IR bridge only.
It does not parse UBE source or establish self-hosting. Tool versions are
recorded, not yet packaged or enforced as release prerequisites.
