# Scanner and source-envelope acceptance

Status: acceptance contract for the scanner item in `Roadmap.md`. Implementation
and native qualification are recorded separately in `SCANNER-EVIDENCE.md`.
No parser, backend, scheduler, public token ABI, arena layout or compiler
generation is selected here.

## Authority and scope

`../../lang-doc/language-spec.md` sections 1–3 and the normative
`../../lang-doc/grammar/ube.ebnf` define the language. The conditional directive
grammar is normative too. The primary specification/focused contracts outrank
conflicting expanded-definition wording; historical audits are rationale.
`SOURCE-INPUT-CONTRACT.md` defines the already qualified input and coordinates.

This item defines hand-authored acceptance data and checks its consistency,
exact original substrings and positions. It does not parse the fixtures with an
existing compiler and call that an independent expected answer. The fixture
checker is test-only PowerShell over strict UTF-8 and scalar coordinates; it is
not a second production scanner. Actual UBE scanner implementation and native
qualification are separate obligations after this definition.

## Input, ownership and output meaning

Input is a qualified `SourceDocument`: exact UTF-8 bytes, optional initial BOM,
LF/CRLF, no normalization or inserted bytes. Scan by borrowing its zero-based
Bytes array ByRef. The document's owner keeps it alive and immutable while any
token/metadata span refers to it. Do not assign a whole document/array per token.

Each accepted lexeme has a kind, original half-open byte span and original
scalar/line/column start/end. The symbolic fixture kinds are a logical test
vocabulary, not frozen numeric enum values or record layouts. A spelling is a
view into the original document. Decoded string/bracket content and folded
lookup identities are separate facts; they never replace the original spelling.

Whitespace, comments, continuations, BOM and designer fragments remain available
through original spans, even when omitted from a parser's logical token stream.
No cooked literal storage, string interner or generic collection is a
prerequisite. Literal value conversion/range checks belong to their language
rules and must not be implemented through host locale or host numeric defaults.

One mutable scan instance owns its cursor, pending output and diagnostics.
Independent scans share only immutable documents/data. Build results privately;
publish the complete output only on fresh success. Allocation/publication failure
preserves every previous token, metadata field and source reference. Caller
failure fallbacks are initialized before managed calls, since admission can
return neutral False before the body and leave ByRef outputs untouched.

## Original positions and logical lines

Offsets are zero-based, half-open original byte/scalar ranges; line/column are
one-based Unicode scalar coordinates. An initial BOM occupies three bytes and
zero content scalars. CRLF occupies two original scalars but advances one line.
Tabs occupy one column; combining marks occupy their own scalar position even
when not valid bare-name characters. Never report UTF-16 code-unit columns.

Physical NEWLINE spans are LF or CRLF. Continuation removes its HSPACE + `_`,
optional HSPACE/comment, physical newline and following indentation from the
logical sequence, without changing source positions or bytes. An underscore
inside a name, quoted string or bracket name is not continuation.

Removing continuation syntax never joins neighboring lexemes. It supplies the
grammar's spacing/spacing1 boundary: `Sub _` newline ` Main` remains Sub and
Main, not SubMain. Logical-line reconstruction for tooling uses a separating
space while original physical spans remain unchanged.

Supply a final logical NEWLINE when missing, including empty/BOM-only input.
Its span is zero width at physical EOF; EOF follows at the same position. There
is no SourceDocument mutation. A physical newline consumed by a continuation is
not a remaining logical terminator. A final continued line therefore still
needs a final logical terminator; statement completeness is checked later.

## Lexical grouping

- HSPACE is ASCII space/tab only. NBSP and other Unicode whitespace do not
  silently become HSPACE. Outside accepted quoted/metadata contexts, an unknown
  scalar produces a controlled `UnexpectedCharacter` diagnostic.
- Bare names start with category Letter (Lu/Ll/Lt/Lm/Lo) or `_`; subsequent
  scalars are those plus ASCII `0`–`9`. Combining marks, non-ASCII digits and
  joiners are not silently accepted as identifier parts.
- Bracket names are nonempty, exclude CR/LF and decode `]]` to `]`. String
  literals exclude CR/LF and decode `""` to `"`; empty strings are valid.
  Apostrophes, colons, fake directives and zero bytes inside these tokens stay
  content. An embedded zero outside an allowed context is an invalid character,
  never EOF. Comments/LINE_CHAR contexts can also retain zero bytes.
- Keywords and identifier identity use Unicode 18 simple C/S folding, not full
  folding, normalization or locale casing. `[Thing]` and `thing` have the same
  name; spelling, brackets and type characters do not create another identity.
- Use longest valid token match. `:=`, `<=`, `>=`, `<>` are indivisible. `==`,
  `!=`, `=>`, `=<` are not invented operators; their component punctuation can
  be scanned and rejected by grammar. Signs remain separate punctuation.
- Integers use ASCII decimal, `&H` hex or `&O` octal with optional adjacent
  `%`, `&`, `^`. Hex A–F are digits, not real suffixes. Thus `1&x` starts with
  integer `1&`; `2^3` starts with integer `2^`. Spaced `1 & x` and `2 ^ 3` have
  separate operators. Identifier type characters remain separate punctuation,
  preserving both `a!b` member access and typed-name grammar.
- A real token requires a decimal point and/or exponent, then at most one of
  `! # @ F R D`. Integer-only `1F`/`1!` must not be silently reclassified as a
  real literal, despite wider VB dialect conventions. Literal value overflow is
  not guessed during raw spelling recognition.
- Apostrophe starts a comment outside quoted content. Rem does so only at a
  grammar-valid statement start and followed by HSPACE or a logical newline.
  `Remember`, `obj.Rem`, `Rem:` are not Rem comments. Colon is a statement
  separator only outside parentheses/literals; `:=` is distinct. A colon inside
  argument parentheses remains punctuation and does not make an expression valid.

## Explicit closure and context boundaries

The specification deliberately leaves some scanner-terminal detail implicit.
The following rules close this consumer contract under the owner's delegated
syntax decisions, while preserving the stated grammar. They are contract
choices, not claims that every spelling was previously documented:

1. Real-text core is `digits '.' [digits] [exponent]`, `'.' digits [exponent]`,
   or `digits exponent`; exponent is `E|e|D|d`, optional sign, then one or more
   ASCII digits. A possible exponent without digits is not part of the longest
   valid real core. A trailing D after a valid point form can instead be the
   existing Decimal suffix. Choose the longest valid full spelling. This accepts
   `.5`, `1.`, `1e+2`, `1D2`, while retaining the grammar's point/exponent rule.
2. `tests/scanner/words.json` classifies the alphabetic grammar vocabulary.
   Structural words retain the documented reserved/contextual roles; the primary
   native-header contextual rule takes precedence over secondary labels.
   Ordinary-call eligibility is recorded separately for Mid/Len/Spc/Tab and
   String/Date/Input/Error/Seek, whose spelling overlaps grammar roles. It does
   not widen legal unbracketed declarations. Source grammar must still allow the
   specified ordinary library calls (explicitly Mid$); context-aware callee
   consumption/binding is separate from raw word classification. No reserved
   spelling invokes a privileged builtin implementation. Single-letter
   digits/suffixes are never globally reserved. The
   explicitly specified nine hard additions remain reserved. Any reserved token
   can be consumed as a member after `.` or `!`; that does not permit an
   unbracketed declaration with that name. Library names absent from grammar
   remain names. The catalogue covers the current normative grammar, not just
   the compiler's own subset.
3. Date/file/directive `#`, Rem statement starts, contextual words, and opaque
   designer fragments require their documented grammar context. Fixtures may
   state that context explicitly. A complete scanner/parser consumer must deliver
   the correct grouping; this contract does not force parser-free guessing or
   invent a public context-switching API. In expression-literal context a paired
   `#...#` preserves a date candidate; file-number context keeps `#` separate.
   Invariant date shape/calendar validation must precede claiming a valid source
   program. Raw candidate recognition is not that validation.
4. Conditional directives occupy complete logical lines after comment and
   continuation recognition. Recognize directive boundaries without evaluating
   symbols in this item. Selected-branch evaluation, symbol scoping, duplicate
   constants and inactive-text recovery are acceptance obligations of the
   conditional-compilation consumer. Malformed inactive quoting/continuation
   recovery is not silently frozen by these raw scanner fixtures. No fixture
   claiming full inactive-branch acceptance is included.

The fixture vocabulary distinguishes Keyword/Identifier only when the expected
context/classification is explicit. Contextual identifier spellings retain their
original bytes. Calendar-invalid date candidates and grammar-invalid punctuation
can be lexically present while a later check fails; do not report them as valid
programs. Conditional compilation and literal conversion are not implemented by
passing this definition gate.

## Native and legacy envelopes

Native header is `UBE SOURCE decimal-digits kind`, then `Attribute UBE_Name =
string-literal` on the next logical line. Kind/extension pairs are MODULE/.bas,
CLASS/.cls, FORM/.frm, CONTROL/.ctl, ignoring case. Header words are contextual.
Leading horizontal spacing/continuations follow program spacing; leading blank
or comment-only lines are not added to the frozen envelope grammar. Trailing
comments and explicit continuations remain allowed where spacing permits them.

Version is numeric: decimal spelling `01` denotes supported source format 1;
new tools emit canonical `1`. Other numeric versions produce
`UnsupportedSourceVersion`. No machine-integer overflow is required to reject
a very long unsupported version: compare bounded decimal spelling/value safely.

Native identity must be one nonempty decoded UBE identifier spelling (bare or
bracketed, using the ordinary name rules); quoted brackets are source spelling,
not another identity. Preserve the quoted source span and decoded/canonical name
separately. Missing/nonstring/invalid name and duplicate UBE_Name diagnose.
Duplicate identity is anchored at the later attribute even if its value agrees.
The final attribute-name component determines UBE_ reservation; preceding
qualified components name the target. A procedure named UBE_Helper does not
turn its ordinary Description attribute into reserved metadata.
Unrecognized UBE_-reserved attribute names diagnose; the currently defined
qualified Procedure.UBE_Primitive is recognized metadata, whose applicability,
binding signature and declaring ownership remain semantic checks.

Legacy VERSION/Object/Reference prefixes, designer blocks, nameless class
metadata and attribute blocks remain accepted grammar alternatives without a
new opt-in flag. Their textual payload is preserved; it does not become an
implicit manifest reference, COM activation or execution. Locale dates/legacy
code pages still require their separate explicit selections.

Legacy grammar permits no VB_Name. The envelope result reports that identity is
absent, without inventing a filename/designer fallback. Package/component
admission must later define any required identity policy. Duplicate/malformed
legacy identity, VERSION-kind/extension policy, mixed native/legacy identity and
designer-root agreement are not classified by this acceptance set. Package
collisions also belong outside independent single-document scanning. These are
explicit later identity-policy needs, not silently accepted executable semantics.

## Diagnostics and deterministic publication

The fixture labels are stable domain classifications, not numeric diagnostic
ABI commitments. They include UnexpectedCharacter, UnterminatedString,
UnterminatedBracketIdentifier, EmptyBracketIdentifier, MissingSourceHeader,
UnsupportedSourceVersion, SourceKindMismatch, MissingSourceIdentity,
InvalidSourceIdentity, DuplicateSourceIdentity and UnknownReservedAttribute.

Anchor at the offending scalar/lexeme. Missing required envelope material at EOF
has a zero-width original EOF span. Unterminated quoted/bracketed tokens instead
anchor at their opening delimiter and retain their incomplete original lexeme
span through the line end/EOF. Version errors anchor at the version token; mismatch at kind; unknown and
duplicate attributes at the offending qualified attribute name. Report earliest
original byte position first; same-position checks use stable documented domain
order. Required recovery is bounded progress or stop, not unlimited cascading
messages. Allocation/root/domain failures have fresh failure status separately
from malformed-source diagnostics. Success does not clear stale Err.

For equal original byte positions, priority is: quoted/character lexical errors
(UnexpectedCharacter, UnterminatedString, UnterminatedBracketIdentifier,
EmptyBracketIdentifier, in that order), MissingSourceHeader,
UnsupportedSourceVersion, SourceKindMismatch, MissingSourceIdentity,
InvalidSourceIdentity, DuplicateSourceIdentity, UnknownReservedAttribute.
An implementation may stop after the first required diagnostic. This does not
freeze parser/literal/conditional semantic diagnostic precedence outside this
consumer. Malformed input can return its scalar failure/diagnostic separately;
it does not authorize publishing a partial successful token result.

The first implementation retains the existing 16777216-byte source limit and
must take an explicit maximum emitted-record count, initially 1048576, including
retained trivia/synthetic records. Check that limit before growth. The limit is
a controlled resource failure, not a new syntax restriction. Nesting work uses
an explicit bounded stack or bounded iteration, with the configured depth
reported in evidence; untrusted source never determines unbounded host recursion.

## Prerequisites and future native acceptance

Already qualified: exact source snapshots, allocation-free UTF-8 decoding,
ordinary scalar/nested records and typed one-dimensional array Length/TryResize/
TryCopy, managed roots/copy/failure behavior. A supplemental accepted-tool probe
demonstrates ByRef geometric append to token-shaped scalar record arrays without
a whole-array assignment in each append; it is not a scanner cost/failure proof.

Required only when implemented: ordinary UBE cursor/lookahead, Unicode 18 Letter
membership/simple fold over independently validated versioned data, and the
compiler's actual token append/publication code. A bounded ASCII version parser
is needed for envelope metadata. Neither generic collections, a new String,
raw-address API, new intrinsic roles nor a scheduler is justified by this item.

Before using the scanner for self-hosting, also reconcile the current bootstrap
source's permissive declaration names with the strict catalogue. A focused
review found SourcePosition.Line, three Input parameters, one Input local and
the low-level Preserve parameter. Ordinary nonreserved renames are the narrow
route. Accepted v2 currently rejects bracketed field/parameter/local declarations,
so brackets would introduce an unnecessary additional bootstrap prerequisite.
The runtime behavior already qualified by the 470-check gate remains intact;
that gate never established complete frozen-native syntax conformance.

Before claiming production scanner qualification, require native tests through
both accepted v2 stages with intact production source and actual UBECore
Reference, byte-identical LLVM and independent fixture comparisons. Verify:

- Every specified token/metadata/diagnostic span and every UTF-8 split boundary;
  both newline forms, BOM, empty source, quoted zeroes and exact raw preservation.
- Fresh failure, stale Err, explicit root-admission exhaustion and forced token
  allocation/growth/publication failure preserving complete old output.
- Four bounded native workers with private outputs and shared immutable input;
  deterministic ordering, early-return cleanup and zero residual roots/payloads.
- Actual byte reads/Feed calls, source copying, token growth/copy/allocation and
  cleanup costs across sizes, token densities and long quoted/name/comment spans.

Let N be source bytes, T token count, R measured record stride and C capacity.
Source payload copying during scanning must be zero. Target no more than two
decoding traversals of source content if a separate envelope pass is needed;
separate any further cooking/folding work and count actual executed operations.
Capacity starts at eight and doubles with guarded arithmetic: C=8 for 1..8
tokens; otherwise T<=C<2T. Growth payload copies <2RT; publication <=2RT;
combined <4RT, with field initialization/padding excluded and separately stated.
Report actual requested allocations/zero initialization, array headers, workspace,
root storage, retained old output and source bytes separately. A fixed initial
eight-record allowance handles small T. No wall-time or full compiler throughput
promise is derived from these budgets.

Versioned Unicode raw input bytes/hashes, license/provenance, interval/mapping
invariants and independent exhaustive table comparison are prerequisites for
the new UBE implementation. Current clean bootstrap generated headers are not
an independent full-data oracle. Do not substitute host Unicode tables, locale
casing or a new privileged intrinsic. Evidence and remaining qualification are
recorded separately in `SCANNER-EVIDENCE.md`.
