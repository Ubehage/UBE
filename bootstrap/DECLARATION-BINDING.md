# UBE declaration binding

Status: declaration/signature acceptance passes at O0/O2. Exact evidence and
companion failure-gate results are recorded in compiler/Progress.md.

This component implements the declaration dependency in the compiler roadmap. The parser
retains syntax, while this pass assigns declaration identities and resolves
declared types and procedure signatures across ordered modules. The VB6
bootstrap continues to perform full admitted semantic analysis and lowering.

## Scope and authority

The existing SEMANTICS.md contract and normative language rules remain
authoritative. The UBE pass collects modules, module declarations, procedures,
parameters, function results, locals, Types, fields and labels. Duplicate checks
use their proper case-insensitive regions. Type references resolve to scalar
codes or nominal declaration identities, with visibility and ambiguity checked
before publishing a result. Procedure signatures retain parameter order, rank
and passing mode. Executable entry selection checks the existing Main contract;
library binding does not assign an entry role based on spelling alone.

Resolving a self- or mutually referencing Type identifies an edge in the type
graph. It does not allocate recursive values or establish a runtime layout.
Expression binding, constant evaluation, fixed-bound evaluation, primitive
authority, finite/recursive layout and lowering remain separate responsibilities.
The expression and constant component is described in EXPRESSION-BINDING.md. A
successful declaration pass must never be represented as ANALYZE OK for the
complete program.

## Ownership requirements

The measured existing parser corpus contains 1,203 host-bound symbols and
18,008 nodes. The existing 16,384-symbol capacity is adequate for this corpus.
Source bytes, scanner tokens, syntax nodes and module ranges remain caller-owned.
Flat pools avoid requiring record-owned dynamic arrays; module ranges retain
source identity and allow physical diagnostics to be reconstructed. No global
current project, module, source or symbol table is permitted.

Appending a module may reserve storage, but must not publish a partial logical
module or change earlier committed contents after failure. Binding constructs
a private candidate and publishes its symbol array only on complete success.
Failure resets public count/entry and preserves the previous symbol array;
callers must keep independent outputs and inputs, as with the parser contract.

## Interfaces

`ProjectSyntax.TryAppendModule(Source(), Bytes(), Tokens(), Nodes(), Modules(),
Counts, Diagnostic)` scans and parses one raw module before adding it to the
project. All arguments are ByRef. `ProjectCounts` retains ModuleCount, ByteCount,
TokenCount and NodeCount. `ParsedModule` retains ByteBase/ByteCount,
TokenBase/TokenCount, NodeBase/NodeCount, RootNode and NameToken. Nodes use
one-based global IDs; token indices are zero-based. ByteStart is rebased into
the project pool; UTF-16 offsets, lines and columns remain physical module
coordinates. Consumers use module ranges to recover module-local byte offsets.

`DeclarationBinder.TryBindDeclarations(Bytes(), Tokens(), Nodes(), Modules(),
Counts, PackageName(), IsExecutable, Symbols(), SymbolCount, EntrySymbol,
Diagnostic)` returns Boolean. IsExecutable is ByVal; other arguments are ByRef.
PackageName is a separately retained ASCII identifier byte array. Symbols are
one-based identities stored at index minus one, with zero meaning absent.

Each BoundSymbol retains ModuleIndex, ScopeSymbol, DeclarationNode, NameToken,
Kind, Region, Visibility, TypeCode, TypeSymbol, ArrayRank, PassingMode,
FirstParameter, NextParameter, ParameterCount, FirstField and NextField.
Kinds reuse declaration node kinds; synthetic Function results use kind 30.
Regions are module=1, value=2, label=3 and result=4. Scalar TypeCode values are
SyntaxTokens keyword codes; nominal types retain TypeSymbol instead. Visibility
uses canonical Public/Private/Friend keyword codes, with zero for locals.
These records express declaration facts, not a stable serialized format or ABI.

BindingDiagnostic retains Code, Reason, ModuleIndex, Node, TokenIndex, ByteOffset,
Utf16Offset, Line and Column. Node/token identities refer to the project pools;
reported byte offsets are module-local. Categories are duplicate=1, name/access=2,
type=3, ambiguity=4, entry=5, limit=6, storage/runtime=7, unsupported=8 and invalid
input=9. Code zero accompanies successful publication. Sticky Err is not cleared.

The bounded project profile retains at most 128 modules, 1 MiB total source,
262,144 tokens and 131,072 nodes. Each individual module still has the scanner and
parser's existing limits. The source-byte aggregate limit follows the present
Byte-array representation and 64 MiB heap quota; it is not a language restriction.
Declaration storage retains at most 16,384 symbols with a bounded lookup budget.
The cumulative node capacity accommodates the measured 74,893 module nodes of
the 44-module compiler source package. Module syntax remains capped at 65,536
nodes. The parser and declaration gates accept exactly 131,072 project nodes,
refuse the next node, and preserve the committed project for rebinding.
The main gate accepts exactly 16,384 symbols and rejects 16,386. The precise
lookup-work threshold is a defensive bound, not a separately qualified limit.

## Acceptance requirements

Native O0/O2 checks must inspect symbol identities, ownership, regions, type
edges, visibility and parameter order/modes on real multi-module input. Include
actual compiler/library modules, repeated independent projects and retry after
failure. Check legal shadowing against duplicates, bracket/case/suffix identity,
private and ambiguous references, wrong selected declaration kinds, entry
signatures and separate label regions. Verify controlled malformed-storage and
resource-limit failures and an exact changed-source negative control.

Allocation faults must reach the actual candidate-growth/publication paths,
preserve prior results, release temporaries and allow retry. Existing parser,
scanner and relevant storage gates remain regressions. Exact commands and
qualified results are recorded in `../compiler/Progress.md` and the
`tests/declaration-binding/README.md` acceptance record.
