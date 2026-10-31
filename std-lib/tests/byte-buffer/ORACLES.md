# Byte-buffer acceptance oracles

These expected results are specified independently of generated compiler output.
The functional and instrumented obligations below have been executed through
both exact source-built stages; see [current evidence](../../BYTE-BUFFER-EVIDENCE.md)
for identities, measurements and qualification limits. These predefined behavior
and budget requirements remain the acceptance oracles. The ordinary source
modules remain the subject under test. The runner removes only their two documented envelope lines and
concatenates their unchanged bodies with each fixture.

## Functional fixtures

Each case must exit zero, produce exactly the single PASS line in `cases.json`,
and produce empty stderr through each exact accepted v2 stage. Raw emitted LLVM
must be identical between stages. All failure diagnostics in the UBE fixtures
exit one, so a successful launch alone cannot satisfy an oracle.

| Fixture | Independently required observations |
|---|---|
| `basics.bas` | Default length/capacity 0; zero reserve; all 256 byte values including embedded zero; capacities 8 at lengths 1/8, 16 at 9/16, 32 at 17, 256 at 256; exact-length independent snapshot; independent record assignment and ByVal mutation; clear retains capacity; reuse preserves earlier snapshot; empty snapshot replaces an earlier nonempty output. |
| `overlap.bas` | Source `[10,20,30,40,50]`, range `(1,3)` produces `[20,30,40]`; self append yields `[20,30,40,20,30,40]` at capacity 8; appending original self range `(1,5)` during growth produces `[20,30,40,20,30,40,30,40,20,30,40]` at capacity 16; end/default zero spans succeed without count change. |
| `rejections.bas` | Negative reserve and each negative/out-of-range source span reject without buffer change; Count -1 and Count 9 in capacity 8 reject; queries return -1, UTF-8 output becomes zero, mutation/output publication do not occur; earlier output byte 91 and buffer byte 65 survive. |
| `utf8.bas` | Empty and cleared logical input have zero scalars even with retained invalid bytes; `[00,41,C2,A2,E2,82,AC,F0,9F,98,80]` has exactly five scalars; a final C2 truncates, adding A2 makes a subsequent independent validation succeed with one scalar; ED A0 80 rejects as surrogate; all failed scalar outputs are zero. |

SourceStart is a zero-based payload offset relative to Source's first stored
byte. It is independent of a source array's language lower bound. Owned buffer
factories always create lower-zero storage.

## Failure, lifetime and cost obligations

The functional runner alone does not establish the following instrumentation
obligations. The separate cost/ownership/concurrency runner executes them;
recorded results are in the linked evidence. Compiler source ingestion must
retain these gates when it starts consuming this module:

1. Seed an earlier Err (for example 123). Successful append/reserve/snapshot,
   zero/default spans, clear, UTF-8 validation/rejection and domain rejections
   preserve that exact thread-local value. Returned status is fresh even with
   stale Err 7. ScalarCount is independently zero on validation failure.
2. Start from count/capacity 8, bytes `[0,1,2,3,4,5,6,7]`, with an earlier owned
   output `[91,92]`. Force both attempts of the next payload allocation to fail.
   Appending byte 8 returns False/Err7; all eight bytes, count 8, capacity 8 and
   earlier output remain unchanged. One failed attempt followed by collection
   and retry succeeds, preserving the earlier Err and bytes.
3. Independently fail the snapshot's prepared-array allocation and its final
   `Array.TryCopy` payload allocation. Each returns False/Err7, preserves the
   earlier output `[91,92]` and original builder, and leaves no reachable partial
   result. After releasing roots and collecting, partial storage is reclaimed.
4. Measure actual allocation, bulk copy, zeroing and live-byte operations for
   N single-byte appends at N = 1, 8, 9, 16, 17, 256, 4096 and 65536. Growth copies
   must be `<2*N`; capacities must meet the contract. Each successful snapshot
   copies at most `2*N` payload bytes and has exactly N bytes. Keep metadata,
   retries and zero-initialization visible as separate measurements.
5. Satisfied reserve, clear and queries request zero payload allocations/copies.
   UTF-8 validation requests zero payload allocations/copies. Successful scans
   feed exactly Count bytes and call Finish once; malformed input may reject
   before Count bytes or Finish, while truncation rejects at Finish. For an
   invalid first byte 255, expect one Feed call and zero Finish calls.
   Directly instrument executed operations; size-derived counters
   cannot qualify these claims. The existing standalone decoder gate must still
   observe zero allocations.
6. After each worker's builders and snapshots leave scope, collect and require
   zero live payload storage attributable to that worker. Exercise early returns
   and failed snapshot publication, as well as normal completion.
7. Run four actual native threads sharing only immutable input, with independent
   builders and outputs and distinct marker bytes 0, 65, 128 and 255. Each must
   preserve its own marker, exact length and snapshots through repeated clear/
   append/reserve operations; join all workers and require cleanup. Separate
   processes alone do not establish this concurrent-instance property.

Maximum-count arithmetic requires an additional injected/allocation-free probe:
request `2147483647` minimum capacity and inspect the resize request or reject it
through deterministic allocation failure. Doubling must never wrap; no success
or performance claim depends on allocating two gigabytes during the test.
