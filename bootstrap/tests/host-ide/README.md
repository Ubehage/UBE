# VB6 IDE-safe termination regression

Run `rtk proxy powershell -NoProfile -File bootstrap/tests/host-ide/check.ps1`.
VB6 needs access to its installation's registry entries. The test launches only
isolated temporary projects; it does not use an already-open developer project.

Actual BootstrapMain code is copied with its entry renamed for a test caller.
Command input/output are substituted to select success, usage, project failure,
output failure and unexpected-error paths deterministically. Each compiled EXE
must terminate with the exact expected exit code (0, 2 or 1), without returning
to the caller. Each IDE execution must return to the caller with IS_IN_IDE=True.
`/runexit` then closes that isolated IDE normally. An unconditional native-exit
negative control must prevent the caller's return marker, reproducing the bug.
All process waits have a 30-second deadline and retain evidence in temporary
directories. This does not test IDE command-line argument handling or console UI.

Passed on 2026-11-10 with VB6 6.00.9782:

- `host-ide/check.ps1`: 10 cases plus the old-behavior negative control;
  `ube host ide f7f56992-a0a8-4e17-99d4-5832c67aad99`.
- `host-error-recovery/check.ps1`: four recovery cases including the missing-Resume
  negative control; `ube host error recovery 69eff74a-0d48-4283-9511-a2097e0e7868`.
- `project-loading/check.ps1`: rebuilt unmodified production sources and passed
  all 54 CLI cases; `ube project loading dbd30a59-26f6-43b5-a9d9-e3b4c6143261`.

All scripts are under `bootstrap/tests/` and were invoked with
`rtk proxy powershell -NoProfile -File <script>`. Evidence directories are under
`C:\Users\Ubehage\AppData\Local\Temp`.
