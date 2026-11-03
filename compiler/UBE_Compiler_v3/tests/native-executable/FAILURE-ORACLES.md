# Tool and publication oracle: review draft

These are independent future acceptance experiments, not results. Supply a
controlled child executable and filesystem fault boundary to the real compiler
through a test-only seam. The seam must preserve production argument building,
waiting, cancellation and publication; it may inject outcomes and observe
events but may not perform publication on the compiler's behalf. Every run
records the exact compiler/tool identity, argument vector, fault activation,
child identity and exit, compiler result, destination bytes, and temporary and
handle inventory. A deliberately untriggered injection must fail its test.

`diagnostics.json` supplies 24 exact status/stdout/stderr vectors for the selected
new-command interface in `../../NATIVE-BUILD-DIAGNOSTICS.md`. Its paths are
controlled display inputs; use corresponding test-owned paths or explicitly
substitute the independently known display spelling when exercising the real
compiler. Compare UTF-8 bytes without BOM or newline normalization. Console
confirmation vectors describe formatter output; also test actual Unicode
console rendering separately. The retained frontend cases keep their existing
streams and bytes. These definitions are not executed native-build results.
Exercise missing versus empty capture, partial records, wrong stream/line ending,
denied diagnostic writes and postcommit warning/confirmation failures alongside
the output-preservation conditions below. A partial-write fault must confirm
the exact prefix delivered and reject an appended fallback.

For each row run with destination absent and with a closed existing destination
containing bytes `55 42 45 00 FF 0A` (SHA-256 calculated by the harness before
the run). For precommit failures, require non-success, exact old bytes or
continued absence, no live child/worker and no owned temporary when termination
and cleanup can be confirmed. Injected cleanup denial is an exception to the
temporary condition: report the surviving path, then remove it from the harness
after checking. If termination or observation is deliberately denied, require
an explicit unconfirmed-cleanup result and no publication; the harness must
account for and stop its own test process after observation rather than claim
the compiler proved it stopped. For identity-race experiments that deliberately
replace the destination or parent entry, compare against the test actor's last
mutation and verify the compiler makes no further change and protected inputs
remain intact; the compiler cannot preserve a sentinel that the actor removed.
Confirmed postcommit and indeterminate commit
cases have their separate observations below; an indeterminate result must not
be asserted to have preserved either the old or new bytes.
Run each case with one and four workers and repeat with a destination path that
contains a space and an ampersand; verify the tool receives it as one argument.

The owner-approved default output location also needs these independent checks
through the real build command. Use a project whose directory and filename
contain spaces, invoke from a different working directory, and observe the
actual executable path and bytes. These are future acceptance cases, not
results:

| Output selection case | Required observation |
| --- | --- |
| No output option and no `build` directory | Create `build` alongside the project and publish `<project-name>.exe` there, using the manifest's original `Name` spelling rather than the manifest filename; run the published executable against its value oracle. Use different valid manifest and filename names to distinguish them. |
| No output option and an existing destination | Publish the new executable at the same default path; on injected precommit failure preserve its previous bytes. |
| Successful build over an existing destination | Replace it without requesting input or overwrite confirmation; verify the final bytes and run the executable against its value oracle. |
| Default `build` directory cannot be created, or its name is occupied by a file | Return a controlled failure and publish no executable; preserve any existing inputs. |
| A UBE-valid manifest `Name` cannot be used as a Windows filename | The default path fails with a controlled output-path error and no publication; the same project can build with an explicit valid destination. First establish that the fixture is accepted as a project name. |
| Explicit destination in a different existing directory | Publish only at the selected path, resolved relative to the invocation directory when relative; run the executable against its value oracle. |
| Default directory or destination initially aliases a protected input | Reject safely before publication; protected bytes remain unchanged. The separate late input-hardlink case below has the owner's clarified successful-replacement behavior. |
| Output option without a value | Return the usage failure without starting a tool or publishing an executable. |
| Project omits optimization and debug settings | Build with the documented optimization 2 and Full debug-information defaults; verify the applicable generated information as well as the executable result. |
| Explicit valid build setting is not implemented | Reject it with a clear unsupported-setting diagnostic before publishing; never silently substitute another setting. This does not permit rejecting the defaults or `DebugInformation = "None"` at optimization 2. |

Check the complete valid settings matrix: optimization 2 with Full or None
must build whether each value is explicit or supplied by its documented default;
all other valid combinations must produce the unsupported-setting diagnostic
before tool launch. Check that explicit `2`/`Full` and the omitted defaults
select equivalent settings, and execute both against the independent result;
different manifest paths do not imply byte-identical artifacts. Test an invalid
value separately and require its existing
project diagnostic, not the unsupported-setting diagnostic. The matrix is a
future acceptance test and does not claim current native support.
Also pair an invalid value with a valid unsupported value and require the project
diagnostic. For a valid pair where both values are unsupported, require UBE1500
to identify `Optimization` according to the proposed deterministic precedence;
when only debug information is unsupported, identify `DebugInformation`. Assert
that none of these rejected cases launches a native tool or changes the output.

Frontend-only evidence: `check-setting-admission.ps1` exercised all 15 valid
explicit pairs and nine pairs containing an invalid value with jobs 1 and 4.
It passed 48 checks for each stage-built CLI from
`bootstrap/out/semantic-cli/e5b3d482d7fd46539e190ea70d20ecef`, using
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/check-setting-admission.ps1 -Compiler bootstrap/out/semantic-cli/e5b3d482d7fd46539e190ea70d20ecef/stage1/ube.exe -OutputDirectory bootstrap/out/native-settings-admission`
and the same command with `stage2/ube.exe`. Valid pairs exited 0 without output;
invalid pairs exited 1 with UBE1306. The first attempt lacked the UBE source
header and failed with UBE1100; after correcting the test source, both commands
passed. This checks frontend admission only, not native option handling or the
proposed UBE1500 precedence.

For the default Full-information case, use a fixture with two source files,
and separately exercise every ordinary admission mutation and resource boundary
listed in `../../NATIVE-DEBUG-CONTRACT.md`. The maintained host CU-identity probe
and its limits are recorded there; it does not qualify the production gate.
For the independent semantic debug comparison, use two source files,
distinct procedure and local names, and executable statements on different
lines. Independently inspect the same raw module and linked artifact with a
qualified debug-information reader: require the correct original file names,
procedure ranges, statement locations and declared parameter/local names and
types for code retained in the artifact. Verify the mappings against hand-authored
source coordinates and record tool and artifact identities. If optimization
inlines a procedure, check its source association and call site; if it removes
code or a runtime value, distinguish absence or unavailability from a fabricated
range or location. Require source identities and declared type/scope information
to remain checkable even where runtime locations are unavailable.
Change a source coordinate, procedure association and variable type separately
in the expected data; each comparison must reject the mutation. These are
proposed future checks; they do not claim interactive debugger support.
For the same inputs and optimization settings, separately execute Full-debug
and no-debug builds, comparing independently expected
results and externally observable side effects. Assert that the debug mapping
and any available variable locations describe the actual optimized executable;
detect absent or optimized-away locations without inventing values. Include a
wrong-location or wrong-value control. Do not require identical machine code
or timing, and do not claim an interactive debugger has been tested by these
artifact checks alone.
Both Full and None at optimization level 2 are required for this comparison;
unsupported-setting rejection is not a passing outcome for either one.
Apply the comparison to the admitted independent native value and runtime-error
fixtures, including the same-thread Err observer and side-effect cases, on both
qualified compiler stages. Run each configuration against its independently
authored expectations as well as comparing the pair; matching wrong results do
not pass. Record both builds' settings, sources, compiler and executable
identities and full process observations.
`additional/debug-sources/DebugSources.UBE` and `DebugSourcesNoDebug.UBE`
name the same package and source files. The first selects the documented Full
and optimization-2 defaults; the second explicitly selects None and optimization
2. Both expect exit 8. The additional frontend admission script accepted both
with jobs 1 and 4 on each 25f stage-built CLI; execution and debug inspection
are untested. The manifest paths differ, so this is a behavioral comparison,
not an assertion of identical raw module bytes.
On the current host, `rtk proxy objdump --version` reported GNU objdump
2.47.20260726 and `rtk proxy objdump --help` listed DWARF info and decoded-line
inspection and PE targets. This identifies a candidate reader only; option
availability does not qualify its interpretation, establish support for the
actual generated format, or replace the required positive and negative probes.
The separate `debug-reader/check.ps1` probe compiled a small C fixture to
Windows x86-64 COFF at optimization 2 with DWARF 4 and checked source line,
procedure, parameter and local records with this objdump. It passed and rejected
both a wrong procedure expectation and an object compiled without debug info.
Command: `rtk proxy powershell -NoProfile -File
compiler/UBE_Compiler_v3/tests/native-executable/debug-reader/check.ps1 -Clang
"C:/Program Files/LLVM/bin/clang.exe" -Objdump
"C:/Users/Ubehage/Documents/WinLibs/mingw64/bin/objdump.exe" -OutputDirectory
bootstrap/out/native-debug-reader`. The first run exposed a probe error: putting
`-gdwarf-4` after `-g0` enabled debug information, so the no-debug control
correctly failed. Reordering flags fixed the probe and the second run passed.
This is C/COFF object evidence, not a linked executable or UBE-generated debug
information and not qualification of the eventual debug reader.
The same host harness now also runs its optimized debug and no-debug C-linked
executables, requiring full process exit 8 for each and rejecting a wrong
expected value of 7. The updated command with
`-OutputDirectory bootstrap/out/native-debug-reader-debug-equality` returned 0
alongside the existing metadata controls. This simple C fixture has no separate
observable side effect or Err and may be folded by optimization; it does not
establish behavioral equivalence for UBE-generated programs.
The host harness was then extended with `debug-reader/behavior.c`, which reads a
volatile runtime input and checks that a non-inlined function increments a
volatile counter once. Optimized debug and no-debug executables both returned 8;
the debug executable had the named fixture's records, the no-debug control did
not, and a debug build mutated to increment twice returned 99. The harness
command above with `-OutputDirectory bootstrap/out/native-debug-reader-behavior-v2`
returned 0. The side effect is observed through the program's exit check; this
is still a C host example without UBE Err or a general equivalence proof.
For that passing run, SHA-256 identities were: Clang
`F3425B2BFF01BC401C84AF6E5E180629182FAFC2EB35CF971A3E50C9CF13F263`, objdump
`2705F05155495673E573BEA229ADAC90A2D89DE08855669D63B3D3663F7A80BB`, probe
script `7EB3D9FC313F44E3EE398789E59C80AF9649F03E67E85B61C606669005566D97`,
source `57EDE647063EA3E7DE3A36F0DF759D4B7F3417467EA6A5922578549F6065B12D`,
debug object `1E43E5725A3E2C85DF374D698EE22B4B25DECECCE3419AF4ABDD9DE90BC7E53D`
and plain object `610132F285BACA6BFE261DF905E259D76B25996BEFA2ACA3BD560B1C649634CD`.
The probe script was then extended to link both debug and no-debug Windows
executables and inspect them as well. The same command returned exit 0 and
reported object and linked checks with four negative controls. The revised
script SHA-256 is `4C5CDEEFAF79E14E0ABA019581E3F5269C3A6AB5B148CBF6C11A8551B07F43ED`;
the debug executable is `09108B2F3FD37257AAE530B7E4CE569CD98528201C74929635274C787451144D`
and the plain executable is `44BB183F6A3CC245328E618D0A21E153A1DC43F28B8BB5709C9D8B7EDA44A068`.
This extends the candidate reader evidence to a C-linked executable; it still
does not establish UBE-generated debug information or full reader qualification.
The reader check was then tightened to require procedure, parameter and local
records within the compilation unit naming `debug-reader/probe.c`, rather than
accepting unrelated runtime-library records elsewhere in the linked file. The
same command again passed the object and linked checks and four controls. This
revision's script SHA-256 is
`F80605A525777D9C4C477D8971F2FAD90B03698DF11C3465443A2BEE5BDE8E20`.
The harness now also links the no-debug fixture object with a separate object
containing unrelated debug records. It confirms those unrelated source and
function records exist, then rejects the resulting executable as evidence for
the fixture's required debug records. The following command returned 0 with
the existing debug, plain, linked and side-effect controls:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/debug-reader/check.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -Objdump 'C:\Users\Ubehage\Documents\WinLibs\mingw64\bin\objdump.exe' -OutputDirectory bootstrap/out/native-debug-reader-unrelated
```

This is a controlled C-linked counterexample to checking for arbitrary debug
records; it does not qualify the UBE production build or debug reader.
`additional/debug-sources/DebugSources.UBE` supplies such a future fixture:
`App.bas` has `Main` on line 3, locals `sourceValue` and `doubled` on lines 4
and 5, and the conditional result assignment on line 7. `MathOps.bas` has
`DoubleIt` and its parameter `value` on line 4, local `factor` on line 5,
side effect `hits` on line 6, and its result assignment on line 7. All named
values are Long; the executable expects exit 8 and returns 99 if the side effect
does not occur exactly once.
The local frontend admission script passed at jobs 1 and 4. The first attempt
used reserved `input` as a variable and produced UBE1204 at line 4, column 9;
the fixture was corrected before the passing checks. Native debug information
and execution have not yet been tested.

The host-only `verifier/check-preservation-comparator.ps1` compares a file's
content hash, creation and last-write times, attributes, security descriptor, Windows file
identity and one named stream. The command below returned 0: an unchanged file
matched, while separate creation-time, last-write-time, attribute, security-descriptor, named-stream
and same-bytes identity changes were rejected. The latter four controls check that no other compared property
explains rejection. This is one supported host filesystem and stream; it does
not inject a compiler failure or qualify the complete preservation oracle.

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-preservation-comparator.ps1 -OutputDirectory bootstrap/out/preservation-comparator
```

The same comparator was applied to the test-only TxF rollback experiment with
an existing destination, using this command:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-transaction-rollback.ps1 -Probe bootstrap/out/transaction-handle.exe -Wrapper bootstrap/out/bounded-inspector.exe -Inspector 'C:\Program Files\LLVM\bin\llvm-readobj.exe' -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename -CheckMetadata
```

It returned 0 after verifying unchanged snapshots for termination before the
rename, termination after staging, and explicit rollback; the successful commit
control also passed. This is evidence for those controlled host cases, not a
production build failure or a qualification of TxF as UBE's publication method.
Adding the test-only `-CorruptMetadata` switch changed only the old output's
last-write time after explicit rollback; the harness returned 1 with
`Output metadata changed after rollback`. The same command without the switch
returned 0. This confirms the integrated rollback comparator detects that
particular metadata-only mutation.

| Case and independently controlled event | Required outcome |
| --- | --- |
| Missing executable, or process creation denied | Launch is attempted once, no child starts, controlled failure; old destination intact. |
| Tool attempts to read standard input | The test child must receive EOF promptly, without reading the user's console or waiting for input. Independently confirm that the inherited input handle is usable and EOF-producing; a child that never reads cannot prove this. Failure to prepare the handle is a controlled prepublication failure. The host `job-containment/drain.c` probes the NUL-handle case, not the production compiler boundary. |
| Process is created suspended but Job assignment or setup fails | Independently confirm the failure was reached before resume. The controlled child must not run its first-instruction marker; terminate and observe it, close owned handles, report a prepublication failure and preserve the old output. Inject termination/observation failure separately and require explicit unconfirmed cleanup without publishing. Include a successful assignment-and-resume control so a marker that never works cannot pass the test. |
| Selected tool pathname is replaced between identity capture and process launch | Use two distinguishable test tools and a controlled barrier. Independently establish which image actually ran. The build must either run the tool whose identity it records for the selected invocation, or report a controlled failure before publication; a hash of a fresh pathname lookup alone is not evidence of the launched image. Include an unchanged-tool success control. Exercise each directly selected tool separately; do not infer the identities of its descendants from the parent image. |
| An ambient Clang config or default-library directive requests an unselected input | The selected command disables default config and COFF default-library discovery while linking its explicit support sequence. Use unique invalid-config/missing-library markers: protected controls build, and deliberately omitted protections fail with those markers. Other object directives still require the cohort's explicit policy; `/nodefaultlib` does not disable every directive. The host `verifier/check-explicit-link-inputs.ps1` checks both omission controls, not the production launch boundary. |
| A required explicit support input is absent or its cohort identity does not match | Return controlled precommit failure; do not search PATH, another installation or bare library names as fallback. The independent fixture must include a differently identified same-name alternative to prove it was not selected. Inspect ordinary embedded-member archives and reject unqualified thin archives, scripts or bitcode inputs. |
| Parent environment requests tool argument rewriting, alternate library search or additional output | Construct the selected child environment without inheriting those variables. Use controlled markers and an unchanged-parent comparison; verify arguments, inputs and owned side outputs at the actual launch boundary. The parent environment is not modified. The explicit-input host test uses the allowlist but does not yet inject every possible parent override. |
| Driver can select different linkers | Use the same driver with two distinguishable test linkers and prove which child actually ran. Require the selected linker and support-input identities to be accounted for independently of the driver, or fail safely before publication if the selected boundary cannot establish them. Include a control that incorrectly records the first linker while invoking the second. `verifier/check-driver-linker-identity.ps1` demonstrates one host driver's selection behavior; it does not inspect a compiler build or prove a production child-identity mechanism. |
| A junction or other supported path component in the selected tool path is replaced after the tool file is opened but before launch | Point the original and replacement paths at distinguishable test tools, independently establish the guarded original identity, and confirm which image actually runs. Require that a successful build runs the intended recorded tool or that the build fails safely without publication. Include an unguarded adverse control that demonstrates the substitution took place and an unchanged-path success control. `verifier/check-tool-junction.ps1` demonstrates this gap for one host combination; it is not a test of the compiler boundary. |
| Child starts, records its argument vector, writes candidate prefix, exits 41 | Observe 41 and the exact vector; compiler reports failure and removes prefix. |
| Child exits 0 without creating candidate | Compiler reports missing output and does not publish. |
| A controlled linker substitutes a prebuilt test executable whose entry point creates a marker file | Build an admitted UBE project with the linker seam producing that executable as its candidate. Independently compare the published bytes with the intended test executable. A successful build leaves the marker absent, establishing that the build did not execute this particular fixture. The test harness then runs the published fixture itself and confirms the marker appears, proving the fixture and observation can detect execution. Check compiler and tool processes have finished before the first observation. The marker executable is test infrastructure, not a claim that file I/O is in the admitted UBE subset; also retain normal-linker acceptance tests. |
| Detectable circular initialization references | Build the direct and helper-mediated cycle fixtures successfully with a nonfatal warning, including when output is redirected, and no interactive prompt. Independently verify warning severity and useful source location through the selected compiler/IDE diagnostic boundary. Direct and helper-mediated non-circular early-access fixtures, including a back-reference in an uncalled helper, are no-cycle controls. Mutate the expected severity and location and require the comparator to reject both. Use the selected UBE1514 format in `NATIVE-BUILD-DIAGNOSTICS.md`; warning analysis and IDE transport remain unqualified. This is a future build/IDE gate, not a claim that the current `--check` path emits a warning. |
| Child exits 0 after writing a target-architecture object file in place of an executable | The candidate check rejects the wrong artifact and leaves the old output intact. Include an object that a format/architecture-only tool accepts as COFF x86-64; accepting that description alone is not proof of an executable. |
| Child exits 0 after writing a DLL in place of an executable | The candidate check rejects the wrong artifact and leaves the old output intact. Include a DLL with the executable-image characteristic set; that characteristic alone does not distinguish it from an executable program. |
| Tool exits 0 after discarding invalid debug information in a Full build | Require a controlled prepublication failure and unchanged old output. Independently observe the discarded information, including when its warning occurs after the retained diagnostic prefix. A valid Full build is the success control. The host-only debug-version probe demonstrates one such tool outcome; it does not establish the production gate. |
| Linker exits 0 after removing required debug information from a Full build | Confirm the input object contains the required debug records, then have a controlled linker remove them from the final executable. The build must fail before publication and preserve the previous output; a normal link is a success control. Independently inspect the final artifact rather than relying on the compiler object's records. The host debug-version probe demonstrates a strip-debug control, not a production gate. |
| Child exits 0 after writing an image with a nonempty section outside its declared image size | Require rejection and preservation of the old output; retain the original executable as a success control. Cover a section beginning at the image end and one starting inside but ending past it. The host-only `handle-rename/check-pe-section-outside-image.ps1` exercises both against experimental probes and omitted-check controls; it does not test the production boundary. |
| Child exits 0 after truncating a required header, section table or raw section of an executable | The candidate check reports unusable output and does not publish. Establish the truncation and affected required range independently and compare the previous output or continued absence. Removing optional trailing bytes alone does not establish that an image is unusable. Header acceptance alone does not prove code integrity or program semantics. |
| Child exits 0 with a PE candidate whose entry point is zero or outside its declared image | Reject before publication and preserve the old output or absence. Establish the altered fields independently and include the unchanged executable as a passing control. |
| Child exits 0 with an import directory in an in-image gap, headers or zero-filled tail | The selected `NATIVE-CANDIDATE-REVIEW.md` profile requires initialized section backing. Independently establish the mutated range, require rejection and preserve the old output or absence. Include an unchanged output as a passing control. `handle-rename/check-pe-image-layout.ps1` tests all three cases and the omitted-layout probe accepts them; this is host profile evidence, not a universal Windows loader rule or production publication test. |
| Child exits 0 with a PE section's raw offset or length outside the file | Reject before publication and preserve the old output or absence. Check arithmetic without overflow and independently establish the bad range. |
| Child exits 0 with an otherwise unchanged PE candidate whose initialized section's raw offset violates `FileAlignment` | Reject before publication and preserve the old output or absence. Independently check the alignment and that the altered section remains within the file; include the original as a success control. The selected layout profile enforces alignment; the earlier omitted-alignment configuration in `handle-rename/check-pe-alignment.ps1` remains an adverse control, not an acceptance test of a compiler. |
| Child exits 0 with an incomplete PE32+ optional header or a section table extending beyond the file | Independently establish the truncated or impossible bounds, reject the candidate before publication, and preserve the previous destination or continued absence. A successful header-listing tool exit or marker match is insufficient. |
| Child exits 0 with a PE32+ directory count exceeding the space declared in its optional header | Independently establish the count and header capacity, reject before publication and preserve the previous destination or absence. Include the original file and an omitted-check comparator control. The host-only `check-pe-directories.ps1` is a focused probe, not a compiler acceptance result. |
| A report-based validator receives apparently acceptable markers in its first 4096 bytes and a disqualifying marker later | A truncated diagnostic prefix alone must not authorize publication. Observe the full controlled report and require the selected validation path to reject it or fail safely when it cannot validate the complete report; retain the previous output. |
| A complete tool report contains an embedded NUL before a disqualifying marker | Validate the entire length-delimited report or reject the malformed report; never treat the NUL-terminated prefix as the entire report. Independently verify the later marker and preserve the old output on rejection. |
| A tool or controlled actor retains a writable candidate handle when the compiler attempts to establish its inspection guard | Establish independently that the handle can write. The guard must fail safely or otherwise prove the writer can no longer change the inspected object; do not inspect and publish based on an unprotected candidate. Preserve the old output, then release the handle and run an uncontended success control. Also test writable mappings separately. |
| Generated LLVM is malformed | Real LLVM validation rejects it; no accepted executable is published, regardless of whether a child could create a file. |
| An LLVM input's parent path is redirected while its original file is held | With a controlled junction and independently distinct valid/invalid IR files, attempt the parent swap after the input guard is acquired and before the selected tool reads. A successful build must use the intended guarded bytes; otherwise fail safely before publication. Confirm the actor reached the barrier and retain a no-guard adverse control. `verifier/check-ir-junction-swap.ps1` shows final-file guarding alone is insufficient for one host path; it is not a compiler acceptance test. |
| Candidate creation, write, flush, close, or full-disk write fails | Independently observe the selected failure point and controlled failure; old destination intact. |
| A precommit failure occurs with an existing executable carrying distinctive metadata | With no concurrent actor, snapshot the destination's file identity, bytes, creation and last-write times, attributes and security descriptor, plus a distinctive named stream where supported. Inject a confirmed precommit failure and compare those properties after the compiler returns. Do not treat host-managed last-access updates as writes by the compiler. Include a test-only mutation that changes a checked property while preserving the main file bytes; the comparator must reject it. |
| Replacement fails with an existing destination and separately with none | Record host failure at replacement; old bytes or absence remain intact. |
| Cancellation before child launch | No child starts; compiler reports cancellation, old destination intact. |
| Child writes prefix, signals ready and waits; request cancellation | With successful containment and termination, confirm child exit before candidate cleanup and return; no publication and old destination intact. If termination/observation is deliberately denied, report cleanup unconfirmed and do not publish. |
| Child has exited successfully, request cancellation before replacement | Confirm replacement was not entered; cancellation preserves destination. |
| Pause immediately around replacement and race cancellation | For a decisive commit result, observe cancellation with old bytes/absence or successful replacement with success; never cancellation with new bytes. An unexpectedly indeterminate result uses the distinct exit 4 disposition. |
| Successful child and replacement | Verify the complete candidate becomes final, success is reported, all handles close, and run the actual executable for its independent value oracle. |
| Existing output is read-only or replacement is denied by sharing | For a host primitive that reports a definitive failed commit, verify the error is reported, the old output remains byte-identical and owned candidate cleanup is accounted for. Establish the deny condition independently; if the host instead supports a safe replacement, verify the successful new output and disposition. |
| A candidate publication protocol uses `ReplaceFileW` | Exercise its documented partial-failure states, including a replaced pathname missing or moved, against the whole protocol. A stub that returns an error without producing the documented filesystem state does not exercise recovery. Observe concurrent readers and competing path changes during recovery as well as final bytes. Microsoft documents these states in [ReplaceFileW](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-replacefilew); if the protocol cannot preserve the required precommit output and visibility, it is not an admissible implementation. |
| Concurrent readers during replacement of an existing output | With test-controlled complete old and new byte patterns, repeatedly open and read the selected path while successful replacements occur. Require each successful observation to be one complete pattern and explicitly count missing-path and open-error outcomes; a missing path during the tested commit is not an old-or-new observation. Establish that replacements really succeeded during the reader interval, and include a control that exposes an intentionally non-atomic remove-then-create operation. A held-reader test in which every replacement fails does not establish successful-replacement visibility. |
| At the initial check, destination is an input, tool, compiler or support file, including hardlink/reparse aliases | Reject before commit; all protected bytes remain unchanged. Test a nonexistent lexical destination and aliased parent as well. See the separate late input-hardlink case for the owner's clarified behavior. |
| A separate output hardlink to a build input is substituted after the initial check | Independently establish the input actually opened and read, then create a separate hardlink to it at the output path without changing the original input. A successful build may replace the output link; verify the original entry, identity, contents, creation and last-write times, attributes, security descriptor and named streams remain unchanged. Link count and filesystem-managed change metadata can change due to the link operations. Safe precommit failure must preserve the output link too. Test sources, manifests, tools and linked objects; confirm the link identifies the original and include direct-input-entry controls. |
| A source changes during a build | Source changes are the user's responsibility. The compiler does not monitor or lock sources for consistency, detect changes, or reject or retry the build because of them. Success with unintended behavior in the resulting program is permitted; no source-change diagnostic is expected. Exercise ordinary read or parse failures as applicable, and separately verify that the compiler itself does not modify the source. For a publication scheme using input handles, test an in-place user edit and a replace-by-rename save separately; report actual host sharing outcomes rather than assuming either save method works. |
| After admission, the actor moves the source's only entry onto the authorized output name | Under the documented entry-ownership interpretation, successful publication may replace that output entry. Independently observe the actor's move before commit; do not require the compiler to restore the old source name or follow the source object to a new name. Keep this distinct from the separate-hardlink case, where the original input entry remains and must be untouched by the compiler. |
| An ordinary path component becomes a junction after its type is checked | A qualified path guard must prevent or safely detect the change before publication. Use controlled empty and nonempty directories and separately establish whether the host permits each reparse operation; checking the original attributes alone is insufficient. |
| Change a parent pathname after output admission so it points into an input directory | Publication must stay bound to the admitted directory object and leaf or fail before commit; it must not resolve the parent again and replace an unrelated input entry. Treat separate late output hardlinks and user relocation into the output slot according to their distinct preceding cases. |
| Replace the destination with another ordinary file during a build | A successful commit may replace the new file without a prompt; if the build fails before commit, the compiler makes no further change to the actor's file. |
| Child exits while descendant retains pipe or candidate | The compiler does not validate/publish while writes remain possible; it drains/stops the contained tree or fails within the defined bound. |
| Inspector inherits a guarded candidate handle and a descendant keeps it after the direct child exits | Exercise the direct-handle proposal only if selected. Verify the actual contained tree and inherited handles are accounted for before commit; an unconfirmed descendant or handle produces a controlled no-publication outcome. Have the descendant advance the shared position after direct-child exit and verify any subsequent read starts correctly. A successful direct-child exit alone is insufficient. |
| Inspector advances a shared candidate file position | For a selected direct-handle handoff, use a candidate with independently known nonempty bytes and have the inspector advance the inherited offset to EOF. Any later complete-file read or hash must explicitly rewind or use a separately qualified handle and match the independently calculated full-file result. A deliberately unrewound read must fail the comparator. Repeat with a partial offset and with a tool failure; never publish based on an empty or partial observation. |
| After successful commit, force an actual postcommit cleanup operation to fail | Observe published new bytes, exit 0 and the proposed UBE1512 cleanup warning on stderr when its output stream works; never report an ordinary build failure. |
| If the selected commit can leave an owned candidate name referring to the published file, deny removal of that name after commit | Verify the warning identifies the survivor and the compiler does not claim complete cleanup. With a controlled actor, test whether that name can open the published object for writing while compiler protection is in effect; require the chosen scheme to prevent an admitted tool or surviving owned writer from changing the verified bytes. If it cannot establish that protection, it must not publish using that scheme. The harness removes its test-owned survivor after observation. |
| After successful commit, close an otherwise unused redirected output channel | For a build with no source or cleanup warnings, redirected success performs no output write and still returns 0 when required cleanup succeeds. |
| Successful interactive build | Show one brief confirmation without input or acknowledgement; return 0. A failed best-effort confirmation cannot undo publication or turn success into failure. |
| Inject an unexpectedly indeterminate host replacement result | Proposed exit 4 and UBE1513 if output works; report no assertion that the old or new bytes won. A known unsupported host/filesystem is rejected before commit. |
| Empty, quoted, Unicode and trailing-backslash arguments | Child reports exactly the intended distinct argument vector; no shell interpretation. |
| Child reports a Windows status outside signed Long range | A distinct controlled unrepresentable-status outcome, not a fabricated negative tool status or start failure. |

For the two initializer-cycle fixtures, the selected diagnostic is warning
`UBE1514`, anchored to A's `B.y` access at line 3 for the direct case and line
5 for the helper case. Independently derive the byte offset and scalar column
from each original source; do not reuse generated spans. At jobs 1, 2 and 4,
compare warning identity, path, source position and severity, and force
different worker completion orders. A warning-free non-circular fixture must
still build. A circular fixture must not become a compile-time error, prompt,
or nonzero build result solely because of this warning. These are proposed
acceptance checks; neither warning analysis nor warning transport is implemented.

The `initializer-cycle-branch` fixture adds a dependency from cyclic B to C,
which has no dependencies. Require exactly one warning for the A–B component
and reject a diagnostic that asserts C is a member of that cycle, following
the selected grouping policy in `NATIVE-BUILD-DIAGNOSTICS.md`.
Also cover two disjoint components, a reachable foreign helper that refers
back to its still-initializing caller, and exact ByRef forwarding from that
caller's module storage. Forwarding via same-module helpers must not hide the
potential cycle. Local/result storage, ByVal copies, forced/omitted temporaries,
uncalled helpers and provably skipped operands are negative alias controls.
Root-origin facts merge conservatively across call sites; the warning may
therefore occur even when the callee never dereferences the alias. Change the
root storage identity, drop a forwarding edge, or use a nonqualifying earlier
call as the expected witness and require the comparator to distinguish each.
Recursive forwarding must terminate analysis with and without a root seed.
These are future source-to-warning checks; the separate 21-case policy model
does not prove extraction from source or emitted compiler diagnostics.
The source-only `additional/check-initializer-warning-anchors.ps1` check
observed line 3, column 20, byte 64 for the direct fixture and line 5, column
13, byte 117 for the helper fixture in the current file bytes. It rejected
independently altered line, column and byte expectations for each. Command:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/additional/check-initializer-warning-anchors.ps1
```

The script derives byte positions from the actual fixture contents, so line
ending changes can change offsets. It checks source anchors and its comparator,
not an emitted compiler warning or IDE transport.

The full-disk case must use a bounded real filesystem or a fault shim that
observes and fails the actual candidate write, not an unrelated synthetic error.
Document platform and filesystem, underlying primitive and any unsupported
conditions. Verify no shell is invoked by making an argument containing `&`
and a marker command; the vector must contain literal bytes and the marker must
not be created. Tool stdout/stderr and diagnostics have separate expectations;
their final exact messages and codes require the existing CLI contract to be
extended before production integration. The future executable compiler's own
process cannot be replaced by a stub when asserting its failure behavior.
Use controlled child copies for transport/failure tests and actual fresh-v3
generated executables for end-to-end success; a stub candidate alone cannot
establish that the compiler emits working native code.

## Process, argument and commit race experiments

The controlled tool and its descendant must signal explicit ready/release/exit
events to the harness; use independently retained process identities and handles
to observe exit. Do not substitute sleeps for proof that a requested race point
was reached. Set and record a finite deadline before each run. The deadline is a
test bound, not permission to report cleanup complete while a writer remains.
The test seam may pause at defined boundaries but must not perform the compiler's
launch, pipe draining, identity validation, cancellation, commit or cleanup.

### Windows argument transport

`../../NATIVE-TOOL-CONTRACT.md` now selects always-quoted CRT-compatible
serialization, explicit argv[0]/application path, 1024 tokens and 32767 UTF-16
code units including the final NUL. Independently test encoded lengths
32766/32767/32768, counts 1023/1024/1025 and environment-block boundaries.
Escaping and surrogate pairs must count toward the actual encoded length.
Below/at-limit cases still need a valid host path and generous other limits;
above-limit cases must not launch. Include malformed encoding/NUL and an input
whose escaped output crosses the limit. Qualify the actual driver-to-LLD hop,
including any driver-owned response file and its expanded vector. The fixed
host probe below does not establish these new boundaries or that second hop.

Have the selected executable record argument count and each argument as a
length-prefixed UTF-16 sequence, independently of a rejoined command line. For
one invocation supply these distinct arguments in this order:

1. An empty string and a single space as separate arguments.
2. `two words`, `a&b` and `trailing\` (one final backslash).
3. `one"quote`, and a sequence consisting of two backslashes immediately
   followed by a double quote, followed by `end`.
4. `æøå` and `𐐀` (U+10400), both as arguments and within an existing path to
   the executable or an input fixture. Use exact Unicode scalar sequences;
   no normalization or ANSI-code-page substitution is permitted.

Compare count, order, UTF-16 code units, lengths and the child's executable
identity to the independently authored expectation. Verify that the ampersand
does not run a marker command. Mutate one expected code unit, remove the empty
argument, and alter the trailing backslash as separate negative controls; each
comparison must fail. This tests the actual boundary and selected child parser;
it does not assume that `CreateProcess` itself accepts a native argument array
or that every unrelated program uses the same parsing convention. Invalid or
unrepresentable argument data must produce a controlled no-publication error.

The focused `arguments/probe.c` uses a hand-authored `CreateProcessW` command
line and a CRT-parsed child to check an empty argument, spaces, ampersand,
trailing backslash, embedded quote and `æøå`. Compiling it with local Clang
using `--target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode`
and running both the resulting executable and the same command with `wrong`
appended returned exit 0; the latter succeeds only when the child rejects the
intentionally wrong final argument. This is a narrow host/CRT probe, not a
production argument encoder, a complete transport test or the required marker
and malformed-input controls above.
The source SHA-256 was
`43B7753D844E5BAF9AF088BDEB5F81AEC7E8B942E77986A88016E870BDEEB954`; the
executable was `113765E3105541C2C65AA8DAF039D865BDFD58C9DC487200619A4A58F674AAE6`.
The executable commands were `rtk proxy bootstrap/out/native-arguments-probe.exe`
and the same command with `wrong` appended.
The probe was subsequently extended with U+10400 encoded as the UTF-16 pair
`D801 DC00`; both the normal run and wrong-argument control again returned 0.
This extends the focused hand-authored list only, not the future encoder or
the remaining path, marker and malformed-input tests.
The extended source SHA-256 was
`410A9696F2D217920FBD60512CEE0116CEDFFEA8C3EBEBD4B85FB69D39A6A7EF` and
the rebuilt executable was
`CEAD40E338D84547A77DACF9592AA390B25EBD815AF8B969273ECF8A99A709FE`.
The extended executable was also copied to `bootstrap/out/args & æøå/probe.exe`.
`rtk proxy powershell -NoProfile -File
compiler/UBE_Compiler_v3/tests/native-executable/arguments/check.ps1 -Probe
"bootstrap/out/args & æøå/probe.exe"` returned exit 0 after both the normal
and wrong-argument checks. An initial direct `rtk proxy` invocation of that
path failed to resolve the path, so the passing run uses a literal-path
PowerShell wrapper. This exercises the probe launching itself from the
specified path, not the production compiler's argument encoder or the marker
control.
The probe was then extended with an argument containing two backslashes
immediately followed by a quote and `end`. The check script passed the normal
and wrong-argument cases from both the ordinary and the space/ampersand/Unicode
executable paths. This still uses a hand-authored command line and does not
qualify a general argument encoder.
The final probe source SHA-256 was
`D3D92F81D30235CA056B0598517EABBE155621718FA056BF50506AFFDE16FFE5`, the
wrapper was `003849E993ED61FDE7CF140722E4CB6ACDA5720F66F51285E69538DCCEB65859`,
and the executable was `E9004375F74DAA3B35DDE18FC1B765E7955E8D6942FBDE3E4DF339581F767C63`.

### Destination-lock candidate experiments

If an implementation proposes an opportunistic lock, test it on the actual
destination and filesystem with an independently controlled competing process.
Hold explicit readiness barriers before lock acquisition, after acquisition,
and immediately around commit; do not use sleeps as evidence. Separately try
opening and renaming the destination, replacing its directory entry, and a
handle opened before lock acquisition. Observe whether the lock is granted,
whether a break needs acknowledgement, when the competing operation can finish,
and whether the compiler's own rename breaks or waits on its lock. For every
case record final destination identity and bytes, candidate identity, the
compiler result and all process/handle exits. Distinguish an ordinary replacement,
which the successful build may overwrite, from a substituted protected input or
alias, which it must not replace. Do not infer safety from an earlier identity
check when an alias can be substituted before commit. Denied locks,
unconfirmed break/cleanup and unsupported filesystems must fail without
publication. Include a no-competitor success control and a control that omits
the lock and demonstrates that the harness observes the substitution. Passing these
experiments is necessary evidence for that candidate, not a claim that the OS
provides an atomic compare-and-replace.

If a transaction-based candidate is proposed, independently observe the exact
identity and access mode held after the destination check, then attempt both an
ordinary substitution and a protected-input alias substitution before commit.
Exercise a transaction conflict, rollback, and a successful uncontended commit;
compare old and new bytes and path identities outside the transaction. A pair
of reads within a transaction is not sufficient evidence of repeatable identity:
the documented TxF isolation level permits separate opens to observe different
committed states. This is an acceptance obligation, not a selection of TxF.

### Quiescence, cancellation and captured output

For deterministic source failures, arrange two admitted modules with distinct
injected lowering failures. The selected serial-lowering baseline compares
canonical failure selection across frontend jobs 1/2/4 without claiming
concurrent lowering. The following completion-order test applies when parallel
lowering is introduced: arrange two admitted modules with distinct
injected lowering failures. At jobs 2 and 4 use barriers to reverse their
completion order; use the ordinary serial schedule at jobs 1. Without external
cancellation or infrastructure faults, require the same lowest-canonical-source
primary diagnostic, location and exit at all three worker counts,
with no publication and all admitted work drained. A comparator with the later
source substituted must fail. Test cancellation and infrastructure races
separately and record the actual event ordering; do not claim identical results
across intentionally different external event orderings.

The direct controlled tool creates a contained descendant and waits until it
confirms readiness. In separate runs the descendant (a) holds an inherited
stdout pipe open, (b) holds stderr open, and (c) holds and can append to the
candidate. The direct child exits 0 while the descendant waits. Assert that
direct-child exit alone triggers neither successful EOF attribution nor LLVM
validation, replacement or success while the descendant can still write.
Release the descendant in a success control; require observed
descendant exit, complete drain, close, and only then validation and commit.
For cancellation, request cancellation after readiness; when termination is
confirmed, require the documented tree stop/drain policy, observed writer exit
and closed owned handles before candidate cleanup and return. If containment, termination or observation fails,
the compiler must fail without publication and must not claim that draining or
cleanup succeeded. `../../NATIVE-TOOL-CONTRACT.md` selects the 600000-ms
invocation, 5000-ms completion grace and shared 5000-ms failure stop/drain
defaults, with at most 50-ms controller waits. These are internal configurable
policy limits, not an assumed OS real-time guarantee. Test zero and
before/at/after deadlines with a controlled clock/event seam, and require no
per-stream/descendant deadline reset. A primary cancellation followed by
unconfirmed stop retains the primary, appends UBE1511/containment and reports
safely retained temporary paths. Its exact vector is in `diagnostics.json`.

The production capture choice is overlapped reads, with pending buffers and
request records retained until actual completion. Inject delayed cancellation
completion and prove no reuse/free before acknowledgement. While one invocation
has unresolved I/O or descendants, a subsequent build must fail its tool
containment admission without launching another or accumulating more unresolved
owners. Release the first fixture's held condition, confirm reaping and then
require a later ordinary invocation to succeed. The existing synchronous-reader
host probes do not establish this production ownership path.

Independently send 0, 4096 and 4097 bytes to each stream, including NUL, `FF`
and LF; also interleave more than pipe capacity on both streams. For the current
proposed capture contract, stdout and stderr must each retain their own first
4096 bytes in order and set truncation only for actual excess. Verify the
asymmetric combinations stdout 4096/stderr 4097 and stdout 4097/stderr 4096,
so one stream's truncation state cannot be reused for the other. Verify the
rendering examples in `NATIVE-BUILD-DIAGNOSTICS.md` and readable
valid text, unambiguous fallback for invalid/control bytes, Unicode line and
paragraph separators, and truncated UTF-8,
and quiet redirected compiler stdout/stderr on success without any warning.
Separately force a post-publication cleanup failure and require a warning on
stderr, published bytes and exit 0. Exact rendering expectations must
be fixed before implementation, consistent with the owner's readable-error choice.
Use altered expected bytes and inverted truncation as negative controls. Inject
capture/read failure and process-wait failure separately and observe each fault;
both must stop publication and remain distinguishable from a child exit code.
For a Windows child status `0x80000000`, require an explicit unrepresentable-
status failure, never a made-up signed child status or launch-failure report.

If a future reviewed handoff changes the current closed-stdin policy to stream
guarded compiler-owned input, it also needs a separate full-duplex test. The
controlled child must write more than pipe capacity to both output streams before
and while reading input larger than pipe capacity. Confirm the exact input bytes,
both output prefixes and completion without a circular wait. Separately close
the child's input early, inject an input-write failure, and cancel while the input
writer and output readers are active; each failed precommit case must preserve
the destination and observe or explicitly report unconfirmed child cleanup.
Use barriers for each state and an intentionally undrained or wrong-input
negative control. These are conditional obligations for that unselected design,
not authorization to replace the draft's closed-stdin policy.

### Identity and commit linearization

Start each run with the existing sentinel and with no destination. Exercise a
destination equal to the source, project, referenced library manifest, compiler
or selected tool, and a hardlink or reparse alias where supported. For nonexistent
output, also test a lexical input name and an aliased parent. Pause after initial
identity evaluation and replace the destination or parent alias before commit;
also attempt to replace the candidate with another file before validation.
Independently compare every protected input's original bytes and identity and
observe whether validation/commit is attempted. A supported platform must prevent
replacement of protected inputs' own entries through changed destination or
parent aliases. The separate late input-hardlink case above permits replacing
that output directory entry while preserving the original input entry.
An ordinary replacement at the selected destination can be overwritten on a
successful commit. A candidate swap must fail or commit the exact verified object,
never the substituted candidate; detection and commit must not leave a race
between a final pathname check and replacement. If the platform cannot provide the required guarantee, the test must
record an unsupported/fail-safe outcome; a string-normalization comparison alone
cannot count as proof. Do not run the swap experiment against uncontrolled user
paths: all inputs, links, candidates and outputs must be test-owned fixtures.

Inject a failure immediately before commit and require old sentinel bytes or
absence, controlled failure and no successful replacement. In a separate run,
observe a successful commit first, then inject failure in an actually attempted
required cleanup or reporting operation. Separately close an unused output
redirected channel and verify success does not attempt a write or report failure.
Separately test an interactive terminal confirmation and a failed best-effort
confirmation after commit; neither requests input nor changes a successful exit.
Require complete new bytes and an explicitly identified postcommit outcome; it
must not be indistinguishable from a precommit failure that promises old bytes.
Require exit 0 and a cleanup warning when its output channel is usable; a broken
channel cannot imply no commit or change the successful exit. Race cancellation
at a controlled barrier on both sides of the commit. Require old/cancelled or
new/success for decisive outcomes, and the distinct exit 4 outcome if the host
result is unexpectedly indeterminate. Repeat runs at jobs 1 and 4,
recording the selected host primitive, filesystem, identities, barrier events,
fault activations, child/tree exit evidence and final bytes.

## Concrete frontend controls

The separate `additional/duplicate-main/DuplicateMain.UBE` project declares
two module entry procedures. Its independent expected diagnostic is UBE1422 at
`Other.bas` line 3, column 12, byte 60, with exit 1. The command
`rtk proxy powershell -NoProfile -File
compiler/UBE_Compiler_v3/tests/native-executable/additional/check-duplicate-main.ps1
-Compiler <stage-cli>` passed at jobs 1 and 4 for each stage-built CLI named in
`additional/ADMISSION-EVIDENCE.md`. The first comparator attempt failed because
of PowerShell array-expression precedence; correcting the comparator produced
the passing four checks. The revised script's `-WrongExpected` control changes
the expected line to 4; it returned exit 1 on both stages while the normal
checks again passed. This establishes frontend diagnostics only, not the
future build path's no-tool or old-artifact behavior.
For the revised comparator, SHA-256 was
`894305DABFEEC45AFDA18D71549D7C20B8FA1AE5F02D869536BA20401B855084`;
the project manifest was `FFC0A41D08781E91D7875CF310B2E773B9D617D33EF20EC84E152637D27B16E8`,
`App.bas` was `6649DBC1914859B9DEECF0DCDD150E0978ECE5EF2255AAA6496859C087E8B84C`,
and `Other.bas` was `9DE0D542B0475C48D12A8E6AE419285D623B462B7C583A8FEA9C6AE22439F54C`.

`additional/invalid-main/InvalidMain.UBE` declares a Main with a required
argument. Its expected UBE1422 is at `App.bas` line 3, column 17, byte 63.
`additional/check-invalid-main.ps1 -Compiler <stage-cli>` passed exact
diagnostic and exit checks at jobs 1 and 4 on each of the same two stage-built
CLIs; its `-WrongExpected` column control returned exit 1 on both stages. These
checks do not establish the unimplemented native build's publication behavior.
The comparator SHA-256 was
`432E07D1DA32ABD85089F9E1864C2E4955D77F49FB57B5461FF0CC78A6830370`, the
source was `F3B97A2A8C3960A0BD747F44544A404A41CC8A919DAB4C821B5D8E6E8B362F0D`,
and the manifest was `BF89C960E94DB591FDEEB9DAC44505458124533AB9065031401E1F56C7491B56`.

The following inputs under `rejections/` have independent expected classes from
`SEMANTIC-CONTRACT.md` and exact messages from `SEMANTIC-DIAGNOSTICS.md`:

| Project | Expected class / code | Primary line, column, UTF-8 byte |
| --- | --- | --- |
| `divide/RejectDivide.UBE` | constant integer division by zero / UBE1411 | 4, 12, 82 |
| `range/RejectRange.UBE` | constant value outside selected integer range / UBE1410 | 4, 24, 94 |
| `deferred/DeferredText.UBE` | datatype semantics not implemented / UBE1433 | 4, 20, 90 |

The local checker was run as `rtk proxy bootstrap/out/v3/ube.exe --check
<project> --jobs N` for each path above and N=1 and 4. All six returned 1 and
displayed the expected code, message and coordinates. Checker SHA-256 was
`FFC471D1FC556D8B2B470057DF07497ADFE292DAF3ED20DC30276C2ABBC80EA5`.
An initial `text` local was rejected by the parser as a reserved identifier;
it was renamed `payload` before the deferred-type observations. These checks
do not prove the future build command avoids launching a tool or preserves the
old output. The actual build-path gate must assert those separately and retain
the appropriate source path and exact prior frontend diagnostic, including the
deferred-versus-invalid distinction.

Repeatable local check: `rtk proxy powershell -NoProfile -File
compiler/UBE_Compiler_v3/tests/native-executable/check-rejections.ps1` passed
six exact stdout/exit/stderr comparisons and three comparator controls using
the same checker hash. Its first LF-only comparison failed; the local Windows
process emitted CRLF, and the passing check uses the host newline. This differs
from `SEMANTIC-DIAGNOSTICS.md`'s LF-separator wording and needs reconciliation
before specifying byte-exact build diagnostics. The test does not normalize the
captured output or establish how another host behaves.
