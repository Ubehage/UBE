# First semantic checking contract

Status: **owner-approved bounded contract**. This defines the First semantic
checking deliverable in the existing development plan. It neither changes
UBE 1.0 nor selects semantic storage, a public phase API or another executor.
Implementation details are tracked in `SEMANTIC-IMPLEMENTATION.md`; executed
qualification and its exact limits are tracked in `SEMANTIC-EVIDENCE.md`.
The owner approved implementation after the behavior review; routine
VB6-compatible engineering decisions do not require another approval.

## Authority and deliverables

The authorities are `../../lang-doc/language-spec.md` (especially 2, 4–6, 8,
11 and 14), `../../lang-doc/conversion-table.md`, the focused memory/threading
contracts, and `../../lang-doc/grammar/ube.ebnf`. They outrank bootstrap behavior
and conflicting expanded wording. Project/reference admission remains governed
by `PROJECT-INPUT-CONTRACT.md`; syntax by `PARSER-CONTRACT.md`.

`SEMANTIC-SYNTAX-INVENTORY.md` records the actual input gaps. The independent
fixtures and future native obligations are under `tests/semantic/`.
`tools/check-semantic-contract.ps1` validates their definition and source anchors;
it never parses, binds or evaluates UBE. `SEMANTIC-EVIDENCE.md` records exactly
what that check proves. A consistent expected answer is not a verified checker.

Owner review guidance: use VB6 behavior for ordinary choices unless it conflicts
with an established UBE definition. Foundation-first development is already
agreed; it does not require another owner decision. Ask about actual observable
conflicts, not routine implementation details or settled development order.

## scope

Consume the existing qualified project/syntax graph: native MODULE sources in
the executable and at most its one explicit direct UBECore source reference.
Canonical source order is root manifest order followed by reference manifest
order, as already qualified. A reference is a package boundary, not a textual
include. Single-source diagnostics use the same rules in a one-module context.
The test package descriptions are oracle inputs, not a new manifest format.

The first checked subset includes:

- Boolean, Byte, Integer, Long and LongLong scalars; scalar module/local
  variables and constants; implemented Sub/Function signatures and bodies.
- Private/Public/Friend and the valid Global variable synonym; ordinary
  default visibility; Option Explicit/On, Compare Binary/Text, Base 0/1 and
  Private Module. Compare/Base have no new numeric behavior.
- Selected expressions in the `operators` section; plain/Let assignments;
  single-line/block If/ElseIf/Else and While; matching Exit Sub/Function/While;
  empty bodies and ordinary function-result assignments.
- Positional, named, optional and omitted arguments, ByVal, exact direct ByRef,
  and individually parenthesized ByRef temporaries for the supported scalars.
- Adopted opaque native values backed by Byte/Integer/Long: neutral/copy,
  exact-type parameters/results, equality, and explicit Value.Pack/Value.Unpack
  declarations validated under section 6.2. This does not implement their ABI.

Every admitted declaration and every body in both packages must be covered.
An unused unsupported declaration is still deferred. This cannot yet check the
whole production UBECore or fresh compiler, whose arrays, classes and other
features exceed this subset. Reference tests use small explicitly identified
UBECore package fixtures, never substitute them for the real library.

Arrays/ranks/bounds, field-only records, String (including fixed strings),
floating/pointer-sized/Currency/Decimal/Date/Variant/Object types, instances,
properties, hooks, enums, interfaces, foreign calls/exports, other intrinsic
roles, Static storage, Inline/ForceInline, lifecycle hooks, labels/GoTo/Return,
Print, With, Set/LSet/RSet, New/Me/AddressOf/TypeOf/CallNew, other control flow,
conditional selection and other source kinds remain explicitly deferred.
Existing frontend rejection/defer results pass through unchanged. No unsupported
feature is legalized or called a language error simply to complete this slice.

## names

Decode bracket escapes (`]]`), remove the permitted type character from name
identity, and compare with the existing pinned Unicode 18 simple fold. Retain
original spelling and exact spans. Do not normalize Unicode, lowercase with
the host locale, expand full-fold sequences, or identify names by raw bytes.
Suffix agreement is a separate check even when lookup succeeds. `%`, `&`, `^`
mean Integer, Long, LongLong; other suffix types are deferred unless there is
an independently decidable suffix conflict. No spelling confers builtin status.

## regions

Parameters, locals and local constants share one procedure declaration region;
If and While do not introduce C-style name scopes. Module fields, constants,
procedures and native types share their containing member region. Same-folded
duplicates are errors regardless of type, signature, brackets or suffix. No
procedure overloading exists. Function-result storage is the specified special
assignment target, not a second callable overload. Labels remain a separate
deferred region. Collect declarations before binding bodies; a module procedure
may refer to another declared later. Reads before a local's written declaration
are deferred in this bounded contract: it does not decide initialization/lifetime
behavior where the normative region rule alone is insufficient.

## lookup

Use the first matching level: procedure parameters/locals/constants; current
Function result in assignment context; own module members; accessible Public or
Friend standard-module declarations in the package; accessible declarations of
all direct references as one level. Multiple matches at that level are ambiguous.
Source/reference order never resolves ambiguity. A local non-callable shadows
an outer procedure: a wrong call does not search another level/signature.

`Module.Member` resolves a standard-module member with accessibility enforced.
Package membership comes from the admitted graph, not a filename or path. Own
module Private is visible locally, Friend only within its package, and Public
across the direct reference unless Option Private Module hides the module.
An inaccessible declaration supplies no unqualified candidate; an explicit
qualified inaccessible member reports InaccessibleName. An unqualified name
with no accessible match reports UndeclaredName. Equal module names across
packages do not become a source-order tie-break; ambiguous qualification errors.
Package-qualified spelling beyond Module.Member is deferred pending its focused
contract; this proposal does not invent a qualification syntax.

## types

Require an As clause or a nonconflicting scalar type character on each variable,
constant, parameter and Function result. There is no implicit Variant. A type
character and As must agree. Comma-separated declarations each need their own
type (`Dim a, b As Long` leaves a untyped). Resolve named native types with the
same identity/accessibility policy; unknown types report UnknownType.
An As-type lookup starts at the containing module: procedure-local values do
not hide datatype names, and procedures cannot declare Types. Thus a local
`Dim Token As Token` can use the module's declared Token datatype. Ordinary
expression lookup still selects the local value first.
`Any` outside external parameters is InvalidType, not a new general type.

Byte is unsigned 8-bit; Integer/Long/LongLong are signed 16/32/64-bit. Boolean
representation is not exposed. Supported numeric conversions are checked;
Boolean converts as False=0/True=-1 and numeric zero/nonzero to Boolean.
A known impossible conversion is ConstantRange; a runtime-dependent conversion
is retained as a checked operation, never rejected merely because it can fail.
No host C width, signed overflow or LLVM poison supplies language behavior.

## literals

The selected literal domain is True/False and decimal integers, with or without
explicit `%`, `&` or `^`. The owner confirmed destination-context typing on
2026-11-01, including literals inside arithmetic, and Long/LongLong defaults.
The primary specification and conversion table now record that decision.

For this subset, the integer destination context is supplied by a variable or
constant initializer, assignment/result destination, optional default, ByVal
parameter or forced ByRef temporary. Propagate it through Group, unary +/- and
integer +, -, *, \\, Mod operands. `Dim x As LongLong = 2147483647 + 1` therefore
has LongLong operands and succeeds. Byte operands still promote to Integer under
the ordinary operator rules: `Const x As Byte = 200 + 100 - 100` succeeds.
The destination is not a restriction that makes a representable literal fail:
if an unsuffixed integer does not fit that context, choose a wider supported
integer type that holds it. For example, in `Dim x As Integer = 40000 - 10000`,
40000 uses Long, the common arithmetic type is Long, and the result 30000
converts successfully to Integer. Check the calculated result against the
destination, not each literal against that narrower destination. Explicit
suffixes still cannot widen silently. This does not add automatic widening of
an arithmetic operation whose already selected operand/result type overflows.
Each call argument starts from its own parameter context, never the caller's
result destination. Comparisons, Boolean/bitwise operations and noninteger
destinations supply no integer destination to their numeric operands; these use
the Long/LongLong default. These precise propagation boundaries are part of
this proposal for review, not permission to infer new noninteger conversions.

Without integer destination context, use Long for values in -2147483648 through
2147483647 and LongLong otherwise, through -9223372036854775808 and
9223372036854775807. A signed unsuffixed literal (unary sign with only intervening
Group nodes) uses that mathematical value for representability, while preserving
the syntax nodes. Other negations operate on their normally typed operand.
An unsuffixed value beyond every supported integer type diagnoses ConstantRange.
The owner confirmed that known final values outside the destination range are
compile-time ConstantRange errors, in ordinary initializers/assignments as well
as Const declarations. Only runtime-dependent faults use the runtime Err rules.
Literal suffixes are never overridden by the destination: the Long additions in
`Const x As LongLong = 2147483647& + 1&` still overflow before conversion.

Explicit suffixed signed-minimum spellings such as `-32768%`, and signed
hexadecimal/octal bit-pattern interpretation remain DeferredLiteral until their
remaining boundary detail is reviewed. Tests can express suffixed minima using
`-32767% - 1%`, `-2147483647& - 1&`, and `-9223372036854775807^ - 1^`.
Real/string/date/Null/Empty literals and their conversions remain outside this
subset. Neither context nor the default rule invents a numeric-to-native-value
conversion; a native destination supplies no representation-type literal context.

## operators

For supported integers: unary +/-, +, -, *, integer division `\`, Mod,
comparisons =/<>/</<=/>/>= and bitwise Not/And/Or/Xor/Eqv/Imp. Unary integer
operations promote Byte to Integer; binary integer operations promote Byte to
Integer then use the first of Integer/Long/LongLong covering both operand types.
For Boolean: Not and eager And/Or/Xor/Eqv/Imp, =/<>, and short-circuit
AndAlso/OrElse. Short-circuit operators require Boolean operands; numeric-to-
Boolean conversions are available in condition/assignment/call contexts, not a
way to erase that requirement. Mixed Boolean/integer eager operations and Boolean
ordering are deferred until their operator-selection detail is reconciled;
the general conversion matrix does not itself choose an operator signature.
`/`, `^`, `&`, Like and identity comparisons are outside the selected type domain.

Integer arithmetic is checked in its result type before any destination
conversion. Division truncates toward zero and Mod has the dividend's sign.
Known overflow/divide-by-zero is ConstantRange/ConstantDivisionByZero;
runtime-dependent failure retains neutral-result and thread-local Err semantics.
Both branches/operands are statically bound and typed, including an unexecuted
short-circuit operand. Evaluation facts retain left-to-right exactly-once
operands, eager versus conditional right evaluation, and checked conversions.
No optimizer may reorder observable errors or evaluate a skipped operand.

## constants

Literal-only integer arithmetic must be evaluated during compilation and reduced
to a typed constant, including in ordinary initializers and assignments. This
is required at every optimization level, not an optional optimizer improvement.
For example, both forms of `40000 - 10000` assigned to Integer carry a folded
Long value 30000 and then the ordinary destination conversion. Keep original
source spans for diagnostics/debugging. Evaluate the existing grouped operations
with their selected types and checked arithmetic; folding cannot silently widen
explicit suffixes, reassociate mixed runtime expressions, suppress known faults
or invent host-language arithmetic rules. Constant subexpressions inside runtime
expressions may fold, without evaluating runtime values or changing their order.

Required constants/defaults contain only supported literals, parentheses,
previously declared accessible constants and supported operators. Variables and
ordinary calls are NotConstant, even if a host optimizer could fold them. Constant
dependencies are acyclic and later constants are not available early. A known
failure is a diagnostic, never a successful neutral constant plus simulated Err.
Static type checking still covers skipped operands; do not execute an unreachable
operation solely to manufacture a runtime failure during constant evaluation.

## assignments

An ordinary scalar declaration establishes its neutral storage before evaluating
an initializer. `Dim x As Integer = expression` has the same declaration and
assignment behavior as `Dim x As Integer` followed by `x = expression` in that
scope. The initializer uses the same expression types/conversions/error rules;
it does not delay creation of x or remove its storage when a runtime operation
fails. In particular, the variable exists during its own initializer and after
a recoverable initializer failure. This does not bypass compile-time diagnostics
or guarantee storage after failure to establish the declaration itself.

Targets are writable supported variables or current Function result storage.
Constants, literals, arbitrary expressions, procedure values and call results
are NotAssignable. Plain/Let assign values; Set on known non-reference targets
is InvalidAssignment rather than numeric assignment. Native values require
exact nominal identity: representation types and distinct native declarations
never implicitly convert, even with identical layouts. Same-type copies retain
semantic value independence. Same-native =/<> returns Boolean; ordering,
arithmetic and condition conversion are invalid. No raw payload field access.

## calls

Bind one declared Sub/Function; never recover a bad signature by selecting
another same-spelled procedure. Expression calls require Function. Statement
calls may discard a Function result. Call F, Call F(), expression F(), and bare
F with zero arguments retain their specified distinctions and zero slots.
An ordinary library function, including a bracketed familiar builtin name,
uses only its declared signature and the ordinary visibility rules.

Required parameters precede Optional. Every Optional has a constant default
convertible to its explicit type; all later ordinary parameters are Optional.
ParamArray's Variant array is deferred. Associate arguments in source order:
positional before named, case-insensitive named matching, no duplicate/unknown
names, no missing required or excess arguments. An omitted slot differs from
zero arguments. Wrong named/positional association is InvalidArguments.

Default passing is ByRef. A direct argument aliases writable exact-type variable
storage, with no numeric/native conversion. Constants, Function results and
expressions are InvalidByRef. An extra pair of parentheses around an individual
argument forces one evaluation/conversion into a temporary of the parameter
type, whose writes are discarded. Omitted optional ByRef gets its own initialized
temporary. ByVal permits the ordinary checked conversion/copy. Preserve both
source evaluation order and source-slot-to-parameter mapping; named association
does not reorder evaluation. Aliases last only for the dynamic call.

## results

The written End Sub/Function must match the declaration. Function-name
assignment selects its declared result type after the local lookup level;
an unassigned result remains neutral, not a definite-assignment error invented
for this slice. Reading a Function call uses its return value; using a Sub as a
value is InvalidCallTarget. Recursive ordinary calls are permitted.
Executable projects require exactly one parameterless module Sub Main or
Function Main As Long; a wrong signature, zero or multiple candidates is
InvalidEntryPoint. Reference Library packages do not select an entry point.
Their ordinary Main-named procedures do not replace the root entry.
Wrong Exit kind is InvalidExit; other statement families remain deferred.

## options

Option Explicit/On is redundant; Off is ImplicitTypingDisabled. Compare Database
is InvalidOption. Existing syntax/defer handling of legacy Def statements is
preserved, never interpreted as implicit declarations. Repeated/conflicting
option policy beyond explicitly invalid values is deferred for separate review.

## boundary

Only Byte/Integer/Long native representations are admitted. Known managed,
nested-native or other representations are DeferredRepresentation, not a new
representation policy. Pack/Unpack must be declared in the type's own module,
with exactly one ByVal parameter, exact representation/native result relationship,
no body, one binding per declaration and at most one of each role per type.
Attribute target, role matching and unknown-role diagnostics follow section 6.2;
no fallback external symbol or type/procedure spelling lookup is allowed.
Recognized other adopted primitive roles remain DeferredPrimitive in this slice.
Unknown roles are InvalidPrimitive. Unknown reserved UBE attributes retain the
existing earlier envelope diagnostic; they do not reach semantic binding.
Ordinary and VB_ metadata are retained without granting execution semantics.
Lifecycle/Inline/ForceInline/Export declarations are deferred, even if uncalled.

Reusable numeric decoding, scalar folding/comparison and generic lookup/storage
algorithms belong in UBECore after demonstrated need and their own contract.
Literal grammar, target ranges, scope/call/type selection and diagnostics stay
in the compiler. Use existing ByteBuffer/Utf8Cursor/Unicode and typed storage
where qualified; no duplicate general numeric parser, magic String implementation,
generic collection API or new intrinsic set is authorized by this document.

## diagnostics

Symbolic classes in fixtures specify domain behavior, not public numeric codes,
wording or a source ABI. Before CLI implementation, extend the existing diagnostic
contract with reviewed concrete codes/messages and allocation-free fallbacks.
The fixture `at` is the exact primary original span; related declaration spans
may be attached without changing the primary. Positions use existing zero-based
UTF-8 byte/scalar and one-based scalar line/column coordinates; no normalization.
Missing Main anchors at root source 0 EOF; multiple Main anchors at the second
candidate; a bad Main signature anchors its name.

Existing frontend failures precede semantic work. Semantic declaration collection
and signature validation precede body binding, followed by root entry validation
only if previous work succeeds. Within each category choose lowest canonical
source ID then first original byte then the fixed diagnostic list order in
`tests/semantic/definition.json`. A duplicate anchors the later written name;
a wrong terminator anchors the entire written End marker. Deferred candidates
participate in that same ordering; a deferred construct is not inspected for
unpromised semantic errors. Fixtures isolate one issue except explicit ordering
tests. Completion timing never selects the reported failure. Resource/cancel
failure has its separate disposition and may prevent a semantic answer.

## publication

Keep the qualified ProjectSyntax/SourceWork/SourceOwner graph immutable and alive
for every returned span/binding. Declarations, types, bound operations, conversions,
call-slot associations and source identities form one complete logical result.
Private pending construction may be incomplete; public output never is. Failed
admission, decoding, lookup growth, body work or final publication preserves the
entire prior result and its source owners. Fresh status, not stale Err, signals
success. Initialize the existing safe storage-failure fallback before managed
entry. Semantic rejection, deferred capability, invalid caller/domain, caller
budget, storage/root failure and cancellation are distinct outcomes.

Logical fixture facts are observations, not a production node layout or phase
interface. Declaration identity is package + module + declaration kind + original
name span; local identity additionally includes its procedure. Never assign
identity in worker completion order or persist task/session numbers in symbols.

## concurrency

Prepare and freeze declaration/type information before private body work. Reuse
the established compiler-owned budget (1, 2 or 4), immutable owners, admission,
completion/cancellation/drain policy and canonical merge. Parse workers must be
drained before a later work category reuses slots. No concurrent nested pools,
global mutable semantic model, compiler policy in UBECore, whole-project worker
copies or restart-per-procedure compilations. Cancellation drains every admitted
worker before returning and never publishes partial declarations/body results.
Independent simultaneous project contexts must not share mutable state.

## resources

Retain existing 256-source, 16,777,216-byte/source and 1,048,576-token/source
admission limits. Proposed semantic caller budgets are declarations, emitted
facts and pending work each in 0..1,048,576, and active traversal depth in 0..256;
these are resource limits, not language limits. Account all unpublished records
and scratch work, including discarded validation detail. Test zero, below, exact
and above each measured requirement and invalid negative/excessive budgets.
Depth must not measure flat left-associative tree height as native recursion.
Use explicit traversal work storage; no source-controlled stack overflow.
Exhausted resources must stop without unbounded retries, corrupt roots or loss
of an old result. External resources remain owned/closed under existing contracts.

## costs

Before production implementation, measure focused candidate storage/lookup probes
in actual UBE through both selected source-built stages. Set representation-
specific constants in that reviewed probe contract before choosing a layout.
Count real source/token reads, folding scalars, comparisons/probes, lookup work,
record writes, allocations, copied bytes, zeroed capacities, roots, peak retained
storage and cleanup. No counters manufactured from input size. Require zero
worker source-payload copies, no per-insert whole-table/project/result copies,
bounded geometric growth and no repeated full-module scan per name use. Separate
total identifier bytes and explicit collision/comparison cost from syntax visits;
publish the worst-case/collision strategy, not an unproved O(1) hash claim.
Compare 1/2/4 jobs with the serial reference and preserve frontend regression
guards; do not claim semantic speedup from frontend's historical measurements.

## acceptance

The current definition gate checks all fixture schemas, requirement coverage,
source/span/coordinate references, binding-target and type/fact domains, inventory
source evidence and negative controls. It audits the current selected accepted
input/artifact identities unchanged; it does not rebuild/requalify them.

The separate `check-semantic-inputs.ps1` gate qualifies only current frontend
admission of each independent source through both existing CLI stages, with
exact already-specified diagnostics. It supplies no semantic expected answer.

Implement and qualify the narrowly required parser detail
extension first, with existing parser witnesses unchanged in their old projection
and new independent detail witnesses. Probe semantic storage/algorithms before
production code. Then run the future obligations in `tests/semantic/obligations.json`:
complete independent binding/type/conversion/call/diagnostic observations through
both source-built stages, all failure/resource/lifetime/concurrency/cost gates,
and retained source/parser/project/CLI gates. A bounded semantic success emits
no executable and must not imply full-language or backend acceptance. The later
First checked native executable deliverable remains separate.
