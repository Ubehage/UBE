# Deferred UBE language and architecture questions

**Status:** decisions intentionally deferred while the UBE 1.0 language is
closed  
**Rule:** this file contains only choices for which classic VB behavior would
conflict with approved UBE architecture, or for which VB provides no portable
model. Ordinary VB-compatible behavior does not require owner confirmation.

## Portable library architecture

RP8 freezes `UBE-LibraryBundle 1` (`.UBL`) in `project-files.md`, using the
semantic-version plus exact public-interface-hash compatibility model in
`project-docs/versioning.md`.

RP8 also resolves the other two portability choices. Legacy `Date = ...` and
`Time = ...` host-clock assignment is rejected in portable UBE 1.0 code;
clock mutation requires a future explicit, permission-aware platform API.
Classic `Circle`, `Line`, `PSet`, and `PaintPicture` forms remain reserved
compatibility syntax; portable graphics operations are ordinary calls in a
separately linked graphics library.

These deferred decisions do not change parsing of source-library
`Reference = "path/Library.UBE"` entries or any other currently frozen core
production, so they do not block the core source grammar.

## Procedure error propagation

- Decide whether a recoverable failure inside a called UBE procedure may
  transfer control to an enabled handler in its caller, as classic VB does, or
  whether the callee always applies UBE's neutral-result continuation locally.
  The current rules make handlers procedure-local and define neutral results,
  but do not specify the cross-procedure boundary. Implementations must not
  infer a new failure by inspecting a possibly older nonzero `Err` record.

The canonical core package identity (`UBECore`) and the combined semantic-
version/public-interface-hash compatibility model are frozen in
[`../project-docs/versioning.md`](../project-docs/versioning.md). The container
that will carry that metadata remains deferred above.
