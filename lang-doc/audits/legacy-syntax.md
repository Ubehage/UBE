# Classic VB textual-syntax audit

**Status:** reviewed; compatible grammar changes promoted and architecture
questions moved to `../deferred-questions.md`  
**Audited artifact:** `lang-doc/grammar/ube.ebnf`  
**Compatibility target:** the claim in `language-spec.md` that UBE 1.0 accepts
the core textual syntax of classic VB6, including exported source headers and
designer data, declarations, statements, and legacy file/error statements  
**Method:** use the classic VB model unless it conflicts with an already
approved UBE rule. Keep ordinary library calls out of the grammar.

This audit is deliberately stricter than checking that the EBNF validator
passes. The validator proves that the grammar is internally connected; it does
not prove that classic source is accepted or that malformed forms are rejected.

## Result summary

The candidate EBNF does not yet substantiate the stated VB6 textual-syntax
coverage. The highest-priority gaps are:

1. exported `.cls` files and procedure attributes cannot be parsed;
2. conditional-compilation syntax is absent;
3. `TypeOf ... Is ...`, computed `On ... GoTo/GoSub`, `Lock`, `Unlock`,
   `Write #`, and `Width #` are absent;
4. `Open` and the grouped file-operation rule accept or reject the wrong
   token forms;
5. statement separators/comments and several block forms have structural
   errors; and
6. the reserved-word model prevents common qualified member names unless the
   scanner applies an undocumented exception.

These are grammar/specification issues, not requests to put `Len`, `MsgBox`,
or other library routines into the parser.

## 1. Exported-source and lexical blockers

### 1.1 Nameless class metadata block is missing (high)

An exported classic class has a nameless metadata block after its version
line. Its shape is:

```vb
VERSION 1.0 CLASS
BEGIN
  MultiUse = -1
  Persistable = 0
  DataBindingBehavior = 0
  DataSourceBehavior = 0
  MTSTransactionMode = 0
END
Attribute VB_Name = "Worker"
```

`designer-block` always requires `Begin qualified-name identifier`, so the
bare `BEGIN` form cannot parse. This contradicts the explicit `.cls` exported
source claim. Add a distinct legacy class-metadata block rather than weakening
ordinary form/control designer blocks. Its accepted property names and values
may remain preserved metadata with no execution meaning.

### 1.2 Procedure/member attributes are rejected (high)

VB exporters place member attributes immediately after the member header, for
example:

```vb
Public Property Get NewEnum() As Object
Attribute NewEnum.VB_UserMemId = -4
    Set NewEnum = Items
End Property
```

`procedure-body` cannot contain `attribute-line`; only local declarations,
labels, statements, and empty lines are possible. Add an optional contiguous
member-attribute block between the procedure header and executable body. Then
validate that an attribute's qualified owner denotes that member. These lines
are metadata, not executable statements.

### 1.3 Conditional compilation is absent (high)

Classic source can contain `#Const` and nested `#If ... Then`, `#ElseIf`,
`#Else`, `#End If` regions at module or procedure scope. None begins a
production in the candidate grammar. Conditional compilation also cannot be
modelled as an ordinary library call because it controls which tokens form the
compilation unit.

The lexical/preprocessing phase needs a specified conditional-compilation
grammar and expression subset, plus rules for inactive text. It must run before
ordinary parsing while retaining source locations. This needs a normative
contract even if UBE later diagnoses unsupported legacy conditional constants.

### 1.4 Qualified members that spell keywords are under-specified (high)

The specification says the scanner recognizes reserved words before
`bare-identifier`, while `member-access` requires `identifier`. Taken
literally, familiar source such as this cannot parse because `Print`, `Name`,
and `Type` occur as grammar literals elsewhere:

```vb
Debug.Print Value
Thing.Name = "sample"
Info.Type = 3
```

The same problem affects library qualification such as `VBA.Date` and any
user/library member whose name happens to be a contextual statement word.
Define a `member-name`/contextual-name rule or a scanner state that permits the
classic qualified-name surface after `.` and `!`. Do not globally turn hard
UBE keywords into identifiers. Add conformance examples for `Debug.Print`,
`.Name`, a bracketed member, and a genuinely prohibited hard-keyword use.

### 1.5 Leading horizontal whitespace contradicts the grammar (high)

The preamble says horizontal whitespace is otherwise insignificant, but most
module items and these closing lines do not consume leading `spacing`:

- `End Sub`, `End Function`, and `End Property` in
  `procedure-declaration`;
- `End Type` in `type-declaration`; and
- `End Enum` in `enum-declaration`.

Consequently an indented terminator is either rejected or, for `End`, risks
being consumed as the standalone termination statement in the body. Module
declarations themselves also generally require column one. Normalize logical
line indentation at a single layer or add `spacing` consistently. Closing
construct recognition must win before standalone `End`, independent of
indentation.

### 1.6 Multiword literals bypass the whitespace model (medium)

The grammar uses literals containing an ASCII space (`"Private Module"`,
`"PROPERTY PAGE"`, and `"Read Write"`). Elsewhere, words are joined with
`spacing1`, which permits tabs and explicit continuations. Replace embedded
spaces with token sequences. Otherwise logically equivalent classic spelling
has inconsistent continuation and whitespace behavior.

### 1.7 Final physical line is not defined (medium)

Every source line production requires `NEWLINE`, including the last
terminator. State that the scanner synthesizes one logical newline before EOF
when a nonempty final physical line lacks one, or add an EOF-aware final line
rule. A valid saved source file must not depend on the editor having appended a
trailing line break.

## 2. Declaration findings

### 2.1 Event parameter parentheses are incorrectly mandatory (high)

`event-declaration` and `interface-event` require `parameter-list`. Classic
event declarations permit an omitted list:

```vb
Public Event Closed
```

Make the list optional. Preserve the separate classic `RaiseEvent` rule:
parentheses are used when arguments are supplied, but a parameterless event is
raised without `()`.

### 2.2 Procedure modifier repetition accepts nonsense (high)

`procedure-declaration` begins with `{ member-modifier, spacing1 }`, so forms
such as these are structurally accepted:

```vb
Public Private Sub Work()
Static Static Function F() As Long
Inline ForceInline Export Friend Sub G()
Default Sub H()
```

Only some combinations are rejected by current static restrictions, and
`Default` is syntactically allowed on every procedure even though the
specification reserves it for properties. Replace the repetition with ordered,
at-most-once modifier slots (or add complete mandatory static checks). Keep
UBE's `Inline`, `ForceInline`, and `Export` extensions, but do not let their
addition weaken classic declaration structure.

### 2.3 Module variable declaration alternatives are too broad and too narrow
(high)

The `[visibility] explicit-variable-declaration` alternative accepts the
non-classic combinations `Public Dim X` and `Private Dim X`. Conversely,
`event-variable-declaration` permits only one `WithEvents` variable, while the
classic `Private` declaration surface permits comma-separated fields and a
`WithEvents` modifier on individual eligible items.

Split module storage declarations into their actual introducer forms:
`Dim ...`, `Static ...`, and `Public|Private|Friend|Global ...`. Give each item
an optional, context-checked `WithEvents` position where compatibility requires
it. Retain the approved restrictions that `WithEvents` is field-only, strongly
typed, non-array, and cannot combine with `As New`.

### 2.4 Parameter grammar over-accepts invalid combinations (medium)

The normative semantic text already has the right UBE rules, but the EBNF
structurally accepts:

```vb
Sub A(Value As Long = 4)                 ' default without Optional
Sub B(Optional ParamArray Values() As Variant)
Sub C(ParamArray Value As Long)
Sub D(Required As Long, Optional X As Long = 1, Later As Long)
```

If the project intentionally uses a permissive parse followed by static
validation, add every restriction to the static-restrictions section and parser
tests. Otherwise split ordinary, optional, and final `ParamArray` parameters in
the grammar. Currently only prose outside the EBNF prevents several malformed
forms.

### 2.5 Classic `DefType` declarations need a compatibility disposition
(medium)

`DefBool`, `DefByte`, `DefCur`, `DefDate`, `DefDbl`, `DefInt`, `DefLng`,
`DefObj`, `DefSng`, `DefStr`, and `DefVar` with letter ranges are absent. Their
implicit-typing effect conflicts with UBE's approved explicit-type rule, so
silently implementing them is not appropriate. However, the broad statement
that every valid classic core construct has a parse suggests the importer
should recognize them and issue a controlled migration/unsupported diagnostic
rather than a generic parse error. Clarify the compatibility boundary and add
recognition only if that broad claim remains.

### 2.6 Array-valued procedure results need an explicit decision (medium)

`function-header` and `property-get-header` allow only `As type-name`, with no
result array suffix. Classic VB can expose array-valued Function results. UBE
must either add a result-array declarator and define its value/lifetime rules,
or explicitly exclude this part of classic compatibility. Do not infer it from
parameter `array-rank`; parameter and result syntax occupy different positions.

### 2.7 Call-site `ByVal`/`ByRef` for legacy external calls is absent (low)

Classic `Call` syntax permits call-site `ByVal` or `ByRef` in the narrow DLL
calling case. `argument` has no such alternative. UBE's declared ABI already
knows parameter passing mode, so this spelling may reasonably be rejected, but
that is a documented compatibility exception rather than an ordinary library
issue. Decide whether import accepts-and-normalizes it or reports a targeted
diagnostic.

## 3. General statement and expression findings

### 3.1 `TypeOf object Is type` is missing (high)

`TypeOf ... Is ...` is language syntax, not a function call. There is no
primary/comparison production for it:

```vb
If TypeOf Item Is IPrintable Then Call PrintItem(Item)
```

Add a type-test expression at the proper precedence. Its right operand is a
type name, not a value expression. Reconcile exact class/interface matching
with UBE's approved interface and identity model. The existing object-identity
`Is` production cannot represent this construct.

### 3.2 Computed `On ... GoTo/GoSub` is missing (high)

The classic forms are:

```vb
On Choice GoTo First, Second, Third
On Choice GoSub ReadIt, WriteIt
```

`error-statement` recognizes only `On Error`; `goto-statement` recognizes only
direct `GoTo`/`GoSub`. Add the computed branch statement with an expression and
one-or-more label references. It is unstructured compatibility syntax and may
receive the same modernization diagnostic as direct `GoSub`, but should not be
confused with error handling.

### 3.3 Colon/comment endings are incomplete (high)

`statement-line` requires a statement after every consumed colon and lets
comments appear only in `line-end`. It therefore rejects common valid forms:

```vb
Value = 1: Rem finished
Value = 1: ' finished
Value = 1:
```

Model a logical statement sequence whose final separator may be followed by a
comment or line end. `Rem` must still become a comment only where a statement
may start and only with the approved following-space/newline boundary. Do not
solve this by permitting empty statements in arbitrary expression contexts.

### 3.4 `Do` accepts both pre-test and post-test conditions (medium)

The independent optionals in `do-statement` accept the malformed hybrid:

```vb
Do While Ready
    Work
Loop Until Finished
```

Classic `Do` chooses a condition before the body, after the body, or neither,
not both. Make those alternatives mutually exclusive or add an explicit static
restriction and regression case.

### 3.5 `Case` relational/range grammar over-accepts combinations (medium)

`case-clause` uses the full `relational-operator` and independently permits a
`To` tail, accepting forms such as `Case Is Like Pattern` and
`Case Is > 1 To 10`. Classic `Case Is` takes an ordinary comparison operator;
a range is the separate `lower To upper` form. Split value, range, and
relational case clauses. Object identity and `Like` should not enter merely
because they are available in general expressions.

### 3.6 Single-line `If` legacy label shorthand is unrepresented (low)

Classic sources may use the legacy branch shorthand in which `Then`/`Else` is
followed by a line number or label rather than an explicit `GoTo`. The current
single-line form requires a normal statement. Confirm the exact VB6 import
surface and either add a narrow label-target alternative or record this as an
intentional compatibility exception. Do not make a bare integer a general
statement.

### 3.7 Repeated prefix operators are not represented (low)

`not-expression` and `unary-expression` each permit at most one prefix. If
classic conformance tests establish that forms such as `Not Not Flag` or
repeated unary signs are accepted, make the productions recursive. This item
needs a compiler-or-formal-spec fixture before normative change; it is not a
reason to guess.

## 4. Legacy file and error statement findings

### 4.1 `Open` has the wrong sharing/locking tokens (high)

Classic `Open` permits `Shared` by itself or `Lock Read`, `Lock Write`, and
`Lock Read Write`. The current production instead accepts `Lock Shared` and
rejects plain `Shared`:

```vb
Open Path For Random Shared As #1 Len = RecordSize   ' should parse
Open Path For Random Lock Shared As #1               ' should not parse
```

Split the access and sharing clauses into exact alternatives, using tokenized
multiword forms. Preserve their classic ordering unless UBE intentionally
documents an extension.

### 4.2 Grouped `file-operation` permits verbs with the wrong tail (high)

One production shares an optional `As expression`/`, expression` suffix among
six unrelated statements. It consequently accepts malformed constructs such
as `Kill A As B`, `ChDir A, B`, and `Name A` while making required operands
optional. Use separate productions:

- `Kill pathname`
- `Name oldpathname As newpathname`
- `FileCopy source, destination`
- `ChDir path`
- `ChDrive drive`
- `MkDir path`
- `RmDir path`

These are special statement surfaces even if their implementation ultimately
calls portable library code.

### 4.3 `Lock` and `Unlock` are missing (high)

The approved threading document explicitly distinguishes `SyncLock` from
classic file-record `Lock`, yet the latter has no production. Required forms
include whole-file, one-record, and range syntax:

```vb
Lock #1
Lock #1, RecordNumber
Lock #1, First To Last
Lock #1, To Last
Unlock #1, First To Last
```

Add file-lock statement productions. Their semantics remain explicit
file-resource behavior and must not be implemented as the object monitor used
by `SyncLock`.

### 4.4 `Write #` and `Width #` are missing (high)

The grammar has `Print #`, `Input #`, and related operations but omits:

```vb
Write #1, Name, Count
Write #1,
Width #1, 80
```

Add exact statement forms. `Write #` requires a file number and comma, with an
optional output list; `Width #` requires a file number, comma, and width
expression. Whether a target can carry out an operation is a controlled runtime
or portability matter, not a reason to reject its syntax.

### 4.5 `Print` output-list syntax is incomplete (medium)

The current `print-list` requires the first item and allows only comma or
semicolon separators. It rejects separator-only output positions such as
`Print ;`, and does not model every classic `Print #` output-list arrangement.
It also conflates screen/object `Print` and file `Print #` in one optional
prefix, making the intended constraints hard to prove.

Create distinct file and non-file surfaces sharing a carefully defined output
list. Test at least blank file output (`Print #1,`), leading/trailing character
position controls, `Spc`, `Tab`, and ordinary expression sequences. UI-object
rendering semantics may live in a framework, but `Print #` is part of the
promised file syntax.

### 4.6 `On Error GoTo -1` is accepted but not specified (high)

The EBNF accepts `On Error GoTo -1`; the normative error section specifies
only `GoTo label`, `Resume Next`, and `GoTo 0`. `GoTo -1` is associated with
later Visual Basic exception state, not the stated classic VB6 model. Remove it
unless UBE deliberately defines it. An accepted token form with no semantics
is worse than a targeted rejection.

### 4.7 `Resume` target overlap needs a clear parse (low)

Because numeric labels include `0`, `Resume 0` is currently parsed as a label
target. Confirm whether UBE intentionally retains that classic spelling and
state its relation to bare `Resume`; unlike `On Error GoTo 0`, it does not
disable the handler. Add parser fixtures so the two uses of zero cannot be
accidentally conflated.

## 5. Classic statements that do **not** automatically need productions

Many familiar VB words are library routines or have the same token shape as an
ordinary no-parentheses call. Provided they are not made hard reserved words,
the existing call grammar can accept examples such as:

```vb
Beep
DoEvents
Randomize Seed
Reset
SetAttr Path, Attributes
SaveSetting AppName, Section, Key, Value
DeleteSetting AppName, Section, Key
```

Their APIs and platform behavior belong in separately compiled library source.
The EBNF should not enumerate them merely because VB documentation historically
calls some of them statements. The grammar/scanner contract must, however,
guarantee that such library names remain usable as identifiers.

Likewise `Abs`, `Len`, `Mid$` when used as a value, `MsgBox`, `InputBox`,
conversion routines, date formatting, and similar built-ins are calls.
`Mid$(...) = ...` remains a real grammar exception because it is an assignment
surface, and is already represented by `dynamic-statement`.

## 6. Compatibility boundary needing an explicit decision

Classic VB6 also has syntax-bound form/graphics operations such as `Circle`,
`Line (x1, y1)-(x2, y2)`, `PSet`, and `PaintPicture`. Their coordinate and dash
punctuation cannot all be parsed as ordinary calls. They are coupled to the
classic form/Printer drawing model and conflict with UBE's platform-neutral
core direction.

Choose and document one of these outcomes before claiming complete VB6 core
textual coverage:

1. recognize the legacy syntax during import and lower it to a compatibility
   framework API;
2. recognize it only to issue a targeted unsupported-feature diagnostic; or
3. explicitly exclude legacy host/UI drawing statements from “core textual
   syntax.”

The same review should cover `Date = expression` and `Time = expression`.
Those are syntax-bound assignments to host state, not ordinary function calls,
and require either compatibility productions or an explicit portability
exception.

This is not a request to put window creation or drawing implementation into
the compiler. It is a request to make the accepted source boundary truthful.

## 7. Recommended implementation order and regression corpus

1. Fix exported class metadata, member attributes, indentation, and contextual
   member names so real exported files can reach later phases.
2. Add preprocessing syntax and tests for nested active/inactive regions.
3. Add `TypeOf`, computed `On`, and the missing file statement families.
4. Split malformed declaration modifiers, `Open`, file operations, `Case`, and
   `Do` alternatives.
5. Resolve the explicitly identified compatibility-boundary items.
6. Add one positive and one negative parser fixture per finding. Fixtures must
   assert the selected parse, not merely that the compiler did not crash.

Minimum positive corpus:

- exported `.bas`, `.cls`, `.frm`, and `.ctl` files, including member
  attributes and a nested `BeginProperty` block;
- nested conditional compilation at module and procedure scope;
- keyword-spelled qualified members (`Debug.Print`, `Thing.Name`);
- parameterless Event declaration and raise;
- `TypeOf`, direct and computed branches, colon comments;
- every `Open` access/share alternative;
- `Lock`/`Unlock` range forms, `Print #`, `Write #`, `Width #`, and every
  individual file-operation verb; and
- indented terminators plus a source file without a final physical newline.

Minimum negative corpus:

- contradictory/repeated procedure modifiers and `Default Sub`;
- invalid parameter modifier/default combinations;
- `Do` with both condition positions;
- mixed relational/range `Case` forms;
- `Lock Shared` in `Open`;
- wrong/missing operands for each file-operation verb; and
- `On Error GoTo -1` unless semantics are deliberately added.

## 8. Reference evidence used for this audit

The repository's normative files remain authoritative for UBE. These Microsoft
references were used only to verify the classic source surfaces:

- [VBA language specification (MS-VBAL)](https://download.microsoft.com/download/0/a/6/0a6f7755-9af5-448b-907d-13985accf53e/%5Bms-vbal%5D.pdf)
- [Sub statement and argument grammar](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/sub-statement)
- [Call statement](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/call-statement)
- [RaiseEvent statement](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/raiseevent-statement)
- [Private/WithEvents declaration](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/private-statement)
- [On...GoSub and On...GoTo](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/ongosub-ongoto-statements)
- [Lock and Unlock statements](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/lock-unlock-statements)
- [Print # statement](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/printstatement)
- [Write # statement](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/writestatement)
- [Width # statement](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/widthstatement)
- [FileCopy statement](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/filecopy-statement)
