# UBE 1.0 project-reference and library-identity audit

**Scope:** UBE 1.0 / Compiler v3 candidate definition  
**Status:** compatible source-project rules promoted; artifact-format choices
saved for later resolution  
**Method:** retain the simple native project format and classic VB project
visibility where that does not conflict with UBE's approved deterministic,
portable, separately compiled library architecture

## Sources checked

- `project-files.md`
- `language-spec.md`
- `audits/names-callbacks.md`
- `audits/forms-controls.md`
- `project-docs/architecture.md`
- `compiler/UBE_Compiler_v2/V3_BOOTSTRAP_CONTRACT.md`
- `compiler/archived/UBE_Compiler_v3/DESIGN.md`

## Compatible project model

### Compilation package

One `.UBE` manifest and all of its ordered `Source` entries form one
**compilation package**. The manifest `Name` is the package's declared name.
It is compared with the same Unicode simple folding as source identifiers;
its original spelling is retained for diagnostics, output names, and
metadata. A package name must be a valid bare or bracketed UBE identifier
after unquoting. Brackets are source spelling rather than part of its identity.

All source modules in the package share the declaration universe already
specified for v2 and v3. Their `UBE_Name` values must be unique after folding.
`Friend` means visible only within this package. A referenced library is a
different package and therefore cannot see or supply `Friend` declarations.

The package name is the first component of cross-package qualification:

```ube
PaintCore.ColorMath.Blend(Source, Target)
```

Here `PaintCore` is the referenced package identity, `ColorMath` is a standard
module, and `Blend` is its Public member. Package, module, and member components
are resolved statically. No component falls back to runtime lookup.

UBE 1.0 has no separately declared source namespace or package alias. Two
direct references with the same folded package name are therefore an error,
even if their paths or versions differ. Adding aliases would change source
identity and is reserved until a complete alias/import design is approved.

### Source-project references

The compatible extension to `UBE-Project 1` is an ordered, repeatable key:

```text
Reference = "../PaintCore/PaintCore.UBE"
Reference = "../Drawing/Drawing.UBE"
```

Each value is a project-relative path to a `.UBE` manifest whose `Kind` is
`Library`. It uses the same quoting, case, duplicate-path, missing-file and
controlled-diagnostic rules as other explicit project inputs. A relative
reference may traverse parent directories to reach the sibling libraries shown
above; each referenced manifest's sources must remain inside its own directory.
Absolute reference paths are invalid and no search path is inferred. This
distinction resolves the earlier ambiguous tree-containment wording.
An executable is not a legal reference. A project may not reference
itself, and the complete directed reference graph must be acyclic.

The referenced manifest, rather than the filename or directory name, supplies
the package identity. Renaming a path without changing `Name` therefore does
not change source qualification. Changing `Name` is a source-breaking library
identity change and must be diagnosed wherever the old qualifier is used.

References are direct and non-transitive for source lookup. Public declarations
of a directly referenced package are visible; declarations from that
library's dependencies are not injected into the consumer merely because the
library needs them. A consumer that names such a package must reference it
directly. Link metadata may still retain transitive implementation
dependencies needed to load and run the direct library.

This model requires no package-manager, registry, environment search path,
network lookup, or install-on-first-run behavior. Every source reference is an
explicit checked-in relative build input.

### Reference order and name lookup

Manifest reference order is significant for deterministic dependency
processing, module initialization after graph ordering, metadata emission,
diagnostics, and linker argument construction. It is **not** a tie-breaker for
ambiguous source names.

After the earlier lookup levels in `language-spec.md` have failed, all direct
references contribute their accessible Public candidates at one lookup level.
Exactly one viable canonical declaration succeeds. More than one is an
ambiguity error with notes identifying every package and declaration. The
programmer resolves a module collision with
`PackageName.ModuleName.Member`; reference order never silently selects the
first package.

This clarifies the existing phrase "in declared reference order": the compiler
visits and reports references in that stable order, but candidate uniqueness
still controls selection. Current-package declarations retain their approved
precedence over referenced declarations. Private and Friend declarations in a
reference never enter the candidate set.

### Library identity and metadata

A compiled UBE library must carry machine-readable metadata containing at
least:

- the folded package identity and original `Name` spelling;
- the language and library-metadata format versions;
- the target triple, pointer width, endianness, and foreign-ABI version;
- exported UBE modules, Public declarations, exact signatures, visibility,
  type identities, layout/managed-field information where required, and
  intrinsic requirements;
- direct dependency package identities and the compatibility requirements
  recorded for them; and
- an integrity identity tying the metadata to the matching native code
  artifact.

Within UBE metadata, a declared type or callable identity is the tuple of
package identity, module/type identity, folded member name, and declaration
kind/signature where the language permits a same-name logical property
accessor. A native linker symbol is an implementation detail derived from that
identity; it is not the source lookup key. `Public Export` foreign symbols and
their generated foreign ABI metadata remain a separate boundary and do not
make arbitrary UBE Public declarations foreign exports.

The compiler validates metadata before using any declaration. A name mismatch,
wrong target, unsupported metadata/ABI version, duplicate identity, missing
dependency, incompatible signature/layout, corrupt length/hash, or code/
metadata integrity mismatch is a controlled compile-time diagnostic. It must
not be deferred to an accidental native-linker failure when the metadata can
detect it earlier.

### Core library reference

The versioned UBE core library selected by the compiler is an implicit direct
library reference so normal programs do not need boilerplate manifest entries.
Its package identity must be fixed by the eventual library contract; this
audit uses `UBECore` only as an illustrative spelling, not a frozen name.

Its Public standard-module declarations participate at the same referenced-
package lookup level as explicit references. Current-package declarations may
shadow them under the approved lookup order. A collision between the core
library and another reference is ambiguous rather than silently preferring
either one; explicit package/module qualification resolves it. Compiler
intrinsics continue to be identified by their versioned declaration and
signature metadata, not by textual name alone.

### Dependency build and initialization order

The reference graph is validated before source parsing depends on imported
metadata. Dependencies are built or selected before dependents. Independent
nodes retain manifest discovery order as the deterministic secondary order;
cycles are errors with the cycle path reported.

Within each package, module initialization retains source-manifest order. A
library package completes its own dependency initialization and then its module
initialization before any of its exported/public entry points are admitted.
An executable's dependencies initialize before that executable's modules.
Orderly shutdown reverses successful package initialization order, while each
package retains its already-approved reverse module-termination order. Partial
initialization unwinds only successfully initialized packages/modules in the
corresponding reverse order.

A `.UBG` remains an orchestration input rather than a link unit. It may contain
all projects needed for a workspace build, but listing two projects in a group
does not create a reference between them; the consuming `.UBE` must still
declare `Reference` explicitly.

## Startup-key reconciliation

The existing manifests and preserved v2 contract use:

```text
Startup = "Main"
```

In UBE 1.0 this key should mean only the language-level entry procedure. Its
value must be `Main`, resolving to the project's unique valid `Sub Main()` or
`Function Main() As Long`. It never names a form. Keeping the key and spelling
preserves every checked-in v1/v2/v3 manifest and avoids changing the bootstrap
contract. Although uniqueness makes it redundant, retaining an explicit entry
key is harmless and gives malformed manifests a precise diagnostic.

An optional startup form uses a distinct key:

```text
Startup = "Main"
StartupForm = "PaintWindow"
```

`StartupForm` must resolve after folding to a form module in the same
executable package. It is illegal for `Kind = "Library"`, cannot name a
referenced form, and does not replace or create `Main`. This removes the VB
project-file ambiguity without changing VB-like source behavior.

The compatible generated ordering is:

1. initialize referenced packages;
2. initialize every executable module in manifest order;
3. construct and load the configured startup form's default identity; and
4. invoke source-level `Main`.

After `Main` returns, the approved live-thread/active-event-source rule decides
whether the process idles or begins orderly shutdown. This is the ordering
already recommended by the form audit and is compatible with the architecture's
sole language-level `Main`; it should be promoted unless the owner chooses a
different order for non-VB reasons.

## Architecture choices saved for later resolution

These questions cannot safely be answered merely by defaulting to VB because
VB6's COM reference registry conflicts with UBE's portable, repository-owned,
metadata-driven architecture.

### Question 1: compiled-artifact reference spelling and container

`Reference` above precisely covers source project references. Release users
also need a way to consume an already compiled UBE library without its source
project. The native code suffix varies by target, and the repository has not
yet frozen either a portable library bundle or a standalone UBE metadata
suffix.

Choose one after the object/library packaging design is complete:

1. `LibraryReference = "relative/path/to/bundle"`, where one versioned UBE
   bundle contains metadata plus target-specific artifacts; or
2. paired explicit metadata and native-artifact keys in a structured reference
   block introduced by `UBE-Project 2`.

Do not use adjacent repeatable scalar keys whose pairing depends on order, and
do not infer metadata by stripping an OS-specific filename suffix. Until this
is resolved, `UBE-Project 1 Reference` should accept `.UBE` source manifests
only.

### Question 2: dependency version constraints

The source-path model is reproducible because it identifies one local
manifest, but the compatibility relation between separately compiled package
versions is not frozen. Decide whether UBE library metadata uses semantic
major/minor compatibility, exact interface hashes, or both. The compiler must
not choose "latest" from the machine or network, and two versions with the same
folded package identity cannot both be source-visible in one UBE 1.0 package
without a future alias/version-qualification design.

### Question 3: final core-package identity

The compiler must implicitly select the compatible core library, but its
canonical package `Name` has not been approved. Freeze that name together with
the compiler/core-library metadata contract. It must not be inferred from a
platform filename, installation directory, or linker spelling.

## Required conformance cases after promotion

- folded duplicate package and source-module identities;
- a current-package member shadowing a referenced declaration;
- unique unqualified reference lookup and ambiguous lookup independent of
  reference order;
- `Package.Module.Member` disambiguation and invalid qualifier fallback;
- inaccessible referenced Private/Friend declarations;
- direct versus transitive visibility;
- duplicate normalized reference paths, duplicate package identities,
  self-reference, and multi-project cycles;
- deterministic dependency/module initialization and reverse partial unwind;
- referenced executable rejection and library-with-`StartupForm` rejection;
- `Startup = "Main"` compatibility, missing/invalid/duplicate Main, and
  same-package `StartupForm` resolution;
- wrong-target, corrupt, incompatible, or mismatched code/metadata rejection;
  and
- no registry, environment, network, or undeclared search-path fallback.
