# UBE project loading

This gate qualifies the ordinary UBE ProjectLoader, ProjectManifest, WindowsPaths
and FileBytes integration. It loads ordered source bytes and retained syntax.
It does not bind procedure bodies, emit code, invoke LLVM, publish executables
or establish self-hosting.

## Public API

```vb
ProjectLoader.TryLoad(ManifestPath, PackageName, PathBytes, Paths, _
    Bytes, Tokens, Nodes, Modules, Counts, Info, Diagnostic, Token)
```

All arguments are ByRef:

- ManifestPath is an unchanged zero-based counted UTF-8 Byte array.
- PackageName and PathBytes are caller-owned Byte arrays.
- Paths is an array of ProjectLoader.SourcePath records: Start, Length and
  ManifestLine. Each record names a complete canonical path in PathBytes;
  its index matches the corresponding ProjectSyntax.ParsedModule index.
- Bytes, Tokens, Nodes, Modules and Counts have the existing ProjectSyntax
  storage types. Source byte, token and node order matches the manifest.
- Info is ProjectManifest.ManifestInfo.
- Diagnostic is ProjectLoader.LoadDiagnostic.
- Token is the explicit Long file owner. Incoming Token must be zero.

The result is fresh Boolean status, independent of sticky Err. Inputs, outputs
and scratch arrays must be distinct caller-owned request storage; callers must
not concurrently mutate or alias them.

A nonzero incoming Token is rejected before changing any old Counts, Info or
arrays. The token remains owned by the caller. For an admitted new request,
Counts is reset to all zero and Info.SourceCount to zero before scratch
mutation. Arrays and other Info fields are not an independently usable result
while those counts are invalid. Work uses private logical counts, committing
Counts and complete Info only after every source has been read, closed and
parsed. Any failure leaves the public counts invalid. This is deliberate
request invalidation, not a claim of atomic publication of many arrays.

If a close fails, Token remains nonzero for caller cleanup; the loader does not
silently retry that close. A failure preceding cleanup retains its diagnostic
and Err even if the cleanup close also fails. After failure callers must retry
any retained close before beginning another request.

## Loading sequence

The supplied path must have .UBE extension. The loader opens the manifest,
obtains its canonical path through that same owned handle, normalizes the
reviewed extended Windows prefix, derives the physical containing directory,
reads the bytes and closes the owner. ProjectManifest then validates metadata
and ordered relative source spans.

For each Source, WindowsPaths normalizes the joined full path and verifies
lexical containment. The loader opens that path and obtains the final physical
path through the same token that will supply its bytes. It checks physical
containment and earlier canonical paths with Windows ordinal case-insensitive
comparison. Only then does it read the source. The source owner closes before
ProjectSyntax.TryAppendModule scans/parses the original bytes.

Canonical diagnostic paths are retained before source reading/parsing.
Only one file owner is live at a time, regardless of module count. No process
working-directory state is changed. Junction escapes are refused before any
external source bytes are read. Different path spellings that resolve to an
earlier canonical path are duplicates; separate hardlink names are not compared
by file ID, matching the existing bootstrap path-based contract.

The current qualified bounds remain 65,536 manifest bytes, 128 modules,
4,096 UTF-8 path bytes, one MiB retained project source bytes, 262,144 tokens,
131,072 project nodes (65,536 per module) and the existing native allocation quota. The canonical path arena
is bounded to 524,288 bytes (128 times the path capacity). Full-language project
references, resources and other unsupported manifest features remain rejected.

## Diagnostic mapping

LoadDiagnostic contains Stage, Code, Reason, ModuleIndex, Line, Column,
PathStart, PathLength, SourceStage, ByteOffset and Utf16Offset.

| Stage | Meaning of Code |
|---|---|
| 0 | Success; ModuleIndex is -1 |
| 1 | Invalid incoming owner or manifest path (Code 1) |
| 2 | Manifest open/canonical path/parent failure |
| 3 | Manifest byte read or close failure |
| 4 | ProjectManifest diagnostic code |
| 5 | Source lexical path resolution/containment |
| 6 | Source open/physical path/containment or duplicate canonical path |
| 7 | Source byte read or close failure |
| 8 | ProjectSyntax diagnostic; SourceStage distinguishes scan/parse/retention |
| 9 | Request storage failure (Code 8) |

OS/library stages preserve the called operation's failure code. Code 11 with
Reason 1 identifies an explicit containment refusal; Code 3 with Reason 2
identifies a duplicate canonical path. A controlled unexpected language failure
uses Code 12 within its current stage.

ModuleIndex is zero-based for source operations and -1 for manifest operations.
Before a source's canonical path is retained, Line identifies its Source entry
in the original manifest; PathLength is zero. After retention, PathStart and
PathLength identify the canonical path in PathBytes, even if the request later
fails. At stage 8, Line/Column/ByteOffset/Utf16Offset come directly from the
scanner/parser. At stage 7, Line still identifies the manifest Source entry.
Diagnostic storage remains inspectable even while request counts are invalid.

## Acceptance and evidence

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/project-loading-ube/check.ps1 -BootstrapExe "C:\Users\Ubehage\AppData\Local\Temp\ube path primitives 0d868d63-27a3-45a4-9e74-2f8aa888b7cd\build\UBE-Bootstrap.exe"
```

Passed on 2026-11-13 at O0/O2:

- Fifteen runtime cases: ordered original bytes/canonical paths, actual compiler
  and library modules, missing source, malformed manifest/source, duplicate
  module identity, duplicate canonical path, lexical escape, junction escape,
  junction alias duplicate, incoming owner refusal, failed close with retained
  ownership, manifest/source read failure, and primary read failure combined
  with failed close.
- Exact read-byte counts prove rejected physical escapes are never read.
- Exact source diagnostics include the failing module and canonical path.
- Primary read Err survives cleanup failure; the caller can close the retained
  token afterward. Every case finishes with zero handles and native blocks.
- All 155 observed successful allocation sites are failed, including the
  allocator's retry, at both optimization levels. Every failure leaves counts
  invalid, releases resources, and permits exact same-context recovery.
- A changed expected-source-byte control returns exact exit 1.

Evidence:
`C:\Users\Ubehage\AppData\Local\Temp\ube project source 2383c9d4-ae19-4cbc-8dee-deedcff1987c`.
This final rerun used `check.ps1 -BootstrapExe` with
`C:\Users\Ubehage\AppData\Local\Temp\ube llvm writing e261ff6b-d0f4-42c6-a1cd-dc387eeb1d17\build\UBE-Bootstrap.exe`,
including shared close-error preservation, canonical-path helpers and the enlarged
project node capacity. All listed assertions passed again at O0/O2.

The first monolithic loader exceeded the existing temporary-frame limit.
Separating manifest and source loading into domain-specific helpers allowed
the same source dependency without increasing resource bounds. The gate links
without a stack-probe stub and qualifies actual native execution.

