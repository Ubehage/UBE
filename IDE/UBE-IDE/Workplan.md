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

## Handoff

- **Current checkpoint:** Step 1 complete and verified on 2026-10-24.
- **Generated output:** `out/` only.
- **Verification command:** `tests/run-step1.ps1`.
- **Verified behavior:** 53 headless assertions pass; repeated Compiler v3
  emission is byte-identical; the native executable passes with Clang 23 on
  `x86_64-w64-windows-gnu`.
- **Expected diagnostic during testing:** the environmental-failure probe asks
  the runtime to publish beneath a missing directory and therefore emits one
  controlled `cannot open for writing` line to standard error.
- **Next action:** complete the remaining parent Phase 0 UX contracts before
  beginning the Step 2 native shell.
