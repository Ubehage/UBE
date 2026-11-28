# Architecture decisions and pending proposals

Date: 2026-11-28. Status: **mixed; approval is recorded per subject below**.

This register is the reviewable decision work requested by the owner while fixing
the architecture audit. It belongs to the existing complete-language/product
work in [Development-Plan.md](Development-Plan.md). It does not create a new
compiler generation, subsystem or release requirement. No production change is
authorized merely by a recommendation appearing here.

The owner has already selected VB6 arithmetic precedence and associativity.
That decision is recorded in the normative language specification and both
grammars; current parser implementation and qualification are separate work.
The choices below preserve the existing checked-range, fresh FAIL, explicit
resource cleanup, precise tracing, native-process and dependency-minimal rules.

## Decision summary

| Subject | Current direction | Decision status |
|---|---|---|
| Runtime primitive authority | Preserve low-level versatility and custom algorithms while enforcing language invariants at checked boundaries | Owner constraint approved; concrete role restrictions must be justified individually |
| Concurrent output ownership | Refuse an overlapping request for the same physical output; hold ownership until cleanup | Owner approved; implementation and qualification pending |
| Static initialization | Retry after failure; per-receiver instance storage; cancelled wait fails without cancelling the initializer | Owner decisions approved and synchronized; implementation/qualification pending |
| Library compatibility/ownership | Source libraries compile into the consuming native program with one memory manager; package visibility remains | Owner source-integration direction approved; canonical compiled-bundle metadata still unfinished |
| Currency/Decimal integer division | Round and checked-convert both operands to LongLong; return LongLong | Owner approved; normative synchronization and implementation tracked separately |

All five subjects now have owner direction, but supporting details marked pending
below are not silently approved. Runtime design constraint
approval is not verbatim approval of every proposed restriction. Each section
distinguishes the approved choice, implementation recommendation, alternatives and
acceptance cases. Approval of one subject is not approval of the others. Technical
evidence for the original findings remains in the local Agent-ideas.md review
dated 2026-11-28.

## Automatic standard-library discovery

Owner requirement, 2026-11-28: the compiler needs the library location, not a
per-project list of standard-library source files. It discovers needed functions
and their dependencies automatically for ordinary projects.

The owner's later clarification permits Compiler.UBE's explicit standard-library
Source entries for bootstrap compatibility. That compiler-project exception
does not require ordinary users to maintain such lists. Standard-library names remain ordinary declarations;
existing package visibility and ambiguity rules continue to apply. Discovery
does not grant the separate validated runtime-support domain's authority.
Target-specific modules must follow the compilation target, not the host.

Acceptance must cover an ordinary project with no standard-library Source or
Reference entry; qualified and unqualified library names under normal lookup;
transitive calls and type dependencies; deterministic ambiguity and missing-library
diagnostics; configured location isolation between concurrent requests; and direct
compiler-project builds plus successive self-builds with the permitted explicit
source inventory. The installed source manifest and source files are authoritative:
editing library source requires no separate index update. The parsed declaration
index supplies lookup; no persistent index is required. Any future cache must
be optional and rebuildable when missing, stale or corrupt.
Unused library code must not become a blanket native dependency merely because
it exists at the configured location. Public documentation must distinguish this
required design from the currently qualified implementation until these gates pass.

## Runtime primitive authority

### Owner direction — approved design constraint

On 2026-11-28 the owner requested UBE be "as low-level and versatile as possible,
but avoid obvious security issues." The agreed interpretation preserves low-level
byte-buffer operations, native interoperability and custom algorithms, while
protecting language invariants: ordinary source must not publish invalid Strings
or bypass live-object safety. No new unsafe source mode is introduced.

This approves the outcome and design constraint, not a blanket prohibition of
the currently exposed low-level roles. A concrete restriction must be justified
by the invariant that cannot be enforced at its public boundary. Where checked
construction/publication or other validated operations can retain a useful
low-level API, prefer that to forcing callers through one high-level algorithm.
Native interoperability retains its separately defined boundaries and obligations.

### Existing boundary and evidence

The language permits Intrinsic declarations, but does not define a general
unsafe-source mode. `compiler/src/PrimitiveRoles.bas` validates role metadata and
signature. The actual UBE review probe showed project source constructing a
String containing byte 255 through public TextPrimitives and publishing it at
O0/O2. Typed Text algorithms correctly validate their own input; the issue is
the authority of their lower-level construction surface.

[../runtime/support-linkage.md](../runtime/support-linkage.md) already defines a
private, compiler-selected support lookup domain with exact source identity
checks. It is not available merely because a user supplies a particular module
name, attribute, signature, or copy of a source file. That existing distinction
can enforce authority without a new source keyword or package mechanism.

### Concrete enforcement recommendation — subject to the approved constraint

Classify intrinsic roles by the preconditions their implementation enforces:

- A role available to ordinary project source must preserve managed-memory and
  value invariants for every admitted argument. Invalid arguments return their
  documented controlled status/failure. Existing checked array/buffer operations
  remain available; do not prohibit all Intrinsic declarations.
- Roles relying on a trusted caller to maintain collector phase/root invariants
  or to publish validated values require either an enforced checked boundary or
  support-only authority. At minimum, audit Managed.*
  snapshot/mark/seal/reclaim/workspace operations, Text candidate construction/
  publication operations, and Object monitor operations requiring an independently
  held precise root. For each actual role the final table must record the enforced
  safety checks or the specific reason ordinary access cannot be safe. Do not infer
  authority from a name prefix or prohibit safe construction merely because it is
  low-level.
- A support-only declaration requires the existing validated support provenance
  in addition to its complete signature. Compiler-generated calls use their
  already-validated role identities. Renaming, copying, requalifying or importing
  a declaration from an ordinary project cannot acquire this authority.
- Public operations such as text creation and collection remain callable through
  ordinary checked UBE APIs. Custom text algorithms can still manipulate arbitrary
  bytes and use a checked boundary to establish a valid String. If current
  source-packaged UBECore wrappers need a
  support-only role, expose a narrow validated operation through the existing
  support integration before rejecting that packaging path. Do not break the
  public Text API or move its Unicode algorithms into native code.
- A supported compiler/toolchain maintainer can rebuild the reviewed support
  closure and its identities. This is explicit installation of compiler support,
  not silent privilege conferred by a consumer project's source or path.

This recommendation does not make hostile native Declare calls or arbitrary
assembly safe. Their separate foreign/assembly contracts are unchanged. It also
does not introduce an unrestricted unsafe mode for ordinary source.

**Alternative not selected:** retain a public low-level implementation surface with an explicit
unsafe admission mechanism and documented obligations. That needs a separate
language/diagnostic contract and would make a broader safety exception than the
reviewed program currently declares. Making only the wrapper Private is not an
alternative: role metadata can otherwise be redeclared.

**Acceptance:** project-source copies and exact redeclarations cannot bypass the
checks or authority of each restricted role; a support-only declaration receives
a located diagnostic before output publication. Legitimate installed support
builds and runs; safe roles still work in self-hosting; public Text APIs
retain valid Unicode and failure/destination behavior; an altered support source
identity is rejected; existing managed-text, object-monitor, self-host and
concurrent-compilation gates pass. Include user-written byte/text construction
algorithms exercising retained low-level operations and controlled rejection of
invalid publication. Admission tests can establish the boundary
without deliberately corrupting process memory.

No further abstract safe-versus-unsafe question is pending. Concrete enforcement
must be reviewed against this approved low-level-versatility constraint before
implementation is claimed complete.

## Concurrent output ownership

**Owner decision, 2026-11-28:** reject overlapping builds of the same output.
The owner selected the first offered option. The behavior below is approved;
production implementation and its acceptance gates remain pending.

### Existing boundary and evidence

[../compiler/CONCURRENCY.md](../compiler/CONCURRENCY.md) requires a coordinator
order or conflict refusal. OutputPublication currently guarantees atomic complete
replacement and input alias protection. Its competing-publication test allows
either completed artifact as the winner, without deciding which request should
own that result. IDE document-version requirements do not themselves resolve
ownership for standalone compiler callers.

### Approved behavior

Acquire exclusive ownership of the resolved physical output destination before
request work that can later publish to it. A concurrent request for that same
destination returns a distinct controlled output-conflict result, preserving the
existing artifact. Hold ownership through successful commit or failed-request
cleanup; a cancellation does not release it while workers or the backend can
still touch the candidate. Release on every completed cleanup path.

The key is the existing physical destination identity: normalized actual parent
directory plus leaf, with the target filesystem's equality rules and existing
alias checks. Existing outputs also require file-identity checks so alternate
names cannot bypass the rule. Implement the reservation using the native target
substrate and process-owned resources, not a timestamp file, persistent global
daemon, registry setting or network service. Qualify same-process requests and
separate compiler processes. Abrupt process exit must not strand a reservation.

The rule applies to cooperating UBE build processes. It cannot prevent arbitrary
external programs that ignore the protocol from writing the destination; retain
the existing immediate-before-publication alias/validity rechecks. Do not silently
claim universal filesystem transactions.

An IDE that wants the newest edit must cancel/drain an earlier build, then submit
the new request after ownership release. A failed overlapping request is not
quietly queued or retried with potentially stale inputs.

**Alternatives:** serialize explicitly queued requests with a defined admission
order, or make the newest submitted generation invalidate older publication.
Either needs a documented source-snapshot/generation contract and cross-process
scope. Last finisher wins is simpler but permits stale builds to replace current
ones, so is not recommended.

**Acceptance:** hold a first request before commit and submit a second for the
same path; assert conflict and unchanged prior output. Repeat with normalized-path
aliases, directory links and existing-file aliases supported by the target.
Reverse delays to show scheduling cannot change ownership. Test independent
outputs, cancellation, backend failure, failed cleanup/retry, process exit and a
new successful request after release. Native artifact atomicity remains a
separate assertion.

The reject-overlap choice supersedes the former unspecified-winner acceptance
case. It does not mark the existing atomic-publication implementation as having
already satisfied exclusive ownership.

## Static initialization

**Owner decision, 2026-11-28:** failed initialization must be retried on a later
use. The owner rejected the initial recommendation to preserve failure until
restart. Allocation failure or a failing function/I/O operation used by an
initializer are examples of recoverable causes. The owner subsequently selected
per-object retained Static storage for instance members, and prompt controlled
failure of a cancelled initialization waiter while the other thread's initializer
continues. The former permanent-failure, noninterruptible-wait and program-global
instance-storage recommendations are not the chosen behavior.

### Existing boundary and evidence

The earlier language promised program-lifetime Static storage, initialized once
on first reach and shared by recursion and threads. It also permitted failed declaration
initializers to leave neutral storage and forbids hidden As New recreation.
The 2026-11-28 decisions now close the ownership, retry and cancelled-wait behavior.
Thread cancellation is a sticky cooperative request; ordinary status-returning
waits return zero on cancellation without changing Err. An implicit Static
initializer has no corresponding status value to return.

### Retry state machine supporting the approved policy

The contract uses one current attempt generation for each owning
Static storage instance. Completion records distinguish existing waiters from a
later independent use; a later successful retry cannot erase the failure owed to
waiters on an earlier attempt.

| State | Initialization-triggering use |
|---|---|
| Unstarted | One entrant owns a fresh attempt; candidate storage is neutral and precisely rooted |
| Initializing(generation) | Other entrants join that attempt and await its outcome; no internal runtime lock is held while UBE initializer code executes |
| Ready | All entrants use the fully published value; ordinary source assignments remain permitted |
| Failed attempt, storage retryable | Existing participants receive that attempt's fresh FAIL; a later independent use can own a new generation |

Successful initialization publishes the complete value and Ready with a
happens-before edge to its waiters. Failure abandons unpublished candidate storage,
performs compiler-owned cleanup and records that attempt's fresh failure separately
from Err.Number. All participants in that attempt receive the same failure data on
their own threads, including when the number is zero. They do not spin internally
and retry on behalf of the failed use. The next independent initialization-triggering
use starts another attempt. Completed external side effects are not rolled back;
retry can repeat them, as the owner-selected policy requires.

Only successful initialization makes Ready permanent. Explicitly assigning Nothing
to a Ready object variable does not rerun its initializer. Neutral storage remaining
after failure is not a usable initializer result and cannot be mistaken for a
partially published success. Initialization first occurs when the declaration is
reached; a later access requiring the still-uninitialized value is a new independent
use. Default continuation skips the failed statement rather than retrying inside
it. A subsequent statement may therefore initiate a new attempt. These rules are
now normative in language-spec.md.

Reentry by the thread owning an unfinished attempt must produce controlled failure,
not expose partial state or wait for itself. An initializer that handles a nested
failure and completes normally may still succeed. Waiting remains cancellable
without revoking another thread's attempt. No additional promise to detect
arbitrary cross-thread user dependency/lock cycles is introduced. Stable numeric
error allocation remains a prerequisite before the feature is admitted.

### Instance ownership evidence and approved wait behavior

A native VB6 class oracle returned the exact sequence 1,2,1,1: two calls on object
A reused its Static local; the first call on B started at one; destroying and
recreating A also started at one. Evidence is
`%TEMP%/ube vb6 static ownership 806c4edc-13c1-440b-87f9-f38c56d222ab`, containing
source, project, CRLF build log and exact encoded exit 1211. Compilation/run
deadlines were 30/10 seconds. The initial sandbox registry failure was followed
by an automatically reviewed outside-sandbox run; native CRLF project/class files
were required before the fixture compiled.

The owner-approved VB6-aligned ownership is per object instance for Static
locals in instance members, shared by all calls/threads using that instance, and
per program/module instance for standard-module Static locals. This contradicts
the earlier proposal to share one instance-method Static across every object;
that proposal is withdrawn. The normative program-lifetime wording has been
reconciled explicitly following the owner's answer, including managed-memory roots.

Implicit initialization waiting has no status result like ThreadWait's zero-on-stop
result. The owner chose fresh FAIL and a thread-local initialization-wait-cancelled
error when a blocked waiter receives a stop request. The initializer and other
waiters continue. The cancelled wait releases its participation/retention and
follows ordinary failed-statement/handler continuation without forced thread
termination. The stop flag stays set. Cancellation and completion claim one ordered
wait transition; only the winning outcome is delivered. An already-set stop flag
rejects admission to a blocking initialization wait; it does not invalidate an
already Ready value. This specific exception is now reflected in threading.md;
ordinary status-returning waits still return successful zero on cancellation.

**Acceptance:** two first entrants share one attempt; after injected failure both
observe its fresh failure and a later independent use retries exactly once. Hold
an old waiter while a retry succeeds to prove generation-specific delivery. Check
reentry, managed roots, complete publication, successful later values, repeated
transient failures, Err.Number zero, stale Err on success and no reconstruction
after explicit Nothing. Qualify per-instance ownership, prompt wait cancellation,
initializer survival and cancellation/completion races. No such UBE runtime
qualification has been performed by this decision-register work.

## Library identities, metadata and ownership

**Owner decision, 2026-11-28:** libraries in one UBE program share the memory
manager. The owner further clarified: "Code from the standard-library (and other
linked source libraries), will be considered a native part of the program. Not a
seperate library." Source References therefore compile into the consuming native
program, rather than becoming runtime DLL boundaries. Package identity/visibility
are retained. Explicit foreign/native library outputs remain distinct. This does
not claim that canonical compiled-bundle encoding or the foreign ABI is complete.

### Existing boundary and evidence

[../lang-doc/project-files.md](../lang-doc/project-files.md) already fixes .UBL
outer framing, the three entries and exact LibraryReference version/hash fields.
[../lang-doc/foreign-abi.md](../lang-doc/foreign-abi.md) already requires exact-width
scalars, status plus output values, opaque managed handles, generation checks,
external leases and orderly unload. The missing work is a concrete compatible
encoding and a precise distinction between source incorporation and explicit
foreign/native library boundaries.

### Recommended behavior

Keep the existing .UBL container and exact-version-plus-interface-hash reference.
Do not add version ranges, implicit search paths or a package resolver. A bundle
consumer selects an explicit target and checks language version, intrinsic ABI,
external ABI and interface identity before exposing declarations or calling code.
Different implementation builds may have the same public interface hash; artifact
integrity remains a separate SHA-256. A public interface is not an artifact hash.

Use one canonical public interface record with explicit versioned framing and
typed fields. Include package and nominal type identity, direct dependency
interface identities, visibility, signatures, parameter order/passing modes,
optional defaults, constants, array rank, properties/events, selected conditional
surface, ABI-relevant layout and ownership operations. Encode defaults by their
typed semantic value, not source spelling. Recursive types refer to stable qualified
identities rather than traversal-dependent numeric IDs. Exclude source paths,
comments, formatting, diagnostic display spelling and ordinary procedure bodies.
Export symbol byte spelling remains included where the native ABI is case-sensitive.

Canonicalization uses the same versioned identifier-folding tables as source
binding; it must not independently choose locale case conversion or silently add
Unicode normalization. Sort unordered declaration records by canonical identity;
retain semantically significant order inside signatures, fields and initialization
dependencies. Canonical interface bytes, not a host object representation, are
hashed. A manifest must identify the folding/table version, target/layout and
encoding version. Golden byte vectors and a complete field schema must accompany
normative promotion; approving this direction alone does not imply that schema
is already complete or interoperable.

A source-linked UBE dependency graph is compiled into one native program and
shares its explicit program-owned managed context. Ordinary internal UBE calls
retain that context; source packages never obtain it through a mutable
process-global current-program slot.
Independent root invocations may retain separate contexts, as they already do.
Package module state, initialization and cleanup retain their own identities
within the program. Allocation, precise roots and collection use that program's
support, rather than each source package constructing an unrelated collector.
There is no additional cross-DLL runtime-service ABI merely for a source Reference.

This preserves ordinary UBE reference identity, ByRef/value rules and precise
collection of cycles crossing package boundaries. It does not expose raw managed
addresses to source code or foreign clients. If future compiled caches are linked,
their support compatibility must be checked; consumers must rebuild incompatible
cached code rather than hope that incidental layouts match. That cache encoding
is still unfinished and is not inferred from the source-integration decision.

The already specified foreign ABI applies when crossing into non-UBE code or an
independent runtime/program context: scalars and values use their declared copy
rules, and object references use explicit independent generation-checked leases.
Raw collector identities, root slots and stack addresses never cross that
boundary. A foreign root library invocation creates/joins its explicitly identified
program context; its incorporated source dependencies are part of that program.
No public foreign
call relies on the hidden UBE calling convention.

Explicit native library outputs retain their format and module lifecycle. Source
packages inside a program do not gain a separate DLL unload operation merely
because of their origin. Orderly native-library unload closes
admission, drains calls, invalidates affected identities/leases under the existing
contract, removes their roots and cannot leave callable code pointers in surviving
objects. The concrete unloading gate must cover shared-context callbacks and
finalizers before unload is claimed. The current staged self-build Source
packaging is not evidence of source-reference linking or library unloading.

**Alternative not selected:** isolate each source UBE library behind the foreign handle/copy ABI with
its own heap. This simplifies support-version isolation, but ordinary cross-package
reference identity, ByRef aliasing and cycle-safe tracing then need a bridge or
distributed collection design. Requiring user code to break all such UBE object
cycles manually would weaken the existing managed-language contract and is not a
routine implementation alternative. It needs an explicit owner semantic change.

**Acceptance:** two independent serializers produce identical canonical bytes;
nonsemantic spelling changes preserve the interface hash while parameter/default/
layout changes alter it. Wrong target, source/artifact pairing, table version,
dependency identity and corrupt metadata reject before publication/loading.
Two incorporated source libraries exchange scalars, Unicode text, custom values,
ByRef aliases and shared objects; cycles crossing package boundaries remain
collectible and source incorporation introduces no foreign wrapper. The produced
program has no required DLL solely corresponding to a source Reference. Package
lookup/visibility remains enforced. Two separate root contexts remain isolated.
Incompatible future cache support rejects. Foreign clients exercise independent leases, stale/foreign
handles, reentrant calls, failed calls, cancellation and orderly unload with
per-thread Err preserved. Add genuine cross-language clients using generated
declarations.

Source incorporation with a shared memory manager is approved and synchronized
into project-files.md, v3-language-definition.md and Development-Plan.md. Completing
and qualifying the compiled metadata schema and explicit native-library ABI/unload
behavior remain obligations; isolated runtime libraries are not the selected
behavior for source References.

### Exact remaining compatibility completion boundary

Source integration is settled; binary interoperability is not qualified by that
decision. The following are required before a producer/consumer may claim a
stable compiled-bundle or foreign ABI implementation:

| Existing contract | Missing concrete deliverable | Acceptance evidence |
|---|---|---|
| `.UBL` frozen outer framing and three named entries | Exact `Manifest` keys, line/value grammar, required fields, duplicate/unknown-field policy and version compatibility rules; currently only an “at least” field list exists | Independently authored valid/invalid byte fixtures, including duplicate fields, truncated values and unsupported versions |
| Canonical public declaration record | Complete byte schema, record tags, bounded lengths/counts, identifier-folding version, semantic default/value encodings, nominal/dependency identities, ordering and hash domain | Two independent encoders match golden bytes/hashes; semantic interface changes alter identity and nonsemantic spelling changes preserve it |
| Target-specific `Artifact` | Explicit admitted artifact kind and consumption/linking rules, support compatibility and source/cache pairing; source integration does not itself select a DLL or cached-object format | Wrong-kind/target/support artifacts reject before symbols become visible; compatible artifacts reproduce the declared interface |
| Foreign status plus result slots | Stable status integers, exact exported names/calling convention, diagnostic-copy signatures, output initialization/commit rules and failure mapping | A separately compiled C client verifies success, fresh FAIL including Err.Number zero, stale handles and unchanged outputs on failure |
| UTF-8 views and owned output values | Exact pointer/length and buffer-query signatures, capacity units, overlap rules, ownership/acquire/release operations and concurrent mutation obligations | Empty/embedded-NUL/Unicode text, undersized buffers, overflow lengths and independent leases exercise precise documented results |
| Decimal/Date and typed/custom values | Versioned field encodings/layouts and accessor signatures, schema hashes and permitted direct-record offsets/alignment | Cross-language byte vectors, recursive managed values, copy independence and wrong-schema rejection |
| Thread transition, callbacks and orderly unload | Concrete context admission, registration, callback retention/release and unload/drain state transitions, including reentry and calls racing shutdown | Bounded concurrent client tests prove rejection after closure, draining admitted calls and no callable removed code after successful shutdown |

These are completion requirements, not newly accepted wire layouts or stable
numeric assignments. Existing bounds, checked failure, ownership and package
semantics constrain their eventual definitions. No additional package resolver,
per-source-package heap or automatic runtime DLL boundary is authorized here.
The benchmark corpus and compiler self-build gates do not satisfy these
cross-language compatibility cases.

## Currency and Decimal integer division

**Owner decision, 2026-11-28:** use the proposed LongLong conversion/result domain.
The exact arithmetic behavior below is approved. Normative synchronization and
implementation qualification are tracked by the language/compiler work.

### Existing boundary and evidence

The numeric contract specifies ties-to-even rounding before integer division and
Mod. Single/Double operands explicitly select LongLong conversion and results.
Currency/Decimal operands do not yet select an integer domain, even though Decimal
can represent integers outside LongLong. Their current implementation remains
unsupported. The owner's VB6 precedence choice does not itself change UBE's
approved 64-bit types, rounding or fresh-failure rules.

### Recommended behavior

For integer division or Mod, if either operand is Currency or Decimal, convert
both operands to LongLong after ties-to-even rounding; the result is LongLong.
Retain the same rule for existing Single/Double cases. Operands are evaluated once
left to right, and conversion/range failure occurs before division. A divisor
that rounds to zero reports division-by-zero failure. LongLong minimum divided
by -1 overflows; its Mod -1 succeeds with zero. Constants obey the same rules at
compile time; runtime failure does not overwrite an unfinished destination.

Currency/Decimal ordinary addition, subtraction, multiplication and real division
retain their existing type-family rules. No Currency scaling or Decimal storage
representation changes. Mixed pointer operands still require their existing
explicit conversions; this proposal does not grant a new pointer conversion.

**Alternative:** retain a Decimal integer result/domain when Decimal participates,
using its 96-bit coefficient range, and separately choose Currency's integral
domain. This avoids narrowing valid large Decimal values but introduces another
integer-division domain and requires its own mixed-operand/result matrix.

**Acceptance:** inspect result types as well as values; test half-even ties,
LongLong extrema before/after rounding, Decimal 10^20, negative dividends/divisors,
rounded-zero divisors, mixed integer/fractional families, minimum Mod -1 and
minimum division -1. Check compile-time/runtime agreement, error order, stale Err
on success and destination preservation on failure.

The LongLong choice is approved; preserving a wider Decimal integer domain for
these operators is not the selected behavior.

## Additional lexical question discovered during grammar repair

The suffix grammar correction exposed an existing unresolved overlap: `^`, `!`
and `&` serve as type suffixes and operators. Examples requiring one lexical
answer include `x^2`, `2^3`, `x!Field`, `x&y`, `x& + y`, and standalone `2^`.
The current parser's greedy suffix consumption is implementation evidence, not an
owner-approved disambiguation rule. The new VB6 arithmetic-order decision does
not automatically decide the additional UBE LongLong suffix, which VB6 lacks.

Before changing this behavior, compare actual VB6 token grouping for its shared
suffix/operator forms and enumerate the additional UBE-only collisions. Preserve
the approved suffix meanings. Then propose the smallest adjacency/lookahead rule
with exact accepted/rejected spellings; do not silently require spaces where VB6
accepts an operator. This is recorded as an investigation dependency, not an
additional settled recommendation or a request for the owner to debug the parser.

Focused caret evidence, 2026-11-28: native VB6 passes `2^3 = 8`,
`2^-2 = 0.25`, and `3^+2 = 9`. The qualified D00694FF UBE compiler rejects
the first compact expression and builds the latter two with unequal results.
The spaced `2 ^ 3 = 8` control passes. The UBE fixtures use the required UBE
source header; earlier trials without that header were invalid and are not
semantic evidence. Evidence directories under TEMP: `ube operator suffix review
10e65c1f-8213-44b8-bf1e-3b7965172374` and `ube compact power differential
09823e3d-1a61-42c1-9801-fa81484aa37f` (case1 through case7).

Initial proposal, superseded by the owner's request for a distinct suffix:
in an expression, interpret `^`
as exponentiation when the following tokens can begin its right operand,
regardless of intervening spaces. Thus `2^3`, `2^-2`, and `3^+2` retain VB6
meaning. Preserve the LongLong suffix in declarations and in terminal literals
such as `2^` or `(2^)`; write `(2^) + 3` when addition must follow an explicitly
suffixed literal. This changes the meaning of `2^ + 3` to exponentiation and
therefore needs an explicit choice against the existing adjacent-suffix rule.
Acceptance must cover ordinary and conditional expressions, identifier and
literal operands, declaration suffixes, terminal and parenthesized suffixes,
and malformed right operands at O0/O2. It does not settle `&` or `!` collisions.

Final owner decision, 2026-11-28: use `&&` as the LongLong numeric-literal suffix,
chosen for keyboard accessibility. Examples: `42&&`, `9223372036854775807&&`;
based spellings such as `&H7FFFFFFFFFFFFFFF&&` retain their existing lexical
admission without claiming newly implemented based-literal evaluation.
The owner also disallowed identifier type suffixes in declarations and uses:
write `Dim Count As LongLong`, not `Dim Count^` or `Dim Count&&`.
Declarations use explicit `As datatype`; existing other numeric-literal suffixes
remain unchanged. Remove `^` as a literal suffix and retain it solely as the
exponentiation operator; do not retain a legacy suffix alias. Ordinary string
contents are unchanged: `"&&"` contains two ampersands, as confirmed with the
owner after distinguishing UI caption escaping. Migrate repository source,
fixtures, seed, language definition, grammar and public manual together.
Qualify decimal suffix ranges, based lexical forms, obsolete identifier suffix
refusal, mandatory `As`, and compact signed powers against native VB6.

## Register reconciliation and verification status

The old `lang-doc/deferred-questions.md` references point to a missing file. This
register can replace that missing architectural decision destination once linked
from language-spec.md, v3-language-definition.md and v3-closure-audit.md. Those link
edits are coordinated separately with the language-definition owner; do not create
two competing registers. Error-flow details already owned by
[Error-Handling.md](Error-Handling.md) remain there. Adaptive decisions remain in
[../lang-doc/adaptive-functions.md](../lang-doc/adaptive-functions.md).

This document was checked against the surviving normative contracts and current
implementation boundaries. Recording the owner decisions does not prove
their implementation. No behavior described here has been implemented or executed
by this decision-register work.
Acceptance cases above are required future checks, not passing test claims. A
complete metadata byte schema, new error-code assignments and the lexical
disambiguation rule are explicitly unfinished. Resolving them is part of the
existing goal, not permission to mark the architecture review's fixes complete.
