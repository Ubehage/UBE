# IDE execution context

Owner-approved direction: expose `IS_IN_IDE` as a global, read-only Boolean
compiler-supplied constant. It describes the program's IDE execution context,
not whether the compiler was launched from an editor, optimization is disabled,
or debug information is present. Normal standalone execution is False; execution
hosted by the UBE IDE is True. It must not be a writable shared compiler global:
the final compiler retains the value in each compilation's context.

The UBE compiler implements both contexts and the guarded Windows launch contract
below. A repository-owned host fixture qualifies launch/debug lifetime behavior;
the GUI IDE and source-level debugger remain future work.

The VB6 bootstrap implements its host equivalent now. `BootstrapMain.Main`
resolves the value on each startup through a `Debug.Assert` helper; the assertion
always succeeds in the IDE and is omitted from built executables. A public
read-only `IS_IN_IDE` property exposes the cached value. The local `ExitProcess`
wrapper calls the Windows API, declared as `NativeExitProcess`, only outside
the IDE. Existing callers still exit Main immediately after the wrapper returns.
This is sequential VB6 host state, not the final compiler's concurrency design.

The focused native/IDE regression is in `../bootstrap/tests/host-ide/check.ps1`.
The test substitutes command input/output but retains actual Main, its helpers
and the remaining bootstrap modules. It checks all completion paths and includes
an isolated negative control that restores the old unconditional termination.

## Implementation findings and approved launch behavior — 2026-11-27

The implementation follows this approved integration boundary.
`CompilationRequest.TryCompile` already owns request-local inputs and arenas;
the execution-context selection belongs there and must travel with those facts.
Initial inspection found direct scanning/parsing in
`ProjectSyntax.TryAppendModuleInDomain` and no conditional compilation in either
compiler path. The UBE path now selects conditional source before parsing, as
recorded below. A binder-only False constant would not complete this item.

The tracked IDE folder contains design and planning entry points, but no current
IDE application or launch/debug protocol. References in IDE/TODO.md to an
application/workplan do not identify files present in this checkout. The locked
IDE design requires compiler and user-program processes outside the IDE process.

The owner explicitly approved the separate guarded IDE-run artifact boundary
on 2026-11-27. The accepted behavior is:

- Ordinary builds bind `IS_IN_IDE` to Boolean False, including conditional
  compilation. Launching the compiler from an editor does not change it.
- An explicit IDE-run compilation request binds it to Boolean True. This
  request state is private to that compilation; source code cannot assign,
  redeclare or override the supplied symbol.
- An IDE-run artifact requires a live host launch session before any source
  initializer or entry procedure executes. Without that session it reports an
  actionable launch error and does not run source code. A standalone build is
  required to run independently; it uses False.
- Implement and test the minimal host/session boundary against a repository-owned
  host fixture, preserving the future IDE's process isolation. Do not claim that
  this fixture constitutes a finished IDE or debugger. Exact transport and
  lifecycle checks must be reviewed against the accepted launch behavior before
  implementation; a persistent environment flag alone is not a live session.

This preserves a true compile-time constant and prevents a copied IDE artifact
from silently executing True outside its intended host. Making the same artifact
switch to False at runtime cannot undo branch removal by `#If IS_IN_IDE Then`.
It would require a different language/build contract, not just another binding.

The Windows host/session contract uses a unique named job
`Local\UBE.IDE.<32 hexadecimal digits>`, with kill-on-last-handle-close and no
breakaway flags. A host creates a non-inheritable job handle, rejects name
collisions, and uses `PROC_THREAD_ATTRIBUTE_JOB_LIST` to put the target into the
job atomically during process creation. It retains the sole lasting job handle
through run/debug execution and supplies the name in the target's private
`UBE_IDE_SESSION` environment block. It must not mutate shared host environment
state or pass the job handle to children. Ending the session closes that handle.

Before runtime-context allocation or source initialization, a hosted executable
opens a non-inheritable query handle, validates actual process membership and
the kill/no-breakaway flags, then closes that transient handle successfully.
Failure reports `E_IDE_CONTEXT` and exits 125 without running source. A stale
environment value or unrelated named job does not satisfy membership. This is
a cooperative lifetime contract, not authentication or a hostile-process sandbox;
an additional retained job handle would extend the session and violates the host
contract. Atomic job assignment requires Windows 10/Server 2016 or later.

Explicit `--build-ide` and `--emit-llvm-ide` requests select True and include the
guard. Ordinary command forms and the existing compilation API default to False.
Hosted library artifacts without an executable entry are rejected. The host
fixture exercises this boundary without representing a finished IDE or debugger.

Acceptance must cover both values in ordinary and conditional expressions,
write/redefinition/ByRef rejection, normal builds started from an editor,
missing/invalid/ended host sessions before source initialization, deterministic
diagnostics and output preservation, simultaneous opposing-context requests,
and the existing self-host/conformance/concurrency gates. The root README and
GitHub main must be updated after completion, as requested by the owner.

### Admission baseline

The qualified Exit Loop compiler `68e264aa/generation-2/UBE.exe` was invoked
with `--emit-llvm <sample.UBE> <sample.ll>` through
`rtk proxy powershell -NoProfile -Command` for three isolated native-envelope
samples. A literal-zero Main emits successfully. A Main reading `IS_IN_IDE`
is rejected with `E_COMPILE`, operation/code/reason `0/2/10`, at `builtin.bas:5:4`.
A file starting `#If IS_IN_IDE Then` is rejected with `E_LOAD`, `8/3/2`, at
`conditional.bas:4:1`. Both rejections exit 1 and retain exact preexisting
output sentinels. Evidence and asserted output-preservation results are in
`%TEMP%/ube ide context admission OBfiu1/report.json`. These are admission
baselines, not successful implementation tests.

The reproducible baseline gate now lives at
`compiler/tests/ide-context/admission-check.ps1`. Run:

```powershell
rtk proxy powershell -NoProfile -File compiler/tests/ide-context/admission-check.ps1 -CompilerExe <qualified-UBE.exe>
```

It passes on the same 68e264aa generation-2 compiler: a successful control,
both exact unsupported-feature diagnostics, sentinel preservation, identical
control LLVM after each rejection, and no leaked publication stage. Evidence:
`%TEMP%/ube ide admission 683c9131-1f1a-448d-b6b0-ccb626b8d139/report.json`.
The report records the compiler hash. This gate intentionally expects the old
admission boundary; it must not be presented as implementation acceptance.

### Initial integration map (historical)

- Pass the selected target context through request-owned loading/binding facts;
  neither `CommandOptions.CommandRequest` nor the current manifest has such a
  selection. Optimization and DebugInformation must not determine it.
- Add conditional selection before `ProjectSyntax.TryAppendModuleInDomain`
  invokes the scanner/core parser. Preserve the existing normative file-local
  constants, unshadowable supplied symbols, inactive-branch behavior, source
  coordinates and opaque assembly payload rules rather than admitting only a
  hard-coded `#If IS_IN_IDE` spelling.
- `ExpressionBinder.LookupName`, its name/member expression path, and
  `ConstantDependency` need deliberate predefined-constant handling. Merely
  setting `ConstantKnown` with SymbolIndex zero is rejected by existing later
  checks. Reject redefinition at symbol registration, not after ordinary lookup
  has already shadowed the supplied identifier. Writable facts govern writes
  and direct ByRef admission.
- Existing Boolean facts (`KwBoolean`, -1/0, not writable) and native constant
  emission suffice; no new native expression opcode is needed. The selected
  value must be resolved into immutable expression facts before native workers
  start, preserving the current concurrency model.
- Preserve ordinary grouped ByRef semantics: direct writable-reference use of
  IS_IN_IDE rejects, but a parenthesized expression may supply a temporary under
  the existing language rule. Do not create a synthetic zero-node BoundSymbol:
  declaration indexing requires real syntax-backed identities. Explicit
  predefined expression facts must pass both ConstantDependency and the ordinary
  name-value guard. Registration checks must distinguish lexical declarations
  from separate namespaces such as labels and qualified fields.
- Bootstrap integration points are `ProjectLoader.ProjectContext`,
  `SourceParser.ParseProject`/`LexSource`, and `SourceSemantics`. The VB6
  `BootstrapMain.IS_IN_IDE` describes the compiler's host and must never be used
  as the target program's value.

### Conditional-compilation dependency checkpoint (historical)

`ConditionalExpressions.bas` evaluates the separate directive grammar using
existing constant arithmetic, text operations and request-owned symbols.
`ConditionalSource.bas` performs per-file branch/constant selection, registered
in the compiler package and wired into normal project loading. The loader now
supplies IS_IN_IDE from an explicit per-load Boolean, retained in each parsed
module and checked for consistency before append/binding. Default loading is
False; appended support inherits that same context. Ordinary binder integration
and concurrent frontend isolation pass the focused gates below. There is no
new IDE-run command at that historical checkpoint. The completed commands and
host protocol are described above.

The new SourceScanner range/selection APIs retain original source bytes and
physical byte/UTF-16 positions, recognize opaque Asm blocks and share the
ordinary comment/continuation rules. Verification:

- `rtk proxy powershell -NoProfile -File compiler/tests/conditional-compilation/scanner-check.ps1 -CompilerExe <68e264aa generation-2/UBE.exe>`: 30 O0/O2 executions pass, including changed observations and escaping-helper FAIL controls. Evidence: `ube conditional scanner 07137975-4114-41e3-a303-f037d47e13ec`.
- `rtk proxy powershell -NoProfile -File bootstrap/tests/source-scanning/check.ps1 -BootstrapExe <d798 seed>`: all 90 existing groups pass. Evidence: `ube source scanning 57176708-c059-4450-8fe2-bb03f077a0aa`.

The selection gate passes 25 authored cases at O0/O2 and four negative-control
runs (`ube conditional selection be6ab975-58cc-4175-bd08-a22f03cd1177`). The
integrated project gate passes six native runs and original-coordinate failure,
output preservation and deterministic recovery checks on dd683241 generation 2
(`ube conditional projects 7e114939-875c-4f3d-a035-945b8dc045c5`). Run the
respective `selection-check.ps1` and `project-check.ps1` in
`compiler/tests/conditional-compilation` with `-CompilerExe` set to that compiler.
The repeated compiler build passes with identical LLVM and native differences
limited to the COFF timestamp; exact hashes are recorded in Progress.md.
These qualify the conditional frontend dependency, not the full hosted execution contract.
The first broad selection-test package contained both the CLI Main and the
test Main; correcting that harness exposed O0 stack-probe calls in the broad client.
The new directive dispatch was separated from source traversal without changing
its branch operations. Selection tests now compile their real dependency
closure. Current integrated evidence follows.

### Standalone and frontend checkpoint (before hosted integration)

The 35885756 generation-2 compiler passes repeated self-build comparisons and
the expanded project gate: 12 native O0/O2 runs, four builtin write/reference/
redefinition rejections with preserved outputs, original source coordinates and
deterministic recovery (`ube conditional projects
ab3debff-1f0e-46a9-9f9a-8ec93305df09`). Full/None debug settings do not select an
IDE context. A grouped ByRef expression uses a temporary as required by the
existing language definition; direct writable-reference use rejects.

`compiler/tests/ide-context/binding-check.ps1 -CompilerExe <dd683241 generation 2>`
passes all six O0/O2 runs for 13 source cases evaluated False/True/False, including
changed-value and escaping-FAIL controls (`ube context binding
14358ed5-42f4-45d9-bb40-b20201d7173e`). Field/label namespaces are preserved;
a matching package named IS_IN_IDE resolves in qualified receiver position,
while the bare identifier remains the supplied Boolean.

`compiler/tests/ide-context/loading-check.ps1 -CompilerExe <dd683241 generation 2>`
passes six O0/O2 runs with default False, explicit opposing values, append
inheritance, mixed-context rejection and exact Unicode coordinates. Two workers
perform eight independent loads each after a both-ready rendezvous (`ube context
loading 812dad30-79e6-4695-936a-0c2072c250a4`). This tests frontend requests; it
does not implement a hosted executable or a launch session.

Broad expression binding passes 84 cases/37587 assertions at both O0/O2 and the
changed-source control. Common CLI conformance passes 1004 assertions across
the 4c2a480f seed and the new compiler. The corrected e0874b0b seed additionally
passes 510 seed conformance assertions and the complete current-source compiler
concurrency gate, including native backend timeout/recovery. Exact commands,
compiler hashes and capacity-regression evidence are recorded in Progress.md.
Final hosted execution and regression acceptance are recorded below.

### Final hosted acceptance — 2026-11-27

The final compiler is generation 2 of `ube compiler rebuild
5c66c361-60ad-4cae-9670-1c1ab27e8e10`, SHA256
`3BB5B9E82A39BBEC607F5ED07926FF3B8E30A3B54EA03CD129FAD8E52D492116`.
`compiler/tests/ide-context/session-check.ps1 -CompilerExe <final compiler>`
passes 35 checks: O0/O2 ordinary False and hosted True, rejection before source
initialization, missing/malformed/stale/unrelated sessions, invalid job flags,
collision refusal, delayed resume with the session retained, and termination
when the host closes while the target is running or suspended. Evidence:
`%TEMP%/ube ide session 619cd81c-46a9-4a8a-91a5-d36c1392bd57`.

The full `bootstrap/tests/concurrent-compilation/check.ps1 -BootstrapExe
<e0874b0b seed>` passes existing isolation/failure/publication/backend checks
and six context cases: independent baselines and simultaneous opposing values
in both assignment orders at O0/O2. Exact LLVM comparisons prove distinct
conditional selection and the guard only for True, before context initialization.
Evidence: `ube concurrent compilation 883b78b0-7350-404a-9f10-d6c7d372c654`.

Successive self-builds match LLVM byte-for-byte and native images except the
COFF timestamp. Final compiler-only conformance passes 518 assertions. Exact
commands, source provenance and further focused acceptance are in Progress.md.
All PowerShell gates use `rtk proxy powershell -NoProfile -File`.

The final `compiler/tests/conditional-compilation/project-check.ps1
-CompilerExe <final compiler>` passes 28 recorded checks, including both-context
write/direct-ByRef/shadow/directive rejection, ordinary library emission and
both hosted library rejections (E_BACKEND 0/1/1) with unchanged outputs. Evidence:
`ube conditional projects 6ca3c0b6-2604-4713-9dcf-e6b5ffd0fa1c`.
