# Fixed source-worker controller draft acceptance

Frozen before compilation/measurement. This is a focused extraction of the
existing source parser admission/wait/stop/drain pump, not a new executor or
semantic phase API. SourceWork and ProcessSourceWork stay unchanged. The parser
keeps its static CallNew target; future consumers may provide their own static
target while using this same scalar controller.

The one-invocation state contains exactly four native LongLong IDs, four Long
source indexes, Jobs/Total/NextSource/Active, a Boolean StopAdmission, and Long
PollCursor/FirstInfrastructureKind/FirstInfrastructureSource. No managed fields,
arrays, callback or work object belongs to this state. Actual emitted type
layout and zero managed metadata must be checked. Every controller helper must
have zero managed root-admission calls and zero allocation/payload-copy calls.

Jobs accepts 1..4, Total accepts 0..256. Admission is canonical and at most Jobs
IDs are live. Each Admit is followed by either a storage failure or the caller's
static CallNew and immediate rootless commit. An admitted positive ID is retained
until a real successful wait reports completion. Cancel closes admission (4),
zero native start closes it (2), caller managed lookup/result storage failure
closes it (5), and false stop/wait closes it (6). First infrastructure kind wins;
later same-kind failures choose the smallest associated source index. Ordinary
source errors remain caller-owned, and choose the smallest canonical source.

Each action performs at most one 1ms native completion wait, one stop request
when closing admission, and one yield while work remains active. Failed wait or
stop never clears the ID. Polling rotates over active slots. AllowAdmission=False
prevents every new admission while still polling/draining active IDs. It may
return idle when there is no active work and unadmitted sources remain. Done
requires no active ID and either all sources admitted or admission closed.

The copied full existing concurrency fixture must retain its independent
1/2/4-worker output/token/graph/span/failure comparisons, actual UBE admission,
overlap/reversed completion/capture proofs, source-copy prohibition, canonical
source failures, boundary/cancellation/start/wait/storage/root denial, old graph
preservation and complete capture/record/handle/root/heap drain assertions.
Underlying parser/scanner and coordinator/worker root bounds stay as documented
in CONCURRENCY-CONSUMER.md; removing two tiny managed controller arrays cannot
relax any bound. Native timing is diagnostic, not a speedup claim.

Additional focused controller assertions must cover the admission pause,
cancellation/first-kind association, failed stop/wait retention and recovery,
and invalid Jobs/Total without starting workers. Both accepted source-built
stages must produce identical raw LLVM. Input/tool/source identities must remain
unchanged and all draft artifacts stay below bootstrap/out/source-worker-slots.
CLASS parsing and semantic worker execution remain outside this qualification.
