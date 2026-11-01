# Procedure root-registration experiment

Status: diagnostic proposal following the measured root costs in
`FRONTEND-PERFORMANCE-EVIDENCE.md`. This does not adopt a production emitter
change or a new collector architecture.

The existing runtime accepts one root layout containing multiple pointer slots.
The experimental LLVM adapter groups only a procedure's private, already-rooted
managed stack values in one native aggregate, with the same field types and
precise pointer offsets. Scalar-only values stay in their original allocations.
ByRef addresses into caller storage retain their original separate roots.
No UBE record/array value becomes a shared alias and no source payload is copied.
All source, scanner, parser and scheduling bodies remain actual UBE.

Allocate and initialize all aggregate fields where the original prologue did.
Register the aggregate through the existing checked `ube_value_root_enter`
before the original individual admissions. Preserve the original status/control
flow for external roots. Replaced private admissions report success only after
the aggregate admission succeeded; failure branches to existing cleanup before
user body or positive worker admission. Remove only the replaced private cleanup
calls and leave the aggregate exactly once at procedure exit. Retain the 32-byte
root-storage ABI, runtime, class layouts, value layouts and callback interfaces.

Before linking, independently assert that every grouped address is a unique
private alloca initialized before root admission, that every original private
root has exactly one matching cleanup, that no scalar-only value enters the
aggregate, and that precise root offsets are the union of the original layouts.
The native result checks compare every source byte, token, node and metric with
the frozen baseline reference, preserving worker drain and zero owned resources.
Count actual root admissions/removals/links/locks at budgets 1/2/4 on the focused
four-source input. Counts may decrease; all language work/results must remain.

These instrumented timings are diagnostic only. Any production adoption still
needs exact source/seed emitter changes, managed-admission/GC/failure regressions,
the retained bootstrap/parser/CLI/concurrency gates and the two complete matched
uninstrumented performance sessions. A successful small experiment cannot prove
the new representation safe for all supported programs or complete the goal.
