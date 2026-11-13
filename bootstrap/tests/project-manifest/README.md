# Bounded project manifest parser

This gate qualifies `compiler/src/ProjectManifest.bas`, an ordinary UBE parser
for the current bootstrap manifest profile. It performs no filesystem access,
source-module parsing, backend invocation or output publication.

## Integration API

`ProjectManifest.TryParse(Text, Sources, Info, Diagnostic) As Boolean` accepts
a zero-based counted Byte array containing an entire UTF-8 manifest. Inputs
are limited to 65,536 bytes and 128 Source entries. UTF-8 may start with a BOM;
LF and CRLF are accepted. Invalid UTF-8, NUL, DEL, other unapproved control
characters and bare CR are rejected.

`Sources() As ProjectManifest.ValueSpan` retains ordered records with
`Start`, `Length` and one-based `Line`. Start is a zero-based byte offset
into the unchanged input; Length describes the raw interior between quotes.
The caller must keep the manifest bytes intact while using these spans.

`Info As ProjectManifest.ManifestInfo` contains:

| Field | Meaning |
|---|---|
| NameStart, NameLength | Raw project-name span in input bytes |
| SourceCount | Exact published Sources length |
| IsExecutable | True for Exe; False for Library |
| Optimization | 0, 1, 2, 3; 4 means Size; default 2 |
| DebugInformation | 0 None, 1 Line, 2 Full; default Full |

Only Name, Kind, Startup, Source, Optimization and DebugInformation are
admitted. Scalar duplicates, missing required fields, unknown keys, unsupported
features and invalid values receive fresh diagnostics. Startup must be Main
for Exe and is forbidden for Library. Names follow the bounded ASCII identifier
profile. Case folding is ASCII and independent of host locale.

`TryCopyValue(Text, Start, Length, Result() As Byte) As Boolean` decodes one
quoted interior, including doubled quotes, into independent zero-based counted
bytes. It checks bounds and quote pairing and preserves Result on failure.
The parser's admitted Name/Source values contain no embedded quote; this
separate function still implements the general quoted-value decoding rule.

Both APIs return fresh status. Successful operations preserve sticky Err.
TryParse preserves all earlier Sources elements/bounds and every Info field on
failure, using private candidate storage and publishing only after success.
Diagnostic always describes the current attempt.

## Diagnostic codes

| Code | Meaning |
|---|---|
| 0 | Success; line and column are zero |
| 1 | Missing or unsupported manifest header |
| 2 | Invalid entry/quoted-value syntax |
| 3 | Duplicate scalar key |
| 4 | Invalid project identifier |
| 5 | Invalid scalar value or Library Startup |
| 6 | Recognized but unsupported key/source extension |
| 7 | Unknown key |
| 8 | Required project field missing |
| 9 | Manifest/source-count limit |
| 10 | Invalid text encoding or forbidden character |
| 11 | Invalid relative source-path spelling |
| 12 | Storage or controlled runtime failure |

Failure locations are one-based. Encoding columns count UTF-16 units; entry
syntax locations identify the beginning of the key (leading whitespace is
ASCII). Missing-field diagnostics identify the last inspected line.

The current Windows bootstrap source-path spelling rules are checked:
nonempty relative path, no root prefix, forbidden Windows filename characters,
at most 32,767 UTF-16 units, and .bas extension. **This is not path containment
verification.** The loader must normalize paths, verify final paths through
the actual open file handle, reject escapes and duplicate physical sources,
read and close each source, then append its retained syntax in source order.
The parser does not resolve dot segments, symbolic links or aliases.

## Acceptance

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/project-manifest/check.ps1 -BootstrapExe "<qualified VB6 bootstrap executable>"
```

The gate compiles actual production UBE plus a test observation module with the
qualified VB6 bootstrap. Independent LLVM harnesses supply runtime bytes and
expected values. Native executables must have AMD64 PE headers.

At both O0 and O2 it checks:

- 52 manifest vectors: header/BOM/casing/whitespace, LF/CRLF, Unicode paths,
  ordered source values, every optimization/debug setting, Library defaults,
  malformed syntax and encoding, invalid paths/values, missing and duplicate
  keys, unsupported/unknown keys, 128/129-source and input-byte limits.
- Exact retained metadata, names, first/last paths and first-source line;
  previous-output preservation on every rejected vector; sticky Err on success.
- Seven direct quoted-interior decoding and invalid-span observations.
- All three observed parser allocations, each with failed retry; exact native
  allocation counts, unchanged previous outputs, subsequent successful reuse,
  and zero live native blocks after disposal.

A changed expected-name negative control returns exact exit 1 rather than
silently passing. The gate links production without a stack-probe stub.
Splitting exact keyword comparisons into bounded helpers resolved an observed
O0 stack-helper dependency in an initially combined routine.

Latest command on 2026-11-13:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/project-manifest/check.ps1 -BootstrapExe "C:\Users\Ubehage\AppData\Local\Temp\ube system primitives 74f4f9c9-eb02-4e20-a63e-871e3d04c435\build\UBE-Bootstrap.exe"
```

Passed all assertions above. Evidence:
`C:\Users\Ubehage\AppData\Local\Temp\ube manifest 289583d9-883f-4190-87c4-ac7afd17bb85`.
No production or test logic changed after that passing run.
This does not qualify OS loading, physical
path containment, compiler self-hosting or concurrent execution.

