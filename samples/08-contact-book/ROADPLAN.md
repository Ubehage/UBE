# Contact Book roadplan

Status markers: `[ ]` pending, `[~]` active, `[x]` verified, `[!]` blocked.

## Outcome

Create a native windowed contact manager with add, search, edit, delete, sort,
import, and export operations. It demonstrates multiple modules, encapsulation,
collections, stable identities, structured storage, and safe editing workflows.

## User experience

The designed form has a searchable contact list and a detail editor for name,
phone, email, and notes. Add/Edit changes are staged until Save Changes. Delete
requires confirmation and can be cancelled. Import previews errors before
commit; export never mutates the active book.

## Project shape

```text
08-contact-book/
|- ContactBook.UBE
|- src/Main.bas
|- src/ContactBookForm.frm
|- src/Contact.cls
|- src/ContactStore.bas
|- src/ContactFormat.bas
|- tests/ContactBookTests.bas
|- tests/fixtures/
`- README.md
```

## Contracts to decide before coding

- [ ] Select and document a simple structured, versioned UTF-8 storage format
  supported by UBE without third-party parsers.
- [ ] Define field limits, required fields, stable contact IDs, duplicate policy,
  case-insensitive search, and deterministic sort/tie order.
- [ ] Define import as all-or-nothing or as an explicit preview/accepted-subset
  operation; never silently skip malformed contacts.

## Capability gates

- [ ] Classes or the chosen encapsulation mechanism, collections, sorting, and
  string normalization are implemented with defined ownership behavior.
- [ ] `UBECore` supports bounded read/write, text decoding, and atomic save.
- [ ] Native UI support covers master/detail lists, multiline editing, search
  events, confirmation, file pickers, resize behavior, and accessibility.

## Implementation phases

### 1. Encapsulated model

- [ ] Keep contact validation and mutation behind a small public interface.
- [ ] Implement stable-ID lookup, add, replace, delete, filter, and stable sort.
- [ ] Ensure a failed mutation leaves the collection unchanged.
- [ ] Avoid exposing mutable collection internals to the form module.

### 2. Structured persistence

- [ ] Parse version/header and every field into temporary records with precise
  record/field diagnostics and configured limits.
- [ ] Reject duplicate IDs, unsupported versions, malformed escaping, truncated
  data, and excessive inputs without partial publication.
- [ ] Serialize deterministically and save with temporary-file plus atomic-
  replace behavior, preserving the last valid file on failure.
- [ ] Make import/export explicit operations distinct from the working-file save.

### 3. Designed form

- [ ] Create the master/detail form through the visual designer with named
  controls, logical tab order, accessible labels, and resizing rules.
- [ ] Preserve selection by stable ID across filtering and sorting.
- [ ] Stage edits, validate before commit, and prompt before abandoning dirty
  edits or deleting a contact.
- [ ] Keep the active book usable after failed import, export, or save.

### 4. Tests and documentation

- [ ] Test model operations, normalization, sort ties, stable selection, field
  boundaries, and transactional failure behavior.
- [ ] Test exact format round trips, Unicode, unknown versions/fields, duplicate
  IDs, truncation, malformed escape sequences, and resource limits.
- [ ] Inject read, allocation, write, flush, and replace failures where the test
  harness permits, and verify original data remains recoverable.
- [ ] Document module boundaries, format, limits, privacy caveats, and build/run
  steps; review comments against `../../COMMENTS.md`.

## Acceptance criteria

- [ ] Every requested operation is available from keyboard and mouse.
- [ ] Search and sort are deterministic and do not alter stored contact order
  unless the format contract explicitly says they do.
- [ ] Malformed or unavailable files never replace the active valid book.
- [ ] The app is local-only and uses no third-party dependency.

## Non-goals

Cloud sync, operating-system address-book integration, vCard, messaging,
authentication, and encryption are outside this sample.
