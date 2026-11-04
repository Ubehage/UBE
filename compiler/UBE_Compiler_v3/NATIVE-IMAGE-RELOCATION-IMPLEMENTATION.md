# Native image base relocations

This is the next bounded dependency of First checked native executable, following
TLS storage association. It adds no language semantics or compiler architecture.
The binary meanings follow the [Microsoft PE format](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format#the-reloc-section-image-only).

## Consumer and authority

TryValidateNativeImageRelocations borrows one qualified immutable PE32+ image,
its layout, and an immutable LongLong array of alternating field RVA / target
RVA pairs. The caller supplies the complete expected pointer set in increasing
field order, derived from producer-bound definitions and explicit CRT anchors,
never from the relocation entries or pointer values being checked. The function
returns the complete relocation directory range only after every entry and every
expected pair matches. An incomplete enumeration is not a successful proof.

The array uses existing scalar array storage; no new owner, cache or index is
introduced. Preparation of expectations belongs to their existing caller and
its storage/work budget. The validator allocates and copies no payload. Inputs
remain immutable and live throughout the call, outputs publish atomically, and
separate invocations are reentrant. Successful calls preserve Err.

The selected profile requires a nonempty, four-byte-aligned directory, complete
initialized uniquely mapped read-only data, and IMAGE_FILE_RELOCS_STRIPPED clear.
Blocks have aligned strictly increasing page RVAs, sizes at least eight bytes
and divisible by four, and remain wholly inside the directory. ABSOLUTE entries
are skipped, including nonzero ignored offsets. Every other entry must be DIR64.
Eight-byte writes must be in increasing non-overlapping order, fully initialized
resident data, and isolated from headers, file aliases and relocation metadata.
Writable and read-only pointer cells are accepted. Code and discardable pointer
storage are rejected. No section-name guess establishes permissions.

Every write must equal the next expected field RVA, and its eight-byte value
must equal preferred ImageBase plus the independently expected target RVA.
The number of matched fields must equal the number of expected pairs. Thus
duplicates, overlaps, missing entries, unexpected writes and altered targets
reject. Target RVA zero is explicitly supported for __ImageBase; an endpoint
up to ImageBytes is representable for established end markers. These numeric
cases do not prove target ownership, callable entry identity or safe dereference;
the caller's binding proofs remain required. In particular the unnamed CRT
constructor target is a frozen artifact observation pending function proof.

All candidate byte reads and traversal/expectation visits use NativeInspection
byte/event/cancellation accounting. Directory/header/span/isolation code is
reused. The shared image-header helper preserves the existing directory reader's
checks and exact costs. Work is O(B + E + W*S), with blocks B, entries E, writes W
and admitted sections S <= 96; there is no repeated full relocation scan.
Scalar storage is constant. Production resource caps remain unchanged.
Caller-shape failures use 1509; malformed/unsupported candidates and mismatched
associations use 1506; resource and cancellation failures retain 1502/token 7
and 1507. Prior results survive all failures.

## Independent cases fixed before implementation

A literal four-section 4096-byte image has read-only data at RVA 4096,
writable data at RVA 8192, TLS at RVA 12288 and code at RVA 16384. Its relocation
directory occupies 28 bytes at RVA 4352 (file offset 768), with blocks for pages
4096 and 8192. Required pairs are (4096,12288), (4104,13088), (8256,16384).
The blocks encode two DIR64 entries and then one DIR64 plus ABSOLUTE padding.
ImageBase is 0x140000000. The exact successful result is independently fixed
as section 0, file 768, length/initialized 28, section offset 256, RVA 4352,
address 0x140001100, characteristics 0x40000040, symbol -1, type zero.

Positive cases include an explicit RVA-zero target, writable field storage,
ABSOLUTE padding with a nonzero ignored offset, and empty ordered blocks.
Negative cases cover stripped relocations, absent/truncated/misaligned directory,
block underflow/overflow/odd size, page misalignment/reordering, unsupported
types, duplicate/overlapping/cross-boundary writes, metadata writes, code or
discardable storage, missing/extra expected fields and altered pointer values.
Check caller shapes, exact/insufficient budgets, every cancellation point,
physical byte/event accounting, immutable inputs, allocation independence,
root refusal and atomic result retention. Corrupted-result and forced-Boolean
controls must fail the oracle through both source-built reader stages.

The retained matrix must match all 49 fields in each of the 16 existing images,
including generated/reference/initializer/TLS fields and all explicit CRT cases.
Freeze expected pairs independently of the candidate under mutation. Remove or
redirect each field's relocation and alter each value; all must reject. Retain
affected directory, TLS, instruction, leaf, unwind, extent and target gates.
Record commands, source/tool/artifact hashes, measured costs and failed attempts.

This proof does not complete global alias ownership, TLS register provenance,
CRT execution effects, whole-function control/dataflow, stack/debug closure,
builder/publication or final native acceptance. Those remain in the parent plan.
