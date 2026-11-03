# Native debug information: selected admission check

This selects the finite prepublication check for the existing Full/O2 target.
It is a design decision, not qualification of a UBE metadata emitter or debugger.
Production uses bounded binary reads from the held candidate; no extra production
inspection tool, textual dump parser or independent worker pool is introduced.

## Expected identity and survival

Before invoking Clang, freeze an expectation table from the checked source graph:
canonical source/declaration identity, original file and directory spelling,
emitted linkage name and a deterministic producer marker containing the compiler
identity and canonical source identity. Do not derive expectations from the
candidate, use basenames alone, or introduce temporary paths, timestamps or
random identifiers. These are metadata identities, not file-consistency checks.
Never reopen or monitor source files to validate this table.

Use the selected unstripped object's and final image's checked COFF symbol
inventories to identify retained compiler-owned definitions. For this initial
non-LTO link, require every compiler-owned definition present after object
compilation to retain its final symbol and definition in both Full and None.
An unexplained object-to-image loss is a build failure, not evidence that source
code was optimized away. Elimination before object emission is allowed. The
selected link must pass this retention rule before qualification; do not infer
retention from the final symbol table alone. Every source unit
with retained code or storage requires its matching compilation unit (CU).
Every retained out-of-line source procedure requires a matching concrete subprogram DIE
and executable address range. An entirely eliminated or declaration-only unit
does not need an invented range. The separate process adapter calls the actual
language Main in the program object, without LTO; require that Main definition
and its source CU even for an empty Sub Main. CRT main is not a substitute.
Do not add debug-only retention or optimization flags to make this check pass.

Match the exact producer, original file/directory tuple and owned linkage
identities. Support-library debug records cannot satisfy program expectations.
Reject conflicting duplicate identities or ambiguous symbol/range mappings.
This check detects missing required records; it is not proof against arbitrary
coordinated corruption of machine code, symbols and debug information.

## Binary profile

The existing candidate layout check runs first. All further offsets, products,
lengths and address conversions use checked arithmetic and bounded reads of the
same candidate object. Short reads and malformed records fail before commit.

1. Resolve literal section names and the selected GNU/LLD `/decimal` long-name
   convention. Locate the string table using checked COFF symbol-table offset
   plus 18 times symbol count; validate its four-byte length, offsets at least
   four, and NUL termination within the table. Check symbol auxiliary counts
   and section references. Reject duplicate required debug sections. Section
   payload ends at its initialized virtual extent, excluding raw alignment
   padding. Microsoft specifies long names for COFF objects, not executable
   images; their use here is an explicitly qualified GNU/LLD convention, not a
   general Windows loader guarantee. See the [PE format reference](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format).
2. Frame every `.debug_info` unit with validated DWARF32/64 initial lengths.
   Owned units must use DWARF 4, DWARF32 offsets and eight-byte addresses.
   Other-version support units may be skipped by their validated lengths;
   independently requiring every expected owned identity prevents them from
   substituting for discarded program metadata.
3. Decode DWARF 4 abbreviation tables and forms with checked string, block,
   reference and section offsets. Traverse DIEs with an explicit bounded stack.
   Resolve specification/abstract-origin references through a bounded,
   cycle-checked chain. Unsupported forms in an owned unit are a controlled
   unusable-candidate failure, never guessed widths or unchecked skips.
4. Check each required concrete procedure's linkage/source association and
   nonempty address range against executable initialized section bytes and
   its final symbol address. Interpret `high_pc` by its form class; check range
   lists, base-address selections and terminators when present. Inline-only
   declarations do not masquerade as concrete procedure ranges.
5. Parse each matched CU's referenced line table once: bound its header,
   file/directory indices, strings, LEB values, opcodes, address arithmetic and
   sequence endings. Require source-associated, non-end-sequence rows inside
   retained executable statement ranges. Empty procedures need their concrete
   DIE/range but no fabricated executable source line. Header-only or unrelated
   support line tables cannot satisfy a source procedure's requirement.
6. For retained out-of-line code, match declared parameters and locals to the
   expected source name, declared scalar/native type and lexical scope from
   the checked graph, resolving abstract-origin/specification references as
   needed. Require declaration records even when value locations are unavailable.
   Bound type-reference traversal under the same event/depth budgets. The
   admitted scalar/native type shapes give a finite type comparison. Inline-only
   instances need no invented out-of-line symbol or concrete function range;
   their applicable origin and call-site associations are covered by independent
   acceptance. This check does not evaluate arbitrary location expressions.

The encoding reference is [DWARF 4](https://dwarfstd.org/doc/DWARF4.pdf), in
particular its unit, entry, range and line-program formats. The emitter uses
[LLVM source metadata](https://llvm.org/docs/LangRef.html#dicompileunit).
The selected toolchain's actual emitted forms must pass the independent gate
before qualification; adding a supported encoding does not weaken identity or
range checks. This is a bounded admission profile, not a complete DWARF reader.

## Work, storage and failure

Initial engineering caps per candidate are 64 MiB of examined debug/symbol
bytes (including rereads), 16 MiB simultaneously owned parser payload including
expectations and resize overlap, 16777216 parsing/index/reference events,
65536 framed units, and depth/reference chains of 256. They are policy limits,
not measured peak usage. Existing candidate length and total owned-lowering
storage caps still apply. Check budgets before allocation, reading or advancing;
count every byte scan, including terminator searches, against the byte budget.
Cache abbreviation and line-table offsets and use indexed identities rather
than unbounded rescans. Check cancellation at most every 4096 events or 65536
processed bytes and around host I/O, following the resource contract's limits
on cancellation within indivisible primitives.

Malformed, absent or unsupported required debug records, and candidate inspection
read failures, use UBE1506 with the candidate path. Budget
exhaustion uses UBE1502 with resource token `debug-information`. Cancellation
uses UBE1507. Failure preserves
the prior executable and releases owned parser state through the build owner.
No diagnostic claims that semantic debug correctness has been proved.

None omits program source metadata at emission and records that fact in the
owned IR handoff. Its normal build does not claim to prove absence of program
records inside arbitrary unsupported-version CUs. Support debug may remain.
Independent final-image and Full/None execution comparisons are still required.

## Independent acceptance and limited current evidence

The source-coordinate, parameter/local type and scope, inline call-site,
available value-location and Full/None behavior comparisons in
`tests/native-executable/FAILURE-ORACLES.md` remain separate acceptance gates.
They verify semantics which the ordinary structural admission check cannot.
Optimization may remove code or make a value unavailable; neither checker may
invent a location. No working interactive debugger is claimed.

Add controls retaining support debug while removing all or one required program
CU; alter producer, source, version, long-name offsets, abbreviations, strings,
line offsets, ranges and Main's association independently. Remove the symbol
and DIE of a non-Main procedure while leaving its code to test retention, and
remove parameter/local declaration records while keeping CU/line records.
Test truncated and
overflowing lengths, duplicate sections/identities, reference cycles, invalid
line sequences and each budget boundary. Positive controls include empty Main,
declaration-only and eliminated units, inlining, and Full/None with CRT debug.
Check actual compiler failure and old-output preservation, not just a host parser.

A maintained test-only probe, `tests/native-executable/verifier/check-debug-unit-identity.ps1`,
passed its Full/None CU-identity comparison and nine malformed/altered controls.
Report `bootstrap/out/debug-unit-identity/45630dbae446496a9f6b9ba21c9602ff/report.json`
records the exact argument vector and source, script, fixture and mutation hashes.
Full contained the expected DWARF 4 C fixture CU and two DWARF 5 support units;
None contained two support units and no matching DWARF 4 CU. Mutations retained
the later support-unit bytes. This establishes only the tested long-name,
framing, root-identity and offset checks. It reads whole test fixtures, skips
other versions, and does not validate DIE children, line programs or semantics.
It is not the production implementation or proof of complete None absence.
