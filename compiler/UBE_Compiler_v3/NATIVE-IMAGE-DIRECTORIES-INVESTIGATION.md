# Native import, TLS and base-relocation investigation

Subsequent import and TLS storage association are qualified in
NATIVE-IMPORT-EVIDENCE.md and NATIVE-THREAD-STORAGE-EVIDENCE.md, reusing the shared
image-directory/span reader. NATIVE-IMAGE-POINTER-INVESTIGATION.md classifies the
49 absolute fields. Rebasing, register provenance and runtime-closure obligations
remain open. This report preserves the earlier diagnostic and its then-next work.

This is diagnostic input to the existing native target, image and startup work.
It does not qualify a production directory consumer, loader behavior, callback
implementation, indirect-call provenance or complete native acceptance.

## Procedure and evidence - 2026-11-04

bootstrap/out/native-image-directories-diagnostic.mjs was evaluated as a module
through the Node REPL. It independently parses the 16 retained PE images and
their frozen expected-definition files from extent-binding report
1ee39e22ed974005bec0d08bcd718b3f. It verifies every retained input identity and
rechecks all 162 distinct input paths on completion. The passing result is
bootstrap/out/native-image-directories-diagnostic.json. No candidate image runs.

The initial diagnostic incorrectly required every ordinary symbol name to be
globally unique, which rejected repeated section symbols. The corrected parser
marks duplicates ambiguous and requires uniqueness only for the queried semantic
identities. This was a diagnostic correction; no production behavior changed.

Directory interpretation follows Microsoft's
[PE format specification](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format).
Import descriptors, lookup/IAT termination and name fields establish the unbound
import association; TLS directory addresses identify the template, loader index
destination and callback array. Absolute image pointers need the corresponding
base-relocation treatment. These structural associations do not establish API
effects, loader execution or subsequent register values.

## Observations

All 16 images have the same following counts and relationships:

- Nine imported DLL names and 47 named import slots, with matching unbound lookup
  and IAT values and null terminators. Bound-import and delay-import directories
  are absent. Required ExitProcess, Sleep, TerminateProcess and VirtualQuery slots
  each uniquely match KERNEL32.dll and their __imp_ symbols. Their image section
  flags are 0x40000040; do not assume the IAT must have a writable section flag.
- The TLS directory is 40 bytes. Its 800-byte initialized template starts at its
  section's RVA and has zero extra fill. ube.stack.floor occupies offset 8 for
  eight bytes; ube_thread_error occupies offset 16 for 784 bytes. The observed
  SECREL offsets therefore refer to this template origin.
- The TLS index destination equals _tls_index and fits a readable writable
  ordinary data section. The callback array contains executable __dyn_tls_init
  and __dyn_tls_dtor addresses followed by a null pointer. Callback behavior is
  not inspected by this proof.
- Two base-relocation blocks contain 49 unique DIR64 fields. All seven generated
  reference-cell addresses, all four TLS directory VAs and both callback-array
  entries have DIR64 entries. All generated cell values equal their frozen
  retained referent VAs. Padding entries are distinguished from actual fields.
  The report retains all 49 RVAs; these selected associations cover 13 fields,
  leaving the other generated/runtime pointer fields to classify and validate.

The complete imports include CRT/API-set dependencies beyond the four APIs called
by generated platform support. Their selection remains part of the explicit CRT
and toolchain boundary, not an inferred permission to call arbitrary imports.

## Next production obligations

Reuse the existing bounded byte/section readers and inspection budget to locate
directory ranges and named IAT slots. Require unique initialized mappings,
complete descriptor/thunk termination, ordinary unbound named imports and exact
frozen DLL/function identities before treating an operand as an API pointer.
Bind the TLS index and generated TLS extents to the actual template, then prove
the runtime base/index register chain before accepting a SECREL member access.

At this investigation checkpoint, NativeUnwind.bas owned TryLocateNativeImageSpan,
which rejects ambiguous or incompletely initialized section mappings, and
TryReadNativeImageFunctionTable owned the PE directory-header checks. The subsequent
import implementation shares those mechanisms in NativeObjects and retains the
function-table and extent gates; later consumers reuse that shared machinery.

Preserve image rebasing obligations: cell equality at the preferred image base
alone does not prove that relocation processing preserves the pointer. Validate
the applicable DIR64 fields and retain CRT TLS-callback/startup closure. None of
these structural checks substitutes for whole-function operand propagation,
call signatures, API results, stack/reserve derivation, debug validation, builder
ownership or final acceptance. The original native-executable goal stays active.
