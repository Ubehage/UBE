# UBE 1.0 language-closure audit

**Status:** core language audit closed; implementation evidence remains active  
**Purpose:** preserve the decisions and proof work used to freeze the Compiler
v3 language specification and EBNF

This is not a public language specification. It records gaps found while
cross-checking `language-spec.md`, the focused normative contracts, and
`grammar/ube.ebnf`. Closed semantics have moved into the normative sources;
remaining checklist work supplies implementation evidence or resolves choices
explicitly isolated in `deferred-questions.md`.

## Release-proof rule

The core definition is frozen. Compiler v3 may claim complete UBE 1.0
conformance only when:

- every item in **Owner decisions** is approved or explicitly reserved for a
  later language version;
- every item in **Specification reconciliation** has matching semantics and
  grammar;
- the grammar accepts every promised UBE 1.0 source form and does not accept a
  form forbidden by the specification;
- positive, negative, ambiguity, and recovery fixtures cover each production;
  and
- the grammar validator and the semantic cross-reference audit pass.

## Owner decisions

### 1. Event binding and subscription

**State:** approved and promoted.

The audit found that `Event`, `RaiseEvent`, dispatch, and unload behavior lacked
the syntax that connects an event-producing object to its handlers. The owner
approved the following VB-style `WithEvents` contract to close that gap.

Approved contract:

- scalar module/class/form/control fields may be declared `WithEvents` when
  their declared class, interface, form, or control type exposes events;
- `<field>_<event>` names the statically bound handler;
- `Set` subscribes the new identity and unsubscribes the previous identity;
- `Set field = Nothing` unsubscribes;
- signatures must match, while an absent handler is allowed;
- `WithEvents` cannot combine with `As New` or a declaration initializer; and
- local `WithEvents` and dynamic `AddHandler` are reserved beyond UBE 1.0.

The rule is now incorporated into `language-spec.md`,
`v3-language-definition.md`, `threading.md`, and `grammar/ube.ebnf`.

### 2. Property contract

**State:** approved and promoted.

The approved VB-style property contract defines:

- same-name Get/Let/Set grouping;
- Get result, Let value, and Set reference roles, with dual Let/Set only for
  `Variant`;
- legal read-only and write-only properties;
- exact matching of indexed parameters plus the setter's final `ByVal` value;
- one indexed Default property per class or interface; and
- collection-style default invocation without implicit parameterless coercion
  or interference with `Set` identity assignment.

The contract is incorporated into `language-spec.md`,
`v3-language-definition.md`, and `grammar/ube.ebnf`.

### 3. Calls and parameters

**State:** VB-derived contract approved by policy and promoted.

The promoted contract defines `name := expression`, positional/named
association, left-to-right evaluate-once behavior, exact direct `ByRef`, VB
parenthesized temporaries, explicit Optional defaults, and a final
`ParamArray Values() As Variant`. `CallNew` retains its stricter approved
capture rules. The complete audit rationale remains in
`audits/calls-parameters.md`.

### 4. Name resolution and overloads

**State:** VB-derived contract approved by policy and promoted.

UBE 1.0 has no user-defined procedure overloading. Declaration regions,
Unicode-folded identity, local/member/module/reference lookup order,
qualification, and ambiguity diagnostics are now defined. Property accessor
selection is not general overloading. Detailed rationale remains in
`audits/names-callbacks.md`.

### 5. Callback procedure values

**State:** classic VB bridge approved by policy and promoted.

`AddressOf` is restricted to a direct foreign-call argument and a statically
known ABI-safe standard-module procedure. It is not a storable first-class UBE
value. The compiler supplies a native entry thunk with thread, `Err`, GC, and
controlled-failure transitions; user code owns native unregistration.

### 6. Forms and controls as source-level types

**State:** compatible VB rules promoted; one architecture conflict saved below.

Module/type identity, `Me`, distinct explicit instances, first/repeated Load,
Form_Load, control containment, rollback, aliases, GC roots, event binding,
`StartupForm`, and startup-before-Main ordering are defined.
`audits/forms-controls.md` preserves the full analysis. One conflicting choice
remains intentionally unresolved:

1. **Default-form recreation:** classic VB silently creates a fresh default
   identity when a bare form name is used after unload. UBE's approved object
   model forbids hidden `As New` reconstruction. Choose either VB-compatible
   on-demand recreation or require explicit `Load FormName` after the slot is
   empty. The audit recommends explicit recreation.

The compatible manifest rule is now `Startup = "Main"` plus optional
`StartupForm = "FormName"`; dependencies and modules initialize first, then the
startup form loads, then source `Main` executes.

### 7. Operator typing and exact scalar contracts

**State:** closed and promoted.

Promotion/result types, exact Decimal and Date contracts, Boolean and bitwise
behavior, concatenation, comparison, `Like`, pointer-sized arithmetic,
Variant/Null/Empty dispatch, and constant folding are now normative in
`language-spec.md`. Unsupported VB.NET integer suffixes were removed. UBE
requires an explicit conversion for incompatible signed/unsigned pointer-sized
mixtures and retains semantic equality for comparable custom datatypes.

### 8. Compiled library references

**State:** source-project references promoted; packaging choices saved.

`Reference = "path/Library.UBE"`, package qualification, direct visibility,
and dependency initialization are defined in `project-files.md`. The following
cannot be inherited from VB's COM registry without violating UBE portability:

1. the portable compiled-library bundle/container and manifest syntax;
2. dependency version compatibility (semantic versions, interface hashes, or
   both); and
3. the canonical package identity of the compiler-selected core library.

The complete analysis is retained in `audits/project-references.md`.

## Specification reconciliation

### Completed during this audit

- The candidate EBNF no longer accepts an entirely headerless file. Bare
  modules remain a Bootstrap Profile exception rather than full UBE 1.0.
- A comment consisting only of `Rem` is now grammatical, matching the lexical
  specification.
- The EBNF header now names only scanner tokens actually defined by the lexical
  specification.
- The validator now proves that every production is reachable from `program`;
  the stale, unreachable `statement-end` production was removed.
- Legacy `BeginProperty ... EndProperty` designer metadata blocks are now
  represented and may nest, closing a missing VB6 form/control file envelope
  without assigning runtime semantics to designer metadata.
- Named and numeric labels may now prefix a statement on the same logical
  line, in addition to occupying a line by themselves; legacy numeric line
  numbers do not require a colon.
- Approved `WithEvents` field syntax and its binding restrictions are now
  present in the candidate grammar and semantic contracts.
- Procedure/property modifiers now have canonical nonrepeating EBNF forms;
  omitted visibility and Static procedure behavior are specified.
- Custom `Type` members now use a field-only production, fixed-length syntax
  applies only to String, array-valued results are represented, and identifier
  type-character identity is specified.
- VB-compatible `With`, `Me`, `TypeOf`, loop, `Select Case`, computed branch,
  and legacy file-statement behavior is specified.
- Conditional compilation now has a normative preprocessing contract and
  directive EBNF; inactive branches are removed before the core grammar.
- Native compilation rejects `DefType` with a targeted migration diagnostic;
  import tools may use it only to create explicit declarations.

### Pending implementation evidence and deferred architecture

- Derive positive and negative property fixtures for accessor grouping,
  indexing, value/reference assignment, and Default restrictions.
- Derive call fixtures for named/omitted arguments, evaluation order, direct
  ByRef, parenthesized temporaries, Optional, and ParamArray behavior.
- Derive lookup/ambiguity and no-user-overload fixtures.
- Derive raw `AddressOf` target, ABI, lifetime, and rejection fixtures.
- Resolve default-form recreation after accepted unload.
- Resolve compiled-library packaging/version constraints and core package name.
- Derive modifier/default-visibility and Static-procedure fixtures.
- Derive positive, negative, ambiguity, and recovery grammar fixtures. Static
  validation now also checks reachability, but fixtures must prove behavior.

The unresolved architecture choices above are mirrored in
`deferred-questions.md`. They are deliberately outside the closed core source
grammar and do not reopen VB-compatible semantics.

## Non-blocking implementation work

These do not prevent the language definition from being frozen once their
contracts are already precise:

- implementing Compiler v3 in the v2-compatible source profile;
- designing internal syntax-tree or IR data structures;
- selecting concrete standard-library algorithms;
- implementing LLVM lowering and target adapters; and
- writing the public manual after the normative definition is closed.
