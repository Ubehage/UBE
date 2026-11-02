# First semantic checking evidence

## Qualified bounded semantic checker - 2026-11-02

First semantic checking is complete within SEMANTIC-CONTRACT.md's bounded
scalar/native MODULE scope. The checker, diagnostics, existing check command
and shared source-worker controller are production UBE code. Maintained gates
consume the actual production closure and real Core reference; OUT source
snapshots remain historical evidence rather than implementation dependencies.

Accepted source-built cohort: `88d1906a667645fa87f885c3a117e52f`.
Manifest SHA-256: `9C4BFED73CF3CF4C42A768B68B61A6C0F318D0E038EC64B66D30BDFEC75BFEB9`.
Its complete bootstrap passed 894 assertions. The final maintained reports are:

| Gate | Exact report | Asserted scope |
| --- | --- | --- |
| catalog | [bootstrap/out/semantic-catalog/qualification/31de05a6e56448448cc99a839f7bab34/report.json](../../bootstrap/out/semantic-catalog/qualification/31de05a6e56448448cc99a839f7bab34/report.json) | 337 aggregate checks; 13,897,579 native assertions and 5 rejected corruptions per stage |
| completeDefinition | [bootstrap/out/semantic-definition/56294e1fdc4a41478e3e4697a58239da/report.json](../../bootstrap/out/semantic-definition/56294e1fdc4a41478e3e4697a58239da/report.json) | 8,854 assertions and 13 corruption guards; OUT-only Definition copy; definition only |
| concurrency | [bootstrap/out/source-set-proof/47ba7f36064440edaf584f73eb04a5f2/report.json](../../bootstrap/out/source-set-proof/47ba7f36064440edaf584f73eb04a5f2/report.json) | Both stages: 8,440 assertions each; 49 units; jobs1/2/4; complete equality/sharing/failure/cleanup; unchanged-input audit |
| controller | [bootstrap/out/source-worker-slots-maintained/31646a5fda924e3c946a838a26ed45e1/report.json](../../bootstrap/out/source-worker-slots-maintained/31646a5fda924e3c946a838a26ed45e1/report.json) | 19 aggregate checks; 4,255 native assertions per stage |
| definition | [bootstrap/out/semantic-contract/0f594bdadfd24596b032776ea7f6a731/report.json](../../bootstrap/out/semantic-contract/0f594bdadfd24596b032776ea7f6a731/report.json) | 205 cases / 20 inventory entries / 31 corrupt controls / 29,437 assertions / 727 unchanged identities; definition only |
| docs | [bootstrap/out/docs-checks/bbf3ba0778b44d9aa1c8242491fd64f5/report.json](../../bootstrap/out/docs-checks/bbf3ba0778b44d9aa1c8242491fd64f5/report.json) | 5 tutorials and 35 API entries; static documentation checks passed for 274 HTML files; no browser/visual review |
| expressions | [bootstrap/out/semantic-expressions/09fede9dd70143a283fd6505781343fa/report.json](../../bootstrap/out/semantic-expressions/09fede9dd70143a283fd6505781343fa/report.json) | Both stages: 37 cases x Err 7/77; 1,403 assertions each; 2 rejected controls each; full streams/raw LLVM equal |
| formatter | [bootstrap/out/semantic-formatter/qualification/3200998ba75a494db4d2828b1f6bc10b/report.json](../../bootstrap/out/semantic-formatter/qualification/3200998ba75a494db4d2828b1f6bc10b/report.json) | 259 aggregate checks; 8,390,673 native assertions per stage |
| frontend | [bootstrap/out/semantic-inputs/f226268745944a17a1dee97f3b862b25/report.json](../../bootstrap/out/semantic-inputs/f226268745944a17a1dee97f3b862b25/report.json) | 6 exact expectations across 3 retained frontend cases |
| lifetime | [bootstrap/out/borrowed-lifetimes/1959a24773454ed68ad09a5ea945df29/report.json](../../bootstrap/out/borrowed-lifetimes/1959a24773454ed68ad09a5ea945df29/report.json) | 56 lifetime/root rows; unowned-borrow control exit 92; experimental root scope, no production-performance claim |
| localCli | [bootstrap/out/local-cli/22d7ebbccd5f4a91b87d374affd5c3d3/report.json](../../bootstrap/out/local-cli/22d7ebbccd5f4a91b87d374affd5c3d3/report.json) | 52 exact local artifact process checks |
| parser | [bootstrap/out/parser/8c513d9949054ba7b4732ec914bf1264/report.json](../../bootstrap/out/parser/8c513d9949054ba7b4732ec914bf1264/report.json) | 1,879 assertions |
| projectCli | [bootstrap/out/project-cli/5a34f470507645678baaa9bd36a8c552/report.json](../../bootstrap/out/project-cli/5a34f470507645678baaa9bd36a8c552/report.json) | 1,202 process assertions |
| semanticCli | [bootstrap/out/semantic-cli/0707a0d0161a413d9589e0d0a0fb3798/report.json](../../bootstrap/out/semantic-cli/0707a0d0161a413d9589e0d0a0fb3798/report.json) | Both stages and 6 native/resource children |
| sourceCli | [bootstrap/out/parser-cli/5525372d74f24d3cb7b1ea8cefd4b146/report.json](../../bootstrap/out/parser-cli/5525372d74f24d3cb7b1ea8cefd4b146/report.json) | 104 process cases |
| whole | [bootstrap/out/semantic-whole/6f214363e9b14e98a5748ce16c0ff4d3/report.json](../../bootstrap/out/semantic-whole/6f214363e9b14e98a5748ce16c0ff4d3/report.json) | 18 parent checks covering both stages; 112,392 resource assertions and 4 controls per stage; four-context 461 and 2 controls per stage; complete comparisons 14,196 assertions and 120 controls total |

The reports record exact commands, accepted source/tool/artifact identities,
controls and actual observations. Both source-built stages are required where
the gate makes a stage-equality claim. Complete expectations remain independently
authored; no expected answer was changed to match a candidate. The catalog
component identity handoff is
`bootstrap/out/semantic-implementation/catalog/maintained-handoffs/73193731212343d6a430300dd8fa4b47/report.json`.

The final independent [acceptance identity audit](../../bootstrap/out/semantic-implementation/statements/native/acceptance-audit/a44fd6809ce94b8888c39507211845ca/report.json)
passed for all 17 reports and 5,984 structured input/artifact identities, with
zero mismatches. Strict current-bootstrap verification passed before and after
the audit. The separate [documentation review](../../bootstrap/out/semantic-implementation/statements/native/final-doc-review.json)
passed the 13 status-document paths, original/candidate hashes, current scope
and reproduction procedures before the guarded copies were applied.

The first final concurrency attempt hit the unchanged 180-second fixture-emission
bound before native assertions, exit -1/timedOut true with empty streams:
`bootstrap/out/source-set-proof/3e538d58990d4e7ea46f1a3c104c28b9/report.json`.
The unchanged command was rerun after competing UBE compilations settled and
passed both stages; the failed report is retained rather than overwritten.

Definition consistency, actual semantic execution, process behavior and measured
costs are separate assertions. Four full contexts use distinct private catalogs,
outputs/budgets/failures over shared immutable source owners; fault/root/OOM and
old-result ownership gates pass. No semantic speedup claim follows from these
correctness/resource results. Earlier frontend performance acceptance retains
its own measured cohorts and numerical-policy limits.

Successful supported checks exit 0 with empty output and create no executable.
The full compiler and actual Core source still defer; full grammar, managed
language families, LLVM/native execution and a public compiler release remain
outside this acceptance. The next existing deliverable is First checked native
executable, starting with reviewed bounded lowering/backend/ABI/runtime-error
and tool-handoff contracts and independent native/failure oracles before code.

## Current reproduction procedures

Run from the repository root. The accepted source-built bootstrap was produced
with its full gate, without skipping proofs:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1
```

That command creates a fresh cohort and updates `bootstrap/out/v2/current.json`
only after its full acceptance gate passes. The final gate invocations below
use the accepted current selection, both stages where required, actual production
sources and default strict audits. They write new OUT reports. The dependent
report arguments shown are the exact final88d reports; when reproducing after
a new build, replace them with the corresponding newly emitted report paths.
Keep source inputs frozen throughout the set. Run the 180-second concurrency
emissions after competing UBE compilations finish; do not change its bound.

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-semantic-contract.ps1 -SelectionPath bootstrap/out/v2/current.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-semantic-whole.ps1 -SelectionPath bootstrap/out/v2/current.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-semantic-catalog.ps1 -SelectionPath bootstrap/out/v2/current.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/semantic/native/expressions/check.ps1 -SelectionPath bootstrap/out/v2/current.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-semantic-formatter.ps1 -SelectionPath bootstrap/out/v2/current.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-source-worker-slots.ps1 -SelectionPath bootstrap/out/v2/current.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-parser.ps1 -SelectionPath bootstrap/out/v2/current.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-parser-cli.ps1 -SelectionPath bootstrap/out/v2/current.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-project-cli.ps1 -SelectionPath bootstrap/out/v2/current.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-semantic-cli.ps1 -SelectionPath bootstrap/out/v2/current.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-semantic-inputs.ps1 -DefinitionReport bootstrap/out/semantic-contract/0f594bdadfd24596b032776ea7f6a731/report.json -CliReport bootstrap/out/semantic-cli/0707a0d0161a413d9589e0d0a0fb3798/report.json -SelectionPath bootstrap/out/v2/current.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-local-cli.ps1 -CliReport bootstrap/out/parser-cli/5525372d74f24d3cb7b1ea8cefd4b146/report.json -SelectionPath bootstrap/out/v2/current.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-concurrency.ps1 -SelectionPath bootstrap/out/v2/current.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-borrowed-lifetimes.ps1 -SelectionPath bootstrap/out/v2/current.json
rtk proxy powershell -NoProfile -File docs/assets/tools/check-development-examples.ps1 -LocalCliReport bootstrap/out/local-cli/22d7ebbccd5f4a91b87d374affd5c3d3/report.json -SelectionPath bootstrap/out/v2/current.json
rtk proxy powershell -NoProfile -File docs/assets/tools/validate-docs.ps1
```

The complete representative validator is definition-only. It writes
`resolved.json` beside its Definition, so validate an OUT copy to preserve the
maintained fixture. The retained final procedure also compared every maintained
complete-fixture byte length/SHA-256 before and after:

```powershell
$fixture = 'compiler/UBE_Compiler_v3/tests/semantic/native/complete'
$before = @(Get-ChildItem -LiteralPath $fixture -File -Recurse | Sort-Object FullName | ForEach-Object { $_.FullName + ':' + $_.Length + ':' + (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash })
$definitionDirectory = Join-Path 'bootstrap/out/semantic-definition' ([guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory([IO.Path]::GetFullPath($definitionDirectory))
$definition = Join-Path $definitionDirectory 'complete.json'
[IO.File]::Copy([IO.Path]::GetFullPath((Join-Path $fixture 'complete.json')), [IO.Path]::GetFullPath($definition))
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/semantic/native/complete/validate.ps1 -Definition $definition
if ($LASTEXITCODE -ne 0) { throw 'Complete definition validation failed' }
$after = @(Get-ChildItem -LiteralPath $fixture -File -Recurse | Sort-Object FullName | ForEach-Object { $_.FullName + ':' + $_.Length + ':' + (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash })
if (Compare-Object $before $after) { throw 'Maintained complete fixtures changed' }
```

The semantic whole parent invokes its complete graph, worker overlap, resource,
cost, project and four-context children; semantic CLI invokes its process/fault
children. Their parent/child reports supply the detailed assertions rather than
requiring a second manually assembled checker implementation. Static docs
validation checks HTML/source/link consistency only; no browser or visual review
was performed for this record.

## Historical implementation and prerequisite records

The following reports retain their original source/tool/artifact identities and
then-current limitations. They are not substituted for the final reports above.

The preceding accepted `ffba5d8dadeb476c828fd0de249d0e24` cohort passed its full
894-check bootstrap and the owned expression, concurrency, lifetime and complete
definition gates. Their preserved reports under `bootstrap/out/` are respectively
`semantic-expressions/2c5f19faca7e402783844ea6ba31e684/report.json`,
`source-set-proof/4e6010fd67684537acae9b2d0958863d/report.json`,
`borrowed-lifetimes/3d820aed0387466bbdb196b28887b8f6/report.json` and
`semantic-definition/05435baae7f34332a71c10e82d6c21e1/report.json`.
The earlier independent Calls/native/duplicate snapshot remains at
`semantic-implementation/calls/native/complete-final/ffc2e5bfcc944396bf9a946369484da6/report.json`,
and the four-context snapshot at
`semantic-implementation/calls/native/four-context/runs/f94745687dc54b02837e6c77f5978d03/report.json`.
Each qualifies its original inputs only; the final maintained gates supersede
them for current acceptance.
The following prerequisite records are historical and retain their original
scope and source cohorts:

- Historical parser detail gate: `rtk proxy powershell -NoProfile -File
  compiler/UBE_Compiler_v3/tools/check-parser.ps1`, 1,879 maintained assertions
  passed for source cohort04c, including all 200 cases, both stages, exact
  detail trees, real resource failures/capacity sweeps, lifetime/sharing and
  measured costs. Report:
  `bootstrap/out/parser/eee096abee4d4e85bd22a7fbd9399ec2/report.json`.
- Retained source CLI: `rtk proxy powershell -NoProfile -File
  compiler/UBE_Compiler_v3/tools/check-parser-cli.ps1`, all 104 process cases
  passed for cohort04c. Report:
  `bootstrap/out/parser-cli/64d7994dd8d14fe4a52169f8529486b7/report.json`.
- Historical definition-only gate: 205 cases, 20 inventory entries, 20 negative
  controls, 23,914 assertions and 541 unchanged identities. Report:
  `bootstrap/out/semantic-contract/72b452c82f23455184030b9aa7786273/report.json`.
  This is independent expectation/source consistency, not semantic execution.
- Focused numeric prerequisites found missing LongLong arithmetic emission and
  unchecked signed-minimum negation in both bootstrap stages. The actual
  reproductions are recorded in Progress.md and v2
  `tests/wide-integers/CONTRACT.md`. A narrow checked-machine-arithmetic repair
  and independent native boundary fixture are now in the bootstrap rebuild at
  `bootstrap/out/v2/281e3cb01f86415793da82acd8d13c2c/`. The whole gate passed
  793 acceptance assertions and selected that cohort. Its eight focused checks
  include 79 native value/Err cases per stage. Cohort04c reports qualify
  their preserved inputs, not the changed runtime/v2 source.

Those prerequisite reports alone did not qualify the checker. Implementation,
source/test promotion and final exact-cohort acceptance followed. Their current
qualified result and local replay are recorded above.
`SEMANTIC-PROBES.md` retains the preset foundation bounds.

## Earlier preparation snapshot

Date: 2026-11-01. Status: **review in progress; checker unimplemented**.
Subsequent status: the owner approved implementation and started that goal.
The results below qualify the preparation snapshot. The later detail/native
qualification is recorded above; its current next action is in Progress.md
and SYNTAX-DETAILS.md. Refresh the source/tool cohort before implementation claims.
The owner requested this preparation goal after the qualified parallel frontend.
That preparation changed no production UBE/bootstrap/runtime code, project
manifests or existing tests. Implementation changes followed under the approved
goal. No commit or push was made.

The owner accepted the foundation-first/basic scope without requiring it to be
asked again. VB6 is the default for ordinary choices unless an established UBE
definition conflicts. Subsequent clarification confirms that literals must fit
their selected types, widening beyond a narrower destination if necessary, and
that scalar initialization is an ordinary assignment after neutral storage is
declared. Added independent cases cover 40000 - 10000 in initializer/split
forms, initializer self-reference, and storage surviving runtime failure.
The owner confirmed rejection of provable faults, including known final overflow
in ordinary initializers/assignments, and required literal-only integer arithmetic
to reduce to typed constants during compilation at every optimization level.
Cases require folded 30000, reject known final overflow/division by zero, and
cover a literal subtree inside a runtime expression. Runtime-dependent failures
retain the existing Err rules; this behavior question is resolved.

## Review package and completion audit

| Goal requirement | Artifact and evidence | Limit |
| --- | --- | --- |
| Inventory actual retained declaration/header/parameter/expression information | `SEMANTIC-SYNTAX-INVENTORY.md`, 16 function-local entries in `tests/semantic/inventory.json`; definition report resolves current evidence lines/hashes | Source audit, not proof of a new published field |
| Identify required syntax extension without implementing it | Inventory table and sequencing; explicit `State.Count = SavedCount` evidence for discarded validation nodes | Existing parser only; no second parser or representation chosen |
| Exact bounded checking scope and normative authority | `SEMANTIC-CONTRACT.md` sections scope through boundary | Whole-language checking and the actual full UBECore remain unavailable |
| Independent binding/type/constant/call/diagnostic cases with original spans | 205 authored cases in `tests/semantic/cases.json`, schema/domain/span checks and deliberate corruptions | Targeted observations; no semantic answers executed or inferred from the compiler |
| Primitive/native-type and library boundaries | Native declaration/nominality/Pack/Unpack and explicit small UBECore reference cases; source inventory and contract | No hidden type-name implementation or shared-library ABI qualification |
| Failures, atomic publication, lifetime and deterministic private body work | Contract publication/concurrency/resources/costs and 12 explicit future native obligations | New native fault, worker and performance tests cannot pass before implementation exists |
| Preserve qualified current input path | Unchanged accepted source/artifact audit; retained parser definition gate; both existing frontend CLIs admit the independent sources exactly | Source admission is not semantic checking or project binding |
| Owner-confirmed literal behavior | Updated `lang-doc/language-spec.md` section 4, conversion table and public Types article; independent contextual/default/suffix/range cases | Precise bounded context propagation remains in the review proposal; other domains stay deferred |
| Resumable handoff | Root Workplan, compiler Roadmap/Progress/README, development plan and navigation link | Review comes before production implementation |

Read the contract and the inventory together. The most important dependency is
that parameter/default/result/declarator/attribute detail is not yet published
by today's parser. Presence of original source bytes does not remove that gap.

## Executed definition gate

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-semantic-contract.ps1
```

PASS: **205 cases, 16 inventory entries, 20 intended negative controls,
23,747 definition/audit assertions, 540 unchanged input/artifact identities**.
Every symbolic semantic, deferred and frontend diagnostic class has an
independent case; every contract rule has cases or explicit future obligations.
The controls reject undefined rules/types, absent spans/owners/bindings, incorrect
call maps/order/modes, wrong coordinates, duplicate identities, malformed outcome
records, impossible expected constant values and stale source inventory evidence.

Report: `bootstrap/out/semantic-contract/fff1916951194a758544410de593646b/report.json`
SHA-256: `FA542A9A0347C0246ABA5B64C5BC6DAE0242D6A0FEC3220B8DBBD6137012708C`.

Corpus SHA-256:
`9C9E4C52DFCC7C487A87E60612EE71F14079872DF9B3524051361A2B7E85C571`.
Expected answers were explicitly authored; no UBE evaluator/compiler generated
their bindings, values or diagnostic choices. The gate resolves exact substrings,
contexts, EOF/point positions and an independent BOM/CRLF/tab/supplementary-scalar
coordinate control. It checks expected value representability, not expression
evaluation. It does not parse UBE or prove that a semantic expectation is correct.

## Executed frontend admission gate

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-semantic-inputs.ps1 -DefinitionReport bootstrap/out/semantic-contract/51667438e510476c94d4420306be1a77/report.json -CliReport bootstrap/out/parser-cli/8223b27728b84529adda41b9a0f95a45/report.json
```

PASS: **205 cases / 224 independent source snapshots / 448 exact native process
outcomes through both qualified CLI stages**. Predictions were fixed before
running: ordinary semantic fixtures reach the existing checking-unavailable
diagnostic; intentional invalid syntax, conditional input and unknown reserved
attributes retain their earlier exact diagnostics and coordinates. Every process
has the predicted exit/stdout/stderr; no new semantic implementation is involved.

Report: `bootstrap/out/semantic-inputs/78d60a09c7e5430f8f3feb02d53cf557/report.json`
SHA-256: `00D19FD74017DBEACD13580311F33AE6BA8FA94200207BC936ADE75062B35B79`.
Its corpus hash is the same one audited by the final definition report above.
This admission run pins the same current corpus. The final definition run adds
explicit future-native folding-obligation wording; neither source expectations
nor frontend executables changed. Earlier 197/201-case admission reports remain
historical preparation evidence, not qualification of the expanded corpus.

The CLI report selects source-built stage artifacts:

- Stage 1: `35B43C1DCC640C9CDE151A132396564FDB482C312C4A224D4F7FF7873D943A02`.
- Stage 2: `DE958D267C85E4B701BA6D1055879CF40F128E629B44A5C61FC020FF1EBC07AA`.

These executable hashes differ; no byte-identical executable claim is made.
The unchanged qualified source cohort is `2c0fb05a3c4b4912861db33043acdb40`,
manifest SHA-256 `2D6B6082C7647DE7D380BEB35C1FAFB057A312F6056C0A9D552CC7E540772D51`.
Its 785 source assertions are audited recorded passes, not rerun here.

## Retained definitions and public documentation

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-parser-contract.ps1
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File lang-doc/tools/validate-grammar.ps1
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File docs/assets/tools/validate-docs.ps1
rtk proxy git -c core.safecrlf=false diff --check
```

- Parser definition PASS: 116 cases, 16 negative controls and 11,969 definition
  assertions; complete accepted 785-check cohort audited unchanged. Report:
  `bootstrap/out/parser-contract/f9960769dc7d4952929fc3c217c64a06/report.json`,
  SHA-256 `07838227DA5956B7C16992D940855EEA9E6E9A02090BE2AC9B7296FF0CA34B21`.
- Grammar PASS: 202 core and 19 conditional productions. No EBNF phrase
  structure changed for this semantic literal rule.
- Documentation PASS: 265 HTML files with the maintained offline structural,
  navigation, relative-link/asset and catalog checks. No new route/style/script.
- Git whitespace check PASS. The focused package review below passes 92
  whitespace/conflict-marker, new PowerShell syntax, review-link and exact
  corpus/cohort checks. A scoped Git diff confirms no production source,
  runtime or project-manifest changes.

```powershell
rtk proxy powershell -NoProfile -File bootstrap/out/review-semantic-package.ps1
rtk proxy git diff --exit-code -- compiler/UBE_Compiler_v3/src std-lib/src bootstrap/runtime bootstrap/src compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE std-lib/UBECore.UBE
```

The ordinary documentation/grammar script invocations initially failed an
AuthorizationManager check. The listed process-only execution-policy argument
allowed those repository-owned validators to run; no user/machine policy changed.
The first authoring/tool-integration attempts also exposed a missing JSON helper
and a dropped zero-valued fixture field; both were corrected before the complete
successful definition rerun. The manual span review corrected an ambiguous
one-letter anchor, and source-envelope inspection kept the unknown reserved
attribute case in its existing frontend category. No production bug was changed.

Direct local-browser verification was attempted with `cua.getState()`; the
browser access host and native pipe were unavailable. Rendering/interactions
and the manual's larger accessibility/browser release matrix remain unverified.
The locally maintained `docs/ROADMAP.md` logs that limitation; that existing file
is ignored by `/docs/*.md`, so the tracked handoff here also preserves it.

## Review decisions and exact next action

The owner-confirmed rule is destination typing through arithmetic, with wider
types when needed to hold the literals, and default Long then LongLong. A scalar
initializer is an assignment after declaration. Review the proposal's precise
propagation boundaries: nested
calls use their own parameters, comparisons/bitwise contexts use defaults, signs
and Group nodes preserve original syntax, and explicit suffixes win. Suffixed
signed minima and hexadecimal/octal signed patterns are explicitly deferred.
No noninteger operator behavior is silently settled.

Also review the bounded scalar/native-value/call scope, declaration-first error
ordering, deferred local-before-declaration lifetime case, proposed caller budgets
and separate diagnostic integration. No storage/lookup representation or public
phase API has been selected; cost constants require measured native probes first.

After owner approval, implement and independently qualify only the inventoried
detail extension in the existing parser, with its prior projection and all
retained gates preserved. Then run reviewed semantic storage/lookup probes before
production checker implementation. Future native obligations remain unexecuted,
and complete representative semantic streams still need independent authoring
before their native gate. No new executor, semantic/backend implementation,
executable-output feature, architecture or push is authorized by this handoff.
