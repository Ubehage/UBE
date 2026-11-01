# Focused collector-root cost diagnostic

Status: diagnostic design for the active performance investigation. No
production optimization is chosen by this document.

The emitter's `EmitValueRoot` already returns immediately for rootless layouts.
Do not assume scalar-only roots are registered or removed without a native
sample showing it. The runtime's registered roots form one singly linked list;
`ube_gc_root_leave` scans it under the collector lock. The focused question is
how much scanning the actual UBE frontend causes, and how it scales with the
number of live workers.

After the uninstrumented pre-optimization baseline is frozen, run
`tools/measure-root-cost.ps1 -BaselineReport <report.json>`. It uses the frozen
raw UBE consumer and intact timing/assertion adapter, with a diagnostic-only
runtime copy. Four independent copies of the complete production SourceInput
MODULE, with distinct envelope names, exercise genuine `TryParseSources` at
budgets 1/2/4. Qualified immutable documents enter the actual UBE source workers;
no C parser or C replacement worker is permitted.

Observe executed collector lock acquisitions, successful root admissions, root
leave calls, list links examined and peak root count. Increment counters while
the existing collector lock is already held. Reset immediately before the work
call and report immediately after return, before result assertions. There are
no forced barriers or completion controls. Compare every document/token/node/
metric against one frozen serial reference and require normal resource cleanup.

These instrumented timings are diagnostic only and cannot pass the performance
gate. Preserve exact runtime/raw/tool/adapter/input/result identities. Report all
three worker budgets, even if contention or scans do not increase. Do not change
root representation, add a per-thread collector or alter compiler concurrency
on the strength of a static hypothesis. Use the measured cause to propose the
narrowest correction, with root-admission/failure/GC/concurrency regressions and
the full retained gates before any production acceptance.
