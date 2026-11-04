# Bounded native symbol inventory

This is the next consumer of NativeObjects/NativeSymbols and UBECore's budgeted
ByteKeys, within the reviewed object-to-image retention and stack/debug checks.
It introduces no new parsing phase, naming policy, worker or production tool.

One fresh NativeSymbolInventory owns a zero-initialized 40-byte symbol slot for
each COFF record and a 16-byte ByteKey capacity for the same count. A single
primary-record traversal fills only primary slots and compact keys. Auxiliary
slots keep NextIndex zero. Thus relocation membership is checked directly,
without reparsing/scanning the symbol table for each relocation. The key Value
is the original COFF record index, never a compact ordinal. A stable Core order
vector covers only the P primary keys. Names remain borrowed ranges in the
caller's same immutable candidate snapshot; no name or snapshot copy occurs.

The owner is passed only ByRef and must not be copied or mutated externally.
Status0 is fresh/disposed, Status4 incomplete or failed, Status1 complete.
Preparation accepts only an empty owner. Failure never exposes a ready partial
index; any allocated capacity remains explicitly disposable. The build owner
retains the immutable snapshot throughout every use and disposes this inventory
before releasing that snapshot. An existing complete result remains in its
separate owner until the pending preparation succeeds.

NativeInspectionStorage is a shared caller-owned parser-payload ledger with
MaximumPayload (default 16 MiB), Payload and PeakPayload. Every capacity is
admitted against both this cap and the existing global NativeLimits/NativeUsage
before allocation. Release follows actual ownership release, including partial
failure. For S COFF records the base payload is 56*S. Sorting temporarily admits
8*P bytes for the Core algorithm's two live vectors/publication overlap; the
retained result is 4*P bytes. Uncollected physical storage is distinct from live
owned payload, as in the Core contract. No cap is increased. Fixed scalar
workspace is bounded independently of S/P; primitive-owned storage headers are
covered by the existing substrate contract.

All inventory visits and Core comparison/read/write events consume the same
NativeInspection event and examined-byte ledger. Core budgets are synchronized
back on failure as well as success. Every admitted event polls cancellation.
Core cancellation maps to1507; exhausted work/storage and allocation refusal
map to1502/debug-information, while global payload exhaustion retains token1.
Malformed/missing/ambiguous candidate records map to1506; invalid internal owner
state maps to1509. Disposal remains available after cancellation and retains
unreleased capacity/charges if managed admission refuses cleanup.

Range lookup accepts a name from a separate immutable query snapshot and uses
the shared Core binary-boundary search. Direct reads reject auxiliary entries.
Required-definition lookup accepts one positive-section EXTERNAL or STATIC
definition, skips undefined/debug/absolute entries, and rejects zero or multiple
definitions. It preserves its output symbol/index on failure. The caller chooses
required compiler-owned identities from the frozen lowering expectation table;
this library of readers does not infer ownership from arbitrary candidate names.

Relocation-target validation traverses each section's effective relocation array
once and requires each non-ABSOLUTE target to be a primary symbol. This does not
apply relocations, resolve external definitions, prove symbol value extents or
validate linked instruction bytes. Held-file identity, required auxiliary
semantics, overlap checks, complete retention/fixup binding, unwind/stack/debug
admission and publication remain separate obligations.
