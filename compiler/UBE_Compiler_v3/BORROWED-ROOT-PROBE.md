# Caller-retained ByRef root experiment

Status: focused diagnostic after private procedure grouping. No production
optimization or foreign-call ABI change is adopted by this document.

The approved managed-value ABI requires callers to retain managed arguments and
borrow owners across calls. A ByRef argument aliases caller storage; a second
callee registration of that exact storage contributes no additional live value
when that caller obligation is satisfied. In contrast, ByVal private copies,
private temporaries, results and array/member borrow owners still need their own
precise retained locations.

This experiment starts with the private-procedure-root candidate and omits only
registrations whose value address is exactly a pointer parameter `%arg.N` and
whose root storage is exactly `%root.arg.N`. These are the existing emitter's
ByRef argument roots. Keep every private frame, ByVal parameter, result, capture,
array/member owner and runtime root unchanged. Preserve status/control flow and
remove exactly the matching redundant cleanup. Use actual UBE calls and existing
rooted native test adapters; an unrooted foreign caller is not qualified by this
experiment. No reference becomes an address in the language.

Compare every original source byte, token, syntax node and metric at 1/2/4 workers
with the frozen reference, and require balanced roots, worker drain and zero owned
residual payload. Repeat with a collection immediately before each actual managed
allocation: count collections rather than inferring them from requests. A success
here covers these bounded frontend calls only.

Before production adoption, explicitly review every UBE call-emission path,
hidden managed result, native entry adapter, member/array argument borrow and
exceptional exit against the caller-rooted obligation. Add focused cases where a
callee replaces the original owner while retaining a ByRef element/member, and
where a ByRef output receives a new managed value before a later collection.
Retain all admission/failure/GC/concurrency and earlier gates. Do not use this
experiment to waive lifetime checks, permit unrooted calls, change language value
semantics, or infer a passed parallel performance gate.
