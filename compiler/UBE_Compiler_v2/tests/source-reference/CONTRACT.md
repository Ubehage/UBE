# Direct source-reference bootstrap contract

This prerequisite serves the fresh v3 source-ingestion workplan item. It does
not turn v2 into a public compiler or qualify standalone shared-library output.

An executable project may explicitly reference up to 16 source Library projects
with ordered `Reference = "relative/path/Library.UBE"` entries. References are
resolved only against the containing manifest. Parent segments are permitted
for sibling libraries, as shown by `lang-doc/audits/project-references.md`;
absolute references and undeclared search paths are forbidden. Each project's
Source entries retain the existing project-directory containment rule. The
executable requires exactly one `Startup = "Main"`. Libraries forbid Startup.
The executable's package is the only source of the entry procedure.

This bounded route accepts independent direct libraries, not nested references.
Self-reference, repeated normalized reference paths, duplicate folded package
names, and nested dependencies diagnose. Thus cycles cannot enter a successful
build. Each project permits at most 256 sources. Manifests and reference paths
also have explicit size bounds. Name, Kind, Startup and native envelope metadata
are validated rather than ignored.

Native sources have `UBE SOURCE 1 MODULE` and one valid `Attribute UBE_Name`.
Module identities are unique within their package. Bare `.bas` source remains
an explicit bootstrap exception for existing v1/v2 sources and diagnostic test
fixtures; every source in a build with a Reference must use a native envelope.
No compatibility import or arbitrary reserved UBE attribute is inferred.

Referenced modules expose only ordinary Public/default-Public procedures and
Types. Private/Friend/Global/Option/module-storage declarations, classes and
other top-level constructs are rejected in referenced modules. Native
intrinsic bindings and record fields retain their existing qualified subset.
Module/package qualification is not supported by this bootstrap route and is
explicitly rejected. Existing global duplicate procedure/type rejection is a
deliberately stricter bound than full UBE name lookup. Libraries cannot consume
declarations from the executable or another independent direct library.
Conservative rejection of a library identifier colliding with an external
declaration is permitted by this bounded contract; it never grants visibility.

Source-package identity is retained during validation. Ordinary library bodies
are compiled into the executable's LLVM unit from their actual checked-in
paths, without copies, header stripping, generated replacement manifests or
archive dependencies. Standalone Kind Library compilation remains unsupported.

Acceptance requires both source-built v2 stages to execute independently
specified native outputs, emit identical LLVM, and reject malformed manifest,
envelope, visibility, direction, identity and path cases without publishing
LLVM. The actual `std-lib/UBECore.UBE` must be consumed intact. Existing fixed
point and foundation gates remain mandatory. Successful compilation alone is
not acceptance.
