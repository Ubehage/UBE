# Collector algorithm gate

Run `collector-check.ps1 -CompilerExe <qualified UBE.exe>`.

This compiles the production `ManagedMemory.bas` with a test-only ordinary UBE
snapshot adapter in place of native ManagedPrimitives. It checks the traversal
and error decisions independently of the unfinished native runtime. Neither the
adapter nor its graph storage is installed as program support.

At O0 and O2 the gate asserts exact surviving allocations and release counts
for a rooted 100-node cycle, duplicate roots and a disconnected 28-node cycle;
root removal and a repeated empty pass; workspace, edge-reading and late
allocation-enumeration failures without any sweep; recovery after partial marks;
retained storage on simulated native-release failure; and joined-round status
without a second EndCollection. It also checks explicit versus opportunistic
error publication, including an owned opportunistic failure, and rejection of
an invalid nonzero edge before sealing. A changed expected release count must
fail at both levels.

Command with generation-2 compiler from rebuild `30c8f236` passed all of these
assertions in evidence directory
`%TEMP%\ube collector algorithm 23f188b9-40f6-4e17-beea-8c041ac38600`.

After workspace retirement was added, the same command passed at O0/O2 in
`%TEMP%\ube collector algorithm 80fbfd8d-4336-4e4d-9c25-13201e10ec4d`.
The adapter rejects snapshot release while workspace remains leased. A second
negative control removes the production retirement call and must exit 1 at
both levels. Successful and failed owned passes retire their workspace before
EndCollection; joined passes do not own or release workspace.

This is algorithm evidence only. Actual precise roots, native release,
allocation pressure/retry, thread rendezvous, barriers and String storage still
require the native integration acceptance gates in `compiler/TEXT-SUPPORT.md`.
