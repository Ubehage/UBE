# UBE Compiler v4 architecture

## Status

The owner approved this direction on 2026-10-27. Task 0 subsequently froze the
measured syntax choice, phase interfaces, identity and merge rules, initial
limits, diagnostic comparison, test/evidence formats, and complete first-slice
library placement in [`TASK0_DECISIONS.md`](TASK0_DECISIONS.md). This document
is the production architecture boundary. Later changes to a frozen contract
require the review specified by `AGENTS.md`; implementation convenience is not
a design decision.

## Design objective

V4 should compile the frozen UBE 1.0 language with v3-compatible observable
behavior while making the common unit of work small, owned, indexed, and
independently verifiable. A source file should not require a private copy of
the grammar. A procedure should not require a private copy of the program. A
function should not require scans over unrelated functions.

## Dependency direction

```text
driver/coordinator
  -> immutable build/session descriptions
  -> project graph and source snapshots
  -> tokens and compact per-source syntax
  -> frozen declarations, names, and types
  -> function-local semantic results
  -> function-local verified IR
  -> target backend fragments
  -> canonical artifact publication

compiler -> versioned UBECore/compiler-support APIs -> minimal intrinsics
backend  -> target description -> LLVM/tool adapter and linked substrate
```

An arrow means the consumer may depend on the producer's published interface,
not its private arrays or construction state. No lower phase reaches upward to
query the driver or mutate an earlier phase.

## Ownership model

- A compilation session owns configuration, limits, target identity, source
  identities, cancellation, and final diagnostics.
- Every source snapshot is loaded once and immutable after validation.
- The grammar/tables are loaded once and immutable for the session.
- Token and syntax arenas are owned per source. Cross-source references use
  stable source IDs plus local IDs, not translated global array offsets.
- Declaration collection is deterministic and serial initially. It publishes
  a frozen, indexed universe of declarations, scopes, folded names, and types.
- Each procedure body owns its binding, typed-expression, control-flow, and
  local-diagnostic arenas. It reads the frozen universe but cannot mutate it.
- Each lowered function owns local blocks, values, instructions, edges, roots,
  and debug locations. Verification is local except for a small explicit
  program-link verifier.
- Backend workers own function fragments. The coordinator assigns canonical
  final order and publishes artifacts atomically.
- Temporary files, processes, locks, and handles have explicit owners and are
  released on success, failure, and cancellation.

## Stable identity and deterministic merge

Stable identities are hierarchical:

```text
project -> manifest source order -> declaration source position
        -> procedure identity -> local syntax/IR identity
```

Hash tables are lookup accelerators only; iteration order is never observable.
Parallel results are merged by stable identity. Diagnostics are sorted by
project/source order, span, stable code, and a documented tie breaker. Final
metadata numbers are assigned during canonical merge, never by workers.

## Phase contracts

Each phase publishes a bounded result with:

- immutable input identities and hashes;
- owned records with checked IDs and explicit absence sentinels;
- deterministic diagnostics and completion status;
- record counts and algorithmic work counters;
- no borrowed mutable arrays from another phase; and
- a release operation for non-managed resources.

The published result must be testable without running every later phase.

Every published phase contract also has purpose-built executable fixtures under
the cumulative policy in `TESTING.md`. Phase dumps and internal validators make
the smallest relevant layer independently testable; a complete self-build is
never the only evidence that a phase works.

## Syntax decision

V4 uses the measured selective hybrid representation defined in
`TASK0_DECISIONS.md`: immutable source bytes and tokens retain lossless input;
per-source syntax stores only structures required by later phases; every token
and node retains an exact span; and a generated grammar inventory/coverage
check prevents hand-written parser drift. Numeric production identities replace
hot folded-name dispatch. Full wrapper/token CST nodes and v3's global syntax
arrays are explicitly rejected.

The reproducible Task 0 runner compares the accepted hybrid against a full
table-driven representation on valid, malformed, depth, and scaling inputs. It
records nodes and bytes per token, parser work, peak working set, recovery,
spans, grammar coverage, and maintenance constraints rather than selecting from
wall time alone.

## Library boundary

The public standard library owns facilities useful to UBE programs generally.
A narrowly scoped compiler-support package may own reusable tooling facilities
that should not be public language APIs. The compiler itself owns language
policy only.

Expected library candidates include bounded text builders, UTF-8 traversal,
ordinal and folded-name operations, hash maps/sets, stable sorting, path
normalization, atomic file publication, process invocation, hashing, binary
readers/writers, and bounded work queues. Each candidate needs a contract,
tests, and an intrinsic audit before v4 depends on it. Moving code does not
mean copying its v3 implementation.

## Performance contract

- The permanent reference path is `--jobs 1`.
- Parallelism is enabled phase by phase only after identical observable output
  and a representative speedup within a recorded memory budget.
- Source and procedure scaling fixtures must remain approximately linear in
  their relevant record counts.
- Verifier edge probes, semantic lookup probes, IR instruction visits, and
  backend instruction visits receive deterministic upper-bound gates.
- No production path serializes a whole compiler model merely to cross a
  worker boundary.
- No phase performs Unicode folding, grammar-name lookup, or symbol lookup in
  a hot traversal when a canonical numeric identity can be resolved once.

## Bootstrap and acceptance model

The intended chain is:

```text
stage zero -> v2 -> preserved v3 seed/production -> v4 stage one
                                             -> v4 stages two and three
```

Development begins with narrow v3-built v4 slices. Self-hosting is a late gate,
not the inner development loop. At each vertical milestone v3 and v4 run the
same selected corpus and compare the appropriate tokens, syntax meaning,
diagnostics, semantic decisions, IR behavior, LLVM/native behavior, and output
artifact rules. Exact text identity is required where the contract freezes it;
otherwise comparison uses a documented semantic normalizer approved before the
gate is implemented.

## Explicit non-goals

- preserving v3 internal module boundaries or record layouts;
- making v3 fast enough to become the final architecture;
- adding UBE language features during the rewrite;
- changing public semantics to simplify v4;
- enabling concurrency before ownership is proven; or
- moving compiler policy into UBECore.
