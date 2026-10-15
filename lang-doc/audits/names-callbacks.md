# UBE 1.0 name-resolution and callback audit

**Status:** reviewed; name rules promoted, callback proposal narrowed during
promotion  
**Basis:** classic VB behavior except where UBE's approved strict typing,
Unicode, 64-bit, portability, managed-memory, and foreign-boundary contracts
require a safer or more precise rule

This report preserves the audit rationale for two closure items. The name rules
were promoted. The final `AddressOf` contract deliberately follows classic VB
more strictly than this report's storable-`UIntPtr` proposal: it is legal only
as a direct compatible external-call argument and is not a storable UBE value.

## 1. Recommended name model

### 1.1 Canonical identity

- Every identifier comparison uses the Unicode simple-folded name defined by
  `../language-spec.md`. Original spelling is retained for source display,
  metadata, and diagnostics.
- Brackets affect tokenization, not identity. `Thing` and `[thing]` therefore
  denote the same name and cannot bypass duplicate detection.
- A declaration's type character is type syntax, not part of its name.
  `Count&` and `Count` have the same canonical name. Conflicting type
  information remains a separate diagnostic.
- Labels have their own procedure-local namespace. A label may have the same
  spelling as a variable or procedure, but no two labels in one procedure may
  have the same canonical name.
- Module names and declared type names occupy the type/qualifier namespace.
  Values and callable members occupy the value/member namespace. Context
  determines which namespace is requested by `As T`, `New T`, the first
  component of a qualified name, or an expression.

### 1.2 Declaration regions and duplicates

UBE 1.0 should not add user-defined procedure overloading. This is the classic
VB model and is consistent with the existing rule that duplicate declarations
after folding are errors.

- Parameters, ordinary locals, local constants, and `Static` locals share one
  procedure declaration region. A duplicate in that region is an error.
- The current Function or Property Get result name is an implicit assignable
  result in its body. A parameter or local may not redeclare that name.
- Fields, module variables, module constants, procedures, and logical
  properties share their containing module/class/form/control member region.
  Except for the combinations below, two declarations with the same canonical
  member name are an error even when their signatures differ.
- The permitted same-name combinations are the approved Get/Let/Set accessors
  of one logical property and identical interface requirements satisfied by
  one implementing member. An event and its `<WithEvents-field>_<event>`
  handler have different names and need no special namespace exception.
- Enum members share the containing Enum's member region. Custom-datatype
  fields share the containing Type's member region. Interface members follow
  the same logical-property exception as concrete members.
- Separate modules may each declare a private member with the same name.
  Separate standard modules may also expose same-named public members, but an
  unqualified use visible from both is ambiguous; qualification is required.
- A module and one of its members should not share a canonical name. Rejecting
  this avoids an otherwise context-sensitive `M.M` corner and follows the
  compiler's goal of actionable, deterministic lookup.

The compiler roadmap's references to "overload sets" and general "overload
resolution" should consequently be narrowed. UBE still needs candidate
selection for logical property accessors, operators, and explicitly specified
broad standard-library/intrinsic signatures, but ordinary user procedures do
not overload by parameter list or result type.

### 1.3 Unqualified lookup

For an unqualified name in a procedure body, search in this order and stop at
the first level that contains a matching canonical name:

1. parameters, locals, local constants, and `Static` locals of that procedure;
2. the implicit Function/Property result where assignment context permits it;
3. members of the current module, class, form, or control (including the
   current object's fields, properties, events where applicable, and methods);
4. accessible public or friend members contributed by standard modules in the
   current compilation package;
5. accessible declarations supplied by explicit project references, in the
   project's declared reference order.

A level containing more than one viable declaration is ambiguous and is a
compile-time error. UBE must not silently select one by source-file order.
Private declarations outside the current containing type/module do not enter
the candidate set. `Friend` declarations enter it only for the same
compilation package.

This order preserves VB's useful local/member shadowing. A modernization
diagnostic may warn about shadowing, but changing the selected declaration is
not permitted. An undeclared or inaccessible name is always a compile-time
error under UBE's mandatory strict typing.

At module scope, lookup begins with the current module's declarations and then
continues with steps 4 and 5. Procedure-local labels are resolved only by
label-bearing statements and never participate in ordinary expression lookup.

### 1.4 Qualified and member lookup

- `ModuleName.Member` performs static lookup in that named standard module and
  is the normal way to disambiguate duplicate public-module names.
- `PackageOrReference.ModuleName.Member` may be used when two visible modules
  themselves collide, provided the project model exposes that qualifier.
- For `expression.Member`, the left expression is resolved first. The member
  is then selected from its static declared class, interface, form, control, or
  custom-datatype type. UBE 1.0 does not use runtime-name lookup merely because
  the value is held in `Object` or `Variant`; a library facility may provide
  explicitly dynamic invocation later.
- An interface-typed expression exposes the interface contract, not additional
  members of the implementing class.
- `With` leading-dot lookup uses the innermost active `With` expression and
  then follows the same static member rule.
- Bang access retains its compatibility meaning for types that explicitly
  expose a named-item/default-member facility. It is not a fallback lookup for
  arbitrary missing members.
- A qualified lookup never falls back to another module or to an unqualified
  declaration after its qualifier has resolved.

### 1.5 Calls without user overloads

After name lookup chooses an ordinary Sub or Function, its single declared
signature controls argument validation and conversion. Result type never
participates in choosing a callable. A call with the wrong arity or types is a
diagnostic against that declaration, not a search for another same-named user
procedure.

Property access is the deliberate exception: read context selects Get, value
assignment selects Let, and object/reference assignment with `Set` selects
Property Set. The already approved property rules then validate index and
value parameters. This is accessor selection, not general overloading.

## 2. Recommended `AddressOf` contract

Classic VB treats `AddressOf` as a low-level bridge for native callbacks, not
as a general delegate or closure facility. UBE should preserve that model,
with the minimum changes required for safe 64-bit native output.

### 2.1 Eligible target

`AddressOf QualifiedName` must resolve statically and unambiguously to a
concrete Sub or Function declared in a standard module. The target may be
Public, Friend, or Private when it is visible at the use site. It may not be:

- a class, interface, form, or control instance member;
- a Property accessor, Event, external `Declare`, Intrinsic, or `CallNew`;
- a procedure selected through an object, `Variant`, callback variable, or
  other computed expression; or
- a procedure requiring hidden captured local or instance state.

This matches VB's essential no-capture callback rule. The callback may still
access ordinary module/global state according to normal visibility and
threading rules.

### 2.2 Result and legal uses

> **Promotion note:** The storable-pointer proposal in this subsection was not
> adopted. The normative contract permits `AddressOf` only directly as a
> compatible external-call argument. It cannot be assigned to `UIntPtr` or any
> other variable. This subsection remains solely as rejected design rationale.

UBE has no procedure/delegate type in 1.0. This audit originally proposed an
opaque address storable as `UIntPtr`; promotion rejected that extension in
favor of classic VB's direct-argument-only rule.

- It may be passed to a compatible pointer-sized parameter of an external
  `Declare`, assigned to an explicitly declared `UIntPtr`, compared with zero,
  or passed through a similarly pointer-sized low-level API.
- It may not be invoked using UBE call syntax, converted to `Long` or another
  narrowing numeric type, used in arithmetic, serialized as a persistent
  program identity, or treated as a managed object.
- Zero is never produced for a valid statically resolved target. `Nothing`,
  `Null`, and `Empty` are not callback addresses.
- `AddressOf` does not create a closure, capture locals, allocate an object, or
  create a garbage-collector root.

Allowing explicit `UIntPtr` storage preserves common VB callback-registration
patterns while preventing the classic 32-bit `Long` representation from
truncating an address in UBE's required 64-bit builds.

### 2.3 ABI validation

The target signature must be valid for a direct native callback on the current
target and calling convention. At minimum:

- the result and every parameter must have an ABI representation accepted by
  that foreign binding;
- ordinary managed `String`, array, custom recursive value, `Variant`, and UBE
  object/reference parameters are not valid raw callback fields;
- `ByVal` scalars cross by value and `ByRef` ABI-safe scalars cross as validated
  native pointers; `Any` remains legal only on external declarations and can
  never appear in the UBE callback procedure itself; and
- a target-dependent unsupported calling convention or signature is a
  compile-time error, not an unchecked adapter guess.

A plain `UIntPtr` parameter does not describe the native callback signature.
Consequently the compiler can prove only that the UBE procedure itself has an
ABI-safe shape unless separate binding metadata supplies the expected native
signature. This limitation must be stated plainly; exact agreement with a
metadata-free third-party API remains the coder's responsibility, as in
classic VB.

The richer exported-UBE-library callback contract in `../foreign-abi.md` is
different: generated foreign metadata uses an explicit function-pointer plus
context record with declared lifetime and thread rules. Raw `AddressOf` must
not replace that record or bypass its validation.

### 2.4 Lifetime, unloading, and threads

- In an executable, the address remains valid until orderly program shutdown
  begins. No new native callback may be admitted after shutdown closes callback
  admission.
- In a shared UBE library, the address remains valid only while that library is
  loaded and before its generated orderly shutdown invalidates entries. Code
  registering a raw callback is responsible for unregistering it before the
  receiving native library can call unloaded UBE code.
- Merely dropping a `UIntPtr` copy performs no unregistration and no cleanup.
  This follows the approved rule that user-created native resources and
  registrations require explicit user cleanup.
- A callback arriving on any native thread must enter UBE's compiled-in thread
  transition, receive independent `Err` state, and obey the approved shared
  visibility, synchronization, GC safe-point, and unload-admission rules.
- Callback re-entry is allowed. It has ordinary synchronous call semantics and
  may recursively cause events or further callbacks. An ABI callback must not
  unwind an error through foreign frames; failure follows the declared native
  callback result convention, or a neutral result plus the thread's UBE error
  state when the binding supplies no richer status channel.
- The generated callback entry thunk, not the raw body address, is the value
  denoted by `AddressOf`. This lets the compiler implement thread registration,
  ABI marshalling, controlled failure, and GC transitions without a separate
  installed runtime.

## 3. Grammar and diagnostic consequences

- The existing grammar form `AddressOf qualified-name` is sufficient. Its
  target restrictions and contextual legal uses are semantic checks.
- The grammar requires no user-overload declaration or callable-pointer type.
- The compiler should diagnose, with source notes naming all candidates:
  duplicate declarations, ambiguous imports/public modules, inaccessible
  declarations, invalid shadowing of a Function/Property result, and invalid
  `AddressOf` targets.
- An ambiguous name must not be resolved by file order, declaration order,
  reference order (except after earlier lookup levels have been exhausted),
  result context, or a conversion-quality guess among user declarations.
- Malformed or incompatible callback declarations must produce controlled
  diagnostics and never an assertion, panic, or partially emitted callback
  thunk.

## 4. Reconciliation required if these rules are promoted

1. Replace general user "overload sets" and "overload resolution" wording in
   project/compiler roadmaps with accessor, operator, intrinsic, or
   library-signature selection as appropriate.
2. Expand the normative names/modules section with the declaration regions,
   lookup order, qualification rules, and ambiguity behavior above.
3. Replace the current one-line `AddressOf` restriction with the eligible
   target, `UIntPtr`, ABI, lifetime, thread-entry, and cleanup contract above.
4. Ensure `foreign-abi.md` keeps generated function-pointer-plus-context
   callbacks distinct from raw compatibility `AddressOf` callbacks.
5. Add positive and negative fixtures for Unicode-folded duplicates, local
   shadowing, ambiguous public modules, explicit qualification, property
   accessor selection, instance-method rejection, pointer narrowing, unsafe
   callback fields, re-entry, and shutdown/unload callback rejection.

## 5. Architecture departures from literal VB behavior

These are not new owner-policy questions; each follows an already approved UBE
requirement and should be recorded when the report is promoted:

- `AddressOf` uses `UIntPtr`, never VB6's 32-bit `Long`, because UBE is fully
  64-bit and pointer truncation would violate the never-crash rule.
- Names use Unicode simple folding rather than a legacy Windows code-page or
  locale comparison.
- Undeclared names and implicit Variants remain errors even if VB6 accepted
  them with `Option Explicit Off`.
- Raw callbacks receive generated transition thunks because arbitrary native
  threads must enter UBE's compiled-in GC/error/thread machinery safely.
- Managed values do not cross a metadata-free raw callback boundary using
  compiler-private layouts.

No additional owner decision is required for the proposed closure unless UBE
1.0 is intended to add either user-defined overloads or first-class callable
values. Both would exceed the VB model and require new syntax, type rules,
lifetime semantics, and a separate design review.
