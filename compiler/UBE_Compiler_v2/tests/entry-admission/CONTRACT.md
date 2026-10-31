# Executable entry admission regression

The previous native wrapper treated a neutral Function Main result as process
success when managed-root admission failed before its body. Sub Main had the
same missing observation. The real 1,048,576-root limit reproduces this without
mocking a runtime primitive; Err 7 alone cannot distinguish a fresh failure
from a stale error.

The wrapper now owns a fresh false Boolean slot, passed as a hidden pointer
only to source Main. Main marks that observer true only after every root and
ByVal admission step succeeds. Ordinary source calls to Main pass null. Failure
to admit source Main produces an actionable fixed diagnostic and process
status 70; successful Main retains its normal result regardless of stale Err.
The observer has stack lifetime and does not use shared state or TLS.

The native probe covers Function and Sub Main, ordinary UBE calls to Main,
stale Err on successful entry, complete root exhaustion, partial registration
cleanup, and successful entry after recovery. A rooted ordinary Try function
still returns its documented neutral False before its body; its ByRef failure
argument remains unchanged, so source callers must keep their existing fallback.

The test adapter renames only the generated native main wrapper and three
procedure symbols for C linkage. It preserves all generated bodies and calls.
Both source-built stages must pass exact native output/status/stderr checks
and produce byte-identical unmodified LLVM.
