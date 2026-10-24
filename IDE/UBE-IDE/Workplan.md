# UBE IDE application workplan

Status markers: `[ ]` pending, `[~]` active, `[x]` verified, `[!]` blocked.

## Step 1: headless foundation

- [x] Implement bounded project/workspace loading.
- [x] Implement document state, whole-buffer editing, and undo/redo.
- [x] Implement atomic save and recovery publication through a narrow adapter.
- [x] Implement command registration and enablement.
- [x] Implement versioned settings and locale catalogs.
- [x] Implement diagnostics and versioned synthetic service envelopes.
- [x] Verify malformed input, failed publication, stale messages, recovery,
  and the complete open/edit/undo/redo/save flow.

## Step 2: plain native application shell

- [x] Record the Phase 0 interaction, command, localization, safety, and
  performance contracts in `../UX-CONTRACTS.md`.
- [x] Implement validated versioned layout state and localized shell
  configuration in UBE.
- [x] Open a Unicode Win32 main window with a central document workspace.
- [x] Dock Project Explorer and Properties on the right and Output at the
  bottom by default; hide, reopen, float, move, dock, and reset them.
- [x] Prove native menus, accelerators, focus traversal, standard-control
  accessibility, resize, per-monitor DPI handling, and off-screen recovery.
- [x] Keep the OS adapter narrow and keep all generated output in `out/`.
- [x] Verify corrupt layout recovery, malformed adapter input, deterministic
  LLVM emission, and controlled native failure.

## Step 3: one real document end to end

- [x] Open a real UBE source file through the bounded document model and show
  it in an editable native center view.
- [x] Keep buffer, dirty/version state, undo/redo, view lifetime, close policy,
  external-change detection, recovery, and save decisions in UBE.
- [x] Add a bounded, versioned document-session bridge with stable document
  identity and stale-result rejection.
- [x] Checkpoint native edits atomically for recovery and use RP8's durable
  temporary-file-and-replace publication for source saves.
- [x] Verify view detach/recreation, explicit Save/Discard/Cancel behavior,
  every recovery-first save boundary, external conflicts, malformed input,
  native edit/undo/redo/recreation, and deterministic emission.

## Step 4: accepted workspace with real state

- [x] Render the manifest's exact ordered source list through the real UBE
  project model in Project Explorer.
- [x] Connect selection-driven project/source Properties and a UTF-8-validated,
  bounded Output buffer with explicit drop accounting.
- [x] Persist docked, floating, hidden, and auto-hidden tool modes plus group,
  order, bounds, and repaired focus through the UBE-owned layout model.
- [x] Verify a two-launch customize/restore/reset cycle without changing the
  active source document.

## Step 5: compiler and navigation path

- [x] Run a bounded UBE-written language service outside the IDE process with
  versioned, atomically published request and result files.
- [x] Apply one unresolved-name diagnostic only when its request and document
  versions match, and retain its exact source-navigation range in Output.
- [x] Resolve View Definition semantically to a project declaration.
- [x] Resolve `StringIsEmpty` to the exact selected `UBECore` 0.1.0-rp1 source
  and refuse a mismatched source identity.
- [x] Verify stale, malformed, cancelled, and failed results do not disturb
  editing.

## Handoff

- **Current checkpoint:** Steps 1 through 5 complete and verified on 2026-10-24.
- **Generated output:** `out/` only.
- **Verification commands:** `tests/run-step1.ps1` through
  `tests/run-step5.ps1`.
- **Verified Step 3 behavior:** 45 UBE model assertions pass; a real UBE source
  opens in the editable native center view; native edit, undo, redo, and view
  recreation preserve its contents; UBE validates the returned version and
  identity, saves it atomically, and removes completed recovery/session files.
  Malformed adapter configuration fails in a controlled path. Repeated RP8
  LLVM emission is byte-identical at SHA-256
  `E1B69293B0446DF343AC77C7EA41462AE2C3AE657C987B7E0979343670BCA06B`.
- **Measured shell checks:** the Step 3 real-document shell completed in 241 ms;
  inherited Step 2 normal, corrupt-layout, and off-screen checks completed in
  201 ms, 130 ms, and 132 ms on the verification host.
- **Toolchains:** Compiler v3 RP8 for Step 3, preserved Compiler v3 RP7
  compatibility gates for Steps 1 and 2, Clang 23 for generated UBE LLVM, and
  the repository's existing MinGW GCC toolchain for the temporary C platform
  adapter on `x86_64-w64-windows-gnu`.
- **Expected diagnostic during testing:** the environmental-failure probe asks
  the runtime to publish beneath a missing directory and therefore emits one
  controlled `cannot open for writing` line to standard error. Steps 2 and 3
  finish with an intentional malformed-configuration probe that emits one
  controlled native-shell error with code 5.
- **Verified Step 4 behavior:** 31 UBE assertions pass for ordered project
  rendering, selection-driven properties, bounded output, layout commands,
  serialization, restore, and reset. Two native launches persist floating,
  hidden, auto-hidden, grouped, and moved tool state, then restore and reset it
  while the active source remains byte-identical. Repeated RP8 LLVM emission
  is byte-identical at SHA-256
  `35AA1D67844DA1F46F4DB4A84F863D13BE704F7E88739441FFFF37890F8632ED`.
- **Verified Step 5 behavior:** 30 UBE assertions cover a real edited document,
  out-of-process diagnostics, Output presentation and navigation, project
  definition resolution, exact-version `UBECore` resolution, identity mismatch,
  stale result, cancellation, service failure, and malformed protocol data.
  Repeated language-service LLVM emission is byte-identical at SHA-256
  `8E29462216FF69D2E12B5D71ACF03C37FD309B9189BC867786C82335D290E105`.
- **Next action:** begin Step 6 by exercising the architectural risk matrix,
  starting with language-service crash/hang recovery and keyboard/accessibility
  checks across the now-complete vertical slice.
