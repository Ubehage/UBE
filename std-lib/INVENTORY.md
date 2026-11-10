# VB6 runtime inventory and UBE ownership

Owner-requested work, 2026-11-10: enumerate every VB6 built-in function and
define the compiler/UBECore boundary before compiler implementation expands.

## Scope and evidence

[The name ledger](VB6-RUNTIME-INVENTORY.md) covers global runtime functions,
their dollar spellings, runtime Subs/statements, global properties, hidden
pointer helpers, and VB6 picture/resource globals. It retains Mac-only entries
found in the shared runtime metadata without promising Windows support.

Primary local evidence is the installed Microsoft VB6 runtime type library
(`msvbvm60.dll`) and `VB6.OLB`. The checked-in JSON snapshots record their hashes
and metadata. No Microsoft executable is copied into this repository.
The extraction tool uses LoadTypeLibEx with REGKIND_NONE, without registration.

Independent documentation cross-checks:

- [Microsoft function index](https://learn.microsoft.com/en-us/office/vba/language/reference/functions-visual-basic-for-applications)
- [Microsoft conversion functions](https://learn.microsoft.com/en-us/office/vba/language/concepts/getting-started/type-conversion-functions)
- [VB6 documentation map](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa232759(v=vs.60))

The modern VBA index is supplementary, not the definition of VB6. The VB6
inventory is a compatibility baseline, not a ceiling on UBECore functionality.
Owner-approved additions from later Basic versions are recorded separately.
Office object models, worksheet functions, .NET functions, optional OCXs,
DAO/ADO and the scripting runtime are not automatically part of UBECore.

## Approved additions beyond VB6

On 2026-11-10 the owner approved including CLngLng and CLngPtr because UBE
supports their destination types. Both belong in UBECore as ordinary conversion
functions, not new keywords or name-selected compiler intrinsics.

| Function | UBE result type | Contract |
|---|---|---|
| `CLngLng(expression)` | `LongLong` | Checked conversion to a signed 64-bit integer. |
| `CLngPtr(expression)` | `IntPtr` | Checked conversion to a signed target-pointer-sized integer. |

These use UBE's existing conversion rules: applicable fractional conversion
rounds to nearest with ties to even; known-invalid conversion is diagnosed at
compile time; runtime-dependent failure returns zero and records thread-local
Err; success preserves existing Err. Target width, not the VB6 bootstrap host's
width, determines IntPtr range. CLngPtr does not expose an address or grant
dereference access, and this addition does not introduce a LongPtr type alias.

The return types and inclusion are approved; exact callable parameter
declarations and implementation remain pending alongside the other conversions.
Other VBA7 functions may be evaluated individually against supported UBE types
and semantics. These additions do not claim VB6 compiler acceptance.

The raw object-library snapshot additionally enumerates object methods and
properties. These are not global functions: for example PictureBox.Point,
TextWidth, TextHeight, PaintPicture, ScaleX/ScaleY, Clipboard.GetText and
Collection.Add belong to their receiver's API. A complete GUI/control API
contract is separate work. Internal DLL exports such as __vba helpers are
implementation machinery, not source-language built-ins.

## Established boundary

The [UBE specification](../lang-doc/language-spec.md) and
[expanded definition](../lang-doc/v3-language-definition.md) already establish:

- The compiler owns lexical rules, grammar, declarations, name resolution,
  types, conversions selected from the approved matrix, control flow,
  evaluation order, lifetimes, error branches and target lowering.
- UBECore owns ordinary algorithms and public callable functions. Recognition
  of a familiar spelling alone never selects hidden compiler behavior.
- A small explicitly bound intrinsic interface supplies irreducible storage,
  allocation, atomic, target and OS operations. Public helpers remain UBE code.
- A syntactic statement may lower to a library operation: Open/Print/Get/Put
  are not reasons to embed file-system algorithms in the compiler.
- Len, bounds and type inspection need compiler-generated metadata. That does
  not make their entire implementation a compiler subsystem.

The inventory proposes per-name placement within those boundaries. UI and
platform package names are not frozen by this inventory.

## Decisions that must be explicit

The owner settled pointer/object text input on 2026-11-10: text-consuming
broad-input functions use invariant numeric text for pointer values and unique
opaque handles for objects and other handle-bearing inputs. They never read
pointed-to memory or object contents. See language-spec.md section 8.1.
For a pointer or object handle of 12345, Mid$(value, 2, 3) returns "234".
Arrays are rejected as text input to these functions at compile time when
their type is statically known. This does not remove explicit array parameters
from APIs such as Join. A runtime-dependent Variant is passed normally; the
receiving function inspects its payload and uses Err.Raise/FAIL for forbidden
array or custom-datatype inputs. Enum values are accepted as invariant numeric text of their
selected underlying value, not their declared member name. Other custom
datatypes are rejected as whole text inputs, including records consisting only
of String fields and opaque native values. Callers may explicitly pass eligible
fields individually; the library does not concatenate fields or assign a
custom-value handle. The owner subsequently proposed an Adaptive modifier:
one implementation returns String; any existing type suffix explicitly selects
the adapted call result type, and unsuffixed calls adapt to the expected type
or default to Variant containing String. `$` keeps String; `%`, `&`, `^`, `!`,
`#` and `@` request Integer, Long, LongLong, Single, Double and Currency.
See [the proposal](../lang-doc/adaptive-functions.md) for the remaining
declaration/context rules before grammar adoption.
The proposed shared input-classification helper uses type metadata. The owner
confirmed that the address-text fallback applies only to an explicitly supplied
pointer/address value, never an internal storage address or a guessed address
for an unknown payload. It performs no dereference and cannot bypass rejection
of known invalid payloads. This is
specified behavior, not an implementation claim.

- Byte-string and ANSI/UTF-16 compatibility operations versus UBE Unicode
  scalar semantics; fixed-layout LenB and pointer helpers versus moving GC.
- IsMissing versus UBE's requirement for explicit Optional defaults.
- CVErr/IsError error-valued Variants versus the defined UBE Variant tags.
- CallByName and COM CreateObject/GetObject versus static member resolution
  and portable object identity. No implicit COM dependency is authorized.
- VB6 date serials, Calendar and local formatting versus timezone-neutral UBE
  Date and invariant implicit conversion. Explicit compatibility calls may
  differ from core conversion semantics.
- Thread-local ownership of Dir enumeration, random state, file numbers,
  formatting state and current-directory behavior.
- Registry-backed settings, process activation, SendKeys and event pumping
  need explicit platform behavior and failure contracts.
- Spc/Tab require Print context. Mid assignment, Input statement, Seek
  statement and Date/Time setters remain distinct from similarly named calls.

Before a row is implemented, specify its exact UBE declaration, accepted
types, return type, omitted-argument rules, success/failure results, Err
behavior, allocation, thread safety, platform scope and acceptance cases.
Unresolved rows are inventoried, not rejected or silently approved.

## Reproduction

Run from the repository root through the required RTK prefix:

```powershell
rtk proxy powershell -NoProfile -File std-lib/tools/read-vb6-type-library.ps1 -Output std-lib/vb6-runtime-metadata.json
rtk proxy powershell -NoProfile -File std-lib/tools/read-vb6-type-library.ps1 -Library "C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.OLB" -Output std-lib/vb6-objects-metadata.json
rtk proxy powershell -NoProfile -File std-lib/tools/build-vb6-inventory.ps1
```

Passing proves metadata/index name coverage, not behavioral conformance or
complete signatures. Constants, enums, control events and the complete Win32
API are not counted as functions. New evidence must extend the ledger instead
of being excluded merely to preserve its count.

Additional spelling gate:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/vb6-llvm/probe-aliases.ps1
```

This compiles isolated fixtures without running them. It asserts acceptance
of 14 additional dollar spellings and rejection of LoadResString$ (type-character
mismatch) and StrConv$ (undefined function). These rejected aliases must not be
invented by mechanically appending `$` to every function returning text.

## Evidence recorded 2026-11-10

- Runtime metadata: msvbvm60.dll 6.00.9848; both input hashes are in the JSON.
- Inventory generator: all 138 independently listed function/conversion names
  accounted for; the broader ledger also includes subs, properties and aliases.
- Grammar word extraction: 181 distinct alphabetic literals, including
  contextual and recognized-but-rejected forms.
- Alias compiler: VB6 6.00.9782; build outside the restricted sandbox because
  the sandbox prevents required registry access. No registry settings changed.
