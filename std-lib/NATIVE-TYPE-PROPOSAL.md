# Minimal library-defined native value contract

Status: adopted for implementation under the owner's delegated decision on
2026-10-30; the bounded scalar implementation and acceptance proof are complete.
See [native evidence](tests/native-type/NATIVE-EVIDENCE.md). The owner
authorized these decisions on their behalf, preferring VB6 conventions when
they do not break agreed definitions. This is the next native-datatype
item in [the compiler workplan](../compiler/UBE_Compiler_v3/Roadmap.md) and
[the library workplan](ROADMAP.md). The owner requested the next-step goal on
2026-10-30. The adopted additions below preserve ordinary record syntax and
semantics; the remaining frozen language rules stay authoritative.

## Adopted mechanism

Add a representation clause to a new form of `Type`, and explicit operation
bindings to intrinsic declarations. Ordinary field-only records are unchanged.
The first test-only value is Octet; it is not an alias for the builtin Byte.

```vb
Type Octet As Byte
End Type

Intrinsic Function PackOctet(ByVal Storage As Byte) As Octet
Attribute PackOctet.UBE_Primitive = "Value.Pack"
End Function

Intrinsic Function UnpackOctet(ByVal Value As Octet) As Byte
Attribute UnpackOctet.UBE_Primitive = "Value.Unpack"
End Function
```

`Type Name As StorageType` has no ordinary fields or executable members. Its
payload is inaccessible through field syntax. The compiler supplies neutral
initialization and value copying from the representation. Different declared
types stay distinct even when their storage is identical. There is no implicit
conversion between Byte and Octet, or between two native value types.
Implicit Print formatting and Boolean condition conversion are also rejected;
ordinary procedures must explicitly supply formatting and predicates.

`UBE_Primitive` is explicit metadata on the intrinsic declaration. Its target
must name that declaration; its role and full signature are validated. No
operation is selected from a type/procedure spelling such as Octet or PackOctet.
Changing both names must preserve behavior. Unknown roles, conflicting bindings,
wrong signatures and unsupported representations are diagnostics, not fallback
symbol calls. The attribute is an adopted semantic addition, not a previously
ignored attribute that the compiler may silently start interpreting.
This scalar contract binds Value.Pack/Value.Unpack. The subsequent approved
storage roles use the same intrinsic attribute syntax with their own exact
signatures; see [managed evidence](MANAGED-STORAGE-EVIDENCE.md). Ordinary
member/designer attributes remain inert, as the
frozen specification requires; imported VB6 metadata gains no executable role.

Pack requires exactly one ByVal parameter of the representation type and the
native type as result. Unpack requires exactly one ByVal native parameter and
the representation as result. Neither body contains UBE statements. Their
visibility follows the existing declaration rules; the test proof uses explicit
callable conversion operations and does not claim v2 implements module privacy.
Opaque payload access is enforced by the type, independently of procedure
visibility. No address, allocation, destructor or lifetime hook is introduced.
Only the native type's declaring module may supply its primitive bindings;
consumers call the operations supplied by that module. Native declarations and
binding headers/terminators cannot span source modules. Attribute targets,
property names and role identifiers use the existing case-insensitive matching.
The role value is one string literal. Other retained metadata remains inert.

## Representation and ABI

Represent the native value as an ordinary native aggregate with one hidden
storage component. Octet has size 1 and alignment 1. Its LLVM value type is a
nominal one-component structure containing i8, not a heap box or a generic
runtime object. Pack/unpack lower to component insertion/extraction. ByVal
parameters/results use that aggregate; ByRef points to the caller's exact type.
The representation name determines scalar signedness and checked conversions.

This deliberately specifies an aggregate ABI, rather than promising that a
nominal type is an LLVM scalar alias. It does not define a foreign-export ABI.
Zero state, storage, calls, copies and returns must work for ordinary library
type names with no backend special case for Octet. The implementation uses
the existing validated scalar-storage mechanisms; initially Byte, Integer and
Long can be qualified independently. Other representations must diagnose until
their layout/operations are supported and tested. No arbitrary size/alignment,
managed storage, recursive representation or nesting native representations
is assumed by this proof.

A native type can be default-initialized/copied without declaring conversion
operations. Each declared new intrinsic needs exactly one operation binding;
at most one Pack and one Unpack declaration binds each native type in the
compilation. A missing attribute on an otherwise unknown intrinsic is an
unsupported-intrinsic error. Existing bootstrap intrinsic declarations keep
their current explicit registry/signature checks; metadata never provides a
fallback arbitrary external symbol call.
Registered legacy bootstrap intrinsic names must still match their complete
private return/parameter/passing-mode signature. A spelling such as StringLength
cannot substitute for a missing native binding; with an explicit valid binding
the same spelling has no special native meaning.

Native values support equality/inequality of the same declared type by their
representation value. Ordering and arithmetic require explicit ordinary
procedures; no new operator-overloading or implicit numeric promotion is added.
Ordinary record equality and opaque managed representations remain separate
obligations. Bounded ordinary array/record copying and lifecycle now have the
separate managed-foundation proof; this does not qualify managed Pack/Unpack.

## Ordinary operations and failure

Conversion/domain procedures remain ordinary UBE code. Infallible pack/unpack
preserve existing Err and require no extra failure-status ABI. Checked primitive
argument/result conversions keep their frozen behavior: invalid constants
diagnose; runtime conversion failure gives neutral storage plus Err.

The test-only TrySet procedure accepts Long plus a ByRef destination, explicitly
checks 0..255, returns False without modifying that destination for -1/256,
and otherwise packs/stores the value and returns True. False is a documented
ordinary result of this test procedure, not a language conversion failure;
the procedure does not inspect, clear or set Err. Its Boolean result is a fresh
per-call status, independent of a stale Err. No public UBECore API is selected.
The later approved fallible managed-storage proof has its own fresh-status,
root/copy/cleanup contract and acceptance evidence. This scalar proof does not
settle or expand that ABI; Value.Pack/Value.Unpack remain scalar-only.

## Decision recorded under owner delegation

1. Adopt the new `Type Name As StorageType ... End Type` form with opaque
   payload and synthesized zero/copy behavior. Existing `Type` field rules stay
   intact; the empty native form is an explicit grammar addition.
2. Adopt `UBE_Primitive = "Value.Pack" / "Value.Unpack"` on intrinsic
   declarations, and the aggregate ABI described above. Intrinsic attribute
   blocks and this attribute's meaning are explicit grammar/semantic additions.
3. Adopt representation equality, explicit conversion procedures, and defer
   user lifetime callbacks and the managed failure ABI until they are needed.

The considered alternative was to prove
an ordinary `Type` with one public Byte field and named UBE operations. That is
a useful baseline but does not prove opacity, representation metadata or new
intrinsic binding. It cannot be reported as completion of the general native-
datatype mechanism item.

## Independent acceptance before implementation

| Obligation | Required result |
|---|---|
| Ordinary names | Two differently named native types with Byte representation work identically, while cross-type assignment/ByRef binding is rejected. |
| Layout | Size/alignment 1 for Octet; exact i8 aggregate payload in LLVM; no heap allocation or runtime constructor for pack/unpack. |
| Neutral/copy/calls | Default 0; assign/copy 255; original mutation does not change copy; ByVal is isolated, ByRef updates caller, returned value is independent. |
| Binding | Renamed pack/unpack work from explicit metadata. Missing/unknown/wrong-signature/wrong-target/duplicate/conflicting metadata diagnoses before output. |
| Opaque access | Access through a guessed field, raw address or a numeric implicit conversion is rejected. |
| Equality | Same-type 0=0 and 255<>0 succeed; unrelated native types cannot compare or convert; ordering is rejected. |
| Failure status | TrySet returns True/False/True for 255/-1/0, preserves destination on False, and gives the same statuses with a pre-existing Err. |
| Existing conversions | Direct pack's Byte parameter diagnoses constant -1/256; runtime-dependent out-of-range conversion remains neutral plus Err. |
| Tool trust | Both source-built v2 stages satisfy independent native/rejection oracles and emit identical LLVM; the v2 source fixed point and inherited corpus remain intact. |

Before implementation, test-only ordinary-record programs establish the existing
value/storage/call baseline. They must be labelled as such and kept out of the
production UBECore manifest. The owner's delegation authorizes implementing the
above decision. No fresh v3 production scaffold is needed for this
bounded mechanism proof.

## Existing-language baseline completed

`rtk proxy powershell -NoProfile -File std-lib/tools/check-value-record.ps1`
passes eight preparatory assertions across both accepted v2 stages. See
[the exact baseline evidence](tests/native-type/BASELINE-EVIDENCE.md).
This proves the existing storage/call/value foundations and makes their limits
concrete; it does not establish the new mechanism's behavioral acceptance.

## Mechanism acceptance

The implementation and its independently specified source cases are checked by
`std-lib/tools/check-native-type.ps1`. The source-built v2 gate runs that proof
and the existing-record baseline before publishing its accepted tool selection.
The complete result, exact identities and limits are recorded under
`tests/native-type/`. No public UBECore API or fresh v3 scaffold is introduced.
