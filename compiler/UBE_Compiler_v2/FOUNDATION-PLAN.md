# Usable v2 foundation plan

Owner request, 2026-10-30: complete the steps needed to obtain a v2 we can work
with. This is the active bounded-bootstrap prerequisite in the fresh v3 and
UBECore workplans, not a new compiler generation or a public-language release.

## Acceptance contract

- Build stage zero and both bootstrap runtime objects from current checked-in
  source, offline, in a separate output directory. Do not rely on restored
  executables or run the full archived-compiler build.
- Build v2 stage one from current `Main.bas`, compile its manifest into stage
  two, then require byte-identical stage-two/stage-three LLVM for the same
  current input. Retain input/tool/runtime identities and complete commands.
- Both v2 stages must pass the existing positive programs, all existing negative
  fixtures with matching diagnostics/status and no new artifact, and independent
  foundation cases. Preserve the existing v1 and C++ seed regression gates.
- Prove Byte unsigned 8-bit and Integer signed 16-bit storage, checked scalar
  conversion at assignment/call/result boundaries, exact ByRef types, scalar
  record value copying and compact zero-based one-dimensional Byte arrays.
  Array tests must preserve 0/128/255 across growth and isolate element access.
  Unsupported cases must diagnose rather than emit invalid LLVM.
- Use native expected values and emitted LLVM assertions, not stage agreement
  alone. Prove missing/malformed inputs and output failures terminate in bounded
  time without publishing new output. Preserve backup artifacts and archives.
- Record observed build duration and actual compiler process peak memory as
  diagnostic measurements; do not claim scaling, allocation or concurrency
  performance from process completion.
- Publish one maintained command and a success manifest identifying the tested
  v2 executable and exact supported subset. A fresh checkout must not need
  ignored backup executables. No new dependency or network build step.

The finished language's arbitrary array bounds/rank, managed deep copies, GC,
threading, full error handling and native-type extension mechanisms remain
outside this bounded v2 contract. Do not silently accept unsupported numeric
operations or describe this compiler as full UBE conformance.

The private bootstrap StringFromByte domain remains 1..255. General byte storage
uses Byte arrays; changing that String intrinsic is not a repair justified by
the embedded-zero suitability probe. New public byte/text APIs and native-type
extension syntax still require their own reviewed contract.

## Work and evidence

- [x] Reproduce the current-source baseline chain and isolate required failures.
- [x] Repair only demonstrated prerequisite defects; add focused positive,
  rejection and native regressions before marking each repair verified.
- [x] Run the source-built fixed point and compatibility/foundation corpus.
- [x] Record executable/input identities, supported subset, limits and the exact
  next UBECore/native-type task in the shared handoff documents.

The maintained build gate passes 130 assertions. Full procedure, crash
reproducers, tool identities, output-helper acceptance and limitations are in
`FOUNDATION-VERIFICATION.md`. Next: review the proposed library-defined native
datatype mechanism in `../../std-lib/FOUNDATION.md`, then specify/prove that
mechanism before a production byte/text API or fresh v3 compiler scaffold.
