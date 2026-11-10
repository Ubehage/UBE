# Compiler development handoff

## Active work: scalar source-to-native implementation

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
Next emit LLVM from those bound trees and qualify real native execution of the
SourceOracle.bas cases, including the approved FAIL protocol. Preserve the
retained conversions, argument modes, exact constants and declaration roles;
do not rediscover behavior from source spellings or fixture names.

Adaptive context inference, assembly lowering and compound-header failure
continuations are outside this first implementation. The runtime inventory in
`../std-lib/INVENTORY.md` remains a planning input, not a support claim.

## Semantic gate

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
and colliding package/module three-part qualifiers. Full Err signatures and
runtime behavior remain future work. Actual concurrent compilation and editor
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
Native execution remains subsequent work.

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
and cross-module call binding. LLVM emission remains unimplemented.
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
matching future source gate and are explicitly unexecuted.

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
