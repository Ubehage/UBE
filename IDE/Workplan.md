# UBE IDE workplan

This is the resumable implementation roadmap for the native UBE IDE. It turns
the accepted direction in `DESIGN.md` into ordered, verifiable work.

The phases are dependency-ordered. Later design exploration may begin early,
but implementation gates cannot be declared complete until their acceptance
criteria and safety tests pass.

## Status markers

- `[ ]` not started
- `[~]` in progress
- `[x]` complete and verified
- `[!]` blocked, with the decision or dependency recorded

## Current position

- [x] Establish the product vision and modern-classic direction.
- [x] Lock the central document workspace and edge-docked tool-window model.
- [x] Lock the Project Explorer's upper-right default position.
- [x] Require all tool windows to be movable, dockable, tabbed, auto-hidden,
  hidden, and floated.
- [x] Establish document-safety, source-fidelity, isolation, responsiveness,
  and graceful-degradation rules.
- [x] Import the compatible native-IDE, tooling, serialization, startup,
  migration, accessibility, recovery, packaging, and sample-distribution
  requirements already established elsewhere in the repository.
- [x] Lock semantic View Definition navigation for project and exact-version
  standard-library source.
- [x] Lock transactional project-local copy-on-write customization while
  preserving the canonical standard library.
- [x] Lock the dockable Registers tool window with exact paused snapshots and
  honestly labelled capability-dependent live sampling.
- [x] Lock external, versioned UTF-8 localization resources for normal
  user-facing text with deterministic fallback and a minimal built-in
  emergency vocabulary.
- [x] Complete and verify canonical implementation Step 1: the UBE-written
  headless project, document, undo, command, settings, locale, diagnostic,
  service-envelope, atomic-save, and recovery foundations pass their native
  verification suite with byte-identical repeated LLVM emission.
- [x] Complete Phase 0 by turning the accepted design into testable UX
  contracts in `UX-CONTRACTS.md`.
- [x] Complete and verify canonical implementation Step 2: the plain native
  shell, UBE-owned layout/localization policy, and narrow Win32 adapter.

## Canonical implementation and handoff sequence

This eight-step vertical slice is the default path from planning into
implementation. It complements the detailed phases below: the phases describe
the complete work, while this sequence defines the smallest useful order in
which agents should integrate and verify it.

Agents resume at the first incomplete step or sub-item. Before stopping, update
the handoff record below with the exact last verified checkpoint, files being
worked on, validation performed, known failures, and the next concrete action.
Do not mark a step complete because its components exist independently; its
end-to-end checkpoint must pass.

### Step 1: build the UI-independent foundations

- [x] Implement and test the project, workspace, document, command, undo,
  save, recovery, settings, service-protocol, and diagnostic foundations needed
  by the first vertical slice.
- [x] Keep these components independent of final colors, icons, control
  styling, and a particular arrangement of native widgets.
- [x] Implement the bounded locale-catalog loader, fallback resolution, typed
  formatting, validation, and minimal emergency-message path before UI
  components accumulate hard-coded text.

Checkpoint: headless tests can open a small project, edit a versioned document,
undo and redo, save atomically, recover interrupted work, and report controlled
errors without starting a graphical window.

### Step 2: create a plain native application shell early

- [x] Open one native main window with the central document workspace.
- [x] Add the accepted default docking regions and placeholder Project
  Explorer, Properties, and Output tool windows.
- [x] Prove menus, command routing, focus, keyboard navigation, accessibility,
  DPI scaling, floating windows, and multi-monitor recovery.
- [x] Use neutral temporary styling and text labels where finished assets do
  not yet exist; temporary text still comes from the source locale catalog.

Checkpoint: the shell reliably starts, docks and floats placeholder tools,
remains keyboard-operable, and recovers from corrupt or off-screen layout data.

### Step 3: connect one real document end to end

- [x] Open one real UBE source document through the workspace model.
- [x] Connect editing, dirty state, undo/redo, external-change detection,
  atomic saving, close behavior, and crash recovery.
- [x] Ensure docking, closing, or recreating its view never loses the document
  buffer or undo history.

Checkpoint: a synthetic interruption at every save and close boundary retains
the last good file or a usable recovery copy.

### Step 4: prove the accepted workspace with real state

- [x] Replace the placeholder Project Explorer with the real ordered project
  model.
- [x] Connect a minimal real Properties view and bounded Output stream.
- [x] Verify moving, grouping, hiding, auto-hiding, floating, restoring, and
  resetting these tools while the document remains active and unchanged.

Checkpoint: one real project survives a complete layout-customization and
restart cycle without source changes, lost tools, invalid focus, or off-screen
windows.

### Step 5: connect one compiler and navigation path

- [x] Run one real compiler or language-service request out of process.
- [x] Display one diagnostic with correct source navigation.
- [x] Resolve and execute one semantic View Definition operation.
- [x] Include one exact-version `UBECore` definition when the required source
  identity is available.

Checkpoint: editing a document produces a version-matched diagnostic and View
Definition reaches the compiler-resolved declaration; stale, failed, or
cancelled requests do not disturb editing.

### Step 6: validate the architectural risks

- [ ] Exercise keyboard-only use, accessibility exposure, mixed DPI,
  multi-monitor changes, service failure, malformed input, cancellation,
  low-memory behavior, and the agreed performance budgets.
- [ ] Fix architectural failures before expanding the number of screens or
  tools.

Checkpoint: the first vertical slice passes its accessibility, recovery,
never-crash, responsiveness, and platform-boundary gates.

### Step 7: freeze the initial visual system

- [ ] Complete Phase 3 colors, typography, spacing, metrics, and light, dark,
  and high-contrast design tokens using the proven shell.
- [ ] Complete the core Phase 4 icon family after the command inventory is
  stable.
- [ ] Replace temporary presentation through shared tokens and asset services,
  not control-specific constants.

Checkpoint: Code, Design, and Debug reference screens use the approved visual
system, pass contrast and scaling checks, and require no structural workaround
to achieve the design.

### Step 8: expand feature by feature

- [ ] Implement the remaining detailed phases using the proven foundations and
  approved visual system.
- [ ] Give each feature an end-to-end slice, failure tests, accessibility
  checks, performance limits, documentation, and a resumable handoff before
  beginning another large feature.

Checkpoint: each feature meets its detailed phase exit criteria; partial
features remain explicitly marked in progress and do not weaken completed
safety guarantees.

## Active implementation handoff

- **Current sequence step:** Steps 1 through 5 complete; Step 6 not started.
- **Last verified checkpoint:** On 2026-10-24,
  `IDE/UBE-IDE/tests/run-step5.ps1` built the UBE-written language service and
  integration model with Compiler v3 RP8 and Clang 23, passed 30 assertions
  across diagnostics, project and exact-identity `UBECore` navigation, stale,
  cancelled, failed, and malformed results, and produced byte-identical
  service LLVM at SHA-256
  `8E29462216FF69D2E12B5D71ACF03C37FD309B9189BC867786C82335D290E105`.
- **Active files:** None.
- **Validation performed:** edited document versioning, out-of-process request
  execution, navigable diagnostics, bounded Output display, case-insensitive
  semantic declaration resolution, exact `UBECore` source identity, stale
  rejection, cancellation, controlled failure, malformed protocol rejection,
  and deterministic emission.
- **Known failures or blockers:** none for Step 5. The C process transport is a
  documented temporary boundary because RP8 still diagnoses arbitrary foreign
  imports and callbacks rather than lowering them; state and safety policy
  remain in UBE.
- **Next concrete action:** Start Step 6 with service crash/hang/restart and
  keyboard/accessibility risk validation across the complete vertical slice.

## Phase 0: requirements and UX contracts

Purpose: define what users must be able to accomplish before selecting UI
implementation details.

- [x] Write representative workflows for creating, opening, editing, saving,
  building, running, debugging, designing, importing, and recovering projects.
- [x] Define beginner, experienced VB6 user, keyboard-only user, screen-reader
  user, large-project user, and multi-monitor user scenarios.
- [x] Inventory all initial documents, tool windows, commands, menus, and
  context menus.
- [x] Include View Definition, View Original Library Definition, project-local
  customization, and Registers workflows in the command and context-menu
  inventory.
- [x] Define command names, enablement rules, default shortcuts, cancellation,
  progress, and error behavior.
- [x] Inventory every initial user-facing string category and define stable
  semantic localization-key naming rules.
- [x] Select and document the dependency-free UTF-8 locale file grammar,
  versioning, fallback, placeholders, plural/selection, accelerator, escaping,
  limits, and validation behavior.
- [x] Define document dirty-state, external-change, close, reload, recovery,
  and conflicting-save state machines.
- [x] Define measurable startup, typing, docking, build-feedback, and memory
  budgets for representative hardware.
- [x] Derive malformed-input and service-failure scenarios from the
  repository-wide never-crash rule.

Exit criteria: every initial workflow has a short written scenario, expected
result, failure behavior, and owner-approved scope. No colors or finished icons
are selected in this phase; grayscale diagrams keep attention on structure.

## Phase 1: information architecture and grayscale interaction design

Purpose: validate organization and behavior before committing to visual polish.

- [ ] Produce grayscale wireframes for Code, Design, Debug, and recovery
  workflows at normal and compact window sizes.
- [ ] Validate the accepted default layout with Project Explorer upper-right,
  Properties/Events lower-right, Toolbox left, and bottom tool tabs.
- [ ] Specify docking targets, tab grouping, splitting, auto-hide, floating,
  keyboard movement, placement previews, and Reset Layout behavior.
- [ ] Specify central document groups, tab overflow, document switching, and
  unsaved-state presentation.
- [ ] Test layouts for one monitor, multiple monitors, monitor removal, mixed
  DPI, and constrained screen sizes.
- [ ] Specify focus order and screen-reader names for the complete default
  workspace.
- [ ] Conduct an owner review and record accepted corrections in `DESIGN.md`.

Exit criteria: the primary workflows and all docking transitions are
understandable in grayscale, work without relying on color, and have an
approved default hierarchy.

## Phase 2: native UI and platform feasibility

Purpose: prove the native implementation boundary before building the full
interface.

- [x] Establish the supported initial Windows versions, DPI modes, input
  methods, accessibility interfaces, and native window behavior.
- [x] Decide which UI facilities are UBE-owned and which use narrow operating-
  system adapters.
- [x] Prototype one main native window, one central document, two docked tool
  windows, and one floating tool window.
- [~] Prove docking and floating across mixed-DPI monitors without lost or
  off-screen windows. Per-monitor-v2 setup, `WM_DPICHANGED`, floating repair,
  and monitor removal are automated; a physical mixed-DPI hardware pass remains
  part of release qualification.
- [x] Prove keyboard focus, screen-reader exposure, resize behavior, and native
  menu integration.
- [~] Measure startup, resize, redraw, docking, and idle resource use. The
  automated shell startup-and-check budget is enforced now; detailed tracing
  and idle working-set baselines remain for the release-like prototype.
- [x] Document the platform boundary and controlled behavior when an OS call
  or resource allocation fails.

Exit criteria: a disposable native prototype demonstrates that the accepted
window model is practical, responsive, accessible, and portable behind narrow
interfaces. Prototype code is not promoted merely because it works once.

## Phase 3: visual identity, colors, typography, and metrics

Purpose: define the visual system after layout behavior is proven and before
production controls multiply.

- [ ] Choose the UBE IDE's visual personality within the accepted modern-
  classic direction.
- [ ] Define semantic color roles before choosing literal values: canvas,
  panel, editor, text, muted text, border, selection, focus, diagnostic,
  success, warning, error, and debug-state roles.
- [ ] Design and test coordinated light, dark, and high-contrast palettes.
- [ ] Verify contrast for normal text, disabled text, selections, focus rings,
  diagnostics, syntax highlighting, and overlapping debugger states.
- [ ] Select UI and editor typography with explicit fallbacks and license
  review. Do not require a downloaded font.
- [ ] Test representative short, long, bidirectional, and fallback-font strings
  while establishing control metrics; avoid fixed sizes derived only from
  English labels.
- [ ] Define spacing, border, corner, shadow, animation, toolbar, tree-row,
  tab, and status-bar metrics at supported scale factors.
- [ ] Define syntax-highlight categories only after mapping them to compiler
  token and semantic categories.
- [ ] Produce representative polished mockups for Code, Design, and Debug.
- [ ] Obtain owner approval and freeze visual tokens for initial implementation.

Exit criteria: named design tokens and reference mockups cover every standard
state in all three presentations, pass accessibility checks, and can be
implemented without control-specific color constants.

This is the main palette and typography decision point. It is deliberately
after interaction validation, so colors do not conceal structural problems,
and before production UI construction, so visual consistency is not retrofitted.

## Phase 4: iconography and visual assets

Purpose: create a coherent icon language after the command and tool inventory
is stable.

- [ ] Define icon geometry, stroke/fill rules, optical alignment, padding,
  active/disabled states, and supported native sizes.
- [ ] Design the core navigation and workflow set first: New, Open, Save,
  Undo, Redo, Build, Run, Pause, Stop, Step, Search, Code, Design, Project,
  Properties, Toolbox, Problems, Output, and docking controls.
- [ ] Test icons at actual toolbar, tree, tab, high-DPI, light, dark, and
  high-contrast sizes.
- [ ] Ensure meaning is not conveyed by color alone and ambiguous icons have
  text labels or accessible names.
- [ ] Create the application icon and required packaged sizes after the visual
  direction and core icon family are approved.
- [ ] Record authorship, license, source format, generated formats, and the
  deterministic asset-generation procedure.
- [ ] Add specialized designer, debugger, resource, and importer icons only as
  those feature inventories become stable.

Exit criteria: the core original icon set is approved, accessible, crisp at
supported sizes, stored in the repository, and reproducibly exportable without
network access.

Icon work begins after Phase 3 and the Phase 0 command inventory. Specialized
icons are intentionally designed alongside their feature rather than guessed
years in advance.

## Phase 5: application, command, settings, and layout foundations

- [x] Create `IDE/UBE-IDE/` with local agent guidance, design, workplan,
  source, tests, and a documented build entry point.
- [x] Implement the native application lifecycle without panic paths.
- [x] Implement the central command registry used by menus, toolbars,
  shortcuts, context menus, and automation-safe tests.
- [x] Implement versioned external locale catalogs, deterministic fallback,
  named typed placeholders, translation diagnostics, safe live development
  reload if practical, and the minimal built-in emergency catalog.
- [ ] Add checks that reject newly hard-coded normal user-facing strings in
  production UI code where practical.
- [x] Implement versioned settings with validation, migration, safe defaults,
  atomic writes, and corrupt-settings recovery.
- [~] Implement docking, floating, tab groups, splits, auto-hide, keyboard
  control, placement previews, and Reset Layout.
- [ ] Implement named Code, Design, Debug, and Custom layout handling without
  unrequested automatic rearrangement.
- [ ] Add synthetic tests for corrupt layouts, missing monitors, mixed DPI,
  invalid bounds, allocation failures, and interrupted settings writes.

Exit criteria: the empty shell starts reliably, all accepted layout operations
work, corrupted state cannot block startup, and layout regression tests pass.

## Phase 6: workspace, documents, undo, save, and recovery

- [ ] Implement `.UBE` and `.UBG` workspace loading with ordered inputs and
  controlled diagnostics.
- [~] Implement document identities, dirty state, shared buffers, views,
  versioning, undo/redo, and external-change detection.
- [~] Implement atomic text saving and transactional paired source/`.UBR`
  saving or recovery journals.
- [ ] Preserve unknown project keys, designer metadata, comments, ordering,
  spelling, encoding rules, and unedited text.
- [~] Implement periodic recovery copies, abnormal-exit detection, comparison,
  selective restoration, and safe cleanup.
- [~] Test full disks, permission failures, truncated files, conflicting
  changes, interrupted writes, corrupt recovery data, and close/reload paths.

Exit criteria: no covered failure loses the last good on-disk version or an
available recovery copy, and unedited files round-trip byte-for-byte.

## Phase 7: project explorer and code editor

- [~] Implement the Project Explorer using manifest order and explicit project
  and project-group structure.
- [ ] Implement project/file creation, inclusion, exclusion, rename, reorder,
  and deletion workflows with previews of affected files.
- [ ] Implement the editor buffer, selections, multi-level undo, scrolling,
  indentation, line endings, clipboard behavior, and large-file limits.
- [ ] Add compiler-aligned lexical presentation and syntax highlighting using
  the approved visual tokens.
- [ ] Implement split document groups, tab navigation, recent documents,
  bookmarks, Find, Replace, and Find in Files.
- [ ] Meet typing-latency, accessibility, input-method, and large-file gates.

Exit criteria: real multi-file projects can be navigated and edited quickly
without requiring compiler services to remain available.

## Phase 8: language intelligence

- [~] Define a versioned, bounded language-service protocol. Step 5 freezes
  the first diagnostic and definition request/result slice.
- [ ] Define documented compiler APIs for syntax trees, semantic queries, and
  refactoring without exposing mutable compiler internals.
- [~] Add live diagnostics, completion, signature help, hover, navigation,
  references, symbol search, rename, and formatting as compiler APIs mature.
- [~] Implement View Definition from compiler-resolved symbol identity and
  exact source range, including project references and the selected `UBECore`
  source identity.
- [ ] Package or otherwise make available the exact standard-library source
  corresponding to each supported library artifact without runtime downloads.
- [ ] Open library definitions in clearly identified immutable editor views and
  provide navigation back to callers and to overridden originals.
- [ ] Implement project-local customization as an atomic source-plus-manifest
  transaction using ordinary current-package name precedence.
- [ ] Compute and preview the complete declaration dependency closure; copy the
  owning module instead when declaration-level isolation is unsafe.
- [ ] Record upstream package, version, interface hash, symbol, and source hash
  and provide upgrade comparison without automatic replacement.
- [ ] Test ambiguous names, stale results, private dependencies, module state,
  initialization, type identity, unavailable source, intrinsics, failed
  writes, undo, removal, and library upgrades.
- [ ] Implement dependency-aware incremental analysis and compilation with a
  deterministic full-rebuild fallback and equivalence tests.
- [ ] Keep lightweight presentation separate from authoritative semantic
  results.
- [~] Implement document-version cancellation and stale-result rejection.
- [ ] Restart a failed service without losing documents or blocking editing.
- [ ] Test malformed messages, huge result sets, crashes, hangs, cancellation,
  rapid edits, and incompatible protocol versions.

Exit criteria: language features agree with compiler behavior and fail by
temporarily removing assistance, never by disabling editing or losing work.

## Phase 9: build, run, problems, and output

- [ ] Integrate `.UBE`/`.UBG` build orchestration through documented compiler
  interfaces.
- [~] Implement Problems and Output with stable diagnostic identity, source
  navigation, bounded storage, copying, and export.
- [ ] Implement Build, Rebuild, Clean, Run, Stop, and target/configuration
  selection with explicit source-version behavior.
- [ ] Implement `StartupForm` as project configuration that participates in
  the specified generated startup sequence and never replaces or invents an
  alternative to the source `Main` entry point.
- [ ] Add discoverable project-creation or sample-browser entries for the
  completed sample programs required by `../Owner-ideas.md`, without making
  the IDE responsible for silently downloading sample content.
- [ ] Isolate compiler and user-process failures from the IDE.
- [ ] Add progress, cancellation, process-tree cleanup, output throttling, and
  controlled handling of missing or incompatible tools.

Exit criteria: users can build and run real projects while retaining a
responsive editor through failed, cancelled, or excessive-output builds.

## Phase 10: visual form, control, property, event, and resource design

- [ ] Define the lossless editable subset for `.frm` and `.ctl` designer
  metadata and safe behavior outside that subset.
- [ ] Implement Toolbox, design surface, selection, movement, resizing,
  alignment, z-order, containment, and keyboard manipulation.
- [ ] Implement Properties and Events using authoritative component metadata.
- [ ] Connect event creation and navigation to source without duplicating or
  silently rewriting handlers.
- [ ] Implement named `.UBR` entry viewing, importing, replacement, removal,
  validation, hashing, and transactional saving.
- [ ] Add undo/redo transactions spanning designer, properties, source, and
  resource changes.
- [ ] Test unknown metadata, corrupt resources, missing entries, write failure,
  unsupported controls, and designer crashes.

Exit criteria: users can design a real form and control, round-trip its files
without unrelated changes, and recover safely from every tested interruption.

## Phase 11: source-level debugging

- [ ] Define a versioned, bounded debugger-adapter protocol.
- [ ] Implement launch, attach if supported, pause, continue, stop, stepping,
  breakpoints, stack traces, Locals, Watches, and Immediate evaluation.
- [ ] Add a target-described register model covering names, groups, widths,
  encodings, availability, and debugger read capabilities.
- [ ] Implement the dockable Registers grid for the selected process, thread,
  and frame with exact paused snapshots, changed-value indication, filtering,
  copying, and accessible non-color state cues.
- [ ] Implement capability-dependent **Live (sampled)** refresh with explicit
  sample age, bounded update rate, cancellation, and no undisclosed suspension
  of the debuggee.
- [ ] Represent stale, unavailable, unreadable, and architecture-specific
  values explicitly; never substitute plausible-looking values.
- [ ] Define source mapping and user presentation for optimized and inlined
  code.
- [ ] Prevent stale debug state from being presented as current.
- [ ] Isolate debuggee and adapter termination, hangs, and excessive output.
- [ ] Verify debugging without automatic workspace rearrangement; offer the
  Debug layout as an explicit action or opt-in preference.
- [ ] Test architecture changes, thread/frame switching, rapid stepping,
  process exit, adapter failure, oversized vector sets, sampling overload, and
  unsupported live-register targets.

Exit criteria: source-level debugging works end to end and debugger failure
cannot terminate the IDE or corrupt source.

## Phase 12: VB6 import and migration

- [ ] Inventory supported `.vbp`, `.vbg`, `.frm`, `.frx`, `.ctl`, and `.ctx`
  inputs and establish legal test fixtures.
- [ ] Implement import as a separate, repeatable operation that never modifies
  the original project.
- [ ] Produce native UBE project, source, and named-resource formats.
- [ ] Generate a migration report distinguishing converted, approximated,
  unsupported, and manually required work.
- [ ] Test malformed, partial, unusually encoded, and hostile inputs.

Exit criteria: supported projects import repeatably with no silent loss and
unsupported content remains visible in the migration report.

## Phase 13: integration, accessibility, localization, and resilience

- [ ] Complete keyboard navigation, screen-reader semantics, scaling, reduced
  motion, light, dark, and high-contrast verification.
- [ ] Complete translation catalogs and test long translations, bidirectional
  text where supported, fallback fonts, plural/selection cases, accelerator
  collisions, malformed catalogs, missing keys, and missing locale files.
- [ ] Generate translator-facing coverage reports for unused, missing,
  duplicate, changed, and placeholder-incompatible entries.
- [ ] Run long-session, low-memory, full-disk, service-crash, large-project,
  multi-monitor, suspend/resume, and settings-upgrade tests.
- [ ] Verify all icons and visual states at supported scale factors and themes.
- [ ] Profile startup, typing, indexing, layout, build, design, and debug
  workflows against the Phase 0 budgets.
- [ ] Perform a complete data-loss and panic-path audit.

Exit criteria: accessibility, localization, performance, recovery, and
never-crash release gates pass on every supported host configuration.

## Phase 14: packaging and release qualification

- [ ] Define portable and installed packaging, file associations, side-by-side
  versions, settings migration, repair, and uninstall behavior.
- [ ] Finalize the application icon and package assets in every required size.
- [ ] Package the compiler, language service, debugger, documentation, and
  required repository-owned assets without runtime downloads.
- [ ] Sign release artifacts where applicable and publish checksums and build
  provenance.
- [ ] Test clean install, upgrade, downgrade handling, repair, offline use,
  removal, and first-run recovery.
- [ ] Publish user, accessibility, keyboard, designer, debugger, migration,
  troubleshooting, and recovery documentation.

Exit criteria: a supported machine can install or unpack UBE, create, design,
edit, compile, run, and debug a real application entirely through the native
IDE, with reproducible and auditable release artifacts.
