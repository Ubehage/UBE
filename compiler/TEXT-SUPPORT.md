# Managed text implementation plan

Status: future managed-text design under Roadmap.md's existing complete-language
item. The completed prerequisite is checked integer multiplication/division/remainder
and portable UTF-8 scalar encoding/decoding, documented in Progress.md and
../std-lib/UNICODE-SCALARS.md. No String implementation or managed-memory
qualification is claimed. The managed runtime proposal below is not approved
for implementation by selecting that arithmetic/library prerequisite.

## Why text comes next

The implementation audit established this dependency order:

| Capability | Current evidence and next dependency |
| --- | --- |
| Counted byte storage and UTF-8 validation | Existing array/file/scanner gates; reusable now |
| Checked integer multiplication, integer division and remainder | Missing in parser/binder/folder/lowerer at the start of this increment; now qualified by integer-operations |
| UTF-8 scalar import/export | Newly qualified ordinary UBE codec building blocks; no managed String claim |
| Variable String values | Still absent from the admitted type/expression/storage profile; requires precise managed lifetime and text lowering below |
| Broad-input compatibility functions | Inventory retains unresolved signatures and Variant/Adaptive dependencies; do not silently narrow them |
| Objects and full managed graphs | Existing normative contracts, separate implementation and acceptance clients |

The compiler and UBECore currently exchange counted Byte arrays. Source tokens
can retain quoted text, but the production parser/binder/lowerer do not admit
ordinary String values. This prevents normal text parameters, results,
concatenation and reusable text-facing library APIs. The runtime inventory
places text algorithms in UBECore rather than in compiler-specific helpers.

The required semantics already exist in language-spec.md,
v3-language-definition.md and managed-memory.md. Strings have value semantics;
immutable backing storage may be shared. Character operations use Unicode
scalar values, not UTF-8 bytes or UTF-16 code units. Empty is the neutral value.
Allocation failure preserves an unfinished assignment and follows ordinary
FAIL/Err propagation. Shared reference loads/stores must be safe across threads.

## Concrete proposed increment

Implement variable-length String values throughout the existing admitted
scalar/finite-aggregate profile: literals, empty initialization, assignment,
parameters and results, ByVal copies, ByRef aliases, captured worker lifetimes,
and managed fields/elements wherever that profile admits their containers.
Add `&` concatenation and binary string comparisons with source evaluation
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

Adding precise roots and safe points changes a shared runtime boundary, so
AGENTS.md's explicit architectural-approval rule applies before implementation.
The owner can approve the concrete capability and architecture without having
to review low-level implementation details. Internal data layouts and primitive
signatures must then be recorded before production edits and independently
reviewed against the existing contracts.

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
