# Form and control source-semantics audit

**Scope:** UBE 1.0 / Compiler v3 candidate definition  
**Status:** compatible rules, startup ordering, and default-instance lifetime
promoted  
**Method:** use classic VB6 behavior where it does not contradict an approved
UBE rule. Questions created by a real conflict are collected at the end for
later resolution.

## Sources checked

- `language-spec.md`
- `v3-language-definition.md`
- `managed-memory.md`
- `threading.md`
- `project-files.md`
- `grammar/ube.ebnf`
- `project-docs/architecture.md`

## Compatible VB-derived model

The following model fits the approved architecture and can be incorporated
without a new owner decision.

### Module identity and type identity

The `Attribute UBE_Name` of a `.frm` or `.ctl` file is its project-unique
source-module name and its declared form or control type name. The extension
and native header kind must agree as already specified.

In a type context, that name denotes the type:

```ube
Dim Window As CustomerForm
Set Window = New CustomerForm
```

Inside an instance's own source module, `Me` denotes that instance. It is a
reference, not a copy and not the project's default-instance slot.

Name lookup should retain the normal VB distinction between type contexts and
value contexts. A declaration that would make a form/control name ambiguous
after case folding is a compile-time duplicate/ambiguity error; the compiler
must not guess from load state.

### Form instances

`New FormType` creates a distinct form identity. It runs the ordinary
parameterless `Class_Initialize` callback exactly once, but it does not by
itself create the platform window or register an active event source.

`Load FormValue` loads that particular identity. Loading an already loaded
identity succeeds without loading it a second time. The first successful load:

1. creates the form's platform-neutral framework state and target UI resources;
2. makes its designer-created controls available;
3. invokes the parameterless `Form_Load` event; and
4. registers the loaded form as an active callback event source.

As in VB6, loading and showing are separate operations. `Load` does not imply
that the form becomes visible. A library-defined `Show` operation may load an
unloaded form before making it visible; its exact UI API belongs to the
standard/framework library rather than the core grammar.

If construction or loading fails, the operation records `Err`, leaves no
partly loaded UI identity observable, and unwinds every resource acquired by
the failed attempt. A previously existing but unloaded form reference remains
a valid unloaded identity unless its explicit unload lifecycle has already
invalidated that identity under the approved rules.

### Default form instance

For VB source compatibility, each form type has one compiler-maintained
project default-instance slot. In a value context, a bare form-module name
refers to this slot:

```ube
Load CustomerForm
CustomerForm.Show
Unload CustomerForm
```

This slot is separate from every identity created by `New CustomerForm`.
Loading or unloading an explicitly created instance does not change the
default slot unless it is in fact that same identity.

The first bare value reference creates the slot's identity on demand and uses
classic VB-compatible first-load behavior. Accepted unload then records an
explicit user decision: the slot stays `Nothing` and later bare references do
not recreate it. `Load CustomerForm` is the explicit operation that begins a
new default-instance lifetime.

The slot is a precise managed root only while it contains an identity. It is
not a raw global pointer and does not bypass garbage collection. Accepted
unload clears the slot together with every other UBE alias to that identity,
as required by the approved identity-wide unload rule.

The unresolved question is whether a later bare reference may silently create
a new identity after the slot has been cleared. That behavior is deliberately
not selected in this report; see Question 1.

### Control instances

A `.ctl` module declares a user-control type. It does not receive a project
default instance merely because its module exists. Normal control identities
are created by a containing form's designer description or explicitly by a
framework operation that returns the declared control type. `New ControlType`
may create an independent identity when the control's declared creation mode
permits it; it does not attach the control to a visual parent or load native UI
resources by itself.

Within a control module, `Me` denotes the current control identity. A
designer-created control field on a form is an ordinary strongly typed object
reference, so `Set`, garbage collection, `WithEvents`, cross-thread access, and
unload safety use the already-approved object rules.

`Load ControlValue` loads that specific control through its containing
framework context. A load requiring a parent fails in the controlled runtime-
error manner when no valid parent/context has been assigned. First successful
load invokes the parameterless `Control_Initialize` callback before admitting
native callbacks. The existing `Control_Unload(ByRef Cancel As Integer)` rule
governs explicit unloading.

The classic VB6 dynamic control-array form of `Load` is not implicitly
specified by the general `Load expression` grammar. It should remain outside
UBE 1.0 unless control arrays receive a separate, complete contract.

### `Load`, `Unload`, and aliases

The operand of `Load` or `Unload` must statically be a form or control
reference. `Unload Nothing` remains the approved no-op. Applying either
statement to an ordinary class, interface, scalar, custom datatype, or generic
`Object` whose concrete type cannot be proven is a compile-time error; no
late-bound guess is made.

`Load` applied to a form/control reference whose value is `Nothing` records a
controlled runtime error and changes nothing. The special bare form-module
operand is resolved through its default-instance slot under the separately
specified default-instance rule; it is not treated as an ordinary `Nothing`
variable.

`Set A = Nothing` releases only `A`. It neither unloads the identity nor clears
other aliases. `Unload A`, once its cancellable event accepts, begins the
approved identity-wide lifecycle: native handles are released, new entries
are rejected, already admitted procedures drain, `Class_Terminate` runs once,
and all UBE aliases—including `WithEvents` fields and a matching default slot—
become `Nothing`.

If `Form_Unload` or `Control_Unload` cancels, no alias, subscription, loaded
state, active-event-source registration, UI resource, or default slot changes.

An unloaded identity cannot be revived by applying `Load` to an old alias:
accepted unload invalidates that identity, and the approved alias-clearing rule
means ordinary UBE code no longer possesses such an alias. Foreign stale
handles receive the already-specified controlled unloaded-object result.

### Events and `WithEvents`

Framework lifecycle procedures such as `Form_Load`, `Form_Unload`,
`Control_Initialize`, and `Control_Unload` are handlers belonging to the
current instance. They are not subscriptions created through `WithEvents`.

A separate `WithEvents` field may refer to either a default or explicitly
created form/control identity. Assignment connects its statically named
handlers exactly as already approved. Accepted unload disconnects those
subscriptions before new callbacks can enter and ultimately clears the field
to `Nothing`; cancellation leaves them connected.

Form/control events remain synchronous and recursively dispatchable. A native
callback is routed onto the required target dispatcher when necessary, while
the source-level handler obeys the existing shared-visibility, per-thread
`Err`, reentrancy, and active-call-drain rules.

### Startup form

A configured startup form must designate a form-module name, not an arbitrary
expression or an explicitly constructed instance. It uses that form's default-
instance slot and the same ordinary construction, load, event-source, unload,
and garbage-collection rules as source-written operations.

Startup-form support remains compiler-generated work on the sole `Main`
startup path. It never creates a second language-level entry point and does
not weaken the requirement for exactly one valid source-level `Main` in an
executable project.

The exact ordering of generated startup-form loading relative to the first
statement of source-level `Main` is not presently fixed consistently enough to
infer. See Question 2.

## Architecture reconciliation

### No separate runtime

Every behavior above is compiler-generated code plus linked program/framework
support. References to framework state or dispatch do not imply a separately
installed UBE runtime, process, VM, or universal object service.

### No hidden `As New` reconstruction

Ordinary `As New` variables remain immediate constructions and never recreate
themselves after `Set variable = Nothing`. Explicit instances created with
`New` likewise never reconstruct themselves. A form default-instance slot has
one narrow compatibility rule: its first bare value reference may construct
it. That permission is consumed by accepted unload and cannot become hidden
post-unload reconstruction.

### Garbage collection and unloading

Loaded forms, loaded controls, admitted callbacks, and active event-source
registrations are precise collector roots. Merely declaring a form/control
type is not a root. An allocated but never loaded explicit instance is managed
like an ordinary object until loaded.

Garbage collection may reclaim an unreachable, never-loaded or ordinarily
released instance, with `Class_Terminate` as specified. It may not substitute
for accepted `Unload` while a form/control remains loaded, because loaded
framework registration keeps the identity reachable and external UI cleanup
is lifecycle work rather than arbitrary GC resource cleanup.

### Threads

Construction and loading invoked from any UBE thread are source-synchronous.
Target platforms may transparently dispatch native UI portions, but the source
operation does not complete until its required initialization/load callback
has completed or failed. The compiler/framework must apply the existing direct
dispatch-wait-cycle detection and must not hold internal collector or
dispatcher locks while invoking `Class_Initialize`, `Form_Load`,
`Control_Initialize`, unload handlers, or other user code.

## Resolved owner decisions

### Default-instance creation and post-unload behavior

The first bare form reference creates the default identity as classic VB does.
After accepted unload, the user has explicitly decided that identity should be
unloaded, so a later bare reference does not create another one. A new default
lifetime requires explicit `Load FormName`.

### Question 2: startup-form ordering relative to `Main`

The specification requires exactly one source-level `Main`, while architecture
text says startup-form loading is generated "on the `Main` startup path." It
does not state whether generated loading happens before `Main`, at a generated
call site inside a wrapper around `Main`, or after `Main` returns. Loading after
`Main` returns would surprise code that expects the startup form during `Main`;
loading before `Main` gives `Main` access to the fully loaded form and preserves
one language-level entry point.

Recommended resolution: after module initialization, generated startup code
constructs and loads the configured default form, then invokes source-level
`Main`; when `Main` returns, the existing live-thread/event-source rule decides
whether the program idles or shuts down.

## Required conformance cases after resolution

- form/control header kind and `UBE_Name` identity;
- type-context versus default-instance value-context lookup;
- two `New FormType` expressions produce distinct identities;
- `New` runs `Class_Initialize` without implicitly showing a window;
- first `Load`, repeated `Load`, failed load rollback, and `Load Nothing`;
- `Form_Load`/`Control_Initialize` event ordering and recursive events;
- cancelled unload preserves every alias and subscription;
- accepted unload clears ordinary, default-slot, and `WithEvents` aliases;
- active calls on several threads drain without stale UI access;
- explicit instances never affect the default slot accidentally;
- controls without valid parents fail safely;
- GC roots for loaded versus merely allocated identities;
- startup form ordering relative to modules and `Main`; and
- the selected post-unload default-instance recreation rule.
