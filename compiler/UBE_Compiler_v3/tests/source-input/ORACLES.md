# Independent source input oracles

The byte policy and cost limits below precede the maintained native tests.
The tests call unchanged UBE production functions through signature-checked
test-only LLVM wrappers. Their reference parser uses a separate scalar decoder
and explicit expected positions; it does not call UBECore to derive answers.

For every split of each vector, append the prefix and suffix separately and
finish. The result must equal one-chunk ingestion. Test all split points of
valid vectors: empty, ASCII, LF, CRLF, a missing final newline, initial BOM,
noninitial BOM, zero, tab, 2/3/4-byte scalars, decomposed and composed accents.
The complete byte snapshot must compare equal with the original, including BOM.
Its scalar count excludes only an initial BOM. Its line count is one plus LF
count. Mutating caller bytes and subsequently resetting/appending the input
must preserve the old snapshot. Two published documents are independent.

Malformed vectors include every isolated continuation and forbidden leading
byte, overlong 2/3/4-byte forms, surrogate, above-U+10FFFF, incomplete forms,
invalid continuation, isolated CR and CR followed by invalid UTF-8. Report the
first byte of the invalid UTF-8 sequence or the first isolated CR. A CR followed
by any byte except LF is already known to be isolated, even if that following
byte is itself invalid UTF-8. Failures preserve prior published documents.

Check negative/range-overrun offsets/counts, zero-byte spans at end, exact byte
limit and limit+1, invalid maximum and the maximum representable API limit.
The API must reject before allocating for a known invalid domain/limit. Failed
append preserves accepted bytes and decoder/cursor state, permitting a valid
retry. EOF validation failure also permits a subsequent completing append.

Force the managed payload allocator to fail twice (including retry) on append
growth and each snapshot payload allocation. Require False, storage kind 5,
Err 7, old document/state intact, then successful retry. Seed Err 77 before
successes and domain/encoding failures; they must leave it unchanged. All root
registrations and payloads must be reclaimed after explicit caller root release
and collection. Four bounded native workers use private state/output with
immutable shared input and deterministic expected results.

Measure executed UTF-8 Feed calls, actual managed allocation requests and actual
payload copy stores for sizes 0, 1, 31, 4095, 4096, 4097, 16384 and 65536. Use
4096-byte chunks. Valid bytes are decoded once (an initial BOM is decoded but
excluded from count). Accepted bytes are appended once; growth copies less than
2N for N>0; final snapshot copies no more than 2N. Thus total explicit byte
copies are less than 5N for N>0 and zero for empty input. Rootless state reads
are separate bookkeeping, not byte payload copies. This component bound excludes
file scratch publication: real file reads add N native scratch-to-managed stores,
so complete loading plus ingestion/snapshot uses less than 6N payload copies for
N>0, excluding command/path transport. Report allocation requests,
requested zero initialization, sampled process memory and elapsed time with
their measurement boundaries. No bound on wall time is inferred from a single
machine run. No UBE worker scheduler is claimed.

The CLI oracle checks fresh failure diagnostics and nonzero status for bad
arguments, missing files, invalid bytes/newlines and completed intake followed
by unavailable source checking. It never emits a compiler output artifact or
reports a source program as valid. Unicode paths must arrive through counted
Unicode command arguments. File primitive gates separately inject short reads,
I/O/close failures, file mutation, token misuse and cancellation cleanup.
