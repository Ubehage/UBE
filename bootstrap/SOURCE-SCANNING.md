# Source-scanning dependency

This increment belongs to the existing bootstrap-dependencies work item. The
VB6 SourceLexer provides the dependency evidence: byte classification and
token counters need subtraction, eager Or and Not; its traversal uses pre-test,
post-test and unconditional Do loops with Exit Do. The single identifier-label
For traversal can use the same Do form. This does not require For counter/step
semantics, managed String storage, or additional arithmetic operators.

## Language admission

The extension admits checked integer subtraction, Boolean/integral Or and Not,
and Do/Loop with one While/Until condition before or after the body, or no
condition. Exit Do exits the nearest enclosing Do. Existing numeric promotion,
source-order evaluation and checked conversions apply. Or is eager; it is not
OrElse. Not binds below comparisons and above And; And binds above Or.

The owner approved default continuation after the entire If or Do construct
when its condition fails. This covers ElseIf, Until and post-test conditions.
Enabled label handlers retain their existing behavior, and failures while a
handler is active skip the construct without recursive entry. Body statements
retain ordinary statement-local continuation. Resume statements remain outside
the bootstrap subset. The normative rule is in
[`error-handling.md`](../lang-doc/error-handling.md).

## Source ownership and text boundary

The UBE scanner lives in `compiler/src/SourceScanner.bas`. It consumes retained,
zero-based UTF-8 bytes; it does not reopen files, mutate input, or store global
current-source state. The caller retains source bytes for the lifetime of token
spans. Its portable UTF-8 validation helper belongs to UBECore. No String
representation or implicit bytes-to-String conversion is introduced.

The bounded scanner follows the current VB6 lexer's admission: ASCII bare and
bracketed identifiers, numeric spellings, quoted strings, longest-match
symbols, statement-position Rem comments, apostrophe comments and explicit
line continuations. UTF-8 in comments and strings is validated, including
surrogate and overlong encoding rejection. General Unicode identifiers,
directives, date literals and assembly remain explicitly unsupported.

Byte offsets start at zero in the original input, including an optional BOM.
Physical lines, UTF-16 columns and UTF-16 offsets start at one after that BOM,
matching the VB6 decoded-source position convention. Four-byte Unicode scalars
advance a UTF-16 position by two. Original spelling is retained through byte
spans rather than duplicated text. Continuations suppress logical newline
tokens but preserve physical locations. EOF retains its actual physical
position; a final logical newline is inserted when absent.

## Scanner interface

`SourceScanner.TryScan(Source(), Tokens(), Count, Diagnostic)` returns an
ordinary Boolean status. All arguments are ByRef. Source is a Byte array,
Tokens contains SourceToken records, Count is Long, and Diagnostic is a
ScanDiagnostic record. Token kinds are Word=1, bracketed identifier=2, Number=3,
String=4, Symbol=5, Newline=6 and EOF=7; word classification remains a parser
responsibility. Each token stores Kind, ByteStart, ByteLength, Line, Column,
Utf16Start and Utf16Length as Long fields.

Success publishes an independent complete token array, its Count, and a zero
diagnostic Code. Failure after entering TryScan sets Count to zero, preserves
the existing token array and publishes the first diagnostic. A call refused
before entering the procedure follows the ordinary language FAIL contract.
Diagnostics contain Code, Reason, ByteOffset, Utf16Offset, Line and Column.
The numeric categories are:

| Code | Meaning | Reason values |
|---|---|---|
| 1 | Invalid source encoding/text | 1 invalid UTF-8; 2 control character; 3 lone CR |
| 2 | Malformed lexical token | 1 quoted token; 2 numeric spelling; 3 continuation; 4 character |
| 3 | Unsupported lexical form | 1 assembly; 2 unsupported identifier/character/literal |
| 4 | Admission limit | 1 source bytes; 2 token length; 3 token count; 4 identifier length |
| 5 | Token storage failure | 1 allocation/growth/publication |
| 6 | Internal operation failure | 1 propagated language failure; Err retains its code |

The helper `Utf8.TrySequenceWidth(Bytes(), Offset, Length, ByteWidth,
Utf16Width)` validates one strict scalar encoding within the supplied prefix.
Bytes must be zero-based; Offset and Length are ByVal Long, and the two widths
are ByRef Long. It allocates nothing. False clears both width outputs; invalid
encoding or span does not invent a usable character. Source bytes must not
change during a call, and output storage requires exclusive caller access.

## Acceptance

The gate is `tests/source-scanning/check.ps1`, with syntax and binding cases in
`tests/source-scanning/syntax-check.ps1`. `utf8-check.ps1` separately executes
37 scalar-width cases at O0/O2 and rejects its changed-input control;
`allocation-check.ps1` passed 42 checks for failed allocation, output
preservation, retry, depth limits and invalid source bounds. Native acceptance
must exercise actual
UBE file input and scanning at O0/O2, compare token fields with independent
expectations, check malformed-input diagnostics and retained output, and reject
a meaningful changed-input control. ControlFlowProbe separately checks loop
forms, operators, failure continuations and active handlers.

Exact limits, executed counts and artifact paths belong to the gate README and
`../compiler/Progress.md`. No complete UBE compiler, self-hosting, managed text,
or concurrent compilation is established by this dependency gate.

The current array boundary limits scanner input to 4,096 bytes and token output
to 4,096 records, including synthetic terminals. Larger real compiler modules
still need a justified storage extension. Count and Diagnostic must use output
storage independent of Tokens; ordinary ByRef aliases otherwise retain their
explicit mutation semantics. Successful scans preserve Err; ordinary lexical
rejection is a False status plus a diagnostic, not language FAIL. Allocation
failure additionally retains Err 7. Internal language failures are propagated
to the public diagnostic boundary rather than silently leaving a cursor still.
