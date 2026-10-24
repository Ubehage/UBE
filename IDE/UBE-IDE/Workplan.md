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

## Handoff

- **Current checkpoint:** Steps 1 through 3 complete and verified on 2026-10-24.
- **Generated output:** `out/` only.
- **Verification commands:** `tests/run-step1.ps1`, `tests/run-step2.ps1`, and
  `tests/run-step3.ps1`.
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
- **Next action:** begin Step 4 by replacing the Project Explorer placeholder
  with the real ordered project model, then connect minimal Properties and
  bounded Output views without moving ownership into the native adapter.
