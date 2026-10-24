# Step 2 native platform boundary

**Initial host:** x64 Windows 10 version 1809 or newer, and Windows 11  
**Native API:** Win32 Unicode windows and standard controls  
**UI framework dependencies:** none

Step 2 proves the application-shell boundary without choosing final colors,
typography, icons, or a third-party UI toolkit.

## Ownership

UBE owns command identifiers and routing policy, validated versioned layout
state, localization lookup, settings and recovery publication, and all
UI-independent workspace/document behavior. The Windows adapter owns HWNDs,
the message loop, standard native controls, menu/accelerator binding, focus
transfer, actual monitor work areas, DPI notifications, and reparenting a tool
between child and top-level native windows.

The current Compiler v3 RP7 cannot yet lower arbitrary foreign declarations
and native callbacks. Therefore the UBE executable invokes the adapter through
the existing bounded `CompilerRunTool` bootstrap boundary. It supplies a
validated, localized shell configuration; the adapter returns only a bounded
layout snapshot; UBE validates and atomically publishes that snapshot. This is
a temporary transport limitation, not permission for native policy to spread.
When direct foreign calls and callbacks are available, the transport can be
replaced without changing the UBE layout, localization, command, or document
models.

## Proven native behavior

- One native top-level main window contains the central document workspace.
- Project Explorer and Properties dock on the right by default; Output docks
  along the bottom.
- Each placeholder can be hidden, reopened, floated as an owned top-level
  native window, moved by the operating system, and docked again. Reset Layout
  restores the accepted arrangement.
- File, Edit, View, Window, and Help menus route through one command handler.
  Ctrl+N/O/S/Z/Y, F6, and Ctrl+Shift+R use a native accelerator table.
- Standard EDIT controls, window titles, tab stops, native focus, and the
  system accessibility bridge expose roles/names/state to MSAA/UI Automation.
- Keyboard, mouse, touch-generated pointer compatibility, Unicode text entry,
  dead keys, and IME composition are delegated to standard Windows controls in
  this prototype; custom editor input handling must preserve those contracts.
- Per-monitor-v2 DPI awareness is requested dynamically with a system-DPI
  fallback. `WM_DPICHANGED` adopts the operating system's suggested bounds and
  rebuilds the system message font at the new scale.
- Saved rectangles are clamped to the nearest current monitor work area before
  display. Missing monitors and grossly off-screen data cannot strand a window.
- All ordinary visible text is supplied from the UTF-8 locale catalog by UBE.
  The C adapter contains only controlled emergency diagnostics for cases where
  configuration cannot be trusted.

## Failure boundary

Configuration parsing is UTF-8 strict, versioned, duplicate-free, and bounded
to 1 MiB, 128 entries, 96 UTF-16 code units per key, and 768 per value. Invalid
configuration exits with a nonzero status before creating the shell. Window,
menu, accelerator, font, COM/accessibility, file, conversion, allocation, and
monitor-query failures follow checked paths. The adapter writes a sibling
temporary result, flushes it, and atomically replaces the result file; UBE then
performs its own validation and atomic final publication.

No OS failure is allowed to mutate a document. The adapter never owns source
text, undo, compiler state, or the authoritative settings file.
