# Counted-byte paths for project intake

Status: adopted by the owner on 2026-10-31; implementation and qualification are
in progress. The owner approved the recommended lexical-containment/open-file-
identity route and the two host bindings. UBECore owns path operations and host observations;
the compiler owns package containment, duplicate/cycle policy and diagnostics.
There is no change to UBE syntax, value copying, roots or thread semantics.

## Declarations and responsibility

```vb
Function TryCurrentDirectoryBytes(ByRef Published() As Byte, ByRef Failure As Long) As Boolean
Function TryNormalizeRelativePathBytes(ByRef Path() As Byte, ByRef Published() As Byte, ByRef LeadingParents As Long, ByRef Failure As Long) As Boolean
Function TryResolvePathBytes(ByRef BaseDirectory() As Byte, ByRef Path() As Byte, ByRef Published() As Byte, ByRef Failure As Long) As Boolean
Function TryReadByteFileIdentity(ByVal Token As Long, ByRef Published() As Byte, ByRef Failure As Long) As Boolean
```

All text is counted strict UTF-8, without NUL, Unicode normalization, environment
expansion or UBE identifier folding. Results are independent Byte arrays. Failure
preserves older arrays; scalar outputs are fresh and distinct from other outputs.
Success preserves incoming thread-local Err. Mutable storage has one caller;
immutable inputs can be shared. No current-directory cache or compiler state is
retained by the library.

Callers seed Failure=8 (and LeadingParents=0 where present) before managed entry,
so an actual root-admission failure before the UBE body cannot expose stale
status. Entered success sets Failure=0; entered failure sets the exact fresh code
and records Err through the established mechanism. No outcome is inferred from
an earlier Err value.

`TryCurrentDirectoryBytes` returns an absolute snapshot and never changes the
process directory. Its new intrinsic binding is `Process.TryCurrentDirectory`
with the same signature: wide host observation and UTF-8 transport only. Capture
it once before resolving a request; later operations use these captured bytes.
Concurrent host directory changes do not change an already captured base.

`TryNormalizeRelativePathBytes` is ordinary UBE. It requires a nonempty relative
path, accepts both Windows separators on the maintained host, uses `/` in output,
elides empty/`.` components and cancels component/`..` pairs. Remaining leading
`..` components are retained and counted by LeadingParents. The result `.` is
valid for an input reducing to the current directory. Absolute and drive-relative
inputs fail; device namespaces are unsupported. Success reports LeadingParents
zero or greater; failure resets it to zero. This is a lexical operation: it does
not open a file or consult the working directory.

`TryResolvePathBytes` is ordinary UBE over checked component storage. BaseDirectory
must be absolute. A relative Path combines with that base; an absolute Path is
normalized independently. Initial supported absolute roots are `X:/` (ASCII drive
letter) and `//server/share/`; neither root can be popped by `..`. Drive-relative
paths and device namespaces are unsupported, never looked up through per-drive
state. Preserve component spelling, use `/`, omit a trailing separator except for
a root, and publish only the complete normalized path. An empty Path is invalid.
No filesystem existence or physical containment is implied by lexical resolution.

`TryReadByteFileIdentity` adds the intrinsic binding `File.TryIdentity` with the
same signature. It borrows an existing live byte-file token under the same Busy
admission rule as read/close. It opens no extra handle. The adapter queries the
already-open file, returns an independent 16-byte opaque identity, and releases
Busy on every path. Layout for this bounded Windows adapter is little-endian:
32-bit format version 1, 32-bit volume serial, 64-bit file index. Callers compare
all bytes for equality within one request; they do not decode/persist IDs, infer
paths from them or treat them as addresses. A host lacking the qualified identity
facility returns unsupported. Host IDs can be reused after files are deleted;
this is not an atomic filesystem snapshot.

The file token remains owned by its original caller on both success and failure;
existing `TryCloseByteFile` handles close/retry. No hidden close failure, directory
handle, raw-address API, new registry or new token type is introduced. The compiler
will obtain identity while its existing file intake owns the open token, before
close and failure-atomic document publication. Its shared intake body must remain
single, preserving the earlier reader entry and all oracles.

## Bounded project policy

The compiler first normalizes each Source as a relative path and requires zero
LeadingParents. References may have leading parents and resolve against the
owning manifest. Sources such as `a/../Main.bas` are supported. A spelling such as
`../app/Main.bas`, which leaves then re-enters the project, is reported as an
unsupported path form for this bounded consumer rather than accepted through a
host-specific case comparison. Absolute/drive-relative Source/Reference remains
invalid under the normative project rules.

Use identities observed on opened manifest/source tokens for duplicate physical
files, self-reference and cycles. This covers case-sensitive Windows directories,
case variants, hard links and aliases without using language simple folding as a
filesystem comparator. Stable compiler source IDs still come from declaration
order, never from a host file ID or worker completion.

The adopted initial containment is the lexical rule above. Following an alias
can reach a file outside that lexical tree; physical containment is not claimed.
If the owner instead requires physical containment across junctions/symlinks,
stop before native implementation and specify a retained traversal/open-owner
operation. Checking attributes and later opening by name would not prove it.
The owner selected the lexical route; physical traversal is outside this consumer.

## Bounds, failure, ownership and costs

Path text is limited to 131068 UTF-8 bytes and the file contract's 32767 UTF-16
code units excluding the final native terminator, matching the maintained
file adapter's wide_count check. Component counts and
all byte sums are checked before allocation. UBE normalization/resolution use
O(N) scanning and copies, with geometric private storage; no repeated concatenation
of complete prefixes. For normalization/resolution, let S be the combined input
byte lengths plus 8. Preset per-call acceptance is at most 16*S+128 observed
payload-copy bytes, 40+12*ceil(log2(S+1)) allocation calls, and 16*S+4096 peak
additional payload bytes, with O(S) component visits. These deliberately bound
temporary components, growth and failure-atomic publication. Identity returns
exactly 16 result bytes; host query must allocate no new native reader or scratch
buffer. Current-directory capture owns at most one bounded native wide buffer
and a pending byte result, released on every path. Measure substrate workspace
and root costs separately rather than manufacturing counters from S.

Use existing shared file failure domains: 0 success, 1 invalid request, 2 malformed
path, 3 host observation/query failure, 4 path too long, 8 allocation/root failure,
9 invalid/stale token, 13 Busy; add 14 unsupported host path/identity facility.
Err remains 5 domain/unsupported, 6 bound/overflow, 7 storage, 57 host I/O. No
allocation failure can publish a partial result or strand Busy. OS observation
and query execute outside the collector lock; independent tokens share no I/O lock.

## Required independent acceptance

Test exact declared signatures/bindings, ASCII/non-ASCII, NUL/UTF-8 errors, exact
limits/one-over, both separators, drive/UNC roots, `.`/`..`, zero/many leading
parents, device/drive-relative rejection, immutable older results, actual copy/
allocation costs and independent concurrent calls. Identity tests need equal
token/reopen/case/alias/hard-link identities, distinct physical files, case-sensitive
directories, missing/unsupported host facilities, invalid/stale/Busy tokens,
genuine allocation/root/query failures, token preservation, fresh status and zero
owned residual resources. Run through both accepted source-built stages. Retain
all existing file/reader/cancellation/close-failure gates. This proposal verifies
none of these APIs by itself.

## Normalization implementation ledger

Inputs are payload-relative counted bytes. A private zero-based snapshot lets
normalization accept any existing array lower bound without changing its input.
Validate strict UTF-8, NUL and UTF-16/byte limits before component processing.
Use one bounded Long component-start stack and a private Byte output workspace;
pop by reducing its logical used count. Publish a correctly sized independent
array only after complete validation. No repeated complete-prefix concatenation
or filesystem lookup belongs in this algorithm.

Drive roots and UNC server/share roots are protected: parent traversal at the
absolute root stays at that root. Relative normalization retains/counts leading
parents. A strict-relative operation rejects a leading separator or drive prefix
as invalid input. General resolution reports drive-relative and device/root-
relative host forms as unsupported. UNC roots require nonempty server/share
components and retain a canonical final slash.

Win32 control/wildcard characters are malformed. Alternate-stream colon syntax
and components ending in a dot or space (apart from exact `.`/`..`) are explicitly
unsupported spellings for this bounded normalizer. This prevents Win32 trimming
from turning an apparently ordinary component into an unrecognized parent alias.
It does not prohibit those host facilities from later language support. Unicode
component bytes, including a filename BOM scalar, remain unchanged.

