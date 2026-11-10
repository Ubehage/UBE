# UBE declaration binding acceptance

Run `rtk proxy powershell -NoProfile -File bootstrap/tests/declaration-binding/check.ps1 -BootstrapExe <executable>`.
The host executable builds the actual UBE scanner, parser, project storage and
declaration binder with portable UBECore. Runtime file input then supplies the
test projects; their bodies are data, not host-compiled replacements for binding.

The gate checks nominal declaration identity, ordered parameter and field links,
scope regions, visibility/defaults, scalar and record signatures, array rank,
entry selection, duplicate/name/type errors, preserved output on failure,
repeatability and project isolation. Recursive Type edges are resolved nominally;
this gate does not claim recursive runtime layout or expression type checking.
Actual compiler and library modules supply a substantial declaration graph.
Diagnostics assert original module-local byte/UTF-16 positions, including an
error in the second module of a project. A body containing an unresolved call
deliberately still succeeds, making the declaration-only boundary explicit.

Two generated modules admit exactly 16,384 symbols and reject 16,386 with the
symbol-cap diagnostic, rather than the lookup-work limit. Corrupt token spans,
module windows, package spelling and cyclic parent/sibling links produce
controlled input diagnostics while preserving older bound symbols. An isolated
fresh project after failures publishes exactly its own two declarations.

Both O0 and O2 use the same emitted library. Changing an actual file's Friend
declaration to Public must fail the precise unchanged visibility assertion.
Numbered assertions, emitted IR, native images and hidden bounded-child logs
remain in a temporary `ube declaration binding <guid>` evidence directory.
Production-only assembly at both levels must not reference the test driver's
Windows stack-page helper. Fault-injection companion gates cover allocation
and publication independently.

Acceptance passed 31 cases and 19,239 assertions at each of O0/O2, both
production-only assembly checks, and the exact changed-visibility negative
control (assertion 814). Many assertions cover path setup and fresh return
status in addition to the semantic observations.

Evidence: `ube declaration binding e7baceb5-9831-46c6-b6c3-550199867ce4`.
Command: `rtk proxy powershell -NoProfile -File bootstrap/tests/declaration-binding/check.ps1 -BootstrapExe <executable>`;
the executable was `ube project loading 4512f340-a4e4-4aaf-98c4-de2e5192b324/build/UBE-Bootstrap.exe`
under the temporary directory. This run used the final shared arena validation
and binder tree-integrity checks.

Companion scripts use the same `-BootstrapExe` argument:

- `allocation-check.ps1`: 34 O0/O2 checks cover all eight binder allocation
  sites (both attempts), all 16 prior symbol fields, successful retry, sticky
  Err, depth refusal through 256 and zero live allocations after disposal.
  Evidence: `ube binder allocation fc834448-1d00-4331-b0e9-84647d98ab22`.
- `append-check.ps1`: 56 O0/O2 checks cover all nine append allocation sites,
  depth refusal, ten metadata corruptions, and an injected failure after new
  byte/token tail writes. Committed module prefixes and counts remain intact;
  all owners are released. Evidence:
  `ube project append c3b617ff-dc8b-45c7-9541-528cc7ffc2f5`.
- `handler-scope-check.ps1`: O0/O2 success and changed-depth negative control
  verify independent caller/callee and recursive handler states, return without
  reset, local GoTo 0 and separate persistent Err. Evidence:
  `ube handler scopes fc10a9cf-046d-4eca-81e4-fdc45c6ff82f`.
