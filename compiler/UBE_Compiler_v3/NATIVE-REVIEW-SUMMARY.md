# First native executable: short review

This summarizes the completed bounded contract preparation and review. The native
backend has not been implemented by this work. The detailed
contract and evidence are in `NATIVE-EXECUTABLE-CONTRACT.md` and
`NATIVE-CONTRACT-REVIEW.md`.

## Where things stand

The first target and the visible build behavior have been agreed. The work
here is the design and review for that target; UBE does not yet build the
native executable described below. Test projects have passed the existing
frontend checker, and separate host experiments have helped test parts of the
design. Those experiments do not prove the future compiler works.

The design choices are now recorded, including path acquisition, stack safety,
bounded diagnostic delivery and the finite production debug-information check.
The next step is implementation and qualification under those contracts,
starting with the required shared error support and counted output facilities.
Core replacement, resource and tool-lifecycle policies are selected.
The detailed evidence and remaining conditions are below. The owner confirmed
that a separate output hard link can be replaced for any build input, provided
the original stays untouched. The owner clarified that source changes during a
build are the user's responsibility. UBE does not monitor changes or reject or
retry a build because of them. A build may succeed with unintended behavior in
the resulting program; the compiler does not promise source consistency.
Changing sources need not produce a compiler error, and UBE is not responsible
for discovering any resulting inconsistency in the program.
The new build command's message format is now settled: errors and warnings go
to stderr, redirected success is quiet, and a confirmed console receives
`built "<path>"`. Existing check output stays unchanged. Exact output examples
are prepared; the new command and its output handling still need implementation
and testing.

The initialization-warning policy is also selected. It follows helpers called
from initializers and possible aliases passed through ByRef, groups each cycle
into one warning and excludes uncalled helpers and downstream-only modules.
It may warn conservatively when a path cannot occur at runtime. A 21-case graph
model and three adverse controls pass; compiler integration and native alias
behavior still need implementation tests.

## Decisions already made

- Start with the checked numeric, Boolean, variable, procedure, `If`, `While`
  and supported native-type subset. Strings, arrays, classes and forms wait.
- Normally initialize referenced libraries before executable modules; initialize
  each module's scalar declarations in written order.
- If initialization accesses another module that has not begun initializing, complete
  that module's initialization first; do not repeat it later.
- Circular initialization references are permitted. A different module cannot
  read an unfinished module; mutually waiting initializers may keep waiting
  until stopped. The compiler warns about detectable circular references, and
  the future IDE must be able to show the warning.
- Default to `build/<project name>.exe` beside the project, with an output-path
  override. A failed build preserves the previous executable; a successful
  build replaces it without another prompt.
- Show a brief success message on a terminal without interrupting scripts.
  Report tool failures clearly. After a successful publication, a cleanup
  problem is a warning and does not turn the build into a failure.
- Include debug information for the optimized program. It must describe the
  actual optimized code and must not change observable behavior; an
  optimized-away value may be unavailable.
- A signed integer minimum `Mod -1` returns zero without a new error and
  preserves any existing `Err`.
- When another call cannot be entered for lack of stack space and recovery is
  safe, skip the callee, return its neutral result if applicable and set Err 28.
- A successful build may replace an ordinary file another program put at the
  output path during the build. Source and other build inputs still need
  protection, and a failed build must not alter the destination.
- A successful build may also replace a separate hard link to a build input that
  another program placed at the output path during the build, provided the
  original input stays untouched. The compiler does not modify source files and
  need not detect changes made by the user during a build.
- For the first target, checked integer overflow or out-of-range narrowing
  uses error 6; integer division or remainder by zero uses error 11. This
  follows the existing bootstrap behavior and VB6-compatible defaults.

## Selected designs and future acceptance

1. **Safe publication:** the entry-ownership policy is selected; the complete
   path/commit design is in `NATIVE-PATH-CONTRACT.md`. Reject input/output aliases
   initially, then replace only the admitted output entry under its held parent.
   Source edits and replacement saves are allowed. A separate late input
   hardlink may be replaced while the original stays untouched. This does not
   track a source object that the user deliberately moves into the output slot;
   the documented engineering interpretation permits replacing that slot.
   Nontransactional extended handle rename is now the selected core commit
   direction. A combined ordinary-path prototype passed 16 cases, including
   source edits and replacement saves, initial aliases, late links, candidate
   protection, cancellation and denied replacement. The initial local NTFS path
   domain and guarded acquisition are selected; production integration and
   host qualification remain required. TxF and pathname
   replacement are historical alternatives, not selected fallbacks. Exact
   assertions and limitations are in
   `tests/native-executable/REPLACEMENT-PROBE-EVIDENCE.md`.
   The existing source reader permits write/delete sharing and closes each file
   after intake. Source changes are the user's responsibility; input protection
   for publication remains a separate requirement.
2. **Tool boundary:** host probes exercise contained processes, output drainage,
   cancellation and argument handling. The Windows review selects suspended
   process creation, explicit handle inheritance and Job assignment before
   resume as the direction for containment. `NATIVE-TOOL-CONTRACT.md` now selects
   the identity scope, encoded argument limits, ten-minute invocation limit,
   five-second completion and stop/drain limits, and overlapped capture ownership.
   An unresolved invocation retains its resources and blocks another tool launch.
   Production implementation/qualification of the tool and selected common path
   acquisition remain required. The stdin-streaming experiment is not a selected replacement
   for the current closed-input draft. See
   `tests/native-executable/JOB-CONTAINMENT-EVIDENCE.md` and
   `tests/native-executable/FAILURE-ORACLES.md`.
   The draft now selects the compile/link commands: optimized LLVM compilation,
   a separate link of those objects through an explicit LLD path, and disabled
   object/executable timestamps. Full uses DWARF 4 debug information. Corrected
   host tests exercised that complete sequence in Full and None modes and
   checked an LLVM-only changed-result control. Support resolution now uses
   explicit startup/archive paths and a selected child environment, disabling
   default configs and library directives. Full/None recompilation and linking
   matched the earlier bytes and result; omitted-option controls failed as
   expected. The concrete 13-file support cohort is recorded. The selected
   identity policy pins tools/non-OS dependencies and treats Windows system
   components as host prerequisites; it does not freeze the OS DLL graph.
   The private Err support
   and observer boundary are selected in `NATIVE-RUNTIME-CONTRACT.md`. Its
   implementation must extract one shared error unit: the whole bootstrap
   runtime retained unrelated library/GC exports even with dead-section removal.
3. **Resource limits and validation:** `NATIVE-RESOURCE-CONTRACT.md` selects
   initial serial lowering, bounded traversal and byte storage, numeric caps
   and work/copy accounting. Generated LLVM and accepted executable length each
   have a 256 MiB default cap; owned lowering payload has a 1 GiB cap. These are
   engineering limits, not measured usage or total memory/disk guarantees.
   Implementation must qualify the counted writer, actual costs, overlap and
   failure behavior. The stack strategy is selected in `NATIVE-STACK-REVIEW.md`;
   the resource caps do not establish runtime stack safety.
   The selected guard establishes committed stack space once at startup
   and uses a cached boundary plus closed error-recording helpers. Its host
   invariant, complete footprint and fatal path require implementation qualification.
   `NATIVE-STACK-REVIEW.md` collects the confirmed recoverable behavior,
   evidence and remaining guard obligations. If recovery is not safe, its
   proposed noninteractive failure path still needs qualification.
   A focused stack measurement found that the experimental frame metadata
   omitted the call's return address. That accounting is corrected and its
   controls pass; it does not yet establish the full recovery reserve.
   The baseline candidate-length check is explicitly post-write; it is not a
   hard disk quota. Windows per-owner and server directory quotas have different
   scopes and are not selected as a portable default.
   See `tests/native-executable/RESOURCE-ORACLES.md` and
   `tests/native-executable/verifier/EVIDENCE.md`.
4. **Candidate checks:** `NATIVE-CANDIDATE-REVIEW.md` now selects bounded
   header, section, entry and directory-range checks. The host probe rejects all
   22 malformed-layout cases that its omitted-check control accepts, and the
   independent structural suite passes for the selected Full/None outputs.
   Count-boundary and permitted-layout controls also pass. Implementing those
   checks and binding the inspected candidate to the published file remain
   open. Zeroed code still passes the structural profile: independent execution
   tests establish behavior for their fixtures; headers cannot establish program
   correctness. Nested directory contents and debug semantics are separate.
   `NATIVE-DEBUG-CONTRACT.md` selects finite program-unit, procedure,
   declaration and line-record admission; independent Full/None execution and
   source/value mapping tests remain required.
5. **Diagnostic delivery:** prepare one final batch, use one owned I/O thread
   and finite controller deadlines, and preserve the build result if delivery
   fails. Unconfirmed writes retain their owner; they do not accumulate further
   writers. Redirected success remains quiet. Exact limits and future tests
   are in `NATIVE-BUILD-DIAGNOSTICS.md`.

## Publication options reviewed

These dispositions apply to the tested combinations, not every use of the
named Windows APIs. None is yet a qualified default for the first build.

| Candidate | Evidence | Review disposition |
| --- | --- | --- |
| Extended rename after an identity check | The test could substitute a protected hard link after the check; the rename replaced that destination name. | A late separate input hardlink may now be replaced; the check and replacement still race for original protected entries and path redirection. |
| Hold the destination without delete sharing and call `ReplaceFileW` or the tested extended rename | On the local host, the same sharing guard that blocked a competing move also blocked the compiler's replacement. | The tested combination cannot provide successful overwrite while holding that guard. |
| Hold the input without delete sharing | A substituted hard-link destination was replaced while the original input's identity, bytes, creation and last-write times, attributes, security descriptor and named stream matched the snapshot. | Consistent with the owner's late input-hardlink decision in this local case; parent-path acquisition and other filesystem cases remain unqualified. |
| Transaction-bound handle rename plus tested guards | Selected tests combined candidate identity, a guarded junction, rollback and reader observations; other combinations remain unqualified. | Promising local evidence, but TxF's documented portability concern and the remaining combined tests prevent selection as the default. |

The selected publication implementation must establish input/output separation during admission,
retain the admitted output parent and leaf, bind
the inspected candidate, and give a decisive commit result without relying on
a deprecated facility as an unexamined portability assumption. A successful
build may replace an ordinary file substituted during the build. Source object
tracking after user relocation is not part of this requirement. An implementation that cannot establish
these conditions on a host must fail before replacing the destination. The
fault-injection and observer requirements are in
`tests/native-executable/FAILURE-ORACLES.md`; the detailed host results and their
limits are in `tests/native-executable/REPLACEMENT-PROBE-EVIDENCE.md`.

The independent fixtures specify expected results and failures. Frontend
admission and host-only experiments are useful preparation, but they do not
show that a future native executable, debugger information or runtime `Err`
works. Those are acceptance checks for the implementation.
