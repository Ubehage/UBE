# Preserved compiler release previews

This directory contains the executable produced for every completed, stable
UBE Compiler v3 release preview. These executables are committed with the
source that produced them so a published preview remains directly available
after later compiler work begins.

Executable names include the compiler generation, preview, host, and target:

```text
ube-v<generation>-rp<preview>-<host>-<target>.exe
```

`SHA256SUMS.txt` records each executable's SHA-256 digest. A preview executable
may be added or replaced only after its complete preview gate passes from a
clean output directory. Existing stable preview executables are immutable;
later work creates a new file rather than overwriting an earlier preview.

These files are release artifacts, not intermediate build output. All other
generated objects, LLVM IR, logs, manifests, and temporary executables remain
under `bootstrap/out/` and are not committed.

## Preserved previews

| Preview | Source commit | Host and target |
|---|---|---|
| v3 RP0 | `57c64da` | Windows x86-64 → `x86_64-w64-windows-gnu` |
| v3 RP1 | `c47b06a` | Windows x86-64 → `x86_64-w64-windows-gnu` |
| v3 RP2 | `0f4a19d` | Windows x86-64 → `x86_64-w64-windows-gnu` |
| v3 RP3 | `285fd58` | Windows x86-64 → `x86_64-w64-windows-gnu` |
| v3 RP4 | `9b3d8d9` | Windows x86-64 → `x86_64-w64-windows-gnu` |
| v3 RP5 | `6090abe` | Windows x86-64 → `x86_64-w64-windows-gnu` |
| v3 RP6 | `e2504b5` | Windows x86-64 → `x86_64-w64-windows-gnu` |
| v3 RP7 | `4eebebe` | Windows x86-64 → `x86_64-w64-windows-gnu` |

RP0 through RP2 were reproduced from their exact completion commits when this
preservation policy was introduced. RP3 through RP7 are the executables produced
by their clean completion builds.
