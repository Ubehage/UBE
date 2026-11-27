# UBE compiler bootstrap source profile

**Status:** the UBE-written compiler implements and tests the scalar, finite
aggregate, managed String, Single/Double and loop-dependency scope below on Windows x64.
It builds itself and compiles independent work in parallel. This file describes
implementation admission; it does not grant exceptions to language semantics.
Earlier bootstrap gates are retained below as historical qualification, not as
the current limit of the UBE-written compiler.

## Current conditional compilation and execution context

The UBE-written compiler selects `#Const`, nested `#If`/`#ElseIf`/`#Else` and
`#End If` before parsing ordinary source. File-local constants become visible
after declaration and cannot redefine supplied symbols. Comments and physical
continuations retain their existing rules. Inactive ordinary syntax and names
are ignored; nested directives still balance, and assembly-block payload stays
opaque even when discarded. Retained tokens and diagnostics preserve original
byte, UTF-16, line and column coordinates.

Directive expressions admit Boolean, decimal integer, finite Single/Double and
String constants with the implemented directive operators and checked constant
conversions. Hexadecimal/octal signed-width semantics remain deferred here.
Date, Currency, Decimal and general Variant expression support are not claimed.
This does not implement target conditional compilation in the VB6 bootstrap.

Standalone builds supply the read-only Boolean `IS_IN_IDE = False` in both
ordinary expressions and conditional compilation. Starting the compiler from
an editor, enabling debug information or disabling optimization does not change
that value. Assignment, shadowing and direct writable ByRef use are rejected;
an explicitly parenthesized expression may use the ordinary ByRef temporary rule.
The explicit `--build-ide` and `--emit-llvm-ide` commands supply True and produce
separate IDE-run artifacts; ordinary `--build` and `--emit-llvm` remain False.
Hosted library output is rejected. Context is request-owned, including supplied
conditional symbols and ordinary constant facts, rather than inferred from the
environment or editor.

An IDE-run executable checks its live host session before context initialization
or any source initializer or entry procedure. The Windows host owns a named job
with kill-on-last-close and no breakaway; the child must belong to that job.
A missing or invalid session prints `E_IDE_CONTEXT`, requests a standalone rebuild
and exits 125. The host retains the job during debugging pauses; ending the
session terminates the child. An environment value alone cannot grant membership.
The repository integration fixture implements this host contract; this is not a
claim of a finished graphical IDE or source-level debugger.

The final compiler `5c66c361` generation 2 passes the 35-check hosted session gate
(`ube ide session 619cd81c-46a9-4a8a-91a5-d36c1392bd57`), including actual
hosted True and standalone False execution and refusal/lifecycle checks.
The hosted runtime/session gates and current compiler identity are recorded in
[IDE-CONTEXT.md](../compiler/IDE-CONTEXT.md). The following standalone checkpoint
is retained as earlier evidence:
Compiler `35885756` generation 2 passes successive self-build fixed-point checks
and `compiler/tests/conditional-compilation/project-check.ps1`: 12 O0/O2 native
runs, four builtin rejection cases, original-coordinate diagnostics, output
preservation and deterministic recovery. Evidence is
`ube conditional projects ab3debff-1f0e-46a9-9f9a-8ec93305df09`.
Compiler SHA256 is `78663AB109FB58E421826EE18BE8CCEF541341656549BA01E8EFFF0D907C782A`.
Detailed frontend and host-session gates are in
[IDE-CONTEXT.md](../compiler/IDE-CONTEXT.md).

## Current Single and Double admission

The UBE-written compiler admits finite `Single` and `Double` literals,
constants, storage, parameters/results, rank-one array elements, finite record
fields and worker captures. The operators `+`, `-`, `*`, `/`, `^`, unary signs
and comparisons are supported, as are conversions with the admitted Boolean,
integer and variable-length String types. Floating operands of `\` and `Mod`
round to nearest/even LongLong values before division; the result is LongLong.
`/` and `^` produce Double in this admitted numeric profile.

Real literals use `!` for Single and `#` for Double; integer-looking forms such
as `1!` and `1#` are admitted. Unsuffixed real literals are Double. The grammar
also specifies the classic Currency suffix `@`, but Currency storage and
arithmetic are not implemented by this increment. `F`, `R` and `D` are not
numeric suffixes.

Finite IEEE rounding, signed zero and subnormals are preserved. NaN and
infinities are rejected. Known invalid constants fail compilation; runtime
failures preserve unfinished destinations and successful operations preserve
earlier Err. Division by zero records Err 11; numeric overflow/nonfinite input
records Err 6; zero to a negative power or a negative base to a fractional power
records Err 5; malformed numeric text, including special-value spellings,
records Err 13. Invariant text uses the shortest round-trip representation and
preserves negative zero as `-0`, following language-spec.md section 14.

O0/O2 qualification covers exact numerical boundaries, failure/recovery,
constants, arrays/records, argument evaluation, grouped ByRef conversions and
worker captures. The final compiler also passes self-build fixed-point,
common-conformance and concurrent-compilation gates. Commands, exact evidence
and the distinction between native-helper and source-level tests are in
[FLOATING-POINT.md](../compiler/FLOATING-POINT.md). This does not claim floating
source admission in the VB6 bootstrap, Currency/Decimal support, the later
Variant dependency scope described below,
foreign floating ABI support or a complete mathematics library.

The UBE-written compiler additionally admits variable-length String values,
quoted literals, `&`, binary comparisons and conversions with the admitted
Boolean/integer and Single/Double types. String locals, globals, parameters, results, finite
record fields, array elements and worker captures use precise managed roots.
Ordinary UBECore text and collection algorithms are linked automatically;
allocation pressure collects and retries once. Exact scope, errors and
remaining exclusions are in [TEXT.md](../std-lib/TEXT.md). Actual O0/O2 source,
fault, collection and worker gates are listed in
[the managed-text tests](../runtime/tests/managed-text/README.md).
This extends the UBE compiler; it does not claim String source admission in
the VB6 bootstrap. Fixed-length String, Currency/Decimal,
text-folding/Like and broad-input compatibility functions remain outside this
increment.

`Exit Loop` is specified for UBE 1.0 as an exit from the outermost enclosing
loop in the current procedure invocation. Both compiler paths now admit it
within Do, While and counted For loops, including mixed nesting and nearest-kind
Exit Do/While/For. UBE admits floating counters; the bootstrap admits integer
counters. Focused O0/O2 execution, invocation isolation and invalid-placement
gates pass; exact scope and evidence are in
[LOOP-CONTROL.md](../compiler/LOOP-CONTROL.md).

The UBE-written compiler also admits rank-one array `For Each` with a writable
Variant control variable, including admitted scalar, String, Variant, finite
record and object-reference elements. The collection expression is evaluated
once. Enumeration retains the original array storage through replacement or
resize and observes writes to that storage; it does not snapshot the elements.
Exit For leaves the nearest For; Exit Loop leaves the outermost enclosing loop
across all four loop kinds. Construct-owned leases and managed roots are
retired at actual exit destinations without clearing procedure locals or the
control variable. Hardened O0/O2 source tests and exact emitted owner/root
oracles are `compiler/tests/loop-control/foreach-check.ps1` and
`foreach-lease-check.ps1`; syntax diagnostics use `foreach-syntax-check.ps1`.

This dependency uses real managed Variant boxes, preserving exact scalar tags,
nominal record value copies and object-reference identity. Checked conversions
cover the admitted Boolean/integer, Single/Double, String, record and object
values. Empty is neutral and failed conversions preserve unfinished
destinations. This is not complete Variant arithmetic, array-valued Variant
support or the complete Variant library.

Genuine named classes, typed and generic Object references, New, Set,
Nothing and identity comparisons supply the object identity needed by SyncLock.
The UBE compiler admits SyncLock with retained targets and acquired-state
cleanup, including loop exits, returns and failure transfers. Source and native
monitor checks are under `compiler/tests/object-monitors/` and
`runtime/tests/object-monitors/`. The class-member implementation admits per-instance scalar, String, Variant, object-reference and
finite-record fields, ordinary Sub/Function methods, and read-only Me. Explicit
receivers are evaluated once before arguments and retained through synchronous
calls, including field ByRef arguments. Class members do not enter unqualified
standard-module lookup; Public, Private and package-local Friend visibility
apply. Real-collector tests cover managed fields, cycles and receiver retention.
Arrays as fields, field declaration initializers, lifecycle hooks, properties,
events, interfaces, instance CallNew targets and field aliases escaping directly
or transitively to asynchronous work remain explicit unsupported forms.
Object-collection enumeration also remains unsupported. These managed dependencies
do not expand the deliberately scalar/finite-record VB6 bootstrap profile.
Final integrated regression qualification of the complete Exit Loop increment
passes on corrected compiler 68e264aa; the exact completion audit is in
[LOOP-CONTROL.md](../compiler/LOOP-CONTROL.md).
Class-member source, collector and allocation-failure checks pass 28 cases on the self-hosted
compiler 97b47838 (SHA256 5510298EAFD95492DD619683B3B562A07408F5764894EDCE0D86D10646B3DA98). The exact boundary and
current evidence are in [CLASS-MEMBERS.md](../compiler/CLASS-MEMBERS.md).

## Current storage limits

The UBE-written compiler no longer imposes the former fixed source-byte,
module-count, token/node-count, symbol-count or total LLVM-output quotas.
Those stores grow with checked counts and allocation failure. The native
runtime's former 64 MiB heap quota and 4096-record collector workspace are
replaced by checked size accounting and growing workspace. Procedure frames
larger than 128 cells use checked heap allocation; 128 is now a small-frame
stack-storage threshold, not an admission limit. Failed allocation reports
failure, and failed compilation preserves an earlier output.

This is not unlimited compiler admission. Counts and indexes still have their
representation bounds; source/manifest files currently fit in 2,147,483,646
bytes. Tokens retain their 4096 UTF-16-unit bound and ASCII identifiers their
128-unit bound. Parsing depth is 48, binding and record-layout depth is 64,
and existing work, parameter, record-layout, module-storage and call-depth
guards remain. The native backend has its existing 30-second invocation
timeout. Compiler input growth does not imply that arbitrary native stack
requirements are supported. The tests and remaining boundaries are recorded
in [FLOATING-POINT.md](../compiler/FLOATING-POINT.md).

## Earlier bootstrap and dependency gates

The checked integer-operation extension now admits `*`, integer `\` and `Mod`
for the existing integer types, with Byte promotion, compile-time diagnostics,
runtime overflow/zero-divisor FAIL and unchanged failed assignment destinations.
Precedence follows the frozen grammar: Mod binds more tightly than `\`, which
binds more tightly than `*`; Mod requires whitespace on both sides.
The minimum signed value Mod -1 succeeds with zero, while its division by -1
overflows. The shared O0/O2 gate is
`../bootstrap/tests/integer-operations/check.ps1`, with independent host/UBE
evidence in its README. That integer-only gate does not qualify `/`, `^` or
floating arithmetic; the current floating increment above does. Ordinary UBE
UTF-8 scalar codecs use these operations; their
exhaustive byte oracle is `../std-lib/tests/unicode-scalars/check.ps1`.

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
removes that admission restriction. That original gate excluded managed fields,
aggregate ByVal/results and foreign layouts. Later String/worker gates qualify
their separately stated scope. This extension uses existing GoTo traversal, without adding
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
regressions are in compiler/Progress.md. That original gate did not qualify
managed fields or aggregate ByVal/results; later String/worker gates extend it.
ReDim/Erase syntax and broader primitives remain deferred. Counted file
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
at O0/O2 plus a changed-input control, and 13 syntax/binding cases. The former
1,048,576-byte input and 65,536-token quotas were removed in the current
increment. Individual tokens retain the 4,096 UTF-16-unit bound and identifiers
the 128-unit bound. This is the
current ASCII identifier profile; full Unicode identifiers remain deferred.
Managed String admission is described above. Exact scanning contracts are in
[SOURCE-SCANNING.md](../bootstrap/SOURCE-SCANNING.md) and compiler/Progress.md.

The UBE-written module parser now retains caller-owned indexed trees for this
admitted grammar. Its gate passed 19 cases at O0/O2, including actual compiler
and library modules, exact tree/spans and a changed-input negative control.
The former 65,536-node module and 131,072-node project quotas were removed;
48 recursive parsing levels remain. These are distinct from the VB6 host
parser's limits. Type references, including
recursive spellings, are retained without claiming recursive layout support.
See [MODULE-PARSING.md](../bootstrap/MODULE-PARSING.md). UBE-written binding,
lowering and self-hosting are now qualified by later gates; complete-language
parsing remains unfinished.

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
UBE-written compiler needed. These historical admission lists do not replace
the current self-hosting evidence linked above.

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

- Check storage-size arithmetic and allocation failure before publishing new
  input state. Check remaining nesting/work guards before recursive descent.
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
- strings and precise managed-storage lifetimes are now qualified in the UBE
  compiler; the compiler's own source still uses counted byte storage;
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
CallNew syntax and binding are qualified independently of native execution.
The host and UBE parser retain a distinct thread-start node with explicit Call
target/argument syntax, including optional parentheses for zero arguments.
The binder accepts Subs and Functions, yields LongLong thread identity and
retains ordinary ByVal/ByRef argument modes. Native source workers and captured
storage are now qualified at O0/O2 through the bootstrap host and UBE lowerer
within the admitted scalar and finite aggregate profile. Escaping ByRef storage,
ByVal aggregate snapshots and grouped scalar temporaries remain valid until
worker cleanup. This does not admit managed objects, aggregate Function results,
or the complete coordination library. The low-level `ThreadPrimitives.Wait(Id,
TimeoutMilliseconds)` requires its timeout argument; the specified global
`ThreadWait` convenience API with an optional timeout is not thereby qualified.
The source-parsing, module-parsing, expression-binding and runtime CallNew gates
record this scope. The integrated concurrent compiler gate also passes for
bounded one/two-worker emission and independent requests in one process
(`ube concurrent compilation 30afd7ad-b7cf-4153-a352-0b8b29e31988`).

The UBE expression component now checks references, calls, assignments,
conversions, ByRef modes, labels and exact scalar constants under
`../bootstrap/EXPRESSION-BINDING.md`. Its native gate qualifies actual compiler
and library bodies at O0/O2, with precise diagnostics and failure preservation.
Nominal recursive equality is checked as a type fact, not executed or laid out.
Separate UBE passes now validate intrinsic authority and finite aggregate
layout under `../bootstrap/SEMANTIC-STORAGE.md`. Production lowering is now
implemented in UBE, with the VB6 bootstrap retained as an independent reference.
An earlier integrated compiler reached the successive self-build fixed point
(`ube compiler rebuild 18c217dd-d417-4e79-b96a-198202d3613a`). The matching
common-conformance checks also passed: 860 assertions for bootstrap/generation 2
and 446 for generation 1, including both optimization modes and backend recovery.
Exact native and failure-gate evidence is in `../compiler/Progress.md`;
the current Single/Double rebuild and conformance results are linked above.

## Explicitly outside the initial implementation

Native threads were outside the original scalar profile; the admitted source
worker and concurrent compiler qualifications above supersede that exclusion.
Classes/events, collection and GC of arbitrary object graphs,
foreign exports/callbacks, UI/designer formats, Adaptive result inference,
assembly/bytecode lowering and full library compatibility are not admitted by
the scalar profile. Resume syntax remains unsupported; the If/Do targets are
specified, while other compound-control targets and complete Err descriptive
fields still need detailed contracts. Reject unsupported forms
explicitly until implemented; their approved full-language semantics remain.

See `../compiler/ACCEPTANCE.md` for the gate. Update this file with named tests
before changing any item from planned to implemented.
