# Native control-flow and effective-target investigation

This is diagnostic evidence for the existing next native-validation work. It
uses the retained object corpus and qualified instruction boundaries; it is not
production whole-function or effective-target qualification.

## Retained inputs and procedure

The descriptor extraction uses the passing reader report
bootstrap/out/native-objects/4e22acebba4d44dcae5b06b3a297ec1c/report.json and the
112 immutable code objects selected by the retained extent-binding matrix.
The independent LLVM disassembly/oracle covers 36,192 instructions and 146,088
bytes. Both readers' extracted descriptors agree byte-for-byte in the explicit
transport and still match the independent length/flow/relative-displacement
oracles. Operand descriptors are observations, not independent operand proofs.

Command:

~~~powershell
rtk proxy powershell -NoProfile -File bootstrap/out/native-instruction-fields-diagnostic/run.ps1
~~~

The passing report, driver and analysis modules are in
bootstrap/out/native-instruction-fields-diagnostic/. analyze.mjs pairs code
relocations with instructions; analyze-flow.mjs derives ordinary COFF/pdata
function ranges and traverses local control flow. Their outputs are
field-analysis.json and flow-analysis.json. The scripts were evaluated as
modules through the Node REPL. Object identities and the two descriptor streams
are checked before analysis; no generated image is executed by these diagnostics.

## Instruction fields

All 5,712 code relocations fit exactly one decoded four-byte field. There are
4,824 REL32 fields and 888 SECREL fields:

| Observed field | Count |
| --- | ---: |
| REL32 memory displacement, four bytes from field start to instruction end | 2944 |
| REL32 memory displacement, eight bytes to instruction end | 184 |
| REL32 memory displacement, five bytes to instruction end | 104 |
| REL32 direct-call immediate | 1512 |
| REL32 direct-tail-jump immediate | 16 |
| REL32 RIP-relative indirect-call displacement | 64 |
| SECREL register-based memory displacement | 888 |

For REL32, the effective offset from the target symbol is the signed original
addend plus the bytes from field start to instruction end, minus four. The
288 instructions with a following immediate use addends -4 or -1, yielding
zero effective offset. Eight references to the anonymous .rdata contribution
use effective offset 19. Every direct call and relocated tail jump has effective
offset zero. SECREL refers to ube.stack.floor or ube_thread_error; 288 such
fields have nonzero member offsets. TLS section offsets must not be treated as
ordinary image virtual addresses.

The production instruction descriptor originally omitted the selected register
for register-indirect calls. Independent LLVM disassembly shows 16 such sites:
eight call through r13 in ube.stack.initialize and eight through rsi in
ube.module.wait. This is a concrete information-loss prerequisite for target
validation. TargetRegister now occupies the descriptor's former four-byte
alignment gap; qualification is recorded in NATIVE-INSTRUCTION-EVIDENCE.md.

Other indirect calls use RIP-relative IAT cells, register-based memory slots
and indexed slots. Those forms occur in generated procedure/module initialization
and common-entry code as well as platform support. Resolving a code contribution
alone does not prove the meaning or bounds of such pointer tables. There are
176 code relocations to .refptr.ube.module.initializers, matching the 176
register-based/indexed memory calls. NativeInitialization emits the initializer
pointer table, an unsigned owner-index bound check and the indirect call. That
source-level relationship guides the required native pointer-table and index
checks; it does not replace them. The register calls belong to VirtualQuery and
Sleep support paths, not the abort routine.

## Function boundaries and control flow

The independently parsed COFF symbols and ordinary .pdata records describe
416 functions: 360 framed functions and 56 leaves. Traversal under the
returning-call model has no instruction-boundary or extent escapes. All 288
instructions outside the resulting function extents are NOPs. The earlier
branch diagnostic separately identifies 5,224 local jumps and 16 relocated tail
jumps. These are observations over this corpus, not a production admission rule.

Treating every call as returning leaves 112 reachable INT3 sites. An alternate
model that assumes the named ube.stack.abort and imported ExitProcess calls do
not return leaves eight trap sites, all in the O0 ube.stack.abort success branch
after TerminateProcess. They are not register-call paths. The other observed
unreachable instructions in the alternate model are NOPs or INT3s.

The remaining success branch needs a qualified API/argument/result relationship.
Microsoft documents that self-termination stops the calling thread and does not
return; a failed call returns zero. See
[TerminateProcess](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-terminateprocess).
The emitted -1 handle is the documented current-process pseudo handle for the
selected platform; see
[GetCurrentProcess](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getcurrentprocess).
This supports the intended proof obligation: establish the actual import and
current-process argument, then admit only the failure continuation on a returned
call. The diagnostic does not establish those premises, nor does it authorize
ignoring arbitrary successful TerminateProcess returns for another process.

## Next production obligations

Preserve indirect-register target identity in the qualified decoder. Pair every
instruction relocation with its actual displacement/immediate field and compute
the effective target offset from the complete instruction, including trailing
immediates. Use qualified contribution and function ownership for direct
transfers; resolve pointer-table/import/TLS meaning for indirect transfers.
Whole-function traversal must check local destinations and terminal edges,
including the observed tail jumps and the explicit termination continuation.
Do not mark a trap safe merely because it follows a call or appears after a RET.

Full unwind operations, stack changes/call-site footprints, recovery-reserve
and startup/refusal closure, debug metadata, native tool/build/diagnostic/
publication ownership and final complete-source qualification remain required.
No language behavior, production cap, architecture or goal scope changes here.

## Signed linked-target counterexamples - 2026-11-03

After instruction-field pairing, the next address obligation is now isolated in
bootstrap/out/native-effective-target-diagnostic/driver.c and run.ps1. Command:

~~~powershell
rtk proxy powershell -NoProfile -File bootstrap/out/native-effective-target-diagnostic/run.ps1 -ReaderReport bootstrap/out/native-objects/cc7e1c28420e4154827555baf1850308/report.json
~~~

Passing report: bootstrap/out/native-effective-target-diagnostic/
791672625ae2495cbbb1912f05e1e2b0/report.json, four commands, 10,088 summed child ms.
Both stages assert six explicit cases through production field equality,
original instruction relocation offsets, and original/linked instruction readers.
All original addends are zero. Three signed-range boundary controls address the
intended target; three counterexamples do not:

| Form | Instruction RVA | Intended target RVA / section offset | Linked field | Decoded RVA / section offset |
| --- | ---: | ---: | --- | ---: |
| REL32 positive limit | 4096 | 2147487748 | 7fffffff | 2147487748 |
| REL32 positive overflow | 4096 | 2147487749 | 80000000 | -2147479547 |
| REL32 negative limit | 2147487744 | 4101 | 80000000 | 4101 |
| REL32 negative overflow | 2147487744 | 4100 | 7fffffff | 4294971396 |
| SECREL positive limit | n/a | 2147483647 | 7fffffff | 2147483647 |
| SECREL signed overflow | n/a | 2147483648 | 80000000 | -2147483648 |

The encoding comparison correctly accepts all six modulo-32-bit fields, and
field pairing correctly yields zero original addend. Those successes therefore
cannot stand in for signed linked-target correspondence. Next establish the
qualified target RVA plus effective addend within the image domain, its signed
32-bit distance from the complete instruction end, or the representable TLS
section offset. Compose that proof with linked-field equality and actual target
ownership/extent before admitting an access or transfer. Negative original
addends remain meaningful; this is not a blanket ban on negative displacements.

The first diagnostic attempt, 940d5998f2714d19bcf1708bf818cd23, failed to compile
because its driver copied the uninstrumented probe source. The corrected runner
copies and hashes the passing component's instrumented probe/runtime fixture.
No production code changed for that diagnostic repair. These are synthetic
address diagnostics, not a newly implemented effective-address acceptance gate.

## Subsequent signed-target implementation

NATIVE-INSTRUCTION-TARGET-EVIDENCE.md records the production consumer and passing
qualification for the signed-address counterexamples above, plus all retained
code relocation targets. NATIVE-TARGET-OWNERSHIP-INVESTIGATION.md refines the next
ownership, reference-cell, import and TLS obligations. These do not complete
whole-function or native-executable acceptance.
