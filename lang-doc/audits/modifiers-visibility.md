# UBE 1.0 declaration modifiers and visibility audit

**Status:** reviewed and promoted into the candidate language specification and
EBNF  
**Compatibility basis:** classic Visual Basic behavior, except where UBE's
approved package visibility, explicit foreign export, mandatory typing, or
inlining contracts require a narrower rule  
**Scope:** `Public`, `Private`, `Friend`, `Global`, `Dim`, `Static`, `Inline`,
`ForceInline`, `Intrinsic`, `Export`, and `Default` in standard modules,
classes, forms, controls, and interfaces

This audit defines source meaning and required diagnostics. A permissive
grammar may recognize a declaration before semantic validation rejects an
illegal modifier or combination.

## 1. General rules

- Visibility controls which UBE source may name a declaration. It does not
  create a foreign symbol. Only a valid `Public Export` procedure has foreign
  ABI exposure.
- At most one of `Public`, `Private`, `Friend`, and `Global` may occur on one
  declaration. Repeating a visibility word is also an error.
- Omitted visibility has the context-specific defaults in section 2. It never
  changes according to source-file order, optimization mode, or project kind.
- `Friend` means accessible anywhere in the current compilation package but
  inaccessible through a project reference from another package. It is an
  approved UBE spelling of package visibility, not a foreign ABI concept.
- `Global` is the legacy spelling of `Public` for a standard-module variable.
  It is not a general substitute for `Public` and is invalid on procedures,
  constants, types, enums, events, interfaces, and every declaration outside a
  standard module.
- A modifier that has no semantic effect in its declaration context is an
  error rather than an ignored decoration.
- Modifiers are part of a declaration, not names. Case folding applies to the
  words themselves, and brackets cannot turn a modifier position into an
  identifier.

## 2. Omitted visibility

UBE keeps the useful VB defaults while making their result deterministic:

| Declaration context | Omitted visibility |
|---|---|
| Standard-module `Sub`, `Function`, or `Property` | `Public` |
| Class, form, or control `Sub`, `Function`, or `Property` | `Public` |
| Class, form, or control `Event` | `Public` |
| Standard-module external `Declare` | `Public` |
| Standard-module `Type` or `Enum` | `Public` |
| `Interface` declaration | `Public` |
| Module, class, form, or control field declared with `Dim` | `Private` |
| Module, class, form, or control `Const` | `Private` |
| `Type` or `Enum` in a class, form, or control | `Private` |
| Local variable, local constant, parameter, or static local | lexical to its procedure; no visibility modifier is legal |
| Interface member | inherently `Public`; no member visibility modifier is written |

Consequently, `Dim Count As Long` at module level is a private field, while an
unmodified `Sub Start()` is public UBE source API. Authors of reusable packages
should still spell visibility explicitly at public boundaries.

`Option Private Module` suppresses access to that standard module's otherwise
public declarations from other compilation packages. It does not turn those
declarations into `Private` inside the current package, does not override
`Friend`, and does not affect `Public Export`: combining `Option Private Module`
with any export is a compile-time error because an export is intentionally an
external boundary.

## 3. Visibility by containing source kind

### 3.1 Standard modules

Standard-module variables, constants, types, enums, procedures,
properties, external declarations, and interfaces may be `Public` or
`Private`. `Friend` is also legal and has the package meaning above. `Global`
is legal only for a variable declaration and means exactly `Public` there.

A public standard-module declaration participates in unqualified package
lookup under the approved name-resolution rules. Visibility does not bypass
ambiguity diagnostics; `ModuleName.MemberName` remains the explicit
qualification form.

A standard module cannot declare an Event because it has no object identity
that a `WithEvents` field can subscribe to.

### 3.2 Classes, forms, and controls

Fields, constants, nested types and enums, events, procedures, and properties
may be `Public`, `Private`, or `Friend`. `Global` is invalid. Public and Friend
instance members still require an instance; neither modifier creates shared
class state or a shared method.

The source module's own declared type name is controlled at the package/type
level rather than by a modifier on the `UBE SOURCE ... CLASS`, `FORM`, or
`CONTROL` header. Source members cannot change the visibility of that type.

Lifecycle procedures and generated event handlers retain their already
approved exact names and required `Private` visibility. In particular,
`Class_Initialize`, `Class_Terminate`, module lifecycle procedures, form/control
load and unload handlers, and a `WithEvents` handler are not made public by the
ordinary procedure default.

### 3.3 Interfaces

An interface declaration may be `Public`, `Friend`, or `Private`; omitted
visibility is `Public`. `Global` is invalid. Every member written inside the
interface is inherently public and abstract. A visibility modifier on an
interface member is invalid rather than redundant.

Interface members may use only syntax that contributes to their public
contract: `Sub`, `Function`, `Property Get/Let/Set`, `Event`, parameter
modifiers, and `Default` on a valid default-property group. They cannot use
`Static`, `Inline`, `ForceInline`, `Intrinsic`, or `Export` because an interface
contains no implementation or foreign entry point.

## 4. `Dim` and explicit visibility

`Dim` is a declaration introducer, not a visibility modifier.

- In a procedure, `Dim` declares an automatic local whose lifetime ends with
  that invocation's scope under the managed-memory rules.
- At module, class, form, or control level, `Dim` declares a `Private` field.
- `Public Dim`, `Private Dim`, `Friend Dim`, `Global Dim`, and `Static Dim` are
  invalid. Use `Public Name As Type`, `Private Name As Type`, `Friend Name As
  Type`, `Global Name As Type`, or the appropriate standalone `Static`
  declaration instead.
- A comma-separated declaration has one introducer and one effective
  visibility. Visibility cannot change partway through the list.

This retains VB's practical distinction between `Dim` and an explicit
module-level accessibility statement without treating `Dim` as shorthand that
can be combined with other visibility words.

## 5. `Static`

### 5.1 Static locals

Inside a procedure, `Static Name As Type` declares a procedure-local name with
program-lifetime storage. It is initialized once, when execution first reaches
the declaration, retains its value between invocations, and is destroyed
during orderly program termination. All recursive calls and all threads share
the same storage for that declaration. Access is subject to the ordinary data-
race and synchronization rules.

A static local remains lexically visible only in its declaring procedure. It
cannot have `Public`, `Private`, `Friend`, or `Global` visibility. `Static` and
`Dim` cannot introduce the same declaration.

### 5.2 Static procedures and properties

On an implemented `Sub`, `Function`, or property accessor, `Static` has the
classic VB meaning: every ordinary local variable declared in that procedure
body receives static-local storage. It does **not** make an instance member a
shared/type-level member, remove `Me`, or allow a call without an instance.
Parameters, the Function/Get result, compiler temporaries, and block-control
state remain per invocation. An explicitly declared `Static` local has the
same storage behavior whether or not the procedure header is `Static`.

For a logical property, either every present accessor is `Static` or none is;
the already approved property-group matching rule diagnoses a mismatch.

`Static` is invalid on:

- events, variables at module/type level, constants, types, enums, interfaces,
  external `Declare` declarations, and interface members;
- `Intrinsic` declarations, because they have no UBE body or locals;
- lifecycle procedures and generated event handlers whose signatures are
  fixed by the language.

A static Sub may otherwise be a `CallNew` target. Its static locals are shared
under the ordinary multithreading rules, so the program is responsible for
appropriate synchronization just as it is for explicitly shared module or
object state.

## 6. Inlining and compiler implementation

`Inline`, `ForceInline`, and `Intrinsic` are mutually exclusive.

- `Inline` and `ForceInline` are legal on implemented Subs and Functions,
  including instance methods. They are invalid on properties, events,
  lifecycle/event-handler procedures, external declarations, interface
  members, and declarations without a UBE body.
- `Inline` requests expansion but permits an ordinary call. `ForceInline`
  requires expansion and invokes the already approved failure, hygiene,
  evaluate-once, `ByRef`, and recursion checks.
- `Intrinsic` is legal only on a standard-module Sub or Function whose body is
  absent under the intrinsic grammar. It is invalid in classes, forms,
  controls, and interfaces, and cannot be `Static`, `Default`, or `Export`.
- Visibility is independent of all three modifiers. An omitted visibility on
  such a standard-module procedure therefore remains `Public`.

Inlining never changes lookup, accessibility, object identity, error state,
thread behavior, or lifetime. In particular, an inlined private member does
not become callable from a source location that could not call the ordinary
member.

## 7. `Export`

`Export` is legal only in this exact semantic combination:

```ube
Public Export Sub Name(...)
End Sub

Public Export Function Name(...) As ResultType
End Function
```

The declaration must be at standard-module level in a `Kind = "Library"`
project and satisfy the normative foreign-ABI contract. `Export` requires an
explicit `Public`; relying on the ordinary public default is an error so the
foreign boundary remains visible in source.

`Export` is invalid on properties, events, external `Declare` declarations,
intrinsics, variables, constants, types, enums, interfaces, instance members,
and every executable project declaration. It cannot be combined with
`Private`, `Friend`, `Global`, `Default`, or `Static`. It may be combined with
`Inline` as an optimization request because an externally callable entry stub
must still be emitted. It cannot be combined with `ForceInline`, because a
foreign entry point necessarily requires an addressable emitted body.

## 8. `Default`

`Default` is not visibility. It is legal only on every accessor of the one
approved indexed default-property group belonging to a class or interface.
It is invalid on a standard module, form, control, ordinary Sub or Function,
field, constant, type, enum, event, external declaration, intrinsic, or
standalone expression.

`Default` does not change the property's visibility. Omitted visibility on an
implemented class property is `Public`; an interface member is inherently
public. The property may instead be explicitly `Private` or `Friend` in a
class, but shorthand access is available only where that property is visible.
A private default property does not create an external conversion facility.

All accessors in the logical property group must agree on `Default`,
visibility, `Static`, and the approved index-parameter contract. `Default`
cannot be combined with `Inline`, `ForceInline`, `Intrinsic`, or `Export`.

## 9. Accepted order and duplicate diagnostics

UBE uses one canonical modifier order. Keywords from a later column cannot be
moved before a keyword from an earlier column:

| Declaration | Canonical order before the declaration kind |
|---|---|
| Implemented Sub or Function | `[visibility] [Static] [Inline | ForceInline]` |
| Implemented Property accessor | `[visibility] [Default] [Static]` |
| Intrinsic Sub or Function | `[visibility] Intrinsic` |
| Exported Sub or Function | `Public Export [Inline]` |
| Field/constant/type/enum/event | `[visibility]` followed by its declaration introducer |
| Interface declaration | `[visibility] Interface` |
| Interface property accessor | `[Default] Property ...` |

Each optional item occurs at most once. Therefore `Static Public Sub`, `Inline
Public Function`, `Export Public Sub`, `Public Public Sub`, `Default Private
Property`, and `Public Inline Static Function` are errors. Canonical ordering
keeps diagnostics and formatter output deterministic; it does not create a
different runtime meaning.

The parser should recover at the declaration header, report the first
misordered, repeated, or incompatible modifier, and continue checking the
body. It must not silently discard a modifier or reinterpret the line as an
implicit call.

## 10. Legality summary

| Modifier | Standard module | Class/form/control | Interface |
|---|---|---|---|
| `Public` / `Private` / `Friend` | declarations and members | members | declaration only |
| `Global` | variables only | no | no |
| `Dim` | private field or automatic local | private field or automatic local | no |
| local `Static` | inside a procedure | inside a procedure | no body |
| header `Static` | implemented Sub/Function/Property | implemented Sub/Function/Property | no |
| `Inline` / `ForceInline` | implemented Sub/Function | implemented Sub/Function | no |
| `Intrinsic` | Sub/Function only | no | no |
| `Export` | public library Sub/Function only | no | no |
| `Default` | no | class Property only | Property only |

Forms and controls are intentionally not granted default properties in UBE
1.0: the approved property contract says one default property per class or
interface. Their ordinary properties remain available by explicit member name.

## 11. Required fixture coverage

Promotion should add positive fixtures for every legal cell above and negative
fixtures for:

- every pair of visibility modifiers, repeated modifiers, and each misordered
  sequence;
- module-level `Dim` being private and an unmodified procedure being public;
- `Global` anywhere except a standard-module variable;
- shared static locals across ordinary, recursive, and multithreaded calls;
- proof that a `Static` instance method still requires an instance and retains
  `Me`;
- mixed-`Static`, mixed-`Default`, and mixed-visibility property accessors;
- each inlining/intrinsic incompatibility and invalid declaration kind;
- explicit-`Public` enforcement and all project/context restrictions for
  `Export`; and
- visibility failures through project references and `Option Private Module`.

## 12. Conflict review

No owner decision is required for this model. It applies the requested classic
VB default where that model is well defined and narrows it only for already
approved UBE architecture:

- `Friend` uses UBE's compilation-package boundary;
- `Export` remains explicit and separate from UBE visibility;
- `Intrinsic`, `Inline`, and `ForceInline` obey their approved compiler
  contracts; and
- `Default` remains limited to the approved indexed class/interface property.

The current candidate EBNF is deliberately broader in several places: it
accepts arbitrary repeated `member-modifier` order, accepts `Static Intrinsic`,
and can parse `Default` on procedure kinds other than a valid property. Those
are grammar/semantic-validation synchronization defects, not language-design
questions. Promotion should tighten the grammar where practical and retain
semantic diagnostics as the authoritative backstop.
