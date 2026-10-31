# Recoverable host primitive binding proof

This bounded v2 prerequisite supports the fresh compiler's source intake.
The accepted combined gate now passes 470 checks; both stages pass all 27
malformed host-signature cases. Current accepted identities and child reports:
`../../../UBE_Compiler_v3/SOURCE-INPUT-EVIDENCE.md`.
The production roles use explicit `UBE_Primitive` attributes and concrete
signatures; procedure spelling does not choose an implementation.
The runtime contract is `../../../../std-lib/FILE-BYTES-CONTRACT.md`.

| Role | Parameter signature | Result | Runtime symbol |
|---|---|---|---|
| `File.TryOpen` | `ByRef Byte(), ByVal Long, ByRef Long, ByRef Long, ByRef Long` | Boolean | `ube_file_try_open` |
| `File.TryRead` | `ByVal Long, ByRef Byte(), ByVal Long, ByVal Long, ByRef Long, ByRef Long` | Boolean | `ube_file_try_read` |
| `File.TryClose` | `ByRef Long, ByRef Long` | Boolean | `ube_file_try_close` |
| `Process.TryArgument` | `ByVal Long, ByRef Byte(), ByRef Long` | Boolean | `ube_process_try_argument` |
| `Error.Set` | `ByVal Long` | Boolean | `ube_error_set_number` |

The LLVM boundary receives Byte array holder addresses, i32 Long values or
addresses, and returns i32 status. Lowering compares status against zero to
produce UBE Boolean. Ordinary managed local/parameter roots retain borrowed
arrays during each synchronous call. No hidden array layout argument is added.
Existing value/storage roles and their lowering remain intact.

`binding-cases.json` specifies 27 independent malformed signatures, covering
all five roles, parameter modes, byte element restrictions, scalar widths,
missing/extra parameters, result type and array-valued result rejection.
Each must return exit 1, include `UBE3232`, and publish no LLVM artifact through
both current-source v2 stages. The maintained source-input gate runs these
cases and compares exact diagnostic output between stages:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-source-input.ps1 -SelectionPath <candidate-selection.json>
```

A focused current-source seed build passed all 27 rejections on 2026-10-30;
its immutable input/tool/command record is
`bootstrap/out/host-bindings/805b88c802224426bcff7ee8fae878d9/report.json`.
Subsequent exploratory source-input runs also passed them through both
provisional source-built stages. Those exploratory reports explicitly use
`ube-source-input-exploratory-1`; they are not an accepted complete bootstrap
gate. Final qualification requires a successful `ube-source-input-proof-1`
report bound into the complete current-source build manifest.
