# Shared scalar error support

Implementation started on 2026-11-03 under First checked native executable.
This qualifies focused host support only; it does not qualify generated UBE
programs, the backend, stack admission or complete native publication.

## Implementation

`../../bootstrap/runtime/error_support.c` owns the single native TLS record
and set/read/clear/specialized Err 28 implementation. The existing bootstrap
runtime includes that source, preserving its private access for managed text
accessors and lifecycle revisions. Native scalar output can compile the same
source alone. It must not link both forms into one image. This follows the
runtime's existing included-source arrangement without introducing a second
record or requiring unrelated runtime facilities in scalar native output.

Recording uses bounded inline byte copies instead of CRT calls. Clear zeros
the entire original record and advances its nonzero revision. The specialized
setter records exactly 28, `out of stack space`, and `UBE.Runtime`, preserving
the ordinary setter's remaining buffer bytes. This remains the temporary
substrate exception with the replacement condition in NATIVE-RUNTIME-CONTRACT.md.
The bootstrap manifest now includes the extracted source, and the full v2
build invokes the maintained error-record gate.

## Executed focused gates

From the repository root:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/check-error-support.ps1
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-linked-error-support.ps1 -SourceReport bootstrap/out/explicit-link-inputs/318209f12b5b4f0282acf596c47e6386/report.json -OutputDirectory bootstrap/out/shared-error-support -UseSharedErrorSupport -RequireMinimal -DebugMode None
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-linked-error-support.ps1 -SourceReport bootstrap/out/explicit-link-inputs/318209f12b5b4f0282acf596c47e6386/report.json -OutputDirectory bootstrap/out/shared-error-support -UseSharedErrorSupport -RequireMinimal -DebugMode Full
```

All three commands exited 0. Reports under `../../bootstrap/out/`:

| Gate | Report |
| --- | --- |
| Record and existing callers | `error-record/b88ecb82bf2a44b7be7cb83b04d667cc/report.json` |
| None linked inventory/TLS | `shared-error-support/ffd779b99e104b4a88bcbce7327abe34/report.json` |
| Full linked inventory/TLS | `shared-error-support/cdc8ff8c4e3847858856f4b528129cf8/report.json` |

The record test checks initial zero state, exact layout and all record bytes,
general/specialized equivalence, revisions 0/1/UINT64_MAX-1/UINT64_MAX,
clear, null text and truncation. Both modes reject the deliberately wrong
specialized error with exit 1 and the expected oracle failure. It also rebuilds
the ordinary bootstrap runtime and runs the existing error_state,
integer_failure and integer_storage probes.

The linked tests observe all three signed remainder widths and overlapping
thread-local state in both worker launch orders. Wrong-error and wrong-thread
controls return 1. The selected image retains exactly five UBE symbols: four
public C helpers and the private TLS record. The standalone object has only
`_tls_index` as an undefined symbol. The image checks reject exports, emulated
TLS and calls or external tail transfers from those four helpers. The retained
whole-runtime/no-GC control has 304 UBE symbols, 299 outside the allowlist.
Reports include commands, source/tool/object/image identities and inventories.

After adding counted output, both linked commands were repeated and exited 0.
Their current reports are
`shared-error-support/9538a9a7fa984c439a02c3e85be2de1c/report.json` (None) and
`shared-error-support/62f6301a14be41258895aca9325ad656/report.json` (Full).
The selected image still contains exactly the five permitted UBE symbols;
the expanded whole-runtime control now contains 306, with 301 outside that
allowlist. The controls still return 1. The earlier inventories describe their
earlier input cohort, not the expanded runtime.

The retained `.su` files report zero static frame bytes for the four helpers
in both modes. This observation alone is not the complete call/recovery reserve;
the return address, calling convention, actual entry paths and linked guard
accounting remain obligations of NATIVE-STACK-REVIEW.md.

An initial strict standalone compilation rejected an unused private accessor.
The accessor is now used by the number reader and forced inline; the passing
linked gates inspect the resulting functions. No test expectation was relaxed.

## Remaining work

The first full v2 rerun failed at caller-retention because that test copied the
runtime without the newly extracted include. Its retained failure report is
`caller-retention/7346267b91dd48da8e1429d9f012bbf1/report.json`. Both that test
and root-registry now copy the shared support and counted-output include.
The complete rerun in `v2/df15817344774026bebebfd1e9ae8eaf/` exited 0 with
914 acceptance assertions; its manifest SHA-256 is
`A8573742189253D557AD7527084E44C6A7E0ED56A937215DAF5EC8A083129445`.
The later checker/resource integration and final native builder still require
fresh source-cohort and retained frontend/checker qualification. The builder needs its
actual generated-operation observer, runtime error oracles, stack admission
and linked recovery-reserve evidence. Counted byte output passes its focused
direct/two-stage gate; `../../std-lib/FILE-OUTPUT-EVIDENCE.md` records its scope.
All lowering, tool, diagnostic/debug and publication integration remains
unfinished.

## Owner-confirmed error replacement - 2026-11-03

The owner explicitly confirmed that all visible Err information survives
successful operations until Err.Clear, valid Resume behavior, or a new error.
A new error replaces every visible field; omitted fields become neutral or
receive the new error's defined defaults. The normative section 9, runtime
contract, public errors lesson and Resume reference now state this consistently.
Changing On Error mode or returning from a procedure does not itself clear Err.
No syntax was added; public trapping/Resume remains outside the current subset.

The production shared support already satisfies its supported fields, so its
source is unchanged: 2,398 bytes, SHA-256
D26C05C8B8BC61D55C5752BD8D660A06285D0FAD429A055525B585CA669D9C8C.
New maintained cases distinguish absent description from absent source, observe
replacement through the existing managed text accessors, preserve the new record
on successful reads and check explicit clear. Deliberately retaining an older
description or source must fail with oracle codes 9 and 10 respectively.

~~~powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/check-error-support.ps1
rtk proxy powershell -NoProfile -File docs/assets/tools/validate-docs.ps1
~~~

Both passed. Error report:
bootstrap/out/error-record/9c6c19988df443899daa405a1d356422/report.json,
23 compile/run commands, including Full/None record tests, six intentional
wrong-error/stale-description/stale-source failures, rebuilt ordinary runtime
and the retained error_state/integer_failure/integer_storage probes.
Static manual validation passes all 274 HTML files. Direct browser checks remain
unverified because both browser-control startup attempts failed before exposing
a surface. No Resume execution or full native-executable acceptance is claimed.

The private fixed buffers may retain bytes beyond their terminating NUL, as
already specified and tested by this substrate's byte-level oracle. Those bytes
are not visible Err text and do not inherit a public field value. The private
revision counter is bookkeeping, not an additional public error-information
field. No source algorithm, stack path, generated helper body or resource cap changed.
