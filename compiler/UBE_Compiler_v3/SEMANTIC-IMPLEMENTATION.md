# Private semantic implementation

This implements the approved First semantic checking contract. It adds no
compiler generation, executor, source grammar or public phase API. The internal
interfaces below coordinate implementation; they are not a release ABI.

## Selected foundations

Use scalar-record indexed storage, explicit work stacks and complete publication.
The 48-byte scalar/LongLong arena, actual geometric/trim/publication copying,
allocation/root denial and retained-owner behavior are qualified by the native
arena probes in `bootstrap/out/shared-semantic-probes/EVIDENCE.md`.

Use the partitioned stable sorted ByteKey/direct-Long-order facility, not the
bounded open-address candidate. The latter exhausts its controlled work allowance
on the adversarial corpus. The final sorted facility completes the full corpus
with logarithmic lookup and stable complete duplicate ranges; exact evidence is
`bootstrap/out/byte-key-order/EVIDENCE.md`. Partition is an opaque integer to
UBECore. Compiler scopes/accessibility remain compiler policy. This also avoids
scanning every same-spelled local in unrelated procedures.

The maintained ordinary-UBE SignedIntegers and Utf8Encoding modules provide
exact signed values/checked arithmetic and scalar encoding. Identifier cooking
belongs here:
consume retained parser-selected suffix/bracket information, simple-fold once,
append derived bytes to one private geometric arena and preserve original spans.
Quoted module identity reuses the qualified envelope/project identity decoder.
No source grammar is recovered with regex or a second parser.

The maintained foundation gate exercises ByteKey/direct order, signed integers,
capacity planning, scalar encoding, name cooking and the arena through actual
UBE workers with private outputs. It checks ownership after caller roots
disappear during collection, bounded captures and failure/cancellation/cleanup.
These component proofs remain distinct from the full production checker gates.

## Owners and result

`SemanticCatalog` privately prepares source/name/declaration/type information,
then freezes it before body work. Each `SemanticSource` retains its original
SourceWork/SourceOwner and admitted envelope/package association. Per-source
syntax-to-name maps contain scalar indexes, never copied tokens or source bytes.
Declaration identity derives from package, module, kind and original name span;
integer IDs are assigned canonically before workers start.

`SemanticModuleWork` retains one catalog and source reference, private fact/value
storage, traversal work, fresh failure, metrics and completion state. A worker
never mutates the catalog, source, syntax, another worker or an old result.
One final `SemanticResult` reference publishes catalog, ordered complete module
results and the entry declaration together. A failed check retains the old
result and its complete owner graph. Failure spans borrow the caller's retained
input; formatting takes that same input, not an old successful result.

The scalar records are declaration metadata (64 bytes), semantic observations
and reduced bound nodes (48 bytes each), names and type metadata. The native
gate checks their actual target layout, rather than importing a probe layout as
proof. The source syntax graph remains immutable and supplies original spans.

## Observations and reduced operations

Keep source-expression typing/binding, type references, conversions, call maps,
options and primitive metadata as explicit semantic facts. Reduced value nodes
contain only materialized execution values; a literal-only arithmetic subtree is
an actual typed constant with no arithmetic children. Facts retain the selected
types/constant values of its original operands and every checked/identity
conversion. Statement/call edges carry their conversion facts, so a folded Long
30000 and its checked Integer destination remain distinct observations.

An expression result carries type, known value, storage/binding information and
an optional materialized node. Delay materializing a known child until a live
runtime operation needs it. This avoids emitting then discarding whole constant
trees. Grouping remains in original syntax and typing facts; transparent groups
do not invent execution operations. A signed unsuffixed literal unit may include
the unary sign and intervening groups: its raw digit token remains source syntax,
not a separately executable positive magnitude that must fit before negation.

Bind/type both short-circuit operands. A provably skipped right operand emits
static facts but no execution values and does not evaluate an unreachable fault.
Unknown conditions retain conditional-right execution; ordinary eager operations
retain left-to-right exactly-once inputs. Variable storage is established before
its initializer, including self-reference, and its operation plan retains storage
after runtime-dependent failure. No runtime execution claim follows from a plan.

Facts and bound nodes use indexed linked children/next siblings where ordered
lists are needed. Source expressions, statements and constant dependencies use
explicit frames; no user-controlled native recursion. Flat arithmetic chains do
not count as nested group/call depth. Record all allocated logical work, including
unpublished validation, under the defined declaration/fact/pending budgets.

## Lookup and declaration preparation

Module declarations precede their members in the stable catalog. Parameters and
locals point to the containing procedure; module members point to its module.
All names are cooked once. Generic ByteKey entries partition module names,
individual declaration regions, package-visible members and reference exports.
Public/Friend/Private and Option Private Module determine which entries exist;
qualified member lookup additionally enforces access on the owning module group.
At each lookup level, zero/one/multiple results mean continue/select/ambiguity.
Never scan unrelated regions or retry a wrong call against another declaration.

Type IDs are 0 Void, 1 Boolean, 2 Byte, 3 Integer, 4 Long, 5 LongLong; native types
follow in canonical declaration order and retain nominal declaration identity,
representation and explicit pack/unpack links. Bare predefined type tokens are
distinct from bracketed ordinary identifiers. No function/type spelling grants
an implicit builtin or primitive binding.

Collect declarations and resolve signatures before bodies. Required constants
cannot use a later constant in the same written declaration sequence. Canonical
source IDs are diagnostic order, not a cross-module constant-visibility filter.
Resolve accessible cross-module/reference constant dependencies from collected
declarations with explicit cycle detection; module constants are established
before bodies. Local reads before written declaration remain the contracted
deferred lifetime case.

## Existing worker pump and budgets

Reuse the existing source worker admission/wait/stop/drain implementation for
per-source semantic work. Preserve TryParseSources and ProcessSourceWork names
and behavior. Factor its control state into scalar fixed slots (four native IDs
and source associations) and shared action helpers; keep syntax and semantic
work/result types separate. This does not introduce a callback executor or a
semantic dependency into SourceWork. Scalar scheduling state cannot suffer a
new managed admission failure while workers require draining. Native start/wait
failures preserve the existing stop-admission and confirmed-completion policy.
Parsing drains before semantic work reuses the same admitted jobs value.

Freeze declarations before body workers. Reserve conservative bounded fact/work
allowances before simultaneous admission, release unused allowance after complete
results, and never exceed the one caller budget. When a structural upper bound
does not fit and no worker is active, check that source alone with the actual
remaining allowance: a conservative estimate must not reject a program whose
actual required count fits. Budget failure is distinct from a semantic error.
No new atomic primitive, nested pool, per-worker project copy or serial whole-body
precheck followed by recompilation is needed.

## Qualification and next action

The generic library facilities, checker, shared source-worker controller and
check command are qualified in the production tree on accepted cohort 88d.
SEMANTIC-EVIDENCE.md records the exact final gates and installed local replay.
Historical accepted cohorts and OUT
source snapshots do not qualify later harness or source edits. The installed
local executable is replaced only through its exact qualified replay gate.

`tests/semantic/native/complete/` holds the independent complete examples and
their source/manifests. `native/whole`, `catalog`, `formatter`, `expressions`,
`four-context`, `source-worker-slots` and `cli` contain their maintained native
and process gates; none depends on an OUT implementation copy. Use all 205
targeted cases and complete graph comparisons, rejecting extra/missing bindings,
types, conversions, values, call maps and diagnostics. Definition consistency
remains distinct from execution.

Declaration Flags bit 128 records an already diagnosed deferred signature
component. Missing primitive binding is independently checked when no signature
component is deferred; Pack/Unpack type comparisons also require available
selected types and representation. A failed explicit primitive binding uses
Auxiliary=-1 only during private failed preparation to prevent a false missing
binding cascade. Valid complete primitive roles remain 1 Pack/2 Unpack.

Published Metrics fields count the explicitly instrumented internal helpers;
they are not asserted to include every preparation/publication access. Native
gates interpose the actual source/token/scalar record operations and allocator,
copy, root and heap mutations for full work/cost assertions. No synthetic count
derived solely from input size substitutes for those observations.

All actual record/resource/copy/lifetime/concurrency costs, source-built stages,
failure sweeps and retained gates must pass for the resulting source cohort.
No native executable backend, full-language acceptance, commit or push is part
of this completed bounded semantic goal. The next existing deliverable begins with reviewed native-executable contracts.
