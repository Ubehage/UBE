# Native Windows stack support

This implements the selected target mechanism from NATIVE-STACK-REVIEW.md and
the private entry interface from NATIVE-ENTRY-IMPLEMENTATION.md. The compiler
emits native LLVM support in UBE; no additional C runtime algorithm is introduced.
The output owns one zero-initialized native TLS floor. Reserve and frame data
remain separately linked immutable metadata bound to the actual objects.

Startup receives the actual caller stack pointer and complete first initializer
footprint. It rejects zero values, queries the byte immediately below that
pointer, and obtains the containing allocation. It then walks reported regions
forward from that allocation to the caller pointer. Each query must return the
full selected 48-byte Windows x64 MEMORY_BASIC_INFORMATION record. Validate
nonzero region size, containment, checked end-address arithmetic, strict forward
progress and unchanged allocation ownership. Only committed private read/write
or execute/read/write pages without PAGE_GUARD extend the current writable run.
Reserved, guarded and inaccessible regions reset the run; free/unknown state or
inconsistent metadata fails the scan. Do not read Protect for reserved pages or
undefined allocation fields for free pages. No queried page is touched.

The last writable run must reach the caller pointer. Compare the immutable
reserve and first footprint against available bytes using checked subtraction.
Publish the floor only after the entire scan and both comparisons succeed.
Failure preserves any previous floor and UBE Err, returns false, and lets the
ordinary entry return status 1 before user code. Startup allocates only one fixed
48-byte record on its own native stack. It performs no heap allocation, output,
worker creation or recursive calls. Region progress bounds the loop by the
queried allocation; no fixed page size or later guard-page growth is assumed.

The fatal path requests TerminateProcess on the current-process pseudo-handle
with status 1 and uses ExitProcess(1) only if that request returns failure.
The wait path loops over non-alertable Sleep(INFINITE), with no module re-entry.
Their own frames and platform call paths require separate qualification. No
real-time termination promise, derived recovery reserve or universal Windows
stack guarantee follows merely from these implementations.

The compiler emitter owns no scratch arrays or host resources. Its fixed output
identities and bytes use the existing cumulative counters; private partial
output is disposable after failure. Runtime state is native-thread-local, and
the admitted language creates no threads, foreign entries or switched stacks.
The existing startup/lifetime host invariant remains mandatory.

The query's return/region semantics and field validity follow Microsoft's
[VirtualQuery](https://learn.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-virtualquery),
[MEMORY_BASIC_INFORMATION](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-memory_basic_information)
and [protection constants](https://learn.microsoft.com/en-us/windows/win32/memory/memory-protection-constants).
Tests must independently assert ABI offsets, malformed responses, fragmented
regions, guard preservation, failed publication, real stack-floor agreement and
both optimized/debug configurations. Full linked frame/reserve binding and
startup/fatal/wait safety remain acceptance work until their gates pass.

## Implementation and focused diagnostic

`src/NativePlatform.bas` implements `TryEmitNativePlatformSupport` using the
existing bounded LLVM writer. The output has 103 fixed identities, no declaration
or body visits, and no emitter-owned scratch allocation beyond the existing
output buffer. It is registered in the production compiler manifest. No numeric
resource cap or declaration/body traversal bound changed for this support.

The emitted scan checks complete query results before inspecting fields. It
branches on committed/reserved state before reading fields whose meaning depends
on that state. Address addition must produce an end strictly greater than the
base and current cursor; the cursor must lie in the reported region, whose base
cannot precede the original allocation. Only the final uninterrupted writable
suffix counts. The compiler emits one fixed 48-byte query record; target register
spills, saved registers and outgoing space also contribute to its machine frame.

The initial maintained run is retained in
`../../bootstrap/out/native-initialization/a8e05f34161241a8a151c5776df7396b/report.json`.
Its first-stage UBE emission/resource checks passed, then its LLVM-only object
compile rejected an unused C include-directory option under `-Werror`. The runner
now uses separate IR-only options. This correction did not change production code.

The focused rerun of that retained UBE output passed 67 groups and 226 commands
in 44,312 ms:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/out/platform-diagnostic/6911f65b3d554790ac8ad5915462ab77/check.ps1
```

Its report is beside the script. The four O0/O2 and Full/None configurations
each pass 560 synthetic assertions with ordinary test reserve, 12 with zero
reserve, 22 with insufficient reserve, and 47 real Windows-memory assertions.
Synthetic cases check malformed extents, overflow/nonprogress, ownership, state,
permissions, query failure/short results, exact capacity and failed publication.
The real oracle independently walks pages backwards using the system page size;
fragmented test allocations retain their guard protection and reject inaccessible
suffixes. Every check preserves UBE Err and its revision. The synthetic oracle
rejects separate guard-removal, admission-bypass and failed-publication mutations.

The ordinary/common entry is linked unchanged to the actual platform object,
shared initialization data and controlled C initializers/Main. Full/None O0/O2
cases cover Function Main with a referenced package and Sub Main in one package,
normal results, invalid reserve, insufficient initial capacity, later initializer
refusal and Main refusal. Setup failures enter no user code and preserve Err;
safe later refusals set Err 28. Both observed tuples and Windows process exits
are checked. Frame and reserve metadata in these cases are deliberately controlled.

Real fatal subprocesses return status 1 without output. Real wait subprocesses
remain waiting and are terminated by the bounded harness. Controlled API calls
check the current-process pseudo-handle/status, failed termination's ExitProcess
fallback, and repeated Sleep(INFINITE) if Sleep returns. This demonstrates the
selected behavior on this host, not a universal OS timing or stack-use bound.

The platform object has exactly the four expected Windows imports, `_tls_index`
and `ube.stack.reserve`; no emulated-TLS helper appears. Static own-frame reports
are 232 bytes at O0 and 152 bytes at O2 for initialization, and 40 bytes for each
fatal/wait procedure in both debug configurations. These numbers exclude each
call's return address and do not bound the called Windows API implementations.
They are not the recovery reserve or complete startup safety qualification.

## Two-stage component qualification

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/initialization/check.ps1 -DiagnosticOnly
```

Report `../../bootstrap/out/native-initialization/0e93680c383b42ebb2e2379d6ce0b931/report.json`
passes 358 groups and 1,094 commands in 280,734 ms of recorded command time.
Each stage passes 2,097,617 emitter/resource/cleanup assertions. The 12 recorded
timeouts are expected wait observations, terminated by the harness: four retained
initialization waits and eight actual platform waits. Allocation failure,
cancellation, exact/below output/identity/payload limits and exhausted root
registry coverage retain controlled failures and complete cleanup.

Both raw compiler outputs are identical: 964,955 bytes, SHA-256
`A0ED96DC9841707BA89BE56C2BAA9B6A99B62828AA87CB09C62CC0C43F90FE95`.
Both emitted platform units are identical: 4,740 bytes, SHA-256
`E6E6F55E389CA8B1764846741ADD99FDF3B13FDE4A817ACE4F6931F81832F54E`.
The production source is 15,322 bytes, SHA-256
`4BD2B485890D21C574658891DAF775984F2529065B32A40EA402733F7A3A0FC7`.

The expanded maintained test is already registered in `bootstrap/build-v2.ps1`.
Its bounded harness deadline increases from 300 to 420 seconds because the
retained expanded matrix consumes about 281 seconds before wrapper overhead.
This changes no production compiler/tool deadline or resource cap. This run uses
the pinned historical bootstrap tools; it is not a refreshed source-built
bootstrap acceptance result.

The test host reports `Microsoft Windows NT 10.0.26300.0`. ABI assertions are
compiled against the selected Windows x64 headers. Full/None here means the
selected compiler flags and corresponding behavior checks; the support LLVM has
no source-level debug metadata, and this does not qualify program debug records.
All retained component input hashes still match after the run. The three affected
PowerShell scripts pass parser syntax checks through
`rtk proxy powershell -NoProfile -File bootstrap/out/check-platform-scripts.ps1`.

## Whole checked-project regression

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/graph/check.ps1 -DiagnosticOnly
```

Report `../../bootstrap/out/native-graph/927756dfc68f45b8b2f9770a039ca4e8/report.json`
passes 194 groups and 510 commands in 1,094,491 ms. Both complete compiler stages
are freshly compiled from the current captured source; no compilation is reused.
The stage compiler commands take 707,110 and 274,341 ms, within the existing
900-second per-command bound. Each stage passes 971 checked graph and 2,108,517
checked-body assertions. All captured input identities still match at completion.

The raw outputs are identical: 8,005,577 bytes, SHA-256
`BF52E59A3AE0C34ED8FA57E02D90697D7D91FF9C6D873D515990A2EB52798B2B`.
This retains actual checked module/import/body/entry behavior through the compiler
manifest containing NativePlatform. Its checked-project observers still use
controlled setup/metadata; actual Windows platform/entry behavior is independently
covered by the component gate above. These are distinct tested scopes.

The retained import-work gate passes six groups and 56 commands in 15,988 ms on
this exact compiler cohort:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/resources/import-work/check-emission.ps1 -ReportPath bootstrap/out/native-graph/927756dfc68f45b8b2f9770a039ca4e8/report.json
rtk proxy git -c core.safecrlf=false diff --check
```

Report `../../bootstrap/out/native-import-emission/79e6ca71228c43aca181c047c5819b48/report.json`
retains the 2,925-visit total, exact-cap success and controlled failure below it,
typed separate-object calls, immutable inputs and cleanup. The whitespace check
also passes. All command handles for this checkpoint are terminal.

Next bind complete frame footprints to the exact non-LTO objects, derive the
recovery reserve and qualify the startup/API and refusal closures. Production
debug validation, tool/publication integration and refreshed whole-bootstrap
acceptance remain pending. The First checked native executable goal is active.
