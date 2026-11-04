# Retained function-extent binding evidence - 2026-11-03

NativeUnwind now validates an image function table once before exposing it for
binary search, then binds each declared object extent to the image range at the
frozen retained definition's exact anchor. Section, file offset, section offset
and positive code length must match. NATIVE-UNWIND-IMPLEMENTATION.md defines the
ownership, allocation, traversal, publication and failure contracts. No production
resource cap or declaration/body/argument work bound changes.

## Commands and current reports

All commands ran from the repository root. DiagnosticOnly uses the retained
qualified bootstrap tools; it does not refresh the whole compiler source cohort.

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check.ps1 -DiagnosticOnly
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-extent-bindings.ps1 -ReaderReport bootstrap/out/native-objects/d130b762f1f5443e91f8c147528ed394/report.json -GraphReport bootstrap/out/native-graph/3ae0e5a87d014b82a61adaae0cc28595/report.json -RetentionReport bootstrap/out/native-retention/e46ecc7337af46ff90e59aa4e18537e7/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-unwind.ps1 -ReaderReport bootstrap/out/native-objects/d130b762f1f5443e91f8c147528ed394/report.json -GraphReport bootstrap/out/native-graph/3ae0e5a87d014b82a61adaae0cc28595/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-image-unwind.ps1 -ReaderReport bootstrap/out/native-objects/d130b762f1f5443e91f8c147528ed394/report.json -RetentionReport bootstrap/out/native-retention/e46ecc7337af46ff90e59aa4e18537e7/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-bindings.ps1 -ReaderReport bootstrap/out/native-objects/d130b762f1f5443e91f8c147528ed394/report.json -FramesReport bootstrap/out/native-frames/157eecd5aacd410fade78655207ec826/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-generated.ps1 -ReaderReport bootstrap/out/native-objects/d130b762f1f5443e91f8c147528ed394/report.json -FramesReport bootstrap/out/native-frames/157eecd5aacd410fade78655207ec826/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-retention.ps1 -ReaderReport bootstrap/out/native-objects/d130b762f1f5443e91f8c147528ed394/report.json -GraphReport bootstrap/out/native-graph/3ae0e5a87d014b82a61adaae0cc28595/report.json -SupportReport bootstrap/out/explicit-link-inputs/318209f12b5b4f0282acf596c47e6386/report.json
rtk proxy powershell -NoProfile -File bootstrap/out/check-unwind-script-syntax.ps1
rtk proxy git diff --check
```

| Gate | Report under bootstrap/out | Groups | Commands | Summed command ms | Matched input hashes |
| --- | --- | ---: | ---: | ---: | ---: |
| Component | native-objects/d130b762f1f5443e91f8c147528ed394/report.json | 50 | 103 | 219854 | 71 |
| Extent binding | native-extent-bindings/ce0baffb7fb4484f94f1f154d1f3c8d1/report.json | 416 | 576 | 31891 | 387 |
| Object ranges | native-unwind/bb7d785f722d4c708cbe7a8b82adec87/report.json | 288 | 576 | 17219 | 222 |
| Image ranges | native-image-unwind/cb58996a18894a899965f475af214caf/report.json | 32 | 48 | 2748 | 94 |
| Integer data | native-data-bindings/10182662c6ce4fd79b137543d23571b5/report.json | 192 | 192 | 8346 | 141 |
| Generated readers | native-object-inputs/7a675a2f7cb940b8a6b74c1a3a451c2e/report.json | 224 | 336 | 12699 | 190 |
| Linked retention | native-retention/62289a8863ae4dd8989b70f70ea69788/report.json | 416 | 576 | 24818 | 249 |

All captured input hashes match at this checkpoint. The component passes
14,687,535 native assertions per bootstrap stage. Raw output is identical:
1,312,008 bytes, SHA256
98E6F260144E7C829D1D08019BB0DBB271AD750CC23247828EF394E34B8D975A.
NativeUnwind.bas is 16,915 bytes, SHA256
A74EEF6A4D149D0CF4224E028F782211B07A8DB89C71586BD0763DF372DA6A57.
The five PowerShell parser checks and changed-file whitespace checks pass.

## Independent assertions and resource bounds

The synthetic two-record image prepares in exactly 648 inspected bytes/167 events.
Binding its first and second records consumes 260/68 and 264/69 respectively.
Independent hooks observe the same physical bytes and admissions, zero payload
allocation/copying, preserved Err and unchanged input bytes. Exact and one-below
budgets, every cancellation admission, full root pressure and invalid owner or
anchor cases preserve prior scalar results. Preparation rejects unordered or
overlapping records before publishing Status=1. Unprepared tables are not searchable.
Absent image metadata does not create an inferred function extent.

A separate 64-record image exercises first, middle and last queries. They use
exactly 7, 1 and 6 binary-search reads plus the selected-record validator, rather
than a complete table walk per query. Controlled result-length and preparation-
status mutations fail their intended assertions through both bootstrap stages.
NativeImageFunctionTable is now four Long fields (16 bytes); the existing raw
table reader publishes Status=0, and the preparation wrapper publishes Status=1
only after all records pass. The earlier indexed readers remain available.

The actual binding matrix uses frozen expected definitions, 144 retained generated
objects and 16 retained explicitly linked images from both generating stages,
root/reference layouts, O0/O2 and Full/None. Independent LLVM symbol/runtime-function
records specify presence and exact lengths. Both current reader stages produce
288 matching unit results: 720 bound extents, 112 present functions without unwind
records and 384 eliminated optional functions. The latter categories are explicit
observations, not invented leaf bounds or stack-cost claims.

For each image, independent test locators shift Main's range start, shorten its
end, remove its runtime-function record, or extend its object-side declared end.
All 128 mutations fail specifically at production extent binding with 1506, rather
than being accepted because another parser or process happened to fail. The
fixture's bounded C arrays and expected-row transport are test-only; production
build ownership and object-extent association still require integration.

## Focused corrections and leaf investigation

The initial component report f27c6d091ae44be886a721f1b1ad2721 records the bootstrap's
controlled UBE2238 rejection of ElseIf. Replacing that one branch with equivalent
nested If statements preserves the selected bootstrap subset; no bootstrap or
language semantics were changed.

The first actual binding run, native-extent-bindings/6d43ece0bdf9435da8ad336b7258b640,
passed its first 18 unit results, then the test-only image mutation locator rejected
unrelated repeated section names from linked support objects. The locator now asks
for only the unique frozen Main name, still rejecting duplicates of that required
identity. Object oracles remain strict. No production change was needed.

The focused command below investigated whether requesting unwind tables could
supply otherwise absent leaf records:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/out/check-leaf-unwind-diagnostic.ps1
```

Report bootstrap/out/leaf-unwind/6a069327384c4f1eab692408ed11065e/report.json retains
exact IR, tools and four commands. Two identical scalar leaf functions, with and
without uwtable, produced zero runtime-function entries at both O0 and O2 on the
selected Windows target. This is a narrow diagnostic observation, not an all-program
proof. Although [LLVM documents the attribute's unwind-table request](https://llvm.org/docs/LangRef.html#function-attributes),
that request did not establish usable leaf metadata here. Production emission was
not changed based on an unsupported assumption.

## Remaining acceptance work

Next establish leaf extents and qualify instruction/relocation equality, then
complete unwind/stack/reserve and producer/debug validation. Bindings prove declared
anchor/length correspondence; they do not prove instruction identity or safety.
The integrated build owner must retain each immutable image's prepared table and
associate object extents with frozen definitions without repeated full scans.
Current explicit toolchain evidence must be integrated before wiring the retained
link/image/binding matrices into the whole bootstrap. Builder/publication, held-file
identity and final source-cohort/retained acceptance gates remain incomplete.
The overall First checked native executable goal remains active.
