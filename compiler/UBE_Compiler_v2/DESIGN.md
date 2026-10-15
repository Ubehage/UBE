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
there unless a feature is strictly required to compile v3. Once the v2
transition gate is verified, v2 is preserved rather than grown toward the
public product independently.

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

V2 becomes the preserved bootstrap compiler only after the multi-module and
stage-one/stage-two gates pass. V1 and stage zero remain preserved and tested.
V3 is the next intentional generation and the first public-release target; it
must be developed and compiled using v2.
