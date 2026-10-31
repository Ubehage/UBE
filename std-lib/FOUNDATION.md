# UBECore/compiler foundation contract

Status: scalar and bounded ordinary managed-value foundations qualified,
2026-10-30. Byte/text contracts are adopted; ByteBuffer source-body functional
tests pass, with its cost/failure/concurrency qualification still pending at
the managed-foundation snapshot.
The owner subsequently delegated design decisions, preferring VB6 conventions
where compatible with agreed definitions. The adopted scalar addition and
current proof are in [the native contract](NATIVE-TYPE-PROPOSAL.md) and
[native evidence](tests/native-type/NATIVE-EVIDENCE.md). The subsequent
owner-approved ordinary Byte-array/record proof is recorded in
[managed evidence](MANAGED-STORAGE-EVIDENCE.md); it does not extend opaque
native representations beyond scalars or establish builtin String lifecycle.
This document implements the first contract item in the
[compiler workplan](../compiler/UBE_Compiler_v3/Roadmap.md) and
[library workplan](ROADMAP.md). It does not amend the language specification.

## Authority and first consumer

The [language specification](../lang-doc/language-spec.md),
[managed-memory contract](../lang-doc/managed-memory.md) and
[threading contract](../lang-doc/threading.md) govern observable behavior.
The [inventory](INVENTORY.md) records eventual scope, not implemented APIs.

The first intended consumer is compiler source loading and text construction:
owned input bytes, immutable decoded text and a privately owned builder. This
is a proposed narrow consumer, not approval of its public API. Prove one small
ordinary library-defined native datatype before substantial text code. Avoid
using an old compiler's String representation as the new byte container.

## Primitive and type-mechanism ledger

Names below describe responsibilities, not proposed source identifiers or ABI
signatures. A compiler primitive needs a written lowering/ABI contract before
implementation; a library operation needs an ordinary UBE declaration.

| Responsibility | Compiler/substrate minimum | Ordinary UBECore responsibility | Required limits and evidence |
|---|---|---|---|
| Scalar storage | Exact-width unsigned/signed integers, floating storage, alignment, checked conversion and arithmetic lowering | Domain algorithms and formatting | Byte 8 unsigned; Integer 16, Long 32, LongLong 64 signed; Single 32, Double 64. Boundary/overflow and LLVM storage checks; no silent width substitution. |
| Target sizes | Target-sized IntPtr/UIntPtr numeric arithmetic; checked size conversion | Capacity policy and size calculations | These numeric types do not grant memory access. Host pointer size cannot select target layout. Test both overflow and invalid constant rejection. |
| Type representation | Validate declared storage, alignment, field offsets, completeness and ABI identity | Choose representations within the approved mechanism | Representation must be expressible for an ordinary type name, with no privileged String/Decimal name dispatch. Exact extension grammar remains undecided. |
| Value semantics | Initialization, assignment, argument/result passing and cleanup lowering; precise root/layout metadata | Type-specific operations where an approved mechanism permits them | Neutral initial state; exact declared type; independent semantic copies. No raw padding/address comparison. Test aliasing, ByVal, ByRef, returns and all exits. |
| Managed storage | Checked allocation, roots, barriers, tracing, safe points and scoped foreign pins | Owned containers and immutable sharing policy | Cycle-safe; no exposed moving address. Failed growth preserves old value and roots. External handles still need explicit release. |
| Arrays/storage | Safe element addressing and approved array value semantics | Growth policy, copying, append/build algorithms | LongLong indices/bounds and arbitrary rank in the finished language. Failed resize preserves complete old contents/bounds; Preserve retains matching index tuples. A one-dimensional bootstrap subset is not full conformance. |
| Byte access | Bounds-checked octet load/store over approved storage | UTF-8 validation/decoding and encoding algorithms | Embedded 0 is data. Bytes, Unicode scalar positions and encoded lengths remain distinct. No C-string length dependency. |
| Text values | Required storage/ABI operations only; managed references where needed | Unicode String behavior, construction and comparisons where practical | Fixed String lengths count Unicode scalars. Ill-formed byte decoding policy/API needs its own contract. Do not replace frozen String behavior with bootstrap behavior. |
| Failure reporting | Per-call success/failure channel plus thread-local Err propagation | Validate inputs, preserve existing values, release temporary ownership | Known-invalid constants are rejected; runtime failures return the language's neutral result and set Err. Success retains prior Err. A stale Err cannot identify whether this call failed. |
| Intrinsic binding | Validate fully qualified declaration, signature, calling convention, target and recognized primitive | Ordinary algorithms and platform adapters | Unknown/mismatched declarations get diagnostics. No implicit runtime symbol fallback. Exact new primitive signatures remain pending. |
| Concurrency | Safe managed publication, nontearing scalar/reference accesses, SC atomics and reentrant SyncLock | Independent mutable owners, immutable inputs and bounded worker orchestration | Logical races cannot corrupt memory or introduce backend undefined behavior. One shared worker budget; cancellation/join/cleanup measured before a compiler workload. |
| Platform access | Explicit foreign ABI and scoped borrowing/pinning | Platform-separated file/path/thread adapters | No OS handles/constants in portable algorithms. Files/handles are explicitly owned on every exit, not released by an invented resource GC. |

Currency, Decimal, Date and Variant are deliberately outside this first
implementation slice. Their frozen meanings remain constraints: Currency is a
scaled signed 64-bit value; Decimal has a 96-bit coefficient with scale 0..28;
Date uses the specified Gregorian/nanosecond model, not a numeric serial.
Their full mechanisms cannot be inferred from a passing scalar probe.

## What the existing grammar can establish

An existing `Type` is a field-only value record. It cannot contain executable
members, initializers, `As New`, visibility or lifetime hooks. `On Get` and
`On Set` are variable access hooks; their existing signatures are not a type
representation, copy, initialization or destruction ABI. Ordinary ByRef or
address access must not bypass those hooks.

Consequently an existing record test can establish record storage and field
access only. It cannot prove that String, Decimal or an ordinary user-named
native scalar can be defined entirely by the library. A generic system or
automatic resource-management model is not implied by this contract.

## Smallest native-type proof: adopted scalar contract

Use a test-only, ordinary library type provisionally called `Octet` with one
unsigned 8-bit representation, zero neutral state and value copying. It owns
no external resource or managed reference. It is distinct from Byte; this
proof does not redefine a frozen builtin or publish a UBECore API.

Recommended mechanism direction: explicit declarative representation metadata
and separately declared ordinary UBE operations. The compiler validates and
lowers representation/call boundaries; the type's domain behavior stays in
UBE. Do not add executable bodies to existing field-only `Type` silently.
The owner delegated those decisions; `NATIVE-TYPE-PROPOSAL.md` records the
adopted syntax, metadata placement and scalar ABI with behavioral evidence.

The decision must settle these concrete questions together:

1. How does an ordinary declaration bind to a primitive representation without
   depending on its spelling, and who can access that representation?
2. Which initialization/copy/clear operations are synthesized from representation
   metadata, and which may be explicitly declared? How are recursion, visibility
   and signature errors diagnosed? A scalar proof needs no destructor callback.
3. How does a fallible operation return a fresh internal failure status while
   preserving neutral-result/Err semantics at the language boundary?

Recommendation for this first proof: private representation; compiler-synthesized
zero initialization and scalar value copy; checked conversion procedures in
UBE; no user lifetime callbacks until their need and semantics are demonstrated.
Use named conversion/inspection procedures for the first proof; implicit
conversions and new operator-overloading rules are not part of this proposal.
The scalar source grammar is adopted. The subsequent ordinary Byte-array/record
proof demonstrates bounded root/copy/result/cleanup behavior. A String
replacement still requires its own representation and language proof.

## Independent acceptance cases

These are target obligations. Cases requiring undecided syntax are specified
as behavior now and remain pending; they are not executable bootstrap passes.

| Case | Setup/action | Independently required result |
|---|---|---|
| Native representation | Define two differently named library types with the approved 8-bit metadata | Both store one octet at the specified alignment; renaming does not alter lowering; incorrect metadata is rejected. |
| Neutral/copy/calls | Default a value, assign 255, copy it, mutate original; pass copy ByVal, ByRef and as a result | Initial 0; copy remains 255; ByVal mutation is private; ByRef changes caller; result is independent. |
| Bounds/conversion | Convert 0 and 255, then constant and runtime -1/256 | Endpoints succeed; known-invalid constants diagnose; runtime failure is neutral with Err, without changing an existing destination where assignment is failure-atomic. |
| Binding rejection | Unknown primitive, wrong width/alignment, wrong signature/ABI/target, duplicate/conflicting bindings | Controlled diagnostic with location; no executable published. |
| Visibility | Ordinary caller attempts raw representation/address access | Rejected unless explicitly permitted by the approved contract; no moving address escapes. |
| Managed successor | Copy a managed value, mutate one copy; retain only a nested reference across collection; exercise early return and failed initialization | Independent semantic values; reachable child survives; dead roots reclaimed; balanced temporary ownership on every exit. No external-resource destructor is inferred. |
| Byte/text separation | Store bytes 65,0,66; decode valid multibyte text; address scalar and byte boundaries | Byte length 3 and exact bytes preserved; UTF-8 byte count differs from scalar count as specified; invalid sequences follow the future explicit API contract. |
| Failed growth | Inject allocation/size failure into a populated container | Existing contents, bounds, ownership and roots remain intact; fresh failure reported; no partial publication or leak. |
| Err preservation | Set Err, perform success; then perform a failure and a second success | Success keeps prior Err; separate internal status distinguishes each call; independent threads do not share Err. |
| Independent owners | Concurrent builders read shared immutable input; cancellation and one worker failure | Deterministic content, no shared mutable scratch, all workers joined, resources released, global budget never exceeded. |
| Costs | Measure actual append work, allocations, copied bytes and peak live storage across growing inputs | Counters correspond to executed operations/allocator instrumentation; no counters invented from input length. Set budgets before accepting the implementation. |

The executable [bootstrap cases](tests/foundation/cases.json) cover only a
small existing-language subset and deliberately include probes for missing
capabilities. Their expected values are written independently of compiler
output. The runner records failures as failures, including failures of a
target obligation; a rejected needed feature is not a compatibility pass.

## Gate and next handoff

The current usable-v2 gate is
`rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1`. It builds only
the seed/runtime and v2 from current source, checks the exact LLVM fixed point
and independent native/rejection/crash cases, and selects the accepted tool
through `bootstrap/out/v2/current.json`. See the
[v2 evidence and limits](../compiler/UBE_Compiler_v2/FOUNDATION-VERIFICATION.md).
The recorded managed-foundation run passes 276 assertions, retaining the opaque
native scalar mechanism and adding precise roots, independent ordinary
Byte-array/record copies/calls/results, bounded collection and controlled
allocation failure. Exact identities and role signatures are in
[MANAGED-STORAGE-EVIDENCE.md](MANAGED-STORAGE-EVIDENCE.md). Byte/text ownership
and decoder contracts are adopted. The ordinary ByteBuffer source body passes
13 functional assertions separately; its measured cost, injected failure and
independent-instance qualification remain the next library obligations. This
does not establish a released/full Library build or builtin String replacement.

The initial comparison investigation can still be run with
`rtk proxy powershell -NoProfile -File std-lib/tools/check-foundation.ps1`.
It builds only the small current C++ seed/runtime in a separate generated
directory, then tests that seed and available restored v2 artifacts. Every
subprocess has a timeout. The report records hashes, commands, results and
limitations. It neither runs the historical full build nor overwrites backups.

Bootstrap qualification is per case, artifact and target. Results must state
the exact usable subset, missing requirements and provenance limitations; no
self-hosting, full language conformance, concurrency, cost or fresh UBECore
library build is established by these cases. See [evidence](FOUNDATION-EVIDENCE.md).
