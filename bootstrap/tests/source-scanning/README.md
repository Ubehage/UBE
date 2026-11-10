# UBE source-scanning acceptance

Run the independent gates with an existing VB6-built bootstrap:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/source-scanning/check.ps1 -BootstrapExe <executable>
rtk proxy powershell -NoProfile -File bootstrap/tests/source-scanning/utf8-check.ps1 -BootstrapExe <executable>
rtk proxy powershell -NoProfile -File bootstrap/tests/source-scanning/allocation-check.ps1 -BootstrapExe <executable>
rtk proxy powershell -NoProfile -File bootstrap/tests/source-scanning/syntax-check.ps1 -BootstrapExe <executable>
```

The enlarged main gate passed 86 groups against the VB6-built executable in
`ube project loading 4512f340-a4e4-4aaf-98c4-de2e5192b324/build`.
Evidence: `ube source scanning 43e03795-4ad7-4c6f-8fa3-d7090b5fdf3b`.
The earlier allocation gate passed 42 checks with evidence
`ube scanner allocation 0c47b7d3-e816-4da9-b988-cd4b42f49150`.
The UTF-8 gate ran 37 cases at both optimization levels plus its negative control;
the syntax gate separately passed 13 groups.

The main gate compiles the actual `compiler/src/SourceScanner.bas` and portable
`Utf8.bas`, reads real files through FileBytes, and checks all seven fields of
every token against manually authored token chunks. Expected physical positions
are calculated from those explicit chunks, not by a second lexer. The checked-in
Arithmetic example must match its authored source exactly before scanning.
Native O0/O2 runs share the same emitted source LLVM. Changing an actual input
file from word `x` to symbol `+` must fail the unchanged token oracle.

Coverage includes native headers, numeric spellings and suffixes, longest-match
symbols, escaped strings/brackets, BOM, Unicode strings/comments, CRLF/LF,
physical continuations, contextual Rem and member names. Exact first diagnostics
cover malformed encodings even in ignored comments, invalid control characters,
truncated quoted/numeric forms, dangling continuations, unsupported assembly,
dates/directives and non-ASCII identifiers. Input and token bounds include a
4096-byte quoted token/comment, 128 decoded identifier characters and exactly
4096 tokens including synthetic terminals. The next token must fail cleanly.

The allocation gate separately rejects each of four allocation stages, preserves
the caller's prior tokens with Count zero, and retries successfully. It checks
nonzero array bounds, recursive-depth failures and released allocations. The
UTF-8 gate checks scalar boundary encodings, malformed/truncated forms, ranges,
physical widths, sticky errors and a changed-input control. The syntax gate
checks the compiler admissions required by the source implementation.

ControlFlowProbe is real UBE code exercising every admitted Do form, nested
Exit Do, runtime subtraction/Or/Not, and successful/failing If/Do conditions.
Its normal runtime input returns zero at O0/O2; its negative control returns
exactly 22. These checks establish the approved skip-entire-construct behavior
for failed conditions, rather than substituting False.

## Scanner interface

`SourceScanner.TryScan(Source(), Tokens(), Count, Diagnostic) As Boolean` uses
immutable zero-based Byte storage and returns an independent exact token array.
The caller retains the matching source bytes while consuming its spans. Count
and Diagnostic require separate storage that does not alias the Tokens backing
array; this precondition is necessary for the failed-scan preservation guarantee
under ordinary ByRef alias semantics. Utf8's byte-width and UTF-16-width outputs
likewise require distinct variables.

Token kinds are 1 word, 2 bracketed identifier, 3 number, 4 string, 5 symbol,
6 newline and 7 EOF. Word tokens retain spelling; reserved-word classification
remains a parser responsibility in this bounded profile. ByteStart/ByteLength
index original bytes from zero, including a possible initial BOM. Utf16Start,
Line and Column begin at one after the optional BOM. UTF-16 lengths count
surrogate pairs as two units. No Unicode normalization occurs.

The final physical EOF position is always retained. A zero-length newline is
inserted only when the last emitted token is not already a newline, matching
the existing bootstrap stream behavior even after a trailing ignored comment.
Strings and bracket spellings retain their raw quoting/escaping as source spans.

Diagnostics contain Code, Reason, ByteOffset, Utf16Offset, Line and Column.
Code 1 is source encoding/control validation; 2 malformed lexical input;
3 an explicitly unsupported lexical feature; 4 a bound; 5 allocation failure;
6 a controlled runtime/storage failure. Reason values distinguish the cases in
SourceScanner without allocating diagnostic String text. Failure publishes no
partial token vector and returns Count zero; an older independent token vector
remains unchanged. Private helpers propagate unexpected fresh FAIL to the
public handler, which writes diagnostics directly without another call frame.

The scanner admits at most 1,048,576 source bytes and 65,536 tokens, including
synthetic newline/EOF entries. Raw token text remains limited to 4096 UTF-16
units and identifiers to 128 decoded ASCII characters. It scans the
existing ASCII identifier profile with strict Unicode text inside comments and
strings. Unicode identifier tables, conditional preprocessing, assembly
payloads and general String storage remain outside this scanner's profile.
The separate module-parsing gate exercises the UBE-written syntax parser.

The enlarged-capacity gate passed 86 groups, including exact 1 MiB source and
65,536-token acceptance, terminal-token overflow, overlong closed/unclosed
quoted tokens and unchanged runtime negative controls. Evidence:
`ube source scanning 43e03795-4ad7-4c6f-8fa3-d7090b5fdf3b`.
