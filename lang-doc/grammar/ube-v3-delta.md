# UBE 1.0 grammar delta for Compiler v3

**Status:** incorporated historical staging record  
**Normative grammar:** `ube.ebnf`, frozen for version 1.0

This file records the phrase-structure changes that were approved and merged
into the UBE 1.0 grammar. It remains as an audit aid; `ube.ebnf` is the
authoritative frozen phrase structure. Merge status does not imply that
Compiler v3 already implements the productions.

## Source identity

Add a native header before the existing optional designer/attribute material:

```ebnf
native-source-header = "UBE", spacing1, "SOURCE", spacing1,
                       source-format-version, spacing1, source-kind, line-end,
                       spacing, "Attribute", spacing1, "UBE_Name", spacing,
                       "=", spacing, string-literal, line-end ;
source-format-version = decimal-digits ;
source-kind          = "MODULE" | "CLASS" | "FORM" | "CONTROL" ;
```

Semantic validation requires this header for newly created native source,
requires kind/extension agreement, and treats classic `VERSION`/`VB_Name`
material as legacy compatibility input. Bootstrap-profile bare modules remain
an explicitly limited compiler-input exception.

## Modifiers and declarations

Add `Export` to `member-modifier`; semantic validation permits it only together
with `Public` on a module-level Sub or Function in a Library project.

Extend enum declarations with an optional underlying type:

```ebnf
enum-declaration = "Enum", spacing1, identifier,
                   [ spacing1, "As", spacing1, ( "Long" | "LongLong" ) ],
                   line-end, { enum-member },
                   "End", spacing1, "Enum" ;
```

Add native interface contracts:

```ebnf
interface-declaration = [ visibility, spacing1 ], "Interface", spacing1,
                        identifier, line-end, { interface-member },
                        spacing, "End", spacing1, "Interface", line-end ;

interface-member = spacing,
                   ( interface-sub | interface-function |
                     interface-property | interface-event ), line-end ;
interface-sub = "Sub", spacing1, identifier, [ parameter-list ] ;
interface-function = "Function", spacing1, typed-name, [ parameter-list ],
                     [ spacing1, as-clause ] ;
interface-property = "Property", spacing1, ( "Get" | "Let" | "Set" ),
                     spacing1, typed-name, [ parameter-list ],
                     [ spacing1, as-clause ] ;
interface-event = "Event", spacing1, identifier, parameter-list ;
```

Add `interface-declaration` to `module-item`. Interface members are signatures
only and therefore have no body or `End Property`/procedure terminator.

## Thread creation

Add one expression form and permit it as a standalone statement:

```ebnf
call-new-expression = "CallNew", spacing1, qualified-name, argument-list ;
call-new-statement  = call-new-expression ;
```

Add `call-new-expression` to `primary-expression` and `call-new-statement` to
`statement`. Semantic resolution restricts the target to a directly visible,
statically known Sub and requires its ordinary parenthesized argument list,
including empty `()`.

## Structured synchronization

Add a block statement:

```ebnf
sync-lock-statement = "SyncLock", spacing1, expression, line-end,
                      statement-block, spacing,
                      "End", spacing1, "SyncLock" ;
```

Add it to `control-statement`. Semantic validation requires an object-compatible
operand and guarantees monitor release on every exit edge.

## Event binding

Add a field declaration for statically bound object events:

```ebnf
event-variable-declaration = [ visibility, spacing1 ], "WithEvents", spacing1,
                             variable-item ;
```

Add it to module-level declarations. Semantic validation limits it to one
scalar module/class/form/control field whose declared class, interface, form,
or control type exposes events. Handlers use the approved
`<field>_<event>` convention. Locals and dynamic handler attachment are outside
UBE 1.0.

## Properties

Split property headers by accessor kind so a setter must have a parameter list
and cannot declare a result type:

```ebnf
property-header     = property-get-header | property-let-header |
                      property-set-header ;
property-get-header = "Property", spacing1, "Get", spacing1, typed-name,
                      [ parameter-list ], [ spacing1, as-clause ] ;
property-let-header = "Property", spacing1, "Let", spacing1, identifier,
                      parameter-list ;
property-set-header = "Property", spacing1, "Set", spacing1, identifier,
                      parameter-list ;
```

Interface properties use the same headers and may carry `Default`. Semantic
validation groups same-name accessors and enforces the approved type, index,
setter-value, visibility, and Default-property rules.

## Named arguments

Add named arguments without treating `:=` as assignment:

```ebnf
argument-slot  = [ argument ] ;
argument       = named-argument | expression ;
named-argument = identifier, spacing, ":=", spacing, expression ;
```

Semantic validation enforces positional-before-named ordering, unique and
known names, omission rules, and the final `ParamArray` contract. All supplied
expressions retain source-order, evaluate-once behavior.

## Instance self-reference

Add `Me` as a primary expression for the current class, form, or control
instance:

```ebnf
primary-expression = (* existing alternatives *) | me-expression ;
me-expression      = "Me" ;
```

`Me` is a hard keyword and is invalid in a standard module or other context
without a current object identity.

## Canonical procedure modifiers

Replace the arbitrary repeated modifier list with distinct implemented
Sub/Function, Property, Export, and Intrinsic prefixes:

```ebnf
sub-function-modifiers = [ visibility, spacing1 ], [ "Static", spacing1 ],
                         [ ( "Inline" | "ForceInline" ), spacing1 ]
                       | "Public", spacing1, "Export", spacing1,
                         [ "Inline", spacing1 ] ;
property-modifiers = [ visibility, spacing1 ], [ "Default", spacing1 ],
                     [ "Static", spacing1 ] ;
```

Intrinsic declarations accept only an optional visibility followed by
`Intrinsic Sub|Function`. This makes repetitions and misordering structural
errors while semantic validation enforces source-kind and project restrictions.

## Short-circuit and identity operators

Extend the existing `and-expression` and `or-expression` operator sets:

```ebnf
or-expression  = and-expression,
                 { spacing1, ( "Or" | "OrElse" ), spacing1,
                   and-expression } ;
and-expression = not-expression,
                 { spacing1, ( "And" | "AndAlso" ), spacing1,
                   not-expression } ;
```

Extend identity comparison:

```ebnf
relational-operator = "=" | "<>" | "<=" | ">=" | "<" | ">" | "Like" |
                      "IsNot" | "Is", [ spacing1, "Not" ] ;
```

`And`/`Or` remain eager. `AndAlso`/`OrElse` short-circuit. `IsNot` and `Is Not`
are equivalent and are restricted semantically to object-compatible operands.

## No new grammar production required

The approved rules for `CollectGarbage()`, module/class lifecycle names,
mandatory `Set`, parameterless `New`, array behavior, conversions, enums'
integer behavior, linked program support, and thread-library functions are
semantic or library contracts using syntax already present before version 1.0.

## Final compatibility-closure additions

The completeness audit also incorporated these VB-compatible forms directly in
the candidate grammar:

- exported class/designer metadata, member attributes, contextual keyword
  member names, indented terminators, and parameterless Events;
- labels before statements, numeric line labels, computed `On ... GoTo/GoSub`,
  `TypeOf ... Is`, distinct `Case` clauses, and exclusive pre/post `Do`
  conditions;
- array-valued Function and Property Get results;
- exact legacy file-operation statement shapes, including `Lock`, `Unlock`,
  `Write #`, and `Width #`; and
- field-only custom `Type` members, String-only fixed lengths, and removal of
  unsupported VB.NET integer literal suffixes.

Conditional directives are a lexical pre-pass rather than core statements.
Their separate normative grammar is
[`conditional-compilation.ebnf`](conditional-compilation.ebnf); only its
selected output is parsed by `ube.ebnf`.

## Promotion checklist

- [x] Close the remaining normative contracts in
  `../v3-language-definition.md`.
- [x] Apply every production above to `ube.ebnf` in one versioned update.
- [x] Define the new words through normative productions; compiler scanners
  must reserve them when implementing grammar version 1.0.
- [ ] Add positive, negative, ambiguity, and recovery fixtures for each form.
- [~] Synchronize `../language-spec.md`, public documentation, and compiler
  diagnostics with the promoted grammar. The normative specification is
  synchronized; implementation and public documentation remain separate work.
- [ ] Remove this staging file after its checklist is fully incorporated, or
  retain it only as clearly labeled historical design rationale.
