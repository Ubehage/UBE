# UBE expression and constant binding

Status: native expression, constant and allocation/depth acceptance passes at
O0/O2. Exact evidence is recorded in compiler/Progress.md.

This is the next approved dependency after DECLARATION-BINDING.md. It moves
reference selection, expression typing and checked constant evaluation into
UBE over the existing retained project trees. SEMANTICS.md and the normative
language specification remain authoritative; no new language rule is introduced.

## Admission

The pass must resolve the admitted local/parameter, assignment-only Function
result, current module, accessible package member, module/package qualifier and
trusted Err fallback regions in their existing order. Wrong-kind or incompatible
selected declarations do not trigger another lookup. Field and array references
retain nominal type and rank without computing runtime record layout.

Check scalar operators, calls, assignment/result/ByVal conversions, exact-type
writable direct ByRef arguments, grouped converted ByRef temporaries, Boolean
conditions and procedure-local label targets. Preserve suffix assertions.
Constants use exact Boolean/Byte/Integer/Long/LongLong values, destination-context
literals, authoritative suffixes and checked intermediate operations. Directly
negated decimal literals include the signed 64-bit minimum. Hex/octal and other
unsettled domains remain explicitly unsupported. Earlier visible constant
dependencies are checked; cross-module Const-to-Const ordering is not invented.
Ordinary expressions may use checked accessible constants from later modules.

The component does not grant intrinsic authority, calculate storage layouts or
lower executable code. Source-defined intrinsic signatures may participate in
type checking but do not acquire trusted runtime roles from this pass. Official
Err support is an explicit fallback after ordinary user declarations, preserving
shadowing and invocation-local error-control semantics.

## Ownership and reuse

Expression binding obtains declarations through the existing declaration pass,
then reuses its exact-region name index. It does not trust caller-forged symbols
or duplicate lexical decoding/hash implementations. Input syntax remains owned
by the caller; work indexes and candidates are per-request values with no mutable
global project state. A single per-node binding array publishes only after
successful analysis. Failure preserves the old array and resets the public count.

Constant helpers return controlled invalid/unsupported/overflow status without
using a floating approximation. Ordinary invalid source must not accidentally
raise a host arithmetic error; unexpected helper failures propagate to the
public controlled boundary. Existing heap, native-frame and source limits stay
in effect unless a focused measured dependency justifies changing them.

## Retained interface

`ExpressionBinder.TryBindExpressions(Bytes(), Tokens(), Nodes(), Modules(),
Counts, PackageName(), IsExecutable, Bindings(), BindingCount, Diagnostic)`
derives private declarations and returns Boolean status. IsExecutable is ByVal;
the other arguments are ByRef. Input pools and package identity follow the
ProjectSyntax contract. The inputs and output variables must be independent.
Success publishes one fact for each syntax node and preserves sticky Err.
Failure resets BindingCount and preserves the previous binding array; callers
must save its old count separately if they intend to retain the old result.
Entry refusal follows ordinary language FAIL before the body can reset outputs.

BoundExpression has SymbolIndex, ScopeSymbol, TypeCode, TypeSymbol, ArrayRank,
ConvertedType, ArgumentMode, Writable, ConstantKnown, ConstantValue, AccessKind,
TrustedRole, HasBounds, LowerBound and UpperBound. ConstantValue and bounds are
LongLong; Writable/ConstantKnown/HasBounds are Boolean; other fields are Long.
Fact storage index is global syntax-node ID minus one. Source symbol IDs match
the deterministic declaration pass over the same immutable inputs. Scope and
declaration identities remain distinct from selected value/call identities.

ArgumentMode is zero when unused, 1 for ByVal, 2 for a direct ByRef alias and
3 for a grouped converted temporary. AccessKind is 0 for ordinary access,
1 for a field, 2 for an indexed element and 3 for a package qualifier.
TrustedRole is 0 for ordinary source, 1 for the official Err receiver, 2 for
Raise, 3 for Clear and 4 for Number; trusted fallback nodes have no source
SymbolIndex. These roles do not confer authority on source intrinsic attributes.

Expression ConstantValue describes the value before its surrounding conversion.
Declaration and assignment facts describe the checked converted destination
value. A directly negated magnitude token is not advertised as a standalone
positive constant. Mutable declaration initializer facts never make later reads
of the variable constant. Grouped ByRef arguments retain their source type and
an explicit destination conversion; their writes affect a temporary.

Declaration/shape nodes retain declared fixed bounds. Reference nodes carry
HasBounds only while that proof remains valid. Whole-array assignment, an array
initializer or any unvalidated source intrinsic declaration conservatively
invalidates reference bounds project-wide. All declared bounds are still checked.
This effect policy is deliberately conservative until intrinsic authority is
validated; it never removes runtime bounds guards.

Recursive nominal records may be checked for same-Type equality: all admitted
fields are comparable scalars or nominal records, and array fields are explicitly
unsupported. This is type checking of recursive edges, not runtime recursive
storage or comparison execution. Aggregate results, ByVal aggregates and grouped
aggregate temporaries remain explicitly unsupported by this bounded component.

Diagnostics reuse DeclarationBinder.BindingDiagnostic and categories, adding
argument=10, constant=11 and label=12. Locations are physical module-local byte/
UTF-16 positions with global node/token IDs. The pass bounds semantic recursive
entries at 64 and lookup work at four million steps, under the existing source,
symbol, heap and native-frame limits. Syntax depth and semantic depth are separate.

## Acceptance before completion

Execute real multi-module sources through the UBE pass at O0/O2 and compare
declaration identities, result/conversion types, argument modes, nominal types,
constant values and exact original diagnostic positions. Exercise actual
compiler/library bodies, not merely their declarations. Reject unresolved or
inaccessible references, ambiguity, incompatible calls and assignments, illegal
ByRef storage, unknown labels, invalid constants and unsupported domains.

Include integer minima/maxima, intermediate overflow before conversion, context
and suffix effects, constant dependencies, user shadowing of Err, independent
requests, changed-input negative controls and atomic result preservation.
Inject allocation and native-depth failures, exercise malformed input and
semantic depth/work bounds, and assert cleanup and successful retry. Run the
relevant declaration/parser/scanner regressions and inspect production-only
native output independently of any test driver support. Record exact commands,
limits, results and the next handoff in compiler/Progress.md before completion.
