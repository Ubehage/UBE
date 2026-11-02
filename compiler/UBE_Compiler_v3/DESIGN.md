# Compiler foundation direction

## Owner decisions — 2026-10-30

The owner approved the following starting point:

1. Develop a fresh UBECore as reusable foundations, growing with concrete
   compiler needs.
2. Keep the compiler's builtin knowledge limited to necessary machine/storage
   primitives and mechanisms for defining types. Implement higher-level types
   and operations in UBE where practical.
3. Prove library-defined native datatype mechanisms early, before substantial
   String, Decimal, Date or Variant implementation.
4. Investigate the smallest existing stage-zero/v2 bootstrap route and test
   every feature required by the first foundation slice independently.
5. Preserve old implementations as history. The active compiler is the new v3;
   old v3 and v4 are under `../archived/`.

This approves the direction, not a particular type-layout language, generic
system, lifetime hook ABI, raw-address API, parser representation or phase API.
Those require written contracts and focused evidence before implementation.

## Boundary to establish first

Define which primitive storage and operations must be compiler-recognized,
which behavior is ordinary UBECore code, and how declarations communicate
representation, initialization, access, copying and destruction without
weakening language safety or portable behavior. The mechanism must serve
ordinary user-defined native types, not only privileged compiler-known names.

The frozen language specification remains authoritative. Existing value-copy,
object-identity, roots/barriers, neutral-failure/Err, concurrency and lifecycle
rules constrain the mechanism. Any additional syntax or observable semantic
change needs an explicit reviewed decision before it becomes production code.

## First proof obligations

- The selected bootstrap tool can compile the exact bounded features needed
  by the foundation fixtures, with independently specified native results and
  controlled rejection/failure cases.
- One small library-defined datatype demonstrates the intended representation
  and lifecycle mechanisms. Test copies, failures and cleanup rather than
  treating successful compilation as proof.
- Byte/text storage defines embedded zeros, byte/scalar positions, ownership,
  mutable versus immutable access, bounds and allocation failure.
- Text construction has measured work, allocations and copied bytes across
  input sizes. Independent instances and immutable shared inputs are tested
  concurrently before a large compiler relies on them.
- Compiler inputs/results have explicit owners. A bounded worker budget and
  deterministic publication must be demonstrated while the design is small.

Windows x86-64 and LLVM remain the initial toolchain direction. Portable
algorithms must not depend on host handles, path syntax or target ABI details.
The compiler and library add no new third-party dependency through this setup.

## Bootstrap and identity

Select tools by source/artifact hash, supported subset, flags, runtime/toolchain
identity and test results. The old version label alone is not a trust proof.
The current-source stage-zero/v2 route is qualified for the bounded subset in
`CONCURRENCY-BOOTSTRAP.md` and earlier adopted foundation contracts.
Historical bootstrap/concurrency records retain their exact assertion counts and
identities. The bounded semantic checker passes its final maintained gates on
accepted cohort 88d; SEMANTIC-EVIDENCE.md records its 894-assertion bootstrap and
native/process/resource/retained proofs. Neither
bootstrap compilation nor a component gate establishes full language, class or
thread support. Unsupported facilities continue to diagnose explicitly.

Archived v3 preview names and existing `bootstrap/out/ube-v3-*` products belong
to the old implementation. The fresh line has a source reader, scanner, envelope recognizer, bounded native
MODULE parser and qualified bounded scalar/native semantic checker, with no
public compiler release identity. `CONCURRENCY-EVIDENCE.md` preserves the earlier bootstrap/concurrency checkpoint
and its retained parser/CLI qualification. `PARSER-NATIVE-EVIDENCE.md`
preserves the earlier parser checkpoint. At that earlier checkpoint, successful syntax reported checking unavailable.
The integrated bounded check path supersedes that status; code generation
remains future work.
Do not overwrite archived previews.

## Measured first grammar consumer

`PARSER-CONTRACT.md` freezes acceptance before implementation.
`PARSER-PROBE-EVIDENCE.md` records the native comparison and selects private
indexed linked-child nodes with explicit operator/operand and control stacks.
Results borrow original source views and publish their complete owned arrays,
root/count metadata and source identity together. The recursive probe cannot
satisfy the shared mixed-depth limit; it is not the production strategy.
The test-only command stream is an oracle bridge, not a required production
intermediate or public ABI. The production consumer is now qualified; its exact
scope and remaining deferred families are recorded in `PARSER-NATIVE-EVIDENCE.md`.

## Qualified concurrency and current semantic work

Compiler-owned source/work references preserve immutable inputs, private complete
results, one bounded worker budget and deterministic publication. UBECore owns
generic thread/storage mechanisms. The project/reference path and initial
parallel frontend were subsequently qualified under their own contracts and
performance evidence; historical instrumented contention results remain history.

The bounded semantic checker now reuses that same controller and ownership
boundary in qualified production. No general
executor, global mutable semantic model or replacement architecture is implied.

The next existing development-plan row is First
checked native executable. Specify its bounded program set, lowering, target ABI,
runtime-error and backend/tool-handoff contracts before code. Preserve original
spans and qualified ownership throughout; current semantic acceptance cannot be
reused as proof of LLVM/native execution or full compiler/Core support.