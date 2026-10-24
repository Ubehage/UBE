# UBE project, project-group, and resource files

**Status:** normative project format for UBE 1.0

UBE uses distinct extensions for source, build manifests, and binary resources.
Extensions are compared case-insensitively; documentation and newly created
files use the canonical spelling shown here.

| Extension | Purpose | Encoding |
|---|---|---|
| `.bas` | Standard/code module | Text |
| `.frm` | Form module and textual designer metadata | Text |
| `.cls` | Class module | Text |
| `.ctl` | User-control module and textual designer metadata | Text |
| `.UBE` | One project manifest | UTF-8 text |
| `.UBG` | One project-group manifest | UTF-8 text |
| `.UBR` | Binary resource sidecar | Binary |
| `.UBL` | Portable compiled-library bundle | Binary |

The `.UBE` extension is reserved for project manifests; it is not a source-file
extension. A compiler invocation may accept an individual source file for
diagnostics and bootstrap work, but a normal build consumes a `.UBE` manifest.

## Native source headers

New native UBE source files use a mandatory versioned header followed by their
source-level name:

```text
UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"
```

The kind must match the extension: `MODULE` for `.bas`, `CLASS` for `.cls`,
`FORM` for `.frm`, and `CONTROL` for `.ctl`. The source-format integer is
independent of the language version. A missing name/header, duplicate identity,
unsupported source-format version, invalid name, or extension-kind mismatch is
a controlled diagnostic.

Classic `VERSION ...` and `Attribute VB_Name` headers identify legacy VB6
compatibility input. Newly created UBE files never emit them. Import/save-as-
UBE tooling writes the native header and `UBE_Name`; unknown reserved `UBE_`
attributes are diagnosed.

## Project manifests (`.UBE`)

A project manifest contains the project's build parameters and complete input
file list. The initial format is a small, line-oriented format so it remains
readable and easy to generate without a special library:

```text
UBE-Project 1
Name = "Paint"
Kind = "Exe"
Startup = "Main"
Source = "src/Main.bas"
Source = "src/PaintWindow.frm"
Resource = "src/PaintWindow.UBR"
Reference = "vendor/PaintCore/PaintCore.UBE"
LibraryReference = "vendor/PaintCore/PaintCore.UBL|1.4.0|0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF"
StartupForm = "PaintWindow"
Optimization = "2"
DebugInformation = "Full"
```

The header and format version are mandatory. Values are quoted UTF-8 strings;
a quote within a value is written twice. Blank lines and lines whose first
non-whitespace character is `'` are ignored. Keys are case-insensitive and may
repeat when they represent lists. Paths are relative to the manifest's
directory, use `/` in newly written manifests, and must not escape the project
tree after normalization. Input order is significant and must be preserved.

`Name`, `Kind`, and at least one `Source` are required. One manifest and its
ordered sources form one compilation package. `Name` is that package's
case-folded source qualifier and must be representable as a UBE identifier;
its original spelling is retained.

`Kind = "Exe"` builds an executable and `Kind = "Library"` builds the target's
native shared-library format. Executables require `Startup = "Main"`; the key
names only the required source-level entry procedure and never a form.
Libraries have no entry point and expose foreign procedures only when marked
`Public Export`.

An executable may specify one `StartupForm`, naming a form module in the same
package. It does not replace `Main`. Generated startup initializes referenced
packages, initializes this package's modules in source order, constructs and
loads the startup form's default identity, and then invokes source `Main`.
`StartupForm` is invalid in a Library project.

`Reference` is an ordered, repeatable path to another `Kind = "Library"`
`.UBE` source manifest. The path follows the same normalization, containment,
duplicate, and missing-file rules as other project paths; no registry,
environment, network, or undeclared search path is consulted. References must
be acyclic, cannot name the current project, and cannot resolve to two packages
with the same folded `Name`.

Only directly referenced packages contribute Public declarations to source
lookup. Their dependencies remain link dependencies but are not injected into
the consumer's unqualified namespace. `Friend` never crosses a package
boundary. `Package.Module.Member` provides explicit qualification. Reference
order makes builds and diagnostics deterministic but never resolves an
ambiguous source name.

Other
target, compatibility, optimization, debugging, and output parameters are
defined as those features are implemented. Unknown keys are diagnosed by the
compiler; editors should preserve keys they do not understand. Duplicate
scalar keys, duplicate normalized paths, missing files, unsupported source
extensions, and path escapes are errors, never reasons for a compiler crash.

Dependencies initialize before dependents. Independent dependency nodes use
manifest discovery order as a deterministic secondary order. Orderly shutdown
reverses successful package initialization, and partial failure unwinds only
successfully initialized packages and modules in reverse order. Listing two
projects in a `.UBG` does not create a reference between them.

`Optimization` accepts `0`, `1`, `2`, `3`, or `Size`; omitted means `2`.
`DebugInformation` accepts `None`, `Line`, or `Full`; omitted means `Full`.
These settings affect generated code and debugger information but never UBE
observable semantics.

`LibraryReference` has the exact form `path.UBL|version|interface-sha256` and
names a compiled-library bundle plus the version and canonical uppercase
64-digit SHA-256 interface
identity required by the consumer. The compiler rejects a bundle unless all
three values and the selected target match its frozen manifest. During RP8, source
declarations still come from an explicit `Reference` to the matching `.UBE`
project; the bundle supplies the verified target artifact and frozen
compatibility record. This paired form keeps source lookup and linking
deterministic: RP8 compiles and links the declared source reference while
verifying that the paired target artifact is compatible. Direct extraction of
the cached artifact is not part of the RP8 linker handoff. The compiler never
infers metadata from a platform library filename.

## Project-group manifests (`.UBG`)

A project group contains group parameters and an ordered list of project
manifests. It uses the same lexical rules:

```text
UBE-ProjectGroup 1
Name = "Paint Suite"
Project = "Paint.UBE"
Project = "tools/AssetPacker.UBE"
```

`Name` and at least one `Project` are required. Each project path must name a
`.UBE` file. A group is an orchestration input, not a link unit: every listed
project retains its own settings and output. Cycles, repeated projects, missing
manifests, path escapes, and incompatible dependencies must produce controlled
diagnostics.

## Binary resource sidecars (`.UBR`)

Binary payloads never appear inline in `.bas`, `.frm`, `.cls`, `.ctl`, `.UBE`,
or `.UBG` text. They live in `.UBR` sidecars, normally beside and sharing the
stem of the source that owns them (for example, `PaintWindow.frm` and
`PaintWindow.UBR`). A project lists every sidecar explicitly with `Resource`.
Textual designer metadata refers to a named entry in that sidecar, rather than
embedding bytes or relying on an unvalidated offset.

`UBE-Resource 1` has the following frozen little-endian layout. The 16-byte
header is the eight bytes `UBEUBR1\n`, a `UInt32` entry count, and a `UInt32`
directory length. Each directory record is a `UInt16` ASCII name length, a
zero `UInt16` flags field, `UInt64` payload offset and length, 64 uppercase
ASCII hexadecimal SHA-256 characters, and the name bytes. Names use only
`A-Z`, `a-z`, `0-9`, `_`, `-`, and `.`, are 1–255 bytes, and records are in
strict ordinal name order. Payloads immediately follow the directory in record
order without gaps or trailing data. Containers are limited to 64 MiB and
1024 entries. Readers validate every length, offset, name, order, and hash
before exposing data. Truncation,
corruption, unsupported versions, excessive sizes, or a missing reference must
produce a useful diagnostic and must never panic or read outside the file.

During compilation, referenced entries are treated as build inputs and emitted
into the program's target-appropriate read-only resource representation. The
compiler records them for dependency tracking and deterministic builds; an
unreferenced sidecar is not implicitly scanned or embedded.

## Compiled-library bundles (`.UBL`)

`UBE-LibraryBundle 1` uses the same directory and payload framing as `.UBR`,
with the distinct eight-byte magic `UBEUBL1\n`. It contains exactly three
entries in canonical order: `Artifact`, `Interface`, and `Manifest`.

`Manifest` is UTF-8 line metadata and records at least the bundle format,
package name, semantic version, UBE language version, intrinsic ABI, target
triple, object format, pointer width, public-interface SHA-256, and artifact
SHA-256. RP8 requires language `1.0`, intrinsic ABI
`ube-intrinsic-abi-1`, a matching target triple, and valid hashes before a
bundle is accepted. `Interface` is the canonical public declaration record;
`Artifact` is the target-specific native library. Unknown format versions,
missing entries, wrong targets, incompatible identities, and corrupt payloads
are controlled diagnostics.

## Compatibility

Import tooling may read classic VB6 project and resource formats, including
`.vbp`, `.vbg`, `.frx`, and `.ctx`, but native UBE projects are written as
`.UBE`, `.UBG`, and `.UBR`. Import never changes the rule that UBE's project and
source metadata are text and binary payloads are separate.
