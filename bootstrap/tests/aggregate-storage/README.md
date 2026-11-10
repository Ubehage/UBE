# Aggregate storage acceptance gate

Run `rtk proxy powershell -NoProfile -File bootstrap/tests/aggregate-storage/check.ps1`.
The gate accepts an existing `-BootstrapExe` and retains generated artifacts.
It checks fixed rank-one arrays, finite scalar-field records, independent value
copies, aliases and guarded indexing in actual compiled source at O0 and O2.

On 2026-11-10 the updated gate passed 35 groups against the VB6-built compiler
in `ube dynamic storage cd871c2d-4cb0-40d5-aa6e-22bed7b6fd84/build`.
Evidence: `ube aggregate storage 686642c7-c424-4926-9682-2978ece9fc13` in the
temporary directory. Three former unsupported cases (dynamic declarations,
different-bound copies and borrowed-descriptor copies) moved to positive
dynamic-storage coverage.

The initial gate built the bootstrap with VB6 6.00.9782 and passed 38 groups.
Evidence: `ube aggregate storage 464b9387-76b0-4159-b3ff-459aa6113b20` in the
printed temporary root; its `build/UBE-Bootstrap.exe` is the tested binary.

This bounded slice rejects different-bound or unknown-shape whole-array copies
explicitly. Full UBE array assignment still adopts source bounds; this gate does
not redefine that contract. Dynamic arrays, heap allocation, managed text and
new loop/header failure semantics remain outside the tested scope.

The source fixture retains ASCII and UTF-8 bytes alongside token-span and tree
node records. Existing GoTo control flow traverses the node array and observes
the stored token lengths. This demonstrates retained buffers/trees, not a UTF-8
decoder or a self-hosting parser. Independent record/array copies, self-copy,
record equality, negative lower bounds, array-element/field aliases and exactly
once indexing are checked separately.
Additional cases use constant bounds, nested record copies/aliases, and
singleton arrays at each LongLong bound through rank-only ByRef parameters.

The same emitted library is called through a test-only LLVM harness at O0/O2.
Each procedure receives a fresh explicit context and volatile runtime input.
Bounds checks include ordinary high indices and both LongLong extremes; failed
reads preserve the receiving variable, failed destination access suppresses its
right-hand side, and failed ByRef preparation suppresses later arguments and
callee entry. Err 9 and handler transfer are observed. A changed tree-start
input must trigger the storage oracle's failure bit.
An invalid index inside an active handler must continue silently without
reentry; the unfinished assignment and later expression operand remain skipped.

SYMBOL/BOUND metadata assertions check nominal Type identity, ordered field
ownership/offsets, fixed array bounds, rank-only parameter shape and resolved
writable access. Negative cases distinguish invalid programs from deliberately
unsupported operations. An invalid aggregate program must preserve an existing
LLVM artifact. Whole-array assignments now exercise independent heap-backed
replacement even for fixed declarations. Allocation failure and ownership
accounting are covered by the separate dynamic-storage gate.
The metadata gate also checks field-declaration scope ownership, a nominal
`Type [Long]` alongside primitive Long, and escaped `Type [A|B]` names across
AST, SYMBOL and BOUND records without corrupting field framing.

Resource regressions require specific controlled errors for 129 flattened
record cells, 65 layout levels, more than 65,536 module-context cells and a
frame whose aggregate copy snapshot pushes it above 128 cells. Storage-limit
failures must preserve the previously emitted artifact.

The syntax regression keeps `Take (Value) = 1` as a no-parentheses procedure
call with a Boolean comparison argument. The bounded parser admits a spaced
indexed assignment using explicit `Let Values (Index) = ...`; bare indexed
assignment requires the opening parenthesis adjacent to the array name.
