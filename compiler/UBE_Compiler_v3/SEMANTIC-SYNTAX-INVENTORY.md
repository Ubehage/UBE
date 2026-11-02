# Syntax information needed by first semantic checking

Initial audit: 2026-11-01, before production edits. The owner subsequently
approved implementation. The table below records that initial gap; the current
candidate retains the added structure described in SYNTAX-DETAILS.md.
`tests/semantic/inventory.json` pins exact function-local evidence snippets;
the definition gate resolves their current lines and records file SHA-256.
This is a source audit, not a new native parser qualification.

## Original retained representation and identified gap

`SyntaxTree.bas` has six-Long SyntaxNode records (kind, first/last byte,
first child, next sibling, child count). SyntaxResult owns nodes/count/root/
source ID. SourceWork retains its SourceOwner alongside tokens/syntax;
ProjectSyntax retains ProjectInput and ordered work. Borrowed spans remain usable
only while those original owners live. Kind alone supplies no name/type/modifier.

| Input family | Retained today | Discarded or not decoded | Required extension before checking |
| --- | --- | --- | --- |
| Native module header | One Header span; envelope/source graph has module/package identity | No declaration-level header children | Reuse admitted identity; retain metadata spans; no second identity decoder |
| Procedure | Procedure/IntrinsicProcedure, Header with Name, optional Parameters, ResultType, body/member Attributes and written EndMarker | Sub/Function and visibility/modifiers are only within header text | Expose procedure kind and exact modifier spans from existing parse |
| Parameter | One ordered Parameter leaf per complete parameter | Typed name/suffix, passing mode, Optional/ParamArray, rank/type and default expression nodes | Publish validated components and default expression; distinguish omitted modifier from explicit ByRef |
| Function result | ResultType leaf covering As phrase; Name may include suffix | Type phrase/rank validation nodes reset | Publish type reference/rank and suffix spans, retaining absence of As |
| Dim/Static/Const | One leaf covering the complete comma-separated declaration | Every individual declarator, suffix/type/bounds/As New/initializer; validation nodes reset | Expose ordered per-name details and initializer expressions without inheriting a following name's type |
| Record field | Field leaf for one validated field | Same detailed type/rank information | Remains deferred, but retain a precise deferred anchor |
| Native Type | Name, representation TypeName and EndMarker children | Representation type is still raw spelling; visibility only in parent span | Decode name/type components from existing parser; no layout inference |
| TypeName | One exact raw type phrase span, including qualification/fixed length where present | No normalized type identity or decoded fixed length | Expose component/rank/length spans; type resolution stays semantic; deferred types need no new implementation |
| Option | Full leaf span | Kind/value only in original tokens | Expose recognized option/value tokens from the parser |
| Attribute | Full leaf span | Target chain and values validated then discarded | Expose target/value components and original string; explicit primitive role validation stays semantic |
| Name/Literal/Group | Exact raw name/literal spans and explicit grouping | No folded name, cooked literal value or static type | Preserve grouping; semantic/library decoding consumes qualified spans, not a new source grammar |
| Member/Bang/NamedArgument | Ordered children and full span | No binding/accessibility or named-parameter association | No grouping extension; record semantic resolution separately |
| Call/CallKeyword/CallStatement | Callee and ordered argument children; Group, Omitted and NamedArgument survive | No signature, ByRef alias/temporary mode or association | Preserve source slots and every individual Group; zero slots differ from one omitted slot |
| Assignment/control | Ordered lhs/rhs or condition/body nodes; explicit statement kinds | No assignability, condition conversion, enclosing Exit validity | Bind existing structure; do not reinterpret structural lvalue as writable storage |
| Terminator/Exit | Original leaf spans | Written target/kind only in token text | Expose written kinds and spans from existing parse; do not silently repair mismatch |

## Qualified retained details

The existing parser now constructs the detailed nodes described in
SYNTAX-DETAILS.md in its existing private arena. The updated inventory JSON pins
20 current function-local source witnesses, including names/suffixes, parameters,
result/type clauses, declarators, option/attribute parts, bounds/ranks and written
terminators. The strict native gate now passes 1,879 maintained assertions,
including all 200 fixtures, 12 exact physical-detail trees, both stages,
publication/allocation/root failures, all real-backed root-capacity ranges,
worker sharing, complete graph validation, cost bounds and corrupt-oracle
controls. Exact report:
`bootstrap/out/parser/eee096abee4d4e85bd22a7fbd9399ec2/report.json`, source
cohort `04c889304e52467bbf597ac84269317e`. This qualifies the retained parser
details for that cohort; semantic checking and later bootstrap changes still
require their own gates. Source witnesses alone would not establish this.

## Original evidence and required sequencing

Before the extension, `TryGrammarParameters`, `TryGrammarProcedure` (result As),
`TryGrammarVariable` and `TryGrammarAttribute` restored `State.Count = SavedCount`,
discarding private validation nodes. `TryGrammarProcedure` retained Name/Parameters/
ResultType children; it is inaccurate to say every procedure header is opaque.
The native comparator's optional Header projection does not prove that details
are absent or authorize changing old expectations. The complete original bytes
remain available, but their presence is not a substitute for semantic input data.

The extension publishes the already validated detail through these same paths,
with exact spans and preserved grouping/budget/failure obligations. Its selected
representation is documented in SYNTAX-DETAILS.md. Do not recover declarations
with regex, a second lexer, a checker-local declaration parser, or guesses from
Node.Kind. The earlier graph did not supply the required capability; retained
original source bytes were never a substitute for structured declaration detail.

Inventory-only source probes and hashes can detect source drift, not establish
runtime detail retention. The strict native gate inspects the published details
through both stages, including source preservation and failed publication.
