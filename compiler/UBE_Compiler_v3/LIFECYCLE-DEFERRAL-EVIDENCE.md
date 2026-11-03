# Lifecycle deferral correction evidence

The earlier local checker accepted module lifecycle declarations and direct
calls as ordinary procedures. The retained probes and exact old-checker
observations are in `tests/native-executable/lifecycle-probes/EVIDENCE.md`.
The bounded semantic contract defers lifecycle declarations; the language
specification separately forbids direct lifecycle calls. The focused correction
uses existing cooked identifier identity and reports existing UBE1400 at a hook
declaration. It does not implement lifecycle execution or separately prove
direct-call enforcement in a future compiler that supports hooks.

The final source-built bootstrap cohort is
`25f3b4878a1348e79766e70decd66b66`, manifest SHA-256
`A56778FE1D2F72F8A79A158A8C292E02F49E785945463D415165790CB362D5E7`.
`rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1` passed 894
acceptance assertions. The maintained semantic CLI gate passed both stages,
including 37 lifecycle cases per stage (source and project jobs 1/2/4,
case/bracket variants, direct-call/defer precedence, unaffected names,
direct-library reference and source order):
`bootstrap/out/semantic-cli/e5b3d482d7fd46539e190ea70d20ecef/report.json`.
Its child proofs and fixed independent expectation/identity negative controls
were checked by `bootstrap/out/semantic-inputs/
93a767e4d6a64877a756d5d3abfcb3ae/report.json`.

The complete fresh gate inventory and report identities are in
`bootstrap/out/semantic-implementation/final25-lifecycle-audit-inputs.json`.
The independent audit command
`rtk proxy powershell -NoProfile -File bootstrap/out/semantic-implementation/statements/native/audit-final-acceptance.ps1 -RecordPath bootstrap/out/semantic-implementation/final25-lifecycle-audit-inputs.json -RequireComplete`
passed for its specified 16-report inventory: 6,044 structured identities,
108 nested reports and zero identity errors. Its report is
`bootstrap/out/semantic-implementation/statements/native/acceptance-audit/
9abfc3ae5f2444c0bd0a07cbbd21093d/report.json`. It excludes the historical
component handoff and does not itself universally assert each nested report's
success; use the individual parent gates for their stated checks.

The retained whole semantic, catalog, expressions, formatter, source-worker,
parser, project and source CLI, concurrency, lifetime, definition and docs
checks are identified in `Progress.md`. The lifetime test has its own explicitly
bounded scope and does not claim production or performance qualification. The
complete-definition validator is definition-only. Neither this correction nor
these checks qualify native executable generation, the proposed tool boundary,
source-level debugging, or full-language behavior.
