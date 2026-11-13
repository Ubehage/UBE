# Output publication

`OutputPublication` owns adjacent staging directories and guarded publication in ordinary UBE.
All paths are zero-based counted UTF-8 byte arrays. Source paths use `ProjectLoader.SourcePath`
records plus the loader's flat path arena. The caller retains every owner and request value.

## API

`TryPrepare(Requested, ManifestPath, PathBytes, Paths, SourceCount, Output, Stage, StageOwned, Token, Failure)`
requires `Token = 0` and `StageOwned = False`. It resolves the output through its existing
physical parent, rejects directory destinations and trailing dot/space leaves, and checks
the manifest and every source against both canonical paths and 12-byte file identities.
It reserves an adjacent `.ube-<tick>-<attempt>` directory using exclusive creation, retrying
only collision status17, at most128 attempts. Output and Stage are request scratch, not an
atomic pair. Once created, StageOwned is published immediately and must be cleaned up.

`TryProtectPath(InputPath, Output, Token, Failure)` independently resolves the output and
refuses canonical-path or hardlink aliases to an additional asset/tool input.

`TryStagePath(Stage, Kind, Result, Failure)` atomically returns one known leaf:

| Kind | Constant | Filename |
| --- | --- | --- |
| 1 | InputIR | input.ll |
| 2 | Executable | output.exe |
| 3 | ImportDefinition | kernel32-memory.def |
| 4 | ImportLibrary | kernel32-memory.lib |
| 5 | ImportLog | import.log |
| 6 | CompilerLog | clang.log |

`TryCommit(ManifestPath, PathBytes, Paths, SourceCount, Output, Stage, StageOwned, Kind, Token, Failure)`
revalidates the physical output parent and protected project inputs before replacing the
destination. Only InputIR or Executable may be committed. The caller must close and validate
the artifact first. Commit retains directory ownership for subsequent cleanup.

`TryDiscard(Stage, StageOwned, Failure)` deletes only the six known leaves and removes the
empty directory. Only explicit missing-file status18 is tolerated for leaf deletion.
Unknown files prevent directory removal; no recursive deletion occurs. StageOwned clears
only on successful directory removal. A primary error survives cleanup. Failed closes
retain Token for a caller retry, using `FileBytes.TryClosePreservingError`.

## Acceptance evidence

Command run on 2026-11-13:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/output-publication/check.ps1 -BootstrapExe "C:\Users\Ubehage\AppData\Local\Temp\ube resource metadata f0be9542-2ec5-4a91-91da-50a7e369657c\build\UBE-Bootstrap.exe"
```

Passed23 real-I/O cases at O0/O2, including exact published bytes, source/manifest path
and hardlink protection, junction physical parents, collision retry/exhaustion, failed
close ownership, commit-time alias rechecks, replacement failure, unknown-file refusal,
and delete/removal recovery. Additional protected-input hardlink and nonalias cases passed.
All118 observed prepare allocation sites and retries preserved prior output and recovered
with balanced owners. A changed expected physical path failed at exact assertion107.

Evidence: `C:\Users\Ubehage\AppData\Local\Temp\ube publication 6dd9414b-4377-498a-acb9-f0244eaa0e08`.
This qualifies publication mechanics, not PE validation or compiler self-hosting.
