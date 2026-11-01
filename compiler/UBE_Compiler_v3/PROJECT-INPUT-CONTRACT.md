# Bounded project input and parallel frontend

Status: concrete contract for owner review, before production implementation.
The owner requested this existing workplan deliverable after commit `41632c4`.
This document does not change the language or the completed concurrency proof.

Authorities: [project format](../../lang-doc/project-files.md),
[reference identity](../../lang-doc/audits/project-references.md),
[development plan](../../project-docs/Development-Plan.md), and
[source-set ownership](CONCURRENCY-CONSUMER.md).

## Scope and boundaries

One executable `.UBE` input and at most one direct, explicit `UBECore` source
reference are in this consumer. No implicit library lookup is permitted. The
reference manifest must declare `Kind = "Library"` and a package identifier
folding to `UBECore`; its path spelling supplies no package identity. The root
must declare `Kind = "Exe"` and `Startup = "Main"`. This consumer checks project
structure and the currently implemented syntax, not entry-point binding, types,
exports, library ABI or generated code.

Generic counted-byte path operations belong in UBECore. Manifest grammar,
package/source identity, containment policy, limits, diagnostics, canonical work
order and publication belong in the compiler. Existing source/UTF-8/file intake,
envelope, scanner and parser bodies are reused. `TryParseSources` remains the
single work-budget owner. No second executor, worker-side manifest loader,
whole-project capture or archived implementation is introduced.

Other libraries, transitive references, project groups, resource containers,
binary libraries, designer input and unimplemented grammar are reported as
unsupported capabilities, never silently ignored or reported as invalid UBE
merely because they are outside this consumer. Malformed structure is still a
project error. A well-formed unsupported key must be distinguished from an
unknown key. The existing source-file CLI remains available.

## Manifest grammar

Read the manifest through the same bounded UTF-8/newline-qualified document
pipeline used for source. Retain exact bytes and original byte/scalar positions.
Accept an optional initial BOM, LF or CRLF, blank lines, and a comment whose
first non-horizontal-space character is apostrophe. Require `UBE-Project 1` as
the first nonblank/noncomment line. A different valid version is unsupported;
missing/malformed headers are errors.

Each entry has a case-insensitive ASCII key, optional surrounding horizontal
space, `=`, and one quoted UTF-8 value. Doubled quotes encode one value quote.
After the closing quote only horizontal space is accepted; this does not add
inline comments to the normative format. Reject missing quotes/equals, trailing
text, NUL and malformed UTF-8 with the exact original witness.

Required scalar keys are `Name`, `Kind`, and, for the executable, `Startup`.
Require at least one `Source` in each package. Preserve the order of repeated
`Source` and `Reference` keys; duplicate scalar keys are errors regardless of
key case. Recognize the documented `Optimization` and `DebugInformation` domains
and defaults, retaining their values without claiming code generation. Recognize
`Resource`, `StartupForm` and `LibraryReference` as known unsupported facilities.
An unknown key remains an error. Do not use the bootstrap compiler's manifest
acceptance as the normative oracle.

Package names use the established bare/bracketed UBE identifier rules after
unquoting and Unicode simple folding for identity. Preserve spelling. Reuse the
existing compiler identifier/envelope helpers and UBECore Unicode facilities;
do not create a competing identifier or case-fold implementation.

## Paths, package boundaries and identity

Resolve the invocation's project path against one captured working directory.
Keep original declared spellings for diagnostics and canonical resolved paths
for file access and duplicate checks. Newly generated manifests use `/`; read
both host separators on the maintained Windows host.

Every `Source` is relative to its own manifest directory. Reject absolute and
drive-relative source paths, and any `..` normalization that escapes that
directory. Reject repeated normalized source paths. Relative `Reference` paths
may traverse parents to a sibling library; absolute/drive-relative references
are invalid. Reject self-reference, repeated normalized reference paths, a
referenced executable, cycles and folded package-name collisions. A dependency
beyond the bounded direct UBECore reference is explicitly unsupported.

Source identities are unique after Unicode simple folding within each package;
the same module name in different packages is not a duplicate. Native envelope
kind/extension and supported version checks retain their existing behavior.
Native MODULE is the supported body scope. CLASS/FORM/CONTROL and legacy input
retain their explicit unavailable/deferred classification.

Path comparison follows the host filesystem contract, not UBE identifier folding.
The concrete lexical-normalization/opened-file-identity route in
[PATH-BYTES-PROPOSAL.md](../../std-lib/PATH-BYTES-PROPOSAL.md) was approved by the
owner on 2026-10-31. It explicitly distinguishes lexical containment from physical
containment across reparse aliases. Do not infer physical containment from a
lexical prefix. The proposal also defines the bounded disposition of paths that
leave and then re-enter their source root.

## Stable source set, ownership and publication

The manifest reader borrows a qualified immutable `SourceDocument` and fills a
private `ProjectManifest` record. `ProjectDeclaration` holds original key/value
byte intervals; no source document or decoded path is copied into that record.
`ProjectManifestFailure` holds Code, EntryKind and an original byte interval;
callers seed Code=1310 before managed entry. `TryReadProjectManifest` returns
fresh Boolean status, with partial metadata permitted only in unpublished
construction state. The enclosing project reference, not a record assignment,
provides complete-result publication.

The reader retains ordered source spans up to the existing 256-source maximum.
It counts every Reference and retains the first two spans: the one admitted
direct reference and the first excess/duplicate witness. Further dependencies
are unavailable under this two-package consumer, not a new project-language
limit. It retains the first known unsupported-facility witness for the loader
after complete structural validation. Fixed metadata words are matched with
ASCII case insensitivity, while Name uses existing UBE identifier rules and
paths preserve bytes. Decimal header version spellings with leading zeroes
retain their integer meaning, as in the established source envelope contract.

Discover root entries in declaration order, then the direct library's entries in
its declaration order. Package IDs are root 0, direct UBECore 1. Source IDs are
the resulting canonical zero-based indexes, independent of thread completion.
Keep package, declaration-path span, resolved path, envelope identity and original
document associated with each ID. This is work/diagnostic order; dependency-first
initialization and future name lookup retain their separately specified rules.
Reference order never breaks an ambiguous declaration-name tie.

Discovery and file intake happen before source-worker admission. Private pending
metadata owns manifests, paths and each immutable `SourceOwner`. Workers receive
only the existing per-source references, not a project copy. A final compiler-
owned reference retains metadata and the complete `SourceWork` vector together.
Publish that reference only after all validation/work and drain succeeds. Failure
or cancellation preserves the complete older project result, its manifests,
paths, source bytes, tokens and syntax graphs.

Use the existing recoverable file-token contract. A failed close remains owned
for retry; never discard a live token. Cancellation stops further discovery or
admission at explicit boundaries and drains admitted workers. New calls have
fresh structured status; callers seed storage failure before managed admission.
No failure is inferred from a stale `Err`, and worker `Err` is never read by the
coordinator as another thread's result.

### Shared file intake implementation boundary

Preserve the existing `TryReadSourceFile` declaration and its publication/error
contract. Extract its single open/read/append/extra-byte/close body into
`TryReadSourceFileInput`, with caller-owned private `SourceInput` state, a
`ReadIdentity` Boolean and a private Byte-array identity output. The ordinary
source entry passes False and finishes directly into its existing Document;
it must not acquire an extra document copy, file handle or identity query.

Add compiler-local `TryReadSourceFileIdentity` with the existing path/maximum/
Document/failure/token parameters and an additional ByRef Byte-array identity.
It uses that same intake body with True, querying the existing open token before
read/close, then finishes the document. Its paired outputs are explicitly private
construction state, not an independently failure-atomic public pair: identity may
be prepared before a later read/close/document failure. Only project-owned pending
metadata calls this entry. The whole project reference remains unpublished until
every part succeeds. This avoids duplicating intake or copying a whole qualified
document merely to pair it with 16 identity bytes. No compiler type enters UBECore.

Observe request cancellation before and after each bounded file intake, before
further discovery/admission and at the existing worker boundaries. Do not add a
second executor or imply interruption of a blocking host read. A failure still
closes, or returns its explicit live close owner for retry; cleanup does not erase
the primary failure. Exact identity-query, close-failure and old-reader-copy
regressions are required before relying on the extracted body.

## Initial resource bounds and diagnostics

The request carries explicit limits. Initial supported maxima are 1 MiB per
manifest, two packages, 256 total sources, 16 MiB per source, 64 MiB aggregate
source bytes, 1..4 workers and the existing scanner/parser limits. Paths retain
the counted UTF-8/Windows conversion bound from the file contract, with a
131068-byte per-path ceiling. Aggregate declared/resolved path bytes are limited
to 4 MiB; combined retained manifest/path/name bytes are limited to 8 MiB. Checked
sums test those bounds before allocation or source admission. These are request
resource bounds, not language limits. Exceeding a request limit is a resource/domain outcome,
not a syntax error or permission to skip inputs.

Manifest errors name the owning manifest and original line/column/byte span.
Source errors name the associated declared source and its original coordinates.
Validate discovery deterministically before parallel body work; choose the first
project-structure failure in declaration/discovery order, then the lowest failing
canonical source ID for body failures. Preserve existing source failure kinds;
add project-specific classifications without reinterpreting a parser diagnostic.
Cleanup failure must not overwrite an earlier primary failure.

CLI: preserve every existing two-argument `--check <source-file>` oracle;
add `--check <project.UBE>` with default budget one and
`--check <project.UBE> --jobs N` for decimal N in 1..4. Invalid options/budgets are
usage failures, not successful empty projects. A project whose syntax succeeds
still returns the existing semantic-checking-unavailable outcome (`UBE1012`),
once, and produces no executable/output artifact. [PROJECT-DIAGNOSTICS.md](PROJECT-DIAGNOSTICS.md)
freezes exact project codes, messages, option forms, ordering and display/fallback
obligations before CLI implementation. Independent process cases and the bounded
filename formatter still need their concrete pre-implementation probes.

## Prerequisite decisions requiring concrete resolution

The current byte-file API can open/read/close a counted path and obtain command
arguments; it provides no working-directory snapshot, absolute-path resolver,
host path-identity comparison or opened-file canonical path. Those cannot be
silently replaced by compiler-specific C path policy.

`PATH-BYTES-PROPOSAL.md` now specifies four exact Try signatures, including two
host bindings, ordinary UBE normalization/combination, identity queries on
existing open tokens, errors, preservation, lifetime and cost bounds. Its lexical
route and containment limitation are approved; physical containment
would require a separately concrete retained-traversal contract. No new raw
managed-address API or language representation is implied.

Exact CLI diagnostics are frozen in PROJECT-DIAGNOSTICS.md; the path prerequisite is approved.
Independent manifest
definition cases are in `PROJECT-INPUT-CASES.md`; their transport/span consistency
check does not execute a loader. The uninstrumented baseline procedure is in
`PERFORMANCE-CONTRACT.md`. These can proceed without implementing a new host API
or changing production behavior.

## Required acceptance

Hand-author expected manifests, normalized paths, package/source order, original
spans and failure dispositions independently of the implementation. Cover quoted
UTF-8/doubled quotes, BOM/CRLF/comments, all required/duplicate/unknown/unsupported
keys, identifier folding, source/reference normalization, sibling libraries,
escapes/absolute paths, aliases, duplicates/cycles/package collisions, missing
files, limits, and valid unsupported source kinds.

Run actual UBE discovery/intake and existing scan/parse workers through both
accepted source-built stages. Compare complete metadata, documents, tokens,
ordered graphs and first diagnostics at budgets 1/2/4 under repeated/reversed
completion. Include zero/one/many inputs, unequal files, independent simultaneous
contexts, cancellation, true allocation/root/file/close/start/wait failures,
complete older-result retention and zero owned residual resources. Preserve the
earlier 592/5652/4049/217/41 gates as applicable; additions may increase counts,
but cannot remove their assertions.

Freeze performance inputs, expected work/results, optimized build/tool identities
and the pre-optimization one-worker baseline before optimization. Meet the exact
[parallel performance gate](../../project-docs/Development-Plan.md#parallel-performance-acceptance)
on the representative real and >=32-source balanced corpora, retain an uneven
corpus and small-input guards, and record both seven-trial sessions. Correctness
alone does not complete this frontend deliverable. No later semantic/backend
work or further GitHub push is authorized by this goal.
