# UBE additions, datatypes, and primitive boundaries

This is a planning inventory for the finished standard library and the support
around it, as requested on 2026-10-30. It does not add declarations or approve
new names. No API listed here is implemented by the fresh `std-lib` project.
The VB6 and VBA7 compatibility baseline is inventoried separately in
[`vb6-runtime.md`](vb6-runtime.md).

`Required` means the cited UBE language contract establishes the behavior.
`Capability` means a reusable need is documented but its new public name,
signature, representation, or exact package remains undecided. `Compiler` and
`Substrate` entries explain support required below ordinary library calls.
`Historical` entries identify private hooks for audit; they are not fresh
UBECore APIs. The compiler is responsible for recognizing language constructs;
library code implements reusable behavior wherever practical.

## Local sources

| Key | Authority and scope |
|---|---|
| S1 | [Core language specification](../../lang-doc/language-spec.md), especially §§4, 6–15. It and the focused contracts take precedence over expanded examples. |
| S2 | [Expanded approved definition](../../lang-doc/v3-language-definition.md), especially §§3–6. |
| S3 | [Conversion table](../../lang-doc/conversion-table.md). |
| S4 | [Threading and memory model](../../lang-doc/threading.md). |
| S5 | [Managed-memory contract](../../lang-doc/managed-memory.md). |
| S6 | [Foreign ABI](../../lang-doc/foreign-abi.md). |
| S7 | [Bootstrap intrinsic ABI](../../lang-doc/bootstrap-intrinsics.md). These are private bootstrap declarations. |
| S8 | [Architecture](../../project-docs/architecture.md) and [fresh-library design](../DESIGN.md). |
| S9 | [Historical compiler-needed facilities](../../compiler/archived/UBE_Compiler_v4/TASK0_DECISIONS.md#library-and-compiler-support-boundary) and [reuse inventory](../../compiler/archived/UBE_Compiler_v4/REUSE_PLAN.md#library-extraction-candidates). Evidence of needs, not inherited API approval. |
| S10 | [Deferred decisions](../../lang-doc/deferred-questions.md). |
| S11 | [Historical v3 intrinsic declarations](../../compiler/archived/UBE_Compiler_v3/BootstrapIntrinsics.bas). |
| S12 | [Archived private library hooks](../../archive/source-library/src/portable/RuntimeIntrinsics.bas). Source inventory only; no implementation is imported. |
| S13 | [Project/resource/library formats](../../lang-doc/project-files.md) and [version identities](../../project-docs/versioning.md). |
| S14 | [Historical v4 compiler-support hooks](../../compiler/archived/UBE_Compiler_v4/support/src/SupportIntrinsics.bas). A third private boundary, not fresh UBECore API. |
| V1 | [Microsoft: 64-bit VBA overview](https://learn.microsoft.com/en-us/office/vba/language/concepts/getting-started/64-bit-visual-basic-for-applications-overview), consulted 2026-10-30 for the owner-requested VBA7 inventory extension. |

## Language datatypes and value categories

These must be understood and supported by UBECore, but their declarations and
static rules are compiler responsibilities. This table deliberately does not
adopt VB6's internal runtime layouts.

| Identifier | Kind | Purpose/contract | Owner/status | Local source |
|---|---|---|---|---|
| `Boolean` | Core scalar | Logical value; source representation is not exposed. Numeric conversion gives False = 0, True = -1; foreign ABI emits signed int32. | Compiler + library support / Required | S1 §4; S3; S6 |
| `Byte` | Core scalar | Unsigned 8-bit integer. | Compiler + library support / Required | S1 §4 |
| `Integer` | Core scalar | Signed 16-bit integer. | Compiler + library support / Required | S1 §4 |
| `Long` | Core scalar | Signed 32-bit integer. | Compiler + library support / Required | S1 §4 |
| `LongLong` | UBE scalar addition | Signed 64-bit integer; thread IDs, array bounds and indexes use the documented integer domains. | Compiler + library support / Required | S1 §§4, 13 |
| `IntPtr` | UBE scalar addition | Signed target-pointer-sized integer; a number, not dereferenceable storage. | Compiler + library support / Required | S1 §§4, 14; S3 |
| `UIntPtr` | UBE scalar addition | Unsigned target-pointer-sized integer; checked mixed arithmetic and explicit foreign pointer facilities. | Compiler + library support / Required | S1 §§4, 14; S3 |
| `Single` | Core scalar | IEEE-754 binary32; floating NaN/infinity behavior differs from checked integer arithmetic. | Compiler + library support / Required | S1 §§4, 14 |
| `Double` | Core scalar | IEEE-754 binary64. | Compiler + library support / Required | S1 §§4, 14 |
| `Currency` | Core scalar | Signed 64-bit fixed point, scale 10,000; checked arithmetic. | Compiler + library support / Required | S1 §§4, 14 |
| `Decimal` | Core scalar | 128-bit storage; separate sign, 96-bit coefficient and scale 0–28; ties-to-even reduction; no NaN/infinity. A directly declarable UBE type, not merely a VB6 Variant subtype. | Compiler + library support / Required | S1 §§4, 14 |
| `Date` | Core scalar | Timezone-neutral Gregorian years 0001–9999, nanosecond resolution; comparison, no core arithmetic or implicit numeric serial conversion. | Compiler + library support / Required | S1 §§4, 14; S3 |
| `String` | Managed value | Unicode value with value-copy semantics; distinguish Unicode scalar positions from UTF-8 byte positions. Input/foreign text contracts explicitly use UTF-8. | Compiler + library support / Required | S1 §§2, 4; S2 §4; S6 |
| `String * n` | Fixed-length value | Exactly n Unicode scalar values, including n = 0; truncation or right-padding with spaces; length participates in exact ByRef matching. | Compiler + library support / Required | S1 §4; S3 |
| `Object` | Managed reference | Reference to any class identity; Set preserves identity; no automatic object-to-scalar conversion. | Compiler + library support / Required | S1 §§4, 12; S3 |
| `Variant` | Managed tagged value | Preserves exact source tag and payload, including arrays/custom values/references; extraction applies checked conversions. | Compiler + library support / Required | S1 §§4, 14; S3 |
| `Any` | Foreign parameter marker | Legal only in external declaration parameters; not a stored general-purpose datatype. | Compiler + ABI / Required | S1 §§4, 11; S3 |
| `T()` | Array value category | Arbitrary rank, LongLong bounds/indexes, independent value copies with source bounds; object elements retain shared identities. | Compiler + library support / Required | S1 §4; S3 |
| `Type` | User-defined value category | Same-declaration semantic value copy; inline nonrecursive fields and hidden managed recursive edges; no structural conversion. | Compiler + library support / Required | S1 §4; S2 §4 |
| `Enum` | User-defined scalar category | Underlying LongLong by default, optionally Long; checked integer participation; numeric string conversion. | Compiler + library support / Required | S1 §4; S3 |
| `Class` | User-defined reference category | Strong object identity, parameterless construction, interface implementation; no user-class implementation inheritance. | Compiler + library support / Required | S1 §§5, 12; S2 §4 |
| `Interface` | Reference contract category | Signatures and interface-typed references, without bodies or implementation inheritance. | Compiler + library support / Required | S1 §5 |
| `Form` | Framework reference category | Explicit load/unload lifecycle plus a project default-instance slot; allocation alone does not create a native window. | Compiler + framework / Required | S1 §§12–13 |
| `Control` | Framework reference category | Containing framework context and load/unload rules; no project default-instance slot. | Compiler + framework / Required | S1 §12 |
| `Empty` | Variant state | Variant's neutral initial state; converts to requested neutral scalar/string/reference successfully. | Compiler + library support / Required | S1 §14; S3 |
| `Null` | Variant state | Propagates through Variant arithmetic/comparison; fixed-type extraction fails; IsNull tests it. | Compiler + library support / Required | S1 §14; S3 |
| `Nothing` | Reference state | Neutral reference; does not apply to a hidden recursive Type edge. | Compiler + library support / Required | S1 §§4, 12 |
| `True` | Boolean constant | Logical true; checked numeric conversion uses -1, including failure for unsigned destinations unable to represent it. | Compiler + library support / Required | S1 §14; S3 |
| `False` | Boolean constant | Logical false; numeric conversion uses 0. | Compiler + library support / Required | S1 §14; S3 |

## Identifier type characters

These are syntax annotations, not additional datatypes or overload names.
A suffix must agree with the declaration; it is not part of name identity.
Arrays, enums, custom/reference types, Variant and fixed strings need an As
clause. Integer literal suffixes are restricted to %, &, and ^; other literal
forms follow the normative grammar rather than this identifier table.

| Identifier | Kind | Purpose/contract | Owner/status | Local source |
|---|---|---|---|---|
| `%` | Identifier type character | Integer annotation. | Compiler / Required | S1 §4 |
| `&` | Identifier type character | Long annotation; distinguish adjacent integer suffix from concatenation. | Compiler / Required | S1 §§2, 4 |
| `^` | Identifier type character | LongLong annotation; also a permitted integer literal suffix, and exponentiation in operator context. | Compiler / Required | S1 §§2, 4, 8 |
| `!` | Identifier type character | Single annotation; distinguish member/bang access context. | Compiler / Required | S1 §4 |
| `#` | Identifier type character | Double annotation; distinguish date delimiters and directive context. | Compiler / Required | S1 §§2, 4 |
| `@` | Identifier type character | Currency annotation. | Compiler / Required | S1 §4 |
| `$` | Identifier type character | String annotation; legacy String-returning spellings do not create an independent same-name overload. | Compiler / Required | S1 §4 |

## VBA7 type and declaration compatibility

The owner included VBA7 in the target inventory on 2026-10-30. Inclusion puts
these items on the design checklist; it does not silently amend the frozen UBE
grammar, type system, or declaration rules. `CLngLng` and `CLngPtr` are covered
by the callable compatibility inventory.

| Identifier | Kind | Purpose/contract | Owner/status | Local source |
|---|---|---|---|---|
| `LongLong (VBA7)` | Compatibility datatype | VBA7's signed 64-bit integral type is available on 64-bit Office. UBE already defines LongLong; apply UBE's checked conversion rules rather than importing VBA7 conversion restrictions automatically. | Compiler + library / Existing UBE type; compatibility differences to document | V1; S1 §§4, 14; S3 |
| `LongPtr` | Compatibility type alias | VBA7 resolves this alias to Long on 32-bit Office and LongLong on 64-bit Office. UBE uses IntPtr/UIntPtr; no automatic alias or foreign-pointer policy is approved here. | Compiler/ABI / Compatibility decision required | V1; S1 §4; S3 |
| `PtrSafe` | External-declaration modifier | VBA7 declaration annotation; does not itself widen pointer parameters/results. Not present in frozen UBE syntax. | Compiler/import compatibility / Decision required | V1; S1 §11 |
| `DefLngPtr` | Legacy default-type statement | VBA7 pointer-sized default typing by identifier range. UBE's mandatory explicit typing remains in force; inventory presence does not authorize implicit declarations. | Compiler/import compatibility / Conflicts with frozen explicit-typing rule | V1; S1 §5 |
| `DefLngLng` | Legacy default-type statement | VBA7 64-bit default typing by identifier range; same UBE explicit-typing restriction. | Compiler/import compatibility / Conflicts with frozen explicit-typing rule | V1; S1 §5 |
| `VBA7` | Conditional compilation constant | VBA version selection in imported source; value in UBE requires an explicit compatibility contract. | Compiler/project configuration / Decision required | V1; S1 §2 |
| `Win64` | Conditional compilation constant | VBA process/platform selection; must not be inferred from UBE's build host when compiling another target. | Compiler/project configuration / Decision required | V1; S2 §6 |
| `vbLongLong` | Variant type-code constant | VBA7 LongLong VarType discriminator; numeric mapping to UBE's versioned Variant tags must be established. | Compatibility library + compiler / Decision required | V1; S1 §14 |

## Defined portable library surface

This is the named UBE-specific surface already specified by the project. VB6
names such as `Err`, `IsNull`, and conversion functions also appear in the
compatibility inventory; the rows here identify additional UBE obligations.
Unstated method signatures and construction APIs remain open.

| Identifier | Kind | Purpose/contract | Owner/status | Local source |
|---|---|---|---|---|
| `CollectGarbage()` | Function As Long | Full synchronous collection snapshot with eligible finalization; 1 if reclamation or eligible termination occurred, otherwise 0. Automatic GC remains mandatory. | UBECore + collector / Required | S1 §12; S2 §4.1; S5 |
| `CurrentThreadId()` | Function As LongLong | Portable process-local thread identity, separate from a native OS handle or ID. | UBECore + thread substrate / Required | S2 §5.3 |
| `ThreadIsAlive(Id)` | Function As Boolean | False without error for a completed issued ID; invalid never-issued IDs fail in the controlled manner. | UBECore + thread substrate / Required | S2 §5.3 |
| `ThreadWait(Id, Optional TimeoutMilliseconds = -1)` | Function As Long | 1 for completion, 0 for timeout/cancellation; success makes worker actions visible; waiting on self is a controlled error. | UBECore + thread substrate / Required | S2 §5.3; S4 |
| `ThreadRequestStop(Id)` | Function As Long | Sticky cooperative stop and wakeup; never forcibly terminates; completed issued ID returns 0 without error. | UBECore + thread substrate / Required | S2 §5.3; S4 |
| `ThreadStopRequested()` | Function As Boolean | Query current worker's stop flag; cancellation alone does not change Err. | UBECore + thread substrate / Required | S2 §5.3; S4 |
| `ThreadYield()` | Sub | Offer scheduling opportunity; correctness cannot rely on another thread running. | UBECore + thread substrate / Required | S2 §5.3 |
| `AtomicBoolean` | Class | One Boolean shared atomic cell; applicable operations are sequentially consistent. | UBECore + atomic primitive / Required | S2 §5.2; S4 |
| `AtomicBoolean.Load` | Method | Observe one Boolean atomic value. | UBECore / Required operation family; signature pending | S2 §5.2 |
| `AtomicBoolean.Store` | Method | Replace one Boolean atomic value. | UBECore / Required operation family; signature pending | S2 §5.2 |
| `AtomicBoolean.Exchange` | Method | Atomically replace and observe previous Boolean value. | UBECore / Required operation family; signature pending | S2 §5.2 |
| `AtomicBoolean.CompareExchange` | Method | Atomic compare/conditional replacement. | UBECore / Required operation family; signature pending | S2 §5.2 |
| `AtomicLong` | Class | One signed 32-bit shared atomic cell. | UBECore + atomic primitive / Required | S2 §5.2; S4 |
| `AtomicLong.Load` | Method | Observe atomic Long. | UBECore / Required operation family; signature pending | S2 §5.2 |
| `AtomicLong.Store` | Method | Replace atomic Long. | UBECore / Required operation family; signature pending | S2 §5.2 |
| `AtomicLong.Exchange` | Method | Replace atomically and observe previous Long. | UBECore / Required operation family; signature pending | S2 §5.2 |
| `AtomicLong.CompareExchange` | Method | Atomic compare/conditional replacement. | UBECore / Required operation family; signature pending | S2 §5.2 |
| `AtomicLong.Increment` | Method | Atomic numeric increment. | UBECore / Required operation family; signature pending | S2 §5.2 |
| `AtomicLong.Decrement` | Method | Atomic numeric decrement. | UBECore / Required operation family; signature pending | S2 §5.2 |
| `AtomicLong.Add` | Method | Atomic numeric addition. | UBECore / Required operation family; signature pending | S2 §5.2 |
| `AtomicLongLong` | Class | One signed 64-bit shared atomic cell. | UBECore + atomic primitive / Required | S2 §5.2; S4 |
| `AtomicLongLong.Load` | Method | Observe atomic LongLong. | UBECore / Required operation family; signature pending | S2 §5.2 |
| `AtomicLongLong.Store` | Method | Replace atomic LongLong. | UBECore / Required operation family; signature pending | S2 §5.2 |
| `AtomicLongLong.Exchange` | Method | Replace atomically and observe previous LongLong. | UBECore / Required operation family; signature pending | S2 §5.2 |
| `AtomicLongLong.CompareExchange` | Method | Atomic compare/conditional replacement. | UBECore / Required operation family; signature pending | S2 §5.2 |
| `AtomicLongLong.Increment` | Method | Atomic numeric increment. | UBECore / Required operation family; signature pending | S2 §5.2 |
| `AtomicLongLong.Decrement` | Method | Atomic numeric decrement. | UBECore / Required operation family; signature pending | S2 §5.2 |
| `AtomicLongLong.Add` | Method | Atomic numeric addition. | UBECore / Required operation family; signature pending | S2 §5.2 |
| `AtomicObject` | Class | One managed object-reference cell; identity and GC rooting remain valid under competing access. | UBECore + atomic/GC primitive / Required | S2 §5.2; S4; S5 |
| `AtomicObject.Load` | Method | Observe shared strong reference. | UBECore / Required operation family; signature pending | S2 §5.2 |
| `AtomicObject.Store` | Method | Publish shared strong reference. | UBECore / Required operation family; signature pending | S2 §5.2 |
| `AtomicObject.Exchange` | Method | Atomically replace reference identity. | UBECore / Required operation family; signature pending | S2 §5.2 |
| `AtomicObject.CompareExchange` | Method | Atomic identity comparison and conditional replacement. | UBECore / Required operation family; signature pending | S2 §5.2 |
| `ThreadEvent` | Class | Manual- or auto-reset synchronization object; construction is parameterless and configuration uses a factory. | UBECore + platform primitive / Required | S4 Coordination library |
| `CreateThreadEvent(Optional ManualReset = False, Optional InitiallySignaled = False)` | Factory Function As ThreadEvent | Factory parameters are ByVal Boolean. | UBECore / Required signature | S4 Coordination library |
| `ThreadEvent.Wait(timeout)` | Method | Common 1/0 wait convention; consumes auto-reset signal or observes manual-reset signal; cancellable. | UBECore / Required | S4 |
| `ThreadEvent.Set` | Method | Idempotent signal; 1 on success, 0 plus Err for invalid/unloaded object. | UBECore / Required | S4 |
| `ThreadEvent.Reset` | Method | Idempotent reset; 1 on success, 0 plus Err for invalid/unloaded object. | UBECore / Required | S4 |
| `Semaphore` | Class | Bounded count; fair FIFO waiter selection subject to cancellation/host scheduling. | UBECore + platform primitive / Required | S4 |
| `CreateSemaphore(InitialCount, MaximumCount)` | Factory Function As Semaphore | Factory parameters are ByVal LongLong. | UBECore / Required signature | S4 Coordination library |
| `Semaphore.Wait(timeout)` | Method | Consume a permit; 1 on success, 0 for timeout/cancellation; genuine failures set Err. | UBECore / Required | S4 |
| `Semaphore.Release(Optional Count = 1)` | Method | Add permits; 1 success, 0 plus Err for invalid count, overflow, or invalid object. | UBECore / Required | S4 |
| `MessageQueue` | Class | FIFO Variant messages; value payloads copied, object identities retained. | UBECore + synchronization/GC / Required | S4 |
| `MessageQueue.Enqueue(ByVal Value As Variant)` | Method | Copy a message into the FIFO, with the specified publication ordering. | UBECore / Required contract; unstated result signature pending | S4 |
| `MessageQueue.Dequeue(ByRef Value As Variant, timeout)` | Method | 1 and update destination only on success; timeout/cancellation leaves it unchanged. | UBECore / Required | S4 |
| `Err.Number` | Thread-local error property | Inspect latest recoverable failure; a successful operation does not clear old error state. | UBECore + error substrate / Required | S1 §9 |
| `Err.Clear` | Thread-local error method | Explicitly clear current thread's error. | UBECore + error substrate / Required | S1 §9 |

All approved waits use signed LongLong milliseconds: -1 indefinite, 0 polling,
other negative values invalid. Their common result is Long 1 on satisfaction,
0 on timeout/cancellation; a genuine failure also sets current-thread Err.
The precise complete atomic API ledger is still required: the expanded
definition names the applicable operation family but does not freeze every
return type, initialization API, failure result, or comparison convention.

## Required behavior without a newly approved public name

The identifiers in this table are descriptive inventory labels, not proposed
callable declarations. Preserve the distinction while designing the new API.

| Identifier | Kind | Purpose/contract | Owner/status | Local source |
|---|---|---|---|---|
| Checked scalar conversion support | Capability | Full normative numeric/Boolean/String relationship matrix, checked ranges and ties-to-even conversion. | UBECore + compiler selection / Required behavior; names pending | S3; S1 §14 |
| Invariant scalar parsing and formatting | Capability | Complete parse and canonical locale-independent text, including floating special values. | UBECore / Required behavior; API ledger pending | S3; S2 §3 |
| Decimal arithmetic support | Capability | Exact coefficient/scale arithmetic and checked rounding/overflow. | UBECore + minimal primitives / Required behavior; names pending | S1 §14 |
| Currency arithmetic support | Capability | Checked fixed-point operations and conversions. | UBECore + compiler / Required behavior; names pending | S1 §14 |
| Invariant Date parsing and formatting | Capability | Approved Gregorian/time literal forms and canonical text; no accidental serial-number conversion. | UBECore / Required behavior; names pending | S1 §§2, 14; S3 |
| Fixed-string resizing | Capability | Scalar-count truncation/padding succeeds without setting Err. | UBECore + compiler / Required behavior; names pending | S1 §4; S3 |
| Variant construction and extraction | Capability | Exact tags and independent value copies; checked runtime-tag conversion and reference Set rules. | UBECore + compiler/GC / Required behavior; names pending | S3; S5 |
| Array storage and copying | Capability | Arbitrary ranks, exact type/rank matching, source bounds, checked offsets, atomic failure preservation of existing array. | UBECore + compiler/GC / Required behavior; names pending | S1 §4 |
| Recursive custom-value storage | Capability | Hidden lazy recursive edges, independent semantic copies, nonmaterializing equality, bounded deep traversal. | UBECore + compiler/GC / Required behavior; names pending | S1 §4; S2 §4 |
| Unicode scalar decode/encode/iteration | Capability | Strict UTF-8 boundary handling with explicit byte/scalar positions. | UBECore / Documented need; new APIs pending | S1 §2; S9 |
| Unicode letter-category lookup | Capability | Versioned Unicode 18 Letter membership for identifiers. | UBECore + pinned data / Required behavior; new API pending | S1 §2; S9 |
| Unicode simple case folding | Capability | Unicode 18 keyword/name identity; preserve original spellings, no implicit normalization. | UBECore + pinned data / Required behavior; new API pending | S1 §2; S9 |
| Ordinal/folded text comparison | Capability | Explicit scalar/binary versus versioned text-fold comparison. | UBECore / Required behavior; new APIs pending | S1 §14; S9 |
| Bounded text/chunk construction | Capability | Efficient growth, explicit ownership and limits; measure allocations and copied bytes. | UBECore / Documented need; representation/API pending | S8; S9 |
| Bounded vectors/storage | Capability | Checked growth/indexes and controlled allocation failure. | UBECore / Documented need; generic/type-specific API undecided | S9 |
| Hash maps | Capability | Efficient lookup with explicit key/equality/hash contracts and collision tests. | UBECore / Documented need; APIs pending | S9 |
| Hash sets | Capability | Membership and uniqueness without observable hash iteration order in compiler output. | UBECore / Documented need; APIs pending | S9 |
| Stable sorting | Capability | Deterministic stable ordering using explicit comparisons. | UBECore / Documented need; APIs pending | S9 |
| SHA-256 and incremental hashing | Capability | Known-vector-tested bounded/incremental hashing for content/package identities. | UBECore or tooling support / Documented need; package/API unresolved | S9; S13 |
| Bounded binary readers | Capability | Checked lengths/offsets and explicit byte order for corrupt/truncated input. | UBECore / Documented need; APIs pending | S9; S13 |
| Bounded binary writers | Capability | Checked growth, canonical encoding, failure cleanup. | UBECore / Documented need; APIs pending | S9; S13 |
| Lexical path operations | Capability | Portable lexical handling distinct from filesystem identity and target-specific casing. | UBECore / Documented need; APIs pending | S8; S9 |
| Bounded file reading | Capability | Explicit encoding/size checks, malformed input and environmental failures. | UBECore + platform library / Documented need; APIs pending | S8; S9 |
| Atomic file publication | Capability | Temporary sibling, complete write/flush/close/replace or controlled failure without partial final output. | UBECore + platform library / Documented need; APIs pending | S7; S9 |
| Process invocation and capture | Capability | Separate arguments, bounded output, timeout/cancellation and handle cleanup. | General API placement undecided; compiler-specific adapter stays tooling support | S8; S9 |
| Monotonic elapsed-time measurement | Capability | Nonsemantic measurements for repeatable profiling; unavailable status explicit. | Tooling support + platform / New public API undecided | S7; S9 |
| CPU/peak-memory measurement | Capability | Resource measurements with provenance; no impact on target semantics. | Tooling support + platform / New public API undecided | S7; S9 |
| Bounded work queue/executor | Capability | Fixed resource budget, cancellation, drain, private results, shared immutable inputs. | Reusable concurrency / Need recorded; fresh API pending | S8; S9 |
| Explicit foreign pinning | Capability | Bounded scoped address stability for ABI transitions; never permanent general storage. | UBECore + compiler/substrate / Required behavior; names pending | S5; S6 |
| Active callback-source registration | Capability | Loaded forms, timers, listeners/watchers retain process liveness until explicitly closed/unloaded. | Framework/library + substrate / Required behavior; names pending | S1 §13; S2 §5.4 |
| Synchronous UI dispatch | Capability | Route UI-owned calls while preserving results/errors; detect direct dispatch-wait cycles. | Framework + platform / Required behavior; names pending | S4 |
| Portable graphics calls | Capability | Ordinary separately linked library functions; classic graphics statements remain reserved compatibility syntax. | Graphics/framework library / Deferred API | S10 |
| Explicit locale-sensitive conversion | Capability | Deliberate locale API, separate from invariant defaults. | UBECore/platform services / Required distinction; names pending | S1 §14; S3 |

## Compiler constructs and lifecycle hooks

These names explain the compiler/library boundary. They are not additional
ordinary UBECore functions to expose with hard-coded name dispatch.

| Identifier | Kind | Purpose/contract | Owner/status | Local source |
|---|---|---|---|---|
| `Main` | Entry procedure contract | Sole parameterless Sub Main or Function Main As Long in an executable; libraries have no source entry point. | Compiler + process entry / Required | S1 §6.1 |
| `CallNew` | Thread creation syntax | Statically resolved Sub, parenthesized ByVal captures evaluated left-to-right before worker starts; independent value snapshots/shared object identities; LongLong ID, 0 failure. | Compiler lowering + thread substrate / Required | S1 §13; S2 §5.1–5.2 |
| `SyncLock` | Structured synchronization syntax | Reentrant object monitor; guaranteed release on every exit edge; safe retention of monitor users. | Compiler cleanup + monitor primitive / Required | S2 §5.2; S4 |
| `AndAlso` | Operator | Boolean short circuit, preserving skipped-operand absence of effects. | Compiler / Required | S1 §§8, 14 |
| `OrElse` | Operator | Boolean short circuit, preserving skipped-operand absence of effects. | Compiler / Required | S1 §§8, 14 |
| `IsNot` | Operator | Negated reference identity, equivalent to Is Not. | Compiler + identity support / Required | S1 §8 |
| `ByVal` | Parameter/capture modifier | Value semantics for arrays/custom values; object-reference copy retains identity. | Compiler + copy support / Required | S1 §5; S2 §5.2 |
| `ByRef` | Parameter modifier | Exact writable storage alias for dynamic call; aliases cannot escape; hooks disallow ordinary bypass. | Compiler / Required | S1 §§5, 7 |
| `New` | Reference construction syntax | Parameterless class/form/control identity construction; not for custom Type recursive edges. | Compiler + allocation/lifecycle / Required | S1 §§4, 12 |
| `Set` | Reference assignment syntax | Mandatory reference assignment, including references entering/leaving Variant; identity retained. | Compiler + library/GC / Required | S1 §12 |
| `Load` | Framework statement | Load statically known form/control reference synchronously and register active event source. | Compiler + framework / Required | S1 §12 |
| `Unload` | Framework statement | Cancellable form/control unload, admission closure, active-call drain, alias clearing; not ordinary class disposal. | Compiler + framework / Required | S1 §12; S4 |
| `WithEvents` | Declaration/subscription syntax | Strong statically bound event reference; ordered Set changes subscriptions; collectible cycles. | Compiler + event/GC support / Required | S1 §§5, 13; S4; S5 |
| `RaiseEvent` | Event syntax | Synchronous reentrant dispatch in subscription order, with snapshot/removal-before-turn rules. | Compiler + event support / Required | S1 §13; S4 |
| `On Error` | Error control-flow syntax | Explicit procedure-local trapping lowered through failure status; thread-local Err. | Compiler + error substrate / Required | S1 §9 |
| `Resume` | Error control-flow syntax | Approved retry/next/label control flow from an active handler. | Compiler / Required | S1 §9 |
| `On Get` | Variable-hook declaration | Exact user hook shape Function(ByRef Storage As T) As T; privileged local backing-storage access. | Compiler / Required; hook name user-defined | S1 §7 |
| `On Set` | Variable-hook declaration | Exact user hook shape Sub(ByRef Storage As T, ByVal Value As T); preserve effects/order. | Compiler / Required; hook name user-defined | S1 §7 |
| `Inline` | Procedure modifier | Optimization request preserving normal call semantics. | Compiler / Required | S1 §6.2 |
| `ForceInline` | Procedure modifier | Mandatory hygienic expansion or diagnostic; recursive cycles invalid. | Compiler / Required | S1 §6.2 |
| `Intrinsic` | Compiler-implemented primitive declaration | Fully qualified name + exact signature + ABI/target support; unknown/unsupported primitive is a diagnostic. Visibility is separately declared; Public Intrinsic is legal. | Compiler/substrate / Required mechanism; minimal set | S1 §6.2; S7 |
| `AddressOf` | Foreign callback syntax | Restricted external-call argument thunk; no storable closure or escaped UBE reference. | Compiler + ABI admission / Required | S1 §11; S6 |
| `Public Export` | Foreign export modifier | Foreign symbol, status ABI and metadata distinct from ordinary public UBE visibility. | Compiler + ABI substrate / Required | S1 §15; S6 |
| `Asm` | Unsafe extension syntax | Target-specific string payload; explicit unsafe configuration and separately specified payload. | Compiler/backend / Reserved envelope, payload specification separate | S1 §10 |
| `Bytecode` | Unsafe extension syntax | Backend-specific string payload; explicit unsafe configuration and separately specified payload. | Compiler/backend / Reserved envelope, payload specification separate | S1 §10 |
| `Module_Initialize` | Private lifecycle hook | Parameterless, deterministic dependency/manifest initialization before Main; cannot call directly. | Compiler + linked startup / Required | S1 §5; S2 §4.3 |
| `Module_Terminate` | Private lifecycle hook | Reverse-order termination of initialized modules, then root release; cannot call directly. | Compiler + linked shutdown / Required | S1 §5; S2 §4.3 |
| `Class_Initialize` | Private lifecycle hook | Parameterless construction; failure exposes no partial identity. | Compiler + lifecycle / Required | S1 §12; S2 §4.3 |
| `Class_Terminate` | Private lifecycle hook | Once-only eligible finalization; no resurrection; bounded safe traversal and controlled failure. | Compiler + collector / Required | S1 §12; S5 |
| `Form_Load` | Form lifecycle hook | Parameterless first-successful-load callback; does not imply Show. | Framework + compiler / Required | S1 §12 |
| `Form_Unload(ByRef Cancel As Integer)` | Form lifecycle hook | Nonzero Cancel preserves state; accepted unload closes new admissions and drains old calls. | Framework + compiler / Required | S1 §12 |
| `Control_Unload(ByRef Cancel As Integer)` | Control lifecycle hook | Corresponding cancellable control lifecycle. | Framework + compiler / Required | S2 §4.1; S1 §12 |

## Substrate capabilities that must remain explicit

These are obligations, not names of approved public intrinsics. Ordinary UBE
algorithms above this boundary must not be hidden inside a new primitive.

| Identifier | Kind | Purpose/contract | Owner/status | Local source |
|---|---|---|---|---|
| Allocation/retry boundary | Primitive capability | Collection and one retry on allocation failure; safely unwind partial construction. | Substrate + collector / Required | S5 Low-memory behavior |
| Precise managed layouts | Metadata capability | Exact managed-field/recursive-edge layouts, never integer-byte pointer guessing. | Compiler + collector / Required | S5 |
| Root publication | Primitive capability | Globals, live locals/temporaries, waits/monitors, leases and pins are exact roots. | Compiler + collector / Required | S5 |
| Managed write barrier | Versioned intrinsic capability | Every heap/global/static managed publication, including bulk-copy equivalent. | Compiler verifier + substrate / Required; callable name pending | S5 Barriers and movement |
| Safe-point rendezvous | Primitive capability | Calls, allocation, backedges, waits, yields and foreign transitions coordinate collection. | Compiler + collector/thread substrate / Required | S5 |
| Cycle tracing/finalization | Managed-memory capability | Automatic cycle-safe collection, once-only finalization, forbidden resurrection. | Collector + UBE support / Required | S5 |
| Non-tearing shared storage | Memory-model capability | Competing scalar/reference accesses remain memory-safe without LLVM data-race UB. | Compiler/backend + substrate / Required | S4 |
| Sequentially consistent atomic operations | Target primitive capability | One global sequentially consistent ordering for approved atomics. | Target substrate / Required | S4 |
| Reentrant monitor primitives | Target primitive capability | Object monitor acquisition/release and safe retained waiters; compiler emits cleanup edges. | Target substrate / Required | S4 |
| Native thread start/drain | Target primitive capability | Bounded creation, monotonic IDs, guarded/checked stack limit, completion resource reclamation. | Target substrate / Required | S4 Limits and cleanup |
| Cancellation/wait wakeup | Target primitive capability | Wake approved waits, preserve Err on cancellation/timeout, ordinary cleanup on worker return. | Target substrate + library / Required | S4 |
| Thread-local error storage | Primitive capability | Independent Err and active error handling per thread/procedure. | Substrate + compiler / Required | S1 §9; S4 |
| Native callback admission | ABI primitive capability | Register unknown foreign thread, establish Err/roots/transition, reject after shutdown. | ABI/thread/GC substrate / Required | S4; S6 |
| Opaque foreign value handles | ABI capability | Independent custom-value semantic copy and idempotent ownership release. | ABI support + compiler / Required | S6 Custom values |
| Generation-checked object leases | ABI capability | Independent leases retain roots; identity-wide unload invalidates all safely. | ABI support + collector / Required | S6 Objects and modules |
| Foreign status and diagnostic copy | ABI capability | Stable success/nonzero failure status, validated result-out parameters and bounded thread diagnostic text. | ABI support / Required; generated symbol names pending | S6 |
| Foreign metadata validation | ABI capability | Target/endianness/width/calling convention/signature/schema/ownership compatibility checks. | ABI/library tooling / Required | S6; S13 |
| Orderly library shutdown | Generated ABI capability | Close admissions, drain calls, terminate modules/objects, invalidate leases, release support. | Compiler + substrate / Required; generated entry name pending | S6 |
| Process entry/exit adapter | Platform capability | Initialize packages, invoke sole Main, respect thread/event-source liveness, orderly cleanup. | Platform + compiler / Required | S1 §§6, 13; S8 |
| Controlled fatal-failure sink | Primitive capability | Bounded noninteractive diagnostic and only safe cleanup when bookkeeping cannot preserve safety. | Substrate / Required | S5 Low-memory behavior |
| OS resource adapters | Platform capability | Files/processes/clocks/native UI operate behind explicit platform libraries; caller ownership documented. | Platform libraries / Required boundary; names pending | S8; S2 §6 |

## Appendix A — every named operation documented in the bootstrap ABI

All six named operations in S7 are listed. These exact historical signatures
are recorded for bootstrap analysis, not adopted as the new public API. The
documented tool-argument limit is 4,096 child arguments; each is passed separately.

| Identifier | Kind | Purpose/contract | Owner/status | Local source |
|---|---|---|---|---|
| `CompilerRunTool` | Historical Intrinsic Function As Long | Explicit executable + ByRef String argument array + Long count; synchronous, shell-free; child exit or documented -1/-2/-3 status; releases process/argument resources. | Compiler-support/platform private / Historical | S7 Tool process boundary |
| `CompilerMonotonicMilliseconds` | Historical Intrinsic Function As Long | Nonnegative monotonic host milliseconds; -1 unavailable; profiling only. | Compiler-support/platform private / Historical | S7 Compiler performance measurements |
| `CompilerProcessCpuMilliseconds` | Historical Intrinsic Function As Long | Nonnegative process kernel+user CPU milliseconds; -1 unavailable. | Compiler-support/platform private / Historical | S7 Compiler performance measurements |
| `CompilerPeakWorkingSetKilobytes` | Historical Intrinsic Function As Long | Peak charged physical working set in KiB; -1 unavailable. | Compiler-support/platform private / Historical | S7 Compiler performance measurements |
| `CompilerDeleteFile` | Historical Intrinsic Function As Long | Delete path or accept absence: 0; invalid path -1; host rejection -2; no shell. | Compiler-support/platform private / Historical | S7 Compiler artifact cleanup |
| `WriteAllText` | Historical compiler text-output operation | Atomic sibling temporary/flush/close/replace; 0 success, 73 open failure, 74 write/flush/close/replace failure; remove partial temporary. Declared Intrinsic in S11. | Compiler-support/platform private / Historical | S7 Compiler artifact cleanup; S11 |

## Appendix B — remaining historical declared hooks for audit

Together with Appendix A, these tables cover every distinct declared intrinsic
name in S11, S12, and S14. This is a source-name inventory, not a claim that the
historical boundaries agree in representation or fully satisfy their contracts.
In particular, v3 declares ManagedVariant payloads as String where the archived
library declares Variant. Do not copy either representation into the fresh API.
V4 support also declares the monotonic/CPU millisecond hooks as LongLong,
where S7/v3 use Long, and adds a byte-based peak-memory hook. Those signature
and unit differences require reconciliation before reuse.

| Identifier | Kind | Purpose/contract | Owner/status | Local source |
|---|---|---|---|---|
| `StringLength` | Private intrinsic | Historical UTF-8 byte-length hook returning Long; does not establish a Unicode scalar-count API. | Bootstrap/substrate / Historical | S11; S12 |
| `StringByteAt` | Private intrinsic | Historical indexed byte access; new controlled-failure contract must be tested independently. | Bootstrap/substrate / Historical | S11; S12 |
| `StringSlice` | Private intrinsic | Historical byte-range copy. | Bootstrap/library-expressible operation / Historical | S11 |
| `CompilerPeakWorkingSetBytes` | Private intrinsic As LongLong | Historical v4 peak-memory query in bytes, distinct from the Long/KiB hook in Appendix A. | Compiler support/platform / Historical; signature and unit reconciliation required | S14 |
| `StringIndexOf` | Private intrinsic | Historical byte-string search from an offset. | Bootstrap/library-expressible operation / Historical | S11 |
| `StringFromByte` | Private intrinsic | Historical one-byte string construction. | Bootstrap/substrate / Historical | S11 |
| `LongToString` | Private intrinsic | Historical Long formatting. | Bootstrap/library-expressible operation / Historical | S11; S12 |
| `CommandArgumentCount` | Private intrinsic | Historical process argument count. | Platform adapter / Historical | S11 |
| `CommandArgument` | Private intrinsic | Historical indexed process argument retrieval. | Platform adapter / Historical | S11 |
| `ReadAllText` | Private intrinsic | Historical whole-file text read. | Platform adapter / Historical | S11 |
| `StringArrayJoin` | Private intrinsic | Historical bounded chunk-array join. | Bootstrap/library-expressible operation / Historical | S11 |
| `CompilerValidateResource` | Private intrinsic | Historical resource-container validation. General readers/hash logic should not inherit compiler policy. | Compiler tooling / Historical | S11 |
| `CompilerResourceLlvmEscape` | Private intrinsic | Historical LLVM resource escaping; backend-specific policy. | Compiler/backend tooling / Historical | S11 |
| `CompilerValidateLibraryBundle` | Private intrinsic | Historical target/version/interface-pinned bundle validation. | Compiler tooling / Historical | S11 |
| `UnicodeIsLetter` | Private intrinsic | Historical Unicode letter-table query. | Pinned-data/library boundary / Historical | S11 |
| `UnicodeSimpleFoldCodePoint` | Private intrinsic | Historical Unicode simple-fold query. | Pinned-data/library boundary / Historical | S11 |
| `ManagedCollectGarbage` | Private intrinsic | Historical collector entry behind public CollectGarbage. | Collector substrate / Historical | S11; S12 |
| `ManagedVariantEmpty` | Private intrinsic | Historical Empty payload creation; source signatures differ. | Variant/GC substrate / Historical | S11; S12 |
| `ManagedVariantNull` | Private intrinsic | Historical Null payload creation; source signatures differ. | Variant/GC substrate / Historical | S11; S12 |
| `ManagedVariantFromLong` | Private intrinsic | Historical Long boxing; source signatures differ. | Variant/GC substrate / Historical | S11; S12 |
| `ManagedVariantCopy` | Private intrinsic | Historical tagged copy; source signatures differ. | Variant/GC substrate / Historical | S11; S12 |
| `ManagedVariantTag` | Private intrinsic | Historical tag query; source signatures differ. | Variant substrate / Historical | S11; S12 |
| `ManagedVariantGetLong` | Private intrinsic | Historical Long extraction; source signatures differ. | Variant substrate / Historical | S11; S12 |
| `RuntimeErrorNumber` | Private intrinsic | Historical current-thread error-number query. | Error substrate / Historical | S12 |
| `RuntimeErrorDescription` | Private intrinsic | Historical current-thread error-description copy. | Error substrate / Historical | S12 |
| `RuntimeErrorSource` | Private intrinsic | Historical current-thread error-source copy. | Error substrate / Historical | S12 |
| `RuntimeErrorClear` | Private intrinsic | Historical current-thread error clearing. | Error substrate / Historical | S12 |
| `RuntimeErrorSet` | Private intrinsic | Historical current-thread error recording. | Error substrate / Historical | S12 |
| `RuntimeCurrentThreadId` | Private intrinsic | Historical portable thread-ID query. | Thread substrate / Historical | S12 |
| `RuntimeThreadIsAlive` | Private intrinsic | Historical live/completed query. | Thread substrate / Historical | S12 |
| `RuntimeThreadWait` | Private intrinsic | Historical bounded/indefinite wait. | Thread substrate / Historical | S12 |
| `RuntimeThreadRequestStop` | Private intrinsic | Historical sticky cancellation request. | Thread substrate / Historical | S12 |
| `RuntimeThreadStopRequested` | Private intrinsic | Historical current-thread cancellation query. | Thread substrate / Historical | S12 |
| `RuntimeThreadYield` | Private intrinsic | Historical scheduler yield. | Thread substrate / Historical | S12 |
| `RuntimeAtomicLongCreate` | Private intrinsic | Historical 32-bit cell allocation. | Atomic substrate / Historical | S12 |
| `RuntimeAtomicLongDestroy` | Private intrinsic | Historical 32-bit cell cleanup. | Atomic substrate / Historical | S12 |
| `RuntimeAtomicLongLoad` | Private intrinsic | Historical 32-bit atomic load. | Atomic substrate / Historical | S12 |
| `RuntimeAtomicLongStore` | Private intrinsic | Historical 32-bit atomic store. | Atomic substrate / Historical | S12 |
| `RuntimeAtomicLongExchange` | Private intrinsic | Historical 32-bit atomic exchange. | Atomic substrate / Historical | S12 |
| `RuntimeAtomicLongCompareExchange` | Private intrinsic | Historical 32-bit atomic conditional replacement. | Atomic substrate / Historical | S12 |
| `RuntimeAtomicLongAdd` | Private intrinsic | Historical 32-bit atomic addition. | Atomic substrate / Historical | S12 |
| `RuntimeAtomicLongLongCreate` | Private intrinsic | Historical 64-bit cell allocation. | Atomic substrate / Historical | S12 |
| `RuntimeAtomicLongLongDestroy` | Private intrinsic | Historical 64-bit cell cleanup. | Atomic substrate / Historical | S12 |
| `RuntimeAtomicLongLongLoad` | Private intrinsic | Historical 64-bit atomic load. | Atomic substrate / Historical | S12 |
| `RuntimeAtomicLongLongStore` | Private intrinsic | Historical 64-bit atomic store. | Atomic substrate / Historical | S12 |
| `RuntimeAtomicLongLongExchange` | Private intrinsic | Historical 64-bit atomic exchange. | Atomic substrate / Historical | S12 |
| `RuntimeAtomicLongLongCompareExchange` | Private intrinsic | Historical 64-bit atomic conditional replacement. | Atomic substrate / Historical | S12 |
| `RuntimeAtomicLongLongAdd` | Private intrinsic | Historical 64-bit atomic addition. | Atomic substrate / Historical | S12 |
| `RuntimeThreadEventCreate` | Private intrinsic | Historical reset-mode/initial-state event allocation. | Wait substrate / Historical | S12 |
| `RuntimeThreadEventDestroy` | Private intrinsic | Historical event cleanup. | Wait substrate / Historical | S12 |
| `RuntimeThreadEventSet` | Private intrinsic | Historical event signaling. | Wait substrate / Historical | S12 |
| `RuntimeThreadEventReset` | Private intrinsic | Historical event reset. | Wait substrate / Historical | S12 |
| `RuntimeThreadEventWait` | Private intrinsic | Historical event wait. | Wait substrate / Historical | S12 |
| `RuntimeSemaphoreCreate` | Private intrinsic | Historical configured semaphore allocation. | Wait substrate / Historical | S12 |
| `RuntimeSemaphoreDestroy` | Private intrinsic | Historical semaphore cleanup. | Wait substrate / Historical | S12 |
| `RuntimeSemaphoreWait` | Private intrinsic | Historical permit acquisition. | Wait substrate / Historical | S12 |
| `RuntimeSemaphoreRelease` | Private intrinsic | Historical permit release. | Wait substrate / Historical | S12 |
| `RuntimeMessageQueueCreate` | Private intrinsic | Historical queue allocation. | Queue/GC substrate / Historical | S12 |
| `RuntimeMessageQueueDestroy` | Private intrinsic | Historical queue cleanup. | Queue/GC substrate / Historical | S12 |
| `RuntimeMessageQueueEnqueue` | Private intrinsic | Historical Variant-message publication. | Queue/GC substrate / Historical | S12 |
| `RuntimeMessageQueueDequeue` | Private intrinsic | Historical Variant-message receive. | Queue/GC substrate / Historical | S12 |
| `RuntimeAtomicObjectCreate` | Private intrinsic | Historical rooted object cell allocation. | Atomic/GC substrate / Historical | S12 |
| `RuntimeAtomicObjectDestroy` | Private intrinsic | Historical rooted object cell cleanup. | Atomic/GC substrate / Historical | S12 |
| `RuntimeAtomicObjectLoad` | Private intrinsic | Historical strong-reference atomic observation. | Atomic/GC substrate / Historical | S12 |
| `RuntimeAtomicObjectStore` | Private intrinsic | Historical strong-reference atomic publication. | Atomic/GC substrate / Historical | S12 |
| `RuntimeAtomicObjectExchange` | Private intrinsic | Historical atomic reference replacement. | Atomic/GC substrate / Historical | S12 |
| `RuntimeAtomicObjectCompareExchange` | Private intrinsic | Historical atomic reference conditional replacement. | Atomic/GC substrate / Historical | S12 |

## Decisions the inventory must not silently make

- Cross-procedure recoverable-error propagation remains explicitly open in S10.
  A stale nonzero Err cannot be treated as evidence that the latest call failed.
- Atomic construction and complete per-method signatures/results need an API
  decision. The archived wrapper signatures are not that decision.
- `ThreadWaitTimeout` is an archived convenience name; the approved public
  definition supplies an optional timeout to `ThreadWait`. Do not substitute
  the historical helper for that contract.
- Wait-object teardown terminology needs a precise public lifecycle API. S4
  requires wakeup/safe cleanup, while ordinary classes do not acquire a general
  language `Unload` statement under S1 §12.
- Compiler-needed collections/builders/hashes/executors have established needs,
  but their fresh APIs, package placement, and representation remain open.
  No generic-type surface is inferred from this inventory.
- Manual Mutex objects, condition variables, typed channels, weak references,
  class-defined value equality, dynamic AddHandler/RemoveHandler, local
  WithEvents, array-element hooks, and first-class accessor references are
  reserved beyond UBE 1.0; they are not silently added to its completion gate.
- Portable Date/Time host-clock assignment is rejected. Explicit clock mutation
  requires a later permission-aware platform API. Portable graphics APIs remain
  separately specified.
- Public foreign ABI helper symbol names/status numbers/schema details must
  come from generated/versioned contracts; do not expose raw collector layouts.
- The example `StringLength` intrinsic in S1 §6.2 uses a different illustrative
  signature from historical S11/S12. A fresh primitive ledger must resolve its
  exact qualified declaration and signature instead of copying an example.

This inventory is a documentary coverage review. It is not executable proof
of any historical or new API's correctness, thread safety, portability, or cost.
