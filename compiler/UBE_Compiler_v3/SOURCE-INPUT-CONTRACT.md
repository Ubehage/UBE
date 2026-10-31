# Compiler source input

This implements the next item in `Roadmap.md`: a genuine consumer of UBECore's
byte buffer, incremental UTF-8 decoder and independent snapshots. It does not
implement a lexer, parser or code generator.

## Representation and ownership

The compiler owns one mutable `SourceInput` per input. `BeginSourceInput` resets
it with an explicit byte limit from 0 through 2147483646 (leaving room for the
one-based EOF column). `AppendSourceInput` borrows a counted
byte range of a zero-based array for one call. This compiler-internal API uses
the bounded bootstrap's zero-based source arrays; arbitrary lower bounds are
not qualified here. Accepted bytes are copied into its ByteBuffer. No input
reference survives the call. A failed append leaves the previous accepted bytes
and cursor unchanged; the returned `SourceFailure` describes this attempt.

`TryFinishSourceInput` validates the final decoder/newline state and publishes
an independent exact byte snapshot into `SourceDocument`. Failure preserves the
old document. Subsequent appends, resets or input mutations cannot change a
published document. Document bytes are immutable by their owner's convention;
ordinary UBE value assignment makes independent copies. Reserved state fields
must not be mutated directly. Outputs must not alias input state/storage.

No global mutable compiler state, worker pool, scheduler or implicit ownership
transfer is introduced. Private mutable instances may be used independently by
bounded workers; shared source documents must remain immutable.

## Source policy and positions

The authority is `../../lang-doc/language-spec.md` sections 1–2 and
`../../lang-doc/project-files.md`. Input is strict UTF-8, with an optional initial
UTF-8 BOM. All original bytes remain, including the BOM, embedded zeroes and
original LF/CRLF. No normalization, code-page guessing, String conversion or
synthetic final newline occurs. U+0000 is preserved; lexical legality is later
context-sensitive work. An isolated CR is rejected. A noninitial U+FEFF is an
ordinary scalar.

Byte offsets are zero-based into the original bytes. Scalar offsets are
zero-based from content after an initial BOM; CR and LF each count as a scalar.
Line and column are one-based. A column counts Unicode scalars, including a tab
as one scalar. LF advances one line and resets the column; CRLF advances one
line in total. A pending CR does not advance the displayed cursor. Empty input
has line count 1. An initial BOM has content start 3, scalar count 0 and cursor
line 1/column 1. Otherwise content start is 0.

An invalid UTF-8 sequence is diagnosed at its first byte, including an incomplete
sequence at EOF. An isolated CR is diagnosed at the CR. Chunk boundaries do not
change results or positions. The byte limit is checked before append allocation.
Malformed input reports its earliest detected sequence; an oversized supplied
chunk reports the byte limit before examining that chunk.

`SourceFailure.Kind`: 0 success; 1 invalid API range/state/limit; 2 byte limit;
3 invalid UTF-8; 4 isolated CR; 5 storage failure; 6 file operation failure
(the separate fresh file failure code identifies the operation). The failure position is the
offending sequence/CR, or the accepted end cursor for domain/storage failure.
Fresh Boolean status determines success; stale Err is never inspected.
When the procedure body is admitted, the failure kind is also fresh.
Like other UBE procedures, a failure to register its minimum managed roots
returns a neutral Boolean before entering the body and preserves ByRef outputs.
Callers initialize Failure.Kind to 5 before a managed Try call, so an admission
failure cannot accidentally reuse a prior success classification. The compiler
driver does this at every such call. The native entry wrapper separately checks
an explicit fresh admission flag; it must not report process success when the
source Main body could not start. It does not infer admission from Err.
Encoding/newline/domain failures preserve Err; allocation failures retain the
existing UBECore Err 7 behavior. Success preserves incoming Err.

## External input and command behavior

Reusable raw file reading, Unicode command arguments, resource handles and
byte storage belong in UBECore. The compiler drives bounded reads and explicitly
closes on every success, failure and cancellation path before publication.
`TryReadSourceFile` consumes the size captured at open using at most 4096 bytes
per read and one extra byte probe. Positive short reads are progress; premature
EOF and observed growth are controlled file failures. This detects observed
length changes, not every possible simultaneous edit or a filesystem snapshot.
The caller supplies an initially zero owned `OpenToken`; ordinary completion
and failures close it. A genuine native close failure leaves that token with
the caller for explicit retry; it is never silently discarded or described as
released. Main retries once and reports a second cleanup failure before process
exit (the OS then owns process resource teardown). Synthetic close-failure tests
distinguish reported failure after actual release from retained ownership.

If both an input/storage operation and cleanup fail, the primary source/file
classification is retained and any remaining token stays owned by the caller.
Err describes the last failed external cleanup operation, rather than pretending
its failure did not occur. Callers use the fresh Boolean and initialized failure
record, not Err, to classify the overall operation. A successful close preserves
the primary operation's Err.

It owns source policy, resource limits and diagnostics. It never feeds source
bytes through the bootstrap NUL-terminated String representation.

The initial executable accepts `--check <source-file>`, the existing source-check
interface. Invalid invocation, file failure and invalid encoding/newlines return
controlled diagnostics and a nonzero status. Successful ingestion is followed
by a controlled nonzero diagnostic that source checking is unavailable. It must
not claim language checking or produce an output artifact. Native/legacy source
envelope interpretation, lexical/semantic checks and normal project compilation
remain later compiler work. Native envelopes in this compiler's own build
inputs are validated by the bounded bootstrap route.

## Acceptance oracles

Before claiming completion, the maintained consumer gate must check both v2
stages with byte-identical LLVM and independent native assertions for:

- Exact bytes, optional BOM, zeroes, empty input, no trailing LF and no Unicode
  normalization; independent snapshots and value copies.
- Valid multibyte scalars, byte/scalar/line/column divergence, CRLF, invalid UTF-8,
  truncated input and isolated CR at every chunk boundary.
- Domain/boundary/size rejection and failed publication preserving old output;
  forced allocation failures and successful calls with stale Err.
- Real Unicode file/argument paths, missing/unreadable/changed input, bounded
  reads, short reads, explicit cleanup and cancellation between reads.
- Private concurrent consumers with immutable shared bytes, deterministic
  results, no residual roots, managed storage or external resources.
- Actual read, allocation and copy observations across sizes, rather than work
  inferred from input length. Retain all earlier bootstrap/library gates.

Exact supported limits, commands, source/tool/artifact identities and results
belong in the separate evidence document, avoiding build-provenance hash cycles.
