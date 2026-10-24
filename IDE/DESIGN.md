# UBE IDE design

**Status:** accepted project direction

This document records the established product design and architectural rules
for the UBE IDE. Decisions marked **Locked** are the approved baseline. They
may change only through an explicit owner decision recorded in this document
and reflected in `Workplan.md` when implementation is affected.

## Requirement provenance

Before this document, the repository established high-level IDE requirements
but did not establish a detailed layout, docking design, color system, icon
family, or implementation architecture. Those inherited requirements remain
binding:

- `../AGENTS.md` requires a native IDE with VB6-like ease of use and forbids
  Tauri, Electron, and webview shells.
- `../project-docs/Roadmap.md` requires project creation, editing, building,
  running, debugging, a code editor, form/control designers, Project Explorer,
  Properties, Toolbox, Immediate and debugger experiences, and integration
  with the compiler, build system, language service, and debugger.
- The project roadmap also requires dependency-aware incremental compilation,
  compiler APIs for syntax, semantic, and refactoring queries, stable designer
  serialization, atomic `.frm`/`.ctl` plus `.UBR` writes, startup-form support,
  VB6 migration, accessibility, localization, keyboard navigation, recovery,
  settings migration, large-project testing, native packaging, and signing.
- `../lang-doc/project-files.md` defines the source, project, group, resource,
  startup, ordering, path, preservation, and compatibility rules that IDE
  tooling must obey.
- `../Owner-ideas.md` requires thirteen sample programs to be distributed with
  the compiler and IDE. Their design is owned by that requirement; the IDE
  must make the completed samples easy to discover and open.

The center-workspace layout, Project Explorer's default right-side placement,
universal tool-window customization, named-layout behavior, and modern-classic
visual direction were established by the owner in the October 2026 IDE design
discussion and are locked here for the first time.

## Product vision

The UBE IDE is a fast, native development environment that combines the
immediacy and clarity of the classic Visual Basic 6 workflow with modern
safety, accessibility, debugging, and project-scale behavior.

The IDE is not intended to imitate Visual Studio or VS Code. Its defining
workflow is short and direct: create or open a project, edit code or visually
design a form, and build, run, or debug it without unnecessary configuration.

The desired character is:

- fast, calm, obvious, and trustworthy;
- compact without being cramped;
- friendly to beginners without hiding the real project structure;
- efficient for keyboard and multi-monitor users;
- native, offline-capable, dependency-minimal, and eventually written
  primarily in UBE;
- resilient enough that an IDE, compiler, designer, extension point, debugged
  program, malformed file, or corrupt setting cannot cost the user their work.

## Locked workspace design

**Locked:** The main working window occupies the center of the IDE. Tool
windows dock around its edges.

The default layout is:

```text
+-----------------------------------------------------------------+
| Menu and compact command toolbar                                |
+------------+-----------------------------------+----------------+
| Toolbox    |                                   | Project        |
|            |       Document workspace          | Explorer       |
|            |                                   +----------------+
|            |       Code / Form Designer        | Properties /   |
|            |                                   | Events         |
+------------+-----------------------------------+----------------+
| Problems | Output | Immediate | Debug | Search                  |
+-----------------------------------------------------------------+
| Build state | target | cursor position | encoding               |
+-----------------------------------------------------------------+
```

**Locked:** The Project Explorer is on the upper-right by default. Properties
and Events occupy the lower-right area. The Toolbox is on the left. Problems,
Output, Immediate, Debug, and Search share the bottom area.

The layout is a useful starting point, not a restriction on the user.

## Documents and tool windows

The IDE distinguishes two window roles:

- **Documents** occupy the central workspace. They include source files, form
  designers, control designers, project settings, and resource editors.
- **Tool windows** support the active work around the edges. They include the
  Project Explorer, Toolbox, Properties, Events, Problems, Output, Immediate,
  Search, and debugger views.

**Locked:** Every tool window can be moved, resized, hidden, shown, docked,
tabbed, auto-hidden, or floated. Tool windows are never permanently tied to a
particular edge.

The docking system must support:

- docking on any outer edge of the main window;
- horizontal and vertical splits with user-adjustable proportions;
- multiple tool windows grouped as tabs;
- reordering within tab groups;
- pinning and auto-hide edge tabs;
- native floating windows, including placement on another monitor;
- a clear placement preview before a dragged window is committed;
- keyboard-accessible docking, movement, resizing, and window activation;
- reopening every closed tool through the View menu or command system;
- restoring the accepted default through a Reset Layout command.

Moving a tool window must not change document contents, silently activate a
different document, or unexpectedly take keyboard focus from the editor.

Document tabs may be split into multiple central document groups. Whether
documents can later be torn into independent native windows is an open design
decision; documents must not be treated as ordinary edge-docked tool windows.

## Workspace layouts

The IDE will provide named starting layouts:

- **Code:** Project Explorer and Properties on the right with a compact bottom
  area.
- **Design:** Toolbox on the left, Project Explorer and Properties on the
  right, and the designer in the center.
- **Debug:** debugger tools and the Immediate window expanded along the
  bottom.
- **Custom:** user-saved arrangements.

**Locked:** Named layouts are starting points, not rigid operating modes. The
IDE must not rearrange a customized workspace merely because a build or debug
session starts. Automatic layout switching, if offered, is an explicit user
preference and is disabled by default.

Layout persistence records window state, dock site, tab group and order,
split proportions, active tool, floating bounds, monitor identity, and DPI.
Settings are validated before use. Missing monitors, changed DPI, corrupt
settings, unsupported versions, and off-screen bounds are repaired safely or
fall back to the default layout. Layout restoration must never prevent the IDE
from starting.

## Interaction principles

1. Common actions remain visible and require few steps.
2. Menus, toolbars, shortcuts, and context menus invoke the same command
   implementation and report the same result.
3. Advanced capabilities use progressive disclosure rather than complicating
   the default workspace.
4. Background activity never steals focus or silently rearranges windows.
5. Build, Run, and Debug clearly identify the project and source version being
   used.
6. Destructive actions identify the affected files before they execute.
7. Every mouse-driven workflow has an accessible keyboard path.
8. Color, icon shape, animation, or spatial position alone never carries
   essential meaning.

## User-work safety rules

The repository-wide never-crash rule applies particularly strongly to the IDE.
Unsaved work outranks UI state, caches, logs, indexes, and build products.

- A compiler, language-service, debugger, designer, imported file, or debugged
  program failure must not terminate the editor process.
- Recovery copies are written regularly and retained after abnormal exit.
- Saves use a temporary file and atomic replacement wherever the platform
  permits. Failure leaves the previous on-disk file intact.
- Paired `.frm`/`.ctl` and `.UBR` updates use a transaction or recovery journal
  so they cannot be left as a silently mismatched pair.
- The IDE explicitly accounts for modified documents before close, reload,
  project removal, or other operations that could discard changes.
- External file changes are detected. Unsaved local changes are never silently
  overwritten.
- Undo history is document-owned and cannot disappear because a view closes,
  floats, docks, or is recreated.
- Every crash or data-loss fix includes a small synthetic regression test that
  failed before the fix.

## Source and project fidelity

The formats in `../lang-doc/project-files.md` are authoritative.

- Opening and saving an unchanged document must not rewrite it.
- Unknown manifest keys and unknown designer metadata are preserved.
- Comments, ordering, original spelling, and formatting outside edited regions
  are retained wherever the format permits.
- The visual designer changes only metadata it understands and owns.
- If safe round-tripping cannot be guaranteed, the IDE explains the limitation
  and offers text editing instead of guessing.
- Generated content is deterministic and visible or clearly disclosed; it is
  never secretly inserted into user source.
- Project Explorer ordering reflects the significant order in `.UBE` and
  `.UBG` manifests and never silently sorts the build order.

## Component boundaries

The intended high-level structure is:

```text
Native IDE process
|- application shell and command service
|- workspace, documents, undo, save, and recovery
|- docking, layout, and window management
|- project explorer and project settings
|- code editor and form/control designer
|- build, run, and debug coordination
|- search, navigation, and tool-window views
`- narrow platform abstraction

Isolated services and child processes
|- UBE compiler and build tools
|- UBE language service
|- debugger adapter
`- program being run or debugged
```

The IDE should eventually be written primarily in UBE and exercise UBE's own
GUI facilities. Windows is the first implementation host. Platform-specific
behavior must remain behind narrow interfaces so future native front ends or
backends do not require rewriting workspace and editor logic.

The compiler, debugger adapter, and user program run outside the IDE process.
Their output is bounded and treated as untrusted input.

## Language and compiler authority

There is one authoritative UBE language implementation.

- Compiler services own syntax and semantic truth.
- The editor may use lightweight local scanning for immediate presentation,
  but it cannot issue authoritative semantic results from a separate language
  implementation.
- Diagnostics, completion, navigation, references, rename, formatting, and
  refactoring use documented compiler or language-service APIs.
- Requests and results carry document versions. Stale results are discarded.
- The editor remains usable while language services are unavailable or
  restarting.
- Language services and builds use dependency-aware incremental work where it
  is safe, while retaining a deterministic full-build path for verification.
- Syntax-tree, semantic-query, and refactoring interfaces are documented
  compiler APIs rather than access to compiler internals.

## Definition navigation and library-source customization

**Locked:** The code editor provides **View Definition** when the user invokes
the context menu on a resolved name. The same command is available from the
keyboard and other appropriate navigation surfaces. It navigates to the exact
definition of a procedure, constant, variable, type, member, property, event,
form, control, or other compiler-resolved symbol. For example, invoking it on
`InitCommonControls` opens the declaration that the compiler bound to that
use, not merely the first textual match.

Navigation uses semantic identity and source ranges supplied by compiler
services. It respects case-insensitive lookup, qualification, project
references, conditional compilation, generated mappings, and the source-
library version selected by the build. When a name is unresolved or ambiguous,
the command explains why rather than guessing.

**Locked:** Definitions in the UBE standard source library are navigable in
the same editor used for project source. The displayed source must correspond
to the exact selected `UBECore` source/interface identity; the IDE must not
quietly show a different installed or repository version. Library tabs are
visibly identified by package, version, and read-only origin.

**Locked:** Attempting to edit an eligible standard-library definition creates
a project-local customization and leaves the canonical standard library
unchanged. This is copy-on-write behavior:

1. The original library view is immutable.
2. On the first edit intent, the IDE determines the smallest complete semantic
   unit that can safely be customized.
3. The IDE previews the local file, declarations, dependencies, and manifest
   changes when the operation is not a trivial single-declaration copy.
4. It writes the local source and updates the project manifest as one
   recoverable transaction.
5. The editor moves to the local copy, preserves the selection and edit
   intent, applies the change, and clearly labels the document
   **Project-local customization**.
6. The original library definition remains available through a command such
   as **View Original Library Definition**.

An ordinary public procedure, constant, or type may be copied as one complete
declaration when it is semantically independent. Required private helpers,
module state, initialization, related type identity, conditional definitions,
or other inseparable context must be included in a visible dependency closure
or cause the complete owning module to be copied. The IDE never produces a
known-incomplete override merely to satisfy the requested edit.

The customization uses ordinary UBE name-resolution rules: accessible
declarations in the current project take precedence over declarations from a
direct referenced package. Fully qualified access to the original package
remains possible. The IDE does not secretly patch `UBECore`, alter a compiled
library bundle, or introduce a second runtime library identity. The local
declaration changes calls resolved from the consuming project; it does not
rewrite calls compiled inside `UBECore`. Changing library-internal behavior
requires the explicit module- or project-fork workflow.

If a symbol cannot be customized safely—such as a compiler intrinsic, a
target adapter unavailable as source, an incompatible library version, or an
unavailable dependency closure—the source remains viewable and the editor
provides a controlled explanation. A broader explicit **Fork Library Module**
or **Fork Library Project** workflow may be offered for cases where a local
declaration is insufficient.

Project-local customizations record their original package, module, semantic
version, interface hash, symbol identity, and source hash. The IDE can then
show whether a customization is current, whether its upstream definition has
changed, and a three-way comparison during library upgrades. It never replaces
customized code automatically.

## Register tool window

**Locked:** The debugger includes a dockable **Registers** tool window. It
obeys the same move, tab, auto-hide, floating, multi-monitor, persistence, and
Reset Layout rules as every other tool window.

The default presentation is a compact grid containing at least the register
name and value. It follows the selected debug process, thread, and stack frame,
groups registers according to the active target architecture, and may expose
hexadecimal, unsigned, signed, binary, floating-point, vector, flag, or decoded
views where meaningful. Changed values are highlighted without relying on
color alone. Users can filter registers and copy a name or value.

When execution is paused, displayed values are an exact debugger snapshot and
include the snapshot state and time. During stepping, the window refreshes and
compares against the preceding snapshot.

While the program is running, continuous display is capability-dependent.
Where the target can provide values without secretly suspending or materially
disturbing the program, the window may offer a configurable live refresh. It
must be labelled **Live (sampled)** with sample age and cannot imply that all
registers were observed simultaneously. If sampling would require hidden
pause/resume cycles or otherwise perturb execution, it is disabled by default
and any opt-in behavior explains the effect. Stale, unavailable, optimized-
away, architecture-specific, and unreadable values have distinct explicit
states rather than fabricated zeroes.

The first version is observational. Editing register values is a separate,
future debugger decision because it mutates the running program and requires
additional architecture, safety, and confirmation rules.

## Responsiveness and limits

- The UI thread does not compile, index projects, hash large files, wait for
  child processes, or perform unbounded file operations.
- Long operations expose progress and cancellation.
- Cancellation is ordinary behavior and leaves coherent state.
- File watching coalesces repeated events and handles event loss by safe
  reconciliation.
- Project inputs, layouts, protocol messages, designer metadata, and tool
  output have documented size and work limits.
- Performance gates cover startup, typing latency, layout changes, large files,
  large projects, low-memory behavior, and long debug sessions.

## Text and localization resources

**Locked:** Normal user-facing IDE text is stored outside program source in
versioned, repository-owned localization resources. This includes menus,
commands, tool-window titles, buttons, prompts, settings descriptions,
tooltips, status text, accessibility names and descriptions, IDE-owned
diagnostics, recovery messages, and other interface prose.

Locale resources are plain UTF-8 text in a documented, deterministic format.
They are checked into the repository, packaged with the IDE, usable offline,
and require no package manager, network service, registry lookup, or external
localization runtime. English is the canonical complete source locale. Other
locales declare their identity, compatible resource-format version, and
fallback chain explicitly.

Source code refers to stable semantic keys rather than English sentences. Keys
describe purpose and context, not screen coordinates or the current wording.
Renaming a command or moving a tool window therefore does not unnecessarily
invalidate translations.

Localized messages use named, typed placeholders. Program code must not build
sentences by concatenating translated fragments or assume English word order.
Plural, selection, accelerator, newline, quoting, and escaping behavior are
defined by the resource format rather than improvised by individual controls.
Untrusted placeholder contents cannot be interpreted as formatting syntax.

Locale loading is bounded and validated. Unknown keys may be retained by
translation tools, while duplicate keys, invalid encoding, malformed
placeholders, incompatible versions, invalid fallback cycles, and excessive
resource sizes produce controlled diagnostics. A missing translation falls
back deterministically and is visibly reportable in localization diagnostics;
it never becomes an unexplained empty label.

The IDE retains only a very small built-in emergency vocabulary needed to
report that localization resources are missing, corrupt, or incompatible and
to offer recovery or exit. This is an exception to the external-resource rule
so damage to a locale file cannot prevent an actionable startup. It is not a
second general-purpose English catalog.

Every layout must tolerate translated text expansion, different word order,
font fallback, and supported bidirectional presentation. Essential meaning is
never encoded solely in an icon, color, mnemonic, or untranslated technical
abbreviation. Compiler and debugger protocol identifiers remain stable and
untranslated; their user-facing explanations are localized at the
presentation boundary.

The exact file extension and grammar are deliberately selected during the UX
contract and foundation phases, before production interface strings are
introduced. The format must remain straightforward for human translators and
simple enough for UBE to parse safely without a third-party dependency.

## Visual identity direction

The detailed palette, typography, icon family, spacing scale, and control
metrics are intentionally not locked yet. They are scheduled in `Workplan.md`
after grayscale interaction prototypes validate the information hierarchy and
docking behavior, but before production UI components multiply.

The established visual direction is **modern classic**:

- compact, information-dense, and readable;
- restrained use of decoration and animation;
- strong visual hierarchy and unambiguous active/focus states;
- first-class light, dark, and high-contrast presentations;
- original, repository-owned assets with no runtime downloads;
- icons designed for small native toolbar and tree sizes, not merely scaled
  down from large illustrations.

Visual choices must meet accessibility contrast and scaling requirements. The
application icon and product identity must use the product name **UBE** and may
not make the IDE look like an unrelated product or a VB6-branded derivative.

## Initial built-in tools

The initial complete IDE includes:

- Project and project-group explorer;
- code editor;
- form and user-control designer;
- Toolbox;
- Properties and Events;
- Problems and build Output;
- Find in Files and symbol search;
- Immediate window;
- breakpoints, Call Stack, Locals, Watches, Registers, and debug controls;
- named `.UBR` resource browser/editor;
- project settings editor;
- sample-project browser or project-creation entry points for the completed
  repository sample set;
- VB6 project import with an explicit migration report;
- crash-recovery manager.

Object browsing, dependency visualization, profiling, binary-size analysis,
benchmarking, test exploration, accessibility inspection, and packaging may be
added later after their boundaries and value are demonstrated. The initial IDE
does not become a general-purpose collection of unrelated tools.

## Documentation structure

`IDE/DESIGN.md` owns IDE-wide accepted behavior. `IDE/Workplan.md` owns the
resumable IDE roadmap. The application will live in `IDE/UBE-IDE/`.

An accepted independently deliverable subsystem may receive its own folder,
`DESIGN.md`, `Workplan.md`, tests, and local `AGENTS.md`. An unaccepted idea
does not receive an empty folder merely for existing. Reader-facing material
belongs in `README.md`; internal architecture belongs in `DESIGN.md`.
