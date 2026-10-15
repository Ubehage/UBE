# UBE 1.0 declarations and types audit

**Status:** reviewed and promoted to the normative specification and EBNF  
**Compatibility basis:** classic Visual Basic declaration behavior wherever it
does not conflict with UBE's mandatory explicit typing, checked conversions,
managed values, deterministic initialization, or portable 64-bit model  
**Scope:** arrays in parameters and results, constants, enums, custom `Type`
declarations, class/interface member legality, `Me`, `With`, fixed-length
strings, type characters, and `DefType` compatibility

This document records declaration/type gaps discovered by comparing
`language-spec.md`, `v3-language-definition.md`, `conversion-table.md`, and
`grammar/ube.ebnf`. It does not itself change the language. Rules should be
promoted to both the normative prose and grammar together.

## 1. Executive findings

The existing contracts already establish the important value model: arrays
and custom datatypes copy by value, recursive custom-type edges are managed,
objects retain identity, enum storage is `Long` or `LongLong`, declarations
are explicitly typed, and fixed strings pad or truncate. The following gaps
remain:

1. The EBNF can declare array parameters but has no syntax for an array-valued
   Function or Property Get result.
2. `constant-expression` is currently an alias for every expression; the
   permitted names and operations, dependency order, cycles, and evaluation
   type are not specified.
3. Enum implicit numbering is defined, but name visibility and constant
   dependency rules still need to be tied to the constant-expression model.
4. `type-member = variable-item` accidentally accepts field initializers and
   `As New`, neither of which is compatible with a plain value datatype.
5. Source-kind legality is mostly semantic and lacks one complete matrix.
   Consequently the grammar structurally accepts `Me`, `Implements`, Events,
   interfaces, and several declaration forms in contexts where prose only
   partly rejects them.
6. `With` does not say explicitly that its target is evaluated once and kept
   alive for the block.
7. The EBNF permits `* n` after every intrinsic type, although only `String *
   n` is meaningful. The legal length domain and ABI consequences are not
   frozen.
8. Type-character conflict rules exist, but suffix legality on declarations
   versus member names needs a single rule. Classic `DefType` statements are
   absent without an explicit compatibility diagnosis.

None of these findings requires changing the approved object identity,
garbage collection, recursive-value, threading, or module-initialization
architecture.

## 2. Arrays in declarations, parameters, and results

### 2.1 Existing behavior

The grammar accepts ordinary array declarations before the `As` clause:

```ube
Dim Values() As Long
Dim Grid(0 To 9, 0 To 9) As Double
Sub Sort(ByRef Values() As Long)
```

Formal parameters use `array-rank`, so they declare rank but no bounds. This is
the correct VB-shaped surface: actual bounds belong to the passed array, not
to a formal parameter declaration. `()` means rank one; `(,)` means rank two,
and so on. `ParamArray` remains exactly one-dimensional `Variant()` under the
approved call contract.

UBE's value model makes both passing modes meaningful:

- `ByRef Values() As T` aliases an array variable of exactly the same element
  type and rank. Rebinding or mutation is visible to the caller.
- `ByVal Values() As T` receives an independent array value under the approved
  array-copy contract. Element mutation or `ReDim` affects only the parameter.
- Omitted passing mode remains `ByRef` for VB compatibility.

An unallocated dynamic array remains a valid array value distinct from an
allocated zero-element array. Copying preserves that state. This distinction
is necessary for deterministic `Erase`, `ReDim`, and foreign-boundary behavior
even if no public inspection function is yet frozen.

### 2.2 Missing result syntax

`function-header` and `property-get-header` end in `as-clause`, whose
`type-name` cannot carry an array rank. The grammar therefore cannot express
the classic result form:

```ube
Function ReadLines() As String()
Property Get Items() As Item()
```

Recommended rule:

- A UBE Function or Property Get may return an array of fixed rank.
- The result syntax is `As element-type array-rank`, for example `As Long()`
  or `As Byte(,)`.
- A result never declares bounds; it returns the complete array value and its
  current bounds.
- Assigning the procedure name uses ordinary value assignment and the returned
  value transfers out as an independent semantic array value. Implementations
  may move or share copy-on-write storage when unobservable.
- A Sub, Property Let/Set, Event, constructor/lifecycle procedure, and
  `CallNew` target has no result type.
- `Declare Function` must not return a managed UBE array directly. Foreign
  array transfer requires an explicit ABI-safe declaration or generated UBE
  library boundary; a raw platform ABI has no portable UBE array layout.
- Interface Functions and Property Gets use the same result syntax and rank;
  an implementation must match element type and rank exactly.

The grammar should add a result-specific production rather than appending
`array-rank` to general `type-name`, because VB variable declarations remain
`Values() As Long`, not `Values As Long()`.

### 2.3 Other required array declaration checks

- Fixed bounds are legal for fields, locals, static locals, and custom-type
  fields. Dynamic bounds are evaluated when execution reaches an automatic
  local declaration and during the containing module/instance initialization
  for fields. Each bound expression is evaluated once, left to right.
- A declaration with fixed bounds cannot use `ReDim`; a dynamic array can.
- `As New`, `WithEvents`, and fixed-length-string syntax apply to the element
  declaration only where their own contracts allow them; an array itself is
  never an object identity and cannot be `WithEvents` or `As New`.
- An array declaration initializer, if retained generally by UBE, needs an
  array-valued expression of identical element type and rank. UBE 1.0 has no
  array-literal syntax. The simpler VB-compatible rule is to reject array
  declaration initializers and initialize arrays only by assignment, return,
  or `ReDim`.

The last recommendation avoids inventing syntax and should be adopted unless a
separate array-initializer feature is deliberately added.

## 3. Constants and constant expressions

### 3.1 Problem

The EBNF deliberately parses `constant-expression = expression`, with a note
that semantic validation rejects nonconstants. The semantic documents do not
yet define the exact accepted subset. Without that definition, compilers may
disagree about calls, property reads, forward references, overflow, `Null`, or
object-related operators in Const, Enum, Optional defaults, and static bounds.

### 3.2 Recommended VB-compatible closed subset

A compile-time constant expression may contain only:

- scalar, String, Date, Boolean, `Nothing`, `Null`, and `Empty` literals where
  the destination context permits them;
- a previously declared Const visible at that source position;
- an already established Enum member;
- parentheses;
- unary `+`, `-`, and `Not`;
- arithmetic, integer division, `Mod`, concatenation, comparison, and logical
  operators whose operands and result are themselves constant; and
- an explicit compiler-known conversion syntax only if such syntax is later
  added to the language. Ordinary library calls are not constant merely because
  the compiler could fold them.

It may not contain variables, fields, array indexing, object creation,
`Nothing` identity tests, `Me`, `With` leading-dot access, calls, properties,
events, `AddressOf`, `CallNew`, or operations whose behavior depends on
runtime state, locale, thread state, or `Err`.

Constants are resolved in declaration order. A comma-separated declaration is
also left-to-right, so `Const A As Long = 1, B As Long = A + 1` is valid.
Forward references and dependency cycles are compile-time errors. This is the
simplest deterministic VB-shaped rule and makes incremental compilation clear.

Constant evaluation uses the same operator typing and checked conversion rules
as runtime expressions but is performed with exact intermediate checking.
Overflow, division by zero, invalid conversion, invalid date, non-finite value
where forbidden, or a result not representable by the declared type is a
compile-time error; it never becomes a neutral value plus `Err` during
compilation.

Every Const still needs an explicit `As` clause or identifier type character,
as already required by UBE. This intentionally differs from classic VB's
implicit type inference and is required by UBE's approved mandatory typing.
`Nothing` is valid only for a compatible reference constant if UBE elects to
permit reference Consts; the safer VB-compatible rule is that user Consts are
limited to scalar, String, Date, and Enum values. `Null` and `Empty` are valid
only as Optional `Variant` defaults, not as ordinary fixed-type Const values.

**Recommendation:** freeze user Consts as scalar/String/Date/Enum only. Object
identity and managed aggregate constants would require initialization and
ownership rules that UBE does not otherwise need.

## 4. Enum declarations

The expanded definition already supplies the useful VB behavior:

- omitted underlying type is `LongLong`;
- only explicit `As Long` or `As LongLong` is legal;
- the first omitted value is zero;
- each subsequent omitted value is the preceding value plus one;
- explicit values are compile-time integral constants fitting the underlying
  type; and
- duplicate numeric values are legal.

The following details should be stated normatively:

- Enum member names share the Enum's member region and are unique after case
  folding. A type character is not legal on an Enum member.
- An explicit member expression may refer only to constants and Enum members
  already visible at that declaration point. It may refer to an earlier member
  of the same Enum, but not a later member.
- Implicit increment is checked. Incrementing the maximum underlying value is
  a compile-time error.
- The declared Enum type and its member names occupy their containing type/name
  regions under the ordinary lookup rules. Qualification as
  `AccessMode.Read` is always legal; whether an unqualified `Read` is visible
  should follow classic VB and the existing containing-scope lookup rather
  than create a new import mechanism.
- Enum members are constants, not storage, and cannot be assigned, passed
  direct `ByRef`, or carry visibility independently of the Enum declaration.

No owner decision is needed: these are direct consequences of the approved
Enum and name-resolution models.

## 5. Custom `Type` fields and recursive values

### 5.1 Existing approved model

Direct and indirect recursive custom datatypes are value types. Only recursive
inline edges use hidden managed storage; ordinary fields retain ordinary
layout. Reading or writing through a recursive edge materializes as deeply as
the executed access requires. Assignment deep-copies value fields and
recursive descendants while retaining object identities in object fields.

Arrays of the containing type do not themselves require a hidden recursive
edge because an array is already managed out-of-line storage. Their elements
use normal custom-value semantics. A fixed inline array of the containing type
is nevertheless recursive in semantic content and must be represented without
infinite inline layout; the compiler should treat that member as a managed
recursive aggregate rather than trying to embed infinite storage.

### 5.2 Grammar defect and recommended field rules

The current production reuses `variable-item`, so all of these parse:

```ube
Type Bad
    Count As Long = 3
    Child As New SomeClass
End Type
```

Classic custom datatypes are passive value layouts. Recommended rule:

- A Type field consists only of a typed name, optional array bounds/rank, and
  an `As` clause or nonconflicting type character.
- A Type field has no declaration initializer and cannot use `As New`.
- `WithEvents`, hooks, `Static`, visibility modifiers, Const, Event,
  procedures, properties, nested Type/Enum/Interface declarations, and
  executable statements are invalid inside a Type.
- Field declaration order is layout/initialization order. Every field starts
  at its declared type's neutral value, with recursive edges unmaterialized.
- A field may have a scalar, String (including fixed length), Enum, array,
  another custom type, Variant, or object-compatible reference type. `Any` is
  forbidden by its existing foreign-parameter-only rule.
- A Type has at least one field. Empty Types should be rejected because they
  have no useful VB-compatible value/layout and complicate ABI size rules.
- Duplicate field names after case folding are errors. Fields are accessed by
  ordinary dot syntax; no field is Default.

This requires a dedicated `type-member` production instead of `variable-item`.

## 6. Source kinds and member legality

The grammar intentionally shares one `module-body`, but semantic validation
needs a complete table so implementations do not infer legality differently.
The following table consolidates the existing VB defaults and approved UBE
contracts.

| Construct | MODULE | CLASS | FORM | CONTROL | Interface body | Type body | Procedure body |
|---|---:|---:|---:|---:|---:|---:|---:|
| Variable/field | yes | yes | yes | yes | no | field only | local only |
| Const | yes | yes | yes | yes | no | no | local yes |
| Type / Enum | yes | yes | yes | yes | no | no | no |
| Interface declaration | yes | no | no | no | no nesting | no | no |
| Sub / Function / Property body | yes | yes | yes | yes | signatures only | no | no nesting |
| Event declaration | no | yes | yes | yes | signature yes | no | no |
| `WithEvents` field | yes | yes | yes | yes | no | no | no |
| `Implements` | no | yes | yes | yes | no | no | no |
| External `Declare` | yes | no | no | no | no | no | no |
| `Intrinsic` / `Export` | standard module only | no | no | no | no | no | no |

Notes:

- Allowing forms and controls to `Implements` interfaces follows classic VB
  instance-module behavior and does not add implementation inheritance.
- Native Interface declarations should be package-level declarations written
  in a standard module source unit. Allowing an Interface inside an instance
  type would create ambiguous ownership and construction visibility without
  adding expressive power.
- Type and Enum declarations in instance modules retain the already specified
  default Private visibility. They describe nested names, not per-instance
  storage.
- Module lifecycle hooks belong only to `MODULE`; class lifecycle belongs to
  CLASS/FORM/CONTROL as already specified. Form/control events retain their
  dedicated framework contracts.
- A CLASS/FORM/CONTROL member is an instance member. UBE 1.0 has no Shared or
  class-static member surface; procedure `Static` changes local storage only.

The EBNF may remain structurally permissive if semantic fixtures test every
rejected cell. A source-kind-specific grammar would provide earlier recovery
but is not necessary for language meaning.

## 7. `Me` and `With`

### 7.1 `Me`

Existing prose correctly says that `Me` is the current CLASS, FORM, or CONTROL
identity. Complete rules should add:

- `Me` is legal only in an instance procedure, property, event handler, or
  variable hook belonging to CLASS, FORM, or CONTROL.
- It is illegal in a standard module, interface signature, Type/Enum
  declaration, field initializer, and any context without an executing
  instance.
- `Me` is a read-only reference expression. `Set Me = ...` and passing it as a
  direct writable `ByRef` actual are errors.
- `Set Other = Me` retains the same identity. `Me.Member` uses ordinary static
  member lookup and visibility.
- A `Static` instance procedure still has `Me`; this is already approved.
- During accepted form unload, existing active procedures may continue using
  `Me` only as allowed by the approved draining lifecycle. No new member entry
  begins after unload acceptance.

### 7.2 `With`

Adopt the classic VB behavior, made deterministic:

- The target expression is evaluated exactly once on block entry.
- Its resulting value/reference is retained for the entire block, including
  across nested calls and event recursion. An object target is therefore a
  temporary strong GC root until block exit.
- A leading dot binds lexically to the innermost active `With`.
- `With` may target a custom datatype lvalue or an object-compatible
  expression. For an lvalue value target, member writes update that storage.
  For a non-lvalue value expression, UBE operates on a temporary and writes
  cannot escape; a compiler should diagnose such pointless writes.
- If an object target evaluates to `Nothing`, member reads/calls return their
  controlled neutral failure and record `Err`; writes do nothing and record
  `Err`. The block still exits normally.
- Reassigning the original variable during the block does not retarget the
  retained `With` receiver.
- `Exit With` does not exist in classic VB and remains invalid unless added as
  a separate future feature.

These rules fit the approved GC and event-recursion architecture without an
owner decision.

## 8. Fixed-length strings

The approved observable behavior is sound: `String * n` always stores exactly
`n` characters; assignment truncates or right-pads with spaces, and padding
participates in comparison. The following must still be frozen:

- Only `String` may carry `* n`. The current `type-name` EBNF incorrectly also
  accepts `Long * 10`, `Object * 2`, and every other intrinsic type.
- `n` is a nonnegative compile-time decimal integer. It is part of the declared
  type: `String * 8` and `String * 9` are different direct-`ByRef` types.
- Length counts Unicode characters, not UTF-8 bytes and not platform `wchar_t`
  units. Indexing/slicing must use the language's separately frozen String
  indexing unit consistently.
- `String * 0` should be legal as a zero-character value. It pads/truncates
  every assignment to empty and has a valid zero-size payload. Rejecting it
  would add a historical restriction with no architectural benefit.
- The source language should not inherit VB6's historical 65,535-character
  ceiling. The compiler accepts any length representable in `LongLong` but
  diagnoses layout/target limits at compile time. Public foreign ABI use still
  requires the explicit representation rules in `foreign-abi.md`.
- Dynamic arrays of fixed strings and custom-type fields of fixed string type
  are legal. `String * n` is not legal with `As New`.
- Assignment and `ByVal` copy the complete padded value. Direct `ByRef`
  requires the exact same fixed length, as already specified.

The zero-length and no-legacy-cap recommendations are modern UBE choices, but
they do not conflict with any approved behavior. If exact binary layout is to
be exposed across raw foreign declarations, that ABI choice must be resolved
in `foreign-abi.md`, not inferred from this surface syntax.

## 9. Identifier type characters

The approved mapping is `%` Integer, `&` Long, `^` LongLong, `!` Single, `#`
Double, `@` Currency, and `$` String. Apply it uniformly:

- A type character is part of a declaration/use spelling but not part of name
  identity. `Count`, `Count&`, and `[Count]` denote the same folded name after
  resolution; a suffix at a use site must agree with the declaration.
- A declaration suffix supplies the complete declared type when no `As` clause
  is present. If both occur, they must name exactly the same type. Thus
  `Dim N& As Long` is legal but `Dim N& As LongLong` is an error.
- A type character cannot describe arrays, custom types, enums, interfaces,
  Object, Variant, Date, Decimal, Byte, IntPtr, UIntPtr, or fixed-string length.
  Those require `As` syntax.
- Function and Property Get names may carry a suffix to declare their scalar
  result. Sub, Property Let/Set, Event, Interface/Type/Enum names, labels, and
  member-access use sites do not acquire a new declaration from a suffix.
- Literal suffixes are lexically separate from identifier type characters and
  follow their own numeric literal rules. Longest-match scanning must preserve
  `1&` as a literal while `1 & Name` remains concatenation.

The grammar currently uses `typed-name` in several result/declaration positions
but plain `identifier` elsewhere. Semantic validation should enforce the above
agreement rather than treating a suffixed use as a different symbol.

## 10. `DefType` compatibility

Classic VB's `DefBool`, `DefByte`, `DefInt`, `DefLng`, `DefLngLng` where
supported, `DefSng`, `DefDbl`, `DefCur`, `DefDec`, `DefDate`, `DefStr`,
`DefObj`, and `DefVar` families assign implicit types according to the first
letter of an otherwise untyped name. That directly conflicts with UBE's
approved invariant that every declaration is explicitly typed and that no mode
can restore implicit Variant declarations.

Recommended rule:

- Native UBE 1.0 does not support any `DefType` statement.
- A legacy importer recognizes the complete statement line so it can issue one
  targeted migration diagnostic and, when operating as a conversion tool,
  materialize explicit `As` clauses on affected declarations.
- The compiler itself rejects `DefType`; it must not silently ignore it,
  because doing so would change the types and behavior of imported code.
- `Option Explicit On` remains accepted but redundant. `Option Explicit Off`
  remains an error. Neither changes the `DefType` rule.

This is an intentional compatibility exception required by approved UBE
architecture, so no owner decision is outstanding.

## 11. Required grammar and conformance work

After promotion, the following work proves closure:

- add a result-specific array-rank production for Function and Property Get,
  including Interface declarations;
- reject managed array results on raw external `Declare Function`;
- replace Type's reused `variable-item` with a field-only production;
- restrict fixed-length syntax to String;
- retain a parseable semantic constant-expression category and test its closed
  evaluator subset;
- add source-kind legality fixtures for every table cell in section 6;
- add positive/negative fixtures for `Me` and single-evaluation/nested `With`;
- add fixed-string length, padding, truncation, exact-ByRef, and target-limit
  fixtures;
- add type-character agreement/name-identity fixtures; and
- add targeted rejection/import diagnostics for each classic `DefType` family.

## 12. Decisions requiring explicit owner resolution

No finding in this audit conflicts with already approved architecture. Under
the owner's instruction to default compatible cases to the VB model, the rules
above can be promoted without a new question.

Two modern details should nevertheless be recorded visibly during promotion:

1. fixed-length `String * 0` is accepted; and
2. UBE does not inherit VB6's historical fixed-string size ceiling, although a
   compiler must reject a declaration that cannot be represented on its target.

If either detail is considered part of the public binary contract rather than
an implementation-neutral source rule, move it to the deferred owner-questions
file before freezing the foreign ABI. All other recommendations are either
classic VB behavior or direct consequences of approved UBE semantics.
