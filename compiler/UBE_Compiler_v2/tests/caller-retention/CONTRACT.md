# Caller-retained managed ByRef regression

This fixture enforces the owner-approved synchronous compiler-private obligation
in [CALLER-ROOT-PROPOSAL.md](../../../UBE_Compiler_v3/CALLER-ROOT-PROPOSAL.md).
The native caller roots writable output locations or precise containing owners
before entry, including neutral outputs. Retaining the old referent alone does
not satisfy the obligation. Unsupported unrooted native calls are controls.

`check.ps1 -SelectionPath <source-built selection>` compiles the intact fixture
through both selected stages and compares raw LLVM. Only native test exports and
a marker before the fixture's explicit collection are appended; no callee roots
are removed in the test. Generated layout and root-lowering assertions require
the intended mechanism and retain private value/borrow-owner roots.

Five independently checked cases cover direct array output, managed record
output, forwarding/exact alias, an array-of-record element while its holder is
replaced, and a class array field while its owner holder is cleared. Each nested
callee returns before the outer callee collects, before any fresh read/borrow.
Every case runs with ordinary collection and collection before managed allocation.
Native post-sweep watches are not traced roots. They check the container before
loading an interior slot, then require the new value live without pending
publication or pins. Contents, stale Err77, completed collection, zero mark
failures and final roots/payload drain are asserted separately.

Missing native output-root and missing containing-owner controls must terminate
with the exact dead-watch diagnostic before dereferencing reclaimed storage.
The direct-output control must reach the marked post-nested-return collection.
These deliberate test exits do not represent supported foreign calls.

The two stages produce 20 positive executions, 12 negative controls and 35
grouped assertions. The observer is generated from the selected cohort's pinned
runtime source on each run; no historical compiler/runtime artifact is needed.
Seed/source fixed point, allocator/root-capacity failures, ByVal/copy/result,
thread capture and native Main admission remain separate maintained gates.
No public foreign ABI, asynchronous ByRef or performance claim follows here.
