# UBE 1.0 language-closure audit

**Status:** historical language-closure record; current gaps and implementation evidence remain active
**Purpose:** preserve the decisions and proof work used to freeze the Compiler
v3 language specification and EBNF

This is not a public language specification. It records gaps found while
cross-checking `language-spec.md`, the focused normative contracts, and
`grammar/ube.ebnf`. Closed semantics have moved into the normative sources;
remaining checklist work supplies implementation evidence. Current unresolved
choices and unapproved recommendations are tracked in
[Architecture-Decisions.md](../project-docs/Architecture-Decisions.md).
That register is not a reconstruction of the missing historical decision or
audit files and does not change normative behavior without owner approval.

The completion statements below retain the historical audit's scope. Referenced
audit files and the original grammar validator/fixture evidence are not retained
in this checkout; their past results are not current acceptance evidence.
Later approved amendments and current implementation limits are recorded in
the normative sources and [bootstrap-profile.md](bootstrap-profile.md).

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
`ParamArray Values() As Variant`. Current `CallNew` argument and lifetime rules
are in [language-spec.md section 5](language-spec.md#5-procedures-names-and-modules)
and [threading.md](threading.md). The historical `audits/calls-parameters.md`
rationale is not retained; the surviving normative calls/parameters clauses
are the contract, not a recovered copy of that audit.

### 4. Name resolution and overloads

**State:** VB-derived contract approved by policy and promoted.

UBE 1.0 has no user-defined procedure overloading. Declaration regions,
Unicode-folded identity, local/member/module/reference lookup order,
qualification, and ambiguity diagnostics are now defined. Property accessor
selection is not general overloading. The historical `audits/names-callbacks.md`
rationale is not retained. Surviving rules are in language-spec.md sections 5
(name resolution) and 11 (`AddressOf`), plus [foreign-abi.md](foreign-abi.md).

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
The historical `audits/forms-controls.md` analysis is not retained; surviving
rules are in language-spec.md sections 5, 6.1 and 12 and
[v3-language-definition.md section 4.3](v3-language-definition.md#43-object-assignment-and-construction).
The default-form choice is resolved: the first bare reference creates the default identity on demand,
but accepted unload records an explicit user decision and prevents later bare
recreation. A fresh lifetime then requires `Load FormName`.

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

The historical `audits/project-references.md` analysis is not retained.
Use the surviving [project-files.md](project-files.md) contract and the current
unapproved architecture-decision register; neither is proof of that missing
audit or of implemented library packaging.

## Specification reconciliation

### Completed during this audit

- The candidate EBNF no longer accepts an entirely headerless file. Bare
  modules remain a Bootstrap Profile exception rather than full UBE 1.0.
- A comment consisting only of `Rem` is now grammatical, matching the lexical
  specification.
- The EBNF header now names only scanner tokens actually defined by the lexical
  specification.
- The historical validator was reported to check reachability from `program`;
  the stale, unreachable `statement-end` production was removed. The validator
  is not retained, so this is not a current validation result.
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
  applies only to String and array-valued results are represented. The historical
  identifier-type-character contract was superseded on 2026-11-28: declarations
  require `As`, identifiers have no suffixes and LongLong literals use `&&`.
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
- Derive first-reference and post-unload default-form fixtures from the frozen
  hybrid creation rule.
- Resolve compiled-library packaging/version constraints and core package name.
- Derive modifier/default-visibility and Static-procedure fixtures.
- Derive positive, negative, ambiguity, and recovery grammar fixtures and rerun
  structural/reachability validation. The missing historical validator and its
  reported results cannot substitute for current behavioral evidence.

The historical `deferred-questions.md` register is not retained. Current choices
and recommendations are in
[Architecture-Decisions.md](../project-docs/Architecture-Decisions.md), where
unapproved proposals are explicitly distinguished from normative decisions.
The current register does not claim to preserve every missing historical item.

## Non-blocking implementation work

These do not prevent the language definition from being frozen once their
contracts are already precise:

- implementing Compiler v3 in the v2-compatible source profile;
- designing internal syntax-tree or IR data structures;
- selecting concrete standard-library algorithms;
- implementing LLVM lowering and target adapters; and
- writing the public manual after the normative definition is closed.
