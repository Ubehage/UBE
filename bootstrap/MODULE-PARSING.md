# Retained UBE module syntax

The existing bootstrap dependency item now includes an ordinary UBE module
parser in `compiler/src/SourceParser.bas` and token helpers in
`compiler/src/SyntaxTokens.bas`. It parses the admitted grammar described in
`../lang-doc/bootstrap-profile.md`. The VB6 bootstrap still performs binding,
lowering and builds; parsing the parser's source as data is not self-compilation.

## Caller ownership and publication

`SourceParser.TryParseModule(Source(), Tokens(), TokenCount, Nodes(), NodeCount,
RootNode, Diagnostic)` returns ordinary Boolean status. Source is a retained
zero-based Byte array; Tokens is the matching immutable zero-based
`SourceScanner.SourceToken` array. TokenCount is ByVal Long. Nodes is a ByRef
array of SyntaxNode; NodeCount and RootNode are ByRef Long; Diagnostic is a
ByRef ParseDiagnostic. Keep matching source, tokens and nodes alive together.
Retain separate caller-owned sets for multiple modules. No mutable global parse
state or shared current module is introduced.

Parsing builds a private candidate. Success publishes an independent node array,
its count, root ID 1 and diagnostic Code zero. Failure after entry sets count
and root to zero and preserves the previous node array. Save the old count/root
separately if it must remain usable after a rejected replacement. Inputs and
output variables must not alias; ordinary ByRef mutation is not suppressed.
A call refused before entry follows language FAIL. Internal helper FAIL is
propagated to the public diagnostic boundary; it cannot silently leave a cursor
unchanged and continue parsing. Successful parsing preserves sticky Err.

## Retained nodes

Node IDs are one-based; array storage is ID minus one. Zero means no link.
Each SyntaxNode contains Kind, Value, Modifier, Suffix, IsIntrinsic, NameToken,
TypeFirstToken, TypeLastToken, FirstToken, LastToken, Parent, FirstChild,
LastChild, NextSibling, ByteStart, ByteLength, Utf16Start, Utf16Length, Line and
Column. IsIntrinsic is Boolean; the other fields are Long. Nodes retain raw
token references rather than allocating text. Token indices are zero-based;
absent name/type references are -1. Source positions follow the scanner's byte
and physical UTF-16 conventions.

| Kind | Code | Kind | Code |
|---|---:|---|---:|
| Module | 1 | Option | 2 |
| Variable | 3 | Constant | 4 |
| Type | 5 | Field | 6 |
| Sub | 7 | Function | 8 |
| Parameter | 9 | Primitive attribute | 10 |
| Body | 11 | Array shape | 12 |
| Name | 13 | Member | 14 |
| Call | 15 | Number | 16 |
| Boolean | 17 | Unary | 18 |
| Binary | 19 | Group | 20 |
| Assignment | 21 | If | 22 |
| Then branch | 23 | Else branch | 24 |
| Do | 25 | Exit | 26 |
| GoTo | 27 | Label | 28 |
| On Error | 29 | | |

Value stores operator token codes for unary/binary/Boolean nodes and the exit
keyword code for Exit. Calls use expression=0, statement=1, explicit Call=2;
If uses block=1 or inline=2; Do uses always=0, pre-While=1, pre-Until=2,
post-While=3 or post-Until=4. Array shapes use fixed=1 or dynamic=2. On Error
uses default=0, Resume Next=1 or label=2. Modifier retains visibility or passing
mode keyword codes; Suffix retains the asserted scalar type keyword code.
These are source syntax facts, not intrinsic binding authority or a foreign ABI.

Children preserve evaluation order. Calls retain callee then arguments;
assignments retain destination then RHS. Conditional loops retain condition
then body, including post-test loops. ElseIf is an If child in its predecessor's
Else branch. Array-shape children precede any initializer. An omitted lower
bound is a synthetic Number node with NameToken=-1, Value=0 and zero span.
Empty nodes have LastToken=FirstToken-1. Primitive NameToken identifies the
role string; TypeFirstToken/TypeLastToken identify its declaration target.
The module NameToken identifies its quoted native identity.

## Admission and helpers

The parser covers native envelopes, Option Explicit, typed declarations,
rank-one array shapes, field-only Type syntax, Sub/Function/Intrinsic signatures,
primitive attributes, current scalar expressions, members/index applications,
calls, assignments, labels, GoTo, On Error, If and all five Do forms. Names and
type references are retained without semantic resolution. Forward, mutual and
self-referencing Type spellings can be parsed; recursive layout remains outside
the current compiler's semantic admission. Unsupported String expressions,
Select Case, For, Resume statements, assembly and the broader grammar remain
explicitly unavailable.

SyntaxTokens classifies ordinary ASCII words and punctuation, recognizes the
admitted integer/decimal-label spellings and compares decoded identifiers with
ASCII case folding. Bracketed names remain identifiers even when their contents
spell a keyword. DecodedIdentifierCode is used only where metadata explicitly
requires a name comparison. Quoted module identities remain bounded ASCII
identifiers. Token spellings are neither globally interned nor copied to String.

Limits are 1,048,576 source bytes, 65,536 tokens, 65,536 syntax nodes and 48
recursive syntax levels per module. Token length remains 4,096 UTF-16 units and
identifier length 128. These are distinct from the VB6 host parser's depth 64
and project token budget. The existing 64 MiB charged allocation quota, 4,096
live blocks, 128-cell frames/finite records and 65,536-cell fixed module context
remain in force. Candidate publication and retained old trees consume that
same quota; the element ceiling does not guarantee every allocation will fit.

## Diagnostics and evidence

ParseDiagnostic contains Code, Reason, TokenIndex, ByteOffset, Utf16Offset,
Line and Column. Categories are syntax=2, unsupported=3, admission limit=4 and
storage/internal operation=5. Reasons identify the rejected rule in the parser;
the first syntax rejection retains the current token location. A propagated
storage failure uses safe initialized coordinates and the current token index,
without risking another read through invalid token storage. Empty source is a
missing-envelope syntax error.

`tests/module-parsing/check.ps1` passed 19 cases at O0/O2 with 4,420 numbered
assertions, including actual SourceScanner, SyntaxTokens, SourceParser, Utf8,
BufferPrimitives and FileBytes trees. It verifies reachability, links, spans,
precedence, argument order, malformed input and retained-output recovery.
Its changed addition-to-subtraction input fails the exact operator assertion 429.
Evidence is `ube module parsing c1842f4e-0926-4ae8-acba-73da249ad277`.
The separate token gate covers 929 tokens, 138 reserved words, six contextual
words and 13 decoded comparisons at O0/O2, with negative control 2. Production-
only assembly checks require no stack-probe dependency. See the
[gate README](tests/module-parsing/README.md) and `../compiler/Progress.md` for
commands, allocation/depth checks and exact artifact paths.
