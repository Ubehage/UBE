# Unicode scalar helpers

The scanner is the concrete first consumer of `Unicode.bas` and `Utf8Cursor.bas`.
Both modules contain ordinary portable UBE bodies. They introduce no primitive,
compiler record dependency, mutable table initialization, or global state.

`IsUnicodeLetter(Scalar As Long) As Boolean` is true exactly for Unicode
18.0.0 general categories Lu, Ll, Lt, Lm and Lo. All other values return false,
including negatives, surrogates and values greater than U+10FFFF.

`SimpleFoldUnicode(Scalar As Long) As Long` uses the default Unicode
18.0.0 simple fold: CaseFolding status C and S. It excludes full expansions (F)
and Turkic alternatives (T). Unlisted values, including invalid scalars, return
the original Long. Thus sharp s stays sharp s, capital sharp s folds to sharp s,
and the Kelvin sign folds to ASCII k. Neither function normalizes text.

Both helpers take values, retain nothing, allocate and copy nothing, preserve
Err, and are reentrant/thread-safe. Balanced decision trees have bounded
logarithmic comparison cost and no runtime table-building cost. The checked-in
source is generated offline by `tools/generate-unicode.ps1` from the recorded
raw files under `data/unicode/18.0.0/`; the neighboring Unicode License V3 and
provenance hashes cover those files and the derived tables. Regeneration checks
every recorded data hash and never accesses the network.

`TryReadSourceScalar(ByRef Bytes() As Byte, ByVal ByteOffset As Long,
ByRef Scalar As Long, ByRef ScalarWidth As Long) As Boolean` borrows an immutable
zero-based array for one call. On success it returns exactly one Unicode scalar
and a byte width of 1 through 4. A negative/out-of-range offset, EOF, malformed
UTF-8 or truncated sequence returns false with both outputs zero. It consumes
no caller cursor and preserves the array and Err. No reference is retained and
no allocation, payload copy, external resource or mutable shared state is used.
Callers must synchronize mutations of shared input; output arguments must be
distinct and must not alias the input array. It calls the existing `Utf8` module's `FeedUtf8Byte`
decoder at most four times and inspects only available bytes.

The maintained acceptance procedure is
`rtk proxy powershell -NoProfile -File std-lib/tools/check-unicode.ps1`.
It accepts `-SelectionPath` for an explicitly selected accepted bootstrap build.
Its report records exact inputs/artifacts, commands and observed work. Passing
this gate qualifies only these library helpers, not scanner or language policy.
