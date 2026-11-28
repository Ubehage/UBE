# UBE IDE workplan

**Status:** implementation open; planning continuity reconstructed 2026-11-28.

This checklist comes from the accepted [DESIGN.md](DESIGN.md) and the existing
compiler/product roadmap. It does not restore the missing historical workplan,
introduce new phases, or establish that an IDE application was delivered.
The checkout currently has no `UBE-IDE/` application. Every implementation and
acceptance item below is open.

## Dependencies and ordering

The compiler's [IDE execution-context contract](../compiler/IDE-CONTEXT.md)
provides a guarded Windows host-session fixture. It does not supply the IDE,
source-level debugger, or editor services. Remaining compiler dependencies are
tracked in [compiler/Roadmap.md](../compiler/Roadmap.md): source-level debug
information and documented compiler services remain separate requirements.
Admission and evidence must be checked against the current compiler profile
before an IDE feature is presented as supported.

Preserve the DESIGN ordering: establish document ownership, save/recovery and
process isolation before exposing editable user work; validate grayscale
interaction/docking prototypes before locking detailed visual identity; select
the localization resource format before introducing production interface text.
Semantic editor features require versioned compiler APIs. Debug views require
real debug metadata and debugger capabilities, not the host-session fixture.

## Open implementation and acceptance checklist

- [ ] Implement the native application shell and shared command service in the
  designated `UBE-IDE/` application location. Keep compiler, debugger adapter
  and user programs outside the editor process; bound and validate their output.
  Acceptance: a service/program failure leaves the editor and unsaved work usable.
- [ ] Implement document-owned undo, modified-document handling, atomic saves,
  periodic recovery copies, external-change reconciliation and recovery after
  abnormal exit. Acceptance: failed writes preserve prior files; view changes do
  not discard undo; local unsaved changes are never silently overwritten.
- [ ] Implement the locked central-document workspace and default tool positions,
  full tool docking/tabbing/auto-hide/floating, document groups and keyboard
  equivalents. Acceptance: every tool can be reopened, moved and restored;
  layout operations preserve document contents, active document and editor focus.
- [ ] Implement Code/Design/Debug starting layouts and saved Custom layouts.
  Automatic switching stays disabled by default. Acceptance: validated layout
  restoration repairs missing monitors, changed DPI, corrupt/versioned settings
  and off-screen bounds without preventing startup; Reset Layout restores defaults.
- [ ] Complete grayscale interaction prototypes, then the visual choices left
  open by DESIGN: palette, typography, spacing, icon family and control metrics.
  Acceptance: keyboard navigation, light/dark/high-contrast presentation, scaling
  and non-color status cues meet the accepted accessibility requirements.
- [ ] Define and implement the repository-owned UTF-8 localization resources
  required by DESIGN, with stable keys, typed named placeholders, English source
  locale, explicit fallback and bounded validation. Acceptance: missing/corrupt
  resources have an actionable emergency path; translated expansion and supported
  bidirectional presentation do not hide essential controls or information.
- [ ] Implement project/group exploration and settings against
  [project-files.md](../lang-doc/project-files.md). Acceptance: source ordering,
  unknown metadata and unchanged file bytes survive round trips; changes are
  deterministic and generated content is disclosed. VB6 import supplies an
  explicit migration report rather than silently guessing unsupported behavior.
- [ ] Integrate versioned syntax/semantic/refactoring requests through documented
  compiler services, with cancellation, stale-result rejection, restart recovery
  and dependency-aware incremental work plus a deterministic full-build path.
  Acceptance: the editor remains usable during service failure and never presents
  stale or independently invented semantic results as compiler truth.
- [ ] Implement the code editor, search, navigation and locked View Definition
  behavior. Acceptance: resolution follows the compiler-selected symbol/source
  identity, including references and conditional compilation; ambiguous or
  unavailable targets produce an explanation instead of a guessed location.
- [ ] Implement the locked standard-library source browsing and project-local
  customization workflow. Acceptance: canonical UBECore stays immutable; a local
  copy includes its necessary dependency closure, manifest edits are recoverable,
  original identities/hashes remain recorded and upstream updates never replace
  customized code automatically. Unsafe/unavailable customization is explained.
- [ ] Implement form/control designers, Toolbox, Properties/Events and the UBR
  resource editor against accepted format/runtime contracts. Acceptance: only
  owned metadata changes; paired source/resource writes are recoverable and
  never leave a silently mismatched pair; unsafe round-tripping offers text editing.
- [ ] Implement build/run coordination and Problems/Output with explicit project
  and source-version identity, bounded progress and cancellation. Integrate the
  existing guarded IDE-run session without treating it as a debugger.
  Acceptance: failed/cancelled work preserves documents and coherent build state.
- [ ] Implement source-level debugging, Immediate, breakpoints, Call Stack,
  Locals, Watches, Registers and debug controls when compiler/debugger dependencies
  are qualified. Acceptance: selected thread/frame values come from actual debugger
  snapshots; stale/unavailable/optimized-away values are explicit. Registers obey
  normal docking, show snapshot age, and never imply safe live sampling where the
  target cannot provide it. Register editing remains outside the first version.
- [ ] Make completed repository samples discoverable through project creation or
  the sample browser. Acceptance: each exposed sample opens against demonstrated
  compiler support; the IDE does not mark the owner's sample requirement complete
  merely by listing planned samples.
- [ ] Qualify the complete IDE under the DESIGN safety and responsiveness gates:
  malformed files/protocols/settings, low memory, cancellation, event loss,
  startup, typing, layout changes, large files/projects and long debug sessions.
  Acceptance: UI work stays bounded and does not perform compilation or blocking
  child-process/file work; failures preserve edits and have actionable diagnostics.
- [ ] Complete native packaging, offline resources, settings migration,
  accessibility/localization and signing acceptance required by DESIGN and the
  product roadmap. No platform support is claimed without tests on that target.

## Handoff and evidence

No IDE application acceptance command has been run for this planning repair.
The next implementation task must select an existing checklist item, identify
its qualified compiler/runtime dependencies, and define concrete assertions
before marking it complete. Record exact commands, results, negative controls
and limitations here as implementation proceeds. The compiler host fixture's
existing evidence remains owned by `compiler/IDE-CONTEXT.md`.
