# Phase 5 self-host performance investigation

Recorded 2026-10-26 on Windows x86-64 with Clang 23 and production compiler
source at 44 files, 1,288,714 source bytes, and 298,373 tokens.

## Conclusion

The original multi-job compiler was pathologically slow; this was not the
expected cost of self-hosting. Phase 3/4 workers copied and reconstructed more
state than the useful work they performed. Normal activation of those workers
is suspended until they can consume immutable shared inputs. `--jobs N` remains
accepted, but the profile reports the effective fallback count.

The first corrected compiler took approximately 13 minutes. Subsequent Phase 5
audits found whole-program cross-products in IR verification and LLVM function
emission, followed by repeated folded grammar-rule comparisons across the
million-node syntax tree. Removing those costs reduced the verified production
self-host to approximately 6 minutes 41 seconds. The remaining architecture is
being preserved as a reference for a v4 compiler rather than expanded with more
v3 worker machinery.

## Reproduced defects

- Eight-job UBECore compilation took 19–27 seconds versus about 7.7 seconds
  sequentially before the investigation; one run crashed with an array index
  of `-1`.
- Eight-job self compilation exceeded 20–30 minutes or failed after prolonged
  execution.
- Isolated self syntax generation took 166 seconds with one job; the old
  eight-job parser did not finish within seven minutes.
- Semantic workers serialized roughly one binding per syntax node, accumulated
  immutable wire strings quadratically, insertion-sorted merged results, copied
  overlapping token slices per expression, and reconstructed the complete
  frozen type/scope/symbol universe once per worker.
- Frontend workers reconstructed the complete embedded grammar per source and
  copied private token/syntax arenas to the coordinator.
- Three insertion-sort guards used non-short-circuit `And`, allowing index
  `-1`; these are now nested, bounds-safe loops.

## Corrections

- Removed the redundant semantic-binding worker round trip; the coordinator
  retains its canonical binding universe.
- Replaced expression insertion sorting with an ordered worker-stream merge.
- Split semantic work into bounded records instead of one repeatedly copied
  immutable string.
- Added a transfer-size preflight and independent semantic publication-lock
  initialization.
- Kept parsing on the coordinator's already loaded grammar.
- Performance-gated ordinary Phase 3/4 worker activation off. Explicit fault
  sites still enter the worker paths and preserve cleanup/error coverage.
- Added permanent UBECore jobs-one/jobs-eight LLVM parity coverage.
- Replaced verifier-wide edge scans with a source-block adjacency index.
- Restricted LLVM function emission to each function's canonical instruction
  span and indexed managed safe points by instruction.
- Added deterministic `ir_verify_edge_probe_count` and
  `llvm_instruction_visit_count` profile fields and clean gates.

## Corrected measurements

UBECore, identical LLVM SHA-256
`31E77BC5F66A0599C6BA05BD39F96FAE56B43FEB9F7F5D2781B0370F47152728`:

| Requested jobs | Effective jobs | Total | Frontend | Parse | Semantics |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 1 | 5.536 s | 0.987 s | 0.609 s | 1.949 s |
| 8 | 1 | 5.290 s | 0.933 s | 0.587 s | 1.757 s |

Final compiler self-host with `--jobs 8` (effective one) completed in
800.730 seconds. The preserved stage-1 compiler built the exact same source in
851.8 seconds. Both emitted LLVM SHA-256
`88C4A905F12B0D8318C5C2F0626F6C84CBD36426B12D8B8630EE17C442DDAAFC`.

| Phase | Time | Share of total |
| --- | ---: | ---: |
| LLVM emission | 244.572 s | 30.5% |
| Semantics | 182.264 s | 22.8% |
| IR verification | 143.723 s | 17.9% |
| IR lowering | 135.673 s | 16.9% |
| Frontend | 46.838 s | 5.8% |
| Parse | 43.601 s | 5.4% |

Peak working set was 901,392 KiB. The generated LLVM was 63,363,819 bytes and
contained 581 functions, 57,662 blocks, and 148,093 IR instructions.

## Current Phase 5 baseline

After the IR/LLVM indexing corrections, the exact-source self-host completed
in 467.140 seconds with peak working set 895,868 KiB. Seed-built and self-built
LLVM both had SHA-256
`1EE666FA6B0AAC03F323A1EE8E22AF4E834FC2F2622E793C490D82457B07E8AA`.

| Phase | Before indexing | Current | Reduction |
| --- | ---: | ---: | ---: |
| Total wall | 800.730 s | 467.140 s | 41.7% |
| IR verification | 143.723 s | 0.485 s | 99.7% |
| LLVM emission | 244.572 s | 63.280 s | 74.1% |
| Semantics | 182.264 s | 181.797 s | unchanged |
| IR lowering | 135.673 s | 124.967 s | 7.9% |

The current build contains 148,601 IR instructions and 92,021 edges. It records
148,253 LLVM instruction visits and 133,327 verifier edge probes, proving the
indexed stages stay linear in their relevant record counts.

## Final bounded semantic audit

Semantic declaration and expression walks compared folded grammar-rule names
for every syntax node. On the self-host corpus this repeated Unicode-aware
string work millions of times even though each node already stores its canonical
numeric `ProductionRule`. Resolving the small set of required grammar rules once
and comparing their integer identities reduced the production fixed-point run
as follows:

| Phase | Previous | Rule-indexed | Reduction |
| --- | ---: | ---: | ---: |
| Total wall | 467.140 s | 400.656 s | 14.2% |
| Semantics | 181.797 s | 111.983 s | 38.4% |
| IR lowering | 124.967 s | 127.530 s | no material change |
| LLVM emission | 63.280 s | 66.451 s | no material change |

The rule-indexed source contained 44 files, 1,295,349 bytes, 299,684 tokens,
and 1,249,321 syntax nodes. Seed-built and production-self-built LLVM were
byte-identical with SHA-256
`C80FC435047E1B31BE8296EC54115BEE797022F8BE67B41ACEE46747F41D318C`.
This is a 50.0% reduction from the first corrected 800.730-second baseline.

A follow-up experiment replaced the remaining linear expression lookup caches
with bucketed chains. It was not retained: the added resolver parameters exposed
the current expression-call lowering boundary at 20 arguments, and the owner
elected to stop extending v3. The experiment was removed before handoff.

## Resumption point

Treat v3 as the executable reference compiler and bootstrap bridge for v4. Keep
the verified `C80FC...D318C` fixed point reproducible, retain its diagnostics and
corpus as differential oracles, and do not carry the Phase 3/4 worker transport
design into v4. The new design needs indexed ownership, immutable shared input,
function-local work units, and canonical merge numbering from the outset.
