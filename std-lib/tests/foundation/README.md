# Independent bootstrap fixtures

These bare-source programs are test-only inputs to the documented bootstrap
profile, not production UBECore modules. No source is added to `UBECore.UBE`.
Expected results in `cases.json` were specified before running the compilers.

The `subset` cases require Long arithmetic/control/calls, exact ByRef storage,
field-only Long records, zero initialization, one-dimensional zero-based Long
arrays, Preserve growth, and controlled rejection of invalid source. They do
not test overflow, aliasing of managed data, arbitrary bounds/rank or failure
recovery. Each native program must return the specified exit code and exact
stdout (only CRLF is normalized), with empty stderr. A second compile must
produce byte-identical LLVM.

The `target-probe` cases test needed semantics outside that narrow subset.
Their failures stay visible; rejecting a feature required by the language is
not a passing test. The scalar IR patterns check actual emitted local storage,
not just whether a small integer prints correctly. A record with one Long
field cannot prove managed deep-copy behavior or type-extension metadata.
The embedded-zero case asks whether the bootstrap String operations can serve
as general byte storage. `StringFromByte` has a documented 1..255 bootstrap
domain: zero is intentionally outside it. Its failure is a suitability limit,
not evidence that this private intrinsic violated its declared contract.

For rejection cases the compiler must exit with an ordinary error status,
produce a diagnostic and leave no LLVM artifact. A crash or timeout fails.
These cases do not yet validate the full diagnostic schema or recovery after
multiple independent errors.

Run the [foundation checker](../../tools/check-foundation.ps1) from the repo
root. It writes commands, process outputs, compiler/input/runtime hashes,
repeat comparisons and timing evidence under `bootstrap/out/foundation/`.
Tool names alone are not evidence that current source produced a restored
executable. The checker builds the current small seed and runtime separately;
restored v2 artifacts are tested by hash, without a self-hosting claim.
When those ignored backup executables are unavailable, the checker explicitly
skips them and still builds/tests the current-source seed. It never downloads
or substitutes a tool. The exit status gates the six `subset` cases for the
current seed only. Inspect the separate probe results for unmet requirements;
this is not an implementation acceptance gate for the planned library types.
