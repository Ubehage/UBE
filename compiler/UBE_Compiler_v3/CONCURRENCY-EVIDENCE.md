# Compiler-concurrency evidence

Date: 2026-10-31. **Completed: the owner-requested bounded concurrency contract,
bootstrap prerequisites and real UBE compiler-consumer proof.** The final accepted
cohort and exact results are recorded in the final section below. Earlier
sections preserve chronological diagnostics, failed test assumptions and
interrupted attempts; their then-pending statements are historical.

The acceptance definitions are [CONCURRENCY-CONTRACT.md](CONCURRENCY-CONTRACT.md),
[CONCURRENCY-BOOTSTRAP.md](CONCURRENCY-BOOTSTRAP.md) and
[CONCURRENCY-CONSUMER.md](CONCURRENCY-CONSUMER.md). Qualification is limited to
those contracts; it is not complete grammar, class/thread semantics, semantic
checking, code generation, project CLI integration or a production speedup.

## Historical initial diagnostic tools

Both stages come from `bootstrap/out/v2/e4cccaa2e5d54163866f2ca3853935d2/`.
The accepted manifest SHA-256 is
`A85116D74DD8DCD2908144F00FF477D325503CDFD307006A9EC4ACD2C1000A9B`.
This is the 501-check foundation used by the qualified bounded parser, not a
new thread/capture/reference qualification. Reports pin selected executable,
runtime and Clang identities. No archived compiler executable was used.

## Actual UBE syntax/value probes

Procedure:
`rtk proxy powershell -NoProfile -File bootstrap/out/probe-concurrency-prerequisites.ps1`.
Capture: `bootstrap/out/concurrency-prerequisites/e4d45fe8a81d489a80d69ee2d3285861/report.json`.
The generated fixtures, paired compile results, native runs and LLVM identities
are retained there. Every subprocess has a finite bound. No production source
was changed for these observations.

| Probe | Both-stage result | What it establishes |
| --- | --- | --- |
| Ordinary scalar `Call RunWorker(7)` | Compile/link/native success, exact stdout `7` plus newline | A supported normal-call control |
| Statement `CallNew RunWorker(7)` with ByVal formal | Compile/link/native exit 0, empty stdout | Suspected omitted work, not thread success |
| Managed record ByVal call | Exact native stdout `99` then `7` | Callee mutation does not mutate caller array |
| Object ByVal parameter | Exit 1, UBE3213 `unknown parameter type: Object`, no LLVM | Existing bootstrap does not admit this reference path |
| Module-level byte array used by Main | Exit 1, UBE3100 undeclared assignment target, no LLVM | Module storage is not an available shared-context shortcut |

The CallNew diagnosis was narrowed by comparing emitted LLVM: the ordinary
control calls `@ube.p0(i32 7)` from Main; the CallNew image defines the worker but
contains no worker invocation and no thread-start call. This distinguishes silent
omission from an asynchronously started worker simply outliving Main. Both stages
agree. `ParseBasicStatements` has no CallNew branch and drops a non-assignment
identifier statement, matching that observed behavior. A focused correction and
maintained regression are required before any bootstrap thread claim.

An initial four-case capture without the Object probe is retained at
`bootstrap/out/concurrency-prerequisites/2a86d75f9cec4df6b926c318f9fb4a35/report.json`.
It is earlier diagnostic evidence, not a different qualification result.

## Actual managed ByVal copy costs

Procedure: `rtk proxy powershell -NoProfile -File bootstrap/out/measure-capture-copy.ps1`.
Capture: `bootstrap/out/concurrency-copy/bdcd5498ad354f13924867bfd9269864/report.json`.
The native adapter calls the intact actual UBE `ReadCopy` procedure, with the
checked emitted BytePacket ABI. The full current runtime uses its existing
test-only payload-copy observer. Only an exported wrapper/platform-main rename
and observation differ. C supplies independent assertions, not workers or a
replacement implementation of UBE copying.

| Byte-array elements | Actual payload bytes copied per ByVal call, each stage |
| --- | --- |
| 1 | 1 |
| 64 | 64 |
| 1024 | 1024 |
| 16384 | 16384 |

All eight measured calls returned 99, preserved every caller byte and seeded
Err77, and left zero live GC payload after test roots were released and collection
ran. The numbers are observed runtime copies, not calculations substituted for
instrumentation. Passing SourceDocument-like records ByVal cannot qualify as
zero-copy immutable input sharing.

## Source-kind reference probe

Procedure: `rtk proxy powershell -NoProfile -File bootstrap/out/probe-reference-prerequisite.ps1`.
Capture: `bootstrap/out/concurrency-reference/60bfce11c57f4873b14ceffcebc3f084/report.json`.
A normal `.UBE` project includes a native CLASS with a public Byte-array field
and a MODULE that passes the instance ByVal and reads its mutation. Both tools
reject at UBE5009, before class semantics: `NormalizeProjectSourcePath` admits
only `.bas` source extensions. The probe does not diagnose a class-layout bug or
prove reference semantics; it identifies an earlier admission prerequisite.

## Decision and remaining proof

The owner approved existing-language reference-class support plus actual
CallNew/wait/cancellation (option 1). The class data/context and compiler
work stay in UBE. Reusable thread mechanisms remain in UBECore with only explicit
irreducible substrate bindings. Layout/API selection and any bootstrap extension
must be bounded and independently tested first.

Reference prerequisite implementation has started against the prewritten bounded
contract in `CONCURRENCY-BOOTSTRAP.md`; it is not qualified yet. No production
scheduler or public thread primitive is qualified. No 1/2/4-worker acceptance, compiler-parallel speed/copy claim or
broader semantic/backend claim follows from this diagnostic record. Generated
procedures currently describe the captures above; maintained reproduction and
before/after regressions are part of the still-active goal.

## Retained silent-omission correction

The maintained fixture is
`../UBE_Compiler_v2/tests/concurrency/callnew-statement.bas`. Its check rejects
successful compilation without an actual `ube_thread_start` call and native
worker output. An exact unsupported-feature diagnostic is a safety pass only;
`-RequireNative` rejects it. The ordinary-call control must still print 7.

The old accepted stages failed that test at
`bootstrap/out/thread-statement/e44a902fb353464f9e1905b0fcfbbf64/report.json`.
The focused source-built before/after reproduction is
`bootstrap/out/thread-statement-fix/260b9b9eae7d4c4c806956b4f8fcbcf2/report.json`,
SHA-256 `EF1B170F2D4FEB7AF56740607032D7D3B54BDE1986F9C71DF41513DE2CB53A2F`.
Both candidate stages emit UBE2240 at (12,5), exit 1 and publish no LLVM.
Their raw self-compilation LLVM agrees. The separate native-required negative
control also rejects the unsupported diagnostic, as intended.

`rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1` then completed
the full 501 grouped checks (136 core plus 13 child proofs), selecting
`bootstrap/out/v2/9b100f5c9fd0484db67f7f5bac5cb261/manifest.json`, SHA-256
`346C2E1F9304C4A504E1ABA3A29E570E0F75E200ECE3B85349B39193BF93351C`.
The manifest reports success and records all input, tool, stage and child-report
identities. This qualifies the omission guard and retained foundation scope.

`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v2/tests/concurrency/check.ps1`
passed all four statement/control checks against both selected stages:
`bootstrap/out/thread-statement/d6202949f370443fabdf22faa754a9f0/report.json`,
SHA-256 `654EDD7766E9A3B81A040BF2BD8D8020F72C3ACCB590CD78BA6BD5953603868E`.
Its native-statement flag remains False. Subsequent reference/runtime source edits
are beyond this accepted cohort and require fresh qualification; the previous
parser reports remain historical evidence until rerun for the final cohort.

## Bounded reference implementation controls

The implementation now admits field-only native CLASS sources and their existing
identity/Set/New/Nothing/Is behavior. Inline record/array value rules remain intact.
It uses the existing shared-reference value layout, checked roots and caller-rooted
managed result ABI, with atomic allocation/publication into private rooted slots.
This is a bootstrap prerequisite, not full class conformance or fresh-v3 CLASS parsing.

`rtk proxy powershell -NoProfile -File bootstrap/out/build-reference-candidate.ps1`
produced three source-built candidate stages and compared stage-two/stage-three
raw compiler LLVM. The comparison passed. Capture:
`bootstrap/out/reference-candidate/1bcc0b83091f4e278b16ce495bb2364a/report.json`,
SHA-256 `AB44C7DAF9A07AF4CACEB519008604EBFA73FB8C1AD5A52AFEFBDD96A42961F0`.
The earlier two-output comparison correctly failed because the old producer lacks
the new backend declarations; it did not establish a fixed point.

`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v2/tests/concurrency/check-references.ps1 -CandidateDirectory bootstrap/out/reference-candidate/1bcc0b83091f4e278b16ce495bb2364a`
passed the paired native output oracle, actual-runtime observer and 22 negative
compilations (11 cases through both stages). Capture:
`bootstrap/out/reference-storage/1683b87713dd4ac8b1cd49d9799c2413/report.json`,
SHA-256 `A2788791CE9717A6FC717EA52B33CE9BCF8A8DA0311D89F57D031CEAE71AACFA`.
The UBE controls cover identity across ByVal calls, private parameter reassignment,
independent record/array slots with shared reference leaves, explicit ByRef slot
changes, cyclic references, neutral values and managed returns. Raw fixture LLVM
agrees between stages.

The independent C observer invokes intact emitted UBE procedures and includes the
actual runtime. Persistent managed-allocation denial returns Nothing/Err7;
collection preserves rooted results and reclaims their cycles after replacement.
Neutral member access returns zero/Err91 without dereferencing null. Real root
registrations fill the 1,048,576-entry capacity. CreateOwner preserves the old
result and returns fresh Err7 at capacities 0 through 11, succeeds with capacity
12, and restores the baseline registration count. Releasing the last test root
and collecting leaves zero roots and live payload. These are executed assertions,
not inferred counts. Thread capture, full earlier gates and final-cohort parser
qualification remain pending; current.json still selects the omission-fix cohort.

## Actual UBE thread prerequisites in development candidates

Typed compiler-generated callbacks now invoke actual UBE Subs. Checked admission
issues an ID only after native TLS and the Sub's checked root/value prologue
succeed. The existing rooted native capture allocation/destruction is reused;
ordinary array/record copying remains independent. The reusable declarations and
Windows adapters are in UBECore's `Threads.bas` and `thread_primitives.c`, under
`std-lib/THREADS-CONTRACT.md`. Source work and scheduling are not in those files.

The native-required statement/control procedure passed through two development
stages at `bootstrap/out/thread-statement/3cf9627fc3114c6cadf705c0187e3433/report.json`,
SHA-256 `375218D7B128E4EEFDFA4934373CF2112C2ED69ED32AC990B4A4101BF08C37D6`.
This proves actual scalar CallNew execution, not shared compiler work.

Procedure:
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v2/tests/concurrency/check-thread-references.ps1 -CandidateDirectory bootstrap/out/reference-candidate/74d021cf657e48858e1ea6815bed297b -Stages 1`.
Capture: `bootstrap/out/thread-references/f1050e24278a4471817663e106dd3f90/report.json`,
SHA-256 `1C753971AD65692929314EAE3C078A709BE1BA295025493DCE928BABD2D61AE1`.
This is one development stage, not paired final-cohort acceptance.

The ordinary UBE program checks stop/wait/timeout, exactly-once left-to-right
argument evaluation, mixed scalar widths, ordinary calls to a thread-target Sub,
and a zero-argument statement start that completes before program exit. The C
observer calls intact emitted UBE procedures; it supplies no worker implementation.
Growing Byte-array lengths 1/64/1024/16384 produce exactly eight observed capture
payload bytes and zero runtime array-payload copy bytes. The actual UBE ByVal-array
positive controls copy exactly 1/64/1024/16384 bytes respectively. A mixed capture
also preserves Double 3.5 and a LongLong with a nonzero high 32-bit part.

The observer removes all caller/creator roots while an actual UBE worker retains
the cyclic source owner, collects, restores its observation root, then stops and
joins. Actual calloc denial, native start denial, worker TLS allocation denial,
wait registration denial with the same stale Err7, and real exhausted root
registrations all produce the expected fresh failures. Failed admission executes
no user body, issues no ID and drains capture ownership. The first successful
root capacity is 13; earlier capacities include an observed worker-prologue
rejection after native record creation. Final test-owned roots, GC payload,
captures, records and handles return to their initialized baseline. Worker Err91
remains isolated. Thirteen unsupported capture/signature cases reject with no LLVM.

These results do not qualify scan/parse scheduling, full class/thread semantics,
all numeric operations or the final tool/source cohort. The expanded bootstrap
gate now retains these prerequisites alongside every previous child proof.

## Focused regressions found by the prerequisite checks

Denied callback-event allocation terminated ordinary managed initialization at
exit 70. The retained synthetic procedure is
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v2/tests/concurrency/check-gc-initialization.ps1`.
Before capture with `-ExpectFatal`:
`bootstrap/out/gc-initialization/2984cee8a09b4c659bf81c83255d36b0/report.json`,
SHA-256 `9F16FC6E33BA7AF0E8DF502891118709C21E41881EFEF6BD49684FD43F7FABFD`.
After capture:
`bootstrap/out/gc-initialization/b714e3e85d414117ad73d0b9aef362e0/report.json`,
SHA-256 `3059CE9A2265E51408ADFAA4AE80FDCD94CE757FAD0B0C5DDA7BF2A67BCC0C82`.
The collector lock now initializes without an unrelated callback event; event
acquisition belongs to actual component-source admission, which returns Err7 and
releases its bookkeeping/pin on denial. The after test checks ordinary managed
allocation, preserved incoming Err, controlled source rejection and zero residue.
This uses the maintained host's existing Vista-or-later API baseline:
[critical-section initialization](https://learn.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-initializecriticalsection)
succeeds on that baseline, and an always-successful
[one-time initializer](https://learn.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-initonceexecuteonce)
publishes it to all callers. No fallible event acquisition remains in that callback.

`check-scalar-output.ps1` retains a small before/after case for LongLong output
using an i32 ABI and Double neutral slots using an integer LLVM constant. The
before oracle passed at `bootstrap/out/scalar-output/155d48dbf817456b8fba7521129bbd9f/report.json`,
SHA-256 `32868D33A9A3F8E58F35CACD0587AAC4AAD976FC9843A695B76B26990DF71AC1`;
the native after oracle passed at
`bootstrap/out/scalar-output/04979625232a4a6f9072c1f93ff9fb83/report.json`,
SHA-256 `52B70F171F4F11FFCCB8A265BDFFF163D245E8A99AADCCD5EEAC4AFEF5396E0F`.
These narrow corrections preserve the actual scalar widths rather than emitting
ill-typed LLVM. They do not establish general floating-point semantics.

`check-reference-order.ps1` retains a MODULE followed by CLASS, leading class
trivia and a preceding file without final newline. The before case incorrectly
rejected at UBE5029 because a synthetic separator became the class header anchor:
`bootstrap/out/reference-order/49dc96a18fb24c6e92b746914d5a145d/report.json`, SHA-256
`1C5C2069DF0EB5D6C45869092DB2061E9D7C72C0CF19AB9C28814D3A535D0FF8`.
Skipping only separator tokens before the actual source start preserves original
bytes/anchors and passes the full native value/reference oracle:
`bootstrap/out/reference-order/8febefd3d409486fb4d91070641659c1/report.json`, SHA-256
`737E12B3757832A66165E33FAF581B5A93E2B52A025C073ECE3E8E3FB7D2E687`.

## Preserved stack-capacity regression

The expanded source gate reproduced native stack overflow on ordinary bounded
expressions, including a 64-operand chain and earlier 96/128 boundary cases.
The PE stack remained its original 1 MiB; raising it or lowering the existing
128-expression bound would not establish the required behavior.

The maintained synthetic gate is
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v2/tests/concurrency/check-expression-stack.ps1`.
The retained before capture reports 11 native stack faults:
`bootstrap/out/expression-depth/265be8455dce4f32aefa153b82d39114/report.json`,
SHA-256 `A98E4A8F0805B253FDD83B8E433B07C6D73F84ED64DB048DDE5C6E89E9FE728E`.
The after capture passes all 28 paired-stage groups:
`bootstrap/out/expression-depth/c9a8612a1ee344c09bd091939d30d4ae/report.json`,
SHA-256 `EFA698491B8969E237921BC221E77665E5B51710032910456F9833B2FC2495D1`.

Type resolution and eager unary/binary emission now traverse explicit bounded
frames. Argument and operator emission use smaller domain helpers; prefix parsing
does not recurse once per unary token or repeated malformed CallNew. The tests
retain accepted constants/variables, nested calls, parentheses and unary prefixes,
combined limits, reference links and controlled over-limit diagnostics. Production
names describe their operations rather than the work session.

## Accepted prerequisite cohort before coordinator integration

Procedure: `rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1`.
All 592 grouped assertions passed, preserving the earlier 501 and adding the
bounded reference/thread and focused crash/regression gates. Both source-built
stages and the LLVM fixed point passed.

Capture: `bootstrap/out/v2/db5cd09e8dd7403f9279e1dc9a333ded/manifest.json`,
SHA-256 `2D3D30772659CBC27AD9D12F674CC52732487FA93721D6436A4AA41EA08A54A2`.
Stage-two executable SHA-256:
`2C3AA854E185B6421A1A760BE4E3EF6C712885DAEDD746A3BBCB756FD9C3BD01`;
runtime object SHA-256:
`4F411C5D14CCE467E4F3663D0C82A8B35436BD081847A5B5EDD4D5AE7AA015FB`.
This cohort qualified the prerequisites. Adding the compiler-owned coordinator
changes pinned source inputs and requires a fresh complete source-cohort gate.

## Compiler consumer development

`SourceOwner`, `SourceWork`, `SourceCancellation` and `SourceParsing` belong to
the compiler. UBECore owns only the generic managed storage and fresh thread
observations. The owner-approved contracts preceded this representation and its
UBE coordinator. The normal production CLI has not gained project compilation.

The retained development capture
`bootstrap/out/source-set-proof/b40a9bddfdf64f8daae31fb016856070/report.json`
contains complete 1/2/4-worker graph/token comparisons, shared-token UBE parser
workers, independent simultaneous UBE coordinators and failure cleanup. A later
boundary assertion in that development run failed: a flat fixture correctly
accepted zero nesting depth. The focused test now uses an actual nested If.
The scanner's existing domain/budget distinction is preserved: nonempty token
limit zero yields unit207; limit one exercises unit206. No parser/scanner rule
was changed to satisfy either mistaken test expectation.

Focused maintained diagnostic procedure:
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-concurrency.ps1 -DiagnosticOnly -DiagnosticRawPath bootstrap/out/source-set-proof/b40a9bddfdf64f8daae31fb016856070/stage1/raw.ll -DiagnosticSuite faults`.
Capture: `bootstrap/out/source-set-proof/9f48e46784894c529495f1b2eb5ed086/report.json`.
It passes 76 assertions, including actual publication/root and worker-root
denial, and explicitly records `qualified:false`. Reused LLVM does not establish
current source-built equivalence.

The acceptance audit additionally requires complete first-error span comparisons,
distinct native worker identities, exact structured fault kinds, a separate
measured 8N publication-copy count, and nonempty token-zero/one-source-budget-four
witnesses. These are assertions of the original contracts, not relaxed limits.
Final qualification remains pending until the maintained full gate and earlier
parser/CLI gates pass against one unchanged accepted source/tool cohort.

## Earlier-gate integration corrections

Two complete source-cohort reruns also passed 592 checks, including coordinator
sources: `bootstrap/out/v2/d5d011717b4f4b5c86e594a7af3d404d/manifest.json`
(SHA-256 `7FB7040C1A051EB3B1E68F9FBAF644C3734119CDE3B1B9D7EE44AE72EC05BDE1`)
and `bootstrap/out/v2/3b4fe4693fd8467ebe4173336198439f/manifest.json`
(SHA-256 `02467198A4A21620E12078CC2CEE9996178599E8445DEEF2505DB2321AE0DE0A`).
Neither by itself qualifies the final consumer or the later harness corrections.

The first strict parser rerun stopped in the definition harness because it
required exactly the historical 501 checks/13 children. Capture:
`bootstrap/out/parser/c4cbc6206bc5401f9f93e521c9c49dd9/report.json`.
The harness now retains all original named child counts and explicitly adds the
seven approved prerequisite proofs: exact core 136 plus all 20 named children
equals 592. It still checks every passed assertion, source/tool/artifact identity
and child cohort. It does not reduce a threshold or accept an arbitrary count.

The first strict CLI rerun reached its diagnostic adapter, which assumed record
types began at zero. The three reference classes reserve those type slots before
all records. Capture:
`bootstrap/out/parser-cli/c50b68bd39994cec8b1fa34d69ac3e6c/report.json`.
The adapter now includes CLASS files in its source closure and maps their actual
native identities first; exact signatures and record-field assertions remain.
No production diagnostic behavior changed. The subsequent procedure
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-parser-cli.ps1 -DiagnosticOnly`
passes 82 exact CLI cases and 27 diagnostic controls per stage, 216 assertions and
identical raw LLVM:
`bootstrap/out/parser-cli/2010c6e63a5c4ccb82e567a2d19ddb22/report.json`,
SHA-256 `38132CAFC7A496DF31C47FA699FE6518164A56E01BD858F84873B9236F20C032`.
This remains diagnostic-only until the corrected source cohort and strict gate
pass together.

The in-progress consumer capture
`bootstrap/out/source-set-proof/ac039b5314c5489b9018355c4d805f8b/report.json`
was deliberately interrupted after those integration failures so the complete
qualification could be restarted consistently. Its partial passing rows are
observations, not a completed acceptance result.

The broader diagnostic run
`bootstrap/out/source-set-proof/dfdaadb17ef346709ddbddae8b06c3fa/report.json`
passed both repetitions at1/2/4 workers, complete ordered results, measured208-byte
publication, reversed schedules, canonical diagnostic spans, limits, shared tokens
and independent contexts. It then rejected an incorrect test assumption that the
first token starts after the BOM. The frozen scanner contract/token fixtures
preserve an explicit Bom token spanning bytes0..3 and zero content scalars; the
next content token starts at byte3/scalar0. The corrected focused procedure
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-concurrency.ps1 -DiagnosticOnly -DiagnosticRawPath bootstrap/out/source-set-proof/b40a9bddfdf64f8daae31fb016856070/stage1/raw.ll -DiagnosticSuite fixtures`
passes36 assertions, including exact Unicode-comment and CRLF EOF coordinates:
`bootstrap/out/source-set-proof/2cf691b63b3f4b2fb107a761b33a7c1a/report.json`.
The same independent fixture check now runs after the first serial result, before
the expanded matrix. No scanner behavior changed.

The baseline audit also now understands prerequisite reports that retain typed
input/artifact identities beside individual native cases rather than exposing a
flat `artifacts` list. It recursively verifies every such identity, retaining
the original flat-list handling for the earlier reports. A focused audit found
69/11/11/18/60/34/12 matching nested identities in the seven new report families.
This is additional identity verification, not omission of their artifacts.

## Final accepted source/tool cohort and gates

The unchanged source cohort passes all predefined gates below. Each report pins
its actual source/tool/artifact identities; the final audit rehashed the selected
tools, every accepted source input, consumer artifacts and local executable, and
required all gate selections to name the same accepted manifest.

Accepted manifest: `bootstrap/out/v2/86f0e97c73f74a4dbaeb19987d965a04/manifest.json`; SHA-256
`138B17C45681B02999961D0EB5A76430667D5D5AC1F3A7091822A6724A62C97F`.

| Selected artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| seed: `ubec.exe` | 2090606 | `D131E17F57FA538F47F3C491B50FEAD2C092AEB761DCA484E8517257C508EF85` |
| compiler: `ube-stage2-v2.exe` | 835072 | `704769B2D6F3B735AD43FDD1FC9E925A0AD0637FCD135A6383128A9296556E92` |
| runtime: `bootstrap_runtime.o` | 134406 | `FB8A7D63E81650D67B40C7A81FABA1E182D7A15A4304E0C342DE5DAF1EFEA604` |
| unicodeRuntime: `bootstrap_unicode_runtime.o` | 28346 | `AB41E49C6E1375AC878F588FF88DC7DB43A7018CAD8F3F811DE811F7C245EDFD` |
| clang: `clang.exe` | 109566464 | `F3425B2BFF01BC401C84AF6E5E180629182FAFC2EB35CF971A3E50C9CF13F263` |

| Exact procedure, from repository root | Passed result |
| --- | --- |
| `rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1` | 592 grouped assertions: core 136 and all 20 named child proofs; both source-built stages and fixed point |
| `rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-parser-contract.ps1` | 116 frozen fixtures, 16 negative controls, 11969 definition assertions; complete accepted-cohort audit |
| `rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-concurrency.ps1` | `success:true`, `qualified:true`; 2826 native assertions per stage, 5652 total; identical raw LLVM |
| `rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-parser.ps1` | `qualifiedParser:true` ; 4049 checks, 188 cases, 10412 actual root capacities, earlier failure/cost/cleanup gates retained |
| `rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-parser-cli.ps1` | `qualified:true`, diagnostic mode off;217 assertions, 82 exact process cases, 27 diagnostic controls per stage; identical raw LLVM |
| `rtk proxy powershell -NoProfile -File bootstrap/out/publish-local-cli.ps1` | Local `bootstrap/out/v3/ube.exe` is the byte-identical qualified stage-two CLI; all 41 exact process oracles pass |

- concurrency: `bootstrap/out/source-set-proof/e77d09d38bdc4a969a8068970a6e2bbb/report.json`; SHA-256 `EFAD982A0AD96454BD479C1B9EF0509540B2C4E673962C07AAF59A4182937F94`.
- parser: `bootstrap/out/parser/5f5f7496ccd94ec395c180a9b8cc2478/report.json`; SHA-256 `1F81C4D780836F899360BDFE5CC51C03FABB74DBC377151E128B28970B020331`.
- cli: `bootstrap/out/parser-cli/6b7f17b1c7e6417e991fa4b2ef1376fd/report.json`; SHA-256 `5BC5B1511CA053FE86531A2BA07DD693FE7B86C75A1D939B828EFC10612D68B0`.
- local: `bootstrap/out/local-cli/7582b6cb289f4fac92d663590799767d/report.json`; SHA-256 `722FD4B92CCA00EA3F63DCFBD1D63B29C719E521DCC0A7AADF8341619BAC0FBD`.
- definition: `bootstrap/out/parser-contract/762af3a606314079a1058fa3ad50581a/report.json`; SHA-256 `4C4A7EE580EE11B1EC051620F9A5C8FC873A66289888D702AC7B5A4E9BF81754`.
- Final independent report/input audit: `bootstrap/out/concurrency-final/97dba101f5d441c8be36a38c86b7607d/report.json`; SHA-256 `8797DCE652BE7DCF75081B8113B006F5B2D8A78D0072C6E1C288A5B07A0D2DF7`.

Both raw consumer images have SHA-256
`B9CF79D747F64029263B88817B2C3C3C9E4FF5DB8A3AEBF7F6C6DBD009826EF2`.


### What actually executed

Each stage ran two complete trials at each budget 1/2/4 over 26 accepted inputs:
every current production MODULE in the compiler and UBECore (18), plus eight
independent empty/BOM/CRLF/Unicode/nesting/growth fixtures. The growing functions
contain 1/8/32/128 increments. CLASS-body grammar remains deferred; the three
production `.cls` owners are qualified only through the bootstrap reference
contract. Rejected/deferred fixtures are additional inputs, not accepted programs.

Actual UBE `CallNew ProcessSourceWork` performs conditional preflight, scanning
and parsing. The one-worker path uses the same operations. Complete token records,
ordered node graphs, source IDs/spans, failure records and metrics match the serial
reference. Distinct simultaneous native/program IDs, real byte-read interleaving,
the reversed native-completion schedule and serialized-work negative control all
pass. The control has four entered workers but zero operation switches, preventing
parked threads from being mistaken for parallel compiler work.

Actual UBE parser workers also borrow one immutable completed token owner with
private graphs. Two independent UBE coordinators run simultaneously, each with
one work budget and its own cancellation, input vector and complete publication.
Those cases compare complete results and drain owned resources. The shared-token
witness retains the caller's published owner and makes no sole-owner claim.

Canonical rejected/deferred first failures remain identical at 1/2/4 jobs,
including reversed completion: rejection 104 at bytes 67..75; deferred 3 at 52..56.
Empty input, one source with four jobs, domain and token/node/pending/depth limits
pass. Cancellation covers before dispatch, admission/work, before publication
and after its admitted commit point. Fault kinds are checked exactly, not merely
for nonzero status. Actual persistent allocation denial, native start/wait failure,
full root-registry pressure at publication and at source-Sub admission preserve
earlier complete graphs and bytes. A rejected source Sub gets no public ID and
executes no body. Native records/captures/handles drain; final test-owned roots
and GC payload are zero.

### Executed costs and performance limitation

Every full26-source trial observes 4,601,950 source-byte reads, 13,983 allocation
requests and 19,068,744 payload-copy bytes, with **zero source-payload bytes copied
by worker capture or work/publication**. Required initial source intake copies
894,863 bytes exactly once; this positive control proves the copy observer is live.
The 26 captures contain 208 reference bytes total; atomic publication copies another
208 reference bytes in one assignment. Publication is measured separately.

Measured retained shared input is 896,335 GC payload bytes. Completed private
results are 7,223,200 bytes, independent of worker budget. The predefined formulas
using emitted 32-byte owners, 88-byte work objects, actual token/node counts and
16-byte array headers equal the measured retained allocation total after collection.
Native capture header 80, record 96 and TLS 4120 bytes are recorded separately; event
handles, native stacks, allocator/collector headers and OS/CRT costs are not GC
payload. Process peak also includes assertion snapshots and deliberate root pressure.

Every successful root admission and GC payload allocation is observed. Maximum
additional roots across the final trials are 1835/3577/6959 for 1/2/4 workers,
below the fixed 4481/8706/17156 bounds. Peak additional GC payload in a trial is
39,792,412/39,792,424/39,792,448 bytes; these counts include private pending work
and collection timing, rather than asserting only a size formula.

The table gives the two measured trial ranges per stage. Timing includes native
observers, including collector acquisition/wait/hold timing. The final gates ran
alongside parser/CLI qualification on a host reporting 32 logical processors;
these are verification-load measurements, not an isolated production benchmark.

| Stage | Jobs | Wall ms range | Additional roots max | Source payload copies |
| --- | ---: | ---: | ---: | ---: |
| 1 | 1 | 32547..42282 | 1835 | 0 |
| 1 | 2 | 40421..46359 | 3577 | 0 |
| 1 | 4 | 70063..79484 | 6959 | 0 |
| 2 | 1 | 37484..41344 | 1835 | 0 |
| 2 | 2 | 43859..44234 | 3577 | 0 |
| 2 | 4 | 62875..66953 | 6910 | 0 |

Four-worker execution is slower than the one-worker reference in these runs.
Each trial records 259,135,779 worker collector critical-section acquisitions;
aggregate wait/hold ticks and worker CPU are retained separately in the report.
This exposes substantial synchronization/instrumentation overhead. It does not
establish a production speedup or identify a single cause. Investigate collector
registration/cleanup and coordination with a focused sample before any broad
redesign; do not infer that passing correctness meets the product performance goal.

### Current handoff

The owner-requested first bounded objective is complete. UBECore contains generic
thread/storage mechanisms; compiler source ownership, ordering, diagnostics and
publication remain in `SourceParsing` and its compiler-owned classes. Existing
names and the fresh compiler line are retained; no archived implementation,
whole-project worker copy, C worker substitute or blanket work lock was adopted.

The next existing-plan item is a **proposed** bounded normal `.UBE`/direct-UBECore
project-input and parallel-frontend contract. Fix source identity/order, paths,
reference limits, diagnostics and failure publication before implementation;
reuse the qualified source-set API. Collector contention is an explicit
performance follow-up. This completed goal does not authorize later language,
semantic/backend or project/jobs CLI expansion. No commit or push is part of
this goal.
