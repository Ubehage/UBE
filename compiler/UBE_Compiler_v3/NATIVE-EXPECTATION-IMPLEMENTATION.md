# Expected native linkage identities

The build owner prepares NativeExpectedDefinitions from its ready immutable
NativeDeclarationPlan before invoking native tools. It retains the matching
checked catalog/source owners, including original file/directory spellings,
declaration names/types/spans and compiler identity, throughout debug validation.
Rows retain canonical source/declaration indices into those owners; candidate
names or paths never generate expectations. Producer/CU encoding remains part
of the required debug emitter, not invented by the binary inspector.

One private ByRef owner holds scalar 40-byte rows and a byte arena. Each row has
name range, output-unit kind, source ID, declaration ID, linkage family, required
object flag, expected storage bytes, nominal type ID and representation. Unit
kinds follow the existing outputs: 0 source module, 1 program entry, 2 process
adapter, 3 initialization data, 4 platform, 5 frame data, 6 private error support.
Support rows use source/declaration -1. Source functions/globals retain the
checked IDs. Names are ASCII compiler policy, encoded with the existing Core
decimal encoder; no source spelling or object prefix establishes ownership.

Families: 1 procedure ube.fN, 2 global ube.gN, 3 initializer ube.module.initN,
4 stack admission, 5 module requirement, 6 initialization schedule, 7 program run,
8 process main, 9 module states, 10 failed latch, 11 initializer table, 12 stack
floor, 13 stack initialization, 14 stack abort, 15 module wait, 16 reserve,
17 frame table, 18 error set, 19 stack error set, 20 error number, 21 error clear,
22 error TLS state, 23 inline error condition. Helpers 4/5/23 may appear per source; 4/5/6 also belong to the
entry. They may be eliminated before object emission. Only language Main and
the required fixed support/initializer definitions require object presence;
all definitions actually present in their object must still retain their image
definition. Matching/remapping those surviving objects is a separate consumer.

Capacity is D + 3*M + 19 rows for D target declarations and M source modules,
and 48 name bytes per capacity slot. This admits the complete bounded policy
without repeated declaration scans or incremental collection growth; actual
Count and NameLength publish only on success. Fixed support count is 19.
The maximum name is shorter than 48 bytes even with a 19-digit target identity.
The total owned capacity is 88 times row capacity, admitted against the shared
16-MiB inspection and global native payload caps before allocation. Partial
allocations retain exact charges and are disposable. Status 0 fresh/disposed,
4 incomplete, 1 frozen. No managed owner copies, retained mutable aliases or
worker-local global state are permitted. Names/rows become immutable when ready.

One added D-row traversal charges the native lowering work ledger as well as
inspection events. Name output and fixed-row preparation also charge inspection
events; generated name bytes are not examined candidate bytes. The existing
3*D+I declaration bound therefore becomes 4*D+I for a build that freezes this
table once. The owner authorized necessary measured increases; numeric caps and
body/argument bounds do not change. This additional visit is for the reviewed
pre-tool expectation table and is not hidden as uncounted inspection work.
Cancellation polls every inspection admission, with the existing lowering poll
on declaration visits. Failure uses existing 1502/1507/1509 mappings; malformed
candidate failures belong to the later consumer. Caller retains its old complete
table in a different owner until new preparation succeeds.

NATIVE-EXPECTATION-EVIDENCE.md qualifies this owner with actual checked-project
plans and emitted LLVM/object membership through the full compiler graph gate.
Complete source/debug metadata emission, retained symbol/range/fixup validation,
stack reserve derivation and publication remain obligations of the active plan.
