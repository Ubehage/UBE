# Initialization-warning evidence

The compiler-owned dependency matrix, component witnesses and ordered UBE1514
records are implemented in `src/NativeWarnings.bas`, under
`NATIVE-WARNING-IMPLEMENTATION.md`. The reusable component traversal belongs to
UBECore; its independent evidence is `../../std-lib/GRAPH-COMPONENTS-EVIDENCE.md`.

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/warnings/check.ps1 -DiagnosticOnly
```

Report `bootstrap/out/native-warnings/8ea86280022b4654bef0249028983c9a/report.json`
passed all six groups, exit 0. Each pinned bootstrap stage passed 2,098,158 native
assertions. Both 899,871-byte raw LLVM images have SHA-256
`4CA9FB7E5387427A7510407A4063D526EFCEF268399603A0963C864AB3AE9FEF`.
The report retains the current captured source/tool/artifact identities and
14 terminal commands (57,491 ms summed process elapsed time). The production
NativeWarnings source hash is
`240E5A932C17BF9E2F46EDDB263184533EE95814C3B9160FC50B966558448A1A`.

The independent six-module fixture contains two multi-module cycles, a self
cycle, an outgoing edge to a downstream module, duplicate edges, tied warning
positions and reversed arrival order. Expected warnings explicitly retain the
full original spans and smallest component member. The earliest downstream
edge is excluded from the cycle's witness. Changing the expected witness is
rejected by a negative control in both stages.

The observer counts actual compiler index visits and actual library transitions;
their sum must equal charged work, including failure paths. A control omitting
one visit is rejected. Workspace headers, allocator/copy instrumentation and
shared usage counters check the exact 12*M*M + 24*M base payload and additional
20*M component workspace. Allocation failure, real root-registry saturation,
invalid dimensions/edges, begin-on-live ownership, private partial results,
pre-cancellation and cancellation at a 4096-transition boundary are covered.
Every test drains its owners and roots and checks zero retained live payload.

Work allowances below, at and above completion are checked on a self cycle.
Payload limits bracket both base and peak ownership. Eight-module disconnected
and chain graphs exercise pending limits 0 through 9 with two other pending
entries already charged. The consumer preserves those entries, admits only the
library's remaining allowance and reconciles actual live/peak counts even when
the library fails. Empty graphs succeed under zero budgets. Err is preserved.

The harness uses the production UBECore reference. It extracts the exact
TryVisitNativeIndex definition from NativeGraph into a test compilation unit,
retaining the complete original file identity; it does not replace the function
with an oracle implementation. The native observer uses the real bootstrap
runtime and existing allocation/copy observations.

The earlier run `88ac8ea5d7504af38afefa7b1ae3ecf1` failed compilation because
the test entry omitted the existing StringLength/StringByteAt declarations used
by NativeOutput. Adding those test declarations resolved the failure; no new
production intrinsic was introduced. Run `3513dd5d36ca43c0a86c14db49c60f04`
passed before production manifest/bootstrap registration. The final run above
uses that registration and bootstrap-compatible assertion descriptions.

GraphComponents is now in UBECore. NativeWarnings is in the compiler manifest.
Both focused gates, plus the previously manual checked-graph lowering gate,
are registered in `bootstrap/build-v2.ps1`. The full updated bootstrap has not
run. These DiagnosticOnly results use historical qualified df158 tools with
current captured sources, not a new source-built cohort. Those component results alone do not qualify
checked-source/ByRef dependency extraction, CLI/IDE warning delivery, runtime
module initialization, or the complete native builder.

Registration checks used
`rtk proxy powershell -NoProfile -File bootstrap/out/check-native-registration.ps1`:
all six registered PowerShell scripts parsed without errors. A separate
filesystem/schema assertion checked 13 unique existing UBECore sources and
53 unique existing compiler sources, plus nonempty passed assertion descriptions
in the component, warning and retained checked-graph reports. These checks cover
registration structure only, not execution of the complete bootstrap.

## Checked-source discovery and ByRef propagation

Production NativeDependencies now consumes the actual immutable checker output,
retained source spans and dense declaration indexes. Its ownership and counted
work contract is in NATIVE-WARNING-IMPLEMENTATION.md. No LLVM, target identities,
source copies, public IR, reparsing or name resolution are added by discovery.

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/warnings/check-sources.ps1 -DiagnosticOnly
```

Fresh report `bootstrap/out/native-warning-sources/c4f0f07a56b740d4ac45426d4363e0cc/report.json`
passed all six groups, exit 0, with 2,108,156 assertions per stage. This count
includes exhaustive real-root pressure, not millions of independent programs.
All 16 commands terminated, with 619,270 ms summed process elapsed time.
Both independently compiled raw LLVM images are 7,563,117 bytes, SHA-256
`5D34E742E7571495F2F80C88A43ACCA79BF180B707A03FF512F35164AE0F5062`.
Captured NativeDependencies is 33,402 bytes, SHA-256
`1707599239C4EA27A3C69F04E458CB82516FA87155D5E9E52012834E51F4AC91`.
The report records every source, tool, adapter and output identity.

The independent JSON fixture has 23 source cases: 22 accepted projects and one
specified checker rejection. Each accepted project runs through the real frontend
and checker with jobs 1, 2 and 4, then production dependency discovery and component
selection. Exact matrix edges, full source spans, ordered UBE1514 records, actual
work and peak payload agree across those worker budgets. Cases cover direct and
forwarded root aliases, named/omitted arguments, forced/default/ByVal/local/other-
module storage controls, seeded and unseeded recursive forwarding, already-true
witness replacement, direct module cycles, uncalled helpers, foreign helper reads
and writes, retained branches, downstream exclusion, provably skipped calls and
foreign native intrinsics. Function-result storage as an exact ByRef actual is
rejected with the frozen UBE1417 span; it is not treated as an accepted program.

The native observer counts actual index visits, cursor events and Core transitions
and reconciles their sum with charged work. Actual queue/cursor/component live
and peak entries reconcile with pending charges; capacity headers reconcile live
payload. Checks cover exact and below-bound work/payload/pending, two preexisting
pending entries, cancellation before work and after a true formal is queued,
persistent allocation failure, full real root-registry pressure and disposal.
Snapshots prove checked nodes/facts and declaration targets unchanged. Successful
discovery preserves Err 77; all paths release roots and retained payload. Altered
expected spans and an omitted observed visit are rejected by independent controls.

| Forwarding-cycle modules | Observed work | Peak payload bytes |
| --- | ---: | ---: |
| 2 | 186 | 1436 |
| 4 | 572 | 2340 |
| 8 | 1992 | 4436 |

The scaling oracle requires growth no greater than fourfold per doubling for these
concrete complete-cycle inputs. It observes operations rather than substituting
input sizes for work. These measurements are not whole-lowering resource acceptance;
the separate declaration-work review remains unresolved and its approved 2*D bound
has not changed.

### Fixture admission and retained failures

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/warnings/check-source-admission.ps1 -Compiler bootstrap/out/semantic-cli/e5b3d482d7fd46539e190ea70d20ecef/stage2/ube.exe
```

Report `bootstrap/out/native-warning-admission/050771b4bddd4c27ac592467002f0b35/report.json`
passes 46 exact process checks: jobs 1 and 4 for all 23 cases, including expected
UBE1417 rejection. This independently uses the historical qualified 25f3 checker;
it does not execute the source programs. Recursive examples are static-analysis
fixtures. The first six-case admission report b8d50d90c9eb44f59b939e998d9179c2
and reserved-name Read rejection dfda608aa9d748e087afbd3ba40c2d81 remain history.
Renaming the fixture helper to PeekValue did not change language behavior.

Earlier discovery run 58c7d4be67ec47938c4176af4d942cf6 rejected unsupported Do syntax
in the new implementation; the supported While traversal replaced it. The first
12-case fresh run 47bd6544a5e94d9a83aabf7593629094 passed, and the 17-case diagnostic
expansion 07dbd0cfc52b4e23b54e7621f1141e13 passed using its validated retained LLVM.
Run 4759fd2c05334d0b9eb35083fa16965b exposed the fixture's incorrect assumption
about function-result ByRef admission; its oracle now requires UBE1417.

Run 8550f9daf6934272847f4358ecab19ee exposed controlled UBE1509 on an omitted default.
Its retained default-diagnostic.c/exe isolated a literal child in caller module 0
whose original syntax belongs to declaration source 1. Discovery had required every
child to use the caller's source. The narrow correction accepts the checker's
cross-source pure literal while retaining source bounds and same-module validation
for other kinds. The default-byref-control case failed before that correction and
passes in the fresh report above. No checker or language behavior changed.

The optional -ReuseReport path is diagnostic-only. It validates the retained
project manifest, complete ordered compiled-source vector, tool cohort and raw
LLVM identities before rerunning native oracles. A copied retained-source mutation
(b6e3be26e2aa46d9aa65321c96e055d1) and the actual production correction against the
old report (8ee1365227b94c17a27df849768bad4b) both reject with zero commands launched.
This protects test evidence; it is not production source monitoring or locking.
The final c4f0 report uses fresh compilation with no reusedCompilation.

NativeDependencies is now the final source entry in the production manifest,
preserving the source order compiled by this gate. The fresh source gate is
registered in bootstrap/build-v2.ps1 with a 1200-second deadline. These focused
DiagnosticOnly results use historical qualified df158 tools on current captured
sources. The updated full bootstrap and final source-cohort gates have not run.
CLI/IDE warning delivery, runtime module initialization, real stack startup/frame
qualification and the complete native builder remain unfinished.

Final registration was checked with the following diagnostic reuse command:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/warnings/check-sources.ps1 -DiagnosticOnly -ReuseReport bootstrap/out/native-warning-sources/c4f0f07a56b740d4ac45426d4363e0cc/report.json
```

Report bootstrap/out/native-warning-sources/d5825fdcd0344e9abc18c8a36c2d0efe/report.json
passes all six groups using the identical validated compiled-source vector and
raw LLVM from c4f0. The harness now requires NativeDependencies in the production
manifest rather than appending it. This rerun verifies registration and native
oracles, not another fresh compiler invocation. The seven registered PowerShell
scripts parse without errors through bootstrap/out/check-native-registration.ps1.
A filesystem/schema assertion checks 13 unique existing Core entries, 54 unique
existing compiler entries, the source-gate registration/deadline and nonempty
passing report assertions. `rtk proxy git diff --check` exits 0 (only existing
LF/CRLF conversion notices). No gate session remains live.
