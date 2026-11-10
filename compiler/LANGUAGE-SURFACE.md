# Compiler language surface and UBECore boundary

This document organizes the existing language contract for the owner-requested
runtime inventory. It does not add keywords or change semantics. The
[core grammar](../lang-doc/grammar/ube.ebnf),
[directive grammar](../lang-doc/grammar/conditional-compilation.ebnf) and
[specification](../lang-doc/language-spec.md) remain authoritative.

## Compiler responsibilities

| Surface | Compiler understands | Library supplies |
|---|---|---|
| Source | UTF-8, Unicode identifier rules, comments, continuations, literals, native/legacy headers and metadata | Unicode data and reusable text algorithms |
| Directives | #Const, #If, #ElseIf, #Else, #End If selection and constant evaluation | No runtime execution |
| Declarations | Dim, Const, Static, visibility, As, arrays, Type, Enum, Interface, Implements, WithEvents, options | Datatype operations expressible as ordinary procedures |
| Procedures | Sub/Function, properties, parameters, Optional, ParamArray, ByVal/ByRef, calls, returns, access checking | Public callable algorithms |
| Flow | If, Select, For, For Each, Do, While, With, Exit, labels, GoTo, GoSub, Return, End | Program-support cleanup where needed |
| Expressions | Precedence, typing, evaluate-once order, arithmetic, comparisons, eager and short-circuit operators, identity | Checked operation/conversion implementations where expressible in UBE |
| Objects | New, Set, Nothing, Me, TypeOf, initialization, alias/lifetime and interface rules | Allocation, collector and lifecycle support behind explicit primitives |
| Errors | On Error, Resume, failing-operation branches and source locations | Thread-local Err state, descriptions and public helpers |
| Threads/events | CallNew capture, SyncLock cleanup, event declarations, RaiseEvent, WithEvents binding | Thread creation, synchronization, dispatch, cancellation and liveness support |
| Legacy I/O | Statement grammar, argument evaluation, assignment destinations, Print separators, Mid assignment | File operations, encoding, formatting, resource ownership and adapters |
| Forms | Load/Unload syntax and typed lifetime obligations | Native framework, windows, controls, UI dispatch |
| Foreign/low-level | Declare, AddressOf restrictions, Public Export, Intrinsic binding, Inline/ForceInline, Asm/Bytecode validation | Target adapters and small irreducible operations |

Source-level functions such as Mid$, Len, Abs and DateAdd resolve through
ordinary declarations. A library function may need type metadata or a primitive
without its public name becoming a special compiler opcode. Constant evaluation
must preserve the same semantics as runtime execution.

## Words versus functions

The owner-proposed [Adaptive function modifier](../lang-doc/adaptive-functions.md)
would let one String-returning library implementation expose calls with any of
the seven existing type suffixes, explicitly selecting the call result type.
Unsuffixed calls adapt to the caller's expected type, defaulting to a Variant
containing String. It is a proposed contextual declaration modifier;
it has not yet been added to the normative grammar or generated word inventory.

The [generated literal-word inventory](GRAMMAR-WORDS.md) lists every alphabetic
literal currently present in the two normative grammars. It is a grammar audit,
not a reserved-keyword table: contextual header words, designer metadata, and
recognized-but-rejected forms are included. The specification decides legality
in each context. Arbitrary identifiers and library names are not enumerated by
the grammar and must not become reserved words merely by appearing in UBECore.

The owner-approved VBA7-derived CLngLng and CLngPtr functions likewise resolve
as UBECore calls, returning LongLong and IntPtr respectively. Their inclusion
requires no new grammar productions; target-pointer width is determined by
the compilation target, independently of the VB6 bootstrap host.

Date, Time, String, Error, Input, Mid, Seek and similar spellings have multiple
roles. The compiler resolves their syntactic role; library declarations supply
the corresponding calls. Recognition is distinct from acceptance: for example
Option Explicit Off and DefType families receive migration diagnostics.

The [runtime ledger](../std-lib/VB6-RUNTIME-INVENTORY.md) assigns every inventoried
name to its proposed owner. [Open semantic decisions](../std-lib/INVENTORY.md)
must close before conflicting VB6 behavior is implemented. Exact signatures
and behavior remain separate from name coverage.
