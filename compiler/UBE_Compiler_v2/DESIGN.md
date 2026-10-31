# UBE Compiler v2 design

## Purpose and release boundary

V2 is the structured transitional UBE compiler generation. It replaces v1's
direct source-pattern extraction with explicit source, token, syntax, semantic,
IR, and LLVM-emission phases. Its release contract is deliberately narrow: it
must remain self-hosting, compile ordered multi-module projects with supported
cross-module references, and provide the stable Bootstrap Profile used to
develop and compile v3.

V3 is UBE's first public-release target. Classes, project structures, complete
language coverage, production optimization, and debugging facilities belong
there. The owner explicitly authorized extending v2 as necessary for bootstrap,
including managed array/record support required by fresh UBECore storage.
This does not make v2 the public product or replace the existing architecture.

## Bootstrap constraints

V2 uses flat dynamic arrays and checked `Long` indices rather than pointers,
recursive object graphs, or implicit ownership. Index `-1` means “no item” only
where a field documents that sentinel. Every index is validated before access.
Arrays have explicit count and capacity fields; capacity growth is bounded and
checked before `ReDim Preserve`.

V2 may remain implemented in `Main.bas`; support for compiling multi-module
input does not require refactoring the compiler itself before the freeze gate.
Phase boundaries are procedures and records. Any later source split must retain
the same bootstrap comparison result and is a routine v2 preservation change,
not a new compiler generation.

## Phase contracts

1. **Driver/project input** validates arguments and manifest/source paths. It
   owns loaded text and never reports a partially written output as success.
2. **Source manager** assigns a stable positive file ID and stores UTF-8 bytes
   plus line-start offsets. Byte ranges use a half-open `[start, end)` form.
3. **Diagnostics** append bounded records containing identifier, severity,
   file ID, byte range, message, and optional note. A phase may recover only at
   a documented boundary; reaching the diagnostic limit stops that phase.
4. **Lexer** converts one source into an ordered token array ending in exactly
   one EOF token. It retains original spelling and byte ranges.
5. **Parser** consumes tokens monotonically and builds flat syntax-node arrays.
   Child lists use first-item/count pairs into dedicated index arrays.
6. **Semantic analysis** builds case-folded symbol tables, resolves checked
   node IDs, assigns types, and rejects invalid programs before IR creation.
7. **IR lowering** produces typed, target-independent instructions grouped in
   verified basic blocks. Evaluation order and checked failure edges are
   explicit.
8. **LLVM emission** accepts verified IR only and appends bounded text chunks.
   The driver writes the joined result only after successful emission.

Each phase returns a success `Boolean` or a neutral result plus diagnostics.
User input must not cause an unchecked array access, arithmetic overflow,
unbounded loop, runtime panic, or partial-success artifact.

## Initial records

- `SourceFile`: path, text, and line-start range.
- `Diagnostic`: stable ID, severity, file/range, message, and note.
- `Token`: kind, file/range, and source spelling.
- `SyntaxNode`: kind, file/range, scalar operands, and child-list range.
- `Symbol`: kind, folded name, declaration node, type ID, and scope ID.
- `TypeInfo`: kind and referenced element/record type ID.
- `IrInstruction`: opcode, result type, operands, source node, and text ID.
- `TextBuffer`: a dynamic `String()` chunk array plus count and total bytes.

The exact fields are frozen one record at a time with tests. Adding a field
requires updating initialization, bounds tests, and snapshots.

## Resource limits

Limits are centralized and checked before allocation: source bytes, source
count, tokens, nodes, nesting, symbols, IR instructions, text bytes, and
diagnostics. Defaults must compile v2 itself. Limit diagnostics identify the
exceeded resource and do not expose raw addresses.

## Bootstrap comparison

Stage zero builds v2 into stage one. Stage one compiles the identical manifest
and source set into stage two. Deterministic textual LLVM IR is compared
byte-for-byte unless a separately reviewed canonicalization document identifies
unavoidable tool metadata. The same positive and negative corpus is run through
both binaries and its output, diagnostics, artifacts, and exit codes compared.

## Evolution boundary

For the owner-authorized current foundation repairs, see `FOUNDATION-PLAN.md`.
The existing internal type identifiers are retained; Byte uses previously unused
identifier 7. LLVM storage is i8 unsigned for Byte and i16 signed for Integer.
Ordinary UBE procedures perform semantic validation, constant evaluation and
conversion lowering; no type behavior is imported from archived compiler code.

Compiler-generated narrowing uses this private program-support ABI:
`i64 @ube_checked_narrow_i64(i64 value, i32 bits, i32 is_unsigned)`.
Supported destinations are (8,1), (16,0) and (32,0). Success returns the exact
value and leaves Err unchanged. Out-of-range input returns zero with Err 6;
invalid representation arguments return zero with Err 5. The compiler truncates
only the checked result. This ABI is not a public UBE intrinsic declaration.
Existing checked i32 arithmetic now returns neutral zero with Err 6 for overflow
or Err 11 for zero division; it does not terminate the process. Independent C
regressions check these failure paths and preservation of stale Err on success.
There is no claim of a complete per-call failure-status or structured-error ABI.

ExpressionDepthLimit centralizes the bootstrap expression-depth bound (128).
Token preflight bounds parentheses and unary runs before parsing. An iterative
colored graph walk checks syntax-node depth/cycles before recursive semantic
analysis and constant evaluation. Oversized expressions diagnose UBE3222 and
publish no LLVM, instead of consuming the native stack. The recursive
value-layout prerequisite check also uses an explicit work stack.

V2 becomes the preserved bootstrap compiler only after the multi-module and
stage-one/stage-two gates pass. V1 and stage zero remain preserved and tested.
V3 is the next intentional generation and the first public-release target; it
must be developed and compiled using v2.

## Opaque scalar native values

The owner delegated the next foundation mechanism's design decisions on
2026-10-30. `Type Name As StorageType` records a representation separately from
ordinary record fields. Byte, Integer and Long lower to one-component native
aggregates with neutral zero and value copying; their hidden payload is not a
source field. Intrinsic declarations record a validated Pack/Unpack role and
native type identity. The binding's exact signature and declaring source module
are checked before lowering. Pack/Unpack emit LLVM insertvalue/extractvalue;
equality compares the extracted scalar. Procedure spelling is not native
dispatch authority. Existing bootstrap intrinsics retain their registered ABI
only when the entire declared signature matches that registration.

Source provenance supplies the binding ownership check; it does not implement
general namespaces or module privacy. Unsupported representation families,
implicit scalar coercions, ordering, arithmetic and Print/condition conversion
diagnose. Managed opaque representations and foreign ABI remain unqualified. Exact contract
and proof: `../../std-lib/NATIVE-TYPE-PROPOSAL.md` and
`../../std-lib/tests/native-type/NATIVE-EVIDENCE.md`.

## Managed ordinary arrays and records

The approved managed-storage work derives precise reference offsets from the
existing type graph. Array slots are traced references; finite records derive
their offsets from their fields. Inline record cycles diagnose. Compiler-owned
roots cover local, parameter, result, temporary and borrowed-owner locations
before safe points and leave on every procedure exit. A borrowed array element
keeps the old owning array rooted even if its holder is replaced during a call.

Assignment, ByVal preparation and result boundaries synthesize independent
copies from runtime value descriptors. New values are prepared while the old
destination/source remain rooted, then published only after a complete copy.
Managed results use a compiler-private hidden output holder; this is not a
foreign ABI. Scalar/reference accesses and managed bulk stores preserve the
specified nontearing/reference-safety properties. User code still synchronizes
shared mutable values.

One-dimensional indexing/counts use signed Long in this bootstrap subset.
Invalid access returns rooted neutral fallback storage and Err 9. Allocation
collects/retries once, then reports ordinary failure with Err 7 while preserving
the destination. Success preserves stale Err. A failed operation does not
implicitly abort subsequent user statements or wrap them in a transaction.

The existing intrinsic-attribute syntax binds Array.Length, Array.TryResize,
Memory.Collect, Array.TryCopy and Memory.CopyBytes by exact declaration role,
type and passing-mode checks. Names remain arbitrary; no raw user address or
foreign-symbol escape is added. Byte growth and validation algorithms remain
ordinary UBECore code. Exact signatures, recorded 276-assertion gate and limits:
`../../std-lib/MANAGED-STORAGE-EVIDENCE.md`. Builtin String, objects and managed
opaque native representations are not qualified by this Byte/record proof.

## Source input and executable admission

The first fresh-v3 consumer uses bounded independent direct source libraries,
with package/module identities retained during validation. Unsupported lookup,
visibility and nested-reference cases diagnose rather than becoming accidental
flat global access. `tests/source-reference/CONTRACT.md` defines the subset.

File.TryOpen, File.TryRead, File.TryClose, Process.TryArgument and Error.Set use
the same explicit signature-checked intrinsic mechanism as storage bindings.
`../../std-lib/FILE-BYTES-CONTRACT.md` isolates the OS/token lifetime boundary;
ordinary compiler source policy remains UBE.

Native entry owns a false admission slot, passed as a hidden pointer to the
source Main only. After root/ByVal preparation, Main marks it true when nonnull.
Ordinary UBE calls to Main pass null and preserve neutral procedure failure
semantics. The native wrapper observes its fresh slot and returns a controlled
error if admission failed, independently of stale Err. Partial roots unwind
through the existing common exit. Exact native/capacity/cleanup results and the
470-check gate are in `../UBE_Compiler_v3/SOURCE-INPUT-EVIDENCE.md`.
