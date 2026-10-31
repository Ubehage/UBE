# Parser definition oracles

This fixture gate defines the next grammar-consumer item in the current v3
roadmap. It checks independently authored expectations; it does not parse source
or select a production parser representation. Run from the repository root:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-parser-contract.ps1
```

The three JSON files share schema `ube-parser-cases-1`. Each case names an
expression, statement or unit entry and one outcome: `syntax`, `reject` or
`deferred`. Syntax supplies an expected phrase shape; rejection supplies a
diagnostic classification and witness; deferred cases supply a reason and make
neither an acceptance nor a rejection claim. Optional `semanticChecks` on syntax
cases record later obligations, not completed validation. Optional `notes` are
text only. Existing EBNF production names are referenced directly and checked
against the current normative grammar.

Every shape is a nested array `[Kind, witnessId, ...childShapes]`. Kind spelling
and child counts use the agreed logical fixture vocabulary. They are not a
runtime tree layout, token ABI, arena, visitor API or parser implementation.
Entry/root domains are checked, as are parent containment, original source order
and non-overlapping siblings. Witnesses need not cover unselected parts of a
unit. They cannot be reconstructed from an existing compiler's answer.

Witness `text` is found with ordinal comparison. `occurrence` is zero-based,
defaults to zero and counts overlapping occurrences. Without `at`, the witness
covers the complete original substring. `at: "start"` and `at: "end"` require
nonempty anchor text and resolve to a zero-width point at the chosen substring
boundary; the report retains that text separately. `at: "eof"` is the only
empty-text witness and resolves to physical source EOF. `Omitted` nodes require
zero-width points, so a comma can locate an omitted argument without pretending
that the comma is its source content. Other nodes require nonempty construct
spans, except empty `Block` and `StatementList` nodes.

The coordinate oracle strictly encodes UTF-8 and counts Unicode scalars over
host UTF-16, independently of UBE's decoder. An initial BOM consumes three bytes
and no content scalar; CRLF consumes two scalars and advances one line. Tabs
occupy one column. Optional independently written numeric anchors assert byte,
scalar, line and column starts. The gate rejects isolated CR, malformed Unicode,
unknown fields, undefined grammar references, unknown node/diagnostic kinds,
wrong arity, missing diagnostics and contradictory outcome fields. Its finite
file, source, witness, node and depth limits protect this test tool only; they
choose no production parser resource contract.

Those test-only guards are 1 MiB per JSON file, 512 cases per file, 64 KiB of
source per case, 256 witnesses per case, 4096 shape nodes and 32 nested shape
levels. They are not UBE language limits or future parser limits.

Negative controls mutate independent fixture expectations and require rejection
for absent original text, wrong byte/CRLF scalar anchors, unknown grammar rules,
undefined nodes, broken arity, missing witnesses/diagnostics, unsupported outcomes,
deferred obligations relabeled as accepted syntax, escaped parent spans and
overlapping siblings. These controls verify the consistency checker. They do
not prove that it can recognize an invalid source program.

Before checking new definitions, the tool audits the existing accepted 501-check
selection, its 136-check source bootstrap, all 13 child reports, source/tool and
artifact identities, and all five Unicode raw/provenance files. It snapshots the
selection and every referenced accepted identity and checks them again afterward.
The 13 feature names must be unique and complete; the managed substrate must
record its current-source build and the scanner must remain formally qualified.
The selected baseline's actual manifest hash is recorded for each run, allowing a
freshly qualified cohort without selecting it by a temporary build directory.
The run writes only a new
`bootstrap/out/parser-contract/<id>/report.json`; it never rebuilds or republishes
the selection. The report distinguishes this unchanged-baseline audit from new
definition assertions. No parser, recovery, literal conversion, binding,
conditional evaluation or complete-program validity is qualified by this gate.
