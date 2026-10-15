# UBE 1.0 calls and parameters audit

**Status:** reviewed and promoted into the candidate language specification and
EBNF  
**Compatibility basis:** classic Visual Basic call behavior, made deterministic
where VB left behavior implicit  
**Scope:** ordinary Subs, Functions, properties, event raising, interface calls,
and declared foreign procedures. `CallNew` keeps its stricter approved capture
contract.

This report preserves the rationale for the calls-and-parameters contract now
promoted into the candidate normative sources.

## 1. Parameter declarations

- A parameter is `ByRef` when neither `ByVal` nor `ByRef` is written. This is
  retained solely for VB source compatibility; new code should state its
  intent.
- Every parameter has an explicit declared type through an `As` clause or a
  nonconflicting identifier type character. There is no implicit `Variant`.
- Required parameters precede `Optional` parameters. After the first
  `Optional` parameter, every later ordinary parameter is also `Optional`.
  A trailing `ParamArray` is the sole exception.
- Every `Optional` parameter has `= constant-expression`. The constant must be
  convertible to the declared type at compile time. An invalid default is a
  compile-time error.
- An optional object, class, interface, form, or control reference may use only
  `Nothing` as its default. An optional `Variant` may additionally use `Empty`
  or `Null`.
- `Optional ByVal` and `Optional ByRef` are both legal. Omitting an optional
  `ByRef` parameter gives the callee a fresh writable temporary initialized
  from the default; writes to it are discarded when the call returns.
- `ParamArray` cannot be combined with `Optional`, `ByVal`, or `ByRef`. It is
  the final parameter, is written with one-dimensional array syntax, and has
  the explicit type `Variant`: `ParamArray Values() As Variant`.
- A procedure has at most one `ParamArray`. A property setter's assigned-value
  parameter is never optional and is never a `ParamArray`; the property
  contract supplies the remaining setter restrictions.

These restrictions preserve VB's flexible call surface without introducing
implicitly typed declarations.

## 2. Argument association

An actual argument is positional, named, or omitted.

```ube
Call Render(Page, , Preview)
Call Render(Page:=Page, Preview:=Preview)
```

- A named argument has the syntax `parameter-name := expression`. Parameter
  names compare case-insensitively by the ordinary identifier rules.
- Positional arguments bind from left to right to parameters not already
  bound. An empty positional slot omits that parameter.
- Named arguments bind by declared parameter name and may appear in any order.
  A positional argument cannot follow the first named argument.
- A parameter cannot be supplied more than once. An unknown name, duplicate
  name, omitted required parameter, or excess argument without a `ParamArray`
  is a compile-time error.
- An omitted slot may bind only an `Optional` parameter. Trailing optional
  parameters may be omitted without writing empty slots. `()` means that no
  arguments were supplied; it is not one omitted argument.
- A named argument cannot target `ParamArray`. Positional arguments remaining
  after all ordinary parameters are associated become its elements.
- UBE 1.0 has no argument splat or array-expansion syntax. Passing an array as
  one remaining actual produces one `Variant` element whose payload is that
  array; it does not expand the array into several arguments.

Argument association is resolved statically from the selected declaration.
UBE does not defer misspelled names or invalid arity to runtime.

## 3. Deterministic evaluation order

- Supplied argument expressions are evaluated exactly once, from left to right
  in source order. Named arguments change association, not evaluation order.
- For a direct `ByRef` actual, resolving its storage location—including index
  and receiver expressions—is that argument's evaluation. Those expressions
  are also evaluated once at the argument's position.
- All supplied arguments are evaluated and all required conversions or
  references are prepared before control enters the callee.
- A compile-time-known invalid conversion rejects the program. A permitted
  runtime conversion that fails produces the destination type's neutral value
  and records `Err` under the conversion contract; the call then proceeds with
  that neutral value.
- Default expressions are constants and have no evaluation side effects.
  Each omitted parameter nevertheless receives its own initialized value or
  temporary for that invocation.
- Return-value assignment, output through `ByRef`, and callee side effects
  occur after argument preparation in the ordinary execution of the callee.

This order also applies to `RaiseEvent` before handlers begin. Handler order is
governed by the event contract. `CallNew` uses the same left-to-right
evaluation rule, followed by its already-approved `ByVal` capture step before
the worker becomes observable.

## 4. `ByVal`

- A `ByVal` argument is converted according to the normative conversion table
  and copied into a fresh parameter value before entry.
- Scalars and value types use their ordinary value-copy rules. Passing an
  object-like value `ByVal` copies the strong reference: the callee can mutate
  the shared object but cannot replace the caller's reference variable.
- Arrays and custom datatypes receive their defined independent semantic value
  copies. Strings and fixed-length strings use their defined value and sizing
  rules.
- An expression, literal, property result, or other non-storage value is legal
  when its type can be converted to the parameter type.

## 5. Direct `ByRef`

A direct `ByRef` argument aliases caller-owned writable storage. Because the
callee may both read and replace that storage, UBE requires all of the
following:

- The actual is an assignable variable, field, array element, or other
  language-defined writable storage location. Constants, function results,
  read-only properties, and arbitrary expressions are not direct `ByRef`
  actuals.
- The actual's declared type exactly matches the parameter's declared type.
  Numeric widening, narrowing, string conversion, `Variant` boxing or
  extraction, enum-underlying conversion, and reference upcasts do not occur
  for a direct `ByRef` binding.
- Exactness includes custom-type identity; array element type and rank; enum
  identity; fixed versus variable-length String and the fixed length; and the
  declared object, class, interface, form, or control reference type.
- A scalar array element may bind to an exactly matching scalar `ByRef`
  parameter. A whole-array parameter requires an exactly matching whole-array
  variable and rank.
- Existing restrictions still apply: in particular, a hooked variable cannot
  be passed to an ordinary `ByRef` parameter, and readonly or foreign-unsafe
  storage cannot acquire mutability through a call.
- The alias remains valid only for the dynamic duration of the call. Retaining
  a caller stack alias after return is invalid, and UBE exposes no ordinary
  first-class `ByRef` value that could do so.

These are semantic checks even where the EBNF structurally accepts a general
expression as an argument.

## 6. VB parenthesized-temporary compatibility

Classic VB permits an extra pair of parentheses around an actual argument to
force value evaluation even when the destination parameter is `ByRef`. UBE
retains that source-compatible escape hatch with precise semantics:

```ube
Call ChangeCount((ShortCount))
ChangeCount (ShortCount)
```

- The parentheses shown above belong to the individual argument expression;
  they are distinct from the call's required argument-list parentheses.
- The enclosed expression is evaluated once, converted under the ordinary
  `ByVal` conversion rules, and stored in a fresh temporary whose declared type
  is the parameter type.
- The callee receives a `ByRef` alias to that temporary. Any value the callee
  writes is discarded after return; it is never converted or copied back to
  the original expression or variable.
- Runtime conversion failure supplies the neutral temporary and records `Err`,
  consistently with an ordinary permitted conversion. A statically forbidden
  conversion remains a compile-time error.
- Parentheses do not make an unsafe alias legal and do not bypass access,
  lifetime, hooked-variable, or foreign-ABI restrictions; they deliberately
  remove aliasing by creating the temporary.

Normal UBE code should prefer a `ByVal` declaration when mutation is not part
of the contract, but imported VB code receives deterministic behavior.

## 7. Optional arguments and `ParamArray` materialization

- An omitted optional argument receives its declared default after compile-time
  conversion. Explicitly supplying `Empty`, `Null`, or `Nothing` is an actual
  argument, not omission, and follows the normal type rules.
- UBE 1.0 has no implicit `Missing` sentinel and does not require `IsMissing`:
  every optional parameter has a declared default. A standard-library API may
  model a sentinel explicitly with `Variant` if its public contract needs one.
- A `ParamArray` is materialized for every invocation as a fresh,
  one-dimensional `Variant` array in source argument order. Each element
  preserves the supplied value's exact Variant tag and payload under the
  normative Variant assignment rules.
- No remaining arguments produces a valid empty array with zero elements.
  Code may enumerate it without special casing. The standard array-bound
  query contract must define how it reports this empty state; calls and
  parameters do not invent a second kind of missing array.
- Mutating or resizing the local `ParamArray` cannot alter the caller's list of
  arguments. Object payloads still preserve object identity, as ordinary
  Variant/object copying requires.

## 8. Call syntax and ignored results

UBE retains the VB statement/expression distinction:

```ube
SaveFile Path, True                 ' Statement form: no outer parentheses.
Call SaveFile(Path, True)           ' Call form: parentheses.
Result = ParseNumber(Text)          ' Expression form: parentheses.
Call ParseNumber(Text)              ' Function result intentionally ignored.
ParseNumber Text                    ' Same, in no-Call statement form.
```

- A procedure call used as an expression has a parenthesized argument list,
  including `()` for zero arguments, and the target must return a value.
- A statement beginning with `Call` uses parentheses when arguments are
  present. `Call Name` and `Call Name()` are both legal for a zero-parameter
  target.
- A call statement without `Call` does not put outer parentheses around its
  argument list. Its arguments follow the callable after whitespace. A
  zero-argument procedure may be invoked by its callable name alone.
- Both statement forms may invoke a Function or property getter and discard
  its result. Discarding a result does not suppress evaluation or side effects.
- Subs cannot appear in value expressions. Assignment syntax is not a call;
  `Name = expression` at procedure scope retains the existing assignment
  disambiguation rule.
- Named arguments and omitted slots are available in each call form. The
  `:=` token distinguishes a named argument from assignment.
- Parentheses used for grouping one individual no-`Call` argument retain the
  temporary rule in section 6; they do not turn that statement into expression
  call syntax.
- `RaiseEvent EventName(...)` uses the parenthesized form. Property access and
  indexing share postfix parentheses and are distinguished by the statically
  resolved declaration, consistent with the property contract.

`CallNew` deliberately differs: it always requires a directly resolved Sub
and an ordinary parenthesized argument list, including `()`, rejects Functions,
and requires every target parameter to be `ByVal`.

## 9. Foreign declarations

The source-level association, evaluation-order, named-argument, and omission
rules apply before a declared foreign call is lowered. The declaration's ABI
contract may impose additional restrictions. In particular, `Any` is legal
only as a foreign parameter and is validated by ABI lowering; it does not
weaken ordinary UBE `ByRef` rules or create an untyped UBE value.

## 10. Required grammar and specification reconciliation

Promotion of this proposal requires coordinated normative edits:

1. Add a named-argument production using `identifier, spacing, ":=", spacing,
   expression`, and permit it in parenthesized and no-parentheses argument
   lists without treating it as an ordinary expression.
2. Keep empty positional slots, but reject empty named arguments semantically.
3. Express, or state as semantic constraints beside the grammar, declaration
   ordering for required, optional, and final `ParamArray` parameters.
4. Require the explicit `ParamArray name() As Variant` shape and reject its
   combination with other passing modifiers.
5. Preserve the three call surfaces: expression calls with parentheses,
   `Call` statements with parenthesized nonempty arguments, and no-`Call`
   statements with unparenthesized arguments.
6. Add positive and negative fixtures for mixed positional/named arguments,
   omitted middle slots, duplicate names, evaluation order, exact direct
   `ByRef`, parenthesized temporaries, optional-`ByRef` temporaries, empty and
   populated `ParamArray`, ignored Function results, and zero-argument forms.

No owner question is required for this contract: it follows the requested
VB-default policy and does not conflict with the approved static typing,
conversion, managed-memory, threading, or `CallNew` architecture.
