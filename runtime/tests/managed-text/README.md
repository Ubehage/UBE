# Managed text qualification

## Current source and collector checkpoint

The full `text-check.ps1 -CompilerExe <UBE.exe>` client now retains 5,000
Strings, checks their independent values after collection, and passes at O0/O2
with its negative control (`dbd8a0ae-04e2-4a2d-9bbe-71bb050f85df`). It does not
expect exhaustion at the removed fixed heap quota. `-AllocationFailure` instead
injects exactly two failed text-allocation attempts and checks fresh failure,
unchanged destination and roots, successful retry and sticky Err at O0/O2
(`a14d0c11-631f-43c9-bc12-dd95f7c106de`). Injection exists only in temporary test IR.

`-Threads` passes retained String-array payload and simultaneous collector checks
with its changed-value control on the self-built compiler
(`18f3dfd7-1803-46fe-956c-84d70f6d662a`). Native `fault-check.ps1 -ProgramIR
<emitted Collector.ll>` also passes O0/O2 and negative controls: default faults
`0c4d335f-cd11-4ea6-b18a-70d8355c4ad9`, `-Growth`
`9f09facd-f677-4d3b-b86a-68b68463cf70`, `-Graph` (5,000 records)
`9026943c-5282-43cc-940c-53b98455b614`, and `-Rendezvous`
`40768c67-4228-4017-9a65-b33f986d7820`. Full compiler provenance and the separate
Single/Double gates are recorded in
[FLOATING-POINT.md](../../../compiler/FLOATING-POINT.md).

## Dynamic metadata checkpoint

On 2026-11-25, `rtk proxy powershell -NoProfile -File
runtime/tests/managed-text/metadata-check.ps1` passed against the current
230,936-byte runtime: O0/O2 snapshot, marking and frame assertions; changed
oracle controls; and the null metadata-list regression. The regression asserts
controlled rejection with the production guard and an access violation when
that guard is deliberately removed in temporary test IR. Evidence:
`%TEMP%/ube managed metadata 8e890b6c-cedf-4ed1-aa51-df49e9b5deb1`.
This gate checks native metadata mechanics; renewed source collector, worker
and heap-frame integration qualification remains separate.

## Earlier String source acceptance

The actual native acceptance runner is `text-check.ps1 -CompilerExe <UBE.exe>`.
It checks text values, conversions, failure preservation, aggregate and worker
roots, and allocation pressure at O0/O2, plus a changed scalar-count control.
`-Simple` selects a smaller literal/ByVal/result/comparison client and its
changed-value control for isolating integration failures. Final O0/O2 runs use
generation 2 from `ube compiler rebuild 2a484f43-e11e-4490-8436-686fe60cb92a`:
full-client evidence `299a500f-fb4c-41fe-a5fa-3af04a7db266`, simple-client
evidence `a6271c60-763d-4b23-be3e-6ea3562f19ec`, each under `%TEMP%/ube managed text `.
At that checkpoint the full client also filled the retained-allocation quota, asserted unchanged
failed destinations and recovered after dropping retained values. The current
growth and deterministic failure cases above supersede that quota assumption. `-Conditions`
checks String Boolean conditions and array indexes, including invalid text;
it passed with negative controls in `b972f7b8-435f-47ef-b9ae-bca740ce12b7`.
Separate native fault/graph/rendezvous gates are documented in
[the runtime README](../../README.md); final self-host and concurrency evidence
is in [compiler progress](../../../compiler/Progress.md).

`text-check.ps1 -CompilerExe <UBE.exe> -Threads` checks a gated worker's ByRef
String array element after the parent replaces its descriptor, both discarding
and preserving values. Full collection occurs before release; worker read/write
results and the independent replacement descriptor are checked exactly. Three
live workers also allocate and collect repeatedly, with exact independent final
strings. All waits and loops are bounded. O0/O2 passed, including a changed
retained-value negative control, using that final generation 2 compiler.
The final client also checks grouped ByRef conversions in both directions:
numeric boxes must not be treated as String roots, and converted String boxes
must survive collection. Evidence:
`ube managed text 7144e855-6f8c-4e4e-833e-dfb92f84ce2b`.

## Historical admission baseline

This diagnostic records what the compiler rejects before managed String support;
it is not the future positive String/collector acceptance gate.

```powershell
rtk proxy powershell -NoProfile -File runtime/tests/managed-text/admission-check.ps1 -CompilerExe <existing-UBE-compiler.exe>
```

The numeric control must emit, build and run with exit 42. The three isolated
String cases must fail with their exact current source diagnostics, preserve
the existing real IR/executable bytes, and allow subsequent numeric recovery
with exactly the original IR hash. Unsupported String locals, literal
expressions and Function results are checked independently.

Passed using generation 2 from `ube compiler rebuild
30c8f236-462a-4e4f-a55d-7cf29fe9b408`. Original evidence is
`ube managed text admission e8f82468-c9c5-468a-91b9-1fb69cc716c8`; rerun after
argument-quoting cleanup also passed in
`ube managed text admission 04ebd0dd-4fcd-4d13-9e32-1c9835f57981`.
Artifacts are under the system temporary directory. Retain this baseline
against the old compiler; new String support must receive separate positive,
negative, ownership, collection and concurrency gates.

`support-package-check.ps1` checks the private managed support package's exact
source bytes, deterministic manifest order and SHA-256 ledger. It also asserts
refusal of an existing destination, missing authoritative source and escaping
ledger path, and detects a changed-byte negative control. All nine sources
passed on 2026-11-20; evidence `ube support package
a63149db-5e98-49c4-95b7-cd04773ec8f5`. This is packaging evidence only; it does
not assert that the packaged String or collector code is executable.

`support-roles-check.ps1 -BootstrapExe <seed.exe>` executes the actual UBE
parser/binder against private support role declarations. The O0/O2 gate checks
exact identities, visibility isolation, signatures, transactional role output,
syntax-based support selection and canonical source identities. Expanded
evidence: `ube managed support roles 844ca9d0-e981-4880-be5e-e3a773425394`.
The expanded run `ube managed support roles
2ce6c4ad-7fe6-4bdb-8cae-757fe5c3dc6a` additionally passes twelve private source
span/count/domain tests against the provenance helper used by NativeLowering.

`managed-roles-check.ps1 -BootstrapExe <seed.exe>` passed 75 O0/O2 cases for
the 20 managed/text/collection primitive identities, independent declaration renaming,
signature/name negatives and unchanged rejected role maps, plus a changed-ID
oracle negative. Evidence: `ube managed primitive roles
4f613ad8-e1b2-4782-abd9-a3b236f68874`. It verifies declaration binding only;
native primitive behavior requires separate execution gates.

`support-install-check.ps1 -CompilerExe <UBE.exe>` checks compiler-relative
discovery, source/manifest output protection (including a hard-link alias),
numeric operation without optional managed assets, controlled missing/corrupt
managed assets, prior IR/executable preservation and exact recovery. The full
default gate passed against `ube managed collection compiler stable/UBE.exe`;
evidence `ube support install a93185e9-ea73-460c-ae7f-2b2c61edb499`.

The support role gate also passed all prior cases with ten syntax selectors,
including exact `Memory.Collect` activation and longer-name refusal: evidence
`ube managed support roles e6d4c1d7-9531-444b-adc7-12c16a0ecbdb`.

After the final reviewed-source comment update and self-build, packaging passed
again (`ube support package 0c89e5c4-1041-4fbc-99e7-fb6ed2665661`) and the full
installed-asset gate passed against generation 2 (`ube support install
b1559fc8-17eb-4621-b790-320762b5b74d`).

`publication-check.ps1` instruments the typed publication boundary while
executing production array resize, copy and preserving resize. It asserts
exact layout identity, element counts, preserved payloads and exclusion of
numeric arrays. O0/O2 pass and removing the production barrier calls fails
the independent call-count oracle. Evidence: `ube managed publication
c1b57870-0ebe-44c6-ac5e-cbbc5c2a10f4`. This gate checks publication routing;
managed String survival and compiler-side fact rejection have separate gates.
