# Managed text implementation plan

Status: implemented and qualified under Roadmap.md's existing complete-language
item. The owner approved String and automatic-memory implementation on
2026-11-13 and delegated implementation decisions that follow established UBE
definitions first, known VB6 behavior second. The completed prerequisite is checked integer multiplication/division/remainder
and portable UTF-8 scalar encoding/decoding, documented in Progress.md and
../std-lib/UNICODE-SCALARS.md. Actual O0/O2 String, collection, failure/recovery,
worker-lifetime, self-host fixed-point and concurrency gates now pass; final
evidence is in Progress.md and runtime/tests/managed-text/README.md.
This approval is for the managed text goal,
not an exception to the established language or memory rules.

## Concrete architecture decision

The implementation adds real String values and the automatic memory support
already required by the language. In user terms: text can be assigned, passed,
returned and shared with workers without callers allocating or freeing it;
copies retain value semantics and failed operations preserve earlier values.
No additional runtime installation is introduced.

The implemented architecture is:

- Store canonical immutable UTF-8 backing data, with byte length and Unicode
  scalar count. A String slot contains an opaque managed identity; zero denotes
  empty text. Sharing the backing data does not expose reference semantics.
  Never expose a backing address as a language value or recycle a live identity.
- Emit precise root/layout information for String locals, globals, parameters,
  results, temporaries, array/record fields and worker captures. Register roots
  before any allocating call or thread publication; release them on every
  ordinary, handler, failure and cancellation exit. Return values need an
  explicit rooted handoff from callee to caller, without a collection gap.
- Use the specified coordinated stop-the-world tracing collector, initially
  nonmoving. Each program owns its collection state; threads publish roots at
  safe points. Collector traversal and text algorithms are ordinary UBE code.
  Minimal primitives provide native allocation, precise metadata/root access,
  atomic publication and thread rendezvous. No algorithmic String implementation
  is hidden behind a familiar function name in the compiler.
- Integrate the collector with existing block ownership rather than inventing
  an independent String-only heap. Managed layouts distinguish references from
  numeric cells. Existing scalar-array owners and explicit native resources
  retain their established contracts; shared quota accounting must not double
  charge or silently enlarge the current program budget.
- Preserve managed reachability through retained old array payloads: an element
  alias or capture can still own storage after its array descriptor is replaced.
  That owner keeps the exact managed layout scannable. Do not make all allocated
  blocks permanent roots or mistake opaque numeric cells for managed references.
  Record equality must compare String content, not stored handle identity.
- Consume the return handoff even when CallNew discards a Function result.
  Worker capture roots must be registered before the worker publication gate;
  native capsule/owner retention alone does not trace captured managed values.
- Make managed-reference writes pass through the versioned publication barrier,
  including aggregate copies and captured values. Blocking waits and OS calls
  must publish a safe transition state; never park while holding a storage,
  descriptor or worker-registry lock required by another thread or collector.
- Allocate uninitialized candidates privately, initialize all managed fields to
  neutral values, and publish only on success. Collection retries allocation
  once. Collector workspace failure must abort marking without sweeping;
  collector bookkeeping cannot recursively invoke its own collection path.

The owner approval establishes an implementation direction, not unreviewed primitive signatures
or an exception to the language. Before production edits, record concrete role
signatures and root/return/array/thread transition invariants in the relevant
runtime contract and review them against the current implementation.

## Typed text surface

The first ordinary UBE text module has explicit typed operations:

```vb
Public Function Length(ByRef Value As String) As LongLong
Public Function FromUtf8(ByRef Bytes() As Byte, ByVal Offset As Long, ByVal Count As Long) As String
Public Sub ToUtf8(ByRef Value As String, ByRef Result() As Byte)
```

These declarations belong to module `Text`. FromUtf8 uses validated logical
byte offsets/counts and rejects malformed encodings; it does not strip BOMs or
terminators. ToUtf8 publishes an independent zero-based byte array only after
success. Length counts Unicode scalars, including embedded zero. Success
preserves Err. Invalid spans use Err 9, negative count Err 5, malformed UTF-8
Err 13 and exhausted allocation Err 7, with normal fresh FAIL behavior.
Empty input produces empty String/array. Exact callable signatures and error
mapping are recorded here for implementation; no existing
broad-input Len/CStr/Left declaration is narrowed or replaced.

Concatenation and binary comparison use ordinary UBE text routines selected by
validated support identities, with compiler-owned evaluation/failure ordering.
Integer/Boolean formatting reuses the existing numeric/UTF-8 algorithms.
String-to-integer conversion must also accept the specified decimal fractions
and exponents with ties-to-even rounding, signs/whitespace, and integer hex/octal
forms. Boolean text uses True/False and the specified numeric-input rules.
Omitting floating-point source types does not permit omitting these text forms.
Compile-time and runtime conversion must agree on exact values and failures.

## Dependency order

The implementation audit established this dependency order:

| Capability | Current evidence and next dependency |
| --- | --- |
| Counted byte storage and UTF-8 validation | Existing array/file/scanner gates; reusable now |
| Checked integer multiplication, integer division and remainder | Missing in parser/binder/folder/lowerer at the start of this increment; now qualified by integer-operations |
| UTF-8 scalar import/export | Newly qualified ordinary UBE codec building blocks; no managed String claim |
| Variable String values | Now admitted with precise managed lifetime and ordinary UBE text lowering; actual O0/O2 gates pass |
| Broad-input compatibility functions | Inventory retains unresolved signatures and Variant/Adaptive dependencies; do not silently narrow them |
| Objects and full managed graphs | Existing normative contracts, separate implementation and acceptance clients |

The compiler itself continues to use counted Byte arrays. Its production
parser/binder/lowerer now admit ordinary String parameters, results,
concatenation and reusable text-facing library APIs. The runtime inventory
places text algorithms in UBECore rather than in compiler-specific helpers.

The required semantics already exist in language-spec.md,
v3-language-definition.md and managed-memory.md. Strings have value semantics;
immutable backing storage may be shared. Character operations use Unicode
scalar values, not UTF-8 bytes or UTF-16 code units. Empty is the neutral value.
Allocation failure preserves an unfinished assignment and follows ordinary
FAIL/Err propagation. Shared reference loads/stores must be safe across threads.

## Implemented increment

Variable-length String values are implemented throughout the existing admitted
scalar/finite-aggregate profile: literals, empty initialization, assignment,
parameters and results, ByVal copies, ByRef aliases, captured worker lifetimes,
and managed fields/elements wherever that profile admits their containers.
The implementation adds `&` concatenation and binary comparisons with source evaluation
order, failure propagation and destination preservation intact.

Provide ordinary portable UBE text algorithms for scalar length and strict
UTF-8 import/export so real text can cross the already qualified byte-I/O
boundary. Specify the exact typed library declarations, malformed-input and
allocation behavior before coding them. These are typed building blocks;
they do not redefine the broader public Len/Left$/CStr contracts or authorize
the still-proposed Adaptive modifier. Reuse existing UTF-8 validation and
integer-formatting algorithms instead of duplicating them.

Conversions involving already admitted Boolean/integer types must follow the
approved invariant rules wherever admitted. Unsupported numeric families,
Variant, fixed-length String, Unicode text-folding/Like and full compatibility
functions remain explicitly diagnosed until their own implementation gates;
their specified semantics are not weakened by this increment.

## Managed-memory prerequisite and approval boundary

The current scalar/finite-array allocation machinery is not the normative
managed collector. Do not label reference counting alone as String GC.
Implement the already specified precise tracing architecture: compiler-known
roots and layouts, safe reference publication, thread coordination at safe
points, automatic collection, one allocation retry, and orderly shutdown.
The initial collector may be nonmoving and coordinated stop-the-world as
permitted by managed-memory.md. Its traversal must be iterative and cycle-safe.
Text is its first language-visible client; it must not require a separate,
temporary String-only lifetime model.

Keep collection and text algorithms in UBE. Only irreducible allocation,
reference/root publication, synchronization and target memory operations belong
behind explicit intrinsic roles. Existing byte arrays, file/process tokens,
thread completion records and error state keep their documented ownership.
No new external runtime, package or downloaded build dependency is proposed.

Adding precise roots and safe points changes a shared runtime boundary. The
owner has supplied the explicit approval required by AGENTS.md and delegated
conforming implementation choices. Do not ask again for routine decisions
within that approval. Internal data layouts and primitive signatures must be
recorded before production edits and independently reviewed against the
existing contracts; an actual departure from language definitions remains a
separate owner decision.

## Acceptance before completion

- Actual UBE source at O0/O2: neutral/empty and quoted literals, embedded zero,
  supplementary Unicode scalars, independent semantic copies, parameters,
  results, arrays/records and CallNew captures; changed-input negative controls.
- Exact byte/text round trips and scalar lengths, strict malformed UTF-8
  rejection, exact binary ordering and concatenation, conversion boundaries,
  left-to-right side effects and unchanged destinations after failure.
- Precise collector roots in every admitted storage class; reachability and
  unreachable synthetic cycles/deep graphs; no conservative integer roots;
  cross-thread publication and blocking-wait/root coordination.
- Automatic reclamation without an explicit collection call; one allocation
  retry, failed bookkeeping without partial sweep, partial construction,
  repeated failure/recovery and zero remaining owned allocations at disposal.
- New roles bound by identity/signature, controlled rejection of unsupported
  forms, deterministic output and unchanged prior artifacts after failure.
- Renew actual compiler lowering, self-build fixed-point/common conformance
  and concurrent compilation gates on the final integrated sources. Record
  tested schedules and limits rather than claiming universal race freedom.
- Update root README, profile, inventory and progress only with passing scope;
  commit and push to GitHub main, then verify the remote commit.

Classes, finalizer execution, object graphs exposed through class syntax,
foreign callbacks/pins, forms and the full library remain later clients with
their own gates. The general collector design must accommodate their existing
contracts without claiming those clients are implemented here.
