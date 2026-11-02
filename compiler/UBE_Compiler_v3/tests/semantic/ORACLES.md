# First semantic contract oracles

These are independently authored proposed answers, not current compiler output.
`cases.json` contains complete small native MODULE projects in canonical source
order. Package `app` is the root executable; `ubecore` denotes its one explicit
reference Library fixture, not a replacement for real UBECore. Every source,
including unused referenced bodies, remains subject to the bounded contract.

`definition.json` names contract sections, symbolic diagnostic/deferred domains,
types and fact modes. `inventory.json` pins function-local evidence in today's
production parser. `obligations.json` defines future native acceptance; those
obligations are not executed by the definition checker.

Witness text is an ordinal substring of an original source. `occurrence` is
zero-based and includes overlapping occurrences. Optional `within` restricts
that search to one unique exact context, avoiding ambiguous one-letter anchors.
`mode` defaults to span; start/end select a zero-width boundary of the anchor;
eof selects original EOF with empty text and no occurrence/context. Optional
numeric anchors independently assert UTF-8 byte, scalar, line and column.
The coordinate control includes BOM, CRLF, tab and a supplementary Unicode scalar.

Expected facts observe a selected construct, not a physical semantic arena.
Bindings refer to an independently declared target and its original name span.
Types distinguish actual nominal identities. Constant decimal values are written
by the author; the definition checker checks representability but does not
calculate an expression's answer. Conversion facts distinguish identity/checked;
argument facts distinguish aliases/temporaries/defaults/zero and omitted slots.
The detailed named-call case maps source-ordered First()/Second() to parameter
indexes 1/0 and requires left-to-right evaluation. It must not be reordered by
signature order. These are targeted observations, not exhaustive serialized
semantic results. Native comparison must validate the complete actual graph,
compare facts at their exact identified sites (including absence on failed
publication), and reject extra/conflicting facts at those sites. Independently
author complete result streams for representative integration programs before
the native gate; serial/parallel full-stream equality alone is not a language
oracle. No current definition assertion claims those native streams exist.

Cases isolate one diagnostic except explicit ordering cases. A fixture's `at`
is its exact primary span. Source-consistency checks cannot prove the semantic
choice is right; review the source, expectation and normative rule together.
The production checker is not used to write or repair an expected answer.
The fixture authoring command did not run a compiler, reference evaluator or
host expression calculation to derive an expected UBE result.

Run from the repository root:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-semantic-contract.ps1
```

The report below `bootstrap/out/semantic-contract/` records original resolved
positions, inventory evidence/lines, input/artifact hashes, assertions and
deliberately corrupted negative controls. It keeps definition consistency,
unchanged accepted identities and actual native qualification separate.
The owner-confirmed contextual/default integer-literal rule is included;
unreviewed suffixed signed-minimum and hex/octal boundary details remain deferred.

The initializer and split-assignment 40000 - 10000 cases require a Long constant
30000, conversion to Integer, and an explicit compile-time-folded observation.
Ordinary assignments/initializers with known final overflow or division by zero
are rejection cases. A separate runtime expression includes a foldable literal
subexpression, without permitting reassociation or evaluation of runtime values.
These are requirements on the future checker; definition/source-admission gates
do not demonstrate that it already folds or diagnoses those operations.

The separate `tools/check-semantic-inputs.ps1 -DefinitionReport <report>
-CliReport <qualified-current-source-cli-report>` runs every corpus source
through both already qualified frontend executables. It predicts syntax
admission, explicit conditional deferral, and existing syntax/envelope failures
before running, comparing exact exit/stdout/stderr and coordinates. This catches
an accidentally invalid semantic fixture without using the compiler to derive
any binding/type/value answer. It does not perform project/reference binding or
qualify new syntax detail publication. The unknown reserved attribute fixture
belongs to the existing envelope failure, not a second semantic diagnostic.
