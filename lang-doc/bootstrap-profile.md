# UBE compiler bootstrap source profile

**Status:** bounded scalar source-to-native compilation implemented and tested
on Windows x64. This file does not grant exceptions to language semantics.

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
| Expressions | Literals, names, calls, comparisons, eager Boolean And and checked Long addition needed by the error fixtures; evaluation once in source order |
| Statements | Scalar declarations/assignments, procedure calls, single-line and block If/Else, procedure-local labels and GoTo |
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
Failure within an If condition or other compound control header is outside the
initial gate until its exact continuation target is settled; conditions in the
initial oracle are nonfailing scalar comparisons.

The emitter rejects potentially failing If headers, lifecycle hooks, explicit
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
- Unicode text and counted byte I/O, with explicit encoding and source spans;
- dynamic arrays and finite value records with independent copy semantics;
- strings and precise managed-storage lifetimes if used by the compiler;
- loop forms, additional operators and ordinary UBECore procedure calls;
- further cross-module resolution features beyond the initial scalar package;
- deterministic diagnostics, file ownership and backend invocation.

Use reusable UBECore algorithms rather than duplicate implementations in the
compiler. The bootstrap may call host facilities, but its generated programs
must follow UBE's target contracts. The final dependency-minimum is established
from actual UBE compiler source and its build, not presumed by this list.

## Explicitly outside the initial implementation

Classes/events, collection and GC of arbitrary object graphs, native threads,
foreign exports/callbacks, UI/designer formats, Adaptive result inference,
assembly/bytecode lowering and full library compatibility are not admitted by
the scalar profile. Resume retry/control-construct resume targets and complete
Err descriptive fields follow their exact contracts when settled. Reject them
explicitly until implemented; their approved full-language semantics remain.

See `../compiler/ACCEPTANCE.md` for the gate. Update this file with named tests
before changing any item from planned to implemented.
