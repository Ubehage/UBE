# Native TLS storage association

This implements the TLS index/template dependency in the active native target
plan. It reuses NativeObjects directory/span/range readers, contribution
isolation and generated-definition binding. It adds no language ABI, compiler
phase, owner arena, dependency or new resource limit.

The PE32+ directory layout and alignment field follow the
[Microsoft PE specification](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format#the-tls-section).
Its template and index fields are absolute image addresses, and its callbacks
form a null-terminated pointer array. These structural meanings do not establish
callback effects or the later runtime register chain.

TryReadNativeThreadStorage takes a qualified immutable image/layout and returns
one scalar NativeThreadStorage containing the directory, initialized template,
loader-index cell and complete callback-array ranges, alignment and prepared
status. It requires a 40-byte TLS directory, nonempty fully initialized template,
zero extra fill and reserved alignment bits clear with an encoded alignment of
8 through 8192 bytes. The template begins at its section origin, making the
observed SECREL member offsets relative to that same template origin.

The directory is resident read-only data. Template and four-byte index storage
are resident initialized writable data; the index starts at zero. All ranges
have unique initialized mappings and pass existing contribution isolation.
The eight-byte aligned callback array terminates within its initialized section;
nonzero entries point to resident readable nonwritable code. All four data ranges
are mutually disjoint. Callback symbol identities, instruction bodies and
startup effects remain required later proof, as do applicable DIR64 fields.

TryBindNativeThreadIndex consumes this prepared state and the associated qualified
instruction, named one-byte target anchor and signed effective position. It
requires an exact four-byte RIP-relative read of the loader-index cell, no write,
index register or segment override, and ordinary fallthrough. The complete index
range is published only on success. Subsequent scaling, TLS array lookup and
runtime base-register provenance remain separate required dataflow checks.

TryValidateNativeThreadMember consumes the same prepared state, associated image
and producer-bound frozen TLS definition. Families 12 and 22 retain their frozen
sizes and permissions. The full member range must match the template section,
file/virtual address geometry and initialized extent. Each member's bytes must
be zero initially, matching the stack-floor and shared Err support declarations.
The existing generated-target validator separately checks the SECREL access
width/position; neither consumer alone proves runtime base-register provenance.

Inputs are borrowed immutable owners from one association; no function retains
an owner or allocates/copies a payload. Scalar result records publish only on
complete success. All byte reads and scans use the existing inspection and
cancellation budget. Callback traversal is bounded by admitted initialized
storage; member reads are bounded by frozen storage size. Functions are reentrant
and preserve successful-call Err state. No source-change monitoring is added.
Caller-shape failures use 1509; candidate mapping/permission/initialization or
association failures use 1506; resources retain 1502/token7 and cancellation1507.

Qualification requires literal images with independent complete range oracles,
malformed directories, boundaries, alignment, permissions, callback termination,
overlap, index and member mutations; exact measured budgets/cancellation,
allocation independence, actual root refusal, atomic outputs and corrupted or
forced results. The retained matrix must compare all 592 TLS-index references
and 888 TLS-member references through both readers, retaining all earlier
instruction, import, reference and generated-target controls. Broader loader,
CRT callback, global alias, register/control-flow, stack/debug and builder/final
acceptance obligations remain part of the original goal.
