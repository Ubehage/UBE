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

## Handoff

- **Current checkpoint:** Steps 1 and 2 complete and verified on 2026-10-24.
- **Generated output:** `out/` only.
- **Verification commands:** `tests/run-step1.ps1` and `tests/run-step2.ps1`.
- **Verified Step 2 behavior:** 29 UBE model assertions pass; the UBE launcher
  and dependency-free Win32 adapter complete normal, corrupt-layout, and
  off-screen-layout checks; native MSAA exposure is queried; malformed adapter
  configuration fails in a controlled path; repeated Compiler v3 emission is
  byte-identical at SHA-256
  `72909EBE320D8AFB20013B3091B69BC3646E982BB84476B9BE5FB15938FF2FFF`.
- **Measured shell checks:** normal 203 ms, corrupt-layout recovery 129 ms,
  and off-screen recovery 160 ms on the verification host, all beneath the
  2,000 ms combined startup-and-check gate.
- **Toolchains:** preserved Compiler v3 RP7, Clang 23 for generated UBE LLVM,
  and the repository's existing MinGW GCC toolchain for the temporary C
  platform adapter on `x86_64-w64-windows-gnu`.
- **Expected diagnostic during testing:** the environmental-failure probe asks
  the runtime to publish beneath a missing directory and therefore emits one
  controlled `cannot open for writing` line to standard error. Step 2's final
  malformed-configuration probe likewise emits one controlled native-shell
  error with code 5.
- **Next action:** begin Step 3 by connecting one real UBE source document to
  the center workspace while the UBE document model retains buffer, dirty,
  version, undo, save, external-change, and recovery ownership.
