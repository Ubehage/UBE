# Retained declaration syntax

Status: implementation contract within the approved First semantic checking
deliverable. This extends the existing parser, not the source grammar or phase
architecture. The initial gap is recorded in SEMANTIC-SYNTAX-INVENTORY.md.

## Representation and original projection

Keep SyntaxNode's existing six Long fields and SyntaxResult's existing fields.
Publish the detail already validated by the same parser as ordinary ordered
children in the same private arena. No checker-local source grammar, sidecar
source copy or second parser is introduced. Node indexes remain private.

The added node roles are Declarator (77), Keyword (78), ArrayShape (79),
AsClause (80), Initializer (81), Dimension (82), TypeCharacter (83),
AttributeValue (84) and Modifiers (85). These are internal comparison identities,
not new source keywords, public IDs or a semantic storage choice.

| Existing parent | Added ordered detail |
| --- | --- |
| Header for a procedure | Optional Modifiers, written Sub/Function Keyword, existing Name/Parameters/ResultType |
| VariableDecl/ConstantDecl/Field | Optional Modifiers, ordered Declarator children |
| Declarator | Typed Name, optional ArrayShape, AsClause and Initializer |
| Parameter | Optional/passing Keyword children, Name, optional ArrayShape, AsClause and Initializer |
| ResultType | AsClause, containing TypeName and optional result ArrayShape |
| AsClause | Optional New Keyword, TypeName, optional result ArrayShape |
| TypeName | Name components, optional fixed-length Literal |
| Name with a suffix | One TypeCharacter child for the parser-selected suffix |
| ArrayShape | One Dimension per rank/bound tuple; each has zero, one or two bound-expression children |
| Attribute | Existing qualified target followed by ordered AttributeValue children, each containing the already validated Name/Literal/signed value |
| Option | Recognized Keyword/value Literal children |
| Exit/EndMarker | The written target Keyword |

Rank-only dimensions use zero-width original comma/closing-parenthesis points.
They are the only additional empty detail leaves. All other detail nodes own
their complete written span and their children obey containment/source order.
Modifiers collect exactly the prefix words recognized at that declaration.
The native module Header retains its original span; admitted envelope/project
identities remain authoritative rather than being independently decoded again.

The old comparison projection discards the added children of formerly opaque
VariableDecl/ConstantDecl/Field/Parameter/ResultType/Attribute/Option/Exit/
EndMarker/TypeName/Name leaves. For headers with specified children, filter only
the added Keyword and Modifiers children; a previously opaque Header retains
its existing projection. A NativeType/RecordType projection filters Modifiers.
The original hand-authored fixtures are not rewritten to fit production output.
Always validate the complete physical graph before applying this projection.
Detailed fixtures select exact physical comparison, including every detail node;
they cannot use the opaque-leaf exception to hide a missing/wrong child.

## Ownership, budgets and costs fixed before coding

Source/token views remain borrowed immutable input. All nodes, expressions,
modifier lists and bounds are constructed privately and published together by
the existing whole-result copy. Failure at any new allocation/root boundary
retains the complete old result and owners; fresh storage failure is seeded
before managed entry. No extra output array or worker capture is required.

MaximumNodes counts every live detail node, including scratch nodes that the
existing ambiguity logic later rewinds. Depth/pending traversal budgets remain
the qualified explicit-stack budgets. The 24-byte node and 16-byte native result
wrapper ABI remain unchanged. Published detail may exceed the old projected node
count; it must not be hidden from node admission or memory measurements.

Preset bounds: on successful parsing, physical nodes must be at most six times
the qualified token count plus eight. Extra detail construction performs one
bounded node write and attachment per added node, with no subtree/table copies.
Preserve zero source-payload copies, geometric growth, exact final trim and
whole-result publication accounting from PARSER-IMPLEMENTATION.md. Retain its
token/node-based work bounds; report any genuine failure instead of increasing
constants after observing it. The historical assertion that opaque validation
needs four times more scratch nodes than final output no longer applies when
those formerly discarded nodes are now part of the output. Replace that
structural premise with explicit physical-node and detail-copy measurements.

## Acceptance

Independently authored detailed cases cover every row above, multiple declarators,
omitted/explicit passing modes, defaults, ranks/bounds, suffixes, modifiers and
attribute values. Compare original spans and full graphs through both source-
built stages. Retain every old syntax/reject/deferred case and failure/resource/
root/worker/copy gate. Add comparator corruption controls for detail kind, value
span, missing/extra detail and the full-versus-projected comparison distinction.
Update the inventory to distinguish the initial gap from current retained fields.
The semantic checker may consume only the resulting qualified information.
