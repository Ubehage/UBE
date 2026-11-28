# If condition error regression

Run `rtk proxy powershell -NoProfile -File compiler/tests/if-errors/check.ps1
-CompilerExe <compiler-or-seed.exe>` from the repository root.

The fixture checks recorded Err and normal False-branch selection for failed
block/single-line If, ElseIf chains, nested If, missing Else and integer division.
It checks remaining operands are abandoned, earlier calls remain observable,
stale Err does not prevent a successful True branch, On Error Resume Next uses
the same rule, enabled handlers receive control and active handlers do not
reenter. Pre/post Until failures must still leave their loops.

The unchanged source must return exactly 0 at O0 and O2. A changed-result control
must return exactly 1 at both levels. Compilation requires a success marker and
empty stderr; execution requires the exact status and empty stdout/stderr.
Every run retains compiler/source hashes, process logs and report.json in Temp.
Explicit Resume syntax is not supported and is not tested here.

The pre-fix compiler failed at O0 with exit 13, evidence
`ube if errors 9ba5203e-c1dd-475c-8c65-f8ac16d8526e`. The corrected seed passed
all four native runs in `ube if errors 0af4eba2-f50c-4685-a0ff-df3ac325ff6f`.
The final second self-built generation passed all four in
`ube if errors ec38d045-df0f-4d57-97c6-914a5180bbfe`.
Compiler identities and broader checks are recorded in `../../Progress.md`.
