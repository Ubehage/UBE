# Focused complete-checker native witness

This is a diagnostic integration witness, not qualification of the complete
checker or a replacement for the 205 targeted and frozen complete streams.
Expected language values and source programs are independently specified before
running the checker. No candidate output will be used to manufacture answers.

The real UBE fixture admits bytes through BeginSourceInput/AppendSourceInput/
TryFinishSourceInput into a SourceOwner, reads the envelope,
scans and parses SourceWork. The whole checker is invoked through
TryCheckSourceSemantics, including frozen catalog preparation, required constants,
static UBE module workers, statements/expressions/calls, entry selection and final
result publication. Jobs1/2/4 are tested on each single-source program; these
requests can admit only one module worker and make no four-worker overlap claim.

Empty Main requires two declarations and exactly three body nodes: module100,
procedure101 and empty block102; no body facts. The owner integer example
Dim x As Integer = 40000 - 10000 requires widened Long left literal, Integer
right literal, Long folded30000 with no arithmetic children, checked Integer
destination, neutral-before/survives-failure storage103. It requires three
declarations, five body nodes and seven complete body facts under INTERFACES.md.

The exact frozen ScalarApp source exercises module Const, ordinary AddOffset,
function result storage, contextual LongLong folding to2147483648, Integer
fold/conversion to30000 and runtime self-initialization. Its independent stream
is bootstrap/out/complete-semantic-oracles/author.ps1 and complete.json. All eight
declarations/signatures and original identity spans, six builtin type records,
twenty body nodes, one catalog constant node and all53 catalog/body fact records
are compared field by field. Parser/arena indexes normalize independently resolved
original spans; expected language values are hand-authored. Missing, extra and
conflicting records fail; physical unused capacity and arena allocation order do
not form language expectations.

FlowApp has exact branch/loop child ownership and Exit targets. ForwardApp's
first module initializer reads later at own-module lookup level3; the read remains
runtime and has no propagated known value. Local-before-written declaration is a
distinct DeferredLocalLifetime case; forward required constants stay NotConstant.

Repeated1/2/4 requests must publish fresh results with equal complete scalar
fact/value payload, preserve old complete results and all original source,
tokens/syntax payload, and select only the proper Main. Known invalid initializer,
wrong Exit, invalid Jobs and observed cancellation must keep the old published
reference and contents. The final root/heap/native worker/capture cleanup must
leave no test-owned resources. A deliberately wrong integer answer must fail the
comparator. Executed source-copy/resize, allocation/copy and root/heap events are
observed directly; no performance or universal resource-bound claim follows.

Both accepted894 stages, unchanged raw LLVM, complete budget/root/allocation/
worker fault sweeps and the full logical complete-output comparator remain final
integration obligations. Initial focused runs may use one accepted stage to
diagnose actual failures and must say diagnosticOnly:true.
