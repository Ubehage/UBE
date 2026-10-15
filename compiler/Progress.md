# UBE compiler progress

This file is the short handoff record for the active item in
`compiler/Roadmap.md`. Update it while working; do not use it as a second
roadmap.

## Current position

- Active milestone: **v3 target definition and scaffold**
- Active item: derive v3 conformance cases from the frozen normative UBE 1.0
  specification and grammar.
- Status: in progress; the v3 generation directory and v2-buildable scaffold
  exist, all owner-level design decisions are resolved, and the UBE 1.0
  specification, focused semantic contracts, project format, and EBNF are
  normative. Conformance coverage remains incomplete.
- Blockers: none recorded.

## Verified baseline

- `UBE_Compiler_v1` is preserved with a matching project manifest and
  `Main.bas` startup module.
- Stage zero compiles v1 into the stage-one executable.
- Stage one emits LLVM IR for both checked-in showcase programs.
- Both showcase programs link and run with their expected output and exit code.
- V1 has automated negative coverage for malformed supported shapes, invalid
  arguments, source read failure, and output write failure.
- Dynamic arrays of compiler-defined records and explicit `ByRef` dynamic-array
  parameters are implemented and covered by native tests.
- The v2 design boundary, project, initial driver, and positive showcase tests
  exist. Stage zero builds v2 and the resulting executable emits working LLVM
  IR for both entry-point forms.
- V2 tokenizes its input into flat token records before recognizing the current
  showcase subset, and emits LLVM through joined text chunks. The new bounded
  join primitive has semantic, lowering, runtime, and native coverage.
- V2 discovers `Sub Main`/`Function Main`, `Print`, and function-result
  assignments from tokens with ASCII case-insensitive keyword matching. The
  acceptance input proves it ignores an earlier non-entry procedure's `Print`.
- V2 now has flat source and diagnostic records, strict UTF-8 validation,
  character-aware diagnostic columns, a 16 MiB source limit, a 100,000-token
  ceiling, and controlled diagnostics for lone CR and unterminated strings.
- The bootstrap runtime rejects embedded NUL bytes in text files instead of
  silently truncating them. V2 negative tests verify the exit code, diagnostic,
  and absence of a false-success output artifact.
- The lexer retains raw token spelling separately from decoded values, handles
  apostrophe/`Rem` comments and doubled string quotes, and LLVM emission escapes
  quote, backslash, control, and non-ASCII bytes.
- Entry parsing now produces a bounded `ProcedureSyntax` record and a flat
  `SyntaxNode` for the print expression. Token, syntax-node, diagnostic, and
  generated-output counts have explicit ceilings; token and text storage grow
  geometrically instead of reallocating for every item.
- String literals, parenthesized string expressions, and `&` concatenation now
  parse recursively into syntax nodes and lower from that tree. Function-result
  integer literals and parentheses use the same syntax-node path.
- V2 decodes UTF-8 identifiers and uses the repository's pinned Unicode 18.0
  letter table through a tested bootstrap intrinsic. Explicit continuations,
  including an optional trailing comment and LF/CRLF, are removed lexically.
- Unicode 18.0 simple folding is exposed by code point through the same runtime
  boundary. V2 keyword/name equality now walks UTF-8 scalars and compares their
  folded values rather than applying ASCII-only byte folding.
- V2 structurally collects all module-level procedures, `Type` declarations,
  and fields into geometrically grown bounded tables. It validates terminators,
  dynamic-array field markers, explicit field types, and Unicode-folded
  duplicate procedure/type/field names before entry parsing.
- Procedure headers now populate bounded parameter records with passing mode,
  dynamic-array status, explicit type, and owning procedure. Functions retain
  their result type. A semantic pass resolves exactly one non-intrinsic,
  parameterless `Sub Main()` or `Function Main() As Long`.
- Procedure body scanning now records typed `Dim`/`Static` locals, initializer
  ranges, assignments, and explicit calls. The first body semantic pass rejects
  folded local/parameter collisions, undeclared assignment bases, and unknown
  callees across v2's complete source.
- A general precedence-climbing parser now turns every stored initializer,
  assignment value, and explicit call into flat expression nodes. It supports
  literals, names, unary/binary operators, parentheses, calls/indexing, member
  access, and linked argument lists. Recursive semantic traversal resolves
  names/callees and checks argument counts across v2's own source.
- Expression nodes now receive stable scalar, record, and array type IDs.
  Recursive type resolution covers variables, procedure results, member fields,
  array indexing, calls, operators, and local initializer assignability across
  v2's complete source.
- Assignment targets are parsed as expressions and checked for addressability.
  Calls enforce exact `ByRef`, assignable `ByVal`, Long array indices, and
  callable/indexable bases. Unary/logical operands and symmetric numeric
  promotion are checked. A scalar-call regression guards a formerly reachable
  out-of-range runtime failure.
- Block `If/Else/End If` and `While/Wend` use a bounded explicit matching
  stack. Conditions use the shared expression tree and must be Boolean or
  integral. Structural and condition errors have focused regressions.
- Ordered statement lowering now retains block-local initializers, `ReDim`,
  calls, assignments, printing, exits, branches, and loops. The LLVM backend
  emits every non-intrinsic procedure, records, arrays, exact `ByRef`
  addresses, checked arithmetic, strings, intrinsic calls, and the native
  entry wrapper.
- V2 is self-hosting for its checked-in single-source Bootstrap Profile: stage
  one emits and links stage two, stage two recompiles the same source, and the
  two fixed-point LLVM outputs are byte-identical. Both compiler stages agree
  on the positive and negative v2 corpus.
- V2 loads ordered multi-source `.UBE` projects, normalizes and de-duplicates
  safe relative `.bas` paths, loads each module once, and maps diagnostics back
  to module-local paths and positions.
- A checked-in multi-module program places `Main` before its support module,
  uses a cross-module `Type`, and calls cross-module functions. Stages one and
  two emit identical IR; the linked program prints `multi-module` and exits 7.
- Negative multi-module gates cover an unknown call in the second module,
  duplicate normalized inputs, and a missing second source. Both stages agree
  and leave no false-success artifact.
- The bootstrap build now recreates `bootstrap/out` before every run. The full
  stage-zero, v1, v2, fixed-point, positive, negative, and native suite passed
  on 2026-10-15.

## Next actions

1. Derive positive, negative, boundary, recovery, and runtime conformance cases for each
   promoted normative rule.
2. Split the v3 compiler scaffold into its first ordered v2-compatible phase
   modules without expanding v2's frozen bootstrap contract unnecessarily.
3. Implement the frozen grammar and contracts in those ordered phases while
   keeping v2 preserved.

## Decisions in force

- Compiler generations and bootstrap stages are different concepts; see
  `compiler/Roadmap.md`.
- Routine v1 fixes do not create `UBE_Compiler_v2`.
- V2's transition gate is complete; routine public-language growth now belongs
  to v3.
- Previous working generations remain buildable and tested.
- V2 is transitional; v3 is the first public-release target and must be
  developed and compiled with preserved v2.
- Fractional-to-integer conversion uses round-to-nearest, ties-to-even, with
  out-of-range failure. Invariant numeric text parsing trims surrounding
  whitespace, requires a complete match, accepts signs, decimal/exponent
  forms and integer `&H`/`&O`, rejects known-invalid constants at compile time,
  and records controlled failure for invalid runtime text. Boolean conversion
  preserves VB rules: zero/`False` is `0`, nonzero is true, `True` converts to
  `-1`, and text accepts case-insensitive Boolean words or numeric strings.
- Every core numeric type converts implicitly to every other with checked
  range and defined ties-to-even rounding; known failures are compile errors
  and dynamic failures produce neutral values plus `Err`. IEEE special values
  survive `Single`/`Double` and invariant string conversion but fail conversion
  to integer, fixed/decimal, date, or Boolean. `Date` converts implicitly only
  with invariant strings; numeric/Boolean serial-date behavior is explicit
  compatibility-library functionality.
- Integer, `Currency`, and `Decimal` arithmetic is checked: constant overflow
  is a compile error, runtime overflow/divide-by-zero returns neutral zero plus
  `Err`, and wrapping is never implicit. `Single`/`Double` follow IEEE-754,
  producing infinity/`NaN` without `Err`; incompatible later conversion still
  fails under the approved conversion table.
- `And`/`Or` remain eager. `AndAlso`/`OrElse` are Boolean short-circuit
  operators whose skipped operand has no effects. `IsNot` and `Is Not` are
  equivalent negated object-identity comparisons.
- `String * n` always stores exactly `n` characters. Assignment silently
  truncates longer values and right-pads shorter values with spaces; this is
  requested fixed-size behavior, not an error. Reads and copies retain all
  padding characters.
- `Enum` defaults to `LongLong` and may specify only `As Long` or
  `As LongLong`. Members are checked integer constants, omitted values
  auto-increment from zero, and duplicate values are allowed. Enum values act
  as their underlying integer for conversion, assignment, calls, comparison,
  arithmetic, bitwise operations, and numeric string formatting; there is no
  strong enum barrier or `Flags Enum` syntax.
- Arrays use `LongLong` bounds/indices, permit negative lower bounds, and fail
  out-of-range reads/writes safely through neutral result/no write plus `Err`.
  Assignment is an independent value copy; `Erase` unallocates dynamic arrays
  or clears fixed arrays; `ReDim Preserve` may resize any dimension while rank
  and type stay fixed, retaining the coordinate intersection and releasing
  removed managed values.
- String comparison defaults to Unicode-scalar, case-sensitive `Option Compare
  Binary`; `Text` uses versioned locale-independent Unicode case folding.
  Fixed padding participates, each expression uses its containing module's
  mode, locale-aware comparison is explicit library behavior, and legacy
  `Database` comparison is diagnosed as unsupported rather than guessed.
- `Variant` preserves the exact assigned runtime type. Extraction applies the
  ordinary conversion table; custom values require the same declared type and
  objects require a compatible object/class destination. `Empty` converts to
  the destination's neutral value without failure, while `Null` survives only
  in `Variant` and otherwise produces a neutral result plus `Err`. `IsEmpty()`
  and `IsNull()` are standard-library tests.
- Storing a statically object-valued expression in `Variant`, or extracting an
  object from one, requires `Set`. Scalar/value payloads use `=`. Whole-Variant
  `V2 = V1` copies the tag and payload; an object payload becomes another strong
  reference to the same identity, while incompatible extraction yields neutral
  value plus `Err`.
- `Null` propagates through Variant unary/arithmetic/concatenation/comparison
  expressions. Fixed-type use, including an `If` condition, converts to neutral
  plus `Err`; `IsNull()` tests it, `Null Is Nothing` is invalid, and `Empty`
  converts rather than propagates.
- Canonical `Date` text is `YYYY-MM-DDTHH:MM:SS[.fraction]`; date-only values
  use midnight, time-only values use `0001-01-01`, zero fractions are omitted,
  and nonzero fractions trim trailing zeroes through nine-digit precision.
  Core conversion is timezone-neutral and invariant. The standard library must
  separately provide explicit localized parsing, formatting, and timezone
  support without changing source or persistence semantics.
- Custom `Type` declarations have native value semantics. Recursive fields use
  hidden, lazily materialized managed storage: both reads and writes
  materialize only the depth accessed by executed code. `New`, `Nothing`,
  identity tests, and allocation-state queries are not exposed for these
  fields. Assignment creates an independent semantic copy, not a bytewise copy
  of owning managed addresses.
- Custom-type `=` and `<>` are fieldwise value comparisons when every field is
  equality-comparable. Hidden recursive allocation state is unobservable and
  comparison performs no materialization. Ordering is invalid for custom
  types, and `Is` remains restricted to object identity.
- Custom-type assignment independently copies scalars, strings, arrays, nested
  values, and materialized recursive descendants. Object and class fields copy
  the managed reference and therefore continue to identify the same object;
  UBE never implicitly clones an object. Such a containing custom type has no
  automatic `=` or `<>` unless an explicit class value-equality contract is
  defined in the future.
- UBE 1.0 has no public weak-reference or class value-equality facility.
  Ordinary references are strong; classes compare only with `Is`/`Is Not`.
  Public functions return custom datatypes as independent values and objects
  as transferred strong references. Ignored result references are released.
- Objects returned to non-UBE callers use opaque ABI handles backed by explicit
  external ownership leases, never raw GC pointers. They remain resident until
  the lease is explicitly released/unloaded or the library is orderly
  unloaded. Self-unload cleans internal resources and invalidates the token;
  later foreign calls receive controlled status, since UBE cannot clear a
  variable stored in foreign code.
- External leases are counted independently. Releasing one handle preserves
  other leases; an identity-wide self-unload invalidates every handle. Release
  is harmless for an already invalidated token, while all other stale-handle
  operations return controlled ABI status.
- Garbage collection is mandatory and automatic. The standard library also
  provides synchronous `Function CollectGarbage() As Long`; it completes
  collection and eligible termination for the unreachable snapshot without
  affecting reachable objects or their external resources, returning exactly
  `1` when that pass did cleanup and `0` when it did not.
- UBE 1.0 adds no `Try`/`Finally`, `Using`, `Defer`, or resource registry.
  Programmers explicitly close or dispose external resources on relevant paths.
  Host process teardown reclaims remaining handles but does not guarantee UBE
  buffer flushing or execution of user cleanup code.
- Object/class/form/control reference assignment requires `Set`; plain `=` is
  value assignment. `As New` constructs immediately when its declaration is
  reached (module initialization for globals, first declaration execution for
  statics), reports failure as `Nothing` plus `Err`, and never silently
  recreates an object after it is set to `Nothing`.
- UBE 1.0 construction is parameterless: `New ClassName` has no arguments and
  private `Class_Initialize()` runs automatically once and cannot be called
  directly. Parameterized setup uses an ordinary Sub or factory Function;
  overloaded/parameterized constructors are deferred.
- UBE 1.0 has no user-class implementation inheritance. Polymorphism uses
  `Implements` and interface-typed references; reuse uses composition/modules.
  Forms and controls keep their dedicated framework lifecycle.
- Native source begins `UBE SOURCE 1 MODULE|CLASS|FORM|CONTROL` followed by
  mandatory `Attribute UBE_Name = "..."`; kind must match `.bas/.cls/.frm/.ctl`.
  The source-format version is independent of language version. Legacy
  `VERSION`/`VB_Name` marks compatibility input and native save emits UBE
  identity metadata instead.
- `Public Export Sub/Function` explicitly exposes a standard-module procedure
  through generated foreign ABI metadata; `Export` requires `Public`, is not
  implied by ordinary visibility, and is limited to ABI-supported signatures.
  `Kind = "Library"` builds the target shared-library format with no executable
  startup; returned objects use the agreed opaque external leases.
- UBE has no separate runtime/VM or installed execution environment. GC,
  threading, errors, memory support, and platform adapters are compiled and
  linked into each native output, with unused support eligible for removal.
- Optional private `Module_Initialize()`/`Module_Terminate()` hooks cannot be
  called directly. Every module, including the `Main` module, initializes in
  manifest order before `Main`/library exports; successful modules terminate
  once in reverse order before globals are released, with controlled cleanup
  after partial initialization failure.
- `Public Interface Name ... End Interface` declares a contract with Sub,
  Function, Property, and Event signatures only. It has no storage, body,
  constructor, or instance. `Implements` uses automatic exact name/compatible
  signature matching; identical multi-interface requirements may share one
  member, conflicts fail, and interface variables are strong references using
  `Set`. VB6 interface-class input maps through compatibility import.
- `Class_Terminate` is an exactly-once notification before an unreachable class
  instance is reclaimed, including cycle collection and orderly shutdown.
  Collection may be delayed; releasing one reference does not destroy an
  instance that remains reachable elsewhere. Time-sensitive external-resource
  cleanup requires an explicit lifecycle operation.
- `CallNew` and the thread library use ordinary nonnegative `LongLong` UBE
  identifiers. Zero reports creation failure, identifiers are not dangerously
  recycled within a process, and platform-native thread IDs/handles require an
  explicit platform-library query.
- `CallNew Qualified.Sub(arguments)` is both expression and standalone syntax.
  Its directly visible Sub and ordinary parenthesized arguments are resolved
  statically; empty `()` is required, and functions, callback variables,
  computed addresses, or runtime names cannot be targets in UBE 1.0.
- Thread stopping is cooperative only. `ThreadRequestStop` sets a flag and
  wakes supported waits; interrupted waits return 0 without `Err`, and the
  worker checks `ThreadStopRequested()` before returning or using `Exit Sub`.
  No forced-stop or `Exit Thread` syntax exists, preserving normal scope and
  lock cleanup.
- The thread API signatures and results are frozen: IDs/current ID are
  `LongLong`; `ThreadWait` has an optional `LongLong` millisecond timeout and
  returns 1 for completion or 0 for timeout/cancellation; stop request returns
  1 when recorded; liveness is Boolean; yield is a Sub. Completed valid IDs are
  harmless, never-issued IDs set `Err`, self-wait fails, and multiple waiters
  are allowed.
- `CallNew` evaluates arguments left-to-right before publication and permits
  only `ByVal` target parameters. Scalars, strings, arrays, and custom values
  cross as independent snapshots; object/class arguments share one strong
  identity. No caller-stack reference may escape, and unsynchronized shared
  access may be logically unordered but can never cause memory unsafety or
  undefined behavior.
- Threads retain all access granted by ordinary lexical scope: visible globals,
  modules, statics, fields, objects, forms, and controls are cross-thread
  accessible, while another procedure's local remains out of scope. Platforms'
  UI-thread requirements are hidden through synchronous transparent runtime
  dispatch with controlled cycle failure; UBE source has no UI-owner-thread
  restriction.
- `SyncLock object ... End SyncLock` is the reentrant structured monitor. It
  provides full memory visibility, rejects `Nothing` safely, accepts no value
  identity, releases on every exit/error/cancellation path, and pins an object
  against reclamation while owned or awaited. It remains distinct from file
  `Lock`; lock-order deadlocks are program logic with optional diagnostics.
- Ordinary scalar/reference access is non-tearing and memory-safe but compound
  updates can race. Sequentially consistent `AtomicBoolean`, `AtomicLong`,
  `AtomicLongLong`, and `AtomicObject` wrappers provide applicable load/store,
  exchange, compare-exchange, increment/decrement, and add operations. UBE 1.0
  exposes no weaker memory orders; multi-value invariants use `SyncLock`.
- UBE 1.0 standard-library coordination consists of `ThreadEvent`, `Semaphore`,
  and FIFO `MessageQueue` carrying `Variant`; manual `Mutex` is deferred because
  `SyncLock` supplies safer structured locking. Waits take
  `LongLong` milliseconds (`-1` infinite, `0` poll), return `Long` 1 when
  satisfied and 0 on timeout, and use 0 plus `Err` for invalid input or dead
  objects. Exact library APIs, condition variables, and typed channels are
  deferred from the core language contract.
- Form `Unload` first calls `Form_Unload(ByRef Cancel As Integer)`. Nonzero
  cancellation leaves the form uninterrupted. Once accepted, its native
  window, handles, and event-source registration are released before returning
  to the initiating user code; existing form procedures may unwind. After the
  final active form procedure exits, `Class_Terminate` runs, every managed
  alias becomes `Nothing`, and storage is reclaimed. Control-event details and
  concurrent-call admission remain open.
- Language-level `Unload` applies to forms and controls, not ordinary classes.
  Resource-owning classes provide their own appropriately named cleanup method
  and still receive `Class_Terminate` before reclamation.
- After accepted form/control unloading, no new procedure may enter the
  component; existing calls on any thread drain normally. Native-handle use
  then fails safely. The initiating thread does not wait for other threads;
  final termination and alias clearing occur when the final active call exits.
  Controls use cancellable `Control_Unload(ByRef Cancel As Integer)`.
- `RaiseEvent` is synchronous, subscription-ordered, and reentrant on the
  raising thread. Nested same-event dispatch runs immediately with its own
  subscription snapshot; UBE never suppresses or coalesces it. Native callbacks
  enter through the platform dispatcher, and recursion exhaustion is a
  controlled unwind rather than a process crash.
- Classes, project structures, and advanced language/production features are
  reserved for v3 unless strictly required to compile v3.

## Files currently in scope

- `compiler/UBE_Compiler_v1/`
- `compiler/UBE_Compiler_v2/`
- `compiler/UBE_Compiler_v3/`
- `bootstrap/build.ps1`
- `compiler/Roadmap.md`
- `compiler/Progress.md`
- `lang-doc/v3-language-definition.md`
- `lang-doc/conversion-table.md`, `lang-doc/managed-memory.md`,
  `lang-doc/foreign-abi.md`, and `lang-doc/threading.md`
- `lang-doc/grammar/ube-v3-delta.md`
- `lang-doc/language-spec.md` and `lang-doc/grammar/ube.ebnf` during normative
  integration

## Verification log

- 2026-10-15: promoted the resolved v3 design to the normative UBE 1.0
  specification and EBNF. The grammar integrity check passed with 175 unique
  productions, no undefined nonterminals, and all required v3 forms. Public
  documentation synchronization was deliberately deferred at the owner's
  direction; its existing grammar-word audit therefore reports the newly
  promoted words until that separate documentation work resumes.

- 2026-10-15: created the v3 project scaffold and design boundary. Both
  preserved v2 stages emitted byte-identical scaffold LLVM; LLVM linked it,
  the executable printed the expected design-stage message and exited 2, and
  `bootstrap/out/v3-scaffold-manifest.json` recorded compiler, source, runtime,
  target, tool, and artifact identities. The full bootstrap suite passed.

- 2026-10-14: stage zero compiled relocated v1; stage one compiled, linked, and
  ran both showcase programs successfully.
- 2026-10-14: the full `bootstrap/build.ps1` invocation passed lexer, parser,
  semantic, codegen, native profile, v1 positive, and v1 negative acceptance
  tests after expected native failures were isolated from PowerShell's
  terminating-error behavior.
- 2026-10-14: stage zero compiled the initial v2 driver; that binary emitted,
  linked, and ran the v2 `Sub Main` showcase successfully. Both v2 entry-point
  forms are now part of `bootstrap/build.ps1`.
- 2026-10-14: v2 added explicit token records, case-insensitive entry discovery,
  token-based showcase parsing, and chunk-joined LLVM emission. The complete
  bootstrap, v1, and v2 suite passes.
- 2026-10-14: v2 added bounded source/diagnostic storage, strict UTF-8 checking,
  located lexer diagnostics, and negative acceptance tests for malformed text.
  The full suite passes, including the embedded-NUL runtime regression.
- 2026-10-14: v2 added retained comments, escaped-string decoding, LLVM byte
  escaping, geometric token/text storage, and its first bounded flat syntax
  node. Parser-negative and end-to-end output tests pass in the full suite.
- 2026-10-14: v2 parses and lowers parenthesized and concatenated string
  expressions through recursive flat nodes; function-result literals also use
  syntax nodes. Positive and malformed-expression tests pass in the full suite.
- 2026-10-14: v2 added Unicode 18.0 identifier-letter classification and
  explicit continuation handling using only checked-in data. The showcase now
  exercises a Unicode procedure name and a commented continuation; the full
  bootstrap suite passes.
- 2026-10-14: v2 added pinned Unicode simple-fold lookup and UTF-8 scalar-wise
  case-insensitive equality. Semantic, lowering, native intrinsic, v1, and v2
  tests pass together.
- 2026-10-14: v2 added bounded procedure, type, and field declaration tables
  with Unicode-folded duplicate checks and controlled structural diagnostics.
- 2026-10-14: v2 added complete Bootstrap Profile procedure-header records and
  semantic entry-point resolution. Positive self-source parsing and negative
  parameter/result/entry diagnostics pass in the full suite.
- 2026-10-14: v2 added local, assignment, and call records plus initial body
  name resolution. Its own source passes; malformed declarations and unknown
  names have controlled regression diagnostics.
- 2026-10-14: v2 added general expression AST construction and recursive name,
  callable, indexing, and argument-count validation. Its complete source and
  malformed-expression corpus pass together.
- 2026-10-14: v2 added recursive expression type resolution and local
  initializer checks for intrinsic scalars, records, arrays, calls, members,
  and operators. Positive self-source and incompatible-type tests pass.
- 2026-10-14: v2 added typed lvalues, call contracts, operand constraints,
  numeric promotion, and callable classification. A negative test exposed and
  now guards an eager-`And` out-of-range crash path.
- 2026-10-14: v2 added structural and typed block `If` and `While` records.
  Stage one parses and analyzes all v2 source in every full bootstrap run; all
  bootstrap, v1, v2, and native tests pass.
- 2026-10-14: v2 added ordered `Dim`, `ReDim`, `Print`, and `Exit` lowering,
  bounded target-independent instruction records, and an initial verifier.
- 2026-10-14: v2 replaced showcase-only emission with whole-program LLVM for
  its Bootstrap Profile. Stage one builds stage two; stage two recompiles v2;
  fixed-point LLVM is byte-identical; positive and negative stage behavior is
  compared automatically. The complete build suite passes.

## Handoff template

Replace these fields when work begins or ends:

- Active item:
- Status:
- What changed:
- Decisions made:
- Commands run and results:
- Remaining failures or blockers:
- Exact next action:
