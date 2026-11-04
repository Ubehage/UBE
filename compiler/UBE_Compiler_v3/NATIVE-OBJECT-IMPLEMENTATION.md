# Bounded native object inspection

This implements the binary-read dependency of the selected stack binding and
debug admission contracts. Production reads bytes directly; LLVM text inspectors
remain independent test oracles. No new file primitive, parser worker pool,
language feature or inspection-tool dependency is introduced.

UBECore BinaryBytes owns portable little-endian decoding. NativeInspection owns
the per-candidate byte/event budget: defaults are the reviewed 64 MiB examined
bytes and 16,777,216 events. Every scalar read, including rereads, admits its
actual width and one event before access and polls cancellation. Budget failure
preserves counters and result and reports 1502/resource 7 (debug-information).
Malformed bytes/ranges report 1506, cancellation 1507, invalid internal budget
state 1509. A host-managed entry failure after admission can retain the admitted
read-attempt charge; it cannot publish a result. No scan is inferred from input
length. Future symbol/string/relocation traversals must use the same ledger.

NativeObjects borrows one immutable zero-based byte snapshot retained by its
build owner. That owner must admit the candidate length and charge snapshot
payload under the existing native limits before obtaining it from the held
file. The readers do no I/O, allocation, payload copying or retained ownership.
Their scalar layout/section outputs publish only after successful validation;
on failure earlier outputs remain unchanged. Outputs, state and failure must be
distinct, and reserved layout fields must not be mutated by callers. Separate
states and immutable shared input permit reentrant reads.

The selected header profile accepts ordinary AMD64 COFF objects and AMD64 PE32+
console executables, bounds optional/section/symbol/string tables with checked
arithmetic, and validates target header alignment and extents. Section reads
bound actual initialized bytes, virtual extents and relocation records, including
the COFF extended relocation-count record. Uninitialized object storage has no
file payload. PE raw alignment padding does not become initialized section data.

Names are borrowed First/Count byte ranges in that same immutable snapshot.
Literal names use at most eight bytes; symbols select their string-table offset
with the zero-prefix union, while sections use the selected `/decimal` encoding.
Indirect offsets must be at least four and names must terminate within the
validated string table. All prefix, digit and terminator reads use the ledger.
No Unicode conversion or case folding changes linkage identities.

Symbol reads validate signed section references (-2, -1, 0 or an existing
section), bound auxiliary record counts, and return NextIndex and an auxiliary
byte range. Callers traverse from index zero using only NextIndex, so auxiliary
records do not become primary symbols. Their contents are preserved and skipped;
unknown auxiliary formats do not become invented definitions. The later indexed
inventory must establish primary-symbol membership for relocation targets and
interpret required auxiliary semantics before using them for binding.

The initial AMD64 relocation decoder supports ABSOLUTE padding, ADDR64, ADDR32,
ADDR32NB, REL32 through REL32_5, SECTION and SECREL. It checks the effective
record array, target index and initialized patch extent. Width is 8, 4 or 2 as
specified; REL32 variants record the end-relative bias 4..9. ABSOLUTE has no
patch or target use. Other encodings fail 1506 rather than guessing semantics.
This reads relocation descriptions; it neither applies them nor proves linked
bytes. All new scalar outputs preserve earlier values on failure, with the
same ownership, cancellation and budget contract as header reads.

These readers are prerequisites, not complete object/image admission. Required
auxiliary semantics, indexed primary-symbol membership, overlapping-region
validation, owned identity retention, unwind/instruction/fixup analysis and DWARF
validation remain required. Reader success is not a stack-safety,
debug-correctness or publishability decision.

The binary field definitions follow Microsoft's
[PE/COFF format](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format).
The selected GNU/LLD executable COFF-symbol/long-section-name convention retains
its separately qualified status from NATIVE-DEBUG-CONTRACT.md.

## Shared native byte comparison

TryCompareNativeByteSpan centralizes constant/code byte-equivalence decisions
over the existing Core scalar reader and shared NativeInspection admissions.
Borrowed ranges must be in bounds; invalid ranges use 1509. It compares chunks
of at most eight bytes, returning a separate Equal result so a different
constant candidate is distinct from an inspection failure. Equal is published
only after a complete decision; read/budget/cancel failure retains its old value.
An empty in-bounds span succeeds with Equal=True and no byte/event work. Equal
nonempty spans read exactly 2N bytes in 2*ceiling(N/8) events. A differing chunk
can stop early. No allocation/copy, retained ownership or shared state is added.
Constant binding and code comparison keep their own candidate failure policy.
