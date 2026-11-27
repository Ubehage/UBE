# Class instance-member acceptance

`baseline-check.ps1` records the pre-member compiler's admission boundary. Run it
against that historical compiler, not as a rejection requirement for the completed
implementation:

```powershell
rtk proxy powershell -NoProfile -File compiler/tests/class-members/baseline-check.ps1 -CompilerExe <UBE.exe>
```

The qualified 5c66c361 generation-2 compiler (SHA256
`3BB5B9E82A39BBEC607F5ED07926FF3B8E30A3B54EA03CD129FAD8E52D492116`) passes four
baseline cases. An empty class emits LLVM. A numeric field, an ordinary method,
and a method returning Me each reject at `Gate.cls:4:1`, with exact
`E_LOAD` operation/code/reason `8/3/42`, exit1, empty stdout, preserved output
bytes, and no leaked publication stage. Evidence:
`%TEMP%\ube class member baseline f64d17a1-e84c-4046-8a6d-c28a9be3535c`.
These are emission/admission assertions, not native execution. The Me fixture
currently fails at its method header, so it does not independently test Me binding.

Future acceptance follows [language-spec.md](../../../lang-doc/language-spec.md)
sections6,7,9,12 and the [managed-memory contract](../../../lang-doc/managed-memory.md):

- Distinct instances have separate fields; aliases share identity and updates.
  Static member selection, visibility, lookup shadowing and signature checks
  follow the existing declaration rules.
- Me denotes the current invocation's instance. Recursion and calls on another
  instance retain the correct receiver; assignment and direct writable ByRef
  use reject. Module, declaration and initializer uses reject. Grouped ByRef
  expressions follow the existing temporary rule.
- Live receivers, returned references, managed fields and field-access
  temporaries survive collection and calls. Managed field writes require the
  existing barrier and precise layout; cycles must remain collectible after
  external roots disappear. Object identity is never a raw-address substitute.
- Nothing member access and failed arguments/methods produce controlled FAIL;
  no failed value commits an assignment. Successful calls preserve stale Err.
  Receiver evaluation, completed side effects and cleanup follow existing
  expression/error rules. Explicit user resources remain user-owned.
- Accepted field initialization must establish neutral storage and preserve
  partial-construction failure cleanup. Lifecycle hooks and other member forms
  outside the implemented scope must remain explicit diagnostics rather than
  being silently ignored.

The existing object-monitor gates cover empty-class identity and monitor/root
behavior. Class-field tracing, instance method ABI, receiver rooting and Me
semantics require the additional gates below. No new language or lifetime rule
is introduced by these fixtures.

`check.ps1 -CompilerExe <candidate>` prepares the end-to-end acceptance gate;
`-Suite Execution`, `GC`, or `Diagnostics` isolates its three groups. Execution
has positive, changed-value and escaping-helper-FAIL runs at O0/O2. Its entry
handler and staged Boolean results prevent a failed test call from silently
skipping an assertion. It covers independent fields/aliases, finite record
copy/ByRef update, managed values, implicit and explicit Me, recursion across
instances, grouped Me, receiver reassignment during calls and field ByRef,
receiver capture before a later argument replaces its named reference and
collects, Nothing-method argument suppression,
Nothing, receiver failure before RHS effects, fresh FAIL and sticky Err.

The GC group emits a separate source probe and adds an observation-only wrapper
around genuine object allocation. Five captured identities are stored as raw
non-root integers. Seven observations inspect the real collector's identity
registry: a cycle reached through an embedded record field survives while
rooted, then both objects disappear; an integer field equal to another object's
identity does not retain it; a field passed ByRef keeps its owner alive across
collection after its named reference is cleared, then releases it on return.
The source also verifies embedded String contents and object links. The observer
does not replace collection or manufacture identities. O0/O2 negative controls
change the exact observation count and must return99.

Diagnostics check located rejection and unchanged prior output for inaccessible
Private members, unqualified leakage, static class-member access, forbidden Me
uses, instance CallNew, and currently unsupported arrays, field initializers,
lifecycle hooks and properties. Cross-package import behavior is not simulated.
Direct and synchronously forwarded field aliases passed to CallNew must reject
at the source alias with native escape reason8/55, preserving prior output.
The combined gate passed24 checks (six execution, four collector and fourteen
diagnostic checks) on the diagnostic candidate
`%TEMP%\ube class compiler solo-20261127\Diagnostic-UBE.exe`, SHA256
`3C229E3A1B85D28C9FA96854760BDFE6CC78985DE01B318E273E50E67EE16A7F`.
Command: `rtk proxy powershell -NoProfile -File compiler/tests/class-members/check.ps1 -CompilerExe <candidate>`.
Evidence: `%TEMP%\ube class members 764714ae-bcff-41a0-a758-dfc4045dbebb`.
This is a focused candidate result, not final self-host qualification. Earlier
runs exposed two fixture mistakes: a variable named with reserved keyword Alias,
and diagnostic projects importing an unrelated helper that required a removed
field. The fixture now uses ReferenceAlias and a minimal diagnostic helper;
production was unchanged by those corrections.

The complete gate was repeated against the self-hosted compiler
`%TEMP%\ube compiler rebuild 97b47838-ae5e-43b6-94dd-45ef39c127d2\generation-2\UBE.exe`,
SHA256 `5510298EAFD95492DD619683B3B562A07408F5764894EDCE0D86D10646B3DA98`.
The same command with that `-CompilerExe` passed all 24 checks. Evidence:
`%TEMP%\ube class members bee8058c-6dd6-4f7d-8fd4-2d02e7c2948e`.

The expanded scalar field fixture repeats all 24 checks successfully in
`%TEMP%\ube class members e6de1dc4-f834-4bb4-9e09-3a60f5a86310`.
Byte, Integer, LongLong, Boolean, Single and Double fields check neutral values,
instance isolation and exact round trips (255, -32768, Int64 maximum, True,
1.5 and -2.25). Real collection still checks the shifted managed-field offsets.
After adding failed-RHS field preservation (existing value 52 and Err 17),
the same command with `-Suite Execution` passes all six execution/control runs:
`%TEMP%\ube class members fef0316a-d721-4bc7-a6a4-8be993413c27`.

### Nonempty object allocation failure

`check.ps1 -CompilerExe <final compiler above> -Suite Allocation` passes four
O0/O2 checks in `%TEMP%\ube class members d49ee4ee-8bac-43b0-9f03-21ea42f1d620`.
`All` now includes these checks, making 28 cases; the prior 24-case result and
this four-case result were separate executions against the same compiler.
The final combined `-Suite All` rerun subsequently passed all 28 cases in
`%TEMP%\ube class members 2896db41-3e1b-4936-a723-d067879c06b5`, covering the
shared observer harness together with execution and located diagnostics.

`allocation-main.bas` and `allocation-observer.ll` retain the actual object
constructor, managed allocator, retry and collector. The observer enables a
target-allocation fault window only during the second and third New calls,
after normal support initialization. Every target allocation in each window
returns null; at least two attempts per construction must occur. Assertions
require a nonempty payload, a false construction result, fresh Err 7, unchanged
output slot and unchanged construction-candidate chain. Source assertions prove
the old identity and value 37 survive default skipping and a caller handler;
a subsequent New creates a distinct neutral object. Actual collection retains
both live objects and reclaims both after their source references are cleared.
Raw observed identities are never registered as roots. The negative control
inverts the old object's observed registry presence; the source must reject the
retention mask with exact exit 4, rather than pass. All runs require empty
stdout/stderr and retained, nonnull native exit status. No production allocation
or collection behavior was changed.
