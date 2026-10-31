# Compiler development roadmap

The active line is the fresh [`UBE Compiler v3`](UBE_Compiler_v3/README.md),
as designated by the owner on 2026-10-30. Its prerequisites and acceptance
rules are in [`UBE_Compiler_v3/Roadmap.md`](UBE_Compiler_v3/Roadmap.md).

- [x] Preserve previous v3/v4 implementations, previews and compiler handoffs
  under `archived/`, with exact original-byte snapshots and relocation records.
- [x] Record the owner's approved library-first datatype/bootstrap direction.
- [x] Define the first foundation contract and primitive/type-mechanism ledger.
- [x] Produce a usable source-built v2 for the bounded byte/scalar foundation
  subset, with fixed-point and independent native/rejection/crash evidence.
  See `UBE_Compiler_v2/FOUNDATION-VERIFICATION.md` (130 acceptance assertions).
- [x] Prove the bounded bootstrap subset and library-defined native datatype
  mechanism before broad compiler implementation.
  The earlier source-input gate passed 470 assertions including managed storage
  and the first library byte/text facility. The current 501-check qualification
  adds scanner/Unicode proofs; see `UBE_Compiler_v3/SCANNER-EVIDENCE.md`.
- [x] Build the first source-ingestion consumer with independently tested
  UBECore facilities, direct source references and controlled native failures.
- [x] Define scanner/source-envelope acceptance over exact source snapshots.
  102 independent vectors/174 word roles pass 2286 consistency assertions;
  this is a definition gate, not native scanner qualification.
- [x] Implement that defined scanner/source-envelope consumer in UBE and pass
  its independent native, failure, resource and measured-cost gates.
  The current-source gate passes 501 grouped checks; exact scanner/Unicode
  evidence and supported limits are in `UBE_Compiler_v3/SCANNER-EVIDENCE.md`.
- [x] Define the first bounded grammar consumer before choosing parser storage
  or strategy. 116 independent cases and 16 negative controls pass the definition
  gate; the native 501-check baseline remains unchanged. See
  `UBE_Compiler_v3/PARSER-EVIDENCE.md`.
- [x] Compare native parser storage/traversal candidates before implementation.
  3828 assertions pass through both accepted stages; linked-child nodes and
  explicit stacks are selected. The necessary recoverable-memory prerequisite
  passes the fresh complete 501-check source gate. See
  `UBE_Compiler_v3/PARSER-PROBE-EVIDENCE.md` for that prerequisite evidence.
- [x] Implement and independently qualify the bounded production grammar consumer.
  Both source-built stages pass 4049 grouped native checks, all 188 cases and
  10412 real-root capacities, persistent faults, cleanup, workers and measured
  bounds. The refreshed 501-check bootstrap and strict CLI/artifact gates pass.
  Exact evidence and scope are in `UBE_Compiler_v3/PARSER-NATIVE-EVIDENCE.md`.

No successor implementation item is selected by this checklist. Agree the next
bounded contract and independent cases before expanding compiler/library scope.

The earlier roadmap is retained under `archived/compiler-history/Roadmap.md`.
It is historical scope and evidence, not the fresh compiler's execution plan.
No old task, phase interface, layout or completion claim transfers implicitly.
