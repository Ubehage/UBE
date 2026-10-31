# Scanner acceptance data

This is the independent acceptance definition for `../../SCANNER-CONTRACT.md`,
not a production scanner or an executable language implementation.

From the repository root:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-scanner-contract.ps1
```

`tokens.json` contains 62 hand-authored source partitions. Each `pieces` entry
is `[kind, exactOriginalText]`; a third true element denotes a zero-width
synthetic final Newline. Eof is also zero width. Concatenating physical pieces
must reproduce the source exactly. Trivia is included so omitted text cannot
hide tokenization mistakes. Selected independently written numeric anchors
check original byte/scalar offsets and one-based line/column coordinates.

Expected decoded string/bracket values, known simple-fold identities, date
candidate validity and directive-boundary witnesses are separate data. Context
such as expression, file-number or logical-directive is an explicit fixture
witness, not a production command-line flag or chosen scanner API. Date
candidate recognition does not qualify literal conversion; directive witnesses
do not evaluate branches or define malformed inactive-text recovery.

`envelopes.json` contains 40 independently authored native/legacy outcomes.
Substring/occurrence anchors designate original metadata or diagnostic spans.
Their coordinates are computed by the test oracle; these are not independently
written numeric envelope positions. A native-header token vector additionally
supplies independent numeric positions. The identity field is the decoded
quoted source spelling; optional canonicalIdentity separately removes identifier
brackets/escapes. Legacy syntax recognition with identity absent is not package
admission or an invented filename fallback.

`words.json` records 174 alphabetic structural-grammar/literal/comment words.
The declared source basis distinguishes documented reserved/contextual roles,
the primary native-header exception and attribute-only UBE_Name. The nine hard
additions are explicit. Ordinary-call eligibility is independent of declaration
reservedness. Digit letters and literal suffixes do not become global keywords.

The checker validates schema/coverage, exact partitions/spans, explicit numeric
anchors, raw/decoded value consistency, known Unicode examples, candidate date
oracles and directive witnesses. Negative controls require rejection for missing
source text, wrong byte positions, absent metadata and undefined diagnostic
labels and redundant synthetic newlines; ordinal comparisons preserve zeroes and distinguish normalized/full-fold
spellings. It never derives expected token boundaries from another compiler.

Identifier/folding sanity checks intentionally recognize only the explicit
fixture scalar set; they are not an implementation of all Unicode 18 data.
The coordinate oracle uses strict UTF-8 encoding plus Unicode scalar iteration
over host UTF-16 strings, independently of the UBE decoder. It performs prefix
recounts on small bounded test data; no production cost claim applies to it.

The checker does not parse source, validate complete envelope grammar, bind
names, evaluate conditional compilation, emit code, or prove production native
failure/resource/performance behavior. Those obligations remain in the contract
and become actual implementation gates later. `../../SCANNER-EVIDENCE.md`
records exact results, readiness probes and the next handoff.
