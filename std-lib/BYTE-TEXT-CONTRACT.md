# Byte/text foundation contract

The owner requested autonomous work through the first tested foundation on
2026-10-30, within the approved [roadmap](ROADMAP.md). Normative value, error,
managed-memory and threading semantics remain authoritative. This document
chooses the narrow library behavior below; managed storage implementation is
subject to its separate mechanism proof.

## Consumer and separation

The first compiler consumer is source ingestion: read owned input bytes,
validate/decode UTF-8, and retain source byte positions separately from Unicode
scalar positions. Lexical policy, source envelopes, diagnostics and line maps
remain compiler responsibilities. UBECore supplies reusable encoding/storage
operations. No new compiler phase architecture is selected here.

Raw bytes preserve every value, including 0. Text is a sequence of Unicode
scalar values; UTF-8 byte counts and scalar counts are distinct. Encoding does
not normalize, case-fold, reject unassigned/noncharacter scalars, strip a BOM
or interpret line endings. Source-specific BOM/line-ending policy belongs to
the compiler. A decoded U+0000 is ordinary data.

Strict UTF-8 accepts shortest encodings of U+0000..U+10FFFF excluding surrogate
code points U+D800..U+DFFF. Malformed/truncated input is rejected explicitly;
there is no implicit replacement character. This follows
[RFC 3629, sections 3 and 4](https://www.rfc-editor.org/rfc/rfc3629).

## Allocation-free decoder

`Utf8Decoder` is an ordinary value record holding an incomplete scalar and
failure state. It owns no managed reference or external resource. Zero
initialization is ready for input. Assignment and ByVal produce independent
decoder states; ByRef intentionally updates the caller. Its fields are reserved
implementation state: callers reset or copy the record rather than editing
fields. The representation is not a serialized or foreign ABI.

- `ResetUtf8Decoder(ByRef Decoder As Utf8Decoder)` restores the neutral state.
- `FeedUtf8Byte(ByRef Decoder As Utf8Decoder, ByVal Value As Byte,
  ByRef Scalar As Long, ByRef Complete As Boolean) As Boolean` returns True
  when the byte is accepted. Complete indicates whether a scalar was produced.
  Scalar is that scalar when Complete is True, otherwise zero. False means
  invalid input/state; both outputs are neutral and failure remains sticky
  until reset. Callers use fresh return/Complete status, including for U+0000.
- `FinishUtf8Decoder(ByRef Decoder As Utf8Decoder) As Boolean` returns True for
  an empty or complete valid stream. A truncated/failed stream returns False
  and becomes/remains failed. Repeating a successful Finish is harmless;
  additional input starts another scalar. Callers decide stream boundaries.

Output arguments must be distinct from each other and the decoder's fields.
This is the ordinary explicit ownership contract for mutable ByRef outputs.
No call retains an argument, allocates, copies input buffers or touches Err.
False is an expected encoding predicate result, like the earlier TrySet proof;
it is not an implicit language error. A higher-level decode operation that
reports an operational failure must separately follow neutral-result/Err rules.
Successful validation must not infer failure from stale Err.

The decoder is incremental: a chunk can end between any bytes. An invalid
prefix may be reported on a later byte or at Finish; no output scalar is
published until the complete encoding passes validation. It does not promise
replacement/recovery or first-invalid-byte diagnostics. Independent records
are reentrant; sharing one mutable record requires caller synchronization.
Immutable input can be read by independent workers. There is no global scratch
state, worker creation, lock or cancellation owner inside the decoder.

## Owned storage and text construction obligations

The next storage facility must have explicit byte length/capacity, neutral empty
state, checked bounds/size arithmetic and independent semantic value copies.
Logical used length is distinct from capacity. Growth prepares replacement
storage before publishing it; failed growth preserves the prior value and
reports a fresh status, with operational errors recorded in the calling Err.
Initial allocation is neutral on failure. Mutable storage has one owner.
Sharing immutable backing is allowed only when mutation cannot affect a copy.

Immutable text construction validates the complete input before publication.
Its public value cannot expose partial decoding or a mutable shared backing.
Builders keep private mutable capacity; published text cannot change when the
builder is reused. No arbitrary native address or pin escapes a call. Precise
managed roots/barriers, temporary ownership and cleanup follow
[managed-memory.md](../lang-doc/managed-memory.md); external-resource cleanup
does not become a collector task. Do not use a NUL-terminated bootstrap String
as raw byte storage.

Before selecting a managed ABI, prove live nested data survives collection,
dead temporaries are reclaimed, copy mutation is independent, early returns
and failed initialization release initialized state, and failed growth leaves
contents/bounds/ownership intact. Inject allocation failure deterministically.
Do not promote the old bootstrap allocator/collector merely because it links.

## Acceptance and cost budgets

Decoder acceptance requires every Unicode scalar to round-trip from an
independently encoded byte sequence; all one/two-byte strings and specified
malformed/boundary/multi-scalar cases; chunk/copy/reset/finish tests; neutral
outputs and sticky failure; stale Err preservation; malformed state without
overflow; both accepted v2 stages agreeing on raw LLVM and native results.

Measure calls actually executed and allocator calls during decoding. Budget:
zero decoder allocations and buffer copies; state size independent of input;
one Feed per byte plus Finish, with bounded arithmetic/branches per call.
Exercise independent states concurrently against immutable input and bounded
test workers. Timing is diagnostic; no machine-specific throughput guarantee.
Storage growth budgets will be fixed before implementing its chosen allocator.

## Bootstrap boundary

V2 tests compile exact ordinary UBE module bodies through its documented bare
source exception. The fresh `Kind = "Library"` manifest and full native source
envelope are not qualified by that test. Test-only C/LLVM adapters may expose
functions, query layout and instrument execution; they may not substitute UBE
algorithm bodies. No archived library algorithm is imported.
