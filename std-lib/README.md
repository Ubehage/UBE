# UBECore standard library

`std-lib/` is the fresh UBECore project, established by the owner on 2026-10-30.
The standard library will grow with concrete compiler needs and provide
reusable facilities for ordinary UBE programs.

The previous library is preserved separately in
[`archive/source-library/`](../archive/README.md). No implementation, intrinsic
declarations, or public APIs have been imported from it.

## Current state

UBECore supplies qualified byte, UTF-8, Unicode/cursor, file-input and bounded
Threads facilities. `Threads.bas` provides fresh identity, liveness, stop, wait
and yield APIs under [THREADS-CONTRACT.md](THREADS-CONTRACT.md). The current
source-built bootstrap passes 592 grouped assertions, including actual UBE
reference captures, value-copy semantics, failures, roots, TLS and cleanup.
[CONCURRENCY-EVIDENCE.md](../compiler/UBE_Compiler_v3/CONCURRENCY-EVIDENCE.md)
records the exact current cohort and the compiler's separate 5652-assertion
source-set proof. Source policy, ordering and orchestration remain compiler-owned;
no executor or compiler source type belongs in UBECore. Full threading, general
String and native Library packaging are not qualified by this bounded slice.

Instrumented four-worker compiler execution was slower; collector contention
needs focused follow-up, and no speedup is claimed. All later development-plan
rows remain proposed and need their own contract and owner review.

## Earlier foundation checkpoints

[`UBECore.UBE`](UBECore.UBE) includes its identity module and two portable
facilities: [`Utf8.bas`](src/portable/Utf8.bas), an allocation-free incremental
decoder, and [`ByteBuffer.bas`](src/portable/ByteBuffer.bas), owned byte storage
with geometric growth, failure-atomic operations and independent snapshots.
Both ordinary module bodies pass independent native tests through both accepted
v2 stages. The first compiler consumer now also requires
[`FileBytes.bas`](src/portable/FileBytes.bas): counted UTF-8 command arguments
and paths, bounded recoverable byte reads and explicit resource close. That
extension and intact source-library integration pass the combined gate; see
[the consumer evidence](../compiler/UBE_Compiler_v3/SOURCE-INPUT-EVIDENCE.md).
There is no released library binary. The
[source-built v2 tool](../compiler/UBE_Compiler_v2/FOUNDATION-VERIFICATION.md)
passed 501 bounded acceptance assertions at that checkpoint, including the
[opaque native-value mechanism](tests/native-type/NATIVE-EVIDENCE.md).
Managed array/record copying, roots, cleanup, failure and component concurrency
were covered by that gate; builtin String remains separate work.

The scanner's concrete library prerequisites are also implemented:
[`Unicode.bas`](src/portable/Unicode.bas) supplies Unicode 18 Letter membership
and default simple folding, and [`Utf8Cursor.bas`](src/portable/Utf8Cursor.bas)
borrows bytes to read one scalar without retaining or copying the source.
Both use ordinary UBE over the existing storage/decoder facilities. Official raw
Unicode data, license and provenance are checked in for offline regeneration.
That source-cohort gate passed eight Unicode/cursor assertions through both
accepted bootstrap stages. That checkpoint's complete gate passed 501 assertions, including
the compiler's raw scanner and source-envelope consumer. See
[`UNICODE-EVIDENCE.md`](UNICODE-EVIDENCE.md) for exact identities and limits and
[the scanner evidence](../compiler/UBE_Compiler_v3/SCANNER-EVIDENCE.md) for
compiler-specific qualification.

The owner approved investigation of a bounded stage-zero/v2 bootstrap route
and an early proof of library-defined native datatypes. The collaborating
fresh compiler is [Compiler v3](../compiler/UBE_Compiler_v3/README.md); the
previous v3/v4 implementations are archived separately.

The historical `bootstrap/build.ps1` gate continues to select the archived
library. It does not build this project.

## Development

- [`INVENTORY.md`](INVENTORY.md): finished-library scope covering VB6, VBA7,
  UBE additions, and compiler-needed foundations, with ownership and open
  compatibility decisions separated from implementation claims.
- [`DESIGN.md`](DESIGN.md): ownership, compiler/library/platform boundaries,
  and evidence required before use.
- [`FOUNDATION.md`](FOUNDATION.md): primitive/type-mechanism ledger, independent
  acceptance obligations and the original native-type proposal.
- [`NATIVE-TYPE-PROPOSAL.md`](NATIVE-TYPE-PROPOSAL.md): adopted scalar mechanism,
  including representation, binding, access, copy and failure rules.
- [`FOUNDATION-EVIDENCE.md`](FOUNDATION-EVIDENCE.md): bounded bootstrap results,
  exact provenance, known failures and next action.
- [`ROADMAP.md`](ROADMAP.md): current work and the next concrete deliverable.
- [`BYTE-TEXT-CONTRACT.md`](BYTE-TEXT-CONTRACT.md): byte/text ownership and decoder API.
- [`BYTE-TEXT-EVIDENCE.md`](BYTE-TEXT-EVIDENCE.md): initial decoder and storage-gap history.
- [`MANAGED-STORAGE-PROPOSAL.md`](MANAGED-STORAGE-PROPOSAL.md): approved mechanism scope.
- [`BYTE-BUFFER-CONTRACT.md`](BYTE-BUFFER-CONTRACT.md): owned buffer API and cost budgets.
- [`BYTE-BUFFER-EVIDENCE.md`](BYTE-BUFFER-EVIDENCE.md): earlier source-body gate and measurements.
- [`FILE-BYTES-CONTRACT.md`](FILE-BYTES-CONTRACT.md): byte-file/argument declarations,
  failure codes, explicit resource ownership and platform boundary.
- [`UNICODE-CONTRACT.md`](UNICODE-CONTRACT.md): scalar letter/fold and borrowed
  UTF-8 cursor APIs, ownership, failures and costs.
- [`UNICODE-EVIDENCE.md`](UNICODE-EVIDENCE.md): official data identities,
  exhaustive tests and exact recorded source-cohort qualification.
- [`AGENTS.md`](AGENTS.md): contributor instructions.

The active consumers include the compiler's source reader, scanner, bounded
parser and `TryParseSources` source-set operation. UBECore owns only the generic
facilities; compiler source policy and diagnostics stay outside the library,
and OS entry stays in the platform adapter. Current qualification is in
[CONCURRENCY-EVIDENCE.md](../compiler/UBE_Compiler_v3/CONCURRENCY-EVIDENCE.md);
earlier parser and foundation records above preserve their original checkpoints.

The target inventory can be checked from the repository root with
`rtk proxy powershell -NoProfile -File std-lib/tools/check-inventory.ps1`.
This checks documentary coverage and links, not library behavior.
