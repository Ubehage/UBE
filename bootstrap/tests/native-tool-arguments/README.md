# Native tool arguments

NativeToolArguments builds the reviewed Clang and llvm-dlltool command lines
in ordinary UBE. It does not start processes, generate import definitions,
inspect output artifacts or publish files.

## API

```vb
TryClangCommand(Application, Stage, Optimization, Command, Failure) As Boolean
TryImportCommand(Application, Stage, Command, Failure) As Boolean
```

All byte arrays are ByRef, zero-based counted UTF-8. Optimization is ByVal
Long: 0 through 3 select -O0 through -O3; 4 selects -Os. Failure is ByRef Long.
Success returns fresh True, sets Failure to zero and preserves sticky Err.
Failure preserves the previous Command.

Application and Stage must be valid absolute Windows drive or UNC paths within
the current 4,096-byte path boundary. They are normalized with WindowsPaths.
Quotes, invalid UTF-8, NUL and forbidden path characters are refused. A drive
root cannot be an application name. This performs spelling validation, not
filesystem existence or executable-format verification.

Command may alias Application or Stage: normalization and construction finish
in private buffers before final independent publication. Every argument,
including the executable and fixed switches, is appended through
WindowsArguments.TryAppendQuotedArgument. Separating spaces are supplied
explicitly. No command shell participates.

Failure 1 denotes invalid optimization/path or a controlled language failure;
3 denotes construction/storage failure. Called WindowsPaths failures retain
their documented codes. Callers must inspect fresh status rather than Err to
decide success. A command is bounded to 131,072 UTF-8 bytes. The child-process
boundary must separately enforce its UTF-16 command limit before invocation.

Fixed text is stored as small explicit ASCII byte tables in the source; no
String support or additional bootstrap feature is introduced. Fixed stage
filenames come from OutputPublication.TryStagePath, which uses WindowsPaths.TryResolveSource, preserving the
private stage directory boundary.

## Exact argument lists

Clang receives, in order:

```text
<application>
--target=x86_64-pc-windows-msvc
-fuse-ld=lld
-nostdlib
-O0 | -O1 | -O2 | -O3 | -Os
-x
ir
<stage>\input.ll
-x
none
<stage>\kernel32-memory.lib
-o
<stage>\output.exe
-Wl,/entry:main,/subsystem:console,/stack:8388608
```

The import tool receives:

```text
<application>
-m
i386:x86-64
-d
<stage>\kernel32-memory.def
-l
<stage>\kernel32-memory.lib
```

The caller must generate the reviewed import definition and archive before
invoking Clang. The admitted runtime requires the reviewed kernel32 imports,
so the command always includes the stage-local import archive.

## Native acceptance

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/native-tool-arguments/check.ps1 -BootstrapExe "C:\Users\Ubehage\AppData\Local\Temp\ube resource metadata f0be9542-2ec5-4a91-91da-50a7e369657c\build\UBE-Bootstrap.exe"
```

Passed on 2026-11-13 at O0/O2:

- Twelve exact command byte vectors, covering every optimization, both tools,
  spaces/shell-metacharacter filenames, Unicode, UNC and output aliases to
  either input. Actual produced command files are parsed by Windows
  CommandLineToArgvW and every resulting argument is compared independently
  against the intended argument list.
- Eleven invalid-input cases preserve previous output: bad optimization,
  quote-containing/relative/empty paths, drive-root application, malformed
  UTF-8 and excessive path size.
- All 101 observed Clang-builder and 66 import-builder allocation sites are
  failed along with their retries. Previous output survives every failure;
  same-context recovery reproduces the exact command and releases all blocks.
- Both changed-command negative controls return exact exit 99.

Evidence:
`C:\Users\Ubehage\AppData\Local\Temp\ube native arguments e1a7b85e-9578-4aff-8ef1-14a41d399448`.

These assertions qualify argument construction, not process containment,
timeouts, backend success or compiler self-hosting.

