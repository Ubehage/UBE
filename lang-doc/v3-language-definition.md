# UBE 1.0 expanded language definition for Compiler v3

**Status:** approved and frozen UBE 1.0 target; not yet fully implemented  
**Implementation target:** `compiler/UBE_Compiler_v3/`  
**Bootstrap compiler:** preserved UBE Compiler v2

This document consolidates the owner-confirmed language and architecture
requirements introduced for v3. Approved decisions and the results of the
completed cross-specification review are recorded here.
This file retains the complete expanded rules, examples, and design context.
`language-spec.md` defines precedence among the normative sources if wording
conflicts.

V3 is the first public-release compiler target. “Final” in this context means
a frozen, versioned UBE 1.0 contract; later language versions may evolve it
deliberately without silently changing 1.0 programs.

## 1. Confirmed design principles

UBE 1.0 shall:

- retain approachable Basic-family source syntax;
- use strict static types while performing safe, obvious conversions;
- diagnose provably invalid programs at compile time;
- turn recoverable runtime failures into neutral results plus thread-local
  `Err`, without automatic dialogs or uncontrolled crashes;
- support native multithreaded programs through an explicit `CallNew` form;
- support directly and indirectly recursive custom data types;
- keep the compiler minimal and move public algorithms and built-ins into
  separately compiled UBE libraries;
- separate portable compiler/library behavior from the small platform
  substrate needed to reach an operating system;
- distinguish build host from compilation target and use LLVM as the initial
  native backend;
- treat Windows as the first development host and target, not as part of UBE
  semantics.

UBE programs do not run inside a separate UBE runtime, virtual machine, or
installed execution environment. Garbage collection, threading, error state,
memory support, and platform adapters are library/substrate code compiled and
linked into the produced program. Link-time elimination should omit unused
support. The word "runtime" in semantic descriptions means behavior while the
native program is executing, not a separately started product.

## 2. Compiler, library, and platform separation

### 2.0 Native source identity

Every newly created native UBE source file begins with a versioned component
header and name attribute:

```ube
UBE SOURCE 1 CLASS
Attribute UBE_Name = "Customer"
```

The permitted kind is `MODULE`, `CLASS`, `FORM`, or `CONTROL`. It must agree
with the file extension: `.bas`, `.cls`, `.frm`, or `.ctl`, respectively.
Missing headers, missing/invalid names, duplicate native identity attributes,
and extension-kind mismatches are compile-time errors. The integer after
`SOURCE` versions the source container independently of the UBE language
version.

New UBE tools emit `Attribute UBE_Name` and never emit `VB_` identity metadata.
Classic `VERSION ...` headers and `Attribute VB_Name` remain recognizable only
as legacy VB6 compatibility input. Saving an imported source as native UBE
replaces its legacy identity header while preserving other supported designer
metadata through the documented conversion path. Unknown reserved `UBE_`
attributes are diagnosed rather than silently assigned meaning.

UBE visibility and foreign-library export are separate. A standard module in a
`Kind = "Library"` project may declare:

```ube
Public Export Function CreateWorker() As Worker
    Set CreateWorker = New Worker
End Function

Public Export Sub ProcessFile(ByVal Path As String)
End Sub
```

`Public` makes a declaration visible to UBE source. `Export` additionally
places a module-level Sub or Function in the generated foreign ABI and is
invalid without `Public`. Ordinary public helpers are never exported
accidentally. Exported signatures may use only types supported by the versioned
ABI; returned objects create external ownership leases under section 4.

Public members of an object returned through the ABI are reached through its
generated opaque-handle interface rather than exported independently. Exported
symbols, calling conventions, value layouts, status results, and ownership
operations are described by generated ABI metadata. The selected target maps a
`Library` project to its native shared-library format and filename.

### 2.1 Compiler responsibilities

The compiler recognizes syntax and enforces semantic behavior. It resolves
types and calls, selects conversions, validates concurrency and lifetimes,
produces verified target-independent IR, and lowers that IR through a selected
target backend.

The compiler does not contain ordinary implementations of public string,
formatting, collection, conversion, threading-helper, or similar functions.
Names supplied by a library are resolved through normal declarations and
versioned library metadata rather than hard-coded textual-name checks.

### 2.2 Core and standard libraries

The core and standard libraries are separate UBE projects compiled and linked
with user programs. The build driver automatically selects the core-library
version compatible with the compiler and target, so beginners do not need to
declare routine language support manually.

Most built-in functions are library procedures. A small `Intrinsic` interface
is allowed only for operations that cannot be expressed safely in ordinary
UBE, such as primitive allocation hooks, atomic target operations, process
startup, and backend-facing facilities. Intrinsics are identified by qualified
declaration, signature, ABI version, and target support—not by name alone.

### 2.3 Platform substrate

A small target-specific substrate supplies unavoidable OS and ABI operations,
including process startup, virtual memory, native thread creation, files,
clocks, message dispatch, atomics, and linker/runtime integration.

Portable UBE library APIs sit above that substrate and must behave consistently
across supported targets. Explicit platform modules may expose native
facilities by opt-in; ordinary portable APIs do not leak native handles.

## 3. Safe implicit conversions

Strict typing prevents unrelated values from being treated as interchangeable.
It does not require users to write boilerplate for an obvious, defined scalar
conversion.

### 3.1 Compile-time-known values

When the compiler knows a value and its destination type, it performs the
conversion during compilation where the UBE 1.0 conversion table permits it:

```ube
Dim Text As String = 42       ' Stored as the constant "42".
Dim Count As Long = "123"     ' Stored as the constant 123.
```

If a permitted conversion is provably invalid or out of range, compilation
fails at the value with a stable diagnostic:

```ube
Dim Count As Long = "not a number"  ' Compile-time error.
```

The compiler must not defer a known failure merely to make it appear silent at
runtime.

### 3.2 Runtime-dependent values

When validity depends on runtime data, the compiler emits the corresponding
checked core-library conversion:

```ube
Dim Count As Long = UserInput
```

If `UserInput` is not a valid `Long`, the assignment receives `0` and the
current thread's `Err` records the conversion failure. No automatic dialog is
shown and the process does not crash.

Successful operations do not implicitly clear an earlier `Err`; code uses
`Err.Clear` explicitly. Every thread has an independent `Err` state.

### 3.3 Frozen scalar conversion details

Conversion from a fractional numeric value to an integer uses round-to-nearest
with ties to even (banker's rounding). For example, `2.5` becomes `2`, `3.5`
becomes `4`, and `-2.5` becomes `-2`. A rounded result outside the destination
range is a conversion failure rather than wrapping or saturation.

Invariant string-to-number conversion permits leading and trailing whitespace
and an optional leading `+` or `-`. It accepts decimal integers and decimal
real values with an optional exponent. Integer destinations also accept `&H`
hexadecimal and `&O` octal forms. After surrounding whitespace is removed, the
entire string must match one permitted form; conversion never accepts only a
valid prefix and ignores trailing text. Default conversion never depends on
the host locale.

A malformed constant string used where conversion is required is a
compile-time error. Malformed runtime-dependent text produces the destination
type's neutral value and records the conversion failure in the current
thread's `Err` state.

A fixed-length declaration `String * n` always stores exactly `n` characters.
Assignment truncates a longer source after its first `n` characters and pads a
shorter source on the right with spaces. Neither adjustment is an error and
neither records `Err`, because the declared fixed size explicitly requests the
behavior. Reading, copying, or passing the value includes all `n` stored
characters, including trailing padding spaces. The value can neither grow nor
shrink during its lifetime.

Numeric zero converts to `False`; every nonzero numeric value converts to
`True`. `False` converts numerically to `0` and `True` to `-1`, preserving the
classic VB bit representation. Boolean-to-string conversion produces `True`
or `False`. String-to-Boolean conversion accepts those words
case-insensitively and also accepts a valid numeric string under the preceding
rules, with zero false and nonzero true.

All core numeric types convert implicitly to one another. Every such
conversion is range-checked. Integer narrowing fails rather than wrapping.
Integer-to-floating conversion is permitted even when a large integer cannot
be represented exactly. Floating conversion follows IEEE round-to-nearest,
ties-to-even; `Currency` and `Decimal` likewise use ties-to-even when reducing
scale. A known out-of-range constant is a compile-time error. At runtime the
same condition produces the destination's neutral value and records `Err`.

`Single` and `Double` may contain IEEE not-a-number, positive infinity, and
negative infinity. Their invariant strings are `NaN`, `Infinity`, and
`-Infinity`; parsing accepts these spellings case-insensitively. Conversion of
a special value to an integer, `Currency`, `Decimal`, `Date`, or `Boolean`
fails. Conversion between `Single` and `Double` preserves the special value.

`String` and `Date` convert implicitly using only UBE's invariant date formats.
`Date` converts to the canonical form `YYYY-MM-DDTHH:MM:SS[.fraction]`.
Date-only input uses midnight; time-only input uses `0001-01-01`. The fraction
is omitted when zero and otherwise contains up to nine digits with trailing
zeroes removed. Core dates are timezone-neutral and the canonical form never
contains localized names, separators, AM/PM text, or a timezone suffix.
Invalid or out-of-range dates follow the ordinary
compile-time-known versus runtime-dependent failure rule. Numeric and Boolean
values do not convert implicitly to or from `Date`; explicit compatibility
library functions provide VB serial-date conversion where required.

An `Enum` is a named set of integer constants whose values otherwise behave as
their underlying integer type:

```ube
Public Enum AccessMode As Long
    Read = 1
    Write = 2
End Enum
```

The underlying type is `LongLong` when omitted and may be explicitly only
`Long` or `LongLong`. The first omitted member value is zero and each later
omitted value is the preceding value plus one. Explicit values are compile-time
integer constants and every member must fit the selected type. Duplicate values
are allowed.

Enum values participate in assignment, parameter passing, returns,
comparisons, arithmetic, and bitwise operations exactly as their underlying
integer. Checked ordinary numeric conversion permits numeric values and other
enums to interact. Invariant string conversion produces the numeric text, not
the member name; a library reflection/formatting function may request a
declared member name. UBE 1.0 has no separate `Flags Enum` syntax.

Array lower and upper bounds and indices use `LongLong`; lower bounds may be
negative. `Option Base` affects only an omitted lower bound. Reading outside an
array's bounds produces the element type's neutral value and records `Err`.
Writing outside the bounds changes nothing and records `Err`. Neither case may
access invalid memory or crash.

Array assignment creates an independent value copy. `Erase` returns a dynamic
array to its unallocated state and resets every element of a fixed array to its
neutral value. `ReDim` discards old contents and initializes new elements to
neutral values.

`ReDim Preserve` retains elements whose full coordinate exists in both the old
and new bounds, and releases managed contents of removed elements. It may
resize any dimension, unlike VB6, but cannot change rank or element type. New
coordinates receive neutral values.

String comparison defaults to `Option Compare Binary`. Binary comparison is
lexicographic over Unicode scalar values and is case-sensitive. `Option Compare
Text` applies UBE's versioned Unicode case folding and remains
locale-independent. Fixed-length padding spaces are stored characters and
participate in comparison.

`Like`, `=`, `<>`, `<`, `<=`, `>`, and `>=` use the comparison mode of the
module containing the expression; modules in one project may choose different
modes. `Option Compare Database` is recognized only as legacy compatibility
syntax and produces a clear unsupported-collation diagnostic. Locale-aware
comparison requires an explicit standard-library call with a locale.

The standard library must provide explicit localization-aware date parsing and
formatting, including local field order, separators, month and day names,
12/24-hour conventions, and timezone operations. Locale-aware calls do not
alter invariant implicit conversion, source literals, or persisted canonical
text.

A `Variant` stores any UBE value together with its exact runtime type.
Assignment into a `Variant` does not coerce that value. Strings, arrays, and
custom datatypes retain their ordinary value semantics, while an object stored
in a `Variant` is a strong object reference.

A statically object-valued expression requires `Set` when stored in a
`Variant`, and extracting an object reference from a `Variant` into an object,
class, form, control, or interface destination also requires `Set`:

```ube
Set Boxed = Instance
Set Instance = Boxed
```

Ordinary `=` stores and extracts scalar/value payloads. Assignment from one
whole `Variant` to another uses `=` and copies the complete type tag and
payload; if the payload is an object, the copy retains another strong reference
to the same identity. A runtime-incompatible extraction produces the
destination's neutral value and records `Err`.

Assignment from a `Variant` to a fixed scalar applies the ordinary conversion
table to the contained runtime value. An object payload does not thereby gain
a general numeric or string conversion. A custom-datatype payload can be
extracted only as the same declared custom type. An object payload can be
extracted as `Object` or a runtime-compatible class type; incompatible class
extraction produces `Nothing` and records `Err`.

An uninitialized `Variant` contains `Empty`. `Empty` converts successfully to
the requested destination's neutral scalar, string, or object value: `0`,
`False`, `""`, or `Nothing`, as applicable. `Null` represents explicitly
missing or unknown data. It remains `Null` in another `Variant`, but conversion
to a fixed type fails, produces that type's neutral value, and records `Err`.
The standard library provides `IsEmpty()` and `IsNull()` tests.

`Null` propagates through unary operations, arithmetic, concatenation, and
comparison when the result remains a `Variant`. `IsNull()` is the reliable test
for that state. Converting a propagated result to a fixed type produces that
type's neutral value and records `Err`; consequently `If Null Then` evaluates
as false through a failed Boolean conversion and records `Err`. `Null Is
Nothing` is invalid because `Is` requires object references. `Empty` does not
propagate and instead converts to the operation's applicable neutral value.

### 3.4 Forbidden relationships

An implicit conversion is available only when the versioned conversion table
defines one. An unrelated object cannot be assigned or passed to an integral
parameter merely because both have an internal machine representation:

```ube
Dim Count As Long = SomeWindow  ' Compile-time error.
```

Object handles remain opaque. An individual library API may explicitly declare
that it accepts an object handle or a broadly convertible scalar; that contract
does not create a general object-to-number conversion.

### 3.5 Determinism

Default numeric, Boolean, date, and string conversions use invariant UBE
formats. Locale-aware conversions and formatting require explicitly
locale-aware library calls. Results must not depend on pointer values, native
handle layouts, or undocumented host behavior.

Integer, `Currency`, and `Decimal` arithmetic never silently wraps. A provably
overflowing constant expression is a compile-time error. Runtime overflow
produces the result type's neutral value and records `Err`. Integer division or
modulus by zero produces zero plus `Err`; `Currency` and `Decimal` division by
zero likewise produces their neutral zero plus `Err`.

`Single` and `Double` arithmetic follows IEEE-754. Finite nonzero division by
floating zero produces signed infinity; floating zero divided by floating zero
produces `NaN`; and finite overflow produces signed infinity. Merely producing
an IEEE infinity or `NaN` does not record `Err`. A later conversion of such a
value to an incompatible destination follows the checked special-value rules.
Any future shift operators must validate their counts rather than inherit a
target processor's masking or undefined behavior.

UBE retains eager VB-compatible `And` and `Or`: both operands are evaluated.
UBE 1.0 additionally provides `AndAlso` and `OrElse`. `AndAlso` evaluates its
right operand only when the left operand is true; `OrElse` evaluates its right
operand only when the left operand is false. They require Boolean-convertible
operands and produce `Boolean`. A skipped operand has no effects: calls,
allocation, errors, events, and other operations within it do not occur.

`IsNot` and the two-word spelling `Is Not` both perform the negation of object
identity `Is`. They apply only to object-compatible references, including
comparison with `Nothing`.

### 3.6 Frozen conversion table

The complete source/destination matrix and its conformance requirements are
frozen in [`conversion-table.md`](conversion-table.md). Compiler and library
implementations must use that versioned table rather than infer conversions
from native layouts or host-language behavior.

### 3.7 Frozen operator and scalar rules

The exact promotion, result-type, checked-failure, Boolean/bitwise, string,
`Like`, `Variant`, `Null`, `Empty`, Decimal, Date, pointer-sized integer, and
constant-expression rules are normative in
[`language-spec.md`](language-spec.md), sections 4, 8, and 14. In particular,
`+` is numeric, `&` concatenates, Decimal uses a 96-bit coefficient and scale
0 through 28, Date is not a numeric serial value, and incompatible mixed
`IntPtr`/`UIntPtr` arithmetic requires an explicit conversion. Implementations
must not select operators from native layouts or host-language defaults.

## 4. Recursive custom data types

UBE permits direct and indirect recursive custom-type declarations:

```ube
Type NewData
    Property1 As Long
    Data As NewData
End Type
```

Custom types are native value types. `New` is reserved for objects, classes,
and other reference-based constructs; it is neither required nor permitted to
construct a custom-type field. Recursive fields do not expose reference
semantics, `Nothing`, identity tests, or an allocation-state query to UBE code.

An inline instance cannot physically contain another complete inline instance
of itself because that layout would have infinite size. The compiler detects
directly and indirectly recursive type groups and represents each recursive
edge with hidden managed storage while retaining ordinary inline layout for
nonrecursive fields. This address is an implementation detail and is never an
observable UBE value.

Hidden recursive storage begins unmaterialized. Reading or writing through a
recursive field automatically materializes one zero-initialized value at that
edge. Materialization proceeds only as deeply as the executed source accesses:

```ube
Dim Root As NewData
Root.Data.Property1 = 42
Print Root.Data.Data.Property1
```

The first statement through `Data` materializes one descendant. The `Print`
statement materializes a second descendant. Code cannot distinguish an
unmaterialized field from a materialized field containing its type's neutral
value except through the ordinary effects of subsequently stored data.

Assignment of a custom type has value semantics. The destination receives an
independent semantic copy of every inline field and every materialized
recursive descendant; later changes to either value do not affect the other.
An implementation may copy a raw contiguous region only when its layout and
field ownership make that operation safe. It must copy or retain strings,
arrays, objects, other managed fields, and hidden recursive storage according
to their own contracts rather than duplicating owning addresses byte-for-byte.

Contained fields follow their own value category during that assignment:

- scalar fields are copied directly;
- strings are copied as values, although an implementation may share
  immutable backing storage until mutation;
- fixed and dynamic arrays are copied by value, including independent element
  storage;
- nested custom types are copied recursively by value; and
- object and class fields copy their managed reference, not the referenced
  object. Both custom values consequently refer to the same object.

UBE never implicitly clones an object during custom-type assignment. Such an
object may own identity or external resources for which an automatic clone
would have no generally correct meaning.

`=` and `<>` compare custom values field by field when every contained field
supports equality. Recursive fields are compared by value, never by their
hidden storage addresses. Unmaterialized storage compares as its type's
neutral value and comparison does not materialize additional descendants;
therefore an unmaterialized recursive field equals a materialized descendant
whose complete observable value is neutral. Implementations must handle deep
values iteratively or with a guarded traversal rather than risking an
uncontrolled native-stack overflow.

Ordering operators such as `<`, `<=`, `>`, and `>=` are not defined for custom
types. `Is` remains an object-identity operator and cannot be applied to a
custom type or its hidden recursive storage.

A custom type containing an object or class field is not automatically
equality-comparable because object identity uses `Is`, not `=`. A future
explicit class value-equality contract may make such a field comparable; UBE
does not infer one from object layout or identity.

UBE 1.0 does not expose weak references or automatic class value equality.
Every ordinary object reference is strong and keeps its object reachable.
Classes compare identity only through `Is` and `Is Not`; `=` and `<>` do not
implicitly compare class fields, layout, or identity. Runtime internals may use
weak references, but they are not UBE source values. Public weak-reference and
class-defined value-equality facilities are reserved for a later language
version.

Public functions may return custom datatypes and objects. A returned custom
datatype is transferred to the caller as an independent value under the same
copy rules as assignment. A returned object transfers a strong reference to
the caller; ending the function releases the callee's local variable but does
not make the returned object unreachable while the receiving program retains
it. If the caller ignores the result, the temporary result reference is
released normally.

An object returned from an exported UBE library or DLL to non-UBE code is not
exposed as a raw garbage-collected address. The library returns a versioned,
opaque interoperation handle and records an external ownership lease as a
garbage-collector root. The represented class or module remains resident even
when no ordinary UBE reference reaches it. It is eligible for destruction only
after the foreign caller explicitly releases or unloads the external ownership
and no other applicable root remains, or when the library itself is orderly
unloaded.

An exported class or module remains responsible for its own internal cleanup.
Before destruction, its UBE termination path releases its UBE-managed state
and every native resource it owns. If the instance initiates its own supported
unload lifecycle, it cleans up and invalidates its exported handle; subsequent
foreign calls through that token return a controlled unloaded-object status.
UBE cannot rewrite a variable stored by foreign code to `Nothing`, and foreign
code must discard an invalidated token according to the generated ABI.

The generated library ABI must provide explicit, documented operations for
foreign ownership release and status reporting. It must never require the
foreign caller to know UBE's garbage-collector layout or directly free UBE
memory.

External ownership is counted per acquired handle lease. Returning or
otherwise acquiring another handle for the same identity creates another
lease. Releasing one lease does not invalidate another caller's lease to that
identity. The instance becomes eligible for ordinary collection only after its
final external lease is released and no internal UBE root reaches it.

Identity-wide self-unload is different from lease release: it invalidates all
foreign handles for that identity. Releasing an already invalidated handle is
harmless and idempotent. Any other operation through an invalidated handle
returns the generated ABI's controlled invalid-handle or unloaded-object
status; it must not dereference reclaimed storage.

The compiler emits type-layout metadata describing managed fields and hidden
recursive edges. The runtime uses that metadata for copying, traversal, and
lifetime management. Directly and mutually recursive type groups use the same
rules.

Arbitrary recursive graphs may contain cycles, so plain reference counting is
not sufficient by itself. The UBE runtime must provide cycle-safe managed
lifetime behavior. UBE 1.0 therefore requires tracing garbage collection for
managed memory.

### 4.1 Variable and managed-memory lifetime

Variable storage has deterministic scope lifetime. When execution leaves a
variable's declaring scope, including through an ordinary return, `Exit`, an
active error path, or cooperative cancellation, the compiler releases that
variable on every control-flow edge:

- scalars require no managed-memory action;
- strings, arrays, objects, and managed recursive values release their roots;
- custom values recursively release their managed fields;
- releasing a variable does not destroy an object that remains reachable from
  another root.

An unreachable managed object or graph is reclaimed by the garbage collector.
Collection time is not observable program logic and is not guaranteed to
coincide with scope exit. Cyclic graphs are collectible after their final
external root is released.

Garbage collection is always automatic. The runtime schedules collection as
needed by allocation activity, memory pressure, unreachable-cycle detection,
and orderly shutdown. Correct programs never require an explicit collection
call, and no implementation may disable automatic reclamation merely because
the standard library also offers a manual request.

The portable standard library provides the following synchronous function:

```ube
Function CollectGarbage() As Long
```

It requests a complete collection and coordinates with all UBE threads,
reclaims managed values that are unreachable under the collection snapshot,
and completes their eligible `Class_Terminate` procedures before returning.
It does not unload or destroy reachable objects, forms, or controls and does
not release external resources still owned by reachable code. It returns
exactly `1` if this pass reclaimed at least one managed allocation or ran at
least one eligible termination procedure; otherwise it returns `0`. This is a
status value, not an object count or byte count. Automatic collection may have
already reclaimed available garbage before the call, in which case the
explicit pass returns `0`.

A class may declare `Class_Terminate` as its final cleanup notification. The
runtime invokes it exactly once after the instance has become unreachable and
immediately before reclaiming that instance's memory. The instance remains
valid while its termination procedure runs. Termination may be delayed,
especially for an unreachable reference cycle, but memory reclamation may not
silently bypass it. Remaining instances receive the same notification during
orderly program shutdown.

Releasing a reference does not necessarily make its object unreachable. For
example, `Set A = Nothing` releases the reference held by `A`; an instance also
referenced by `B` remains alive. Implementations may promptly terminate an
ordinary acyclic instance when its final reference is released, but source
code must not depend on prompt collection. Code requiring timely release of an
external resource must perform an explicit lifecycle operation rather than
wait for `Class_Terminate`.

`Unload` is an explicit lifecycle operation for a form or control identity.
It differs from releasing an individual reference:

```ube
Set A = New MyClass
Set B = A
Set A = Nothing  ' A is Nothing; B still refers to the instance.
Unload B         ' begin the lifecycle-defined unload of the instance.
```

For a form, `Unload FormValue` first invokes its cancellable unload event:

```ube
Private Sub Form_Unload(ByRef Cancel As Integer)
    ' Set Cancel to any nonzero value to refuse unloading.
End Sub
```

The event begins with `Cancel = 0`. If it returns with a nonzero value, the
unload request is abandoned and the form continues uninterrupted. Its window,
handles, event-source registration, references, and loaded state remain
unchanged.

If the event returns with zero, unloading is accepted. The platform window is
destroyed and its native handles and active event-source registration are
released before control returns to the user code that initiated `Unload`.
Procedures already executing as part of that form, including a procedure that
used `Unload Me`, remain valid and are allowed to return normally. After the
last active `Sub`, `Function`, property, or event procedure belonging to the
form exits, final unloading runs: `Class_Terminate` is invoked exactly once,
all UBE-managed references to that identity become `Nothing`, and the instance
storage is reclaimed. It cannot be resurrected during termination.

`Unload Nothing` has no effect. Concurrent access and foreign references need
additional rules before this lifecycle is normative; no implementation may
allow them to observe freed storage, corrupt memory, or crash the process.

After a form accepts unloading, no new event, callback, property, `Function`,
or `Sub` may enter that form. Procedures that entered before acceptance,
including procedures executing on other UBE threads, may finish normally and
may continue to use ordinary UBE fields while unwinding. An operation that
requires the already destroyed platform window or native handle fails through
the controlled runtime-error mechanism and must not access a stale handle.

Final termination waits until every previously active form procedure returns,
but the initiating thread does not block waiting for procedures on other
threads; such waiting could deadlock. The runtime automatically performs
`Class_Terminate`, alias clearing, and reclamation when the active-call count
reaches zero.

Controls follow the same lifecycle through:

```ube
Private Sub Control_Unload(ByRef Cancel As Integer)
End Sub
```

Nonzero `Cancel` leaves the control loaded and unchanged. After acceptance, no
new procedure enters it, its native handles and callback registration are
released, existing procedures drain, and final termination clears every alias
to `Nothing`.

Ordinary user-defined classes do not automatically support the `Unload`
statement or form-style loaded state. A class that owns a resource exposes an
ordinary author-defined method such as `Close`, `Dispose`, or `Shutdown` when
it requires explicit timely cleanup. It still receives `Class_Terminate`
before garbage-collected reclamation. The language does not impose one method
name because different resources have different lifecycle operations and
`Close` is already meaningful to many APIs.

The order of termination among otherwise unrelated unreachable instances is
unspecified. A runtime failure in `Class_Terminate` follows the ordinary
controlled-error rules and must not crash the process or prevent the runtime
from continuing orderly cleanup. Resurrection is forbidden; access to another
instance that is concurrently terminating follows the controlled runtime-error
contract.

Globals and module-level variables are roots for program lifetime. An
initialized `Static` local is also a program-lifetime root even though its name
is visible only in its declaring procedure. A static local is initialized once
when execution first reaches its declaration and retains its value between
calls.

During orderly shutdown, UBE:

1. stops accepting new callbacks and ordinary thread creation;
2. completes registered language/runtime shutdown bookkeeping;
3. releases initialized static locals in reverse initialization order;
4. releases module and global variables in reverse module initialization
   order;
5. performs a final managed-memory collection;
6. tears down the program's linked support code and returns the program exit
   code.

Orderly shutdown begins after the thread and event-source liveness rule in
section 5 reaches zero. Cleanup cannot be guaranteed after forced process
termination, power loss, or host failure.

### 4.2 External resources are code-owned

Garbage collection manages UBE memory. It does not track or automatically
close arbitrary resources created by user code. Files, sockets, native
windows, database connections, synchronization objects, child processes,
foreign handles, and user-defined resources remain the responsibility of the
code that creates or acquires them.

Such code must close or dispose of each resource on every relevant success,
error, cancellation, and early-exit path. UBE 1.0 adds no `Try`/`Finally`,
`Using`, `Defer`, or automatic resource registry. Cleanup remains an explicit
call written by the programmer. Programs must never depend on
garbage-collection timing to flush data, release a lock, close a file, or
perform another externally visible operation.

When a process ends, the host operating system reclaims its remaining
process-owned handles. That host behavior does not imply that UBE tracked or
gracefully closed them, and it does not guarantee that language/library
buffers were flushed or that user cleanup code ran. Code requiring either must
perform the explicit operation before termination.

The compiler is held to the same rule. It must explicitly release input and
output files, temporary artifacts, process and pipe handles, locks, target-tool
resources, and every other external resource it acquires. Compiler failure
paths require the same cleanup discipline as successful compilation.

### 4.3 Object assignment and construction

Object, class, form, and control reference assignment requires `Set`, retaining
the visible distinction between value copying and shared identity:

```ube
B = A                  ' Value assignment and copy.
Set WindowB = WindowA  ' Reference assignment; both identify one object.
Set WindowA = Nothing
```

This requirement also applies to object-returning Function results and other
assignments of `Nothing` to a reference destination. Plain `=` cannot assign
an object reference.

`Dim A As New MyClass` constructs the object immediately when execution reaches
that declaration. `Class_Initialize` therefore runs at a predictable source
location. A normal local constructs on each execution of its declaration; a
module/global constructs during orderly module initialization; and a `Static`
local constructs the first time execution reaches its declaration and retains
the value between calls.

If construction fails, the destination remains `Nothing` and the current
thread's `Err` records the failure. `As New` does not enable VB6-style hidden
auto-recreation: after `Set A = Nothing`, `A` remains `Nothing` until source
code explicitly assigns another object.

Class construction is parameterless in UBE 1.0. `New ClassName` takes no
argument list, and `Private Sub Class_Initialize()` is the sole automatic
initialization callback. It runs exactly once for a successfully allocated
instance and cannot be called directly. Classes that require input expose an
ordinary initialization Sub called after creation or a factory Function that
creates, initializes, and returns the instance. Constructor overloading and
parameterized `New` are reserved beyond UBE 1.0.

Form and control modules also declare source-level types. Their `UBE_Name` is
the module/type identity, and `Me` denotes the current instance inside a class,
form, or control. A bare form-module name in value context denotes its
compiler-maintained project default-instance slot; a control type has no such
project default merely because it is declared.

`New FormType` creates a distinct identity and runs `Class_Initialize`, but does
not create a window or load/show the form. First `Load` of that identity creates
its framework/UI resources and designer controls, invokes `Form_Load`, and
registers an active event source. Repeated Load is idempotent. Showing is a
separate framework-library operation. Control identities come from a containing
designer or an explicit framework operation; independent `New` is legal only
for a control creation mode that supports it, and Load requires a valid parent
context.

Loading is synchronous even when platform UI work is transparently dispatched.
Failure records `Err` and rolls back every partial resource. Load/Unload require
a statically known form/control operand; `Load Nothing` is an error and
`Unload Nothing` is a no-op. Accepted unload clears a matching default slot and
every ordinary or `WithEvents` alias, while cancellation preserves all state.
An unloaded identity cannot be revived.

A standard module may optionally declare parameterless private lifecycle
procedures:

```ube
Private Sub Module_Initialize()
End Sub

Private Sub Module_Terminate()
End Sub
```

They cannot be called directly. Every executable module initializes in project
manifest order before `Main`, including the module that declares `Main`.
Libraries perform the same ordered initialization through their linked startup
path before permitting the first exported call. Successfully initialized
modules terminate exactly once in reverse order; `Module_Terminate` runs before
that module's globals are released. A module whose initialization did not
complete is not treated as initialized.

One `.UBE` manifest is one compilation package. Ordered repeatable `Reference`
entries name local source Library manifests; direct referenced packages expose
Public declarations while Friend remains package-local. Dependencies
initialize before dependents. An executable retains `Startup = "Main"` and may
add `StartupForm = "FormName"`. After dependencies and all executable modules
initialize, generated startup constructs and loads that form's default identity
and only then invokes source-level Main. Reference order is deterministic build
input but never an ambiguity tie-breaker.

Initialization failure follows a controlled startup-failure path and
terminates already initialized modules in reverse order. Termination failure
does not prevent remaining module cleanup. Forced host termination cannot
guarantee either hook. These operations are emitted and linked into the native
program or library; no separate UBE runtime is started.

UBE 1.0 has no implementation inheritance between user-defined classes.
`Implements` supplies interface polymorphism: an interface-typed reference may
identify any class that supplies the complete interface contract. Classes
reuse implementation through contained objects and modules rather than base
classes, constructor chains, or overridable inherited members. Forms and
controls follow their dedicated framework lifecycle rather than user-class
inheritance.

UBE declares a native interface as a named contract:

```ube
Public Interface IWriter
    Sub Write(ByVal Text As String)
    Function IsReady() As Boolean
    Property Get Name() As String
End Interface
```

An interface contains declarations only: Subs, Functions, Properties, and
Events, but no storage, executable body, constructor, or module state. It
cannot be created with `New`. An interface-typed variable is a strong object
reference, is assigned with `Set`, and may identify any implementing class.

Property accessors with one name form one logical property. The approved
VB-style forms are:

```ube
Public Property Get Name() As String
    Name = StoredName
End Property

Public Property Let Name(ByVal Value As String)
    StoredName = Value
End Property

Public Property Get Child() As Child
    Set Child = StoredChild
End Property

Public Property Set Child(ByVal Value As Child)
    Set StoredChild = Value
End Property
```

Get declares and returns the property type. Let assigns a value type, while Set
assigns an object-compatible reference. `Variant` may expose both Let and Set;
no other property type may. Read-only and write-only properties are legal.

For an indexed property, every accessor has the same ordered index parameters,
including names, types, passing modes, optionality, and defaults. A Let or Set
accessor adds one required final `ByVal` value parameter of the property type;
it cannot be optional or `ParamArray`. All accessors also agree on visibility,
`Static`, and `Default`. Duplicate or mismatched accessors are compile-time
errors.

A class or interface may have at most one Default property. It must have at
least one index parameter and supports collection-style shorthand such as
`Customers(5)`. UBE never invokes a parameterless default property implicitly,
and `Set A = B` always means reference assignment rather than hidden default-
property evaluation.

A class module declares `Implements IWriter` and supplies ordinary members with
the exact required names and compatible signatures. One member may satisfy
identical requirements from multiple interfaces. Conflicting same-name
requirements are a compile-time error in UBE 1.0. Classic VB6 interface-style
class modules are accepted through compatibility import and mapped to this
contract model.

Managed memory is frozen in [`managed-memory.md`](managed-memory.md), and
exported ownership/layout is frozen in [`foreign-abi.md`](foreign-abi.md).

### 4.4 Calls and parameters

UBE preserves the classic VB call surfaces while making association and
evaluation deterministic. Expression calls use parentheses; `Call` statements
use parentheses when arguments are supplied; statements without `Call` use the
unparenthesized form. Either statement form may intentionally discard a
Function result. `CallNew` remains the separately restricted Sub-only form.

Arguments may be positional, omitted, or named as
`ParameterName := expression`. Positional arguments precede named arguments;
named arguments bind case-insensitively in any order and cannot name a
`ParamArray`. Every supplied expression is evaluated exactly once from left to
right in source order before the callee begins, regardless of parameter order.

Direct `ByRef` requires writable storage of exactly the declared parameter
type. An extra pair of parentheses around an individual actual requests the
classic VB value-temporary behavior: evaluate and convert once, pass the fresh
temporary ByRef, and discard writes afterward. It cannot bypass safety or ABI
restrictions.

Required parameters precede parameters with compile-time Optional defaults.
Omitted Optional ByRef parameters receive invocation-local writable
temporaries. A final `ParamArray Values() As Variant` receives a fresh
one-dimensional Variant array containing remaining positional arguments in
source order. It cannot combine with Optional, ByVal, or ByRef. Detailed rules
and diagnostics are normative in `language-spec.md` section 5.

### 4.5 Names, overloading, and raw callbacks

UBE 1.0 follows the classic VB declaration model and does not add user-defined
procedure overloading. Same-name Get/Let/Set declarations form one logical
property; otherwise declarations in one region must be unique after Unicode
simple folding. Lookup proceeds deterministically from procedure locals, to
the current result in assignment context, current members, public/friend
standard-module members, and explicit references. Multiple matches at the
selected level require qualification and are never resolved by file order.

`AddressOf` remains a deliberately narrow compatibility feature rather than a
first-class delegate system:

```ube
Call NativeRegister(AddressOf WindowProcedure)
```

The target is a statically known ABI-safe Sub or Function in a standard module.
The expression is legal only as an actual argument for a compatible pointer-
sized parameter of an external `Declare`; it cannot be stored, invoked through
UBE syntax, or used to capture instance/local state. The value passed is the
address of a compiler-generated native entry thunk, not an unchecked body
address. That thunk performs the required thread registration, ABI marshalling,
per-thread `Err`, GC transition, and controlled failure behavior.

Raw callback registration is an external resource owned by user code. The
program must unregister it before orderly shutdown or library unload; dropping
another native value does not unregister it. This narrow raw bridge is distinct
from the generated pointer-plus-context callback records used by UBE's
versioned exported-library ABI.

### 4.6 Modifiers, visibility, and static procedures

UBE retains VB's context-sensitive omitted visibility: ordinary implemented
procedures are Public, while `Dim` fields and module-level Const declarations
are Private. Type/Enum/Interface and standard-module external declarations are
Public where legal; interface members are inherently Public. Lifecycle and
`WithEvents` handlers remain Private. `Friend` is package-only, `Global` is the
legacy Public spelling only for a standard-module variable, and
`Option Private Module` prevents cross-package visibility and Export.

Static locals initialize once when first reached and are shared by recursive
calls and threads. A Static procedure/property accessor applies that storage
behavior to its ordinary locals without turning an instance member into a
shared member or removing `Me`. Parameters, results, temporaries, and control
state remain invocation-local.

Modifiers use one canonical grammar order. Inline/ForceInline apply only to
implemented Subs and Functions. Intrinsic is a bodyless standard-module Sub or
Function. Export is explicitly `Public Export [Inline]` on a Library standard-
module Sub/Function and never Static or ForceInline. Default applies only to
the one approved indexed class/interface property. Invalid, repeated, or
ineffective combinations are diagnosed rather than ignored.

## 5. Threads and `CallNew`

### 5.1 Creation

`CallNew` starts an existing `Sub` on a new UBE thread and evaluates to a
`LongLong` UBE thread identifier. Its exact source form is:

```ube
Dim Worker As LongLong
Worker = CallNew ProcessItems(InputPath, 10)

CallNew Background.Logger(LogPath)  ' The returned ID may be ignored.
CallNew IdleWorker()
```

The keyword is followed by a directly visible, statically resolved `Sub` name
and its ordinary parenthesized argument list. A local-module Sub, an accessible
member or imported/public-module Sub, or a qualified name resolved by ordinary
scope rules is eligible. The result may be used as an expression or ignored as
a standalone statement. Parentheses remain required for a target with no
arguments.

A `Function`, variable-held callback, computed address, runtime name, or other
dynamically selected target is a compile-time error in UBE 1.0. Users may write
a wrapper Sub when a Function's return value is intentionally discarded.

The identifier is an ordinary nonnegative `LongLong`, so it can be stored,
compared, logged, placed in custom values and arrays, or passed through an API.
`0` is the invalid value. UBE assigns identifiers uniquely for the lifetime of
the process and never recycles one in a way that could make a stale ID identify
a newer thread. A stale or unknown ID supplied to a UBE thread operation
produces a controlled runtime error.

An UBE thread identifier is portable program identity, not necessarily the
host operating system's native thread ID or handle. Platform-library calls
provide native identity explicitly when an OS API requires it; portable code
must not assume the two values are equal.

Failure to create a thread produces `0` and records the failure in the calling
thread's `Err`.

### 5.2 Argument capture

Arguments are evaluated once on the calling thread, from left to right, before
the new thread becomes observable. Every `CallNew` target parameter must be
`ByVal` in UBE 1.0; a target requiring any ordinary `ByRef` parameter is a
compile-time error. No reference to caller-owned stack storage may escape into
the new thread.

Scalar arguments are copied. Strings, arrays, and custom datatypes cross the
thread boundary as independent value snapshots under their ordinary copy
rules. Object and class arguments copy their strong reference instead, so the
calling and new threads intentionally share the same object identity.

Shared-object access must remain memory-safe even when user synchronization is
missing: a data race may make the logical ordering and result unpredictable,
but it must never produce memory corruption, a use-after-free, an uncontrolled
crash, or LLVM undefined behavior. The synchronization model defines how code
obtains deterministic ordering.

Threads do not narrow ordinary lexical visibility. Every UBE thread may access
the globals, module variables, initialized static variables, public fields,
shared objects, forms, and controls that the executing source could normally
name. A local in another active procedure remains inaccessible because it is
outside lexical scope, not because it belongs to another thread.

UBE source imposes no owner-thread restriction on forms or controls. When a
target platform requires a UI operation to execute on a particular dispatch
thread, the runtime transparently routes that member operation. A property get
or Function waits for and returns its result; a property set or Sub retains
ordinary completed-call semantics. Native callbacks execute through the
platform dispatcher, but every ordinarily visible form/control remains usable
from all UBE threads.

Transparent dispatch must never expose stale handles or create undefined
behavior. The runtime must detect dispatch-wait cycles where practical and
report a controlled runtime error rather than knowingly enter a routing
deadlock. User-created lock-order deadlocks remain program logic and should be
diagnosable where possible.

UBE 1.0 provides a structured object monitor:

```ube
SyncLock Service
    Service.Counter = Service.Counter + 1
End SyncLock
```

The operand must evaluate to an object or class reference. Each object identity
has an internal synchronization identity; value types cannot serve as monitor
identities. The monitor is reentrant for its owning thread. Other threads wait
until the owning thread leaves the outermost matching block.

The compiler releases the monitor on every control-flow edge out of the block,
including ordinary completion, `Exit`, procedure return, handled runtime error,
and cooperative cancellation. `SyncLock Nothing` is a controlled runtime
error. Successful release and subsequent acquisition establish full memory
visibility between the participating threads.

An object cannot be reclaimed while a thread owns or is waiting for its
monitor. Accepted unload prevents new entries and final reclamation waits for
existing monitor users under the ordinary active-call drain rule. Lock-order
deadlock remains a program-logic error, although an implementation may provide
diagnostics. `SyncLock` is distinct from classic file-record `Lock`.

Ordinary scalar and object-reference reads and writes are individually
memory-safe and never torn, but a compound expression is not automatically an
atomic transaction. Competing unsynchronized updates such as
`Counter = Counter + 1` may therefore lose a logical update even though they
cannot corrupt runtime memory.

The standard library provides `AtomicBoolean`, `AtomicLong`, `AtomicLongLong`,
and `AtomicObject` for single shared values. Their applicable operations are
`Load`, `Store`, `Exchange`, `CompareExchange`, `Increment`, `Decrement`, and
numeric `Add`. Every UBE 1.0 atomic operation is sequentially consistent: UBE
chooses the strongest straightforward ordering and exposes no relaxed,
acquire, or release selector. Advanced ordering may be added in a later
language/library version without weakening existing calls.

Atomic wrappers protect one value and one atomic operation. Code uses
`SyncLock` when several fields or operations must be observed as one protected
unit. Custom-datatype and array operations are not atomic as a whole.

The portable UBE 1.0 standard library also provides these synchronization
classes:

- `ThreadEvent` lets one thread signal waiting threads without conflicting
  with the language's `Event` keyword;
- `Semaphore` limits the number of concurrent entrants to a resource; and
- `MessageQueue` transfers `Variant` messages safely between threads in
  first-in, first-out order.

Waiting operations use signed `LongLong` milliseconds. `-1` means wait
indefinitely; zero performs a nonblocking check; other negative values are
invalid. A wait returns `Long` value `1` when satisfied and `0` on timeout.
Invalid arguments or an unloaded/destroyed synchronization object return `0`
and record `Err`, allowing timeout to remain a normal non-error result.

Manual `Mutex`, condition variables, and statically typed channels are reserved
beyond UBE 1.0. `SyncLock` supplies the safer structured locking behavior;
`ThreadEvent` covers common notification; and a typed channel requires a future
generic-type contract. `MessageQueue` supplies practical message passing
without weakening the language's static variables. Exact constructors and
methods are standard-library design and do not affect the core grammar.

### 5.3 Cancellation and waiting

UBE provides cooperative cancellation, not unsafe forced thread termination.
The portable core library supplies:

```ube
Function CurrentThreadId() As LongLong
Function ThreadIsAlive(ByVal Id As LongLong) As Boolean
Function ThreadWait(ByVal Id As LongLong, _
                    Optional ByVal TimeoutMilliseconds As LongLong = -1) As Long
Function ThreadRequestStop(ByVal Id As LongLong) As Long
Function ThreadStopRequested() As Boolean
Sub ThreadYield()
```

`ThreadRequestStop` records a request. The target thread observes it explicitly
and returns through ordinary control flow. No operation may asynchronously
tear down a thread while it holds a lock or is mutating managed state.

A worker ends when its target Sub returns or executes `Exit Sub`; UBE 1.0 adds
no `StopThread`, `KillThread`, or `Exit Thread` statement. A stop request wakes
the target when it is blocked in `ThreadEvent`, `Semaphore`, `MessageQueue`, or
`ThreadWait`. An interrupted wait returns `0` without recording `Err`; the
worker distinguishes cancellation from timeout by calling
`ThreadStopRequested()`. Returning then runs ordinary scope cleanup on every
control-flow edge.

`ThreadWait` returns `1` when the target has finished and `0` on timeout or
cancellation. A valid already-completed target returns `1` immediately;
waiting on the current thread returns `0` and records `Err`. Multiple threads
may wait for the same target.

`ThreadRequestStop` returns `1` when the request is recorded, including when a
request was already pending. A valid completed thread returns `0` without
error. `ThreadIsAlive` similarly returns `False` without error for a completed
thread. An identifier that was never issued produces the operation's neutral
result and records `Err`.

`ThreadYield` only offers another runnable thread an execution opportunity;
program correctness cannot depend on whether a particular thread runs next.
The runtime retains enough compact metadata for completed identifiers to
distinguish completion from a never-issued ID without retaining full native
thread resources.

### 5.4 Program lifetime and callback-event sources

UBE 1.0 binds object events through VB-style `WithEvents` fields:

```ube
Private WithEvents Worker As WorkerClass

Private Sub Worker_Progress(ByVal Percent As Long)
    Print Percent
End Sub
```

`WithEvents` is available only for a scalar field of a module, class, form, or
control. The declared type must statically declare events through a class,
interface, form, or control contract; the generic `Object` type is not enough.
It is not available for locals, parameters, arrays, or custom-datatype fields.
One declaration names one event field.

The handler for event `EventName` on field `FieldName` is the optional
`Private Sub FieldName_EventName(...)`. Its parameters must match the event
declaration exactly. A same-named declaration of the wrong procedure kind or
signature is a compile-time error. The handler remains an ordinary private Sub
and may also be called directly by code in its scope.

Completing `Set FieldName = Instance` removes the subscriptions associated with
the old field value and installs the matching subscriptions on `Instance`.
Completing `Set FieldName = Nothing` removes them. The old object is not
unloaded or destroyed merely by reassignment. Following classic VB,
`WithEvents` cannot combine with `As New` or a declaration initializer; source
uses an explicit `Set` at the desired initialization point. Events raised by
`Class_Initialize` therefore occur before that explicit connection.

Each successful connection takes its subscription order from the completing
`Set` operation. Two `WithEvents` fields that identify one object create two
independent subscriptions. Connection changes are memory-safe across threads.
Each event invocation uses the subscriptions present when it begins, subject
to the removal-before-turn and addition-on-next-invocation rules below.

UBE 1.0 does not provide local `WithEvents`, `AddHandler`, or `RemoveHandler`.
Dynamic subscription is reserved for a later language version.

`RaiseEvent` is synchronous and reentrant. Handlers execute in subscription
order on the thread that raised the event, and all applicable handlers finish
before `RaiseEvent` returns. A handler removed before its turn is skipped; a
handler added during one dispatch first participates in the next dispatch.

Raising the same event, directly or indirectly, from one of its handlers starts
a nested complete dispatch immediately. For example, resizing an object inside
its `Resize` handler may raise `Resize` again normally. UBE does not silently
suppress, merge, or defer recursive event delivery. Each nested invocation
uses the subscriptions in effect when that invocation begins.

Native form/control callbacks enter through the runtime's platform dispatcher
and otherwise follow the same rules. Every handler uses the executing thread's
independent `Err` state. A handled runtime error follows ordinary control flow;
an exhausted recursion/stack limit is reported as a controlled runtime error
and unwinds safely rather than becoming a native stack overflow or process
crash. Accepted form/control unloading prevents new dispatches while already
active handlers drain under the unload lifecycle.

The runtime keeps a process alive while either of these is true:

```text
live UBE thread count > 0
OR active callback-event-source count > 0
```

When `Main` returns:

- remaining worker threads continue, even if their IDs were ignored;
- if active event-source objects exist, the startup thread enters an idle
  message-dispatch loop;
- the process exits normally only after the final UBE thread has returned and
  the final event source has been unloaded or closed.

An ordinary object does not keep the process alive merely because its type can
declare events. A loaded or started form, timer, socket listener, file watcher,
or similar library object registers itself as an active event source. The
registration retains the object until it is closed or unloaded.

Event-source registration and the message pump are portable linked-library
services over a target-specific substrate; they are not hard-coded object names
inside the compiler and require no separately installed execution environment.

### 5.5 Frozen threading contract

The formal data-race, happens-before, synchronization-class, cancellation,
error, callback, limit, cleanup, and shutdown contracts are frozen in
[`threading.md`](threading.md).

## 6. Portability and targets

UBE source semantics are OS-independent. A conforming compiler distinguishes:

- the **host**, on which the compiler runs;
- the **target**, for which it emits code;
- the target triple, data layout, ABI, object format, linker, platform
  substrate, and compatible library artifacts.

Target-independent compiler phases must not assume Windows drive letters, path
separators, PE/COFF, MinGW, a Windows message queue, or a particular native
thread API. Portable paths, Unicode text, integer widths, overflow, clocks,
newlines, files, process exit, threading, and error behavior require explicit
UBE contracts.

Windows is the initial supported development host and target. Full portability
may be claimed only after the same normative conformance suite passes on at
least one additional OS target and target-specific behavior is documented.
Using LLVM is necessary for this goal but is not sufficient without portable
linked-support and library boundaries.

## 7. Promotion status

The owner-level decisions recorded in the preceding sections are approved.
The focused conversion, managed-memory, threading, and foreign-ABI contracts
remain normative for those subjects. The final cross-specification audit has
closed the language-wide syntax and semantic gaps. Questions that necessarily
conflict with approved architecture or lack a portable VB precedent are kept
in [`deferred-questions.md`](deferred-questions.md) and are outside the closed
core source grammar until resolved.

Promotion freezes the target; it does not claim implementation. Compiler v3
must still derive positive, negative, boundary, recovery, and runtime
conformance coverage from every applicable rule. Public documentation must
continue to distinguish specified behavior from implemented behavior until the
compiler and linked libraries pass that suite.
