# Value materialization regression

Only managed expression nodes used exclusively through known non-reference
member/array addresses or exact verified positional ByRef actual addresses may
omit private value/scratch/root slots. A bounded argument-link pass requires
the same non-array named callee/formal mapping as emission, exact formal count
and ownership, modes1/3 and a known actual address. Unknown, unlinked, ByVal,
unreferenced, mixed, statement/initializer, call/result, reference identity,
New and Nothing uses retain their slots. Address-chain
classification is bounded. ByRef caller ownership and every genuine value,
borrow, fallback, incoming ByVal, result and entry obligation remain separate.

`check.ps1 -SelectionPath <source-built candidate.json>` extracts the actual
tracked classifier helpers and tests independent synthetic AST masks through
both source-built compilers. The old six-argument native bridge roots its shared
neutral holder for three additional empty arrays before entry, reports fresh
Err7 on rejected admission and releases it after every admitted call. Formal
binding controls root all six actual input holders in C. The native caller roots
all three original input arrays;
the 32-byte root ABI, real registry exhaustion/recovery, stale Err and forced
collection/payload drain are asserted. No observed root count weakens the oracle:
NeedsValueSlot must retain exactly its two indexed-access borrow-owner roots,
without duplicate argument or private value roots. At the actual full registry,
zero or one available root must fail neutrally with Err7; two must succeed and
preserve stale Err77. Every admission and cleanup leaves the old graph intact.
The original2,097,226 native assertions remain intact;34 binding assertions add
exact modes, wrong owner/count, unknown/unlinked/shared links, mixed aliases,
initializer/CLASS receiver, cycle rejection and fresh recovery. Private argument
record layouts are checked against emitted LLVM and native static sizes.

The same-cohort manifest-pinned compiler LLVM supplies a test-only eager
oracle. Only NeedsValueSlot is replaced with its former ResolvedType >= 1000
decision; no historical compiler binary or ignored report is consumed. Both
accepted stages must emit identical fixture LLVM. Every omitted slot in eager
output must have only allocation, neutral initialization and exact 32-byte root
bookkeeping uses. After those enumerated deletions, every other instruction,
global, native layout and procedure signature must be byte-identical. Deliberate
real-use, genuine-value, ABI and partial-slot corruptions must fail the oracle.

The tiny record fixture covers address-only members, ByVal copies and managed
call/results. A separate forwarding fixture witnesses four unused private
slots for ByRef record/record-array/record/member-byte-array arguments, seven
newly omitted actual pairs over its complete source. The maintained eager
comparator forces every managed slot, so it additionally includes the already
address-only Document base of Document.Bytes: exactly eight omitted pairs,
five in Forward (four actuals and that member base), and three in Main.
Exact per-procedure node sets distinguish these routes; the prior seven-pair
experiment compared against the original address-aware compiler instead.
A real local allocation keeps forced-GC
reclamation meaningful. Literal ByRef arguments still produce the exact
independent UBE3202 diagnostic and no LLVM through either accepted stage.
Existing independent reference/New/Nothing/return and borrowed
array replacement fixtures add lifetime controls. Each runs with forced
collection, exact output, zero native roots and zero remaining payload. The
existing managed-storage, entry, reference and thread gates remain required.
This proof makes no timing or performance-acceptance claim.
The maintained report has25 checks: all19 original checks, four for the new
forwarding fixture, and two stage-specific literal rejection checks.
