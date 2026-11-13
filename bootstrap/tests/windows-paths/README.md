# Windows path helpers

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/windows-paths/check.ps1 -BootstrapExe <path-enabled-bootstrap-executable>
```

The gate compiles the actual `WindowsPaths` UBE source with portable buffer,
UTF-8, file-error and path-primitive declarations. It checks exact native output
at O0 and O2. `GetFullPathNameW` supplies normalization expectations and
`CompareStringOrdinal` supplies Unicode case-insensitive equality expectations;
tests do not substitute locale-sensitive or ASCII-only comparison. Generated
executables must have AMD64 PE headers and complete within 60 seconds. Source
snapshots, LLVM, executables and diagnostics remain in the printed directory.

## Public API

All helpers return Boolean status. Arrays are zero-based counted Byte storage.
They accept strict UTF-8, reject embedded NUL and enforce the current 4,096-byte
file-path boundary. Result arrays contain only their exact logical byte count.
Path operands must be distinct from the scalar Failure/Boolean outputs under
ordinary UBE ByRef typing. An input array and Result may be the same array.

| Function | Contract |
| --- | --- |
| `TryNormalizePhysical(InputPath, Result, Failure)` | Converts reviewed `\\?\C:\...` and `\\?\UNC\server\share\...` spellings to ordinary absolute drive/UNC paths, changes slash separators to backslashes, and removes trailing separators except a drive root. Rejects device namespaces, incomplete roots, invalid path characters and exact `.`/`..` components. |
| `TryParent(Path, Result, Failure)` | Normalizes spelling and extracts its parent. A drive or UNC root returns itself. |
| `TryResolveSource(Root, Relative, Result, Failure)` | Validates the host-admitted relative-path characters, joins against the normalized root, calls OS full-path normalization, and requires strict descendant containment. Relative `.`/`..` components remain legal when the resulting path stays inside the root. Source-extension validation belongs to the project loader. |
| `TryIsWithin(Root, Path, Within, Failure)` | Requires a complete directory prefix and a descendant beyond it; the root itself and similarly named siblings return Within=False. Compares whole prefixes through the Windows ordinal primitive. |
| `TrySamePath(First, Second, Same, Failure)` | Compares complete normalized spellings through Windows ordinal case-insensitive comparison. This is spelling equality, not file identity or hard-link detection. |

Successful calls set Failure=0 and preserve sticky Err. Invalid policy/input sets
Failure=1 and Err=5. Allocation failure sets Failure=3 and retains Err=7. OS
primitive failures retain their explicit failure/Err pair. Every failed operation
preserves the previous Result, Within or Same. Scratch and output ownership are
local to the invocation and caller; there is no mutable global compiler state.

`TryNormalizePhysical` normalizes **spelling only**. Its name describes its use
with final paths returned by an opened file handle. Neither full-path normalization
nor these comparisons prove physical containment. The loader must obtain the
final path from the same open source handle and check that against its established
physical root before accepting the source. These helpers do not launch processes
or publish compiler output.

## Assertions

The gate covers exact extended-drive/UNC conversion, drive and UNC parents/roots,
safe relative dot segments, forward separators, OS-normalized paths, sibling
prefix refusal, equal-root refusal, Unicode paths and Unicode case-equivalent
spellings whose UTF-8 byte lengths differ. Directory prefix extraction follows
separator boundaries, avoiding byte-count slicing of a case-folded name.

Invalid vectors cover absolute or rooted source references, parent escape,
device paths, incomplete UNC roots, forbidden characters, malformed UTF-8, NUL
and excessive byte length. Exact byte and Boolean assertions verify atomic
publication, sticky errors and destination aliases on both success and failure.

For each of the five helpers, the native test measures allocations for its valid
baseline, then fails every observed allocation and its retry. Every refusal must
preserve caller outputs and report Err=7/Failure=3. The same input must recover
after every fault, and context disposal must leave zero observed live blocks.
Changing the first input path while retaining its expected bytes must produce
exact assertion exit 100. This qualifies the stated helper behaviors, not physical
file identity, process invocation or compiler self-hosting.
