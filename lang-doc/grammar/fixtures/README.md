# UBE 1.0 grammar fixtures

This directory is the source-level conformance corpus for the candidate UBE
1.0 grammar. It is deliberately dependency-free and contains complete source
files rather than isolated snippets.

The fixture index is `expectations.csv`. Its `grammar_expected` column records
whether a conforming parser must accept or reject the file. `later_expected`
records a semantic result where that distinction matters. A value of `n/a`
means the fixture only establishes grammar behavior.

The categories have distinct purposes:

- `positive` exercises representative accepted productions.
- `negative` contains one intentional syntax error per file.
- `ambiguity` is syntactically valid but must be rejected during name or
  semantic analysis rather than resolved by source order.
- `recovery` contains more than one syntax error. A parser must reject it and
  should report both marked errors without crashing or looping.

Run the repository-owned checks from the repository root:

```powershell
& ./lang-doc/grammar/fixtures/validate-fixtures.ps1
```

The runner checks the corpus structure, headers, index, intentional-error
markers, and the normative EBNF's static validation. It does not claim to parse
the fixtures yet. Once the v3 parser has a stable command-line conformance
interface, its parse results must be added to this runner; until then the CSV
is the machine-readable oracle.

