# Project discovery and publication ownership

Concrete continuation of PROJECT-INPUT-CONTRACT.md. These are compiler-owned
domain objects within the existing frontend, not new subsystems or executors.
The manifest and initial discovery/publication implementation exist. Initial
native consumer tests pass; complete consumer/source qualification is pending.
See PROJECT-INPUT-EVIDENCE.md for the exact tested scope and remaining gates.

## Retained objects

- `ProjectPackage` owns the original manifest `SourceDocument`, its private
  `ProjectManifest` metadata, declared/resolved/directory path bytes, the 16-byte
  opened-file identity, package ID and referring declaration span. Root ID is 0;
  direct UBECore is 1. Raw name/value spans remain views into that manifest.
- `ProjectSource` owns declared/normalized/resolved path bytes, opened-file
  identity, package/declaration indexes and the recognized `SourceEnvelope`.
  It retains one `SourceOwner` with the existing Document/SourceId fields.
  No mode flags or project fields are added to SourceOwner or SourceWork.
- `ProjectInput` retains one captured working directory, the invocation path,
  ordered package/source reference vectors, logical counts, checked aggregate
  byte totals and a validation flag. It owns construction mutability; after
  intake succeeds it is immutable. Successful vectors have exact logical length.
- `ProjectSyntax` retains that input reference and the complete existing
  SourceWork vector. It contains no semantic/backend acceptance flag.

Workers receive only the existing SourceOwner references. No package, manifest,
path table or whole project is copied into a worker. Reference-vector trimming
may copy references, never document/token/node payloads.

## Entries and limits

`TryReadProjectInput` consumes counted invocation-path bytes, explicit limits,
the existing SourceCancellation reference and a caller-owned zero OpenToken.
It produces a complete ProjectInput replacement only after successful discovery,
file close and validation. Failure retains the previous input reference.

`TryParseProject` additionally accepts Jobs 1..4 and a ProjectSyntax replacement.
It performs intake, builds the exact ordered SourceOwner reference vector, calls
TryParseSources once with the same budget and publishes a new ProjectSyntax
reference only after complete success/drain. Failure leaves the entire earlier
ProjectSyntax graph unchanged. No direct serial parser alternative is added.

`ProjectLimits` carries nonnegative maxima: manifest bytes <=1048576, packages
<=2, sources <=256, per-source bytes <=16777216, total source bytes <=67108864,
per-path bytes <=131068, aggregate path bytes <=4194304, retained manifest/path/
name bytes <=8388608, tokens/nodes/pending <=1048576 each and depth <=256.
Zero budgets are meaningful resource boundaries, not defaults or empty success.
A rootless initializer supplies the documented normal defaults for the CLI.
Known lengths/sums are checked before admission/copy/allocation. Native directory
capture has its own fixed bound; check its returned candidate before retaining
it under aggregate request accounting. Request limits do not promise a complete
process-memory ceiling or physical filesystem snapshot.

The same read-only context may be inspected after a failure for diagnostics.
Failure context retains the failed request's input metadata/documents, not its
private worker token/node graphs. The older published result remains separate.

## Failure and diagnostic ownership

`ProjectFailure` has a fresh category, Code, package/source IDs, location role,
original byte interval, original SourceFailure/FileFailure or SyntaxFailure,
and a ProjectInput context reference. Code 0 delegates to the retained existing
source diagnostic domain; project codes follow PROJECT-DIAGNOSTICS.md. Reuse the
existing 200+ scanner-to-syntax projection when needed, not a new interpretation
of parser errors.

Categories are success0, invalid request1, resource2, project structure/policy3,
unavailable4, storage5, file intake6, source syntax/scanning7, cancellation8,
worker admission9 and wait10. Locations distinguish invocation, manifest and
source documents. Use invocation bytes when failure occurs before context/path
construction. Manifest path/schema failures point into the owning manifest;
source read/body failures use the associated source path/document.

Caller seeds storage category/code 1310, IDs -1 and a Nothing context before
managed entry. Each fallible managed helper is likewise preceded by fresh
storage status. No result derives from earlier Err. A close failure keeps its
explicit OpenToken for caller retry and never erases an earlier structured
failure. At most one intake token is owned at a time; all close before workers
start. Cancellation checks occur before/after each bounded intake, before more
admission and at existing worker boundaries; blocking host I/O is not forcibly
interrupted.

Reference assignments are fallible in the bounded bootstrap and preserve their
previous destinations. Clear and verify loop-local constructor targets before
`New`, and check essential stored associations and final reference publication
by identity. A failed binding after worker admission records storage failure and
continues drain; it must not dereference a stale work reference or exit the pump
early. Managed diagnostic-location helpers return checked Boolean status.
Storage-status initialization takes scalar field references and needs no managed
admission. These rules change no `Set` semantics or ownership boundaries.

## Discovery policy

Use the frozen root-manifest/root-sources/direct-library/library-sources order.
Normalize Source/Reference declarations through UBECore; preserve spelling and
declaration intervals. Compare opaque opened-file identities for source aliases
within a package and manifests across the dependency graph. Package/module
names use existing quoted/bracketed identifier validation and simple folding.
Source IDs remain canonical indexes. No filesystem comparison uses that fold.

Resolve a manifest's parent lexically using the existing path resolver with
literal `..`; it does not require another path API or filesystem directory query.
Recognize malformed/unsupported paths, duplicate declarations, self/cycles,
package collisions and unavailable additional libraries explicitly.

On a failed MODULE envelope, run existing conditional preflight/scanner only on
that failed discovery path to preserve the source CLI's first-error priority.
Reuse its scalar priority predicate rather than copying scanner/parser bodies.
Successful source tokens are constructed once in their actual UBE worker.
Known unsupported envelopes retain the existing deferred-family handling.

Independent consumer tests must prove full metadata/order, original bytes/spans,
identity cases, limits, cancellation/faults/close retry, exact older-result
retention, zero residual resources, budgets 1/2/4 and complete work equality.
This document is no substitute for those tests or the final performance gate.
