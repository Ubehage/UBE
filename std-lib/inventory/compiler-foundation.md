# Reusable foundations needed by the compiler

This part records capabilities already called for by project architecture and
the fresh-library direction. Most public names and signatures are **not yet
chosen**. Capability labels below are inventory labels, not approved UBE
identifiers, generic types, packages, or new intrinsics. All remain unimplemented
in the fresh UBECore.

Sources: [fresh boundary](../DESIGN.md), [workplan](../ROADMAP.md),
[compiler/library architecture](../../project-docs/architecture.md),
[historical reuse analysis](../../compiler/archived/UBE_Compiler_v4/REUSE_PLAN.md),
[historical ownership table](../../compiler/archived/UBE_Compiler_v4/TASK0_DECISIONS.md),
and [planned library areas](../../docs/library/index.html).
The historical plans supply requirements and failure lessons, not reusable code
or automatic API approval.

## Text, storage and lookup

| Capability | Kind | Required behavior | Candidate owner/status |
|---|---|---|---|
| Byte storage and bounded byte views | Storage types/operations | Exact lengths, embedded zero bytes, checked ranges, explicit ownership and borrow lifetime | UBECore; representation and names pending |
| Immutable text snapshots and slices | Text types/operations | Stable UTF-8 bytes with retained owner lifetime; cheap views need measured copy/retention rules | UBECore; names pending |
| UTF-8 decoding and iteration | Text operations | Strict malformed/truncated/overlong/surrogate handling; report byte positions; guaranteed progress | UBECore; algorithm contract pending |
| Unicode scalar encoding | Text operation | Validate scalar range; produce exact UTF-8 bytes without host locale | UBECore; name pending |
| Unicode letter membership | Character classification | Consume pinned Unicode 18 data and provenance; no host-dependent classification | UBECore plus data substrate; name pending |
| Unicode simple case folding | Text operation | Versioned scalar folding for the approved comparisons; no implicit normalization | UBECore; name pending |
| Ordinal and folded comparison | Text operations | Distinguish byte/scalar/folded comparison; deterministic outcomes and exact length rules | UBECore; names pending |
| Text/chunk construction | Mutable builder | Bounded growth; avoid repeated full-output copies; measure allocation and copied bytes | UBECore; type/method names pending |
| Integer formatting and parsing | Conversion operations | Exact widths, bounds, invariant text and minimum-negative-value handling | UBECore; existing compatibility names cross-reference runtime inventory |
| Incremental binary construction | Mutable builder | Checked sizes, transactional failure, explicit byte order and finalization | UBECore; names pending |
| Growable indexed storage | Collection capability | Amortized growth, checked indexes/capacities, no hidden whole-program copies | UBECore; no generic syntax assumed |
| Hash maps and sets | Collection capabilities | Collision/growth behavior, checked allocation, explicit equality/hash consistency | UBECore; key/value APIs pending |
| Stable sorting | Algorithm | Defined comparison contract; preserve equal-key order; bound work and temporary storage | UBECore; API pending |
| FIFO and bounded queues | Collection capabilities | Defined capacity, ordering, ownership transfer/copy and failure | UBECore; APIs pending; synchronized MessageQueue separately specified |
| Lookup/interning storage | Collection capability | Canonical values with explicit ownership; no hash-iteration-dependent public order | UBECore mechanisms; compiler owns NameId allocation policy |

## Files, encoding and tools

| Capability | Kind | Required behavior | Candidate owner/status |
|---|---|---|---|
| Lexical portable paths | Path operations | Separate parsing/normalization from filesystem lookup; preserve host/target independence | UBECore; names pending |
| Filesystem path resolution | File operations | State case/symlink/containment behavior and host failures explicitly | Platform-backed UBECore; compiler owns project containment policy |
| Bounded file reading | File/stream operations | Check sizes and growth; reject malformed text at the selected encoding boundary; close on all paths | Platform-backed UBECore; names pending |
| Binary and text streams | Stream interfaces | Explicit seek units, lengths, encoding, partial reads/writes and ownership | UBECore plus adapters; APIs pending |
| Complete output writes and flushing | File operations | Detect partial writes/full disk; retain explicit handle ownership and error status | Platform-backed UBECore; names pending |
| Atomic file replacement | File operation | Publish complete validated contents using documented same-filesystem guarantees; clean temporary files | UBECore contract plus host adapter; compiler owns artifact success policy |
| Temporary files and directories | File operations | Collision-safe creation, explicit lifetime, controlled cleanup failure | Platform-backed library/support; ownership decision pending |
| Directory enumeration | File operation | Explicit enumeration instance, deterministic sorting when requested, cancellation/cleanup | Platform-backed UBECore; names pending |
| SHA-256 and incremental hashing | Hash operations | Known vectors, bounded streaming, repeatable digest representation and finalization | Reusable library; placement/name pending fresh review |
| Bounded binary readers/writers | Serialization operations | Checked offsets/lengths, explicit endianness, corrupt/truncated-input failures | UBECore; names pending |
| Canonical record encoding | Serialization operations | Escaping, limits, stable field rules and transactional failure | Reusable library mechanisms; compiler owns record schema |
| Separate-argument process creation | Process operation | No shell reparsing; explicit executable/arguments/environment and resource ownership | Library or compiler support with platform adapter; public boundary pending |
| Process pipes and captured output | Process/stream operations | Concurrent draining, bounded stdout/stderr, timeout/cancel and handle cleanup | Library/support; APIs pending |
| Process completion and cancellation | Process operations | Distinguish child exit, startup failure, timeout and cancellation; drain/release resources | Library/support; APIs pending |
| Command-line/environment access | Environment operations | Explicit encoding, absence, bounds and platform representation | Library/support adapters; names pending |
| Monotonic measurement | Clock operation | Document units, range/resolution, wrap/unavailability; never drive program semantics from profiling metadata | Compiler support initially; reusable API pending |
| CPU time and peak-memory measurements | Measurement operations | Report availability and units accurately; process-local evidence | Compiler support; not ordinary language semantics |
| Console streams | Console/stream operations | Standard input/output/error, encoding, redirection and controlled write failure | Platform-backed UBECore; APIs pending |

## Concurrent use and native boundaries

| Capability | Kind | Required behavior | Candidate owner/status |
|---|---|---|---|
| Bounded work scheduling | Concurrency capability | One shared worker budget, bounded queue, exact task ownership, cancellation and drain | UBECore mechanisms; compiler owns task decomposition |
| Cooperative cancellation signalling | Concurrency capability | Defined observation/wakeup and lifetime; preserve existing ThreadRequestStop rules | UBECore; richer token API not yet defined |
| Immutable shared-input publication | Ownership contract | Publish completed state before access; no mutable aliases or whole-model transport | Library storage and compiler ownership contracts |
| Private-result publication | Ownership contract | Single writer, complete result, release on failure; observable order chosen by consumer | Library mechanisms; compiler owns stable merge identities |
| Independent-instance reentrancy | Verification requirement | Concurrent builders/maps/readers do not share accidental mutable state | Every affected library API |
| Synchronized shared mutation | Verification requirement | Use specified atomics/SyncLock/events/queues where sharing is part of API; no blanket global lock | Every affected sharing API |
| Allocation and managed storage primitives | Substrate capability | Checked sizes, collection/retry, correct roots/barriers, controlled failure | Small documented substrate; not a public raw-address allocator by default |
| Native-thread and wait primitives | Substrate capability | Admission, TLS errors, cancellation wakeup, bounded creation and cleanup | Platform substrate behind UBE thread/synchronization APIs |
| Foreign transitions and scoped pins | Substrate capability | Exact roots and bounded pin lifetime; safe callback entry and shutdown rejection | Versioned ABI/substrate; public shape pending |
| Native resource wrappers | Platform capability | Explicit close/release, stale-handle checks, idempotence where promised | Platform libraries; no implicit GC resource registry |

## Wider standard-library areas already named by the project

The [project roadmap](../../project-docs/Roadmap.md) and
[manual overview](../../docs/library/index.html) additionally call for the
following areas. The runtime inventory supplies existing compatibility names;
this table records the remaining capability scope without inventing signatures.

| Capability | Kind | Scope still to define | Candidate owner/status |
|---|---|---|---|
| General numeric mathematics | Algorithm family | Checked integer/decimal/floating operations and explicitly documented special values | UBECore; VB6 names cataloged separately |
| Date/time and duration helpers | Algorithm family | Civil fields, calendars, explicit serial-date conversion and locale operations; no implicit Date arithmetic | UBECore; extra types/names pending |
| Networking and sockets | Platform-backed API family | Connections, reads/writes, timeouts, cancellation, ownership and errors | Standard-library/platform scope named; public APIs pending |
| Events and active sources | Runtime/framework family | Subscription snapshots, callbacks, source registration and shutdown liveness | Defined UBE lifecycle; public framework APIs pending |
| Native graphics, printing and UI | Framework family | Portable calls, native adapters, control/type/member surface and diagnostics | Separate documented framework/graphics scope; not compiler built-ins |
| User-defined native datatype support | Vision capability | Representation and initialization/access/destruction control beyond approved Type/hooks | Project vision only; no new syntax or intrinsic approved |

The foundation list is not an implementation schedule. Each selected capability
must first acquire a reviewed API/representation and a small independently
executable acceptance gate. Unchosen facilities remain inventory entries.
