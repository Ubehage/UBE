# Native relocation field comparison

TryValidateNativeRelocationValue checks one COFF relocation field against its
already resolved image target and image site RVA. The immutable object/image
snapshots and explicit file offsets are supplied by the caller, which must tie
them to the relocation and a qualified code/data placement. The target is a
qualified image NativeDefinitionRange from named resolution or anonymous constant
binding. This scalar consumer does not infer site placement, resolve names again,
or claim complete byte coverage of a contribution.

The field description must have its reader-defined width and relative-end value.
ABSOLUTE has no field and succeeds after one zero-byte admission. Other supported
forms add a target-dependent adjustment to the original little-endian field:
ADDR64/ADDR32 use the target VA; ADDR32NB uses its RVA; REL32 and REL32_1..5 use
target RVA minus site RVA minus 4..9; SECTION uses the one-based image section
number; SECREL uses the target's section offset. All field arithmetic is modulo
the field width. The selected LLD implementation uses this encoding arithmetic:
[COFF Chunks.cpp, toolchain source commit](https://raw.githubusercontent.com/llvm/llvm-project/0d261d1ca552c95a8f007e061c787ac7132fbcbc/lld/COFF/Chunks.cpp).

This is an encoding comparison, not proof that a truncated address or relative
displacement is safe for an instruction. The complete consumer must constrain
relocation use, instruction operands, target extents and effective addresses.
Absolute target symbols and unsupported relocation kinds are not admitted.
Target section indices use the existing at-most-96-section profile; target
offset/RVA and site fields fit the unsigned 32-bit image domain and positive
target extents, while the VA and its extent fit the signed address domain used
by the existing image reader. Zero-filled data targets are permitted.

Bytewise addition with carry compares the low 2/4/8 bytes without overflowing
signed scalar arithmetic, including negative relative adjustments and high-bit
original addends. Inputs are immutable and borrowed. There is no payload
allocation/copy, retained ownership, mutable shared state or Err modification.
Success examines exactly 2W bytes in 2W+1 inspection events for width W; a mismatch
can stop earlier. Cancellation is checked before each admission. No numeric cap
or declaration/body/argument bound changes. Invalid caller spans/descriptor shape
or target state use 1509; unsupported kinds and differing linked bytes use 1506;
budgets use 1502/resource 7 and cancellation uses 1507. No output is published
other than the final Boolean and failure record.

Qualification requires hand-specified values for every supported kind, carries,
wraps, high bits and negative adjustments; mutation of each byte in each field;
exact/one-below budgets, every cancellation admission, allocation independence,
invalid state and root refusal. Retained generated-artifact comparisons must
compose the production named/constant target binders with an independent site
oracle, and reject altered linked bytes, object addends and site RVAs.

The following remain required: production site/contribution placement tied to
frozen retention records, distinct-contribution ownership/alias checks, overlap
and complete relocation/unchanged-byte coverage, instruction/stack/debug meaning,
pointer-cell/import/TLS checks, tool/build ownership and publication acceptance.
