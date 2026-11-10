# UBE workplan

This is the repository-wide resumable checklist for active goals and handoffs.
Owner-defined release requirements live in `Release-Requirements.md`; long-term
sequencing lives in `project-docs/Roadmap.md`; module-specific work may use a
nearer roadmap or progress file.

## Status markers

- `[ ]` not started
- `[~]` in progress
- `[x]` complete and verified
- `[!]` blocked, with the reason and required decision recorded

## Restart baseline — 2026-11-10

The final UBE-written compiler must be multithreaded, with all compiler code
thread-safe from the start, as reaffirmed by the owner on 2026-11-10. The VB6
bootstrap may remain sequential. The concrete architecture requirement is in
`project-docs/Development-Plan.md`; its pending concurrency gate is in
`compiler/ACCEPTANCE.md`. This requirement is independent of the later IDE.

### Active definition priority: error handling

The owner identified error handling as the failure point of the previous
attempt and requested an exact project-wide definition before implementation.
`project-docs/Error-Handling.md` records the existing baseline, concrete open
decisions and required acceptance cases. The owner approved Err.Raise exiting
the raising procedure with FAIL, caller-side handling, default failed-statement
skipping and explicit resource cleanup before raising. These are normative in
`lang-doc/error-handling.md`. Remaining boundary decisions are tracked in the
review. Normative contracts and affected public articles have been reconciled
for the scoped failure-result claims. The static documentation validator passed
274 HTML files; browser verification and execution of manual examples remain
unverified. That documentation audit alone does not establish compiler conformance;
the scalar source-to-native gate below supplies its own execution evidence.

The authorized execution order is now in `project-docs/Development-Plan.md`,
with a planned scalar admission set in `lang-doc/bootstrap-profile.md` and
source acceptance requirements in `compiler/ACCEPTANCE.md`.

- [x] Start the repository-owned VB6 bootstrap with `.UBE` project loading and
  multiple ordered modules as the minimum, per the owner's requirement.
  Feed retained module buffers into the later parser; do not build a separate
  single-file compiler first. `rtk proxy powershell -NoProfile -File
  bootstrap/tests/project-loading/check.ps1` built with VB6 6.00.9782 outside
  the sandbox and passed all 54 loading/CLI cases. That gate checks loading only;
  the retained module buffers now feed the lexer/parser below.

- [x] Implement the bounded lexer/parser over the retained module buffers.
  `rtk proxy powershell -NoProfile -File bootstrap/tests/source-parsing/check.ps1`
  built with VB6 6.00.9782 and passed all 37 syntax cases, including retained
  tree structure, exact source spans, multi-module calls as syntax, the actual
  error oracle, unsupported/malformed input and parsing limits. The same binary
  passed all 54 project-loading cases. Exact commands/artifacts are recorded in
  `compiler/Progress.md`. This proves parsing, not execution or error behavior.
- [x] Implement name resolution and scalar type checking over those trees,
  including package/module visibility, Main validation, typed arguments/ByRef,
  duplicate declarations and the official Err binding. LLVM emission follows.
  The bounded semantic contract and trusted error-support declarations are
  documented in `bootstrap/SEMANTICS.md`. The semantic gate passed 76 cases;
  the same VB6 executable passed 37 parser and 54 loader cases. Assertions cover
  declaration identities, conversion/ByRef treatment, exact constants and
  diagnostics. Exact commands and evidence are in `compiler/Progress.md`.
- [x] Emit LLVM from the bound scalar project and qualify actual native
  execution, including the approved FAIL protocol and SourceOracle cases.
  `bootstrap/tests/native-compilation/check.ps1` passed 23 assertion groups,
  including actual source execution at O0/O2, x64 output, deterministic IR,
  checked failures and output preservation after backend failures/timeouts.
  The same binary passed 76 semantic, 37 parser and 54 loading cases. The internal
  contract is in `bootstrap/LOWERING.md`; exact evidence is in compiler/Progress.md.

- [x] Native failure-flow feasibility: `rtk proxy powershell -NoProfile -File
  bootstrap/tests/failure-flow/check.ps1` passed on Clang 23.1.3. O0/O2 assert
  x64 PE and exact exit 0 for eight behavior cases. Negative controls return
  exact masks 158 and 4. Hand-authored IR only; no source compiler is implied.
- [x] Compile the matching UBE source oracle through the VB6 bootstrap and
  qualify real parsing/lowering against those observations. All eight checks
  pass independently at O0/O2 with volatile runtime input; input zero rejects
  all eight observations with exact negative-control mask 255.

### Implementation baseline

Owner-approved block assembly syntax (2026-11-10) is specified as Asm / raw
physical payload lines / End Asm, alongside the existing quoted form. Grammar,
lexical/preprocessor boundaries and the public Asm article are synchronized.
Target dialect, bindings and lowering remain separate work; no assembler or
parser implementation is claimed by this definition change.

The owner requested a restart after the previous implementation failed.
Existing working-tree removals are retained; historical implementation and
verification claims do not establish support in this checkout. The language
contracts, IDE design, release requirements and accepted samples remain the
product baseline.

- [x] Prove the VB6-to-LLVM bridge. On 2026-11-10,
  `rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File bootstrap/tests/vb6-llvm/check.ps1`
  passed outside the sandbox: VB6 emission, controlled invalid-path failure,
  x64 PE machine assertion, and native exit code 42. This is a fixed IR fixture,
  not a compiler for UBE source.
- [~] Define compiler vocabulary and inventory every VB6 runtime built-in
  before expanding implementation, as requested by the owner on 2026-11-10.
  See `compiler/LANGUAGE-SURFACE.md` and `std-lib/INVENTORY.md`. Name coverage is
  checked; conflicting semantic choices and exact UBE signatures remain open.
  Owner-approved additions beyond VB6 include CLngLng (LongLong result) and
  CLngPtr (IntPtr result), recorded in `std-lib/INVENTORY.md` on 2026-11-10.
  Broad text inputs use pointer values as numeric text and object identities
  as unique opaque handle text (language-spec.md section 8.1). No pointer
  dereference is implied. Arrays are compile-time-invalid as text input when
  statically known. Enum values use numeric text; other custom datatypes are
  rejected as whole text inputs, with eligible fields usable individually.
  Runtime-dependent Variant payloads are checked by the receiving function,
  which raises on invalid input. The owner proposed Adaptive String-returning
  functions: all seven existing identifier type suffixes explicitly select the
  call result type; unsuffixed calls adapt to the expected type or default to
  Variant containing String. Declaration/context and suffix/operator details
  are tracked in `lang-doc/adaptive-functions.md` before grammar adoption.
  Explicit suffix conversion occurs before ordinary destination conversion;
  optimization must preserve intermediate rounding, checks and failure behavior.
  The address-text fallback is approved only for an
  explicitly supplied pointer/address value; it never uses internal storage
  addresses, dereferences memory or bypasses known invalid types.
- [ ] Define the minimum bootstrap source subset needed to build the
  UBE-written compiler, with explicit rejection of unsupported constructs.
- [x] Extend the scalar bootstrap with Byte, Integer and LongLong storage,
  arguments/results and checked conversions. The concrete dependency evidence
  is in `bootstrap/DEPENDENCIES.md`; this is an incremental extension within the
  approved bootstrap dependency work, not a complete self-hosting subset.
  The integer gate passed 46 groups, including 113 runtime boundary cases
  across 25 conversion pairs at O0/O2. The same executable passed all 23 native,
  76 semantic, 37 parser and 54 loading regressions. See compiler/Progress.md.
- [ ] Implement and test that subset, then establish reproducible self-hosting.
- [x] Implement the bounded source-buffer and finite-record dependency:
  fixed rank-one arrays, scalar/nested records, checked indexing/fields, ByRef
  and independent copies within the explicit AGGREGATES.md boundary. The
  aggregate-storage gate passed 38 groups, including actual source-byte and
  token/tree-record execution at O0/O2. The same executable passed all 46 integer,
  23 native, 76 semantic, 37 parser and 54 loading regressions. Exact evidence
  and remaining dynamic-storage/text/I/O work are in compiler/Progress.md.
- [ ] Expand compiler and UBE libraries toward the frozen language contract,
  with source-level debugging and thread-safe compilation.
- [ ] Deliver the native IDE, accepted samples and complete offline manual
  against demonstrated compiler support.

Compiler acceptance criteria and the immediate handoff are in
`compiler/Roadmap.md` and `compiler/Progress.md`.
