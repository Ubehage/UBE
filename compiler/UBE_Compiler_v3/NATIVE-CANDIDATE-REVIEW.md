# Native candidate validation: selected structural profile

The separate `NATIVE-DEBUG-CONTRACT.md` selects the bounded Full-information
admission check, including program identity, symbols, DIEs and line records.

This selects a finite structural-check profile for the first Windows x86-64
console target and the Clang/LLD command sequence in
`NATIVE-EXECUTABLE-CONTRACT.md`. Use bounded reads of candidate bytes, not
success markers in a tool's text report. The production implementation and its
binding to publication remain unqualified. This is not a complete Windows
loader model or proof of program behavior. The C probe is test-only; production
code remains UBE under the existing compiler/library boundaries.

## Selected bounded checks

Inspect the same stable file object that the publication protocol will commit.
Check every read against the observed file length using checked arithmetic;
handle short reads, cancellation, size limits and I/O failures as controlled
build failures. Do not allocate directly from untrusted header counts. A
successful tool exit or a truncated report is not an image check.

The profile checks the following conditions; fields outside this list are not
implicitly validated:

1. Require complete DOS/PE/COFF headers, their signatures, a PE offset at least
   64, x86-64 machine, executable flag and no DLL flag. Accept 1..96 sections.
   The section table starts after the declared optional-header length and must
   fit both the file and declared headers. The 96-section bound follows the
   [documented Windows limit](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-image_file_header).
2. Require the 112-byte PE32+ fixed optional header and console subsystem 3.
   File alignment is a power of two in 512..65536; section alignment is a power
   of two at least 4096 and at least file alignment. Header size is nonzero,
   file-aligned and within the file/image. Image size is nonzero and
   section-aligned. These choices cover the selected ordinary-page linker
   output, not PE's special low-alignment layouts.
   [Optional-header reference](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-image_optional_header64).
3. Nonempty sections appear in increasing, nonoverlapping virtual order after
   the section-aligned headers. Use the larger of virtual/raw size for layout
   extent, round its end to section alignment and require it within the image.
   Initialized raw ranges are file-aligned, ordered, nonoverlapping, after the
   headers and wholly in the file. Empty sections consume no layout range.
   A zero-filled tail is permitted when virtual size exceeds raw size.
   [Section reference](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-image_section_header).
4. Entry RVA is nonzero, inside the image and within the initialized bytes of
   an executable section. When virtual size is nonzero, the entry must also be
   below that virtual end; raw alignment padding is not an entry location.
5. Accept 0..16 directory entries only when they fit the actual optional header.
   Except for the cases below, each present address/size pair must be nonzero
   and fit wholly in one section's initialized raw bytes and its nonzero
   virtual extent. Reject header/gap/zero-fill backing. Both fields zero means
   absent. The reserved entries 7 and 15 must be zero. Require CLR entry 14
   absent for this native output profile. Global-pointer entry 8 has zero size;
   if its address is present, require one backed byte. Certificate entry 4
   instead uses an eight-byte-aligned file offset and an in-file range.
   [Directory definitions and exceptions](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format).

These checks do not inspect nested import/thunk/name structures, relocation or
exception records, TLS contents, certificate contents/signatures, COFF symbol
names, checksums, instructions or debug semantics. Those are explicitly outside
this structural profile. The separate required debug-information check and
independent runtime/ABI oracles still apply. In particular, accepting a directory
range does not establish that its records are valid or that every required
directory is present. A structurally accepted image is not guaranteed to load.
Avoid rejecting outputs merely because an
optional trailing overlay or optional directory is absent. Do not execute the
user's candidate during a build. A candidate can pass all structural checks and
still have wrong or zeroed code; independent execution of controlled fixtures
tests behavior separately.

The finite profile also bounds its metadata traversal. The test implementation
retains 96 triples of 32-bit section fields (1152 bytes) and fixed read buffers;
it does not copy the candidate body. Its maximum requested metadata is
`64 + 24 + 112 + 2 * 16 * 8 + 96 * 40 = 4296` bytes, because it reads directory
entries twice. It makes at most 131 fixed-size reads and at most 1536
section/directory containment comparisons. These are code-derived profile bounds,
not measured total process memory or a candidate-length/disk quota. Production
accounting must include storage wrappers, handles, diagnostics and concurrently
live build state. Candidate accepted-length policy remains a separate resource
decision.

## Current host evidence

Build the same test probe with and without the additional layout checks:

```powershell
rtk proxy 'C:\Program Files\LLVM\bin\clang.exe' --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode -DCHECK_IMAGE_LAYOUT compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/pe-structure.c -o bootstrap/out/pe-image-layout.exe
rtk proxy 'C:\Program Files\LLVM\bin\clang.exe' --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/pe-structure.c -o bootstrap/out/pe-without-layout.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-pe-image-layout.ps1 -Probe bootstrap/out/pe-image-layout.exe -UncheckedProbe bootstrap/out/pe-without-layout.exe -Executable bootstrap/out/native-handle-rename.exe -ControlExecutable 'bootstrap/out/output-path-determinism/e8b8bd1d39dd4294adb31a55ac219794/candidate one/Full.exe' -OutputDirectory bootstrap/out/pe-image-layout
```

The current check returned 0. It rejected 22 changed-layout cases covering
header/alignment/order/overlap problems, directory gaps and zero-fill tails,
half-empty pairs, reserved/CLR entries, entry padding and certificate alignment.
The probe with these checks omitted accepted every one. It also accepted an
overlay, an in-file certificate-offset range and a zero-sized global-pointer
entry. The latter two are synthetic range controls, not valid-certificate or
loader proofs. Complete synthetic tables accepted 96 sections but rejected 97,
and rejected a 17th directory; the omitted-layout probe accepted all three.
None of the mutated/synthetic executables was run. Exact probe/fixture/script
hashes and layout results are in
`bootstrap/out/pe-image-layout/5139ff2d3b414db392cabea9290a1b3c/report.json`.
The refreshed report includes all three boundary results and hashes, the probe
source hash and the additional Full success-control identity. The boundary
files are retained beside that report.

The existing independent structural suite was extended with wrong-machine and
DLL controls and passed for both selected staged Full and None outputs:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-pe-structure.ps1 -Readobj 'C:\Program Files\LLVM\bin\llvm-readobj.exe' -Executable 'bootstrap/out/output-path-determinism/e8b8bd1d39dd4294adb31a55ac219794/candidate one/Full.exe' -OutputDirectory bootstrap/out/pe-image-layout -StructuralProbe bootstrap/out/pe-image-layout.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-pe-structure.ps1 -Readobj 'C:\Program Files\LLVM\bin\llvm-readobj.exe' -Executable 'bootstrap/out/output-path-determinism/e8b8bd1d39dd4294adb31a55ac219794/candidate one/None.exe' -OutputDirectory bootstrap/out/pe-image-layout -StructuralProbe bootstrap/out/pe-image-layout.exe
```

Each run accepted the original and zero-code control and rejected all 11
wrong-kind/target or malformed cases. Both used the current probe including
the CLR-directory exclusion; the layout suite above tests its CLR mutation.
Their artifacts are under
`bootstrap/out/pe-image-layout/a7a3f67e230a4cab9061bfd43513d5d3` (Full)
and `ca58f04726e44d36b7fe8be48efd6b6a` (None). These results
select the finite profile; they do not qualify candidate identity, publication,
short reads, cancellation, production UBE implementation or arbitrary PE files.

## Qualification gate

Use independently constructed mutations of a known accepted executable: wrong
architecture, object and DLL; truncated headers and section table; zero or
outside entry; raw range beyond file; misaligned raw offset; inconsistent
directory count and optional-header length; and checked-arithmetic boundary
cases. For each, confirm the mutation independently, require controlled failure
and unchanged previous output, and include the original as a success control.
Use test-only mutations that disable individual checks to show the corresponding
oracle actually catches them. Also test representative outputs of every selected
linker and supported debug mode, including legitimate absent optional directories
and harmless trailing data, so rejection tests do not define an unnecessarily
narrow file format.

Test incomplete reads, cancellation, candidate swaps and retained writable
handles at the actual compiler boundary; the test harness must not validate or
publish on the compiler's behalf. An image parser and identity protection are
separate obligations. The current `CHECK_IMAGE_LAYOUT` probe exercises the
selected profile's host cases above; it does not establish this production gate.
The earlier weaker configurations below remain adverse evidence. Zeroed entry
code still passes the selected structural profile, as explicitly expected.

## Earlier probe evidence

The observations below describe the earlier, weaker probe configurations; they
remain useful adverse controls and do not supersede the selected profile above.

The test-only structural probe now checks nonempty directory ranges against the
image size, using the file size for the certificate table. Its focused harness
accepts an original executable, rejects an import range past the image and a
certificate range past the file, and verifies that disabling the range checks
accepts those mutations. A padded file-offset control is accepted by the
certificate-file-offset interpretation and rejected by an intentionally wrong
RVA interpretation. The control contains placeholder bytes, not a validated
certificate. These tests cover range arithmetic only: they do not establish that
directories are mapped to suitable sections, that their contents are valid, or
that a candidate will load or execute. They do not select this probe for UBE.
The same harness independently finds a 20-byte gap outside the declared headers
and every section, places the import directory there, and observes that the
range-only probe accepts it. On the tested fixture the gap begins at RVA 1024.
The loader's treatment of that gap and all directory types remains unqualified;
the result demonstrates the checker limitation, not a general loader rule.

A separate adverse control moved a non-entry, nonempty section's virtual
address to `SizeOfImage`, leaving the entry section unchanged. The experimental
probe accepted both the original and the mutated image. This demonstrates that
its existing image-size and entry checks do not enforce the proposed section
virtual-range check. The mutation was not executed, so this observation makes
no claim about loader behavior or production validation:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-pe-section-outside-image.ps1 -Probe bootstrap/out/pe-structure-probe.exe -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename
```

The command returned 0 after asserting both acceptances and independently
checking the mutated address equals the declared image size. The qualification
gate must reject this case as well as preserve the original success control.
The test-only probe was subsequently extended to reject a nonempty section
starting at or beyond `SizeOfImage`. The following builds and checks returned
0: the normal probe accepted the original and rejected the mutation, while the
variant without the new check accepted both. Running the latter with
`-RequireRejected` returned 1, confirming that the rejection assertion detects
the omitted check. These are narrow test-only results; they do not validate
ordering, all legal outputs or loader behavior. After adding the separate end
check below, the omission build needs both omission flags to reproduce this
original start-boundary control.

```powershell
rtk proxy 'C:\Program Files\LLVM\bin\clang.exe' --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/pe-structure.c -o bootstrap/out/pe-structure-image-start.exe
rtk proxy 'C:\Program Files\LLVM\bin\clang.exe' --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/pe-structure.c -DOMIT_SECTION_IMAGE_START -DOMIT_SECTION_IMAGE_END -o bootstrap/out/pe-structure-no-image-start.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-pe-section-outside-image.ps1 -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename -Probe bootstrap/out/pe-structure-image-start.exe -RequireRejected
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-pe-section-outside-image.ps1 -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename -Probe bootstrap/out/pe-structure-no-image-start.exe
```

The `-CrossEnd` variant changes a non-entry section's virtual size so its end
is exactly one byte past `SizeOfImage`. The extended test-only checker accepted
the original and rejected this mutation; with `OMIT_SECTION_IMAGE_END` it
accepted both. Requiring rejection from that omission build returned 1. This
tests one virtual-range boundary, not all section layout or loader rules:

```powershell
rtk proxy 'C:\Program Files\LLVM\bin\clang.exe' --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/pe-structure.c -o bootstrap/out/pe-structure-image-end.exe
rtk proxy 'C:\Program Files\LLVM\bin\clang.exe' --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/pe-structure.c -DOMIT_SECTION_IMAGE_END -o bootstrap/out/pe-structure-no-image-end.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-pe-section-outside-image.ps1 -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename -CrossEnd -Probe bootstrap/out/pe-structure-image-end.exe -RequireRejected
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-pe-section-outside-image.ps1 -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename -CrossEnd -Probe bootstrap/out/pe-structure-no-image-end.exe
```

The updated normal test probe was also run through the earlier independent
structural fixture suite. It accepted the original and zero-code control and
rejected all nine previously identified malformed structures; the command
returned 0. In particular, acceptance of the zero-code control remains a known
limitation, not evidence that the resulting code works:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-pe-structure.ps1 -Readobj 'C:\Program Files\LLVM\bin\llvm-readobj.exe' -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename -StructuralProbe bootstrap/out/pe-structure-image-end.exe
```

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/pe-structure.c -o bootstrap/out/pe-structure-probe.exe
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode -DOMIT_DIRECTORY_RANGES compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/pe-structure.c -o bootstrap/out/pe-structure-no-directory-ranges.exe
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode -DCERTIFICATE_AS_RVA compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/pe-structure.c -o bootstrap/out/pe-structure-certificate-as-rva.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/handle-rename/check-pe-directory-ranges.ps1 -Probe bootstrap/out/pe-structure-probe.exe -UncheckedProbe bootstrap/out/pe-structure-no-directory-ranges.exe -WrongCertificateProbe bootstrap/out/pe-structure-certificate-as-rva.exe -Executable bootstrap/out/native-handle-rename.exe -OutputDirectory bootstrap/out/native-handle-rename
```
