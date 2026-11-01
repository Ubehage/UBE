# Independent project-input oracles

The project contract, diagnostic contract and PROJECT-INPUT-CASES.md define the
consumer; bootstrap acceptance is not the project-file language authority.

## Manifest structure component

`manifests.json` supplies 53 independently specified byte fixtures, dispositions,
metadata and original spans. Check canonical/BOM/CRLF/no-final-LF input, blanks,
comments, ASCII key/setting case, decimal leading-zero versions, required fields,
scalar duplicates, quoted/doubled-quote values, unknown/known unsupported keys,
bare/bracketed/Unicode/reserved names, settings, reference counts and 256/257
source boundaries. A well-formed unavailable facility remains explicit metadata
for the loader; this component's success is not complete project acceptance.
The parser stores raw views and never opens the named paths.

Reject NUL in every part of manifest text, including a comment, before schema
interpretation. Keep its exact original byte witness. The source-document
qualifier intentionally allows that Unicode scalar, so it cannot substitute for
this manifest rule. The tiny nul-comment case previously succeeded; its corrected
run must fail UBE1302 at bytes 2..3. Keep that regression.

Every case checks metadata/failure, unmodified complete document bytes, preserved
incoming Err and zero live payload after root release/collection. Compare exact
native record sizes/offsets before accessing fields. Both tools must produce
identical raw LLVM, without changing production UBE bodies or layouts for tests.

The observation budgets are fixed independently of measured output: no payload
copy leaves during parsing, at most 16 runtime allocator calls, at most 32768
additional requested live bytes (including runtime allocation headers/workspace),
and at most 64*N+1024 watched-source element reads. Nonempty documents must report
nonzero actual reads. Report executed allocator/copy/read events, not values
calculated from N. These broad ceilings cover the fixed 256-source/two-reference
metadata vectors, private scalar seen-state and source-name validation.

Observe native reads at the existing typed-element access boundary, filtering by
the actual rooted document-array holder. A deliberate watch on the independently
owned input construction array must fail the nonzero-read check. This guards
against a disconnected or fabricated source-read observer.

Deny each of the three metadata payload allocations, including retry; require
fresh storage code 1310, unchanged input and balanced roots. Fill the actual
1048576-root registry and require controlled pre-body failure followed by retry.
Four native test callers share the immutable qualified document and keep private
metadata/status, repeat eight times each, retain thread-local Err, force collection
and drain every root/payload. This is component reentrancy evidence, not a new
executor or a replacement for actual UBE source-worker qualification.

## Initial consumer failure controls

The intake harness uses production UBE discovery and the existing UBE workers.
Its first 27 cases execute budgets 1,2,4,4,2,1. Successful results must retain
exact source bytes, canonical source associations, complete tokens/nodes/metrics
and equal results across budgets. Every rejection preserves the earlier complete
reference and its observable graph; no intake handle or worker may remain.

Additional test-only native controls must exercise the actual 1048576-root
registry, an OS read failure, a real retained-token close failure, malformed
UTF-8 together with a failed close (the UTF-8 failure remains primary), and
cancellation requested during the current bounded file read. After removing the
fault, explicit close/retry and an ordinary complete parse must succeed. These
controls do not replace the separate allocator, start/wait, reentrancy, exact
metadata-span, CLI or performance requirements.

The enclosing facade must also retain the old graph and drain on actual native
start/wait failure. For allocator qualification, first count executed native
calloc positions across the caller and actual UBE worker for a successful
one-worker request. Deny each position and its retry if the operation retries
(the host reader-record allocation has one attempt). Require controlled storage
or allocation-induced worker-admission
failure, old graph retention and no residual file/worker resources, followed by
successful retry. Report actual denied positions and reject a disconnected
observer. This exercises the project operation, not merely its manifest helper.

## Complete consumer witnesses

The ordinary 35-case proof additionally checks real hard links, Unicode paths,
package-local names, folded name collisions and four simultaneous independent
contexts. The separate optional case-sensitive fixture requires distinct files
named Main.bas/main.bas and never changes the host setting.

`intake-contract-proof.h` freezes independent constants for a two-package
BOM/CRLF/comment manifest with nondefault settings: complete metadata fields,
all declaration/referral intervals, retained paths and captured directory, and
source/path/metadata byte totals. It also freezes complete existing failure
witnesses, including exclusive ends, and finite request-domain/zero/exact-fit/
one-short boundaries. A flat literal can use zero depth; the depth-zero rejection
fixture contains an explicit parenthesized expression requiring depth.

`intake-observation.h` applies the existing native worker enter/exit observation
pattern to successful and dual-parser-error projects. It waits for actual native
completion in descending canonical order and asserts the full lowest-source
failure, old graph retention and drain at budgets 1/2/4. These are test controls,
not a production scheduler. Metadata/span/accounting/failure-end/order mutations
must each be rejected by their independent checker. The separate native contract
variant adds one group per compiler without altering the original allocator
fixture or its 375 observed denial positions.

Jobs CLI, source-only compatibility, full source/retained qualification and the
performance gate have separate reports; none follows from a component grammar
pass. Diagnostic mode never refreshes source-built qualification. Current exact
commands, reports and remaining acceptance are in PROJECT-INPUT-EVIDENCE.md.
