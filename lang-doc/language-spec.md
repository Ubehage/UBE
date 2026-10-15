# UBE core language specification

**Target version:** 1.0  
**Status:** frozen UBE 1.0 core language contract; implementation pending  
**Grammar:** [`grammar/ube.ebnf`](grammar/ube.ebnf)

This specification and the focused contracts below form the normative UBE 1.0
language definition for Compiler v3. Deferred platform/library architecture
questions are isolated in `deferred-questions.md` and do not silently alter
this core contract.

- [`conversion-table.md`](conversion-table.md) defines implicit conversion and
  failure behavior;
- [`managed-memory.md`](managed-memory.md) defines managed values, collection,
  finalization, and low-memory behavior;
- [`threading.md`](threading.md) defines shared access, synchronization,
  cancellation, and shutdown; and
- [`foreign-abi.md`](foreign-abi.md) defines the generated boundary used by
  exported UBE libraries.

[`v3-language-definition.md`](v3-language-definition.md) is the normative
expanded semantic definition and supplies detailed lifecycle and behavioral
rules not repeated here. If wording there conflicts with this specification or
one of the focused normative contracts, this specification and the focused
contract take precedence.

## 1. Scope and compatibility

UBE 1.0 accepts the core textual syntax of classic VB6: declarations, procedures,
properties, events, expressions, structured control flow, labels and legacy
file/error statements. It also recognizes the textual headers and designer
blocks found in `.bas`, `.cls`, `.frm`, and `.ctl` files. Native UBE project,
project-group, and binary-resource formats are specified separately in
[`project-files.md`](project-files.md).

“Syntax-compatible” means that a valid classic VB6 core construct has a UBE
parse with the same token grouping. It does **not** promise bug-for-bug runtime
behavior, binary compatibility with ActiveX/COM, identical numeric overflow,
or acceptance of every undocumented IDE serialization artifact. Designer
metadata is preserved for tools but has no core-language execution semantics.
This includes nameless `BEGIN ... END` class metadata,
`BeginProperty ... EndProperty` designer groups, and contiguous member
`Attribute` lines emitted beneath procedure/property headers.

New native source files begin with `UBE SOURCE 1` and their source kind, then
declare `Attribute UBE_Name`. Legacy `VERSION` and `Attribute VB_Name` headers
are compatibility input. Saving imported code as native UBE replaces its
legacy identity header. The bootstrap profile may accept bare modules only for
the documented compiler-bootstrap subset.

Built-in functions are not grammar productions. For example, `Mid$(s, 2)` is a
normal call whose callee happens to be supplied by the standard library. The
statement form `Mid$(s, 2) = value` is syntax and therefore is in the grammar.

## 2. Source and lexical rules

Source text is Unicode. Language definition 1.0 uses the character properties
of Unicode 18.0. A conforming implementation shall accept UTF-8 (with or without
BOM) and may accept legacy Windows code pages when explicitly selected. Line
endings are LF or CRLF. Unicode normalization is not performed.

Keywords and bare identifiers compare case-insensitively using Unicode simple
case folding. Original spelling is retained for diagnostics and metadata.
A bracketed identifier can contain any character except a newline or an
unescaped `]`; `]]` represents one `]`. A bare identifier may not equal a
reserved keyword. Contextual words are treated as keywords only where required
by a grammar production.

UBE 1.0 adds the hard keywords `CallNew`, `SyncLock`, `AndAlso`, `OrElse`,
`IsNot`, `Interface`, `Export`, `WithEvents`, and `Me`. The words in the native
`UBE SOURCE` header and its source-kind position are contextual to that header.
`UBE_Name` is a
reserved attribute name, not a general keyword. Bracketed identifiers remain
available when importing a legacy declaration that conflicts with a keyword.

After `.` or `!`, any reserved-word token may be consumed as a member name.
Thus familiar forms such as `Debug.Print`, `Thing.Name`, and `.Type` do not
require brackets. This contextual rule never makes the same word legal as an
unbracketed declaration name.

The scanner supplies these terminal tokens to the grammar:

| Token | Definition |
|---|---|
| `HSPACE` | One space or horizontal tab. |
| `NEWLINE` | LF or CRLF. |
| `EOF` | End of input. A scanner inserts one final `NEWLINE` if absent. |
| `LETTER` | Unicode character in category Letter. |
| `LINE_CHAR` | Any character other than CR or LF, respecting quoted strings. |
| `COMMENT_TEXT` | All characters through, but excluding, the newline. |
| `STRING_TEXT` | Zero or more non-newline characters; `""` encodes one quote. |
| `DATE_TEXT` | Nonempty non-newline text validated as a date/time literal. |
| `REAL_TEXT` | Decimal digits containing a decimal point and/or exponent. |
| `BRACKET_IDENTIFIER_TEXT` | Nonempty bracket content, with `]]` escape. |
| `KEYWORD` | Any reserved-word token when consumed as a member name after `.` or `!`. |

An apostrophe begins a comment outside a string/date literal. `Rem` begins a
comment only where a statement may start and when followed by horizontal
space or a newline. A physical line continues when its last non-comment tokens
are whitespace and `_`; the continuation and following indentation disappear
before parsing. A colon separates statements except inside literals or
parentheses. The grammar's `spacing` production includes continuations so a
continued token sequence behaves as one logical line.

Integer and real suffixes are part of their literal token when adjacent. The
scanner uses longest-match tokenization. Thus `1&` is one integer literal,
while `1 & x` is concatenation. Date literal contents are interpreted using the
invariant UBE date syntax by default; a compatibility mode may enable the VB6
locale-dependent interpretation.

Invariant date/time literals use a proleptic Gregorian calendar and exactly one
of these forms between their `#` delimiters:

```text
YYYY-MM-DD
HH:MM
HH:MM:SS
HH:MM:SS.fraction
YYYY-MM-DDTHH:MM[:SS[.fraction]]
YYYY-MM-DD HH:MM[:SS[.fraction]]
```

The year range is `0001` through `9999`. Hours use the 24-hour clock. A
fraction contains one through nine decimal digits. Leap seconds and time-zone
suffixes are not accepted. Locale-dependent forms such as `#10/13/2026#`
require an explicitly selected VB6 compatibility mode.

Conditional compilation runs after physical-line continuation and comment
recognition but before the core EBNF is parsed. It supports case-insensitive
`#Const name = constant`, nested `#If condition Then`, `#ElseIf condition Then`,
`#Else`, and `#End If`. Directives occupy complete logical lines and do not
produce declarations or statements. `#Const` names are file-local, become
visible only after their declaration, and cannot be redefined. Project-supplied
symbols are visible from the start of every file and cannot be shadowed.

Conditions use literals, conditional constants, parentheses, comparison, and
the scalar arithmetic and Boolean operators; they cannot call code, access
members, allocate, or depend on target runtime state. Only the selected branch
is sent to the core parser. An inactive branch need only remain lexically valid
enough to balance nested conditional directives; other syntax and unknown
names within it are ignored. Removed lines are replaced by blank logical lines
so source locations remain stable. The directive phrase grammar is normative
in [`grammar/conditional-compilation.ebnf`](grammar/conditional-compilation.ebnf).

## 3. Grammar conventions and disambiguation

The EBNF is normative for phrase structure. These rules settle intentional
VB-family ambiguities:

1. The scanner recognizes reserved words before `bare-identifier`.
2. At module scope, a procedure header wins over a statement interpretation.
3. At procedure scope, `name = expression` is assignment. A call without the
   `Call` keyword uses the no-parentheses argument form. With `Call`, or in an
   expression, arguments use parentheses.
4. Empty argument slots are retained (`F a,,c`) for VB6 compatibility.
5. A leading-dot expression is legal only inside a `With` body and binds to the
   innermost active `With`.
6. `End If`, `End Select`, `End With`, and procedure/type terminators are parsed
   before the standalone process-terminating `End` statement.
7. `Else` associates with the closest unmatched single-line `If`; a newline
   after `Then` selects block form.
8. Semantic validation rejects non-assignable forms accepted structurally by
   `lvalue`, nonconstant `constant-expression`s, misplaced declarations, and
   incompatible procedure terminators.
9. The core EBNF parses the selected output of conditional compilation, not
   inactive branch text.

## 4. Types

UBE retains the VB type names and adds explicit machine-sized types needed by a
64-bit compiler.

| Type | UBE core meaning |
|---|---|
| `Boolean` | Logical value; representation is not exposed. |
| `Byte` | Unsigned 8-bit integer. |
| `Integer` | Signed 16-bit integer (VB-compatible). |
| `Long` | Signed 32-bit integer (VB-compatible). |
| `LongLong` | Signed 64-bit integer. |
| `IntPtr`, `UIntPtr` | Signed/unsigned target pointer-sized integer. |
| `Single`, `Double` | IEEE-754 binary32/binary64. |
| `Currency` | Signed 64-bit fixed point with scale 10,000. |
| `Decimal` | Decimal value with a 96-bit coefficient and scale 0 through 28 in 128-bit storage. |
| `Date` | Timezone-neutral proleptic-Gregorian date/time from year 0001 through 9999, with nanosecond resolution. |
| `String` | Unicode string. `String * n` is fixed-length. |
| `Object` | Reference to any class instance. |
| `Variant` | Tagged value capable of holding any core value. |
| `Any` | Foreign-function-only untyped parameter. |

The legacy identifier type characters are `%` (`Integer`), `&` (`Long`), `^`
(`LongLong`), `!` (`Single`), `#` (`Double`), `@` (`Currency`), and `$`
(`String`). An explicit `As` clause and a type character may not conflict.

A type character is not part of name identity. A suffix on a declaration or
use must agree with the declaration's type. It can name only the seven scalar
types listed above; arrays, custom types, enums, references, `Variant`, and
fixed-length strings require an `As` clause. Integer literal suffixes are `%`,
`&`, and `^`; UBE does not accept the unrelated VB.NET suffixes for unsigned
fixed-width types that UBE does not define.

`String * n` is legal only for `String`; `n` is a nonnegative compile-time
decimal integer counting Unicode scalar values. Zero is a valid length. UBE
does not impose VB6's historical 65,535-character ceiling, but rejects a size
that the selected target cannot represent. The length is part of the type,
including for exact `ByRef` matching. Assignment truncates or right-pads with
spaces to exactly that length.

Arrays may have arbitrary rank. Bounds and indexes are `LongLong`, and lower
bounds may be negative. Omitted bounds in a declaration create a dynamic
array. `Option Base` affects only omitted lower bounds; explicit bounds always
win. Array assignment requires identical element type and rank and creates an
independent value copy with the source bounds. `ReDim Preserve` retains every
element whose complete index tuple remains in the new bounds. Failed bound,
index, or allocation operations follow the neutral-result and `Err` rules and
must leave an existing array unchanged. Implementations shall diagnose
overflow instead of depending on host or LLVM undefined behavior.

A Function or Property Get may return an array by writing `As ElementType()`
after its parameter list. The rank is the number of commas in that result
specifier and participates in the declared result type. Returning and assigning
the array uses the ordinary independent array-value copy; object elements retain
their object identities as part of that copy.

A custom `Type` is a value type. It may contain a field of its own type. Such a
recursive field begins as an empty implicit edge and materializes automatically
as deeply as code reads or writes it. `New`, `Nothing`, and `Is` do not apply to
that edge. Assignment to the same declared custom type makes a deep semantic
value copy of value fields; object fields retain the same object identities.
Unrelated custom types never convert merely because their layouts match.
Two values of the same custom datatype support `=` and `<>` when every field
is equality-comparable. Comparison is recursive semantic field equality;
padding bytes and hidden recursive-storage addresses are never compared, and
comparison does not materialize an empty recursive edge. Ordering is invalid.

An `Enum` has underlying type `LongLong` unless its declaration says `As Long`.
No other underlying type is legal. Enum values otherwise participate in
assignment, conversion, comparison, arithmetic, and bitwise operations as the
underlying integer type.

A custom `Type` contains at least one field. A field has an explicit type,
optional array shape, no initializer, and no `As New`, visibility, Static,
WithEvents, hook, or executable behavior. Fields initialize in declaration
order to their type's neutral value. Enum members are unique constants; an
explicit member value may use only constants and earlier visible Enum members,
and an omitted value is zero for the first member or the checked preceding
value plus one thereafter. Duplicate numeric Enum values are legal.

## 5. Procedures, names, and modules

`ByRef` is the compatibility default when neither parameter passing modifier is
present. `ParamArray` must be the final parameter and is always an array.
`Optional` parameters require a constant default except a trailing
`ParamArray`. A function or property result is assigned through its procedure
name, as in VB6.

Required parameters precede optional parameters. After the first `Optional`,
every later ordinary parameter is also optional; one trailing `ParamArray` is
the only exception. Each optional parameter has a compile-time constant default
convertible to its declared type. An optional object-compatible reference may
default only to `Nothing`; an optional `Variant` may also default to `Empty` or
`Null`. Omitting an optional `ByRef` parameter creates a fresh writable
temporary initialized from the default, and writes to it are discarded.

`ParamArray` cannot be combined with `Optional`, `ByVal`, or `ByRef`. It is the
last parameter, has one-dimensional array syntax, and is explicitly declared
`As Variant`, for example `ParamArray Values() As Variant`. Remaining
positional arguments are copied into a fresh Variant array in source order; no
arguments produces a valid zero-element array. An array passed as one argument
is one Variant payload and is not automatically expanded.

An argument may be positional, omitted, or named with
`ParameterName := expression`. Positional arguments must precede named
arguments. Named arguments may appear in any order, bind case-insensitively,
and cannot target `ParamArray`. Unknown or duplicate names, a required omitted
parameter, and excess arguments without `ParamArray` are compile-time errors.
`()` supplies no arguments; it is not one omitted slot.

Supplied arguments are evaluated exactly once from left to right in source
order, including receiver/index expressions used to locate `ByRef` storage.
Naming changes association, not evaluation order. All argument values,
conversions, and aliases are prepared before the callee begins. This order also
applies to `RaiseEvent`; `CallNew` then performs its separately specified
`ByVal` capture before making the worker observable.

A direct `ByRef` actual aliases writable caller storage and must have exactly
the parameter's declared type. It cannot rely on numeric conversion, Variant
boxing/extraction, enum conversion, reference upcasting, or a different fixed
String length. Constants, results, read-only properties, hooked variables, and
arbitrary expressions are not direct `ByRef` storage. The alias lasts only for
the dynamic call and cannot escape as a first-class reference.

For VB compatibility, an extra pair of parentheses around an individual
argument to a `ByRef` parameter forces value evaluation. UBE evaluates and
converts the expression once into a fresh temporary of the parameter type,
passes that temporary ByRef, and discards any callee write on return. This does
not bypass type, access, lifetime, or foreign-ABI checks.

Expression calls use parentheses. A statement with `Call` uses parentheses
when it supplies arguments; `Call Name` and `Call Name()` are both legal for a
zero-parameter target. A statement without `Call` uses the classic
unparenthesized argument form. Either statement form may invoke a Function and
discard its result; Subs cannot be used as value expressions. `CallNew` keeps
its stricter approved syntax and accepts only a Sub with parenthesized `ByVal`
arguments.

UBE is always explicitly and statically typed. Every variable, constant,
parameter, property, and function result must declare its type with an `As`
clause or a nonconflicting identifier type character. There is no implicit
`Variant` declaration mode; code that wants a `Variant` must say so explicitly.
Use of an undeclared name is always a compile-time error.

`Option Explicit` and `Option Explicit On` may be accepted as redundant
VB-import compatibility declarations. They do not change semantics.
`Option Explicit Off` is a compile-time error in every build mode; strict
typing is not a compiler option and no compatibility mode may disable it.
The `DefBool`, `DefByte`, `DefCur`, `DefDate`, `DefDbl`, `DefInt`, `DefLng`,
`DefObj`, `DefSng`, `DefStr`, and `DefVar` families are likewise rejected with
a targeted migration diagnostic. An importer may use them only to materialize
explicit `As` clauses; the compiler never silently applies or ignores them.
Duplicate declarations after case folding are errors. `Friend` means visible
within the current compilation package; `Global` is accepted as the legacy
synonym for public module scope.

UBE 1.0 has no user-defined procedure overloading. Parameters, locals, local
constants, and Static locals share one procedure declaration region. Fields,
module variables, module constants, procedures, events, and logical properties
share their containing member region. The approved Get/Let/Set accessors are
one property rather than overloads; identical interface requirements may be
satisfied by one member. Other same-name declarations in one region are
errors regardless of signature. Type characters and brackets do not create a
different name. Labels occupy a separate procedure-local region.

Unqualified procedure-body lookup stops at the first matching level:

1. parameters, locals, local constants, and Static locals;
2. the current Function or Property Get result in assignment context;
3. members of the current module, class, form, or control;
4. accessible Public or Friend declarations from standard modules in the
   current compilation package; and
5. declarations from all direct explicit project references as one lookup
   level.

More than one match at the selected level is an ambiguity error; source-file
and reference order never break the tie. Separate modules may therefore expose
same-named public members, but an unqualified use must be unique. `Module.Member`
qualifies a standard-module member. A resolved expression's member is selected
from its static class, interface, form, control, or custom-datatype type;
`Object` and `Variant` do not enable implicit runtime-name lookup. An
interface-typed expression exposes only that interface. Leading-dot lookup
uses the innermost `With`. Bang access works only for a type with an explicitly
defined named-item/default-member facility.

An ordinary Sub or Function has one signature, so a wrong argument list is a
diagnostic against that declaration rather than a search for another
same-named procedure. Read, value-assignment, and `Set` contexts select Get,
Let, and Set accessors respectively; this is property accessor selection, not
general overloading.

At most one visibility modifier is legal. Omitted visibility follows classic
VB defaults: implemented procedures/properties are Public; Events are Public
in classes, forms, and controls; standard-module external declarations, Types,
Enums, and Interfaces are Public; module/instance `Dim` fields and module-level
Consts are Private; and a Type or Enum inside an instance module is Private.
Interface members are inherently Public and write no visibility modifier.
Lifecycle procedures and `WithEvents` handlers retain their required Private
visibility rather than inheriting the ordinary procedure default.

`Global` is the legacy synonym for Public only on a standard-module variable.
`Dim` is a declaration introducer: inside a procedure it creates an automatic
local, and at module/instance scope it creates a Private field. It cannot be
combined with a visibility word. `Friend` means package-visible and never
crosses a project reference. `Option Private Module` hides that standard
module's otherwise Public declarations from other packages and is incompatible
with `Public Export`.

`Static` on a local gives that declaration program-lifetime storage, initialized
once when first reached and shared by recursion and all threads. `Static` on an
implemented Sub, Function, or property accessor gives every ordinary local in
that body the same static-local behavior; it does not make an instance member
shared, remove `Me`, or change parameters/results/temporaries into shared
storage. Every accessor of a logical property agrees on Static. Static is
invalid on lifecycle/event handlers, Intrinsic, Export, external declarations,
interfaces, events, types, enums, constants, and module-level fields.

Declaration modifiers use the canonical order encoded by the grammar. Inline
and ForceInline are mutually exclusive and apply only to implemented Subs or
Functions. Intrinsic is a standard-module Sub or Function with no UBE body and
cannot combine with Static, Inline, ForceInline, Default, or Export. Export is
exactly `Public Export [Inline] Sub|Function` in a Library standard module; it
cannot use Static or ForceInline. Default applies only, and consistently, to
the approved indexed property of a class or interface. Repeated, misordered,
or semantically ineffective modifiers are compile-time errors.

An Event declaration is valid only in a class, form, control, or Interface.
Standard modules have no instance/subscription identity and cannot declare or
raise their own Events.

Source-kind legality is fixed as follows: standard modules may contain fields,
constants, Types, Enums, package-level Interfaces, implemented procedures,
WithEvents fields, external Declares, Intrinsics, and Exports, but not Events
or Implements. Classes, forms, and controls may contain fields, constants,
Types, Enums, implemented procedures, Events, WithEvents fields, and
Implements, but not nested Interfaces, external Declares, Intrinsics, or
Exports. Interface bodies contain signatures only. Type bodies contain fields
only. Procedure bodies contain local variables and constants but no nested
type or procedure declarations. Instance members are per-instance; UBE 1.0 has
no Shared class-member surface.

The grammar accepts module attributes because they occur in exported VB6
source. Unknown legacy attributes must be retained by tooling. Attributes
beginning `VB_` are reserved for compatibility metadata. Attributes beginning
`UBE_` are reserved by UBE; an unknown reserved UBE attribute is diagnosed.

Every module may define private, parameterless `Module_Initialize` and
`Module_Terminate` procedures. All modules, including the module containing
`Main`, initialize in deterministic project order before `Main` executes and
terminate in reverse order during orderly shutdown. These hooks cannot be
called directly. Initialization failure prevents `Main` and terminates the
already initialized modules in reverse order.

UBE classes do not inherit implementation from other classes. An `Interface`
contains Sub, Function, Property, and Event signatures without bodies. A class
uses `Implements` and must provide every required member with a compatible
signature. Compatible object and interface assignments preserve identity.

A module, class, form, or control field declared `WithEvents` is a strong
object reference with statically bound event handlers. Its declared type must
be a class, interface, form, or control type that declares events; arrays,
locals, procedure parameters, custom datatypes, and the unspecialized `Object`
type cannot be declared `WithEvents` in UBE 1.0. One declaration names one
field.

For a field named `Source` and an event named `Changed`, an ordinary procedure
named `Source_Changed` is its handler when it is a `Private Sub` whose
parameters exactly match the event declaration. A handler is optional. A
same-named procedure with an incompatible kind or signature is a compile-time
error rather than an ignored handler.

`Set Source = value` disconnects the field's handlers from its old object and
connects them to the new object before the assignment statement completes.
`Set Source = Nothing` disconnects them. Reassignment never unloads or destroys
the old object merely because this field released it. Following classic VB,
`WithEvents` cannot combine with `As New` or a declaration initializer; source
performs an explicit `Set` at the desired initialization point.

UBE 1.0 has no local `WithEvents` declaration and no dynamic `AddHandler` or
`RemoveHandler` statement. Those facilities are reserved for a later language
version.

Property accessors of the same name in one type form one logical property.
`Property Get` reads it and declares the property result type. `Property Let`
writes a value type; `Property Set` writes an object, class, interface, form,
or control reference. A `Variant` property may provide both Let and Set because
its assignment syntax distinguishes value payloads from object payloads.

A property may be read-only (Get only) or write-only (Let and/or Set only).
Every accessor in one property group has the same visibility, `Static` status,
`Default` status, and ordered index-parameter contract. Matching index
parameters have the same names, types, passing modes, optionality, and default
values. A setter appends one required final `ByVal` value parameter; that
parameter is neither optional nor `ParamArray`. Its type is the Get result type
when a Get exists and otherwise defines the write-only property's type.

Let is legal for non-object value types and `Variant`. Set is legal for
object-compatible types and `Variant`. Supplying both Let and Set is legal only
for `Variant`. Duplicate accessors of one kind and incompatible accessor groups
are compile-time errors.

A class or interface may declare at most one `Default` property. Every accessor
in that property group carries `Default`, and the property has at least one
index parameter. A default property permits collection-style indexed shorthand
such as `Customers(5)`. It never supplies a hidden no-argument conversion or
changes reference assignment: `Set A = B` always assigns the identity denoted
by `B` and never invokes a default property.

Reading a property invokes Get. Plain assignment invokes Let; `Set` assignment
invokes Set. The assignment form must agree with the property's value/reference
contract. An unavailable direction is a compile-time error when statically
known and otherwise a controlled runtime error at a foreign/dynamic boundary.

## 6. Procedure implementation contracts

### 6.1 Program entry point

Every executable UBE project has exactly one source-level entry point named
`Main`, declared at module scope in one of these forms:

```vb
Sub Main()
End Sub

Function Main() As Long
    Main = 0
End Function
```

`Main` takes no parameters. The `Sub` form returns a successful process exit
code of zero. The `Function` form returns a signed 32-bit `Long` process exit
code. A project with no matching `Main`, more than one matching `Main`, or a
`Main` with any other signature is invalid when built as an executable. Name
matching follows the ordinary case-insensitive identifier rules.

Libraries do not declare an entry point. Constructors, forms, events, and
arbitrary procedures cannot replace `Main` as the executable entry point.

A project may designate a startup form. This is a build configuration feature,
not a second entry-point form: the compiler arranges for the selected form to
be created and loaded after dependency and module initialization but before
source-level `Main` begins. After `Main` returns, the ordinary thread/event-
source liveness rule decides whether the process idles or shuts down. Startup
forms follow the same cancellable unload, active-procedure drain, event-source
liveness, and orderly shutdown rules as other forms.

### 6.2 Inlining and compiler implementation

UBE distinguishes ordinary calls, requested optimization, mandatory source
expansion, and compiler implementation:

```vb
Public Inline Function Min(ByVal A As Long, ByVal B As Long) As Long
    If A < B Then Min = A Else Min = B
End Function

Public ForceInline Function RotateLeft(ByVal Value As LongLong, _
                                       ByVal Count As Long) As LongLong
    ' Ordinary UBE implementation.
End Function

Public Intrinsic Function StringLength(ByRef Value As String) As LongLong
End Function
```

`Inline` is an optimization request. The compiler may emit an ordinary call.
`ForceInline` is a language contract: every call must be replaced with the
function body, and compilation fails if expansion is impossible. Inlining must
preserve ordinary call semantics: arguments are evaluated once, local names
are hygienic, and `ByRef` identity is retained. Recursive `ForceInline` call
cycles are invalid.

An `Intrinsic` declaration has a header and matching `End` line but no UBE
body. It names an operation supplied by the compiler or target backend. An
intrinsic is identified by its fully qualified declaration and signature, not
by textual name alone. Missing implementations and unsupported targets are
compile-time errors. Intrinsics cannot also be `Inline` or `ForceInline`.

The intrinsic set is part of the versioned compiler/program-support interface and must
remain small and documented. Operations expressible in UBE—including string
algorithms, conversions, collection logic, and most datatype operations—belong
in the separately compiled standard-library source. Intrinsics are reserved
for irreducible facilities such as primitive memory operations, target
instructions, allocation hooks, and LLVM-facing operations.

## 7. Variable access hooks

A stored module, class, or local variable may attach named procedures to reads
and writes while retaining ordinary variable-use syntax:

```vb
Private Temperature As Double
    On Get TemperatureRead
    On Set TemperatureWritten
End Variable

Private Function TemperatureRead(ByRef Storage As Double) As Double
    TemperatureRead = Storage
End Function

Private Sub TemperatureWritten(ByRef Storage As Double, ByVal Value As Double)
    If Value < -273.15 Then Error 5
    Storage = Value
End Sub
```

The declaration owns real backing storage. `On Get` and `On Set` may each occur
at most once. A hook name is resolved in the declaration's lexical scope. Hook
signatures are exactly:

```vb
Function GetHook(ByRef Storage As T) As T
Sub SetHook(ByRef Storage As T, ByVal Value As T)
```

The parameter names are not significant. The first argument is a privileged
reference to that declaration's backing storage. Access through this argument
bypasses the variable's hooks; all ordinary references to the variable,
including references inside its hooks, remain hooked. This makes bypass local
and explicit and prevents accidental compiler-wide suppression of hooks.

The following lowering is observable language behavior:

- Reading `X` invokes its get hook and uses the returned value. Without a get
  hook, it reads the backing storage.
- Assigning `X = Value` evaluates `Value` once, then invokes its set hook.
  Without a set hook, it writes the backing storage.
- A compound read/modify/write operation performs one hooked read followed by
  one hooked write.
- Initialization writes backing storage directly before hooks become active.
- Taking a hooked variable's address or passing it to an ordinary `ByRef`
  parameter is a compile-time error, because either operation could bypass its
  hooks. Its privileged storage parameter may be forwarded `ByRef` by a hook.
- Array-element hooks and first-class accessor references are reserved for a
  later language version. A hook on an array variable observes access to the
  array value, not individual element access.

Hooks are side-effecting unless future effect annotations prove otherwise. An
optimizer must preserve their number and order relative to other observable
operations. A hook that accesses its variable through the ordinary name can
re-enter itself; this is legal and follows normal recursion rules.

## 8. Expressions

Precedence, from lowest to highest, is:

`Imp`, `Eqv`, `Xor`, `Or`, `And`, `Not`, comparisons, `&`, `+ -`, `* /`, `\`,
`Mod`, unary `+ -`, and `^`. Exponentiation is right-associative. Other binary
operators are left-associative. Comparisons do not chain.

`And` and `Or` preserve VB6 eager evaluation. `AndAlso` and `OrElse` require
Boolean operands and skip the right operand when the left operand determines
the result. A skipped operand has no effects. `IsNot` and `Is Not` are
equivalent negated object-identity comparisons. Parenthesizing a `ByRef`
argument may force value
evaluation in compatibility mode; normal UBE code should use explicit `ByVal`
signatures rather than rely on that quirk.

`With expression` evaluates its receiver exactly once and retains that value
until `End With`; a retained object is a temporary strong managed root. A
leading dot binds to the innermost active block. Reassigning the variable from
which the receiver came does not retarget the block. A custom-datatype lvalue
is updated in place; a non-lvalue value expression uses a temporary. A
`Nothing` receiver produces the ordinary controlled member-access failure.

`Me` is a read-only reference to the current class, form, or control instance.
It is legal only while executing such an instance member, cannot be assigned or
passed as writable direct `ByRef` storage, and is unavailable in modules,
interfaces, declarations, and initializers.

`TypeOf expression Is TypeName` tests whether a non-`Nothing` object-compatible
reference implements or derives from the named class, interface, form, or
control type. It evaluates the expression once and returns `False` for
`Nothing`; scalar and custom-datatype operands are compile-time errors.

Required constant expressions may contain literals, previously declared
constants, enum members, parentheses, conversions whose result is statically
known, and the ordinary scalar operators. They cannot read variables, allocate,
call procedures or properties, access object members, raise events, or depend
on runtime or locale state. Dependencies must be acyclic. Evaluation uses the
same exact types, checked arithmetic, and failure rules as runtime execution;
an operation that would set `Err` is a compile-time error.

### 8.1 Compatibility built-ins and value conversion

Strict typing does not require familiar Basic built-ins to reject harmless
scalar inputs. Standard-library functions specifically documented as
compatibility built-ins, including string functions such as `Mid$` and `Len`,
accept broadly typed input values and apply their documented conversion at the
call boundary. A string argument is used directly; a numeric, Boolean, date,
or other scalar argument is converted to its invariant string representation
when the operation consumes text. Thus a literal string and an integer are
both valid inputs to a text-consuming compatibility built-in.

This behavior is an explicit part of each built-in's signature and is not a
general implicit-conversion rule. It does not weaken declaration typing,
assignment checks, user-procedure calls, or other signature selection.

When an object is supplied to a compatibility built-in that permits objects,
linked program support passes the object's opaque handle as the value payload rather than
rejecting the call. An object handle is a runtime-managed identity token, not a
dereferenceable pointer or exposed memory address. The individual built-in
defines how it uses or converts that handle. For example,
`Mid$(PictureBox, 3, 1)` passes `PictureBox`'s handle to `Mid$` under its
broad-input contract; it is not rejected merely because the argument is an
object. `Nothing` is represented by the null handle. Passing an object to an
API without a broad-input or object-accepting contract remains a compile-time
type error.

The standard-library specification must define canonical scalar-to-string and
handle behavior for every broadly typed built-in so results do not depend on
locale, address layout, or undocumented host conversions.

## 9. Runtime errors and explicit trapping

UBE failures while a program runs never display an automatic message box or other modal
user interface. A recoverable failing operation returns the neutral value for
its result type (`0`, `False`, `""`, or `Nothing`, as applicable) and records
the failure in the current thread's `Err` state. Because a neutral value may
also be a successful result, it is not by itself an error indicator; code that
needs to distinguish the cases inspects `Err.Number` or uses an active error
handler.

Successful operations do not implicitly clear a previously recorded error.
`Err.Clear` clears it explicitly. Error state is isolated between threads.
Runtime code must not terminate a process, show UI, or expose undefined
behavior merely because no handler is active. Resource exhaustion or another
condition from which execution cannot safely continue follows a separately
documented controlled-failure path and must never become memory corruption or
an uncontrolled crash.

UBE retains explicit VB-style trapping:

- `On Error GoTo label` activates a procedure-local handler.
- `On Error Resume Next` records the error, substitutes the neutral result
  where one is required, and continues with the statement following the one
  that failed.
- `On Error GoTo 0` disables the active handler for the procedure.
- `Resume`, `Resume Next`, and `Resume label` continue from an active handler
  using their familiar control-flow meanings.

Handlers are lexical procedure state and do not require native exceptions or
stack unwinding. The compiler lowers each potentially failing operation to an
ordinary result plus an internal error status and branches according to the
active `On Error` mode. This keeps requested trapping explicit and permits a
low-overhead implementation.

`On Error GoTo -1` is not UBE syntax. `Resume 0`, if present, denotes the
numeric label `0`; it has no hidden handler-reset meaning.

## 9.1 Legacy control-flow and file statements

`Select Case` evaluates its selector once and tests clauses in source order;
the first matching part executes. Comma-separated clauses are alternatives,
`a To b` is inclusive, `Is op value` compares against the selector, and
`Case Else` matches only when no earlier part did. Each clause expression is
evaluated only if reached.

A `Do` loop has either one precondition after `Do`, one postcondition after
`Loop`, or no condition; it never has both. `While` continues while true and
`Until` continues while false. `On expression GoTo` and `On expression GoSub`
round the expression to `Long` using normal checked conversion, select the
one-based label position, and continue with the following statement when the
result is outside the list. `GoSub` additionally records the ordinary
procedure-local return point.

Classic `Open`, `Close`, `Print #`, `Input #`, `Line Input #`, `Get`, `Put`,
`Seek`, `Lock`, `Unlock`, `Write #`, `Width #`, and named file-operation
statements retain their VB statement shapes. Their file numbers, access modes,
record positions, formatting, encoding, locking, and failure results are
defined by the separately linked portable file library. The language does not
silently track or close these resources at scope exit; the program owns
explicit cleanup, with the operating system reclaiming remaining process
resources only when the program ends.

## 10. UBE low-level extensions

Two core extension statements reserve a stable syntactic envelope:

```vb
Asm "target-specific assembly payload"
Bytecode "backend-specific bytecode payload"
```

The string is lexically ordinary, including doubled-quote escaping. Their
payload languages, constraints, interpolation rules, calling convention, and
LLVM lowering are separate specifications. A compiler must reject an unknown
target or payload format; it must never reinterpret malformed payload as UBE.

## 11. Static restrictions

The parser may build a tree for structurally valid text that later fails these
mandatory checks:

- `Exit` must name an enclosing construct of the appropriate kind.
- `Next` variables, procedure terminators, and property kinds must match their
  open constructs.
- Labels are procedure-local and unique after case folding.
- `GoSub`/`Return`, standalone `End`, and unstructured file I/O are accepted
  compatibility features and should produce opt-in modernization diagnostics,
  not parse errors. `On Error` is a supported explicit error-trapping feature.
- Declarations without an explicit type and `Option Explicit Off` are errors
  in every mode.
- `AddressOf QualifiedName` is the classic low-level callback bridge. It must
  resolve statically to an ABI-safe Sub or Function in a standard module and
  may appear only as an actual argument for a compatible pointer-sized
  parameter of an external `Declare`. It cannot target an instance member,
  property, event, external declaration, intrinsic, or captured local state.
  It is not a storable or callable UBE value and creates no closure or GC root.
- `Any` is restricted to external declarations.
- `Inline`, `ForceInline`, and `Intrinsic` are mutually exclusive; `Default`
  remains restricted to valid property declarations.
- Hook handlers must have the exact signature required by their variable type.
- Inline assembly and bytecode require an explicitly enabled unsafe context in
  the compiler configuration.

## 12. Objects, managed lifetime, and resources

The `UBE_Name` of a form or control module is both its source-module name and
its declared type name. In an instance module, `Me` denotes the current class,
form, or control identity; it is a reference, not a copy. A form name in a type
context denotes the form type. In a value context, a bare form-module name
denotes that form's compiler-maintained project default-instance slot. Controls
do not receive a project default instance merely because their type exists.

`New FormType` creates a distinct identity and runs its parameterless
`Class_Initialize`, but does not create a platform window, make the form
visible, or register an event source. `Load FormValue` loads that identity
synchronously. First successful load creates framework/UI state and
designer-created controls, invokes parameterless `Form_Load`, and registers the
loaded form as an active callback event source. Loading an already loaded
identity succeeds without repeating those steps. Loading does not imply
showing; `Show` is a framework-library operation.

A control identity is created by its containing designer or by an explicit
framework operation. `New ControlType` creates an unattached identity only when
that control type permits independent creation; it does not supply a visual
parent or native UI resources. `Load` requires a valid containing framework
context and otherwise records a controlled error. Classic dynamic control-array
`Load` is outside UBE 1.0 until separately specified.

Construction or loading failure records `Err`, exposes no partially loaded
identity, and releases everything acquired by the failed attempt. `Load` and
`Unload` require a statically known form/control reference; ordinary classes,
generic `Object`, and unrelated values are rejected. `Load Nothing` records a
controlled error. `Unload Nothing` remains a no-op.

`Set` is mandatory whenever an assignment destination is an object, class,
interface, form, or control reference, including a reference entering or
leaving a `Variant`. Reference assignment preserves identity; it never clones
an object. `Set A = Nothing` removes only `A`'s reference and does not affect
other aliases.

`Dim A As New T` constructs `T` immediately when execution enters the
declaration's scope. Construction is parameterless. Clearing `A` later does
not cause automatic reconstruction. Classes use parameterless
`Class_Initialize`; parameterized setup is an ordinary method.

Variable storage ends deterministically with its scope. Managed values that
are no longer reachable become eligible for automatic collection, which need
not happen immediately. `CollectGarbage()` requests a synchronous collection
and returns `Long` 1 if cleanup work was performed, otherwise 0. An unreachable
class receives `Class_Terminate` at most once before reclamation. Resurrection
from termination is an error.

Files, sockets, native handles, database connections, and other resources
opened by user code are not automatically tracked by garbage collection. Code
must close or release them explicitly on success, error, and cancellation
paths. Orderly process termination closes remaining operating-system resources,
but is not a substitute for timely cleanup.

`Unload` applies to forms and controls, not ordinary class instances. A form
first invokes `Form_Unload(ByRef Cancel As Integer)`. A nonzero `Cancel` leaves
it loaded. Once accepted, new calls and callbacks are rejected, its window and
native handles are released, existing procedures drain, and all aliases become
`Nothing` when unloading completes. Control unloading follows the corresponding
control lifecycle without inventing class-wide `Unload` behavior.

Accepted unload clears a matching default-instance slot and every ordinary or
`WithEvents` alias to that identity. Cancellation changes none of those
references, subscriptions, resources, or liveness registrations. An identity
whose unload completed cannot be revived; a subsequent default-form operation
can only refer to a newly created identity under the separately resolved
default-slot creation rule.

## 13. Threads, events, and program lifetime

`CallNew Qualified.Sub(arguments)` starts a directly visible, statically
resolved `Sub` and returns a nonnegative `LongLong` program thread identifier.
Zero reports creation failure and records `Err`. Identifiers are not native
handles, are not reused during a process, and may be ignored. A Function is not
a legal target. Arguments are evaluated once from left to right and captured
`ByVal` before the worker begins; value data is copied and object identities are
shared.

All program state normally visible to code remains visible from every UBE
thread. Unsynchronized competing access has unspecified relative order but
must not tear scalar or reference values, create invalid managed references,
or invoke undefined behavior. `SyncLock object ... End SyncLock`, sequentially
consistent atomics, thread events, semaphores, and message queues provide the
ordering defined in [`threading.md`](threading.md).

Stopping is cooperative. `ThreadRequestStop` records a sticky request and
wakes approved waits; `ThreadStopRequested()` lets the worker observe it and
return through normal cleanup. `ThreadWait` waits for completion and makes the
worker's preceding actions visible on success. UBE does not forcibly terminate
a thread.

Events dispatch synchronously unless an individual API explicitly documents a
different model. An event handler may cause the same event to be raised again;
recursive dispatch follows ordinary recursion rules and must end in controlled
failure rather than an uncontrolled stack crash if limits are exhausted.
Calls involving UI-owned objects are transparently dispatched to their owning
thread while preserving the source call's synchronous result and error
behavior.

Each successful `WithEvents` connection is one subscription. Connections are
ordered by the completion of the `Set` operations that established them. An
event invocation uses the subscriptions present when that invocation begins:
a connection removed before its turn is skipped, while one added during
dispatch first participates in the next invocation. Concurrent connection,
disconnection, dispatch, and unload are memory-safe and follow the same
subscription-snapshot rule. Successful form/control unloading clears affected
`WithEvents` aliases to `Nothing` and disconnects them under the approved
unload lifecycle.

After `Main` returns, a program remains alive while any UBE thread or active
callback-event source exists. Loaded forms, active timers, listeners, and
similar registered sources count; a merely allocated object that declares
events does not. Orderly shutdown begins after both counts reach zero and uses
the ordering in [`threading.md`](threading.md).

## 14. Conversion, arithmetic, and comparison

The complete implicit relationship matrix is normative in
[`conversion-table.md`](conversion-table.md). A permitted known conversion is
performed during compilation where possible. A provably invalid or
out-of-range constant is a compile-time error. A permitted runtime-dependent
conversion failure produces the destination's neutral value and records the
current thread's `Err`. Successful operations do not clear an earlier error.

Fractional-to-integer conversion rounds to nearest with ties to even. Default
numeric, Boolean, and date text is invariant. `True` has numeric value -1 and
`False` value 0. Canonical Date text is
`YYYY-MM-DDTHH:MM:SS[.fraction]`; locale-sensitive parsing and formatting are
explicit library operations.

Integer, `Currency`, and `Decimal` arithmetic is checked. Known overflow or
division by zero is a compile-time error; runtime-dependent failure produces
neutral zero plus `Err`. `Single` and `Double` follow IEEE-754, including
infinities and NaN, without recording an error merely for producing those
values.

Operands are evaluated exactly once from left to right. Integer arithmetic
promotes `Byte` to `Integer`, then chooses the first of `Integer`, `Long`, and
`LongLong` that covers both operand types. Enums participate as their
underlying integer type and arithmetic results are not enum values. Decimal,
Currency, and floating combinations use the first applicable result family:
`Double`; `Single` (except that mixing it with Decimal, Currency, LongLong, or
a pointer-sized integer produces Double); `Decimal`; then `Currency`.

`IntPtr` and `UIntPtr` arithmetic is permitted between two operands of the
same pointer-sized type and with a fixed integer whose complete range fits it
on the selected target. Other signed/unsigned pointer mixtures require an
explicit conversion. They never silently promote to Decimal and never grant
memory access.

`+`, `-`, and `*` use the common numeric type. `/` produces Decimal when a
nonfloating operand is Decimal or Currency and otherwise Double. Before `\`
and `Mod`, nonintegral operands round to the nearest integer, ties to even;
division truncates toward zero and the nonzero remainder has the dividend's
sign. `^` converts both operands to Double and is right-associative. `&` is the
only string-concatenation operator; `+` is numeric only.

Boolean `Not`, `And`, `Or`, `Xor`, `Eqv`, and `Imp` are eager logical
operations. On integral values they are bitwise operations in the common
integer type. `AndAlso` and `OrElse` require Boolean values and short-circuit.
String comparison is lexicographic under `Option Compare`; `Like` uses the
classic `?`, `*`, `#`, bracket-list, negated-list, and range patterns.

Decimal has a sign, a 96-bit coefficient, and a decimal scale from 0 through
28. Results preserve exact digits when possible and otherwise reduce scale by
round-to-nearest, ties-to-even; it has no NaN or infinity. Date is not a numeric
serial value and supports comparison but no core arithmetic. Its fields use the
proleptic Gregorian calendar, years 0001 through 9999, hours 00 through 23,
minutes and seconds 00 through 59, and nanoseconds 0 through 999999999.

`Option Compare Binary` is the default and compares Unicode scalar values.
`Option Compare Text` uses the versioned, locale-independent Unicode folding
defined for UBE. `Option Compare Database` is unsupported and diagnosed.

A `Variant` begins as `Empty` and preserves the exact type assigned to it.
`Null` propagates through Variant arithmetic and comparison. Conversion of
`Null` to a fixed type fails with a neutral result plus `Err`; `IsNull()` is the
reliable test. `Is` and `IsNot` apply only to object-compatible references.

## 15. Libraries, exports, and portability

UBE programs are native executables or libraries. They do not require a
separate UBE runtime, virtual machine, or installed execution environment.
Garbage collection, threading, error state, and platform adapters are program
support compiled and linked into each output; unused support may be omitted.
Ordinary public functions remain separately compiled UBE library source rather
than hard-coded compiler implementations.

`Public Export` is legal only on a module-level Sub or Function in a project
whose kind is `Library`. It creates a foreign entry point governed by
[`foreign-abi.md`](foreign-abi.md). Public UBE visibility alone does not export
a foreign symbol. Exported custom values and object references transfer the
documented value ownership or external lease to the receiving program until it
releases them. Self-unloading exported objects invalidate all leases safely.

The language and portable library do not assume Windows paths, handles,
message queues, object formats, or calling conventions. Windows is the first
development host and target, not part of the language semantics. Target-
specific facilities require explicit platform APIs. A portability claim
requires verification on the named target rather than inference from LLVM
support alone.

## 16. Reserved evolution space

VB6-compatible programs should avoid declaring unbracketed names that are UBE
keywords. New hard keywords will be added only in a major language version;
minor versions should use contextual keywords. Bracketed identifiers remain an
escape hatch for source migration.
