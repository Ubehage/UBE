# Native target ownership investigation

This diagnostic guides the existing target-ownership and operand-validation work.
It does not qualify a production owner, complete native dataflow or indirect-call
safety. The native-executable goal remains active and incomplete.

## Procedure and inputs - 2026-11-04

bootstrap/out/native-target-ownership-diagnostic.mjs was evaluated as a module
through the Node REPL. It consumes the retained field-analysis.json diagnostic,
the passing extent-binding matrix 1ee39e22ed974005bec0d08bcd718b3f, all associated
frozen expected-definition files and linked images. Original objects, frozen
expectations and images are SHA-256 checked against retained identities. The
script and all 275 distinct inputs are recorded in
bootstrap/out/native-target-ownership-diagnostic.json and rechecked on completion.

Independent COFF/PE parsing provides symbol locations, reference-cell contents,
import directory/IAT associations and the TLS directory's index address.
Access width and instruction flow come from the earlier decoder observations;
that dependency is explicit and does not establish independent operand semantics.
No image is executed by this diagnostic.

## Observations

All 5,712 code relocation references across 112 nonempty objects and 16 images
were classified, with no mismatches:

| Target class | References | Diagnostic check |
| --- | ---: | --- |
| Generated functions | 1512 | Frozen function identity, zero effective addend, direct call/tail form |
| Generated data | 728 | Effective addend and observed access width fit frozen storage extent |
| Generated TLS data | 888 | Member addend and observed width fit frozen storage extent |
| Reference-pointer cells | 1880 | Eight-byte read at cell start; contents equal the frozen generated data referent's VA |
| TLS index | 592 | Four-byte read; symbol VA equals PE TLS directory AddressOfIndex |
| Import address cells | 80 | Eight-byte read at an IAT slot matching its import-directory name |
| Anonymous constants | 16 | Address formation at offsets 0 or 19 within the known 31-byte contribution |
| Explicit CRT function | 16 | Direct zero-addend call to __main; runtime implementation proof remains separate |

The observed imports are KERNEL32.dll ExitProcess, Sleep, TerminateProcess and
VirtualQuery. This association is diagnostic PE evidence, not an API-effect proof.
The __main reference belongs to the explicitly selected CRT support boundary in
NATIVE-EXECUTABLE-CONTRACT.md; it must not be treated as an arbitrary generated
function merely because its name resolves in the candidate.

## Next production obligations

The production generated-owner consumer now passes the entry/extent gates in
NATIVE-TARGET-OWNERSHIP-EVIDENCE.md, using pre-tool frozen definitions and qualified
retained ranges. An anchor remains distinct from a complete accessible extent.
Reference cells now pass the production name, range, content and access gates in
NATIVE-REFERENCE-POINTER-EVIDENCE.md. Global data aliases and image residency still
require complete qualification. Next bind IAT/TLS-index locations to actual PE
structures using NATIVE-IMAGE-DIRECTORIES-INVESTIGATION.md before using those
meanings in instruction analysis. Preserve base-relocation and CRT callback proofs.
Prove register/index propagation and bounds before indirect calls or accesses;
a valid pointer-cell value alone does not prove a later register contains it.
SECREL member bounds do not prove the runtime base is the selected TLS template.

NATIVE-INSTRUCTION-TARGET-EVIDENCE.md qualifies signed linked-address correspondence
under explicit caller preconditions. Complete function traversal, terminal
edges, CRT/startup/API closures, unwind and stack/reserve derivation, debug,
build/tool/diagnostic/publication integration and complete-source acceptance
remain governed by the existing native plan. No cap or architecture changes are
introduced by this diagnostic.
