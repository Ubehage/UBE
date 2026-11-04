# Bounded AMD64 instruction inspection

This is a prerequisite of the existing native code/stack validation work, not a
new backend or architecture. Production consumes immutable bytes through the
shared NativeInspection budget; external disassembly remains test-only.

The first observed leaf inventory is retained in
bootstrap/out/native-leaf-inventory/1e982df3f2374736a3f61ae6033648cc/report.json.
It identifies seven distinct name/optimization pairs without runtime-function
records. The optimized general Err setter has forward/backward branches and three
returns; the clear routine loops. Stopping at the first RET is insufficient.

NativeInstruction describes one selected AMD64 encoding: byte length, control
flow, written general-register mask, memory width/base/index/scale/segment/write,
displacement and immediate field locations/widths, indirect transfer target
register, signed branch displacement and
signed memory displacement. Register IDs 0..15 follow AMD64 encoding. Memory bases
-1/-2/-3 mean no memory operand, RIP and SIB absolute displacement respectively;
index -1 means none. TargetRegister is 0..15 for register-direct indirect
calls/jumps and -1 for all other instructions, including memory-indirect
transfers. It occupies the former four-byte alignment gap: the record remains
72 bytes and both signed 64-bit fields keep their offsets. Field offsets are relative to the instruction start. Normal
RET has flow=1 and excludes its terminal RSP pop from the written-register mask.
Flows 0/2/3/4/5/6/7 mean fallthrough/conditional branch/direct jump/direct call/
indirect call/indirect jump/trap. Calls and stack instructions record RSP writes.

The selected profile covers scalar integer move/extend/LEA, arithmetic/test,
conditional move/set, shifts, multiply/divide, direct/indirect control transfer,
stack operations and the observed multi-byte alignment NOPs. The canonical
unprefixed CC encoding (INT3) is a one-byte trap (flow=7), with no explicit
GPR or memory operand writes. Prefixes on CC remain outside this profile.
Recognition does not authorize reaching a trap; the leaf consumer rejects it,
and the full control-flow consumer must prove termination-call closure separately. Operand-size 66 and
canonical REX, GS TLS and CS NOP prefixes are handled explicitly; repeated 66
prefixes on compiler alignment NOPs remain bounded by the 15-byte instruction
limit. Unsupported prefixes, opcodes or group forms are rejected rather than
assigned a guessed length. This is not a full AMD64 decoder or proof that any
instruction stream is safe or belongs to a specific function.

TryReadNativeInstruction accepts a first byte and available byte count within
one caller-owned snapshot. A private cursor reads each accepted byte exactly once
through TryReadNativeBits, with field reads checked against both supplied bounds
and the architectural 15-byte limit before admission. It owns fixed scalar
workspace only, performs no payload allocation/copying, and publishes its result
only on success. Invalid API bounds use 1509; malformed/unsupported encodings use
1506, resource exhaustion uses 1502/token7, cancellation uses 1507. Err and input
bytes remain unchanged. Numeric caps and declaration/body/argument work bounds
are unchanged. The forthcoming control-flow consumer must independently establish
instruction boundaries, branch targets, complete leaf extents and allowed stack
behavior; this scalar reader alone establishes none of those whole-function claims.

Encoding reference: [LLVM X86 instruction formats](https://raw.githubusercontent.com/llvm/llvm-project/main/llvm/lib/Target/X86/X86InstrFormats.td).
The indexed AMD volume-3 PDF endpoint was unavailable during this investigation;
selected encodings must therefore also be checked against the pinned toolchain.
Windows leaf/nonvolatile rules: [Microsoft x64 ABI](https://learn.microsoft.com/en-us/cpp/build/x64-software-conventions).
Independent assembler/disassembler comparisons and malformed synthetic cases are
required before claiming this implemented profile is qualified.

## Relocation fields and effective offsets

TryReadNativeInstructionRelocationOffset consumes a qualified NativeInstruction,
its section-relative start, and a qualified NativeObjectRelocation from that
same immutable COFF section. The caller must establish those identities, decode
all instruction boundaries, and visit every non-ignored relocation exactly once.
This scalar operation adds no indexes, allocations, payload copies or retained
owners. It uses fixed scalar workspace and charges one zero-byte inspection
event per well-shaped attempt; budgets and cancellation use the existing path.
Inputs and Err are unchanged. The signed result publishes only on success.

REL32 through REL32_5 must exactly cover a four-byte direct branch immediate
(flow 2/3/4) or RIP-relative displacement with no index or segment override.
SECREL must exactly cover a four-byte displacement with a register base,
no index or segment override, and ordinary fallthrough flow. Other field/kind
combinations reject. REL32 result = signed original field + complete instruction
end - relocation field start - relocation RelativeEnd. SECREL result is the
signed original displacement. This follows the selected AMD64 relocation rules
in [Microsoft PE/COFF](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format).
The REL32_1 through REL32_5 variants have RelativeEnd 5 through 9.
All arithmetic is widened; signed 32-bit field endpoints and unsigned 32-bit
section coordinates cannot overflow the signed 64-bit result.

Invalid descriptor shapes or section coordinates use 1509; unsupported kinds,
misplaced fields and incompatible operand forms use 1506. Resource and cancellation
failures retain 1502/token7 and 1507. The helper checks field widths, ordering,
nonoverlap, signed displacement range and complete instruction length before
using them. Qualified descriptors remain a precondition; scalar shape checks
cannot prove that a forged descriptor describes any actual instruction.

The result is a target-relative addend, not a resolved address or permission to
access/call it. Linked-field no-wrap/range checks, target extent and ownership,
TLS base provenance, pointer/import meaning, access width, direct target entry
and whole-function flow remain obligations of their consumers. In particular,
SECREL does not turn a TLS member offset into an image VA. Returning an offset
for a RIP-relative field does not establish the instruction's operand semantics.

Qualification requires independently specified direct/RIP/TLS examples,
trailing immediates, all six relative kinds, signed endpoints, malformed fields,
unchanged outputs on failure, exact budgets/cancellation/Err/root refusal,
and every retained code relocation against independent COFF and LLVM boundaries.

## Signed linked instruction targets

TryReadNativeInstructionRelocationTarget composes the qualified original
instruction/relocation pairing with a resolved image NativeDefinitionRange,
the qualified instruction's image RVA and first file byte, and immutable image
bytes. Callers establish object/image instruction and contribution identity,
unchanged nonrelocated bytes, target identity, and complete relocation coverage.
The operation does not derive any of those associations from a returned value.

It first obtains the original effective addend through the existing offset
helper. For REL32 variants, target RVA plus addend must fit the unsigned 32-bit
RVA domain, its VA must remain representable in the selected signed address
domain, and its distance from the complete image instruction end must fit signed
32 bits. For SECREL, target section offset plus addend must be nonnegative and
fit signed 32 bits, matching a section-base-relative AMD64 memory displacement.
The actual four linked bytes must equal that signed displacement. No arithmetic
is reduced modulo 32 bits for this address proof. Negative original addends and
negative relative distances remain valid when the resulting target is valid.

The atomic signed 64-bit result is the effective RVA for REL32, or effective
section offset for SECREL. It is not a target extent or a memory-access license.
Image/domain ownership, full access width, function entry, TLS base, pointer cell,
imports and complete function/stack semantics remain required. In particular,
a representable RVA does not itself prove membership in a mapped image section.

ValidNativeRelocationTarget centralizes the existing scalar target-range checks
shared with field encoding comparison. NativeSignedInstructionField is shared
between the decoder and linked-target consumer; its behavior is unchanged.
No payload allocation/copy or retained owner is introduced. Inputs and Err remain
unchanged; private scalar workspace is reentrant. Success charges two inspection
events and four byte reads: one original pairing event and one linked field read.
Failure may stop earlier. Caller shape/span errors use 1509; unsupported pairing,
derived address overflow and linked mismatch use 1506. Existing budget/cancellation
codes and unchanged-output behavior apply. All production caps stay unchanged.

The six diagnosed signed-boundary cases are mandatory regression vectors.
Qualification also covers all relative kinds, trailing immediates, nonzero and
negative addends, RVA/VA endpoints, every linked-field byte, target/site mutations,
exact budgets, both cancellation points, allocation independence, Err, immutable
inputs, root refusal and independent target comparisons on the retained matrix.
