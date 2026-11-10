# Bootstrap semantic contract

This is the implemented boundary for the approved name-resolution and scalar
type-checking step. The normative language specification and conversion table
remain authoritative. Native lowering consumes these bindings under
[the lowering contract](LOWERING.md), with its own execution gate.

The bounded [aggregate extension](AGGREGATES.md) adds nominal finite Type
records and fixed rank-one arrays. Bindings retain type identity, field offsets,
element strides, rank and known bounds; ByRef array parameters retain unknown
caller bounds until execution. Known invalid indexing is rejected statically.
Record equality and independent record/same-known-bounds array copies are
admitted. Other aggregate paths listed there receive explicit diagnostics.

## Binding and ownership

The semantic pass consumes the retained ordered project syntax tree and produces
caller-owned symbols and per-node bindings. A binding records the declaration
identity and resulting type, rather than relying on a name string during later
lowering. Source nodes and their diagnostic spans remain available. A failed
pass does not publish a successful partial result.

Lookup uses the language's local/parameter region, Function-result assignment
context, current module, then accessible package members. Ambiguity at the
selected level is an error; a wrong signature does not cause a second lookup.
Module and package qualification select actual declarations and enforce access.
Labels occupy a separate procedure-local region. GoTo and On Error targets must
resolve there; this step introduces no additional prohibition on jumping into
an If branch. Duplicate declarations follow the normative case-insensitive
regions, not a single project-wide name table.

If a three-part qualifier's root simultaneously names the current package and
a module, namespace precedence is not yet defined by the full contract. This
case receives E_UNSUPPORTED. Ordinary two-part module qualification remains
available; failed member selection never retries a different namespace.

Executable projects require exactly one module-level Main, with no parameters,
declared as Sub or Function returning Long. Library projects have no startup
entry selection; a normally declared procedure named Main does not acquire an
entry role merely from its name.

## Official error-support declarations

The bootstrap supplies a compiler-owned, trusted declaration set for the
already-approved scalar error surface. This is an explicit support interface,
not a claim that the removed UBECore implementation has been restored or that
project references are already implemented.

| Receiver/member | Admitted signature | Stable binding role |
|---|---|---|
| Err | Error-support receiver | `error.object` |
| Err.Raise | Sub, one ByVal Number As Long | `error.raise` |
| Err.Clear | Sub, no arguments | `error.clear` |
| Err.Number | Long value read | `error.number` |

These declarations enter symbol resolution with explicit trusted origin and
role identities. An ordinary user declaration cannot acquire a role through
its spelling, its file/module name or a matching signature. User locals,
module/package members and a user module named Err take precedence over the
fallback support receiver. Once a user receiver is selected, a missing member
does not fall back to the support declaration. A user module's Raise procedure
remains an ordinary call.

The pass validates the admitted signatures and retains their role bindings.
Native lowering implements immediate procedure exit/FAIL for `error.raise`,
record clearing for `error.clear`, and the current thread's error-number read
for `error.number`. The existing record-only Error.Set primitive is not Raise.
The semantic pass itself does not execute these operations.

Only Number reads are admitted here; this does not settle full-language member
write capabilities. Optional Raise parameters, other Err members and legal
error-number value ranges remain pending. A literal Err.Raise call is legal
syntax and binding in a reusable procedure, not an automatic constant-error
diagnostic.

## Scalar values and calls

Storage and declared signatures admit Boolean, Byte, Integer, Long and LongLong.
Implicit assignment and ByVal/result conversions follow the normative matrix:
False is 0, True is -1, and a numeric zero/nonzero becomes False/True. Conversion
to Byte checks 0 through 255, so True cannot convert to Byte. Signed integer
destinations enforce their 16-, 32- or 64-bit ranges. Direct ByRef
requires exact-type writable storage. An extra grouping pair on an individual
argument instead requests a converted temporary, with callee writes discarded.
The call's argument-list delimiters alone do not request that temporary.

Integer addition, unary signs, comparisons and Boolean logical And retain
their typed operations. Byte arithmetic and unary signs promote to Integer;
binary integral operations select the common Integer, Long or LongLong type.
Integral And is bitwise in that common integer type.
Mixed Boolean/integer operator domains remain explicitly unsupported rather
than inferred from VB6 behavior; ordinary assignment conversions remain valid.
Boolean comparisons currently admit equality and inequality; Boolean ordering
and unary numeric operations remain deferred.

Decimal integer literals follow destination-context/default Long-or-LongLong
typing and authoritative explicit %, & and ^ suffixes. A numeric destination
context flows through grouping, addition, unary signs and integral And; it does
not turn a comparison's numeric operands into Boolean values. A literal which
outgrows its context widens before the expression's final conversion.
`2147483648 + -1` can yield a valid Long destination, while
`2147483647 + 1` overflows when Long arithmetic is selected. A LongLong
destination instead supplies LongLong context to those unsuffixed literals.
Constant folding must
check every selected operation and final conversion, retain source locations,
and never use floating-point approximation for integer values.

The same three suffixes are accepted on declarations and references. They are
not part of name identity and must agree with the selected declaration's type.
They do not request conversion of an ordinary function's return value; Adaptive
functions remain outside this profile. Byte and Boolean declarations require As.

Required constants may depend only on earlier visible constants, with no
variable reads, calls or dependency cycles. Literal-only arithmetic in normal
initializers/assignments receives the same checked folding. Runtime-dependent
expressions retain their types and conversions for lowering.

The current boundary admits earlier constants in the same module or procedure
and visible containing-module constants. The full specification does not yet
define a cross-module declaration order for required constant dependencies.
Cross-module Const-to-Const dependencies therefore receive E_UNSUPPORTED;
manifest order is not invented as a constant-evaluation rule. Ordinary
expressions may read accessible constants from another module once those
constants have been checked, including modules later in the manifest.

Hexadecimal/octal bit-pattern interpretation and noninteger operator domains
remain deferred by the normative specification. Their recognized syntax is
explicitly rejected by this semantic boundary. No host VB6 conversion silently
decides those language rules.

## Verification boundary

The semantic gate must assert resolved declaration identities, result and
conversion types, ByRef argument treatment, constants and trusted roles as
well as success/failure. Negative cases require source locations and controlled
diagnostics. Existing parser and loader gates must continue passing on the same
binary. Bounds and exact commands/results are recorded in the compiler handoff
before any completion claim.

The implementation bounds retained symbols at 16,384 and semantic expression
recursion at 128 levels. The latter is independent of syntactic nesting: a long
left-associative expression can have a deep tree without nested parentheses.
Hash-table candidate inspection has a separate four-million-step work budget.
These resource limits do not change the full language's semantics.

On 2026-11-10 the semantic gate passed all 76 cases with VB6 6.00.9782. The
same executable passed 37 parser cases and 54 loading cases. Symbol/depth limits
are exercised by the gate; the lookup-work guard is defensive and its exact
threshold is not separately qualified. Commands and artifact paths are in
`../compiler/Progress.md`.

## Explicit primitive declarations

Intrinsic declarations retain a Boolean syntax marker and a `primitive` child
containing the attribute target and decoded role. Binding requires exactly one
matching attribute and the complete declared signature for Array.Length or
Memory.CopyBytes. Only then is the canonical role published in the symbol's
existing BindingId field. Ordinary names, including user functions named like
the library declarations, carry no primitive authority. Unknown roles and
unsupported declarations fail explicitly. See COUNTED-BUFFERS.md.

## Bound inspection records

`--analyze` publishes the ordered project/module summary and ANALYZE OK only
after the complete project passes. `--dump-bound` additionally prints ENTRY
(the selected symbol, or zero for a library), SYMBOL declaration records and
BOUND node records. The test runner asserts these development records;
they are not a library serialization format or ABI.

Aggregate metadata extends SYMBOL records from 14 to 24 fields and BOUND
records from eight to 16 fields, preserving the original prefixes. The exact
appended field order is in AGGREGATES.md.

Expression constants describe the value before a surrounding conversion.
Declaration/assignment constants describe the converted destination value.
Each argument retains its formal destination type and value/alias/temp mode.
A directly signed integer literal is represented by its unary node's exact
constant; the magnitude token does not advertise a standalone positive value
that would exceed its selected signed type. All source syntax remains retained.
