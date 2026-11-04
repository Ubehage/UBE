# Declaration work accounting review

The owner approved the documented 3*D correction on 2026-11-03 by selecting
option 1 in the pending review question. NATIVE-RESOURCE-CONTRACT.md and the
independent resource oracle now reflect that decision. All resource caps and
body/argument traversal bounds are unchanged. This approval covers preparation,
signatures and entry storage. The owner subsequently approved the separately
counted I import allowance and further necessary increases, as recorded below.

The original 2*D counterexample and pre-approval evidence follow. They remain
historical proof of the accounting gap, not claims that the complete native
lowering is now resource-qualified.

## Reproduced gap

`NativeDeclarations.bas` visits every checked declaration once to prepare stable
target identities and ABI fields. `NativeBodies.bas` subsequently reads each
procedure definition, visits its parameters for the LLVM signature, and visits
its member list for entry storage. The latter visits must count even though
they read prepared target rows rather than original source declarations.

The eight-procedure fixture in `tests/native-executable/graph/bodies.c` has
23 declarations: one module, eight procedures, eleven parameters and three
locals. Its definition emission visits eight procedure rows, eleven signature
parameters and fourteen entry members: 33 visits. Combined declaration work
is therefore 56, exceeding the existing 2*23 = 46 bound. Body traversal work
is separate and remains 2*V+E for emission.

The revised independent source-inventory/work assertion fails against the
previously passing production body, retained as
`../../bootstrap/out/native-graph/ef1c2d437ec34098a6fac7594689ecf2/stage0/adapter.ll`.
The exact focused commands, from the repository root and then the diagnostic
directory respectively, are:

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -O2 -Wall -Wextra -Werror -I . bootstrap/out/native-graph/ef1c2d437ec34098a6fac7594689ecf2/stage0/adapter.ll compiler/UBE_Compiler_v3/tests/native-executable/graph/bodies.c bootstrap/out/v2/df15817344774026bebebfd1e9ae8eaf/bootstrap_unicode_runtime.o -o bootstrap/out/native-body-diagnostic/declaration-work/before.exe
rtk proxy .\before.exe
```

Clang returned 0; the observer returned 1 at the new assertion
`emitted_work==3*(int64_t)live-8+33`. Production now charges those definition
visits with `TryVisitNativeIndex`, including the existing cancellation and work
limit checks. The complete two-stage graph gate subsequently passed in
`../../bootstrap/out/native-graph/b4674599705a458ab587e2e4c027d93b/report.json`:
18 groups, including 761 graph and 2,105,845 body assertions per stage.
Generated program LLVM remains byte-identical to the pre-correction result.
The retained old-code failure and exact source/artifact identities are in
`../../bootstrap/out/native-body-diagnostic/declaration-work/before-report.json`;
`before-observer.c` retains the then-current observer bytes.

The independently expanded boundary probe passed 2,105,999 assertions against
each current retained adapter. It checks zero/early/below/exact/above work
allowances, actual consumed work and complete partial-owner cleanup. Exact
commands, input identities and terminal results are in the sibling
`boundary-report.json`. The expanded probe was then promoted byte-identically
to the maintained `graph/bodies.c` (SHA-256
`CD41F763D72AAD598FFF8C701603DC8AD65D38DC61694F8A4982E27FF0B60DD8`).
These passes establish accurate charging and the tested behavior, not compliance
with the unchanged 2*D formula or approval of the proposal below.

## Approved bounded correction

Retain one declaration/identity preparation scan. Permit one definition visit
per emitted procedure/global/local and two per parameter: signature and entry
storage. Their combined declaration contribution is at most 3*D, where D is
the complete checked declaration count. With the subsequently implemented module
initializer definitions included, a sharper expression is D+M+F+G+L+2*P
for emitted module initializers, procedures, globals, locals and parameters; unused
non-emitted declarations do not create extra visits. Constant-time resolved
target lookups performed while emitting a body node or argument are part of
that counted node/argument visit, not an additional whole-declaration scan.
Future source/debug/warning consumers must account for their own visits under
their applicable bounds; this correction does not grant uncounted rescans.

Keep both body walks, the 2*A argument-map bound, all default resource caps,
canonical serial output, stable identities, existing ownership and cancellation
rules unchanged. No new pass over procedure bodies, output buffer, public IR,
worker pool or target behavior is proposed. The cumulative work ceiling still
limits all actual charged visits and produces controlled UBE1502 exhaustion.

The contract and independent oracle are synchronized with the approval. Retain
the failing control and exact-limit proof above, and extend whole-program
measurements as the remaining lowering is integrated. Approval changes the
accepted bound; it does not replace whole-lowering resource qualification.

## Approved additional typed-import work

The owner approved the necessary increases on 2026-11-03: "You may approve
whatever increases are needed to make it work." This authorizes the documented
3*D+I allowance below and further necessary, evidence-based resource adjustments.
Keep actual costs, bounds and failures explicit; no numeric cap is increased by
this change. Future adjustments do not require another approval question under
that authorization, but still require documented rationale and qualification.

The approved 3*D correction does not include repeating a foreign procedure's
typed declaration in each output module that uses it. The concrete fixture in
`tests/native-executable/resources/import-work/` has ten executable modules,
each calling the same public library Function with twenty ByVal Long parameters.
Its retained qualified checker/declaration adapter confirms at jobs 1 and 4:

- 42 checked declarations: 11 modules, 11 procedures and 20 parameters.
- Preparation plus ordinary definitions requires 42+11+40 = 93 visits, even
  before the 11 module initializer definitions are included.
- Ten distinct importing outputs require ten typed procedure declarations and
  200 formal-declaration visits: 210 additional visits.
- The minimum 303 visits already exceeds 3*42 = 126. Including module initializer
  definitions yields 314. This is an output-boundary requirement, not a request
  for a repeated scan of all declarations per module or call.

Exact command:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/resources/import-work/check.ps1
```

It returned exit 0 in
`../../bootstrap/out/native-import-work/b37361a2198c4ae4977be7688244d189/report.json`.
The probe reads actual checked module nodes and prepared targets, asserting one
resolved twenty-argument foreign call in each of ten sources. The report pins
the retained qualified adapter, native observer, source fixture and tool inputs.
It proves this count counterexample; it does not implement native module output.

Approved addition: retain the approved 3*D own-declaration bound and separately allow
I typed-import visits, where I is one visit per distinct imported target per
output plus one per formal of an imported ordinary procedure. Discover and
deduplicate targets during the already approved graph-planning walk, then emit
only that bounded list. Do not scan all project declarations for each module.
ByRef's pointer and owner are emitted in the same formal visit; intrinsics and
folded constants need no ordinary foreign procedure declaration.

For user graph references, I is at most V+A: each distinct imported target has
a referring node, and each distinct imported signature has a call whose checked
argument associations cover its formals. The separate startup reference to the
parameterless Main adds at most one. Thus I <= V+A+1, with actual I charged to
the existing cumulative work cap. This does not add a body traversal or argument-
map traversal, change those bounds, increase any numeric cap, or permit uncounted
lookups. Private import-map payload, zeroing, copying, cancellation, allocation
failure and cleanup must be documented and qualified with the implementation.

The adopted bound is 3*D+I, not an increase to a fixed multiple of D that could still
be exceeded as more modules share a large signature. It preserves fully typed
LLVM declarations and the adopted ABI. Production import emission may now use
this allowance; whole-lowering acceptance still requires implementation evidence.

The implemented module consumer is now qualified in NATIVE-MODULE-IMPLEMENTATION.md.
The same 42-declaration fixture measures 126 own visits plus 210 import visits;
the extra own visits include module/member selection omitted from the earlier
minimum counterexample. Total lowering work is 2,925 with exact-cap success and
controlled failure at 2,924. No further allowance or numeric cap increase was
needed. The current full-module own contribution remains within 3*D.

## Expected linkage table - 2026-11-03

The owner also authorized: "You may approve whatever increases are needed to
make it work." The reviewed debug/retention contract requires a frozen expected
identity table before native tools. NativeExpectations now traverses the ready
lowering target catalog once, charging every row to the existing native work
ledger, as well as its separate inspection event/payload budgets. The focused
nine-declaration regression measures exactly nine additional visits; exact nine
and one-below eight work limits distinguish success and controlled exhaustion.
Missing-row and omitted-work controls reject. NATIVE-EXPECTATION-EVIDENCE.md
records the two-stage component evidence, storage/cancellation boundaries and
subsequent actual checked-project integration.

The adopted combined declaration/import bound is 4*D+I: the existing lowering
contribution stays within 3*D+I and expectation freezing adds D once per build.
No numeric cap or body/argument bound changes. Fixed support rows and name-byte
construction also consume inspection events. This does not authorize a per-module
whole-catalog scan or claim that the current full native builder is qualified.

The full checked-project graph gate now measures the added pass on both
three-source root/reference layouts at jobs 1/2/4 through both bootstrap stages:
D=38, exactly 38 extra native visits, 54 rows, 647 name bytes, 742 inspection
events and 5,808 owned payload bytes. The optional error helper adds one row
per source, changing capacity to D+3*M+19 without another declaration visit or
any numeric cap change. NATIVE-EXPECTATION-EVIDENCE.md records the full command
and report. This measures expectation construction alongside existing writer
charges; it is not a complete native-builder resource acceptance claim.
