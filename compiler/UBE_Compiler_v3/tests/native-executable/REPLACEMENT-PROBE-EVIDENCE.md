# Focused Windows replacement probe

## Combined ordinary-path publication and source edits

The owner's source-change clarification supersedes any source-consistency
requirement inferred from the historical source-lock experiments below. UBE
does not monitor changes, lock sources for consistency, reject changed sources
or retry to obtain a stable on-disk snapshot. Compilation may succeed despite
inconsistent input; discovering the resulting program error is not its duty.

`handle-rename/anchored-publish.c` combines initial input/output separation,
held ordinary-directory components, inspection of a held candidate and relative
extended rename into that same output parent. Directory handles request
`FILE_READ_ATTRIBUTES` with read/write sharing; source handles allow read,
write and delete sharing and close before the actor barrier. The candidate
handle requests read/delete access with read sharing and stays open through
the rename. The test requires exactly the nine bytes `candidate`, not a PE
executable. The relative rename uses information class 65 and replace/POSIX
flags. No source identity is rechecked after the actor barrier.

The following commands completed with exit 0. The harness checks expected
process exits, barrier outcomes and source/output/candidate bytes for 16 cases:
success, absent output, cancellation, locked output, late ordinary output,
late hardlink, source edit, source replacement save, source moved to output,
initial source entry, initial hardlink, ancestor move, candidate move,
candidate write, invalid candidate and reparse parent.

```powershell
rtk proxy 'C:\Program Files\LLVM\bin\clang.exe' --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/anchored-publish.c -o bootstrap/out/anchored-publish.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-anchored-publication.ps1 -Probe bootstrap/out/anchored-publish.exe -OutputDirectory bootstrap/out/anchored-publication
```

Report: `bootstrap/out/anchored-publication/6918f780254e40e5881399bf3fbd6c58/report.json`.
The report records these SHA-256 identities:

| Artifact | SHA-256 |
| --- | --- |
| Probe executable | `3F7B68A302ABD83AB6CF946A1BE0B9467CBC649E984505B0DC925831A0CF1714` |
| C source | `E4B46DB4441947B03BB7B5BC275573E011A744836A6CE7ACA58BB2F6034E9DB9` |
| Harness | `FB8B818B123C69AFA8DD8736B4485BDE04EC42D89F7005B4C4495DDA3A135FC8` |

Source edits and replacement saves succeeded and their new bytes survived
publication. Cancellation, denied replacement and invalid candidates preserved
the old output. Initial aliases rejected before readiness. The actor could not
move the held ancestor or mutate/move the held candidate; the ancestor could
move once the process released it. The relocation case follows the documented
engineering interpretation that the admitted output entry belongs to the build;
it is distinct from the separate-hardlink case, which preserves the original.

An earlier probe requested additional directory rights and failed acquisition
with `c0000022` before readiness. Restricting those handles to the required
metadata access resolved that focused failure without a pathname fallback.

These assertions cover ordinary drive-absolute directories on this host and
file bytes, not all input metadata, named streams, security descriptors or
filesystems. Rejecting reparse parents is a probe boundary, not a selected
blanket production restriction. Complete name/reparse handling, actual candidate
creation, tool-writer containment, PE/debug inspection, preexisting mappings and
production integration remain separate obligations. Earlier reader-stress
experiments below are not integrated checks of this combined prototype.

## PE data-directory count control

The test-only structural probe now rejects a PE32+ directory count that cannot
fit in the declared optional-header size. `handle-rename/check-pe-directories.ps1`
alters only that count in a known executable and establishes that the original
count fits. The test command below returned 0: the original was accepted and
the mutation rejected. A build with `-DOMIT_DIRECTORY_BOUNDS` accepted both;
running the rejection assertion against that build returned 1, as intended.
Both probe builds used Clang's `--target=x86_64-w64-windows-gnu -std=c17 -Wall
-Wextra -Werror -municode`; the latter additionally used the macro above.

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-pe-directories.ps1 -Probe bootstrap/out/pe-directory-0.exe -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename -RequireRejected
```

This checks the count against header capacity, not the contents or validity of
the directories, and does not qualify the production candidate-validation gate.
The integrated structural comparator was also run with independent mutations
that omit raw-section bounds or directory-count bounds:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-pe-probe-mutation.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -Readobj 'C:\Program Files\LLVM\bin\llvm-readobj.exe' -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename
```

The command returned 0: the correct probe passed, and the comparator rejected
each separately mutated probe at its corresponding malformed case.
The structural-fixture generator and transaction harness were then extended to
include this case. `check-pe-structure.ps1` with
`-Readobj 'C:\Program Files\LLVM\bin\llvm-readobj.exe' -Executable
bootstrap/out/native-handle-rename.exe -OutputDirectory
bootstrap/out/native-handle-rename -StructuralProbe bootstrap/out/pe-directory-0.exe`
returned 0 and created fixtures under
`bootstrap/out/native-handle-rename/5866e5d0c56b4c63ac0b7e1c1947f785`.
The count mutation passed readobj's selected header markers but failed the
test-only structural check. Running `check-transaction-executable.ps1` with
the same probe, that directory as `-MalformedDirectory`, its `zero-code.exe`
as `-ZeroCode`, and the normal wrapper, inspector and executable/object/DLL
fixtures returned 0: all nine malformed cases were rejected with old output and
candidate preserved, while the zero-code adverse control was still published.
This remains a TxF experiment, not a production publication or semantic check.

## Section alignment adverse control

`handle-rename/check-pe-alignment.ps1` changes only the entry section's raw-file
offset, increasing it by one byte after checking the original alignment and
that the mutated range remains within the file. The experimental structural
probe accepted both the original and mutated file. [Microsoft's PE format
description](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format)
requires executable section raw offsets to be multiples of `FileAlignment`.
This is a format counterexample, not a claim that the mutated file was run or
that alignment alone establishes loadability or program correctness.

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-pe-alignment.ps1 -Probe bootstrap/out/pe-structure-probe.exe -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename
```

The command returned 0 after observing acceptance of both fixtures.

The test-only structural source was subsequently extended to check nonzero
power-of-two file alignment and alignment of nonempty raw offsets and sizes.
Using Clang with `--target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra
-Werror -municode`, it was compiled to `bootstrap/out/pe-structure-aligned.exe`;
a second build added `-DOMIT_FILE_ALIGNMENT` and used
`bootstrap/out/pe-structure-no-alignment.exe`. Running the command above with
`-Probe bootstrap/out/pe-structure-aligned.exe -RequireRejected` accepted the
original and rejected the misaligned fixture. Running it with
`-Probe bootstrap/out/pe-structure-no-alignment.exe` accepted both. Both scripts
returned 0. This checks one fixture and a deliberately omitted check; it does not
qualify all PE alignment rules, other linker outputs, or a compiler validator.
As a comparator negative control, the same script with both
`-Probe bootstrap/out/pe-structure-no-alignment.exe` and `-RequireRejected`
returned 1 after the mutated probe accepted the malformed file. Thus the
rejection assertion detects this omission rather than merely observing it.
The updated structural probe was also used with the existing transaction and
external-inspector harness:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-executable.ps1 -Probe bootstrap/out/transaction-handle.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector 'C:\Program Files\LLVM\bin\llvm-readobj.exe' -StructuralProbe bootstrap/out/pe-structure-aligned.exe -Executable bootstrap/out/native-handle-rename.exe -ObjectFile bootstrap/out/native-handle-rename-object.o -DllFile bootstrap/out/native-handle-rename-control.dll -OutputDirectory bootstrap/out/native-handle-rename
```

It returned 0: the normal case committed, the candidate-swap case was rejected,
and the object and DLL were rejected with old output and candidate preserved.
This is still a test-only TxF experiment, not a selected publication scheme.

On 2026-11-02, `rtk proxy powershell -NoProfile -File
bootstrap/out/file-replacement-review/probe.ps1` exited 0. The script's SHA-256
was `4BED42D686C50443E6F763013D99F060CA9988DFF929179BAF21155825798547`.
It operates only on a new test-owned GUID directory under `bootstrap/out`.
The repeat run used `bootstrap/out/file-replacement-review/
27dbe36298f941e2bfbc01b414425786/` and observed:

- `[IO.File]::Replace` installed the new bytes at an existing destination and
  removed the candidate name.
- `[IO.File]::Move` installed the new bytes when the destination was absent.
- With an exclusive destination lock, replacement failed and both old and
  candidate byte sequences remained intact.
- After an initial pathname check, a test swapped the destination entry to a
  hardlink of a protected test peer. Unchecked replacement still proceeded; the
  protected peer's bytes remained unchanged. This demonstrates the check/commit
  race, not modification of the protected peer.

The earlier run reported NTFS through `DriveInfo`; an attempt to query volume
information using `fsutil` was denied. Its first script attempt failed because
Windows PowerShell's `New-Item` did not support the chosen `-LiteralPath`
parameter; the corrected script above is the passing version.

This is a focused observation of .NET operations on this host. It does not prove
atomic visibility, identity-protected replacement, failure atomicity for all
cases, cross-volume behavior, power-loss durability, other filesystems, or the
production compiler's process boundary. A handle-anchored or equivalent commit
mechanism and its complete failure gates remain unqualified.

The probe is now retained as `file-replacement/probe.ps1` under this test
directory, with an explicit output-directory parameter. Running
`rtk proxy powershell -NoProfile -File
compiler/UBE_Compiler_v3/tests/native-executable/file-replacement/probe.ps1
-OutputDirectory bootstrap/out/file-replacement-review` returned exit 0 and
reported the same four outcomes above, using a fresh test-owned directory.
This repeat has the same limitations; it does not qualify an atomic,
identity-protected production commit.
The maintained script SHA-256 was
`E184C117B4F017DEF8C5C8BB57C9162488C4B713CC585520AC43FBEA3DF3BA4B`.

The separate `handle-rename` probe tested `SetFileInformationByHandle` on an
open candidate. With an absolute destination it observed successful existing
and absent replacements, plus locked-destination failure preserving both files.
With `FILE_RENAME_INFO.RootDirectory` set to the open directory and a relative
destination name, this host returned Windows error 87; the old and candidate
bytes remained intact. The check was run after compiling with local Clang:
`rtk proxy powershell -NoProfile -File
compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check.ps1 -Probe
bootstrap/out/native-handle-rename.exe -OutputDirectory
bootstrap/out/native-handle-rename`; it returned exit 0 for those explicit
observations. The initial relative-only probe also returned 87. This is a
specific API/host result, not proof that every relative or handle-based Windows
rename is unavailable. The absolute-name success is not an identity-protected
commit and does not close path-race, atomic-visibility or failure-atomicity
gates.
Repeating the same check after opening the directory with `FILE_ADD_FILE` in
addition to list/read access still produced error 87 for the relative-root call;
the absolute-path controls passed. This rules out only that tested access-mask
variant, not other APIs or host mechanisms.
The same probe was extended to call `NtSetInformationFile` dynamically with
`FileRenameInformation` and the open directory as `RootDirectory`. On this
host, the explicit existing- and absent-destination checks succeeded; a locked
destination failed and preserved both old and candidate bytes. The script above
returned exit 0 after checking those outcomes as well as the Win32 error 87 and
absolute-path controls. This is a narrowly observed native-API candidate, not
an approved production dependency or a qualification of atomic visibility,
parent/target swap resistance, untrusted aliases, other filesystems or all
failure outcomes. In particular, it does not prove that a checked destination
identity cannot change before the rename.
The extended probe source SHA-256 was
`44CC018F8502BFAECF670A19FBBADFF516E8B31CD61E855C893B150B5E2DE3F2`,
the comparator was `FBA142FE24D6A77128DF1B36219E08273CD3B882F5D4D1EB5F6F6C2889CDF353`,
and the executable was `FD451B1B3CBF5B2C7D390167D4D760468EF27E251EA43F64F097DCB3A2EC8937`.
The probe was further extended with ready/release events to attempt moving the
parent directory after the directory and candidate handles were open. A move
and move-back control succeeded before opening those handles; during the paused
probe, the same move was denied. After release, the relative rename succeeded in
the original directory. The first comparator treated the denial as a test error;
the revised comparator explicitly records it and checks the resulting bytes.
This run did not achieve the intended directory swap and therefore does not
prove swap resistance or identify which open handle caused the denial. Other
race actors, permissions and filesystems remain untested.
In a separate event-controlled target-entry race, the actor moved the checked
destination aside and created a new destination before releasing the probe. The
native relative rename then succeeded and overwrote that new entry; the old
bytes survived only at the actor's moved-aside path. The comparator explicitly
checked the actor's old file and the final new candidate bytes. This establishes
that holding the candidate and directory handles alone does not bind the
destination identity. Overwriting an ordinary substituted destination is now
permitted by the owner's decision; the remaining question is whether the same
operation can protect an input or input alias substituted before commit. This
does not test a production compiler or a stronger protective scheme.
The same event-controlled test substituted a hard link to a protected test file
for the checked destination. The native relative rename replaced that directory
entry, while the protected peer retained its original bytes. This confirms that
the substituted entry was not identity-checked; it does not establish safety
for other link types, filesystems, or a production publication implementation.
The updated `handle-rename/check.ps1` passed with the existing probe executable
on this host, including the hard-link assertion.
An analogous event-controlled symbolic-link test was prepared in
`handle-rename/check-symlink.ps1`, but could not reach the rename: Windows
PowerShell's link creation failed with `NewItemSymbolicLinkElevationRequired`.
The final script creates and checks the link before starting the rename
process; its attempted run exited 1 at that setup step. Thus no conclusion is
drawn about symbolic-link replacement or target preservation. A prior version
also attempted to terminate a process immediately after releasing its event;
that termination was denied while the process was exiting, and a later process
check found no remaining `native-handle-rename` process. The revised ordering
avoids starting that process when link setup fails.
The separate `handle-rename/check-junction.ps1` test creates a junction to an
original directory, waits until the native-relative probe has opened its
handles, then moves that junction and replaces it with one targeting another
directory. The junction swap was observed before the probe was released. The
command below returned 0: the rename changed the original directory's file to
`new`, while the other directory's file stayed `other` and remained visible
through the selected path.

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-junction.ps1 -Probe bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename
```

This demonstrates that the opened directory handle retained its original
target in this test, but also that a successful handle-relative rename need not
publish at the path the user selected after a junction swap. The probe has no
path-stability guard and does not qualify the publication contract or prove
safety for other reparse points or filesystems.

A follow-up candidate guard opened the junction itself using
`FILE_FLAG_OPEN_REPARSE_POINT`, without delete sharing, and checked the open
handle's reparse attribute and mount-point tag. The event-controlled test held
that handle while attempting the same junction move and native-relative rename.
On this host, the junction move still succeeded and the rename updated the
original directory. The first version treated a successful move as a failing
test; the revised comparator reports either observed outcome and checks the
resulting file bytes. Both the unchecked and tag-checked runs observed the
move. Commands for the tag-checked run:

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/junction-guard.c -o bootstrap/out/native-junction-guard.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-junction-guard.ps1 -Probe bootstrap/out/native-handle-rename.exe -Guard bootstrap/out/native-junction-guard.exe -OutputDirectory bootstrap/out/native-handle-rename
```

This rules out that attribute-only handle as a guard for the tested operation and
host; it does not identify the system's internal reason or rule out a stronger scheme.
The move actor was then changed from PowerShell's `Directory.Move` to a separate
`MoveFileExW` call with flags zero. After rebuilding `junction-guard.c` with
the same compile command and rerunning `check-junction-guard.ps1`, the API
move also succeeded while the tag-checked no-delete-share handle was held;
the original directory received the candidate. The script observes the direct
child's actual status rather than the `rtk proxy`-normalized status. This
confirms the same limited finding for that Windows API on this host.
The guard was then changed to request `FILE_LIST_DIRECTORY` as well as
`FILE_READ_ATTRIBUTES`, still with no delete sharing and the same junction-tag
check. Rebuilding and running the same commands showed a different result:
`MoveFileExW` failed with sharing violation 32 while the guard was held, the
native-relative replacement succeeded and was visible through the selected
junction, and the same move succeeded after the guard closed. Both observations
were asserted in the revised script. Thus the preceding failure applies to the
attribute-only access, not to this stronger handle. This is a promising focused
host result, not a complete publication solution: safe acquisition of every
path component, races before acquisition, existing handles, destination-entry
swaps, candidate identity, other reparse types and filesystem behavior remain
unqualified.

`check-junction-preopen.ps1` tests one pre-existing-handle case. A separate
actor first opens the junction with DELETE access and signals readiness. The
stronger guard then fails to open it with sharing violation 32 and never signals
that it acquired protection. After the actor closes its handle, the same guard
opens successfully and closes cleanly. The guard helper was rebuilt using the
compile command above; both the original guarded-move test and this command
returned exit 0:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-junction-preopen.ps1 -Guard bootstrap/out/native-junction-guard.exe -OutputDirectory bootstrap/out/native-handle-rename
```

This establishes the observed sharing conflict for a pre-existing DELETE
handle to this junction on this host. It does not cover all mutation methods,
other pre-existing handles, or atomic acquisition of a full path chain.

The stronger no-delete-share guard does not prevent every junction mutation.
`check-junction-clear.ps1` held that guard, then opened the junction with write
access and issued `FSCTL_DELETE_REPARSE_POINT` for the mount-point tag. On this
host the operation returned success while the guard remained open. The test
confirmed that the junction path no longer resolved to the protected test file
and that the original target file's contents stayed intact. The guarded-move
and pre-existing DELETE-handle results above remain valid for their respective
operations; they do not establish protection against this in-place change.

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/junction-guard.c -o bootstrap/out/native-junction-guard.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-junction-clear.ps1 -Guard bootstrap/out/native-junction-guard.exe -OutputDirectory bootstrap/out/native-handle-rename
```

Both commands returned 0. This is a controlled test of a test-owned junction,
not evidence about all reparse-point mutations or a production guard.
The guard was subsequently tightened to share reads only, withholding both
write and delete sharing. After rebuilding, the clear actor's write-capable
open failed with sharing violation 32 while the guard was held; it succeeded
and cleared the junction after guard release. The guarded rename and
pre-existing DELETE-handle tests were also rerun and passed under that setting.
This makes read-only sharing a stronger candidate for the tested junction, but
does not qualify access permissions, complete path-chain acquisition, destination
identity, other reparse operations, or filesystem support.
The `native-parentguard` mode of the handle-rename probe holds the actual parent
directory with list/add access and read sharing only, and uses that same handle
as the native-relative destination root. `check-parentguard.ps1` observed that
an actor could not move the destination while this handle was open; however,
the intended rename also failed with sharing violation 32. The old destination
and candidate contents were checked after failure, and moving the destination
succeeded after the process closed its handle. The first test revision assumed
the actor would succeed; a later revision assumed the intended rename would
succeed. Both assumptions were corrected before the passing observation. The
ordinary less-restrictive handle-rename suite also passed after rebuilding.
Commands:

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/probe.c -o bootstrap/out/native-handle-rename.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-parentguard.ps1 -Probe bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check.ps1 -Probe bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename
```

This parent-handle configuration is therefore not a workable existing-output
replacement solution on the tested host. Other access/share combinations and
mechanisms are not ruled out by this observation.
The probe was then run with two additional parent-directory share masks. With
read and write sharing but no delete sharing (`-Mode native-parent-nodel`), the
actor moved the old destination and substituted another file, which the intended
rename then replaced. With read and delete sharing but no write sharing
(`-Mode native-parent-nowrite`), both the actor's move and the intended rename
were blocked; the rename returned sharing violation 32 and the original files
were preserved. The read-only-sharing baseline was rerun and gave the same
blocked-both result. Each `check-parentguard.ps1` run returned 0 and, where the
actor was blocked, verified that a move succeeded after the probe closed its
handle. These are three specific sharing configurations on this host, not an
exhaustive proof that no workable mechanism exists.
The read-only-sharing parent guard was also tested with the extended native
rename form and replace-plus-POSIX flags (`-Mode native-parent-posix`). The
actor's destination move and the intended rename were both blocked; the latter
returned sharing violation 32, old and candidate bytes remained, and the actor's
move succeeded after release. The separate unguarded extended-rename control in
`check.ps1` passed after the same rebuild. This rules out that tested combination
on this host, not every extended-rename flag or publication design.
For an initially absent destination, the retained native-relative rename probe
now has a create-only mode (`ReplaceIfExists = FALSE`). Its event-controlled
test passed both an uncontended creation and a case where another actor created
the destination before commit. In the latter, rename failed with Windows error
183, and both the actor's destination bytes and the candidate bytes remained.
The existing replacement probe suite also passed after rebuilding. Commands:

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/probe.c -o bootstrap/out/native-handle-rename.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-create-race.ps1 -Probe bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check.ps1 -Probe bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename
```

This identifies a candidate collision-safe absent-destination operation on the
tested host. It does not address replacement of an existing executable, path
component stability, candidate identity, or other filesystem behavior.
For candidate identity, `check-sourceguard.ps1` compares two event-controlled
cases. An actor opens a hard link to the candidate for writing while the probe
is paused. With the original permissively shared source handle, the actor changes
the bytes and the later rename publishes the changed content. With a handle
opened for read and DELETE access while sharing reads only, the probe first
reads `candidate` through that same handle; the actor's write open is denied,
and the rename publishes the original bytes. The first actor used the default
PowerShell file-sharing mode and was blocked even in the unguarded case; it was
corrected to share read, write and delete, after which both controls passed.

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/probe.c -o bootstrap/out/native-handle-rename.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-sourceguard.ps1 -Probe bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename
```

This is a candidate for anchoring the source file after the guard is acquired;
it does not test pre-existing writers or mappings, identity before acquisition,
verification by an external tool, destination identity, path stability, or
other filesystems. It does not qualify the whole publication operation.
An external-tool compatibility experiment held the same read/DELETE,
read-sharing-only style of guard over a test executable and invoked the local
GNU objdump with `-f`. Objdump succeeded before and after the guard, but while
it was held returned status 1 and `Permission denied`. The candidate SHA-256
was unchanged. The following commands returned 0 for the test's assertions:

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/file-guard.c -o bootstrap/out/native-file-guard.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-tool-read.ps1 -Guard bootstrap/out/native-file-guard.exe -Objdump C:/Users/Ubehage/Documents/WinLibs/mingw64/bin/objdump.exe -Executable bootstrap/out/native-debug-reader/debug.exe -OutputDirectory bootstrap/out/native-handle-rename
```

This demonstrates a concrete compatibility obstacle for that particular tool
and host; it does not determine the exact sharing flags objdump requested, test
other tools, or prove that a different validation or handle-handoff scheme is
impossible. An externally validated candidate still needs its validation tied
to the bytes ultimately committed.
Two later host experiments explored a different sequence. With a read-only
candidate handle sharing read and delete but not write, the local objdump could
read the candidate while the handle was held; the earlier DELETE-access guard
still blocked it. In a separate event-controlled test, the probe read a test
candidate through such a handle; an actor moved its pathname and substituted a
different file, while a write open on the original object was denied. The probe
then used `ReOpenFile` on its held handle to obtain read/DELETE access and
renamed that reopened object. The original `candidate` bytes reached the
destination and the substituted file remained at the old candidate path. The
source-guard and create-only controls also passed after rebuilding the probe.
Commands for the focused checks:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-tool-read.ps1 -Guard bootstrap/out/native-file-guard.exe -Objdump C:/Users/Ubehage/Documents/WinLibs/mingw64/bin/objdump.exe -Executable bootstrap/out/native-debug-reader/debug.exe -OutputDirectory bootstrap/out/native-handle-rename -ReadOnly
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-reopen.ps1 -Probe bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename
```

These are separate tests, not a complete validation-to-publication proof. In
particular, an external tool opening the candidate *path* after substitution
could inspect the substitute rather than the held object. The experiments do
not bind the tool's read to the guarded handle, protect destination identity,
or qualify pre-existing mappings and other filesystems.
`check-tool-stdin.ps1` explores a different tool handoff for generated LLVM:
it opens the valid IR fixture read-only while denying write sharing, moves its
path and places invalid IR at that path, then streams from the still-open
original handle to Clang's stdin. The guard also blocks an attempted write open
on the moved original. Clang 23.1.3 at O2 with `-llvm-verify-each` compiled the
guarded stream to an object; a separate invocation on the substituted invalid
bytes failed and produced no object. This command returned 0:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-tool-stdin.ps1 -Clang "C:/Program Files/LLVM/bin/clang.exe" -OutputDirectory bootstrap/out/native-handle-rename
```

This is a bounded host experiment for one IR input and one Clang invocation,
not the production process boundary or final executable validation. It does not
combine the external tool, `ReOpenFile` and candidate publication in one run,
prove cancellation or drain safety, or address destination identity and path
stability. It illustrates how a tool supporting stdin could receive held-object
bytes without re-opening a swapped source pathname. The current diagnostic draft
specifies closed tool input; selecting this experiment as a production handoff
would require reviewing and changing that contract to permit a bounded,
compiler-owned input stream, including concurrent writing/draining,
cancellation and a definite close. It is not an approved exception to the
existing draft.
The test-only `tool-reopen.c` and `check-tool-reopen.ps1` subsequently combine
the held-object input and `ReOpenFile` experiments. A read-only, write-denying
handle is passed directly as Clang's stdin through an explicit handle list.
In the swap case an actor moves that input path and substitutes invalid IR;
write access to the held original is denied. After Clang verifies and compiles
the held bytes, the probe reopens that same object and renames it to a new
test-owned path. The comparator checks the renamed IR's SHA-256 against the
fixture, verifies the substitute remains at the old path, and inspects Clang's
object with objdump. An unswapped control also passes; a third case supplies
invalid held input and requires failure with no published file or object.

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/tool-reopen.c -o bootstrap/out/native-tool-reopen.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-tool-reopen.ps1 -Probe bootstrap/out/native-tool-reopen.exe -Clang "C:/Program Files/LLVM/bin/clang.exe" -Objdump C:/Users/Ubehage/Documents/WinLibs/mingw64/bin/objdump.exe -OutputDirectory bootstrap/out/native-handle-rename
```

Both commands returned 0. The renamed file in this experiment is the held IR,
not the linked executable; the object output itself is not identity-protected.
The test uses an absent destination, does not contain Clang in a Job or exercise
cancellation, and does not establish path stability or existing-executable
replacement. It demonstrates one possible held-input handoff, not a production
design or approval to change the closed-stdin draft.
The follow-up `check-source-mapping.ps1` creates a writable .NET file mapping
before the candidate guard starts, disposes the explicit `FileStream`, and
keeps the mapping and view alive. On this host guard acquisition failed before
its readiness signal and the old destination remained. After disposing the view
and mapping, a control guard opened and renamed the original candidate
successfully. The first test attempt passed a null mapping name that this .NET
runtime rejected; a unique named mapping was used in the passing run:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-source-mapping.ps1 -Probe bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename
```

This shows fail-closed behavior for that managed mapping setup, not that the
mapping alone caused the sharing conflict: the runtime may retain an underlying
file handle. It does not qualify existing views made through other APIs or
memory-mapping behavior on other filesystems.
The direct Windows-API `mapped-writer.c` control opens a writable mapping and
view, explicitly closes its original file handle, signals readiness, and waits.
With that view alive, the candidate guard's open failed with sharing violation
32. The writer then changed the mapped bytes and closed the view; the old
destination remained, and a fresh guard successfully renamed a restored
candidate. A first script attempt accidentally reused the typed `Writer`
parameter name for a process object; it was corrected before the passing run.

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/mapped-writer.c -o bootstrap/out/native-mapped-writer.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-native-mapping.ps1 -Probe bootstrap/out/native-handle-rename.exe -Writer bootstrap/out/native-mapped-writer.exe -OutputDirectory bootstrap/out/native-handle-rename
```

Both commands returned 0. The ordinary source-guard, create-only and retained
rename suites also passed after rebuilding the probe. This checks one writable
mapping configuration on this host; it does not establish behavior for all
mapping types or complete candidate and destination protection.
The same direct-mapping test was repeated with the read-only candidate guard
used by `native-reopen`, which shares read and delete but denies write sharing.
Its open also failed with sharing violation 32 while the writable view existed;
after the writer changed and closed the view, the test restored the candidate
and a fresh guard/reopen/rename control succeeded. The DELETE-access guard case
was rerun in parallel and again showed the same fail-closed outcome. Both
`check-native-mapping.ps1` runs returned 0. This is evidence for this one
Windows mapping configuration, not proof for every writable mapping, pre-existing
writer or filesystem.
The pre-existing-handle experiment was extended with a separate GENERIC_WRITE
actor. After rebuilding the helper, `check-junction-preopen.ps1` passed both in
its default DELETE mode and with `-Prewrite`: in each mode the guarded open
failed with sharing violation 32 before signaling readiness, then succeeded
after the actor closed its handle. This covers those two specific access modes,
not every operation capable of changing a path component.
The guarded-move script also has a `-MoveParent` case: the protected junction is
inside a test-owned parent directory, while its target is outside that parent.
With the read-only-sharing guard held, an actor's `MoveFileExW` on the parent
failed with access denied 5; the intended replacement remained visible at the
selected path. After guard release and rename completion, moving the parent
succeeded. The original direct-junction control was rerun and again observed
sharing violation 32 while held and a successful post-release move. Both runs
returned exit 0. This does not identify which open handle caused the parent
denial or establish safety for arbitrary ancestors, races during acquisition,
or other filesystems.
The extended check also opened the destination with read/write sharing but
without delete sharing. A separate move was denied, and the candidate's native
relative replacement was also denied; after closing the handle, both original
destination and candidate bytes remained. Thus this tested lock blocks both the
unwanted swap and the desired replacement; it is not by itself a workable
atomic publication solution. The check returned exit 0 for these observations.
The separate `handle-rename/replace-file.c` probe holds an existing test
destination open for read without delete sharing, then calls `ReplaceFileW` in
the same process. The call failed with sharing violation 32; the held old file
still contained `old`. After closing the handle, the same call succeeded, the
destination contained `new`, and the candidate no longer existed. The following
compile and assertion commands returned 0:

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/replace-file.c -o bootstrap/out/native-replace-file.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-replace-file.ps1 -Probe bootstrap/out/native-replace-file.exe -OutputDirectory bootstrap/out/native-handle-rename
```

This rules out this simple no-delete-share guard combined with `ReplaceFileW`
for the tested host; it does not qualify replacement or all host/filesystem
behavior. The extended native rename form (`FileRenameInformationEx`, replace plus POSIX
flags) was also tested: an unlocked existing-destination control succeeded,
but the same form under the no-delete-share handle failed with Windows sharing
error 32 and preserved both files. Thus this specific extended form also does
not bypass the tested lock. Other flags, APIs and filesystems remain outside
this observation. The documented rename information structure specifies a
target directory/name and replacement flags; it does not expose an expected
destination file identity in the listed fields
([Microsoft FILE_RENAME_INFORMATION](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ntifs/ns-ntifs-_file_rename_information)).
The inference is that a separate identity check alone cannot turn this call
into an atomic identity comparison, consistent with the observed swap race.
Windows opportunistic locks are another candidate for a future focused test,
but a break notification alone is not an atomic compare-and-replace. Microsoft
documents that an incompatible operation can break a lock even when initiated
by the same process on a different handle, and that notification behavior
depends on lock type ([oplock overview](https://learn.microsoft.com/en-us/windows-hardware/drivers/ifs/oplock-overview),
[FSCTL_REQUEST_OPLOCK](https://learn.microsoft.com/en-us/windows/win32/api/winioctl/ni-winioctl-fsctl_request_oplock)).
Any proposed use must demonstrate how the compiler's own commit, concurrent
changes, lock-break acknowledgement and previously opened handles interact;
no oplock solution has been selected or qualified here.
Microsoft's [FSCTL_REQUEST_OPLOCK documentation](https://learn.microsoft.com/en-us/windows/win32/api/winioctl/ni-winioctl-fsctl_request_oplock)
also distinguishes directory oplocks: changes to directory contents break the
available directory oplocks without requiring an acknowledgment, so the change
may proceed before the observer responds. A read-handle directory oplock has a
separate acknowledged break for renaming or deleting the directory itself.
Thus, as an inference from that documented distinction, an ordinary directory
oplock notification alone cannot prevent a late destination-entry substitution
between a check and commit. This is documentation review, not a host test or a
claim that every combined locking scheme is impossible.
The focused `oplock/probe.c` was subsequently compiled with local Clang using
`--target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode`.
`rtk proxy powershell -NoProfile -File
compiler/UBE_Compiler_v3/tests/native-executable/oplock/check.ps1 -Probe
bootstrap/out/native-oplock-probe.exe -OutputDirectory bootstrap/out/native-oplock`
returned exit 0. For a level-1 oplock on an existing test file, it observed a
break notification while a competing move was still pending, then the move
completed after the lock handle was closed and preserved the expected bytes.
This checks one competing move on one host. It does not test the compiler's own
commit under the lock, already-open handles, an absent target, all break modes,
or any atomic identity guarantee.
In `oplock/own-commit.c`, a same-process worker instead attempted a
`MoveFileExW` replacement while a level-1 oplock was held. An unlocked control
replaced successfully. With the lock, the worker completed with access denied
(error 5), and no break notification arrived within the ten-second test bound;
both old and candidate bytes remained. The first harness expected a break and
failed; `oplock/check-own-commit.ps1` was then changed to assert this observed
outcome alongside the unlocked control, and it passed. This is one API and one
lock type, not proof that every same-process replacement or oplock scheme fails.
An extended same-process probe used the native directory-relative rename call.
Its unlocked native control succeeded; while holding the level-1 oplock, the
native rename returned access denied, with no break notification within ten
seconds, and the comparator verified old and candidate bytes unchanged. The
initial native attempt passed a DOS absolute path to the native API and returned
error 123; it was corrected to use the tested directory handle and relative
name before the passing comparison. This rules out only that observed pairing,
not other lock levels or schemes.
The extended source SHA-256 was
`59012619D3710EBC1CCFEBB228E7979EB86BA4A71A9FCCBD476D072BB0A69066`,
the comparator was `86BF47CBECF2D3C8FFF16D4C8D3CFCBF4E890CEBF605B0FFCE7AC1E492B18F59`,
and the executable was `2D628EA10E4714D23211D8D3322D92634E0410BE126EEFF0CD3BFFE12EF79A31`.
The competing-move source, comparator and executable SHA-256 values were
`768393715E169A988CBA3DBD54784CD896921B577E37CA5A98D5BF8F442F3E9B`,
`EE2BCBBE34C34D76151FD86E515ADA459399ACC22FF50761C31A3C9B761ADC92`, and
`EDDC641B14DFDB4F99D807601B41CC7C4A23E712A2B244DB054512823EC9EDC7`.
The same-process source, comparator and executable were
`70676A38DBEEE3D35D71A7C6B3AA3193C71148A7B07C1FD618E222909D978E9A`,
`FDDDEB37BE41007514631CFB27D3DB9C4B706E7C6E44E342DB4211C441F292F4`, and
`E2A28E3ADE985A08D0D3F32BBF77701E7AF25840F5F548B6625B80390B84F305`.
Transactional NTFS is not selected as a resolution: Microsoft recommends
alternatives and states it may not be available in future Windows versions
([Transactional NTFS](https://learn.microsoft.com/en-us/windows/win32/fileio/transactional-ntfs-portal)).
It also has filesystem and feature restrictions, including encrypted files
([programming considerations](https://learn.microsoft.com/en-us/windows/win32/fileio/programming-considerations-for-transacted-fileio-)).
This is a portability assessment, not evidence that every TxF operation fails
on the current host or that ordinary replacement meets the contract.
Microsoft's [TxF isolation documentation](https://learn.microsoft.com/en-us/windows/win32/fileio/txf-basic-concepts)
also states that TxF uses read-committed isolation: separate opens inside the
same transaction may see different results. It describes transactional writer
locks and ordinary sharing rules separately. Therefore, as a review inference,
merely placing a destination read and later rename in one transaction would not
by itself establish that the checked name still refers to the same file. A
specific scheme would need to establish the relevant lock and path behavior,
including aliases and commit/rollback outcomes. This is documentation analysis,
not a TxF host experiment or a claim that all transaction-based schemes fail.
The final probe source SHA-256 was
`E7CEFD270BB7103A0AF0EE4B971159B6F5022F8F46F4F116DA31541E88E850D9`,
the comparator script was
`530FFD8519C7B5EC03D337919A031C6EAA500322371A1D4FDD793F76E75463F9`, and
the executable was
`74E0A037912A4ADCC6C95AD6561B56510C01D789642E3D7FEEB93F43C6EC802E`.

## Extended hard-link replacement

The test-only `probe.c` also tries `FileLinkInformationEx` with the replace
and POSIX flags, using an opened candidate and a relative destination. Microsoft
describes these flags in its [FILE_LINK_INFORMATION documentation](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ntifs/ns-ntifs-_file_link_information).
On this host, the unlocked control replaced the destination with a link to the
candidate, retaining the candidate name. With the old destination open without
delete sharing, a competing move was denied and the link operation failed with
Windows error 32; the comparator checked that both old destination and candidate
contents remained intact. This does not establish a safe publication method or
rule out other approaches or filesystems.

The unlocked comparator also writes different bytes through the retained
candidate name and observes them through the destination. Thus a successful
link leaves another name capable of changing the published file until that name
is removed or otherwise protected. A cleanup warning alone would not establish
the candidate's continued integrity; any future use must address that alias as
well as the destination race.

## Guarded input with a substituted hard link

`handle-rename/check-protected-original.ps1` tests a distinct case: the selected
destination is the original test source name itself, either directly or through
a junction to its parent. In all four unguarded controls (native-relative and
native-posix, each direct and through a junction), the candidate replaced that
name. With a read handle that withheld delete sharing on the original, all four
replacement attempts failed and the candidate remained; the preservation
comparator matched the original's identity, bytes, creation and last-write
times, attributes, security descriptor and named stream. On this host the
native-relative failures reported error 5 and native-posix reported error 32.
Command:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-protected-original.ps1 -Probe bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename
```

This test uses a pre-established input guard and a test-owned path on one host.
It does not establish race-free acquisition, full parent-path protection, all
filesystem behavior or the separate-hard-link policy. It does not select a
publication protocol; the old-output, candidate and input requirements must
still be qualified together.

`handle-rename/check-protected-input.ps1` holds a separate protected input open
for read without delete sharing while the event-controlled rename probe is
paused. A positive guard control confirms that moving the input's original
name is denied. The actor then moves the initial destination aside and creates
a hard link to the protected input at that destination; the probe resumes its
native relative replacement. On this host the replacement still succeeded,
replacing the substituted hard-link name with the candidate, while the protected
original retained its bytes. The unguarded comparison also replaced the alias.
Thus this particular input handle does not enforce the draft's no-substitution
requirement for all names of the input; the probe does not itself perform a
destination identity check. Unchanged original bytes alone would
miss the destination-name race. This is one filesystem, access mode and API,
not proof about all sharing modes or reparse points.

After compiling `probe.c` with the command in the extended hard-link section,
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-protected-input.ps1 -Probe bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename`
returned 0 with both observations and the guard control. The first run expected
the guarded replacement to fail and correctly failed the test when it instead
succeeded; the comparator was then changed to check and report either coherent
outcome rather than prejudge the host result.

The comparator was extended with `-Mode native-posix` and rerun in both modes:
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-protected-input.ps1 -Probe bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename -Mode native-posix`
and the same command with `-Mode native-relative`. Both returned 0 after
observing that the substituted hard-link name was replaced even when the
protected original was open without delete sharing; the original bytes remained
intact. Thus the extended rename's promising reader result does not by itself
meet the draft's protected-alias check. These tests cover one controlled
substitution, not all forms of input access or path redirection.

After the owner's clarification, the same two commands were rerun with the
hard-link harness extended to snapshot the original after link creation and
again after replacement. Both modes returned 0 for guarded and unguarded runs;
the original's file identity, SHA-256, creation and last-write times, file
attributes, security descriptor and a named stream matched. The output link was
replaced in each run. Link count and filesystem change metadata are not included:
creating and removing a hard link changes link-related metadata. This remains a
single-host experiment and does not qualify the complete publication protocol.
The harness was rerun in both modes after adding independent changes to each
snapshot field as comparator controls; both runs returned 0 and rejected each
changed field. These controls exercise the comparison, not arbitrary filesystem
mutations or the production compiler.
The harness now also compares the destination's file identity to the protected
original immediately after hard-link creation, before releasing the publisher.
Both rename-mode commands above returned 0 with that assertion, so the test does
not rely only on equal file contents to establish the substituted alias.
After the owner clarified that source edits during a build need not be detected,
the guarded run was extended with a test-controlled in-place write before
publication. Both rename-mode commands returned 0: the write succeeded while
the original name was held without delete sharing, the output hardlink was
replaced, and the original retained the edited bytes and the other snapshot
properties measured after the edit. This is one host sharing combination; it
does not show that all editor save strategies work or qualify the complete
publication boundary.
The guarded case now also attempts a test-owned editor save using
`File.Replace` with a backup path. On this host it was blocked while the guard
was held, preserving the edited original and replacement; the same operation
succeeded after release. Both rename-mode commands returned 0 after this
addition. An initial use of a null backup path was rejected by the local
PowerShell/.NET binding and was replaced with an explicit test-owned path.
This is one editor-style replacement API and one host, not evidence about all
editors or a selected compiler policy.

The candidate-reopen experiment was also repeated with extended POSIX rename.
`check-reopen.ps1 -Mode native-reopen-posix` held the candidate open without
write sharing, observed a blocked write-open, moved its pathname and substituted
another file, then reopened the original handle for delete access and renamed
that original object to the destination. On this host the destination contained
the original bytes and the substituted candidate name remained untouched. Both
the extended and ordinary `native-reopen` modes passed after rebuilding the
probe. This combines candidate-object anchoring with the extended rename in one
host test; it does not bind an external verifier to those bytes or solve the
protected-destination alias race.

The command was `rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-reopen.ps1 -Probe bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename -Mode native-reopen-posix`,
with a second run using `-Mode native-reopen`. The executable was rebuilt after
the earlier hash snapshots in this file; those hashes identify earlier probe
versions.

`executable-tool-reopen.c` combines this particular candidate anchor with a
real executable-shaped test file: it passes the guarded open handle as stdin to
`llvm-readobj --file-headers -`, waits for a successful exit, reopens that object
and uses the extended rename to replace an existing output. The accompanying
`check-executable-tool-reopen.ps1` passed normal and pathname-substitution
cases, verified the published file hash against the original, checked that a
write-open of the moved candidate was blocked, and verified that invalid input
left an existing old output unchanged. Command:
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-executable-tool-reopen.ps1 -Probe bootstrap/out/executable-tool-reopen.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename`.
The probe was compiled with the same Clang target and warning flags as
`probe.c`. This is a test-only combination: the inspection's exit status is
only a header-tool result, not executable validation; tool output is discarded;
the test does not cover descendants, bounded production cleanup, destination
alias protection or production compiler integration. Streamed input remains
unselected in the draft.

After the owner's hardlink clarification, the same harness added a case that
holds the protected test input with read/write sharing but without delete
sharing, then substitutes its hardlink at the output after the candidate has
been inspected. The local command above returned 0: both guarded and unguarded
late-hardlink cases replaced the output link, published the original candidate
hash and preserved the protected input's identity, content, creation and
last-write times, attributes, security descriptor and named stream. The harness
confirmed the substituted output shared the protected input's identity before
commit. The other included controls also passed. This combines the tested
candidate inspection/reopen path and one guarded input; it does not establish
full path acquisition, all input entries, reader visibility under concurrent
replacement, complete image validation or a production publication protocol.
The harness now also tests the output name as the original input entry itself.
With the no-delete-sharing input handle, inspection succeeded but commit was
denied, and the original snapshot and candidate hash remained. In the unguarded
control the same operation replaced the original entry with the inspected
candidate, confirmed by a changed file identity. The same command returned 0
with both controls and the previous cases. This is one direct path and one host;
it does not qualify redirected parent paths, multiple inputs or a full protocol.
The same harness now has a precommit parent-junction swap control. The probe
inspected the original candidate and reopened it for commit, then the actor
moved the selected junction and put a link to another directory at that name.
The rename reported success and published the candidate in the originally
opened directory, while the selected path still named the alternate output.
The command above returned 0 after checking both observations and the other
controls. This demonstrates that holding the candidate and parent-directory
handles alone does not keep the user-selected path stable; it is not a complete
path-guard test or a production compiler result.
With the optional `-JunctionGuard` case, the same harness held the selected
junction while the inspected candidate reached the precommit barrier. The
actor's move was blocked, the candidate appeared at the selected path, and the
move succeeded after guard release. The unguarded parent-swap control and the
other included cases also passed. An initial harness run reused a junction name
between cases and failed during setup; unique per-case names fixed it before
the passing run:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-executable-tool-reopen.ps1 -Probe bootstrap/out/executable-tool-reopen.exe -Inspector 'C:\Program Files\LLVM\bin\llvm-readobj.exe' -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename -JunctionGuard bootstrap/out/native-junction-guard.exe
```

This combines candidate inspection, handle-based commit and one junction
guard on one host. The guard is acquired separately; it does not qualify the
whole path, multiple input protections, complete candidate validation,
concurrent readers or every host failure.
The guarded case was extended again to hold a protected input without delete
sharing and, at the precommit barrier, move the old output aside and substitute
a hardlink to that input. The same command returned 0: the junction move was
blocked, the inspected candidate reached the selected path, the original input
snapshot and actor-moved old output were preserved, and the junction could move
after guard release. This combines those specific guards and substitutions; it
still does not establish safe acquisition of the full path or all protected
inputs, or qualify production publication.
The same combined harness also tested the original input entry as the selected
output through the guarded junction. The attempted junction move was blocked,
inspection succeeded, the commit attempt was denied, and both the input
snapshot through the selected path and the candidate hash remained unchanged.
The guard released and the junction move then succeeded. The command above
returned 0 with this new case and all earlier controls. This covers one input,
one junction and one host; full path and input-set acquisition remain open.
The combined harness also placed the guarded junction inside an ordinary
ancestor directory and attempted to move that ancestor before commit. In the
recorded run the move was blocked, the selected path showed the candidate,
and the move succeeded after the guard was released. The command above returned
0 with that observation and the earlier controls. The harness also recognizes
and reports the adverse redirected-path outcome if the host permits the move;
it does not treat that outcome as evidence of a safe publication scheme. This
one ancestor test does not establish protection for an arbitrary path chain or
identify which open handle blocked the move.

The combined test now also opens the existing output without delete sharing.
It confirms the inspection succeeded and the native commit call was attempted;
on this host the rename returned NTSTATUS `0xC0000043`, while the old output
and candidate bytes remained intact. The same command reran the normal, swap,
invalid and locked cases successfully after rebuilding the probe. This is one
definitive observed failure, not a proof about all host failure outcomes.

The same combined harness now includes a read-only destination. Inspection and
the commit attempt were confirmed; the extended rename returned NTSTATUS
`0xC0000022` on this host and both the old output and candidate bytes remained
intact. The comparator restores the test-owned file's attribute afterwards.
The normal, swap, invalid, locked and read-only cases passed the same
`check-executable-tool-reopen.ps1` command above. This is one attribute and one
host/API combination, not a general statement about read-only replacement or
an assertion that a failed build removed its temporary candidate.

The combined harness also accepts `-StalledInspector`. With the existing
30-second test sleeper, the probe's ten-second tool wait expired, it terminated
the direct child and observed its exit, and the comparator confirmed no commit
was attempted and both old output and candidate remained intact. The command
above with `-StalledInspector bootstrap/out/stalled-inspector.exe` passed this
case alongside the other five. This test has no descendant process and does not
qualify production cancellation, Job containment, unconfirmed termination, or
temporary cleanup.

The combined test also now holds a read handle to the old output with delete
sharing during the inspected-candidate commit. The extended rename succeeded,
the destination hash matched the inspected original candidate, and the held
handle still read the old bytes. The same six ordinary cases and optional
stalled-tool case passed the command with `-StalledInspector` above. This
combines one held-reader observation with the candidate anchor; it is not a
concurrent reopen stress test or a solution for protected destination aliases.

The combined harness can also supply `-ObjectFile` as an adverse control. With
the COFF object fixture, `llvm-readobj --file-headers -` exited successfully,
and the test-only probe consequently published the object. The harness
confirmed its hash and reported that undesired outcome explicitly. The same
command above with `-ObjectFile bootstrap/out/native-handle-rename-object.o`
passed the comparison and the other cases. This demonstrates why the combined
probe's child exit is not a qualified executable-candidate check; it is not
production behavior or permission to publish an object as an executable.

The test-only probe was subsequently changed to inspect a bounded report after
the child exits and require the observed AMD64, executable-image and PE32+
header markers while rejecting the DLL marker. With `-ObjectFile` and `-DllFile`
controls, the same combined harness now rejects both before commit, preserves
the old output and candidate, and still passes the normal, swap, reader, invalid,
locked, read-only and optional timeout cases. The command is the one above with
`-StalledInspector bootstrap/out/stalled-inspector.exe -ObjectFile bootstrap/out/native-handle-rename-object.o -DllFile bootstrap/out/native-handle-rename-control.dll`.
The first compile exposed a signed/unsigned comparison warning; it was fixed
before the passing run. This is a test-only text comparison against one LLVM
version, not a selected stable parser, a complete PE validity check, or a
bounded production capture: the test report file can grow before its size is
checked. It must not be treated as production candidate validation.

The combined harness now also tests an absent destination: valid inspected input
was published with the expected hash, while invalid input left the destination
absent. The full harness command above, including the stalled, object and DLL
controls, returned 0; a subsequent run after clarifying the output text passed
without the optional stalled case. This covers these two outcomes on the current
host, not a racing creation of a destination or production cleanup.

The harness subsequently added an event-controlled creation of an ordinary
output after the probe has opened the candidate but before inspection and
commit. For valid input, the extended rename replaced that actor-created file
and the published hash matched the candidate. With invalid input, inspection
failed and the actor's bytes remained. The full non-stalled harness command
above with the object and DLL controls returned 0. This exercises the selected
ordinary-output policy at that particular event point; it does not test every
commit race or protect against destination aliases to inputs.

The combined probe now offers a second event immediately before the native
commit call, after the inspection and candidate reopen. With an ordinary file
created at that barrier, the candidate replaced it. With a hard link to a
test-owned protected input created at the same point, this intentionally
unprotected probe also replaced the alias; the protected original bytes remained.
The harness reports that as an adverse control, not a successful input-
protection check. The non-stalled combined command with object and DLL controls
returned 0 after observing both cases. This makes the remaining alias race
concrete in the same inspect-and-publish flow; no protected-set validation is
implemented by this test probe.

The combined probe now records the parent candidate handle's current position
after the inspector exits. On this host, `llvm-readobj` left it at 49,152 bytes;
the probe then explicitly rewound the guarded handle and reread the `MZ` bytes
before publishing. The non-stalled combined command with object and DLL controls
returned 0. This shows the observed inherited-handle position must not be assumed
to stay at the start; it does not establish behavior for every inspector or
concurrent reader.

The same probe now checks that its measured position equals the test candidate's
length and performs a one-byte read without rewinding; the read returned EOF.
After an explicit rewind it reread `MZ`, and the non-stalled combined command
with object and DLL controls returned 0. This is a narrow negative control for
the observed EOF position, not the future full-file hash comparison or evidence
that every tool advances a handle to EOF.

The test probe subsequently rewinds again and copies the entire guarded file to
a test-owned observation file before commit. The PowerShell comparator hashes
that copy independently and requires it to match the original fixture hash; it
also requires the empty-byte hash corresponding to the observed EOF read to
differ. The non-stalled combined command with object and DLL controls returned 0,
including pathname substitution. This is a complete-byte comparison for this
fixture and host, not a production hashing implementation or a bound on the
test-owned observation file.

## Inspecting an opened executable over stdin

`handle-rename/check-executable-stdin.ps1` copies the test probe executable,
opens it for reading without write sharing, moves its original name and puts
invalid bytes at the old pathname. A write-open of the moved original is denied.
On this host, LLVM `llvm-objdump -f -` recognized the bytes streamed from the
still-open handle as `coff-x86-64` / `x86_64`, while the invalid substituted
bytes returned a nonzero status. A separate COFF object compiled from the same
test source was also accepted and reported the same file format and
architecture, demonstrating that these `-f` checks cannot distinguish it from
the executable. The harness reads both output streams concurrently. This is a
file-format inspection, not executable verification, proof that the full binary
is sound, or a combined inspection-and-publication test. The test harness now
uses a ten-second input-copy deadline, but that does not qualify production
cancellation or bounded waits; the stream handoff remains an unselected alternative.

The object control was built with `rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -c compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/probe.c -o bootstrap/out/native-handle-rename-object.o`.
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-executable-stdin.ps1 -Objdump "C:\Program Files\LLVM\bin\llvm-objdump.exe" -Executable bootstrap/out/native-handle-rename.exe -ObjectFile bootstrap/out/native-handle-rename-object.o -OutputDirectory bootstrap/out/native-handle-rename`
returned 0 for the above positive and negative controls.

As a harness negative control, `stalled-inspector.c` was compiled with Clang for
`x86_64-w64-windows-gnu`, then supplied as `-Objdump` to the same command. It
does not read stdin and sleeps for 30 seconds. The harness returned exit 1 with
`Inspector input copy timed out` after the ten-second copy deadline and waited
for its test child after termination. The ordinary inspector case passed again
after the harness change. This tests this single stalled-child case, not the
production process-tree or every timeout/termination failure.

The separate `check-executable-headers.ps1` experiment queried
`llvm-readobj --file-headers` by pathname for the same executable and object,
and for a DLL built from `handle-rename/dll-control.c` with
`rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -shared compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/dll-control.c -o bootstrap/out/native-handle-rename-control.dll`.
The executable had AMD64, PE32+ optional-header and executable-image fields;
the object lacked the latter fields. The DLL had both the executable-image and
DLL characteristics. A test-only text comparator checked those observations
and excluded the DLL; this command returned 0:

`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-executable-headers.ps1 -Readobj "C:\Program Files\LLVM\bin\llvm-readobj.exe" -Executable bootstrap/out/native-handle-rename.exe -ObjectFile bootstrap/out/native-handle-rename-object.o -Dll bootstrap/out/native-handle-rename-control.dll`

This distinguishes these three controls only. It is not a selected parser,
stable machine-readable interface, bound to the opened candidate, or proof of
complete PE validity or loadability. A DLL's executable-image characteristic
alone is not sufficient to identify a program executable.

## Concurrent-reader observation

The test-only `handle-rename/visibility.c` first replaces an existing 65,536-byte
file without a reader as a control. It then starts a reader opening the output
with read, write and delete sharing while repeatedly attempting to replace it
with complete alternating byte patterns. The reader checks each opened handle
for exactly one complete pattern. In ten runs on this host, the no-reader
control succeeded, but the first concurrent `MoveFileExW` replacement failed
with error 5 in every run; each reader observed one complete old pattern. The
first uninstrumented run failed, after which the probe was changed to report
which operation failed. The comparator accepts this specific observed host
failure as an observation, not as a successful concurrent replacement.

Build with `rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/visibility.c -o bootstrap/out/native-visibility.exe`.
Then `rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-visibility.ps1 -Probe bootstrap/out/native-visibility.exe -OutputDirectory bootstrap/out/native-handle-rename`
returned 0 after recording those ten outcomes. No concurrent replacement
succeeded in this experiment, so it supplies no proof of old-or-new visibility
across a successful replacement, or of behavior for other APIs, sharing modes,
filesystems or production builds.

The same reader experiment was extended with the native directory-relative
`FileRenameInformation` operation used by the other handle probe. After
rebuilding, ten `-Mode move` and ten `-Mode native` runs both returned the same
observations: each no-reader control succeeded, each concurrent first rename
failed with error 5, and each reader completed one old-pattern read. The
commands were the compile command above followed by
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-visibility.ps1 -Probe bootstrap/out/native-visibility.exe -OutputDirectory bootstrap/out/native-handle-rename -Mode native`
and the same command with `-Mode move`. This does not identify why error 5
occurred or establish that a reader caused it; no successful replacement
overlapped a verified reader in either mode.

The reader test was then made event-controlled: it signals only after opening
the original file and holds that handle until the first replacement attempt has
finished. After rebuilding, ten runs each of `-Mode move` and `-Mode native`
again reported error 5 on the first attempt and one complete old-pattern read.
For a separate `-Mode no-reader` control, the same `MoveFileExW` loop completed
200 replacements in each of ten runs. These observations establish that the
reader handle was held in the tested failure cases and that repeated no-reader
replacement worked on this host. They do not identify the OS-level cause of the
error, prove general atomic visibility, or qualify native no-reader repetition.
All three modes were run using `check-visibility.ps1` as above with the
corresponding `-Mode` value.

An additional `-Mode release-first` control opens and reads the old file using
the same reader, waits for that reader to close, then runs the same 200
`MoveFileExW` replacements. After rebuilding, all 200 replacements succeeded in
each of ten runs; ten parallel comparison runs that held the reader across the
first replacement again observed error 5. This supports a distinction between
the tested held-reader and released-reader cases, but does not establish the
underlying OS cause or prove a production retry policy. The command is the same
`check-visibility.ps1` invocation above with `-Mode release-first`.

The event-controlled experiment also compared `ReplaceFileW` using `-Mode
replace`. The no-reader control succeeded. In an initial run and ten repeated
runs on this host, at least two replacements succeeded, but a subsequent
reader `CreateFileW` returned error 2 (file not found) while replacements were
ongoing; all complete reads before that reported a uniform old or new pattern.
The test treats that reader-open failure as an observed adverse outcome, not a
passing atomic-visibility result. It does not pinpoint the instant or cause of
the missing-path result, prove the state of the path after the error, or claim
the same behavior for other filesystems and APIs. The command is the same
`check-visibility.ps1` invocation with `-Mode replace`. The comparison harness
was updated after its initial expected-success run failed to record this
specific result rather than misreport it as a passing visibility test.

The harness now includes `-Mode non-atomic`, which intentionally deletes the
old name, waits five milliseconds and then moves the candidate into place.
After rebuilding, ten runs all detected a reader open error 2 during this
control; ten `-Mode replace` comparisons again observed error 2. An initial
control run also observed reader open error 5, so the harness recognizes either
open failure for the intentional control, while preserving the observed code in
its output. This demonstrates sensitivity to this constructed remove-then-move
case, not a proof that `ReplaceFileW` uses that sequence or that every gap is
detected. The command is the same harness invocation with the respective mode.

The same test was extended to native `FileRenameInformationEx` with replace
and POSIX flags (`-Mode posix`). On the reported NTFS host, ten runs completed
200 replacements each while the reader was active; every read was a complete A
or B pattern, both patterns were observed in every run, and no open error was
reported. The harness also reran the intentionally non-atomic control, which
observed an open failure in every run. The command is the same
`check-visibility.ps1` invocation above with `-Mode posix`. This is promising
evidence for the tested reader and workload, not a proof across all schedules,
filesystems or failures, and it does not solve protected-input aliases, path
races, candidate verification, cancellation or production integration. The
separate no-delete-share destination test still failed for this extended rename.

For the test directory, a separate `GetVolumePathNameW` /
`GetVolumeInformationW` probe reported root `C:\`, filesystem `NTFS`, maximum
component length 255, and flags `0x03E72EFF`; the OS version string was
`Microsoft Windows NT 10.0.26300.0`. The volume query was compiled with
`rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/volume-info.c -o bootstrap/out/native-volume-info.exe`
and run with `rtk proxy bootstrap/out/native-volume-info.exe bootstrap/out/native-handle-rename`.
This identifies the reported local volume and OS version only; it does not rule
out filter drivers, virtualization, or different behavior on another NTFS host.
The initial `Get-Volume` and `fsutil fsinfo volumeinfo C:` queries were denied
access; the Win32 query succeeded without escalation.

`check-truncated-executable.ps1` tested that same header tool against two
damaged copies of the probe executable. It rejected a 1,024-byte truncation
with an unexpected-end-of-file diagnostic. The script independently checked the
probe's `.text` raw offset and size, then zeroed all 12,800 bytes of that code
section without changing the file length; `--file-headers` still returned 0 and
reported the executable-image characteristic. The damaged image was not run.
The test demonstrates that header checks alone do not establish intact code or
correct semantics; it does not require a compiler to detect every possible
corrupted but structurally valid program.

`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-truncated-executable.ps1 -Readobj "C:\Program Files\LLVM\bin\llvm-readobj.exe" -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename`
returned 0 after observing both cases on this host.

For these executable-inspection experiments, `llvm-readobj --version` reported
LLVM 23.1.3. SHA-256 identities at the time of the checks were:

| File | SHA-256 |
| --- | --- |
| `C:\Program Files\LLVM\bin\llvm-readobj.exe` | `C6716B20621C408580DD02CD8BE67AE8885FCC533546157396ADCD556169C59D` |
| `C:\Program Files\LLVM\bin\llvm-objdump.exe` | `32EC4C63053FE3225F263E1C53B0826007379C970B0E8D6CA0E3CC78C3027202` |
| `bootstrap/out/native-handle-rename.exe` | `C454C21CE9BEB6AABA356AAEA1F5D147347DF2422B89F60879D6D7915C66813A` |
| `bootstrap/out/native-handle-rename-object.o` | `D8B3CC1E184C5605321BD8E4256218749906672FA457EDCD137734F72393FB9E` |
| `bootstrap/out/native-handle-rename-control.dll` | `6BC98801E60EEC0B16C0B42528BF566C0D50EB5938C1DA53D1A421EADA12FBB9` |

The probe was compiled with `clang.exe --target=x86_64-w64-windows-gnu -std=c17
-Wall -Wextra -Werror -municode` and checked using
`powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-link-replace.ps1 -Probe bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename`.
The existing `check.ps1`, `check-create-race.ps1`, and `check-reopen.ps1`
comparators also passed against the rebuilt probe. The hashes above identify the
earlier probe version, not this extended version.

### Inspector descendant in the combined handoff probe

The test-only executable handoff now starts its inspector suspended, assigns it
to a kill-on-close Windows job, and resumes it. It refuses to accept the report
if any job process remains after the direct inspector exits; it terminates the
job and observes an empty job before reporting this particular outcome. A fake
inspector returns zero, emits an executable header marker, and leaves a child
holding inherited standard handles. The harness observed that direct exit and
marker, confirmed the remaining job process was stopped, and checked that no
commit was attempted and both the previous output and candidate were preserved.

Both probe programs were compiled with `C:\Program Files\LLVM\bin\clang.exe
--target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode`.
The following command passed, including the existing timeout, object, DLL,
publication and protected-alias controls:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-executable-tool-reopen.ps1 -Probe bootstrap/out/executable-tool-reopen.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename -StalledInspector bootstrap/out/stalled-inspector.exe -DescendantInspector bootstrap/out/descendant-inspector.exe -ObjectFile bootstrap/out/native-handle-rename-object.o -DllFile bootstrap/out/native-handle-rename-control.dll
```

This is a test-only cooperative descendant scenario, not a production process
containment proof. The report is still captured in an unbounded file and its
text markers are not a selected production validator. Job assignment failure,
breakaway behavior, containment across other environments, and protected-input
path races remain to be resolved; the existing alias control still demonstrates
an unsafe replacement. This evidence does not qualify publication for use.

### PE structural adverse controls

`check-pe-structure.ps1` independently reads selected PE fields and checks the
entry point and section file ranges. The unchanged executable passed; four
copies with a zero entry point, an entry point at the end of the image, an
out-of-file section offset, or an oversized section were rejected by this
test-only comparator. `llvm-readobj --file-headers --sections` returned zero
and the previously used header markers matched for all four damaged copies.
A fifth copy with its entry section zeroed still passed both checks, illustrating
that these structural checks do not prove code integrity or program behavior.
No corrupted executable was run.

The following command returned 0 on this host:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-pe-structure.ps1 -Readobj "C:\Program Files\LLVM\bin\llvm-readobj.exe" -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/pe-structure
```

This comparator is an adversarial test oracle, not a complete PE validator or
a chosen production implementation. The future gate must reject the four
structural failures, bind inspection to the published bytes, and use independent
execution oracles to check generated behavior. Tool exit and header markers alone
cannot establish either property.

The PE structural control now also includes a truncated DOS header, an
out-of-file PE offset, a section count that puts its table beyond the file and
a declared optional-header length of 16 bytes. The independent comparator
rejected each. On this host `llvm-readobj` returned nonzero for the truncated
DOS header and PE offset, but returned zero for the oversized section count and
the short optional header; the latter also passed the earlier marker check.
The same `check-pe-structure.ps1` command above returned 0 with these added
cases. This remains a partial test oracle, not a complete PE validator.

As an explicit adverse control, `check-transaction-executable.ps1` accepts
`-Malformed <path>` for the generated `optional-short.exe`. It independently
checks that the declared optional header is shorter than 112 bytes, then uses
the real inspector and the test-only publication flow. In the recorded run the
header-marker wrapper accepted the malformed file and the transaction
published it; the file was not executed. The normal, swap, object and DLL
controls also passed. Reproduce by running `check-pe-structure.ps1` as above,
then substitute the `optional-short.exe` path under its printed test directory
in this command:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-executable.ps1 -Probe bootstrap/out/transaction-handle.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -Executable bootstrap/out/native-handle-rename.exe -ObjectFile bootstrap/out/native-handle-rename-object.o -DllFile bootstrap/out/native-handle-rename-control.dll -OutputDirectory bootstrap/out/native-handle-rename -Malformed <optional-short.exe>
```

This confirms a concrete failure of the experimental marker-based candidate
check, not a failure of an implemented UBE backend. A production validator
must reject the malformed candidate without publication.

The test-only `pe-structure.c` provides a separate bounded-field native probe
for the specific header, entry and file-range rules checked by the PowerShell
oracle. It uses fixed-size reads and checks ranges before seeking. Against the
ten current controls it agreed with the independently written comparator:
the intact and zero-code files passed these limited structural checks, and the
eight selected damaged cases were rejected. A build that deliberately omits
raw-section bounds checking was rejected by the comparator on the out-of-file
section case. The following command built both probe variants and returned 0:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-pe-probe-mutation.ps1 -Clang "C:\Program Files\LLVM\bin\clang.exe" -Readobj "C:\Program Files\LLVM\bin\llvm-readobj.exe" -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/pe-structure
```

This native probe is not a full PE or loader validator, does not establish code
integrity or program behavior, and is not selected for production. Passing
this finite control set does not qualify its handling of every malformed file
or prove a no-crash production implementation. A later test-only integration
with the transaction is described below.

The transaction handoff gained a test-only `-StructuralProbe` option. It runs
the native structural probe against the same held candidate handle, rewinds the
shared file position before the existing bounded header inspector, and compares
the held file's identity with the transaction-bound handle before rename. With
the structural probe enabled, `check-transaction-executable.ps1` rejected the
short-optional-header control before publication and preserved the old output
and malformed candidate. The valid executable still committed, the path-swap
control was rejected, and object and DLL controls were rejected. Running the
same harness without the structural probe again published the malformed
control, reproducing the marker-only failure. Both comparisons returned 0:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-executable.ps1 -Probe bootstrap/out/transaction-handle.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -Executable bootstrap/out/native-handle-rename.exe -ObjectFile bootstrap/out/native-handle-rename-object.o -DllFile bootstrap/out/native-handle-rename-control.dll -OutputDirectory bootstrap/out/native-handle-rename -Malformed <optional-short.exe>
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-executable.ps1 -Probe bootstrap/out/transaction-handle.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -Executable bootstrap/out/native-handle-rename.exe -ObjectFile bootstrap/out/native-handle-rename-object.o -DllFile bootstrap/out/native-handle-rename-control.dll -OutputDirectory bootstrap/out/native-handle-rename -Malformed <optional-short.exe> -StructuralProbe bootstrap/out/pe-structure-probe.exe
```

`<optional-short.exe>` is the test-owned artifact printed by the PE structural
comparator above. This integration demonstrates rejection of that particular
malformation; it is not a complete candidate validator, a qualified external
tool boundary, or a selected production mechanism.

The junction harness now also combines the native structural probe, bounded
header inspector, identity match, a read/write-sharing guard on the physical
output parent, a read-only-sharing guard on the selected-path ancestor and,
optionally, the junction guard. In both controlled runs, attempts to move the
physical output parent, candidate and destination were blocked; setting a
mount-point reparse record on the nonempty output parent returned error 145.
With the junction guard, its tested clear and move were also blocked and the
expected fixture hash was committed at the selected path. Without that guard,
the junction swap succeeded and the committed file remained in the original
directory while the selected path resolved elsewhere. Both tests returned 0;
the unguarded junction result is an adverse control:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-junction.ps1 -Probe bootstrap/out/transaction-handle.exe -OutputDirectory bootstrap/out/native-handle-rename -HandleRename -Inspect -Executable bootstrap/out/native-handle-rename.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -StructuralProbe bootstrap/out/pe-structure-probe.exe -AncestorGuard bootstrap/out/native-directory-guard.exe -ReadOnlyAncestor -GuardOutputParent -ReparseActor bootstrap/out/set-junction.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-junction.ps1 -Probe bootstrap/out/transaction-handle.exe -OutputDirectory bootstrap/out/native-handle-rename -HandleRename -Inspect -Executable bootstrap/out/native-handle-rename.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -StructuralProbe bootstrap/out/pe-structure-probe.exe -AncestorGuard bootstrap/out/native-directory-guard.exe -ReadOnlyAncestor -GuardOutputParent -ReparseActor bootstrap/out/set-junction.exe -Guard bootstrap/out/native-junction-guard.exe -RequireBlocked
```

Each held component in this experiment was acquired separately by pathname.
It is not a race-free general path walk, a complete protected-input set or a
qualified validator; the zeroed-code adverse control still passes both checks.
Failure injection, other path shapes and filesystem/TxF portability remain open.

`check-guard-acquisition-race.ps1` tests a different ordering: an actor swaps
the child junction after an ancestor guard is held but before the junction guard
opens that child. The actor redirects it to a directory whose destination is a
hard link to the original protected test file and whose local `protected.bin`
is a decoy. When the test probe derives the protected identity from the newly
redirected output path, it compares against the decoy and publishes over the
protected alias. The original protected peer's bytes remain unchanged. In the
second run, the probe receives the original protected file's independent path
and rejects the alias; the candidate and original files remain. Both runs used
the structural and header inspectors and returned the expected outcomes:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-guard-acquisition-race.ps1 -Probe bootstrap/out/transaction-handle.exe -AncestorGuard bootstrap/out/native-directory-guard.exe -JunctionGuard bootstrap/out/native-junction-guard.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -StructuralProbe bootstrap/out/pe-structure-probe.exe -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename
```

The first harness attempt reused a typed PowerShell parameter name for a process
object and was corrected before the passing run. The adverse case demonstrates
that separately acquiring a child guard after a path swap does not recover an
earlier path meaning, and that re-resolving protected identities through the
changed output path is unsafe. Supplying one independent protected path was
only a focused control, not a complete protected-set or full-path acquisition
scheme. The probe now opens and retains that independent file before candidate
inspection; the same harness passed again after this change.

`check-protected-identity-swap.ps1` then moves the protected file's original
name after inspection and puts a decoy at that name. The output destination is
a hard link to the original protected file. A deliberately late pathname
lookup compared against the decoy and allowed the test transaction to replace
the protected alias. The retained-handle mode compared against the original
file identity, rejected the alias, and preserved the candidate. Both modes
checked that the actor's moved original and replacement decoy existed as
expected, and both used the structural and header inspectors. Command:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-protected-identity-swap.ps1 -Probe bootstrap/out/transaction-handle.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -StructuralProbe bootstrap/out/pe-structure-probe.exe -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename
```

This is evidence for retaining one input identity across one pathname swap,
not a complete protected-input set, a guarantee against external changes to
the input bytes, or a qualified full path-acquisition scheme.

`check-protected-set.ps1` extends this test-only handoff to four independently
opened protected files. It checks an ordinary destination, an alias of each
file, a second hard-link name for one file, and an input pathname swapped to a
decoy after the identities were retained. The ordinary case committed; all six
alias cases were rejected and the test checked the candidate, destination and
input bytes. The script returned 0 with the ordinary probe. A separately built
`-DOMIT_LAST_PROTECTED` mutation published over the fourth input's alias, and
the comparator returned 1 on that case. An initial comparator revision waited
for the mutated probe without releasing its barrier and timed out; it was
corrected before the passing control. Commands:

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/transaction-handle.c -lktmw32 -o bootstrap/out/transaction-handle.exe
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode -DOMIT_LAST_PROTECTED compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/transaction-handle.c -lktmw32 -o bootstrap/out/transaction-handle-omit.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-protected-set.ps1 -Probe bootstrap/out/transaction-handle.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -StructuralProbe bootstrap/out/pe-structure-probe.exe -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename
```

Run the same final command with `-Probe bootstrap/out/transaction-handle-omit.exe`;
that comparator must return 1 for the deliberately omitted input. This finite
test does not implement or qualify the compiler's complete input inventory,
identity acquisition, memory/handle budgets or other filesystem behavior.

The integrated comparator now accepts `-MalformedDirectory` for all eight
damaged cases generated by `check-pe-structure.ps1`. With the native probe
enabled, it rejected each before publication and checked preservation of both
the old output and each candidate. It also accepts `-ZeroCode`, independently
checks that the executable entry section alone was zeroed relative to the valid
fixture, and observes the adverse result: both structural and header checks
accepted and published that file. It was not executed. The normal, swap, object
and DLL controls passed in the same run. Reproduce after generating the PE
fixtures, replacing `<fixture-directory>` with the printed test directory:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-executable.ps1 -Probe bootstrap/out/transaction-handle.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -Executable bootstrap/out/native-handle-rename.exe -ObjectFile bootstrap/out/native-handle-rename-object.o -DllFile bootstrap/out/native-handle-rename-control.dll -OutputDirectory bootstrap/out/native-handle-rename -StructuralProbe bootstrap/out/pe-structure-probe.exe -MalformedDirectory <fixture-directory> -ZeroCode <fixture-directory>/zero-code.exe
```

This extends the integrated control set but does not make structural validation
proof of executable behavior or qualify the finite test probe for production.

### Existing writable candidate handle

`check-preexisting-writer.ps1` opens a test candidate for reading and writing
before the existing `native-reopen-posix` guard is acquired. The guarded open
failed with sharing violation 32, leaving the old destination unchanged; the
already-open writer then changed the candidate. After closing that writer and
restoring the candidate, the guard and rename succeeded. This command returned
0 on the test host:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-preexisting-writer.ps1 -Probe bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename
```

The result covers one Windows sharing configuration and one ordinary file
handle. It does not prove protection against every writer, mapping, filesystem,
or candidate pathname substitution, and it does not qualify production handoff.

### A disqualifying marker after the diagnostic prefix

The test-only `late-marker-inspector.c` emits all markers accepted by the
experimental header comparator in its first 4096 bytes, followed by a DLL marker
after that prefix, and exits zero. The combined harness independently checks the
prefix and full report, then observes that the existing full-report comparator
rejects it before commit and preserves both old output and candidate. This
demonstrates why a retained diagnostic prefix cannot itself establish that an
entire report is acceptable. It does not qualify report text as a PE validator:
the current probe still writes an unbounded report file, and the synthetic tool
does not establish anything about actual candidate bytes.

The helper was built with `rtk proxy "C:\Program Files\LLVM\bin\clang.exe"
--target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror
compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/late-marker-inspector.c
-o bootstrap/out/late-marker-inspector.exe`. The combined command in the earlier
inspector-descendant section passed with its `-StalledInspector` option omitted
and `-LateMarkerInspector bootstrap/out/late-marker-inspector.exe` added.

### Bounded inspector handoff probe

The separate test-only `bounded-inspector.c` gives the inspector a read-only
candidate handle, starts it in a kill-on-close job, and drains stdout and stderr
concurrently while retaining at most 4096 bytes each. It accepts the experimental
header markers only for a completed, untruncated stdout report. With the real
`llvm-readobj` it observed 2606 stdout bytes and accepted the marker comparison.
The late-marker report produced 4229 bytes and was rejected as truncated. A
separate noisy inspector produced 131072 bytes on each stream; the probe drained
both, retained 4096 per stream, and rejected the truncated report. The command
below returned 0 after all three explicit observations:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-bounded-inspector.ps1 -Probe bootstrap/out/bounded-inspector.exe -Readobj "C:\Program Files\LLVM\bin\llvm-readobj.exe" -LateMarker bootstrap/out/late-marker-inspector.exe -Noisy bootstrap/out/noisy-inspector.exe -Executable bootstrap/out/native-handle-rename.exe
```

Build the probe with Clang's `--target=x86_64-w64-windows-gnu -std=c17 -Wall
-Wextra -Werror -municode`; build `noisy-inspector.c` and the earlier
`late-marker-inspector.c` with the same options excluding `-municode`. This
probe does not publish, validate PE structure, or prove correct report content
from an untrusted tool. Its success does not qualify production cancellation,
failed drain or observation, process escape, path races, or all pipe schedules.

The same comparator was extended to exercise 0, 4096, 4097 and 131072 bytes
on each stream, with different uniform bytes on stdout and stderr. The probe
checks every retained byte for the expected stream pattern and reports the
result; the harness checks counts and whether the stdout report was truncated.
Each case rejects separately altered prefix, count and truncation observations.
After rebuilding both test programs, the command above returned 0 for these
four cases as well as the real and late-marker controls. These uniform patterns
do not establish correct capture for arbitrary byte sequences, stream-specific
unequal lengths, failed reads, or every concurrent schedule.

The bounded handoff probe was then extended with the earlier descendant
inspector as a control. The direct inspector exited zero while its child kept
inherited standard handles; the probe terminated the remaining job, observed
zero active job processes, drained both pipes to EOF and rejected the report.
The full bounded-inspector command above passed again with
`-Descendant bootstrap/out/descendant-inspector.exe` appended. This is one
cooperative descendant test; the probe still does not publish and does not
qualify termination failures, escape, hostile handle injection, or production
cleanup.

An embedded-NUL adverse control exposed a defect in the earlier test-only
marker comparator: a 131-byte report placed all acceptable markers before the
NUL and a DLL marker after it; `strstr` saw only the prefix, and the bounded
probe reported acceptance. Both test-only comparators now reject a report
containing NUL before applying their text checks. After rebuilding them,
`check-bounded-inspector.ps1` passed with both `-Descendant
bootstrap/out/descendant-inspector.exe` and `-NulMarker
bootstrap/out/nul-marker-inspector.exe`. The combined handoff comparator also
passed with `-NulMarkerInspector bootstrap/out/nul-marker-inspector.exe`,
checking rejection before commit and preservation of both files. This repairs
only the experimental comparator; it does not make text markers an adequate
production PE validator.

### Transactional destination-lock experiment

The test-only `transaction-replace.c` opens an existing destination as a
transacted writer, compares its file identity with one protected test file, and
uses `MoveFileTransactedW` to replace it. `check-transaction-replace.ps1` uses
test-owned files and event barriers to try moving the destination and inserting
a protected hard link at the race point. Before the probe, it establishes that
the actor can move the destination and create the hard link without the guard.

On this host, leaving the transacted destination handle open blocked the
competing move with sharing violation `0x80070020`, but the transacted replacement
also failed with error 5; old and candidate bytes survived. Closing that handle
while retaining the transaction, then trying the actor at a second barrier,
still blocked the competing move with `0x80070020` and allowed the transacted
replacement to commit, both with and without the actor. An alias already present
at the initial identity check was rejected and the candidate remained. An
initial comparator revision tried reading the transaction-locked destination
before release and hit a sharing violation; it was corrected before the passing
run. Commands:

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/transaction-replace.c -lktmw32 -o bootstrap/out/transaction-replace.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-replace.ps1 -Probe bootstrap/out/transaction-replace.exe -OutputDirectory bootstrap/out/native-handle-rename
```

This is a promising observation for one existing destination and one NTFS host,
not a selected mechanism. The test does not establish the complete protected
set, candidate anchoring, prior open handles, parent-component substitution,
absent destinations, visibility to readers, cancellation, commit failure or
other filesystems. TxF has the portability and deprecation limitations recorded
above, and a production design must meet all of those obligations rather than
assume they follow from this single lock test.

`check-transaction-junction.ps1` then tested the missing parent-path race in
the same closed-handle transaction variant. The probe checked and locked the
original destination through a test-owned junction. After the handle closed,
an actor moved that junction and substituted one pointing to a directory whose
destination was a hard link to the protected test file and whose candidate was
different. The actor observed the new junction resolve to the protected alias.
The transaction nevertheless reported success: it replaced that alias with the
substituted candidate, left the original destination and candidate unchanged,
and left the protected peer's bytes unchanged. The harness returned 0 after
checking those observed outcomes:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-junction.ps1 -Probe bootstrap/out/transaction-replace.exe -OutputDirectory bootstrap/out/native-handle-rename
```

Therefore this pathname-based transaction experiment does not satisfy the
protected-alias or verified-candidate requirements, despite its earlier
destination-entry result. This does not rule out a different transaction scheme
with separately qualified parent and candidate anchoring.

The transaction/junction harness now accepts `-Guard`, which starts the
existing test-only read-sharing junction guard before the transaction. With
that guard held, an actor could neither clear the junction's reparse point
(open failed with sharing violation 32) nor move the junction at the
closed-handle barrier. The transaction committed the original candidate over
the original destination, the protected alias remained unchanged, and moving
the junction succeeded after guard release. The unguarded control was rerun and
again observed redirection. Both commands returned 0:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-junction.ps1 -Probe bootstrap/out/transaction-replace.exe -OutputDirectory bootstrap/out/native-handle-rename
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-junction.ps1 -Probe bootstrap/out/transaction-replace.exe -OutputDirectory bootstrap/out/native-handle-rename -Guard bootstrap/out/native-junction-guard.exe
```

This covers one junction, two attempted operations and one NTFS host. The
guard is acquired separately, not through a qualified full path traversal; the
transaction probe still reopens its candidate by name, does not account for all
inputs or pre-existing handles, and does not qualify visibility, cancellation,
failure atomicity, other reparse types or filesystems. TxF's documented
portability limitations still apply. These results do not select a production
mechanism.

`check-transaction-candidate.ps1` separately swapped the test candidate name
after the destination lock was established and its handle closed. The
transaction reported success and committed the substituted bytes while the
original candidate survived under its moved name. The command returned 0 after
observing that adverse outcome:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-candidate.ps1 -Probe bootstrap/out/transaction-replace.exe -OutputDirectory bootstrap/out/native-handle-rename
```

This is a pathname-substitution control; the transaction probe does not itself
inspect the candidate. It shows that its destination protection alone cannot
bind earlier candidate inspection to committed bytes.

`transaction-handle.c` explores another test-only variant: it opens the
candidate with a transaction-bound handle, then uses `NtSetInformationFile`
with a directory-relative rename on that handle. With no competitor it
committed the original candidate. In a second run, the actor first demonstrated
that the candidate name could be moved and restored without a guard; at the
closed-destination-handle barrier its attempted move was blocked by a sharing
violation, and the transaction committed the original candidate. Both cases
were checked by the following commands:

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/transaction-handle.c -lktmw32 -o bootstrap/out/transaction-handle.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-handle.ps1 -Probe bootstrap/out/transaction-handle.exe -OutputDirectory bootstrap/out/native-handle-rename
```

The actor did not achieve a candidate swap, so this does not demonstrate that
the rename would preserve identity after a successful swap. Nor does this test
actually inspect candidate bytes before opening the transaction. It does not
combine the junction guard, cover pre-existing handles, guarantee the selected
path, or establish reader visibility, rollback/cancellation, storage support
and other acceptance obligations. The TxF portability limitations remain.

The handle-rename harness was extended with the protected-destination race and
an alias already present at the identity check. The actor demonstrated that it
could move the destination and create a protected hard link before the guard;
at the closed-target-handle barrier, the move was blocked, and the original
candidate committed. The pre-existing alias was rejected and the candidate
remained. The same `check-transaction-handle.ps1` command above returned 0.

The handle-based variant was also run through the junction harness. Without a
junction guard, the actor swapped the junction; the directory-relative rename
committed the original candidate in the original directory while the user's
selected path now resolved to the protected alias elsewhere. With the existing
junction guard, the attempted clear and move were blocked, the transaction
committed in the original directory, and the move succeeded after guard
release. Both of these commands returned 0:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-junction.ps1 -Probe bootstrap/out/transaction-handle.exe -OutputDirectory bootstrap/out/native-handle-rename -HandleRename
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-junction.ps1 -Probe bootstrap/out/transaction-handle.exe -OutputDirectory bootstrap/out/native-handle-rename -HandleRename -Guard bootstrap/out/native-junction-guard.exe
```

The unguarded result preserves the opened candidate but does not publish at the
then-current selected pathname. The guarded result covers one controlled
junction and host; it is not a production selection or a qualification of full
path acquisition, verified input handoff, readers, pre-existing handles,
rollback, cancellation or the documented TxF portability constraints.

The transaction-handle probe now has a test-only inspection-handoff mode. It
holds a read-only, no-write-share handle, reads the nine expected candidate
bytes, then opens the transaction-bound candidate and compares their volume and
file identifiers before using the latter for rename. An uncontended handoff
matched and committed the expected bytes. In an event-controlled swap between
the first read and the transacted open, the actor moved the original and put
different bytes at the candidate name; the identity comparison rejected the
swap, preserving the old destination, moved original and substitute. A new
write-open to the held original was blocked before either handoff. Command:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-inspected.ps1 -Probe bootstrap/out/transaction-handle.exe -OutputDirectory bootstrap/out/native-handle-rename
```

After rebuilding the probe, this command, `check-transaction-handle.ps1`, and
the guarded handle-rename junction command above returned 0. The inspection is
only a nine-byte test comparison, not an external executable validator. The
inspection-handoff mode has not been combined with the full junction or reader
tests, pre-existing writers and mappings, complete protected inputs, failure
injection, all path components or other filesystems. File identity and sharing
behavior are qualified only for the observed host cases; TxF is not selected.

`directory-guard.c` tests a separate guard on one ordinary ancestor directory:
it opens the directory without delete sharing, permits read/write sharing and
rejects a reparse point. In the combined executable-inspection transaction
harness, that guard blocked a move of the ancestor while the transaction still
committed; moving the ancestor succeeded after guard release. With both this
guard and the existing junction guard, the ancestor move and tested junction
clear were blocked, and the transaction committed. An ancestor guard alone did
not block a direct move and substitution of the child junction; with both
guards, that child move was blocked and commit succeeded. The actor's selected
move-and-restore control succeeded before guards were acquired in every run.

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/directory-guard.c -o bootstrap/out/native-directory-guard.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-junction.ps1 -Probe bootstrap/out/transaction-handle.exe -OutputDirectory bootstrap/out/native-handle-rename -HandleRename -Inspect -MoveAncestor -Executable bootstrap/out/native-handle-rename.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -AncestorGuard bootstrap/out/native-directory-guard.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-junction.ps1 -Probe bootstrap/out/transaction-handle.exe -OutputDirectory bootstrap/out/native-handle-rename -HandleRename -Inspect -MoveAncestor -Executable bootstrap/out/native-handle-rename.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -AncestorGuard bootstrap/out/native-directory-guard.exe -Guard bootstrap/out/native-junction-guard.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-junction.ps1 -Probe bootstrap/out/transaction-handle.exe -OutputDirectory bootstrap/out/native-handle-rename -HandleRename -Inspect -Executable bootstrap/out/native-handle-rename.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -AncestorGuard bootstrap/out/native-directory-guard.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-junction.ps1 -Probe bootstrap/out/transaction-handle.exe -OutputDirectory bootstrap/out/native-handle-rename -HandleRename -Inspect -Executable bootstrap/out/native-handle-rename.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -AncestorGuard bootstrap/out/native-directory-guard.exe -Guard bootstrap/out/native-junction-guard.exe
```

All four tests returned 0, including the adverse unguarded-child observation.
They do not demonstrate race-free acquisition of a whole path, arbitrary
ancestors or reparse types, pre-existing actor handles, every filesystem, or a
production transaction scheme. TxF and header-only validation remain unselected.

`check-directory-reparse.ps1` tests whether the ordinary-directory guard's
read/write sharing allows a directory to acquire a mount-point reparse record
after the guard checked that it was ordinary. On this host, the actor converted
an empty directory into a junction both without and with the guard; the guarded
path then resolved to the actor's target marker. For a nonempty directory, the
same operation failed with Windows error 145 both without and with the guard.
The first harness attempt reused a typed PowerShell parameter name for the
process object and was corrected before the passing run. Commands:

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/set-junction.c -o bootstrap/out/set-junction.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-directory-reparse.ps1 -Guard bootstrap/out/native-directory-guard.exe -Actor bootstrap/out/set-junction.exe -OutputDirectory bootstrap/out/native-handle-rename
```

This adverse control shows that the tested guard alone does not keep an empty
ordinary directory's type stable. The nonempty failure does not prove general
protection for nonempty paths, all reparse operations or other filesystems; the
test does not perform publication. Any proposed path walk must address changes
between checking and using each component rather than rely on a one-time tag
check.

The guard gained a test-only read-only-sharing variant. On this host, the
empty unguarded directory again accepted a junction record, whereas the actor's
write-capable open failed with sharing violation 32 while either an empty or
nonempty directory had that stronger guard. The nonempty unguarded control still
failed to install the record with error 145. In the combined transaction
harness, a read-only-sharing ancestor guard plus the junction guard blocked the
tested ancestor move and junction clear while the inspected executable committed.
A separate `-OrdinaryChild` case used an ordinary nested output directory, with
no junction guard: the ancestor move was blocked, the transaction committed,
and the move succeeded after the guard was released. The comparator explicitly
required the observed failures and successful commit. Commands:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-directory-reparse.ps1 -Guard bootstrap/out/native-directory-guard.exe -Actor bootstrap/out/set-junction.exe -OutputDirectory bootstrap/out/native-handle-rename -ReadOnly -RequireReadOnlyObservations
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-junction.ps1 -Probe bootstrap/out/transaction-handle.exe -OutputDirectory bootstrap/out/native-handle-rename -HandleRename -Inspect -MoveAncestor -Executable bootstrap/out/native-handle-rename.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -AncestorGuard bootstrap/out/native-directory-guard.exe -ReadOnlyAncestor -Guard bootstrap/out/native-junction-guard.exe -RequireBlocked
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-junction.ps1 -Probe bootstrap/out/transaction-handle.exe -OutputDirectory bootstrap/out/native-handle-rename -HandleRename -Inspect -MoveAncestor -OrdinaryChild -Executable bootstrap/out/native-handle-rename.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -AncestorGuard bootstrap/out/native-directory-guard.exe -ReadOnlyAncestor -RequireBlocked
```

These results do not qualify guard acquisition order, handles opened before the
guard, an output parent guarded with the same sharing, arbitrary path shapes,
or all reparse and filesystem behavior. A read-only-sharing guard directly on
the output parent previously blocked the intended rename. The tested guard and
transaction are not selected as production infrastructure.

The test-only transaction probe was extended to hold the immediate output
parent with `FILE_LIST_DIRECTORY | FILE_ADD_FILE` and read-only sharing, then
use that same directory handle as the root for its handle-based rename. The
controlled actor's destination move was blocked, but the intended transacted
rename also failed with `STATUS_SHARING_VIOLATION` (`0xC0000043`) before the
staged-rename barrier. The old output and candidate hash were preserved. The
otherwise comparable unguarded transaction rollback/commit harness was rerun
and its commit control passed. Both commands returned 0:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-parent-guard.ps1 -Probe bootstrap/out/transaction-handle.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename -RequireBlockedFailure
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-rollback.ps1 -Probe bootstrap/out/transaction-handle.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename
```

This rules out the tested immediate-parent access/share combination as a
working replacement solution on this host. It does not rule out every parent
guard or transaction design; TxF and the header-only validator remain unselected.

The immediate-parent experiment also tested `FileRenameInformationEx` with
replace and POSIX flags on the transacted candidate handle. With the same
read-only-sharing parent guard, the actor move was blocked and the intended
extended rename failed with the same `0xC0000043` sharing violation; old output
and candidate were preserved. Without that parent guard, the extended rename
staged and committed the fixture successfully. The comparators explicitly
required the respective blocked-failure and commit outcomes:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-parent-guard.ps1 -Probe bootstrap/out/transaction-handle.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename -Posix -RequireBlockedFailure
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-parent-guard.ps1 -Probe bootstrap/out/transaction-handle.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename -UnguardedPosix -RequireCommit
```

Both commands returned 0 after rebuilding the probe. This distinguishes the
observed parent-sharing conflict from a blanket inability to use this extended
rename in a transaction on the test host. It does not resolve path protection,
other flag combinations or filesystem support.

The immediate-parent probe was then extended with read/write sharing but no
delete sharing on the parent. While the transaction held the target and
candidate, an actor could not move either file, and its attempt to set a
mount-point reparse record on the nonempty parent failed with error 145. Both
the ordinary and extended transacted handle renames then committed the inspected
fixture. Before acquiring the guards, the harness moved and restored each file
as an actor control; the separate empty-directory control above established
that the reparse actor can create a junction where the host permits it. Both
commands explicitly required these observations and returned 0:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-parent-guard.ps1 -Probe bootstrap/out/transaction-handle.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename -ShareWrite -ReparseActor bootstrap/out/set-junction.exe -RequireShareWriteCommit
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-parent-guard.ps1 -Probe bootstrap/out/transaction-handle.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename -ShareWrite -ReparseActor bootstrap/out/set-junction.exe -RequireShareWriteCommit -Posix
```

This tests one nonempty ordinary output parent and one mount-point operation on
the local host. It does not prove that the parent remains nonempty under every
operation, that other reparse tags cannot be set, or that pre-existing handles,
safe acquisition, all inputs, failures and filesystems are covered. It does not
select the transaction, the guard or the incomplete header inspector.

The immediate-parent test was extended with a separate actor that opened the
output directory with `DELETE | FILE_LIST_DIRECTORY` and full sharing before
the guard was acquired. Both tested no-delete-share parent modes failed to
open the directory with sharing violation 32; the old output and candidate
remained unchanged. As a control, the unguarded extended-rename variant
committed while that actor handle was open. After the actor released its handle,
the harness moved and restored the directory. The probe initially reported a
misleading additional `open failed: 0` because later API calls overwrote the
error value; it was corrected to retain each open's actual error before the
passing runs. Commands:

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/preopen-directory.c -o bootstrap/out/preopen-directory.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-parent-guard.ps1 -Probe bootstrap/out/transaction-handle.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename -Preopen bootstrap/out/preopen-directory.exe -RequirePreopenFailure
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-parent-guard.ps1 -Probe bootstrap/out/transaction-handle.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename -Preopen bootstrap/out/preopen-directory.exe -ShareWrite -RequirePreopenFailure
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-parent-guard.ps1 -Probe bootstrap/out/transaction-handle.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename -Preopen bootstrap/out/preopen-directory.exe -UnguardedPosix -RequireCommit
```

These are controlled pre-existing-handle observations on one host, not proof
that every handle or path conflict is detected. The control did not perform a
move through the held DELETE handle while the transaction was active.

`check-preopen-move.ps1` subsequently used that preopened DELETE handle to
attempt the move. In the guarded case, guard acquisition failed first; after
the probe exited, the actor moved the directory through its held handle and
the old output and candidate remained. In the unguarded case, the actor's
held-handle move during the active transaction failed with Windows error 6824;
the transaction then committed, and a new directory move succeeded after it
ended. The first comparator incorrectly assumed that the in-transaction move
would succeed; it was corrected to require the observed failure before the
passing run. The test deliberately distinguishes these observations from a
claim that an unguarded handle can redirect this particular transaction.

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-preopen-move.ps1 -Probe bootstrap/out/transaction-handle.exe -Actor bootstrap/out/preopen-directory.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename
```

The command returned 0 for this one preopened-handle configuration on the test
host. The post-transaction move used a new operation, so it does not establish
that the identical held handle would work after transaction completion. It also
does not cover other access masks, timing, path components or filesystems.

The actor and harness were then extended to retain that same DELETE handle
after the failed in-transaction attempt and retry it after the commit. The
first attempt again returned 6824; the retry through the same handle succeeded
and moved the directory containing the committed fixture. The guarded control
still failed guard acquisition and then allowed the actor's first move after
the probe exited. After rebuilding `preopen-directory.exe`, the same
`check-preopen-move.ps1` command returned 0. This supersedes the earlier
new-operation-only observation for this one host and handle configuration; it
still does not establish behavior for other access masks, timing or paths.

The inspection handoff also has a test-only executable mode. It gives the held
read-only candidate handle to the bounded inspector wrapper, which invokes
`llvm-readobj` under nested Windows jobs; after successful inspection the outer
probe matches the held handle's file identity against the transaction-bound
candidate before renaming that handle. `check-transaction-executable.ps1`
observed a successful executable case whose published SHA-256 matched the
original fixture, a pathname swap rejected by the identity comparison, and
object and DLL controls rejected before commit with old output and candidates
preserved. Both the bounded-inspector and nine-byte transaction-handoff suites
also passed again after rebuilding. The new command was:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-executable.ps1 -Probe bootstrap/out/transaction-handle.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -Executable bootstrap/out/native-handle-rename.exe -ObjectFile bootstrap/out/native-handle-rename-object.o -DllFile bootstrap/out/native-handle-rename-control.dll -OutputDirectory bootstrap/out/native-handle-rename
```

The wrapper's header-marker comparator is expressly not a complete executable
validator: the structural and zero-code counterexamples above still apply.
The outer probe discards wrapper diagnostics, and this combination has not
qualified cancellation, failed observation, all descendants, junction guards,
full protected inputs, arbitrary paths, or portable TxF support. It is a
host-only combined experiment, not a production handoff decision.

The same executable-inspection and identity-handoff variant now exposes a
test-only barrier after the transacted rename has been staged but before commit.
`check-transaction-rollback.ps1` exercised four cases: process termination
before the rename, process termination after the staged rename, explicit
rollback after the staged rename, and successful commit. After each precommit
case the old destination bytes and candidate fixture hash were present; after
commit the destination hash matched the fixture and the candidate name was
absent. At the staged barrier, a reader allowing read/write/delete sharing
observed the old bytes before each rollback, termination or commit. The actual
inspector and identity match were observed in all four cases. Command:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-rollback.ps1 -Probe bootstrap/out/transaction-handle.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename
```

The command and the prior `check-transaction-executable.ps1` controls passed
after rebuilding `transaction-handle.exe`. These are four coordinated host
cases, not a production cancellation protocol or proof for process termination
during the commit call, disk or machine failure, failed rollback observation,
all reader sharing modes or other filesystems. The header-based inspection
remains incomplete, and TxF remains unselected.

The rollback harness now accepts `-Absent` and uses the probe's test-only
transacted `OPEN_ALWAYS` destination. It independently confirms the destination
is initially absent and still returns file-not-found to an outside reader after
the candidate rename is staged. Termination before or after staging and an
explicit rollback all left the destination absent and the candidate hash
unchanged; the commit control published the matching executable. A competing
create succeeded in a pre-transaction control, but at the held transaction
barrier it failed with HRESULT `0x80071A90`; the transaction then committed.
The command below returned 0 after rebuilding the probe:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-rollback.ps1 -Probe bootstrap/out/transaction-handle.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename -Absent
```

This is a controlled initially-absent case on the tested NTFS host. It does not
establish absent-path behavior through substituted parent components, other
competing operations, failure during commit, all filesystem configurations or
TxF availability. Preventing this particular concurrent ordinary create is
compatible with the approved policy permitting a successful build to overwrite
an ordinary file; it does not demonstrate every concurrency behavior.

`check-transaction-commit-race.ps1` released the post-staging barrier and then
attempted to terminate the test process at delays of 0, 1, 5 and 20 ms, three
times each. It independently classified final files as the complete old state
with the original candidate or the complete new executable with no candidate
name. In the recorded run all 12 outcomes were new. Termination was issued in
the three zero-delay runs; in those runs the commit message was not observed,
even though the new bytes were present. The other nine processes completed and
reported commit. The earlier staged-barrier termination case separately
observed rollback, before release. Command:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-commit-race.ps1 -Probe bootstrap/out/transaction-handle.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename
```

This shows why lack of a completion message after an externally terminated
process cannot be treated as proof that the old file survived. It does not
establish where termination landed inside the commit call, exercise both race
outcomes after barrier release, implement cooperative compiler cancellation,
or prove crash durability. The distinct indeterminate-outcome policy remains a
proposal; this test does not implement or qualify it.

The junction harness was then extended to use that external inspector and a
real executable fixture rather than the nine-byte candidate. Four runs combined
external inspection, held-file identity comparison, transaction-bound handle
rename and the direct-junction or ancestor move. With the junction guard, both
attempted path changes were blocked, the published file's SHA-256 matched the
fixture, and the moved component became movable after guard release. Without
the guard, both path changes succeeded and the inspected executable was
committed in the original directory while the selected path resolved elsewhere.
All four invocations below returned 0; the unguarded results are adverse
controls, not successful publication at the selected pathname:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-junction.ps1 -Probe bootstrap/out/transaction-handle.exe -OutputDirectory bootstrap/out/native-handle-rename -HandleRename -Inspect -Executable bootstrap/out/native-handle-rename.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe"
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-junction.ps1 -Probe bootstrap/out/transaction-handle.exe -OutputDirectory bootstrap/out/native-handle-rename -HandleRename -Inspect -Executable bootstrap/out/native-handle-rename.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -Guard bootstrap/out/native-junction-guard.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-junction.ps1 -Probe bootstrap/out/transaction-handle.exe -OutputDirectory bootstrap/out/native-handle-rename -HandleRename -Inspect -MoveAncestor -Executable bootstrap/out/native-handle-rename.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe"
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-junction.ps1 -Probe bootstrap/out/transaction-handle.exe -OutputDirectory bootstrap/out/native-handle-rename -HandleRename -Inspect -MoveAncestor -Executable bootstrap/out/native-handle-rename.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector "C:\Program Files\LLVM\bin\llvm-readobj.exe" -Guard bootstrap/out/native-junction-guard.exe
```

The wrapper still uses the deliberately incomplete header-marker comparator.
The junction guard is separately acquired and covers one known component; this
does not prove safe traversal of the whole path, full protected-set identity,
failure/cancellation handling, all reader modes, other environments or TxF
availability. No production scheme is selected by this result.

The junction harness now has `-Inspect`, combining the nine-byte inspected
handle, transaction identity comparison and handle-based rename with the
junction race. Without the junction guard, an actor redirected the selected
path after the identity match; the original candidate was committed to the
opened original directory while the selected path resolved elsewhere. With
the guard, the tested junction clear and move were blocked, the expected
candidate committed at the selected path, and the move succeeded after guard
release. The same pair of observations occurred with `-MoveAncestor`, where
the actor moved the parent containing the guarded junction. An unguarded
move-and-restore control succeeded before the handles were opened in each run.
All four commands returned 0:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-junction.ps1 -Probe bootstrap/out/transaction-handle.exe -OutputDirectory bootstrap/out/native-handle-rename -HandleRename -Inspect
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-junction.ps1 -Probe bootstrap/out/transaction-handle.exe -OutputDirectory bootstrap/out/native-handle-rename -HandleRename -Inspect -Guard bootstrap/out/native-junction-guard.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-junction.ps1 -Probe bootstrap/out/transaction-handle.exe -OutputDirectory bootstrap/out/native-handle-rename -HandleRename -Inspect -MoveAncestor
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-junction.ps1 -Probe bootstrap/out/transaction-handle.exe -OutputDirectory bootstrap/out/native-handle-rename -HandleRename -Inspect -MoveAncestor -Guard bootstrap/out/native-junction-guard.exe
```

These are coordinated host probes, not proof of safe guard acquisition for an
arbitrary complete path, executable verification, all pre-existing handles,
failure atomicity, or other filesystems. The guarded ancestor denial does not
identify which held handle caused it. TxF remains unselected and discouraged
by Microsoft for future reliance.

The handle-transaction harness also tried opening the old destination for read
at the closed-target-handle barrier, keeping successful readers open through
commit. Both sharing configurations opened successfully before the transaction.
While it was active, a reader sharing only reads received sharing violation 32;
a reader allowing read, write and delete sharing opened and observed `old`.
That held reader continued to observe `old` after the commit, while the path
contained `candidate`. The same `check-transaction-handle.ps1` command returned
0 and recorded these observations. This exposes an availability tradeoff while
the transaction is held. It is not a repeated concurrent-reader visibility
test and does not prove old-or-new observations across the actual commit or
for other reader sharing modes and filesystems.

`transaction-reader.c` and `check-transaction-visibility.ps1` subsequently
ran a reader that repeatedly opened the destination with read/write/delete
sharing across five separate transaction commits. Barriers required an old
observation before each commit and a new observation afterward, with the reader
continuing until the new observation. All five runs committed and observed only
complete old or new bytes; each recorded zero missing paths, sharing/access
errors, other open errors and invalid contents. The same harness ran five
deliberately non-atomic delete-then-move controls; every run observed thousands
of missing-path errors, demonstrating sensitivity to that gap. Commands:

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/transaction-reader.c -o bootstrap/out/transaction-reader.exe
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/non-atomic-replace.c -o bootstrap/out/non-atomic-replace.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-visibility.ps1 -Probe bootstrap/out/transaction-handle.exe -Reader bootstrap/out/transaction-reader.exe -OutputDirectory bootstrap/out/native-handle-rename -RequireNoOpenErrors
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-visibility.ps1 -Probe bootstrap/out/non-atomic-replace.exe -Reader bootstrap/out/transaction-reader.exe -OutputDirectory bootstrap/out/native-handle-rename -ExpectMissing
```

This covers five short-file commits with one permissive reader sharing mode on
the test host; the earlier read-only-sharing denial remains. It is not proof
for every schedule, file size, reader mode, failure or filesystem, and does not
resolve the rest of the publication contract or select TxF for production.

The bounded probe now also checks direct tool failure and timeout. A controlled
inspector emitted all positive marker strings and exited 41; the probe observed
that status, drained the pipes and did not accept the report. A stalled direct
inspector was terminated after the probe's test-only ten-second timeout; the
probe observed its exit and both pipe EOFs. After rebuilding the probe and
`error-inspector.c`, the bounded-inspector command above returned 0 with
`-Descendant bootstrap/out/descendant-inspector.exe -NulMarker
bootstrap/out/nul-marker-inspector.exe -ErrorInspector
bootstrap/out/error-inspector.exe -StalledInspector
bootstrap/out/stalled-inspector.exe`. This confirms those controlled cases only;
it does not qualify denial of termination or observation, production timeouts,
or process-tree behavior outside the tested job.
