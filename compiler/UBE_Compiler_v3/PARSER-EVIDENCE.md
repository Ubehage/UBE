# First grammar-consumer definition evidence

This records the completed definition-only snapshot. Its 116 cases remain frozen.
The subsequent [native probes](PARSER-PROBE-EVIDENCE.md) pass through a newer
501-check source cohort after a focused recoverable-memory bootstrap correction.
That evidence records the current identities, measured choice and next production
implementation; historical hashes below remain unchanged.

The next definition item in `Roadmap.md` is complete. `PARSER-CONTRACT.md` and
its independently authored fixtures define the first bounded native MODULE
grammar consumer before choosing parser representation or implementing it.
No production compiler/library source, runtime, manifest, accepted selection or
protected instruction changed. The existing executable still reports program
checking unavailable after successful source/scanner intake.

## Executed definition gate

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-parser-contract.ps1
```

Passed **11969 new definition-consistency assertions**, with **16 negative
controls**, over **116 manually authored cases**:

| Oracle context | Syntax shape | Structural rejection | Deferred | Total |
|---|---:|---:|---:|---:|
| Expressions | 37 | 9 | 1 | 47 |
| Statements | 24 | 9 | 6 | 39 |
| Native units | 16 | 8 | 6 | 30 |
| Total | 77 | 26 | 13 | 116 |

The exact report is
`bootstrap/out/parser-contract/c46feb602f674a38a0d052370152d7fe/report.json`,
SHA-256 `1429DD01244CE839D7E490C186B2B8A1688640EF5D060A0F38FA371A47F2E045`.
It records 13 explicit definition/authority inputs and their unchanged hashes,
resolved original spans, logical shapes, diagnostic/deferred expectations and
the full retained-baseline audit. Both before/after audit flags are true.

| Definition input | SHA-256 |
|---|---|
| PARSER-CONTRACT.md | `091CC2C70F4B4C381E9EFF92598A3DE2865B81B0FB779296AF1CF497F4217BCF` |
| tools/check-parser-contract.ps1 | `EFFCC0E2A116EC8A9DB97D86E495BCCBDE4FFAE3ED1FECECEEA239AC396A2FEE` |
| tests/parser/ORACLES.md | `F28669C63162D258EFE3D79BF6F4B43A14B2D5F37EE1824DFADD436C2D915B49` |
| tests/parser/expressions.json | `9ECB1FA3232F53E4376E7D0013056CFA50580B8E1FF0F93A1604AA8B06579020` |
| tests/parser/statements.json | `B18E8A87404CD90E55718845F8C3FEBCC3595404D31E3D68585208C89EB0C65B` |
| tests/parser/units.json | `7E355259ECC6F9346E9633081A5E8556450E03512168A78492A3D93016A5DE7C` |

## What the gate checks

The test-only checker does not tokenize or parse fixture source. It verifies
strict schema/outcome separation, existing EBNF production references, exact
ordinal source/point witnesses, selected independent numeric coordinates,
logical node arities and entry domains, complete parent containment and ordered
nonoverlapping siblings. Raw and point-anchor text remain distinct. Unicode
coordinates are counted independently over strict UTF-8/UTF-16 scalar pairs,
including supplementary letters, BOM and CRLF. Invalid data produces a bounded
failed report; its fixture guards are not production language limits.

Negative controls reject unknown grammar/node/diagnostic names, incorrect
outcomes, absent text/witnesses/diagnostics, incorrect byte/CRLF anchors, broken
arity, deferred obligations mislabeled as syntax, children escaping parents,
overlapping siblings and invalid omitted-slot spans/placement. Synthetic
coordinate/structural controls test the consistency machinery; they are not
additional source-program oracles. None of these checks proves that an expected
source grammar answer is correct or that a parser recognizes it.

Separate authors and cross-review checked the new expectations against primary
language rules. Review corrected three negative fixtures whose reserved `Read`
procedure name would have failed before their intended parameter error; they now
use `ReadValues`. Member attributes remain separate from procedure body nodes.
Numeric array-rank interpretation is not inferred from surface comma witnesses.
Supplementary-letter and word-operator spacing cases were added, alongside
nested With association, label priority and explicit deferred control families.

## Decisions and retained boundaries

The first domain is branch-free native MODULE syntax used by fresh v3 and
portable UBECore. Current source comprises six compiler and six portable library
modules; those modules were read as concrete requirements, not parsed by this
definition tool or claimed as newly verified syntax inputs.

Grouping follows the actual primary precedence table, including Mod binding
more tightly than integer division and integer division more tightly than
multiplication. Power is right-associative, other binary operators left-
associative, and comparisons do not chain. Normal calls retain ordinary library
binding, including Mid$/Len/String$ overlaps; members may use reserved tokens.

Named/omitted arguments, individual argument parentheses, assignment before
statement-call interpretation, closest single-line Else, Rem after Then,
continuations and compound terminators retain explicit witnesses. At the start
of a logical statement line, identifier-colon is chosen as a label ahead of the
otherwise possible zero-argument-call interpretation. This is a documented
consumer closure under the owner's delegated decisions. Numeric labels remain
deferred and do not steal a literal from `1 = 2`.

Structural syntax acceptance is distinct from program acceptance. Nonassignable
lvalues, missing types, nonconstant initializers, Option Explicit Off,
incompatible procedure terminators and invalid binding contracts retain later
semantic obligations where the primary specification puts them. Intrinsic
executable bodies and malformed declaration phrases have separate rejection
witnesses. Existing v2 failures were not used as expected grammar answers.

Legacy/designer/class/property/interface/event/hook and other unselected syntax
families remain deferred, with their exact list in the contract. Adjacent
use-site suffix/operator ambiguity such as `x& + y` is explicitly unresolved in
this first scope; no new language ban or arbitrary grouping is inferred.
Conditional selection/inactive recovery must precede core parsing, and cannot
universally require a successful provisional whole-file scan or metadata pass.
The original bytes remain the future consumer's necessary input authority.

## Preserved native qualification

The definition gate separately passed **6141 baseline-audit assertions** and
rechecked **2308 unique recorded identities** before and after checking new data.
These are the previously audited 2307 identities plus the current selection
pointer. It retained the accepted 501 grouped native checks, 136-check source
bootstrap, all 13 distinct child proof families, compiler/runtime/tool identities
and five Unicode raw/provenance inputs. Managed-substrate current-source status
and scanner formal qualification remained required. No native suite was rerun,
no executable rebuilt and no selection republished by this goal.

The retained cohort is `bootstrap/out/v2/4eb76c64ed774a1a9fb38b38155b71ef/`:

| Identity | SHA-256 |
|---|---|
| Final manifest | `5A1C0A9D2A9DA40AAAA1FC45B0AF259003AFC362572B26AC207884C607EF0726` |
| Source bootstrap manifest | `DB5DFA468B3F043580ABA90FA28AA28019DDC8062B3104F59473B85E3C85EF8F` |
| Selected v2 stage two | `25392B89D16B8BF80E25F53D10EA0F3407C4AECC81BEF6114FB740B5F9D43A60` |

`SCANNER-EVIDENCE.md` records the native execution results and their supported
limits. This identity audit preserves that result; 11969 definition assertions
must not be added to 501 and called new native compiler verification. A fresh
qualified 501-check cohort can be supplied with `-SelectionPath`; the checker
records its actual hash rather than hardcoding one temporary build identity.

Final handoff checks also passed:

- `rtk proxy powershell -NoProfile -File bootstrap/out/audit-parser-definition.ps1`
  rechecked the report hash/counts, all 13 definition input identities, selected
  baseline identity and the six input hashes printed in this evidence file.
- `rtk proxy powershell -NoProfile -File bootstrap/out/audit-source-handoff.ps1`
  passed 29 PowerShell parses, 19 JSON parses, 58 Markdown documents and 167 local
  link targets, manifest containment/targets, protected-instruction preservation
  and tracked whitespace checks. These are structural checks, not parser tests.

## Exact next action

Run small native UBE representation/traversal probes against this fixed grouping
contract before choosing production parser storage or strategy. Demonstrate
bounded nesting, first-error progress, intact source views and failure-atomic
publication with current typed arrays/records. Include lower/at/above resource
boundaries, root/allocator faults, cleanup, private consumers and actual work/
copy/allocation measurements through both source-built stages.

Then document the measured choice and implement the first bounded consumer.
No new generic collection, String, scheduler, language feature or archived parser
architecture is selected. A parser, its native comparison runner, recovery
implementation, conditional evaluator, semantic checker and code generation
remain unimplemented by this goal. No additional owner decision is required to
run the focused probes already called for by this plan.
