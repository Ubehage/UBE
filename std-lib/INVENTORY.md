# UBECore and standard-library inventory

**Requested scope:** the VB6 runtime, shared VBA7 language/runtime facilities,
and the additions defined by UBE. VBA7 was explicitly added by the owner on
2026-10-30. **Implementation status:** the first byte/Unicode/file foundations
and bounded Threads Try APIs are implemented and tested.
[THREADS-CONTRACT.md](THREADS-CONTRACT.md) defines the adopted thread slice;
[CONCURRENCY-EVIDENCE.md](../compiler/UBE_Compiler_v3/CONCURRENCY-EVIDENCE.md)
records current qualification and its separate compiler consumer. Broader
contracts and limits are linked from [README.md](README.md). This catalog is
target scope, not evidence that every listed API exists, all threading semantics
are supported, or a library binary has been released.

This is the target-scope inventory for planning the finished library. It does
not freeze new signatures, change UBE 1.0 semantics, import archived code, or
claim implementation. Each entry must eventually have a declaration, behavior,
failure result, ownership/threading contract, tests, documentation, and target
availability. Existing UBE rules remain authoritative where they differ from
VB6 or VBA7; unresolved compatibility questions are recorded below.

## Read the inventory

| Part | Entries | Coverage | Reference |
|---|---:|---|---|
| VB6 and VBA7 functions and statements | 233 | Conversion, strings and bytes, formatting, math, finance, dates, inspection, arrays, files, environment, processes, settings, interaction, resources, and syntax requiring library services | [Runtime inventory](inventory/vb6-runtime.md) |
| UBE language and runtime additions | 250 | Primitive/value/reference types, conversions, managed memory, threads, synchronization, lifecycle, foreign ABI, compiler constructs, and historical private bootstrap hooks | [UBE contract inventory](inventory/ube-contract.md) |
| Runtime objects, constants and components | 178 | Err, Collection, application/framework objects, enums/constants, intrinsic controls, platform/COM/ActiveX boundaries, and VBA conditional constants | [Objects and components](inventory/vb6-components.md) |
| Reusable compiler foundations | 49 | Text construction, storage, lookup, Unicode, hashing, files, serialization, process support, and bounded concurrency; capabilities whose final public names are not yet chosen | [Foundation inventory](inventory/compiler-foundation.md) |

Tables name individual functions/members where a name exists. Some rows describe
a constant family, class surface, or capability rather than one callable. Row
counts therefore measure catalog entries, not a promised number of functions.
Shared entries may appear in more than one part to explain their different
contracts; their implementation is not to be duplicated.

## Meaning of “intrinsic”

VB documentation often calls a built-in function intrinsic. UBE distinguishes
an ordinary library declaration from an `Intrinsic` declaration implemented by
the compiler/substrate. Familiar names such as `Mid$`, `Len`, and conversions
belong in ordinary library source wherever practical. They are not permission
to add parser keywords or new backend hooks.

| Kind | Expected ownership |
|---|---|
| Ordinary reusable algorithms and types | UBECore, in functional UBE modules |
| OS-dependent constants, declarations and operations | Separate platform libraries/adapters, following `AGENTS.md` |
| Native forms, controls, drawing, printing and event dispatch | The documented native framework/graphics boundary; exact package surface still needs definition |
| COM, OLE, external ActiveX controls and database components | Explicit compatibility/platform scope; inventory inclusion is not a new dependency or a binary-compatibility promise |
| Syntax, primitive type recognition, layout rules, lowering and language enforcement | Compiler |
| Irreducible allocation, atomics, native transitions and ABI support | Small documented substrate/intrinsic boundary |
| Backend/tool policy and compiler measurements | Compiler support; generally useful parts may become public APIs after review |

These ownership descriptions classify the work; they do not introduce new
package names or approve new architecture. The finished ecosystem can cover
the requested surface while keeping the compiler and portable core small.

## VBA7 additions

Include `LongLong`, `LongPtr`, `CLngLng`, `CLngPtr`, `PtrSafe`, the `^` type
character, `vbLongLong`, `DefLngLng`, `DefLngPtr`, and the relevant conditional
constants. In VBA7, `LongPtr` selects an integer width and `PtrSafe` qualifies
foreign declarations. UBE already defines `LongLong`, `IntPtr`, and `UIntPtr`;
accepting a `LongPtr` spelling or `PtrSafe` qualifier needs an explicit
compatibility decision. UBE continues to require explicit typing, so adding
VBA7 to the inventory does not enable default-type statements.
[Microsoft's VBA7 overview](https://learn.microsoft.com/en-us/office/vba/language/concepts/getting-started/64-bit-visual-basic-for-applications-overview)
and [PtrSafe reference](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/ptrsafe-keyword).

VBA7 language support does not imply an implementation of Excel, Word, Access,
Outlook, PowerPoint, or the VBA editor object model. Those are host libraries,
not the shared language runtime. The component inventory records their boundary
so this scope is visible rather than silently omitted.

## Compatibility decisions that must remain explicit

| Area | UBE rule or decision needed |
|---|---|
| String positions, `Asc`/`Chr`/`StrConv`, `$` and `B` forms | Distinguish Unicode scalar positions, UTF-8 bytes, and explicit legacy encodings. Do not inherit VB6 UTF-16/ANSI storage assumptions accidentally. |
| Embedded zero bytes and fixed strings | Text/byte APIs must state length and truncation/padding behavior; C-string termination cannot define UBE text semantics. Fixed String lengths count Unicode scalar values. |
| `Len` and broad-input built-ins | Preserve UBE's approved broad-input contracts, including accepted opaque object handles. Define each function's meaning; no general object-to-scalar conversion is implied. |
| Dates, serial values, calendars and locale | UBE Date is a nanosecond-resolution, timezone-neutral Gregorian value, not a numeric serial. VB serial-date conversion and locale-dependent formatting need explicit library contracts. |
| Conversions and overflow | UBE checked conversion, neutral failure results, invariant defaults and ties-to-even rounding remain in force. `Val` and other expressly different legacy APIs need their own contracts. |
| Optional arguments and `IsMissing` | UBE requires explicit optional defaults; a VBA-style missing Variant marker and its interaction with Empty/Null/Error need a recorded decision. |
| `CVErr` and Variant error values | Define the error-valued Variant payload and its operators/conversions; it is distinct from thread-local `Err` state. |
| Error propagation | Cross-procedure handler transfer is still open in `lang-doc/deferred-questions.md`; inspecting an old nonzero `Err` cannot identify a fresh failure. |
| File numbers and record I/O | Define encoding, positions, sizes, sharing, locking, padding and serialization. Do not expose compiler-internal managed layouts through `Get`/`Put` or `LenB`. |
| Arrays and copies | UBE arrays are independent values with LongLong indexes and arbitrary rank; Preserve retains complete index tuples in the new bounds. Library compatibility must respect those rules. |
| `VarPtr`, `StrPtr`, `ObjPtr`, native handles | No ordinary API may expose a moving managed address. Any unsafe bridge needs a scoped ABI/pinning contract and owner-approved behavior. |
| `CallByName`, Object/Variant member lookup and COM | UBE has no implicit runtime-name lookup. Explicit compatibility facilities must be designed without silently changing ordinary static binding. |
| Settings, `ChDir` and enumeration state | Specify per-instance/per-thread/process state and synchronization. Windows registry and drive semantics are platform behavior, not portable defaults. |
| `Rnd`/`Randomize`, clocks and environment | State ownership and reproducibility must be documented; implementation must not assume one implicit shared mutable instance is safe. |
| Explicit UI calls | `MsgBox` and `InputBox` are user-requested interaction. Recoverable runtime failures still never display automatic dialogs. |
| Forms, events and unload | Use UBE's synchronous dispatch, default-instance, active-call drain, alias clearing and shutdown rules. Raw native callbacks and UI dispatch need tested transitions. |
| `Date =`/`Time =`, classic drawing syntax and `Def*` | Respect their existing rejected/reserved status. Including their names in a compatibility inventory does not enable them. |

Sources: [core specification](../lang-doc/language-spec.md),
[expanded semantics](../lang-doc/v3-language-definition.md),
[conversions](../lang-doc/conversion-table.md),
[memory](../lang-doc/managed-memory.md),
[threading](../lang-doc/threading.md),
[foreign ABI](../lang-doc/foreign-abi.md), and
[deferred questions](../lang-doc/deferred-questions.md).

## Completion and growth

The inventory is broad so features are not forgotten. Implementation still grows
with a concrete consumer: establish the tested bootstrap subset and byte/text
foundation first, then add only the next required facilities. A catalog entry
is not permission to implement an entire family speculatively.

For each selected item, record its exact owner/module, signature, argument and
result types, evaluation order, conversions, errors, ownership/copying, thread
safety, target support, algorithmic costs, and independent acceptance cases.
Published constants also need exact values. Methods and events need their
containing type and member kind. Compatibility changes require decisions in
the normative documents before implementation.

This inventory covers the shared language/runtime surface and identifies the
wider VB6 component ecosystem. Exhaustive binary/member parity for every
external OCX, vendor component, Office host, or internal `msvbvm60.dll` export
is a separate requirement and is not claimed here. Per-class gaps and the
evidence needed to close them are recorded in the component inventory.

## Inventory checks

Run `rtk proxy powershell -NoProfile -File std-lib/tools/check-inventory.ps1`
from the repository root. The checked-in
[reference checklist](inventory/reference-checklist.json) records the primary
indexes and independently transcribed baseline names used by this check.

The 2026-10-30 check passed for all five documents: 710 catalog rows,
175 reference function/alias names, all 73 distinct historical intrinsic names
from the three declared source boundaries, 52 local link targets, table shape,
duplicate identifier/kind keys, reference links, and trailing whitespace.
The three source boundaries are v3 bootstrap declarations, the archived
library's private declarations, and v4 compiler support. The check establishes
named coverage for these baselines, not signature correctness, remote-link
availability, complete per-control member parity, or runtime behavior.

Independent cross-review also reconciled library-call versus syntax ownership,
the separate Decimal sign/coefficient, legal Public Intrinsic visibility,
identifier suffixes, and historical primitive signature/unit disagreements.
All APIs in the fresh library remain unimplemented.
