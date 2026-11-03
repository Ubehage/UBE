# Checked-result lowering review

This source audit is not proof that existing records suffice for correct code.
Record layouts and numeric kinds are private implementation details, not a
new public IR. The following maps required inputs to producers and outstanding
independent obligations.

`additional/check-initializer-dependency-graph.ps1` independently anchors the
early-access and circular-initialization fixtures in their source files. It
checks the initializer nodes, their binary-node/first-read links, and the resolved
cross-module declaration targets; changing each dependency target is rejected.
Both targeted 25f stage observers identified below passed the script at jobs 1
and 4, with identical output per observer across worker counts. For each:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/additional/check-initializer-dependency-graph.ps1 -Observer <observer-path>
```

These are retained checked-graph relationships only. They do not establish
that a future consumer initializes a not-yet-started module before access or
implements the eventual rules for circular references. The owner clarified
that the references themselves must remain allowed. Actual execution and
independent event observation remain required.

`additional/check-indirect-initializer-graph.ps1` checks the helper-mediated
cycle fixture separately: the initializer call resolves to `ReadB`, that
helper's body contains the read of B's declaration, and B reads A's
declaration. Both targeted stage observers passed at jobs 1 and 4; four
controls independently changed the call target, helper-body link and two read
targets and were rejected. For each observer use:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/additional/check-indirect-initializer-graph.ps1 -Observer <observer-path>
```

This establishes those graph links for the fixture, not a warning-analysis
implementation, a general call graph, or native initialization behavior.
The same command with `-Acyclic` checks the helper-mediated no-cycle fixture:
both observers passed at jobs 1 and 4, including a control that inserts a
spurious B-to-A target and three other changed-link controls. This is a
comparison of the observed fixture graph, not proof that arbitrary call paths
have no back-reference.

`additional/check-initializer-call-graph.ps1` checks the separate early-call
fixture. Both targeted observers passed at jobs 1 and 4: A's initializer call
targets B's public procedure, B's procedure body assigns B's `y`, and B's
initializer calls its own setup function. The checked count assignment targets
B's counter. Mutations of
the cross-module call target, procedure body, assignment target and initializer
call target were rejected. Command for each observer:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/additional/check-initializer-call-graph.ps1 -Observer <observer-path>
```

The graph check does not run the functions or prove B initializes before the
call; the native result and initializer-entry observer remain future gates.

The owner confirmed that every signed integer minimum `Mod -1` succeeds with zero
and preserves the existing Err, matching the portable `SignedIntegers.bas` helper. The language
specification and older scalar-operator audit now state that distinction from
overflowing integer division. LLVM `srem` is undefined for this operand pair,
so lowering must avoid executing it. A separate same-thread Err observation is
needed because both success and a neutral overflow result have value zero.
The existing checker currently accepts the literal expression and folds it to
Long zero: `remainder-constant/RemainderConstant.UBE` passed `--check` at jobs 1
and 4 with both 25f stage CLIs, and `check-remainder-constant.ps1` observed the
zero-valued folded node with both 25f targeted observers and rejected a wrong
expected value. This is evidence of the existing checker's constant result; it
is not evidence of the future native runtime or Err behavior.
`tests/native-executable/additional/check-remainder-graph.ps1` separately checks
that the Integer, Long and LongLong dynamic remainder fixtures retain the
expected result and operand types, operator, source spans, distinct declaration
targets and written operand order. Both 25f targeted observers named below
passed all three checks and rejected wrong-operator and wrong-type mutations.
This is checked-graph evidence only; it does not execute lowering or observe Err.

| Required input | Current source evidence | Remaining obligation |
| --- | --- | --- |
| Publication and ownership | `SemanticResult.cls`, `SemanticCatalog.cls`, `SemanticModuleResult.cls`: the result owns catalog, entry declaration and ordered module results; modules hold facts, values and root. | Retain owners through lowering and tool completion; test consumption after caller roots disappear, including cancellation. |
| Declarations, types, defaults, native roles | `SemanticModel.bas` records declaration source/syntax, scope, type, parameters, flags, initializer, value and body; type records include representation and pack/unpack declaration IDs. | Test nominal identity, role identity, neutral values and caller/callee agreement; verify flags/defaults against the semantic contract. |
| Execution and spans | `SemanticModel.bas` defines `BoundNode` with source/syntax, type, value, target, ordered child links, flags and auxiliary index; `SEMANTIC-IMPLEMENTATION.md` describes reduced constant nodes. | Check operation ownership, type and source mapping. A folded expression retains original facts/span without recreating arithmetic. |
| Declarations and assignments | `SemanticStatements.bas` creates storage/assignment nodes, links the value, and stores conversion fact ID in the auxiliary field. | Test neutral storage before initializer, self-reference, failed runtime initializer and destination conversion. |
| If, While and exits | `SemanticStatements.bas` builds control nodes, links condition and statements, and retains exit targets and flags. The existing complete semantic oracle includes a block If, nested While and both exits with identity Boolean condition conversions. | Extend the independent observation to single-line If, ElseIf, nested loops and nonidentity condition conversion. A separate conversion fact must be associated correctly; no lowering consumer has been tested. |
| Calls and passing | `SemanticCalls.bas` links live children in written order followed by omitted pure defaults in parameter order. It emits a contiguous parameter-ordinal fact map with written ordinal, parameter, expression and mode, and links the call node to the call fact. The existing complete oracle includes reordered named parameters and forced/omitted temporaries. | Demonstrate a lowering consumer uses the two orderings correctly, including nested side-effecting calls and all modes. The `order`, `alias`, and `optional` projects are partial future native oracles. |
| Short circuit and checked operations | `SemanticExpressions.bas` emits typed expression/conversion facts and reduced nodes; the implementation contract says a provably skipped operand has static facts but no execution value. | Test known and unknown branches, eager operators, exact-once evaluation and conversions. Guard LLVM operations from undefined behavior on dynamic failures. |
| Resources and concurrency | `SEMANTIC-IMPLEMENTATION.md` defines immutable catalog, private source results and one bounded worker controller. | Set lowering-specific allocation, copying, nesting, cancellation and cleanup bounds. Semantic measurements do not qualify lowering. |

The existing independently authored `tests/semantic/native/complete/calls.ps1`
specifies the call map, source evaluation order, forced and omitted temporary
modes, If/While conditions and exit targets for `argument-modes-and-control`.
The recorded `bootstrap/out/semantic-whole/6f214363e9b14e98a5748ce16c0ff4d3/report.json`
reports 1,368 checks for that project per stage, for jobs 1, 2 and 4, and 40/40
corruption controls per job's comparison. This is existing cohort evidence,
not a rerun during this review and not evidence of native lowering or execution.
Its condition conversions are identity Boolean conversions; it does not cover
the numeric-to-Boolean condition or all control variants listed above.

Before production lowering, extend the independent observations for those gaps,
and resolve any missing relationships with a focused checker change and retained
gates. A successful check alone does not establish readiness to lower.

The existing complete-project `calls.ps1` oracle derives declarations, source
spans, expressions, argument maps and control nodes independently, then checks
the observed semantic records. It is a suitable starting point for the missing
cases, but its existing Boolean conditions and non-nested calls do not prove
the added native fixtures' graphs. Extend the independent project definitions
with numeric conditions, nested reordered arguments and nested exit targets;
check the conversion fact, both written and parameter order, and the exact
exit target separately. Mutation controls must change each of those relations
individually and be rejected. Run the observations through the qualified
source-built stages and record identities before claiming these gaps closed.

`tests/native-executable/additional/check-numeric-conditions.ps1` now checks
the two Long-valued While conditions in the existing `conditions` fixture,
including each bound child and its condition-associated Long-to-Boolean fact.
It also changes the source type in each observed fact and requires rejection.
A diagnostic run using an existing local targeted observer passed two checks
and two controls. This does not qualify the observer or the source-built stages
and does not exercise a lowering consumer; repeat it with both verified stage
observers and preserve their identities before closing the observation gap.

Subsequently both targeted observers named in the qualified 25f report
`bootstrap/out/semantic-whole/d6427b01696642339093b6fc06bd3dab/report.json`
passed this script with exit 0, each reporting two checks and two controls.
Relative to that report directory, the stage-1 observer is
`f740ea07e47744afb51ff8e72dd6f6f7/targeted-stage1-ee4c75f3860143c78d87811112256454/targeted.exe`
(SHA-256 `971A8CE0328F143C41B50064F7335AEC080B2BA36ADF127E638005376BEC187D`);
the stage-2 observer is
`f740ea07e47744afb51ff8e72dd6f6f7/targeted-a459a1512e004eeea42bfa75b75ae947/targeted.exe`
(SHA-256 `F3F7545008D7DA3E99AFAF95A05C7AB08181954D6392B59B63DAFCDF89ED1B69`).
For each run use `rtk proxy powershell -NoProfile -File
compiler/UBE_Compiler_v3/tests/native-executable/additional/check-numeric-conditions.ps1
-Observer <observer-path>`. The script SHA-256 is
`809EE5CA538F48B443E6BD5C16EDFC788479942C4DDC2A61D4FDDEABE71C3679`, and the
fixture source SHA-256 is
`28E223D6CA457ED3205A924C4E322C3C93F5F4AD7FD60B29583D3A1C043C2FF1`.
This comparison covers only these two conditions and the specified type
mutation, not all control variants, lowering or generated execution.

`tests/native-executable/additional/check-multiply-graph.ps1` observes the two
dynamic Long multiplications in the multiplication-overflow fixture. It checks
the operator and type, source ranges and two ordered variable operands, and
rejects a mutated operator. Both 25f targeted observers identified above passed
the script with exit 0. Earlier attempts exposed two errors in the comparator:
it included the initializer's equals sign in the expression range and then
formed the expected-offset array incorrectly; those were corrected before the
passing runs. This establishes only these checked-graph relationships, not
overflow lowering, runtime Err behavior or native execution.

`tests/native-executable/additional/check-initializer-self-graph.ps1` anchors
the self-referencing declaration and failed-initializer fixture in source. It
checks that the self-read targets its declaration, that the division node is
linked to the other declaration, and that the later read and assignment target
that same storage. Mutating either the self-read target or assignment target is
rejected. Both 25f targeted observers identified above returned exit 0 with
both mutation controls. The comparator was then extended to check the types,
operator kinds, initializer/assignment conversion fact targets, contexts and
links. Both observers passed again and rejected four separate mutations:
self-read target, assignment target, division operator and conversion target.
It was extended again to check ordered operands, literal values and the divisor
target; both observers passed and a fifth control changing the dividend was
rejected. A further check anchors the procedure body to the first declaration
and verifies the declaration/assignment sibling order; both observers passed
and a sixth mutation that changes the order was rejected.
This checks these graph relationships only; it does not prove neutral
initialization, operator lowering, runtime error behavior or execution.
For each observer the command was `rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/additional/check-initializer-self-graph.ps1 -Observer <observer-path>`,
using the two paths and identities given above.

`check-reference-initializer-graph.ps1` copies the referenced-library fixture
and appends a synthetic `Main`, because the targeted observer's single-source
mode requires an executable entry. It checks the two module declaration nodes, their order,
initializer values and the second initializer's reference to the first; wrong
order and target mutations are rejected. Both 25f targeted observers above
returned 0 using `rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/additional/check-reference-initializer-graph.ps1 -Observer <observer-path> -OutputDirectory bootstrap/out/reference-initializer-graph`.
This is a synthetic single-module graph observation, not the actual referenced
library graph, cross-project binding, initialization execution or proof of
dependency order. Those remain acceptance obligations.

The observer also has a `--project` mode, so
`check-reference-project-graph.ps1` now inspects the actual executable and
referenced library together. It verifies library declaration order, the second
initializer's link to the first declaration and the executable initializer's
link to the library's second declaration. Both 25f targeted observers above
passed at jobs 1 and 4 with identical observation streams within each run;
mutations of the cross-project target and library order were rejected. Command:
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/additional/check-reference-project-graph.ps1 -Observer <observer-path>`.
This supersedes the synthetic check for these specific graph relationships,
but the catalog's source order is not proof of runtime initialization order;
native execution and the order mutations remain future acceptance checks.
The comparator was subsequently extended to check both modules' root links,
initializer literal operands and their destination conversion records. Both
observers passed again at jobs 1 and 4; in addition to the earlier mutations,
incorrect conversion-target and library-operand mutations were rejected. These
checks still concern retained graph data, not execution ordering.

For `reference-initializer-error`,
`tests/native-executable/additional/check-reference-error-graph.ps1` inspects
the actual whole-project result. It checks the library declarations' linked
order, division operands and target, the later read of the failed variable,
and the executable's link to that later declaration. Both targeted observers
passed at jobs 1 and 4 with identical streams within each run; wrong operator,
declaration-order and cross-project-target mutations were rejected. Use
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/additional/check-reference-error-graph.ps1 -Observer <observer-path>`
with the two observer paths above. This does not execute initialization or
observe Err.

`tests/native-executable/additional/check-nested-exit.ps1` separately observes
the nested-exit source: it identifies the two While nodes by their source
anchors and checks that the Exit While node targets the inner one. A mutation
redirecting it to the outer node must fail. The same two 25f targeted observers
identified above each returned exit 0, reporting the expected target and
wrong-target control passed. This does not test emitted control flow.

`tests/native-executable/additional/check-nested-arguments.ps1` independently
anchors the nested named calls and checks their bound child order and parameter
association. Separate mutations change the outer child order and the inner
written-argument association. Both 25f targeted observers identified above
returned exit 0 and reported the checks and both controls passed. This is a
focused checked-graph observation, not execution of a lowering consumer.

`tests/native-executable/additional/check-single-line-if.ps1` checks the
condition and ordered branch nodes of four single-line If statements; it also
rejects a mutation removing the first Then branch. Both 25f targeted observers
identified above returned exit 0 and reported four checks and the control
passed. It does not establish emitted branch behavior.

`tests/native-executable/additional/check-elseif-graph.ps1` checks the existing
`conditions` fixture's block If, ElseIf and Else against source anchors. It
checks their parent/child and sibling order, both comparison operators and
literal operands, and that the two left operands share a declaration target.
Both 25f targeted observers identified above passed and rejected four separate
mutations of branch order, nested condition, branch target and operator. Run
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/additional/check-elseif-graph.ps1 -Observer <observer-path>`
with each of those observer paths. This covers one ElseIf graph only; it does
not independently establish the shared declaration's identity, emitted branch
behavior, or all ElseIf combinations.

For reproducibility, run each script with the same PowerShell invocation and
`-Observer` paths listed for the numeric-condition check. The nested-exit
script SHA-256 is
`133F3D7352EFD9593EBE2435481EDC996341177AF0545E545F2DF38A95BCF135`; its
source SHA-256 is
`CB2C651516F27734F358CA49EE5C3CE61DD5EC9906DD37DB8E0B1D998D394DB7`.
The nested-arguments script SHA-256 is
`A5869DC1C23D71F4C8C2803480F413E85B5CEB0D2B62AB94C42E6DC761AF6F17`;
its source SHA-256 is
`F28F3541901249309C365B1FAF6DE64FE7E3E087BBC1378B09E2B44A22E8791C`.
The single-line If script SHA-256 is
`4365917972070138DBB5CB210AEF5A528A1D99B1020ED2550DB70527FF93D6CA`;
its source SHA-256 is
`9226494A28A3F5726EB3199C4EEEC52239AA7A77619ADDA387B96604A4C3F7DE`.
