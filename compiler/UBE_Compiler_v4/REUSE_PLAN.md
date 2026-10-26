# V3 to v4 reuse plan

## Reuse rule

Reuse contracts, evidence, and behavior aggressively. Reuse implementation
only after a focused audit proves the code is already in the correct ownership
layer and fits a smaller v4 interface. “It already works in v3” is evidence for
behavior, not permission to copy its architecture.

## Asset classification

| Asset | Decision | How v4 uses it |
|---|---|---|
| Frozen language definition and EBNF | Reuse unchanged | Normative input; v4 tests every implemented production against it. |
| V3 release executable and fixed-point source | Reuse as oracle/bootstrap | Build v4 stage one and answer differential questions; do not link against v3 internals. |
| V1/v2/v3 bootstrap chain and hashes | Reuse as trust root | Preserve existing gates and append v4 identities rather than replacing history. |
| V3 positive, negative, malformed, ABI, package, debugger, target, managed, thread, event, and lifecycle corpus | Reuse as tests | Run through v3 and v4 with explicit comparison rules; promote every discovered mismatch to a named regression. |
| Stable diagnostics and exit behavior | Reuse as public contract | Build a machine-readable ledger from tests/docs; compare code, span, severity, notes, exit status, and artifact presence. |
| `.UBE`, `.UBG`, `.UBR`, `.UBL` and versioning contracts | Reuse as formats | Reimplement bounded readers/writers against frozen format fixtures and corruption tests. |
| Target triples, ABI classification, mangling, linked-runtime and debug contracts | Reuse as specification | Port decision tables behind target interfaces; compare generated declarations, layout, objects, and native probes. |
| Typed IR semantics and verifier invariants | Reuse as design evidence | Define a smaller function-local v4 IR; port invariants and fixtures, not v3 global arrays. |
| Unicode 18 tables and generation provenance | Reuse generated data | Consume through a library API with hash/provenance checks; do not duplicate folding loops in phases. |
| V3 performance profiles and deterministic work counters | Reuse as regression evidence | Retain representative inputs and establish v4 budgets before feature expansion. |
| V3 source manager, diagnostics, lexer, parser, semantics, IR, and LLVM modules | Reimplement selectively | Extract observable cases and algorithms one at a time behind v4 contracts; no wholesale module copies. |
| V3 `ParallelFrontend`, `ParallelSemantics`, result transport, and executor wiring | Retire | Preserve only failure scenarios and deterministic-merge requirements. Never recreate whole-project worker copies. |
| V3 whole-program syntax/binding/expression arrays and translated global offsets | Retire | Use per-source and per-procedure owned arenas with composite stable IDs. |
| Repeated string building, insertion sorts, linear lookup caches, and string-based rule dispatch | Retire | Replace with library builders/collections, stable indexed ordering, and numeric identities with work-count gates. |
| V3 bootstrap intrinsics | Audit and shrink | Each use must be irreducible, versioned, tested, and have a library fallback/removal plan where practical. |

## Library extraction candidates

No candidate is complete merely because a similarly named intrinsic or v3
routine exists. Each extraction task must define behavior, failure, ownership,
thread safety, portability, limits, tests, and documentation before compiler
use.

| Capability | Intended owner | Required before v4 use |
|---|---|---|
| Bounded text/chunk builder and integer formatting | UBECore Strings/Conversions | Linear-growth tests, output limit, allocation failure, Unicode/byte contract. |
| UTF-8 decode/iterate and Unicode simple folding | UBECore text/Unicode module | Pinned Unicode identity, malformed-input behavior, no hidden locale dependence. |
| Hash map/set and stable sort | UBECore collections | Collision, growth, deterministic result-order, low-memory, and concurrency contracts. |
| SHA-256 and bounded hashing streams | UBECore hashing | Known vectors, large input, incremental/finalization, failure behavior. |
| Portable path operations | UBECore paths | Lexical vs filesystem normalization, traversal, case policy, host adapters. |
| File reads and atomic output replacement | UBECore files plus platform adapter | Size limits, permissions/full disk/interruption, cleanup, no false-success output. |
| Shell-free process execution | Compiler-support plus platform adapter | Separate arguments, bounded capture, timeout/cancel, exit status, handle cleanup. |
| Bounded binary reader/writer | UBECore serialization | Checked offsets/lengths, endian contract, corrupt/truncated input tests. |
| Bounded work queue/executor primitives | UBECore concurrency | Cancellation, drain, ownership, wakeup failure, stress and leak tests. |

Public API naming and package placement remain separate source-library tasks.
If a facility is useful only to build tools, propose a versioned
compiler-support library instead of polluting either UBECore or the compiler.

## Differential comparison ladder

1. Input acceptance, exit status, diagnostic identity/location, and artifact
   presence.
2. Token kind/value/span snapshots.
3. Normalized syntax meaning and recovery boundaries.
4. Declaration, type, conversion, binding, and control-flow decisions.
5. Function-local IR semantics and verifier rejection cases.
6. Target ABI/layout, LLVM validation, native results, debug records, package
   contents, and linked-runtime behavior.
7. V4 stage-two/stage-three fixed point and exact UBECore slice reproduction.

Each task uses only the lowest comparison level needed to isolate failure.
