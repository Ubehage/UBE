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
StartupForm = "PaintWindow"
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

Compiled-library reference containers, dependency-version compatibility, and
the canonical implicit core-library package name remain intentionally
unfrozen. `UBE-Project 1 Reference` therefore accepts source `.UBE` manifests
only; it does not infer metadata from a platform library filename.

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

The versioned `.UBR` container will have a magic signature, a bounded directory
of named entries, payload lengths, and integrity hashes. Its exact byte layout
will be frozen before implementation. Readers must validate all lengths,
offsets, names, duplicates, and hashes before exposing data. Truncation,
corruption, unsupported versions, excessive sizes, or a missing reference must
produce a useful diagnostic and must never panic or read outside the file.

During compilation, referenced entries are treated as build inputs and emitted
into the program's target-appropriate read-only resource representation. The
compiler records them for dependency tracking and deterministic builds; an
unreferenced sidecar is not implicitly scanned or embedded.

## Compatibility

Import tooling may read classic VB6 project and resource formats, including
`.vbp`, `.vbg`, `.frx`, and `.ctx`, but native UBE projects are written as
`.UBE`, `.UBG`, and `.UBR`. Import never changes the rule that UBE's project and
source metadata are text and binary payloads are separate.
