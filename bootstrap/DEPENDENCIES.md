# Dependencies for the UBE-written compiler

This is an incremental assessment under the development plan's **Extend
bootstrap dependencies** item. The current compiler implementation is VB6;
there is not yet a complete UBE-written compiler from which to derive a final
self-hosting subset. Existing pipeline operations provide concrete evidence
for the next extension, not proof that the complete dependency set is known.

## Integer storage

| Existing operation | Required target capability |
|---|---|
| HostFiles reads and writes UTF-8 through Byte buffers; NativeBackend inspects executable header bytes | Byte values and checked conversions, followed later by byte arrays and counted I/O |
| Arithmetic on byte values | Integer intermediates: the language explicitly promotes Byte to signed Integer before integral operations |
| Syntax and bound trees retain indices, counts and source positions as Long | Preserve existing Long behavior and reject out-of-range narrowing |
| SourceSemantics checks signed-64-bit literals and intermediate values using host Decimal arithmetic | LongLong storage, arguments and results in target UBE code; target semantics must not inherit the VB6 host's 32-bit Long limit |
| Native declarations and binary formats use fixed-width fields | Explicit range-preserving conversions among supported integer types; complete records and foreign layouts remain later dependencies |

The completed integer extension is Boolean plus Byte, Integer, Long and LongLong scalar
storage, parameters, results, constants and checked conversions. It uses the
existing expression operators, module pipeline and error protocol. Integer
identifier/literal suffixes `%`, `&` and `^` retain their declared meaning;
use-site suffixes assert the declaration's type rather than requesting an
Adaptive conversion.

Byte values range from 0 through 255; Integer is signed 16-bit, Long signed
32-bit, and LongLong signed 64-bit. Byte arithmetic promotes to Integer.
Unsigned Byte conversion of Boolean True (-1) fails rather than wrapping.
Unsuffixed literals use an available numeric destination context, widening
when needed; explicit suffixes remain authoritative before final conversion.
These are existing language rules, not new bootstrap-specific semantics.

The bootstrap's private scalar ABI can retain i64 cells while enforcing each
source type's range. This does not qualify public memory layouts, arrays,
records or foreign calls. Executable Main and trusted Err signatures retain
their existing admission rules.

## Source buffers and retained records

The bounded storage increment is described in AGGREGATES.md. HostFiles' byte
buffers motivate Byte arrays; SourceToken and SyntaxNode motivate records
containing numeric kind/offset/length and parent/child/sibling indices, stored
in arrays. This proves their storage and traversal before managed text and
dynamic growth are introduced. Existing comparisons and GoTo suffice to test
the data structures without inventing unresolved loop-header failure rules.

The bounded implementation selects finite scalar records and fixed-bound
rank-one arrays, checked field/index access, ByRef borrowing and independent
copies with known matching array bounds. Source bytes and spans replace no
language String contract; the fixture stores bytes as data. General dynamic
buffers, bounds-replacing array copies and record-owned arrays remain required
later for a practical compiler and are explicitly deferred.

## Remaining evidence to gather

The completed counted-buffer prerequisite provides access through the existing
Array.Length and Memory.CopyBytes roles, described in COUNTED-BUFFERS.md.
HostFiles' counted reads/writes and retained lexer byte spans need lengths and
overlap-safe range copies. Their status contracts are already explicit, and an
ordinary UBECore append function can compose them without allocation.

Dynamic resizing needs stable descriptors, replacement-before-publication,
cleanup on every return/FAIL, and allocation recovery. In particular, resolve
the lifetime/observable identity of an element ByRef alias when a later argument
or the callee resizes, erases or replaces the owning array. Freeing the old
payload while such an alias is live is unsafe; neither a pinning policy nor a
new resize rejection is selected by this increment. The existing call-lifetime
alias guarantee must be preserved. These requirements precede admitting growth.

Porting practical source buffers and retained trees still needs dynamic growth
and broader aggregate ownership beyond the admitted fixed arrays/finite records;
ordinary scanning needs loop forms and further operators; reading source and
writing output need explicit library I/O. Text representation, ownership,
allocation failures and corresponding UBECore interfaces must be admitted and
tested before porting those algorithms. Integer support alone does not make
the bootstrap self-hosting.

The final compiler's multithreading requirement applies to all of that work.
State remains owned by compilation requests and work items, with immutable
sharing or explicit synchronization. The sequential VB6 host remains an
implementation prerequisite, not evidence of final-compiler concurrency.

Acceptance belongs in `tests/integer-types/check.ps1`,
`tests/aggregate-storage/check.ps1` and `tests/counted-buffers/check.ps1`;
exact executed results and next work belong in
`../compiler/Progress.md`.
