# Class instance members

This increment implements the existing class-member requirements within the
complete-language roadmap. It builds on genuine managed class identities and
the existing precise collector; it does not introduce inheritance, a second
object model or a shared class-member surface.

## Qualified implementation boundary

Ordinary class Sub/Function members receive a statically bound instance.
Unqualified fields/methods and explicit Me use that same identity. Me is
read-only, including direct writable ByRef; grouping follows the existing
temporary argument rule. Me is unavailable outside instance execution and in
declaration initializers. Private access is class-local and Friend remains
package-local; class members never enter the global standard-module lookup
pool. A class name cannot invoke an instance member without a receiver.

Fields currently admit scalar, String, Variant, class/Object reference and
finite-record values. Each new object receives neutral per-instance storage.
Reference assignment preserves identity. Scalar field accesses and nested
record fields reuse existing checked loads, stores, conversions and managed
write barriers. Arrays, declaration initializers, lifecycle hooks, properties,
events and interfaces remain unsupported and receive diagnostics. Class
methods as CallNew targets, and field aliases that escape directly or
transitively to asynchronous work, remain unsupported. Ordinary synchronous
field ByRef arguments retain their owning receiver throughout the call.

## Storage and calls

AggregateLayout retains InstanceCells and InstanceReferences independently of
the one-cell class-reference layout. Field offsets follow declaration order;
finite records reuse their existing layout and exact managed-reference offsets.
NativeManagedLayout emits a separate immutable object payload layout. The
existing object.create and nominally checked object.address runtime operations
allocate/access that payload. No runtime ABI change is required.

A method has a hidden identity argument rooted in its own invocation frame.
An explicit receiver is evaluated once and retained before subsequent argument
evaluation, including collection and replacement of its original source
variable. The checked receiver address rejects Nothing before remaining work.
Existing fresh FAIL results, default statement skipping and caller handlers
remain unchanged. Class fields are excluded from module storage, ordinary
local frames and module startup initialization.

The compiler's native-tool deadline is now 60 seconds. A solo current-compiler
LLVM build completed normally in 37002 ms, exceeding the former 30-second
deadline. The bound, child cleanup, log bound, prior-output protection and
failure diagnostics remain enforced. The VB6 bootstrap retains its own bound.

### Warm compiler provenance

The first deadline diagnosis used the frozen `ube class compiler solo-20261127`
package. Qualified compiler `5c66c361/generation-2/UBE.exe` emitted its LLVM in
8062 ms; direct LLVM import generation took 45 ms and direct O2 compilation/link
took 37002 ms. The latter completed with exit 0 under a retained 120-second
host deadline. Evidence is `%TEMP%/ube class backend timing
a514b181-2194-4d30-ac1e-7ad5553fefb7`. This establishes that this build exceeded
the old deadline; it does not establish ordinary self-build qualification.

After the production deadline changed to 60 seconds, a fresh source package was
created with `bootstrap/tools/self-host-sources.ps1 -Kind Exe -Optimization 2`:
`%TEMP%/ube class warm compiler 6c98695a-c1f7-4eae-9bb5-af3e7e7e0382`.
It retains `sources.sha256`, matching LLVM assets, the packaged managed support,
and `initial-compiler.json` recording the qualified 5c66 compiler hash.
Runtime, template, import and managed-source parity checks passed before
packaging: 256588 runtime bytes, 335 templates/49431 bytes, 45 imports and
15 ordered managed-support sources.

The qualified compiler's actual `--emit-llvm` operation took 7931 ms;
`llvm-dlltool -m i386:x86-64` took 46 ms. A direct invocation of clang with
`--target=x86_64-pc-windows-msvc -fuse-ld=lld -nostdlib -O2`, the emitted LLVM,
the generated Kernel32 import archive and
`-Wl,/entry:main,/subsystem:console,/stack:8388608` completed in 32216 ms.
No stack-check suppression was used. The executable passes AMD64 PE32+
header assertions. Its SHA256 is
`B64CA9398D5060A32652494520703B8BB693A3797D1003F6E3177848F771B000`.
The operation JSON files retain exact arguments, exit codes and timings;
stdout/stderr are retained separately. Clang emitted only its target-triple
override warning. No synthetic `BUILD OK` log was produced.

This `UBE.exe` is a warm compiler produced by an explicit temporary host step.
Normal repeated self-builds and final acceptance must qualify its descendants;
the manual link itself is not that qualification.

## Acceptance

Commands use `rtk proxy powershell -NoProfile -File`:

- `compiler/tests/class-members/baseline-check.ps1 -CompilerExe <5c66 compiler>`
  records the old admission boundary, not a requirement that new code rejects.
- `compiler/tests/class-members/binding-check.ps1 -CompilerExe <5c66 compiler>`
  compiles the actual frontend and checks receiver/visibility/rejection facts
  with positive and changed-expectation/escaping-FAIL controls at O0/O2.
- `compiler/tests/class-members/check.ps1 -CompilerExe <candidate>`
  checks source execution, exact real-collector reachability/retirement and
  located diagnostics/output preservation.
- `bootstrap/tests/concurrent-compilation/check.ps1 -BootstrapExe <qualified seed> -ClassOnly`
  compares independent LLVM baselines against simultaneous and swapped class
  requests with different instance layouts.
- Repeat self-build, common CLI conformance and the full concurrency gate
  qualify the integrated compiler. Native-backend regression covers the
  bounded deadline and retained-owner cleanup.

The tests use actual source and collector state. Compiler success or LLVM
shape alone does not establish execution or lifetime correctness. Current
evidence and remaining language work are recorded in Progress.md.

## Final compiler qualification — 2026-11-27

Final compiler: `%TEMP%/ube compiler rebuild 97b47838-ae5e-43b6-94dd-45ef39c127d2/generation-2/UBE.exe`,
SHA256 `5510298EAFD95492DD619683B3B562A07408F5764894EDCE0D86D10646B3DA98`.
All commands below start with `rtk proxy powershell -NoProfile -File`.
The qualified seed is the e0874b0b package recorded in Progress.md.

| Gate | Command and result | Evidence directory under %TEMP% |
|---|---|---|
| Repeated ordinary build | `bootstrap/tests/self-hosting/rebuild-check.ps1 -InitialCompilerExe <6c98695a warm compiler>`; PASS, 41188/40612 ms, identical sources/assets and LLVM, native differences only in COFF timestamp | ube compiler rebuild 97b47838-ae5e-43b6-94dd-45ef39c127d2 |
| Common conformance | `bootstrap/tests/self-hosting/check.ps1 -CompilerExe <final compiler> -BootstrapExe <e0874b0b seed> -CompilerOnly`; PASS 518 assertions, including real 60-second backend timeout and unchanged prior output | ube compiler conformance b73b763b-38b4-45e0-b519-2c858f581232 |
| Class source, GC and allocation | `compiler/tests/class-members/check.ps1 -CompilerExe <final compiler>`; PASS 28 checks: six execution, four collector, four allocation/retention-control and fourteen located diagnostics | ube class members 2896db41-3e1b-4936-a723-d067879c06b5 |
| Failed field assignment | Same command with `-Suite Execution` after adding failed-RHS destination preservation; PASS six O0/O2 runs | ube class members fef0316a-d721-4bc7-a6a4-8be993413c27 |
| Concurrent classes | `bootstrap/tests/concurrent-compilation/check.ps1 -BootstrapExe <e0874b0b seed> -ClassOnly`; PASS six independent/simultaneous/swapped class cases | ube concurrent compilation dd38aac0-e36d-4c1d-b70a-9958dd972e1e |
| Full concurrency | Same command without `-ClassOnly`; PASS all existing worker, quota, publication, cleanup, backend, context and class cases; timeout/recovery at 61119 ms | ube concurrent compilation 1de79e39-72f7-4f57-9b4f-6e56b6a67138 |
| Layout regression | `bootstrap/tests/semantic-storage/check.ps1 -BootstrapExe <e0874b0b seed>`; PASS 78 cases/26357 assertions at O0/O2, changed-role rejection at assertion 432 and production no-stack-probe checks | ube semantic storage 925b8737-5d97-4fe7-8a5d-96aa0c743f5f |
| Backend deadline | `bootstrap/tests/native-backend-ube/check.ps1 -BootstrapExe <e0874b0b seed>`; PASS 13 probes at O0/O2, logical 40-second success, 60-second timeout, retained cleanup/retry and restored-30-second negative control | ube native backend e1b3de98-5484-4f3b-bf7f-630c762d8d1b |
| Class admission | `compiler/tests/object-monitors/admission-check.ps1 -CompilerExe <final compiler>`; PASS 13 cases, including fields/methods admitted and exact hook rejection | ube class admission fe571e0c-b373-41aa-9ab4-618e3b73c24d |
| Empty-class references | `compiler/tests/object-monitors/reference-check.ps1 -CompilerExe <final compiler>`; PASS six O0/O2 runs | ube object references 41cf9b36-ea4b-4073-90e8-b9f6e5584233 |
| Locks | `compiler/tests/object-monitors/lock-check.ps1 -CompilerExe <final compiler>`; PASS six runs | ube object references 2297e4fd-8efa-45dd-9839-f0c1ec99bd77 |
| Exact cleanup | `compiler/tests/object-monitors/cleanup-check.ps1 -ProgramIR <2297e4fd/locks-O0-positive.ll>`; PASS four O0/O2 oracle/control runs | ube source monitor oracle 84723486-b7ff-4cae-986c-8e898a8ad2dd |

Successive LLVM SHA256:
`143356806E42645A588DB10005A3A44D7D8945275A2F23D50C9D6A2DB57530A4`.
The earlier seed-only conformance result is reused explicitly; no new seed
language feature is claimed. The frontend gate passes 20 cases with six O0/O2
positive/control runs in `ube instance binding 34ea17fd-9e12-4df8-b0f7-cafdb025221e`.
Package validation passes 350 assertions in
`ube self-host sources 1c6f056f-ddc7-4ea4-87c5-406df2c79f94`.

The displayed Counter example passes all four extracted O0/O2 expected/changed
runs on the final compiler (`ube class example 8720ba37-58a0-4690-9f18-034fe8807b7c`).
Documentation validation passes 278 pages/4806 references/191 word pages and
13 navigation logic groups. Browser rendering, clicked local-file navigation
and clipboard checks remain unverified because browser access is unavailable.


The combined class gate includes failed-RHS destination preservation and real
allocator failure through construction retries. Default and handled failure
preserve the old object, report Err 7, leave no candidate object behind, and
permit later successful construction. Actual registry observations and inverted
retention controls pass at O0/O2; negative controls exit 4 as required.
