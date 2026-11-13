# Native escape ownership qualification

The production analyzer publishes one node-indexed `EscapeFact` array. On a
declaration node, `StorageEscapes` identifies promoted storage or an incoming
owner parameter. On an argument node, `NeedsOwner`, `OwnerKind` and
`OwnerIdentity` identify program storage, a storage symbol, a call temporary,
or an indexed payload snapshot. An escaping indexed local also promotes its
underlying array so fixed inline payloads never escape. The analyzer does not
emit native pointers or perform worker execution.

Run the actual UBE source-derived assertions through
`rtk proxy powershell -NoProfile -File bootstrap/tests/expression-binding/check.ps1 -BootstrapExe <host>`.
The 2026-11-13 run passed 70 cases and 26,561 assertions at O0/O2, including its
mutation control. Evidence: `ube expression binding
792736cc-6fcf-44ac-9ec9-901f089729d9`.

Run the matching host analyzer against that gate's retained fixture:
`rtk proxy powershell -NoProfile -File bootstrap/tests/native-escapes/check-host.ps1 -FixtureProject <artifacts>/escapes.UBE`.
It checks the expected promoted declarations, each owner category, preservation
after bounded rejection and successful retry. Passed evidence:
`ube host escapes 3d16e5e9-8f4f-4f37-a34b-89eccc796f82`.

The shared fault runner accepts `-Analysis Escape`:
`rtk proxy powershell -NoProfile -File bootstrap/tests/expression-binding/allocation-check.ps1 -Analysis Escape -BootstrapExe <host>`.
Six allocation sites were measured; all were failed and retried at O0/O2 while
checking every retained output field and zero live allocations after disposal.
Together with bounded call-depth probes, 30 checks passed. Evidence:
`ube escape allocation d27a313a-b4b2-411b-ae3d-495f2094e6b2`.
The default expression-analysis mode also passed its 48 checks after the shared
runner change (`ube expression allocation f13a2c5c-25a2-454c-8f15-4fabcbe2b58a`).

Real source worker execution belongs to `runtime/tests/callnew/check.ps1`;
compiler scheduling, parallel requests and performance require additional gates.
