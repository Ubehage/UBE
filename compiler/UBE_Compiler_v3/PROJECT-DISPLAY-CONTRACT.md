# Bounded project path display

Continuation of PROJECT-DIAGNOSTICS.md; no source text or full String facility.
`TryFormatProjectPath` borrows zero-based counted path bytes (maximum 131068)
and prepares the entire quoted display before replacing its older String result.
It escapes quote/backslash, C0 and DEL exactly as that contract requires and
preserves other UTF-8 bytes. The helper prints nothing. A failed native allocation
or managed admission must return False and retain the earlier result and input.

The temporary bootstrap String surface allocates immutable process-lifetime
strings. It is used for bounded CLI metadata only, with per-byte pieces and one
join, not as source storage or the future UBECore String implementation. Shared
native allocation-list publication must be synchronized; scratch arrays/results
belong to each caller. Process teardown releases the legacy String arena after
callers drain. Tests may explicitly invoke that private teardown after dropping
all display references. That does not establish general String lifecycle semantics.

Before CLI use, both source-built tools must pass exact UTF-8/control/quote output,
empty input, boundary/one-over input, every executed allocation position and any
retry, actual root-capacity exhaustion, old result/input retention, concurrent
callers sharing immutable bytes and complete teardown. Capture native allocation
calls/requested bytes; initial ceilings are 32*N+64 calls and 128*N+4096 requested
bytes during one helper call. They include native overhead, not process RSS.

The synthetic regression in tests/project-input/display-before-oom.json records
the actual pre-fix exit 70 on a denied legacy String allocation. Preserve that
capture (SHA-256 F9D63757317E17293E30FE648685EDE08F367C5C03F8D8F4CEACC4E2FA1DAE79).
The fix must make the same actual UBE helper return controlled False. It must not
hide the fault, rewrite production LLVM bodies or weaken the expected output.
No project CLI or refreshed source-cohort acceptance is implied by this component.
