# Bounded coordinator wait diagnostic

Status: focused experiment; no production wait-policy change is adopted here.

The current UBE coordinator repeatedly calls `TryThreadWait(Id, 0, Completed)`
and yields when no slot completes. Measured serial work uses nearly two CPUs;
callsite observations also show schedule-dependent coordinator array/reference
reads. Test the smallest alternative before changing roots or scheduling more
broadly: use the existing wait API with timeout 1 instead of zero.

The timeout is a maximum requested blocking interval, not a forced sleep before
observing completion. A signaled worker returns immediately. Host scheduling can
overshoot a requested timeout, so this experiment promises no real-time bound.
Admission order, active IDs, one worker budget, completed visibility, cancellation
checks, retry/drain and canonical first failures remain the existing UBE code.
No worker is delayed by a test barrier or replaced by C.

Use two exact experimental LLVM inputs: the frozen original and the prior
private-frame/caller-retained-ByRef candidate. Change only the zero-to-LongLong
timeout operand immediately consumed by the one native wait call. Compare every
byte/token/node/metric with the frozen reference at budgets 1/2/4, require the
same root admissions/removals, and check complete cleanup. Retain every row.

Instrumented diagnostic timings cannot pass the performance gate. A production
policy change needs the original failure/cancellation/reverse-completion/overlap
gates, one-source overhead guards, full representative workloads and the two
uninstrumented sessions. Keep compiler wait policy out of UBECore.
