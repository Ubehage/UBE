# UBE compiler bootstrap source profile

**Status:** bounded scalar and aggregate source-to-native compilation implemented and tested
on Windows x64. This file does not grant exceptions to language semantics.
The dynamic-storage extension below passed its separate 41-group native gate;
exact results and regression evidence are recorded in compiler/Progress.md.

Project loading is implemented separately from source compilation. On
2026-11-10, `bootstrap/tests/project-loading/check.ps1` built the VB6 loader and
passed 54 cases for ordered multi-module `.UBE` input, native source envelopes,
UTF-8, path containment and controlled rejection. It does not parse procedure
bodies. Current limits and supported manifest keys are in `../bootstrap/README.md`.

The VB6 lexer/parser now retains syntax trees for the scalar forms below.
`bootstrap/tests/source-parsing/check.ps1` passed 37 cases for tree structure, source spans,
the actual failure-flow source oracle, malformed/unsupported input and parsing
limits. That gate proves syntax only. The separate semantic gate below qualifies
entry-point resolution, symbols, arguments and scalar types. The native gate
described below separately executes the oracle.

`bootstrap/tests/source-semantics/check.ps1` passed 76 cases for the bounded
contract in `../bootstrap/SEMANTICS.md`, including trusted Err declarations,
shadowing, package/module lookup, visibility, duplicate/undeclared names,
signatures, ByRef alias/temporary treatment, labels and checked constants.
The subsequent integer dependency extension admits Byte, Integer and LongLong
storage alongside Boolean/Long. Hex/octal interpretation, mixed Boolean/integer
operator domains, cross-module required-constant dependencies and colliding
package/module three-part qualifiers are explicitly deferred as documented
there. No UBE runtime behavior is claimed by semantic acceptance.

`bootstrap/tests/integer-types/check.ps1` separately checks Byte, Integer and
LongLong storage and the full admitted scalar conversion matrix. It asserts
exact typed constants, suffix agreement, Byte promotion, checked narrowing,
ByRef rules and native behavior at O0/O2. Its evidence is recorded in the
compiler handoff; arrays, records and foreign layouts are not covered.

`bootstrap/tests/aggregate-storage/check.ps1` covers the subsequent finite-record
and fixed rank-one array extension. Its exact admission and storage limits are
in [AGGREGATES.md](../bootstrap/AGGREGATES.md). It retains source bytes and
token/tree records, checks bounds, borrows fields/elements/arrays ByRef and
copies independent values. Its original fixed-storage acceptance required
identical known bounds for whole-array copies; the dynamic extension below
removes that admission restriction. Managed fields, aggregate ByVal/results and
foreign layouts remain outside the profile. This extension uses existing GoTo traversal, without adding
loop-header failure semantics.

The counted-buffer extension validates exact Intrinsic declarations for the
existing Array.Length and Memory.CopyBytes roles and executes portable UBECore
AppendBytes source. `bootstrap/tests/counted-buffers/check.ps1` passed 25 groups
covering identity binding, actual O0/O2 execution, overlap, span failures,
record-only Boolean status and explicit wrapper FAIL. Its allocation-free
boundary is in [COUNTED-BUFFERS.md](../bootstrap/COUNTED-BUFFERS.md).

The current [dynamic-storage extension](../bootstrap/DYNAMIC-STORAGE.md) is
implemented. It adds empty dynamic declarations, exact Array.TryResize
and Array.TryCopy intrinsic bindings, and independent whole-array assignment
for matching element type/rank with different or unknown bounds. Descriptors
contain lower/upper bounds and payload/owner pointers; initial fixed payloads
are inline and replacements use separately owned blocks. Prepared aliases retain
original storage through calls or assignment completion/abandonment. Replacement
values are independent of later writes through old aliases. A conservative
project effect invalidates current-bound proofs when shapes may change, while
declaration metadata retains initial fixed bounds. Its 41-group gate is
`bootstrap/tests/dynamic-storage/check.ps1`; exact evidence and same-build
regressions are in compiler/Progress.md. Managed fields, ReDim/Erase syntax,
aggregate ByVal/results and broader primitives remain deferred. Counted file
I/O is qualified separately below.

The counted file-I/O gate `bootstrap/tests/file-io/check.ps1` passed 56 groups
for explicit owned tokens, exclusive creation, bounded byte transfers and
ordinary UBECore progress/cleanup helpers at O0/O2. Its limits and target
boundary are in [FILE-IO.md](../bootstrap/FILE-IO.md).

The source-scanning extension admits the loop and operator forms listed below
and executes `compiler/src/SourceScanner.bas` with ordinary UBECore UTF-8
validation. `bootstrap/tests/source-scanning/check.ps1` passed 86 groups for
actual file input, retained tokens/positions and controlled malformed-input
diagnostics. Separate gates passed 42 allocation/depth checks, 37 UTF-8 cases
at O0/O2 plus a changed-input control, and 13 syntax/binding cases. Its input
limit is 1,048,576 bytes, with at most 65,536 tokens. Individual tokens retain
the 4,096 UTF-16-unit bound and identifiers the 128-unit bound. This is the
current ASCII identifier profile; managed String storage and full Unicode
identifiers remain deferred. Exact contracts and evidence are in
[SOURCE-SCANNING.md](../bootstrap/SOURCE-SCANNING.md) and compiler/Progress.md.

The UBE-written module parser now retains caller-owned indexed trees for this
admitted grammar. Its gate passed 19 cases at O0/O2, including actual compiler
and library modules, exact tree/spans and a changed-input negative control.
Syntax limits are 65,536 nodes per module and 48 recursive parsing levels;
these are distinct from the VB6 host parser's limits. Type references, including
recursive spellings, are retained without claiming recursive layout support.
See [MODULE-PARSING.md](../bootstrap/MODULE-PARSING.md). UBE-written binding and
lowering, complete-language parsing and self-hosting remain unimplemented.

`bootstrap/tests/native-compilation/check.ps1` compiles actual UBE source through
the complete pipeline and asserts the eight error-oracle checks at O0/O2,
multi-module initialization/calls, ByRef behavior, checked failures, bounded
recursion, x64 output, deterministic IR and failed-build output preservation.
The implemented lowering and remaining boundaries are in
`../bootstrap/LOWERING.md`; exact evidence is in `../compiler/Progress.md`.

The parser also admits ordinary typed scalar constants/initializers, integer
`%`, `&` and `^` declaration/reference/literal suffixes, unary signs, integer
radix spellings, ASCII bracketed
names, numeric labels, ElseIf and redundant Option Explicit/On. Unsupported
types, operators, declarations and control forms fail explicitly. It reports
the first error and does not provide IDE multi-error recovery. Parser limits
and its development dump format are defined in `../bootstrap/DESIGN.md`.

The initial scalar admission set exists to prove the accepted error contract
before expanding implementation. The later dependency set identifies what the
UBE-written compiler will need; it is not a claim that self-hosting is already
possible or that its minimum dependencies have all been measured.

## Initial scalar admission set

| Area | Admitted scope to implement first |
|---|---|
| Container | UTF-8 `.UBE` project manifest with multiple ordered `.bas` modules, each with `UBE SOURCE 1 MODULE` and Attribute UBE_Name; project loading is required from the first implementation |
| Entry | One package-wide module-level `Function Main() As Long` or `Sub Main()` for an Exe project |
| Types/storage | Boolean, Byte, Integer, Long and LongLong; explicitly typed locals, parameters and function results; neutral initialization; scalar module variables |
| Procedures | Module Subs and Functions; ByVal and exact writable-storage ByRef; parameterless and positional calls; Exit Sub/Function |
| Expressions | Literals, names, calls, comparisons, eager Boolean/integral And/Or/Not, checked integer addition/subtraction and unary signs; evaluation once in source order |
| Statements | Scalar declarations/assignments, procedure calls, single-line and block If/Else, procedure-local labels and GoTo; Do/Loop with pre-test or post-test While/Until, unconditional Do and nearest-loop Exit Do |
| Errors | Err.Raise with a Long code, Err.Number read, Err.Clear; default continuation; On Error GoTo label, On Error Resume Next and On Error GoTo 0; failure while a handler is active |
| Output oracle | Main's process result plus harness observations; production Print is not required merely to report test success |

This table selects surface features, not an alternate grammar. Match the
normative EBNF and strict declaration rules for every admitted source form.
Err operations must resolve to the official error-support contract rather than
give arbitrary user declarations magic behavior by name. The concrete
declaration/binding representation is documented in `../bootstrap/SEMANTICS.md`;
the test-only native prototype does not decide that interface.

SourceOracle.bas is a module of callable checks, not a standalone executable.
A test-only native harness supplies runtime arguments and calls its compiled
procedures; this does not expose ordinary Public procedures as
foreign exports. Separate standalone Main fixtures qualify executable startup.
The initial oracle uses nonfailing scalar comparisons. The source-scanning
extension now admits failing If/ElseIf and Do/Loop conditions: default execution
skips the entire affected construct, while enabled handlers still receive
control. A failed condition is not a Boolean. See
[`SOURCE-SCANNING.md`](../bootstrap/SOURCE-SCANNING.md) for the dependency scope.

The emitter rejects lifecycle hooks, explicit
Raise in the executable root Main, and potential cross-module initializer cycles.
These bounded-profile rejections preserve the open full-language contracts;
they are not new semantics for those cases. Debug locations survive as source
spans and IR comments, but full native debugger information remains unimplemented.

The first runtime failure cases pass variable input so the compiler is not
asked to silently execute a provably invalid constant operation. Separately
assert required constant-failure diagnostics. An Err.Raise in a reusable
procedure is legal; analysis must distinguish a declaration from a provably
invalid executed call. Detailed interprocedural analysis beyond the admitted
profile is not a prerequisite for starting the parser.

## Input and failure constraints

- Set and document byte/token/nesting/diagnostic limits before implementing
  the source reader. Check limits before allocating or descending recursively.
- Reject malformed UTF-8, embedded invalid source characters, truncated
  tokens, mismatched terminators and duplicate declarations with locations.
- Unsupported constructs receive an explicit diagnostic; never compile them
  as no-ops or silently adopt VB6 runtime semantics.
- All compiler host I/O and child-process failures have fresh status and
  actionable diagnostics. Do not use stale VB6 Err to classify success.
- Any failed build leaves an earlier valid output untouched and does not
  advertise a new executable. Exact output-publication mechanism is an
  implementation task with failure tests.
- This profile does not allow bare/headerless source as an undocumented
  shortcut. Imported VB6 syntax is separate subsequent compatibility work.

## Dependencies needed before self-hosting

Add and prove these only as compiler-source needs demand them:

- Byte, Integer and LongLong storage and checked conversions/arithmetic are
  implemented by the integer dependency extension; its gate is
  `bootstrap/tests/integer-types/check.ps1`. This does not imply arrays or records;
- Unicode text and broader input processing, with explicit encoding and source
  spans; counted UTF-8-path byte I/O is admitted through the exact File.* roles
  in language-spec.md and the bounded contract in bootstrap/FILE-IO.md;
- broader aggregate storage; finite scalar-field records and fixed rank-one arrays
  are qualified by the aggregate gate, while growing arrays and general bound-adopting
  copies are covered by the dynamic-storage acceptance gate described above;
- strings and precise managed-storage lifetimes if used by the compiler;
- broader loop forms, additional operators and further UBECore procedures;
  ordinary calls into the counted-buffer UBECore source are now qualified;
- further cross-module resolution features beyond the initial scalar package;
- deterministic diagnostics, file ownership and backend invocation.

Use reusable UBECore algorithms rather than duplicate implementations in the
compiler. The bootstrap may call host facilities, but its generated programs
must follow UBE's target contracts. The final dependency-minimum is established
from actual UBE compiler source and its build, not presumed by this list.

## UBE-written declaration component

The independent UBE component now retains ordered project syntax and binds
declarations and signatures under `../bootstrap/DECLARATION-BINDING.md`.
Its native gate accepts actual compiler/library modules and checks scoped
identity, visibility, nominal type references, parameter modes and executable
entry selection. Recursive Type references resolve as graph edges only.
Expression validity, constants, primitive authority and runtime layout still
come from the VB6 bootstrap; declaration success is not a full analysis result.
Exact native and failure-gate evidence is in `../compiler/Progress.md`.

## Explicitly outside the initial implementation

Classes/events, collection and GC of arbitrary object graphs, native threads,
foreign exports/callbacks, UI/designer formats, Adaptive result inference,
assembly/bytecode lowering and full library compatibility are not admitted by
the scalar profile. Resume syntax remains unsupported; the If/Do targets are
specified, while other compound-control targets and complete Err descriptive
fields still need detailed contracts. Reject unsupported forms
explicitly until implemented; their approved full-language semantics remain.

See `../compiler/ACCEPTANCE.md` for the gate. Update this file with named tests
before changing any item from planned to implemented.
