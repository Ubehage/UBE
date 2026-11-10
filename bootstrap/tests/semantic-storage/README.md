# UBE semantic storage acceptance

Run `rtk proxy powershell -NoProfile -File bootstrap/tests/semantic-storage/check.ps1 -BootstrapExe <executable>`.
The host builds actual UBE PrimitiveRoles and AggregateLayout with their syntax,
declaration, expression and UBECore dependencies. Runtime files provide the test
projects. Both O0 and O2 use the same emitted library.

The role gate asserts all eleven exact signatures and canonical role IDs, wrong
results and selected parameter modes/types/arity, missing/duplicate attributes,
wrong targets, unknown/untrimmed roles, ordinary familiar names with no authority,
case-insensitive metadata, nominal TryCopy identity, executable versus library
Main and parser rejection of implemented intrinsic bodies. Only procedure
declaration nodes may carry authority. Malformed placement is rejected explicitly.

Layout checks assert finite nested field widths/offsets, fixed and dynamic owner
sizes, borrowed array facts, logical ByRef record widths, indexed scalar/record
values and fields selected from indexed records. Exact boundaries cover 128
record cells, 64 layout visits, 65,536 aggregate module cells and singleton
arrays at signed64 extreme bounds. Recursive unused Type graphs, excess sizes
and malformed shape metadata fail with preserved prior output and zero count.
The parameter-shape mutation swaps existing complete shape subtrees while
retaining valid tree links, rather than depending on a malformed child count.
Rank-only tags with retained fixed-bound children are rejected by both relevant
passes. Exact second-module diagnostics retain original local byte/UTF-16
coordinates; context capacity is also tested as a sum across two modules.

Actual compiler/library sources pass both complete semantic passes; independent
request recovery checks deterministic facts. Changing an actual File.TryRead
attribute to File.TryWrite must fail the precise unchanged role assertion.
These checks establish semantic identities and the private cell representation,
not native code generation from this new layout or a foreign/public ABI.

Production-only assembly at O0/O2 must not depend on the large assertion driver's
test-only Windows stack-page helper. Hidden child processes and native tests are
bounded; temporary `ube semantic storage <guid>` directories retain source, IR,
images, logs and numbered assertions. Allocation/depth fault injection is in
the separate parameterized `allocation-check.ps1` companion.

Final acceptance passed 50 cases and 16,263 assertions at each of O0/O2,
production-only assembly checks at both levels, and the exact changed-role
negative control (assertion 432). Many assertions cover runtime path setup and
fresh status in addition to the semantic facts.

Evidence: `ube semantic storage 1a6965b9-bb6a-493b-a180-d8639b38bfc9`.
The command above used `UBE-Bootstrap.exe` from the temporary directory
`ube project loading dbd30a59-26f6-43b5-a9d9-e3b4c6143261/build`.
This run includes the final primitive-placement and array-shape arity guards.

Run the allocation companion twice using
`rtk proxy powershell -NoProfile -File bootstrap/tests/semantic-storage/allocation-check.ps1 -Pass Primitive -BootstrapExe <executable>`
and the same command with `-Pass Layout`.
It measures the complete allocation sequence on a 303-symbol fixture, then
fails every observed allocation and its retry. Each failure must preserve all
old output fields, publish zero count and release temporary owners. A subsequent
successful attempt must preserve sticky Err; final disposal must leave zero live
blocks. Native depth probes cover 0, 192, 224, 240, 248, 252, 254, 255 and 256.

- Primitive: 10 observed sites, 38 fault/depth checks and two baseline
  measurements passed; `ube semantic allocation ba1b2e59-ee73-4bf9-914b-51bc4b325ddb`.
- Layout: 27 observed sites, 72 fault/depth checks and two baseline measurements
  passed; `ube semantic allocation 64234d5b-3b19-49d7-a836-1df9c3836f00`.

Both passes use the same host binary as the main gate. The primitive fault
fixture executes PrimitiveRoles and its prerequisites; AggregateLayout is also
compiled into that test library but is not invoked by that fixture.
