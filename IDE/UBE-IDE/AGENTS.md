# UBE IDE application instructions

This folder contains the native UBE IDE application and its headless core.

Before changing it, read `../DESIGN.md`, `../Workplan.md`, this folder's
`DESIGN.md`, and this folder's `Workplan.md`.

- Production behavior is written in UBE wherever the current compiler can
  express it. Keep temporary host adapters narrow and replaceable.
- UI, compiler, debugger, and operating-system details must not leak into the
  document and workspace models.
- No malformed project, document, setting, locale, protocol message, or host
  failure may panic or discard the last good user data.
- Every crash or data-loss fix requires a synthetic regression test.
- Generated binaries, LLVM, temporary workspaces, and test output belong in
  `out/` and must not be committed.
- Update this folder's `Workplan.md` and the parent `../Workplan.md` when a
  checkpoint changes state.

