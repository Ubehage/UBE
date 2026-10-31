# Production parser CLI oracles

`cases.json` independently fixes exact exit/stdout/stderr behavior for the actual
production compiler, built from its unchanged manifest through both selected
source-built v2 stages. The CRLF/BOM/Deseret missing-operand witness pins original
scalar line/column separately from its UTF-8 byte anchor. Source/file, raw lexical,
envelope, deferred-family and still-unavailable semantic checking results remain
distinct. Pending conditional input must defer before whole-file scanner/envelope
requirements can reject malformed or reserved inactive text.

Statement date candidates retain their complete hash-delimited original spans
even though a raw MODULE scan keeps separate punctuation. An invalid calendar
field still reaches the unavailable semantic-check result: this gate verifies
literal grouping without claiming date conversion or calendar validity.
Print expression candidates cover the separate file-number lookahead boundary.
A physical continuation within a candidate must report the complete offending
continuation token rather than becoming legal date text after trivia removal.

New parser diagnostics print an immutable error-code/message header naming the
following three numeric lines: original scalar line, scalar column and byte
offset. This avoids constructing Strings while reporting parser storage failure.
The older source/scanner diagnostic format remains covered by its exact cases.

`diagnostic-oom/check.ps1` runs against each actual production LLVM image. Its
checked native adapter calls the intact `TryPrintSourceSyntaxFailure` and rootless
`PrintSyntaxStorageFailure` bodies. The complete runtime is compiled with test-only
allocator observation. All eleven new failure kinds, an unknown-kind default and
failed position preparation run with allocation enabled and persistently denied;
the independent oracle requires exact output, unchanged input bytes, preserved
incoming Err77 and zero runtime malloc/calloc/realloc attempts. A separate case
fills the real root registry to its production limit, requires fresh False and
Err7, prints the actual static fallback, and releases every real root. Counts do
not claim that the C library or OS never allocates internally.

The separately pinned `before-kind5.json` and `before-kind5-kind101.json` retain
the pre-fix synthetic captures: the actual old formatter exited70 on its first
runtime allocation under persistent denial for both storage and ordinary syntax
failures. They pin the old source, actual helper symbol, raw LLVM and tool/runtime
identities. They are historical evidence; current runs do not require rebuilding
or executing the old compiler, and do not call a reimplemented formatter.

The listed real compiler and UBECore modules must reach the bounded syntax result,
then report semantic checking unavailable. This establishes syntax consumption of
those exact sources; it does not establish semantic checking, executable output,
self-hosting, complete language support, inactive-text recovery, or parser costs.

Run `rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-parser-cli.ps1`
for qualification against a refreshed accepted source cohort. `-DiagnosticOnly`
still pins accepted bootstrap executables/runtime
and current tested source bytes, but explicitly skips the stale accepted-source
audit and cannot qualify the final cohort. Every report records mode and hashes.
