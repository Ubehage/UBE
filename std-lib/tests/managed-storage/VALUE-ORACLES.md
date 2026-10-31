# Compiled managed-value acceptance oracles

`cases.json` fixes native outputs before running either source-built compiler.
The maintained command is `std-lib/tools/check-managed-values.ps1`; its selected
compiler must bind a successful, immutable source-build manifest. Successful
compilation by itself does not satisfy an oracle.

| Fixture | Independent requirement |
|---|---|
| `array-values.bas` | Empty/default length, zero bytes, embedded zero/255, independent assignment and ByVal, deliberate ByRef mutation, self-assignment, preserved growth and independent lengths. |
| `record-values.bas` | Default nested scalar fields, array-containing record assignment and ByVal independence, ByRef mutation, self-assignment, actual target record size/alignment 24/8. |
| `results.bas` | Independent array/record results, nested result calls, mutation after assigning a result, result/local survival across explicit collection. |
| `nested-roots.bas` | A record owns an array of records, each owning Byte storage. All live nested bytes/scalars survive allocation and repeated explicit collection; a copied graph stays independent. |
| `borrowed-element.bas` | A ByRef element stays live while the callee replaces its parent array and collects. The borrowed element and replacement array remain distinct. |
| `scope-cleanup.bas` | A thousand normal and early-return calls allocate local managed records/copies. Collection after return leaves zero additional managed payload bytes. |
| `failure-boundaries.bas` | Real compiled UBE copy/growth operations see injected allocation failures. Two failures preserve destination bytes/length and set Err 7. One failure retries successfully, preserves Err 77 and produces independent storage. Resize returns a fresh Boolean. Dead allocations are reclaimed. |
| `initialization-boundaries.bas` | Failed ByVal-array clone returns a neutral scalar without entering the body; failed whole array/record result copying retains the neutral result. The record source is fully initialized before injection. Caller inputs stay independent. Single-failure retries preserve stale Err and dead initialized values are reclaimed. This is an operation boundary, not an implicit transaction over later user statements. |

`entry-oracle.c` calls the entire compiler-generated program entry, seeds Err 77,
and checks the exact post-collection managed live-byte baseline. For the record
fixture, added LLVM layout-query functions inspect the compiler's actual type;
they do not define or replace it. `failure-oracle.c` owns two precise test roots
and invokes six compiler-generated UBE procedures through signature-checked LLVM
bridges. It injects failure only at the runtime's managed allocation boundary;
the C driver does not implement UBE copying, resizing or value construction.

`binding-cases.json` separately specifies malformed storage-binding signatures,
parameter modes/types, metadata targets/bodies, unknown roles, cross-module
declarations and managed program entry rejection. Each must return exactly the
specified diagnostic category and exit one, publish no LLVM, and give identical
diagnostics through both stages. The managed Main fixture explicitly assigns
an empty Long array; it exposes the earlier entry/result ABI mismatch instead
of stopping at an unrelated missing-result error.

Every positive fixture must satisfy its native oracle through both source-built
stages, with empty stderr, exit zero and byte-identical raw LLVM. Report checks
count stage/native comparisons, stage LLVM identity and rejection cases; they are
not a count of individual scalar assertions. The separate C substrate suite
checks runtime traversal, root capacity, partial-construction rollback and
bookkeeping exhaustion. Neither suite establishes builtin String semantics,
complete managed language coverage, a public owned-buffer API or concurrent
mutation behavior.

The earlier ten failed obligations and exact old compiler identities remain
recorded in `../byte-storage/obligations.json` and `../../BYTE-TEXT-EVIDENCE.md`.
The new suite does not rewrite those historical failures as passes. Foundation
`array-copy.bas`, `array-byval.bas` and `record-array-copy.bas` additionally move
from rejection cases to positive mutation oracles; inline recursive records
retain their independent rejection case.
