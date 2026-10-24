# UBE IDE interaction contracts

**Status:** accepted implementation baseline for Steps 1 and 2  
**Presentation:** structural only; colors, final typography, and finished icons
remain deliberately undecided

This document turns the accepted IDE design into testable user outcomes. It
defines behavior and failure handling, not a final visual treatment.

## Representative users and environments

- A beginner can create or open a project, find its files, edit, build, run,
  and understand the next action without first configuring the workspace.
- An experienced VB6 programmer finds the direct menu/keyboard workflow,
  Project Explorer, Properties, Events, Toolbox, Immediate window, and visual
  designer familiar without inheriting unsafe VB6 behavior.
- A keyboard-only user can reach every document, tool, command, docking
  action, and confirmation. F6 cycles panes; menus and the command service
  provide paths that do not require dragging.
- A screen-reader user receives native roles, names, state, focus, selection,
  and error text. Reading order follows the logical workspace, not pixel
  position.
- A large-project user can continue typing and saving while bounded services
  index, build, search, or restart outside the UI thread.
- A multi-monitor user can float tools at different scale factors. Disconnecting
  a display or changing DPI brings every required window back on-screen without
  discarding the saved logical arrangement.

The representative baseline machine is a four-core x64 computer from 2018,
8 GiB RAM, an ordinary SATA SSD, integrated graphics, and a 1920x1080 display.
The large-project fixture is 1,000 source files and 250,000 source lines.

## Primary workflows

Each workflow has the same safety rule: cancellation or failure leaves the
last good files and any available recovery copy intact.

| Workflow | Successful result | Controlled failure |
| --- | --- | --- |
| Create | Choose a template, name and location; preview files; create and open the project. | Invalid names, collisions, permissions, or partial creation identify affected paths and offer retry or cleanup. |
| Open | Select `.UBE` or `.UBG`; preserve source order and unknown fields; restore a validated layout. | Malformed manifests open diagnostics without crashing; unsafe layout data falls back to the accepted default. |
| Edit and save | Edit a versioned document, undo/redo, and atomically publish exact intended text. | External changes, full disks, and access failures preserve both unsaved memory and the previous disk file. |
| Build | Build the explicitly identified project and source versions in an isolated process; stream bounded progress and diagnostics. | A compiler crash, timeout, corrupt message, or cancellation leaves editing and saving available. |
| Run | Save or explicitly choose the last successful build, then start it outside the IDE process. | Start failure reports the executable and cause; the IDE remains responsive. |
| Debug | Start or attach, pause, step, inspect frames and exact paused registers, then stop or detach. | Adapter or target failure terminates only that session and marks stale data explicitly. |
| Design | Open a form/control in the center, edit owned metadata, switch to code, and save source plus `.UBR` transactionally. | Unsupported or unsafe metadata is preserved and offered as text rather than guessed. |
| Import VB6 | Scan first, preview conversions and unsupported features, then write a new UBE project with a migration report. | The source VB6 project is never modified; partial output is recoverable or removable. |
| Recover | Detect abnormal exit, compare recovery copies with disk, and restore selected documents as unsaved edits. | Corrupt recovery entries are isolated; valid entries remain available. |
| Navigate definition | Resolve a symbol through compiler services and open the exact project or matching library-source definition. | Unresolved, ambiguous, stale, or unavailable definitions explain the condition and never guess. |
| Customize library source | Preview the safe semantic unit, copy it locally with provenance, update the manifest transactionally, and apply the edit there. | Intrinsics, unavailable source, or incomplete dependency closures remain read-only with an explanation. |
| Inspect registers | Show exact paused values for the selected process/thread/frame; label supported running samples as `Live (sampled)`. | Stale, unavailable, unreadable, and unsupported values remain distinct and never appear as invented zeroes. |

## Initial surface inventory

Central documents are source editor, form designer, control designer, project
settings, resource editor, migration report, recovery comparison, library
source, and read-only generated/diagnostic detail views.

Tool windows are Project Explorer, Toolbox, Properties, Events, Problems,
Output, Immediate, Search, Call Stack, Locals, Watches, Registers,
Breakpoints, and debug-session state. Every tool has Show, Hide, Dock, Float,
Move, Resize, tab-group, auto-hide, and Reset Layout paths in the complete IDE.
Step 2 implements the shared shell behavior with Project Explorer, Properties,
and Output placeholders before specialized content is added.

Top-level menus are File, Edit, View, Project, Build, Debug, Tools, Window, and
Help. A menu may stay absent until it has an implemented command, but command
identity is stable and does not depend on its current menu position.

The initial command families are:

- File: New Project, New File, Open Project/Group/File, Close, Save, Save As,
  Save All, Import VB6, Recent, Exit.
- Edit: Undo, Redo, Cut, Copy, Paste, Delete, Select All, Find, Replace, Find in
  Files, Go To Line, View Definition, View Original Library Definition,
  Customize Library Definition.
- View: Code, Designer, each initial tool window, Next/Previous Document,
  Command Search, Full Screen.
- Project: Add/Remove/Rename/Reorder Item, References, Resources, Properties,
  Set Startup Form, Fork Library Module/Project.
- Build and Run: Build, Rebuild, Clean, Cancel Build, Run, Run Without Build.
- Debug: Start/Continue, Pause, Stop, Restart, Step Into/Over/Out, Run to
  Cursor, Toggle Breakpoint, Quick Watch, Add Watch, selected process/thread/
  frame, register display mode.
- Window: Focus Next/Previous Pane, Dock/Float/Move/Resize active tool,
  auto-hide, close tool, Code/Design/Debug/Custom layouts, Save Layout, Reset
  Layout.
- Tools and Help: Settings, keyboard mapping, localization diagnostics, sample
  browser, documentation, report issue, About.

Editor context menus use the same Cut/Copy/Paste, navigation, definition,
customization, breakpoint, watch, and search commands. Project Explorer menus
use the same project/file operations. Designer, property, output, diagnostic,
search-result, and debugger context menus expose only commands valid for the
selected semantic object. Context menus never contain a private implementation
of a command.

## Command contract

Every command has a stable dotted identifier, locale label key, enablement
predicate, execution result, cancellation policy, and optional default
shortcut. Menus, toolbar buttons, shortcuts, context menus, accessibility, and
tests route through that single identity.

The initial global shortcuts are Ctrl+N New, Ctrl+O Open, Ctrl+S Save,
Ctrl+Shift+S Save All, Ctrl+Z Undo, Ctrl+Y Redo, Ctrl+F Find, Ctrl+H Replace,
F5 Start/Continue, Shift+F5 Stop, F9 Toggle Breakpoint, F11 Step Into, F10 Step
Over, Shift+F11 Step Out, F12 View Definition, Ctrl+Tab Next Document, F6 Focus
Next Pane, and Ctrl+Shift+R Reset Layout. A user mapping may replace them later;
conflicts are diagnosed rather than silently resolved.

A disabled command explains its unmet condition through accessible status or a
command query. Long commands return immediately to a cancellable progress
operation. Cancellation is an ordinary result, not an error. Failures name the
operation and affected project/document without exposing unbounded service
text or changing focus unexpectedly.

## Document safety state machines

A document is `Clean`, `Dirty`, `Saving`, `Save failed`, or `Recovery
available`. Disk identity is independently `Unchanged`, `Changed externally`,
or `Missing`.

- Editing moves Clean to Dirty and advances the document version.
- A successful atomic save moves the same version to Clean. Edits made while a
  save is pending remain Dirty.
- A failed save retains Dirty text, undo history, recovery data, and the last
  good disk file.
- External change plus Clean offers Reload or Keep Open. External change plus
  Dirty offers Compare, Save As, Reload/Discard with confirmation, or Cancel.
- Close of a Dirty or newer-recovery document offers Save, Don't Save with the
  exact affected document, or Cancel. Project/IDE close aggregates choices
  without hiding failures.
- Recovery restoration opens as Dirty and never silently overwrites disk.

## Localization contract

User-facing categories include menus, commands, tool/document titles, buttons,
prompts, status and progress, settings descriptions, tooltips, accessible
names/descriptions, diagnostics, recovery text, migration reports, and empty,
loading, unavailable, and error states.

Keys use semantic dotted names such as `Command.File.Save`,
`Tool.ProjectExplorer.Title`, and `Diagnostic.IDE4101`. They never encode a
screen coordinate. English is complete; fallback is deterministic. The exact
UTF-8 grammar, doubled-quote escaping, named typed placeholders, brace rules,
limits, and validation behavior are defined in
`UBE-IDE/resources/locales/FORMAT.md` and implemented by the Step 1 loader.
Accelerators are part of localized labels and collisions must be reported.
Plural and selection forms will extend the versioned grammar before strings
that require them ship; code may not synthesize English plural fragments.

## Performance budgets

Measured on the baseline machine in a release-like build:

- cold shell visible and keyboard-ready: at most 2,000 ms; warm: 1,000 ms;
- ordinary typing response at the 95th percentile: 16 ms for files through
  1 MiB, 50 ms through 10 MiB;
- docking preview: 50 ms; committed dock/float layout: 100 ms;
- first build acknowledgement/progress: 250 ms, independent of build duration;
- focus or menu command feedback: 100 ms;
- empty-shell idle CPU: below 1% after settling;
- empty-shell working set: 150 MiB maximum, with a 75 MiB target;
- layout/settings files: bounded by the shared 1 MiB text limit; service
  messages and output remain independently bounded.

A missed budget is recorded as a regression with the machine, fixture, and
measurement. Work is moved off the UI thread rather than concealing latency.

## Never-crash scenarios

Tests must cover invalid UTF-8, truncation, duplicate and unknown fields,
unsupported versions, oversized files/messages, corrupt layouts, off-screen
bounds, removed monitors, mixed DPI, invalid native handles, allocation and OS
call failures, inaccessible/full disks, interrupted atomic replacement,
service crash/hang/restart, stale replies, output floods, compiler/debuggee
crashes, malformed designer/resource data, file-watcher loss, suspend/resume,
and shutdown during active work.

The result is always a bounded diagnostic, a safe fallback, cancellation, or
isolation of the failed service. None may terminate the editor or discard the
last good user data.
