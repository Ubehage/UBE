# Array ownership transfer qualification

`check.ps1` links the production runtime asset to the focused native probe at
O0/O2. Assertions cover descriptor identity, negative bounds, sticky Err,
unchanged allocation count, retained old-destination aliases, self-move of an
inline descriptor, inline-source refusal with both descriptors unchanged,
owned-to-inline-destination transfer, empty source and balanced retirement.
Its negative control removes inline-source rejection and must exit 1.
`check.ps1 -Concurrent` runs two real workers, each making 20,000 transfers,
while the root takes 40,000 protected descriptor snapshots. It checks coherent
bounds/payload/owner tuples, retained aliases, sticky per-worker Err and balanced
retirement. A changed value comparison must fail after safely draining workers.

`source-check.ps1 -CompilerExe <path>` builds and executes the ordinary UBE
`Probe.bas` at O0/O2. It checks the identity-bound wrapper, values/bounds,
source emptying, inline refusal, fixed-destination replacement and sticky Err.
Its changed-value oracle must exit 5. Run it with both the bootstrap and the
actual UBE compiler; a native-only probe does not prove source integration.
It also reaches source depth 256, commits Move, observes ordinary-call refusal
with Err 28, then commits a reverse Move from the handler. Reducing recursion
by one makes that boundary oracle fail, as required.

Current evidence:

- Native with the expanded precise-root context:
  `2ffd8fe8-5fb8-42e6-b606-8bdef82710de`, all four runs passed (225602-byte runtime).
- Concurrent native: `2c3e1384-9a4b-4cc6-8d57-ca35a039bd58`, O0/O2 and both
  changed-value controls passed.
- Fresh bootstrap source: `591810e2-e0ef-4346-9b90-25cfa5c3fa9a`, positive/value/depth
  controls at O0/O2 and three invalid-signature rejections passed using
  `ube native intrinsics f844bb77-293e-4c69-af9f-cdb03f67bbb6/build/UBE-Bootstrap.exe`.
- Final rebuilt UBE source: `499a2363-43fb-4515-9632-20e347695bb8`, the same
  assertions passed using
  `ube compiler rebuild 2a484f43-e11e-4490-8436-686fe60cb92a/generation-2/UBE.exe`.
- Two-output binder preparation: all 15 measured allocation failures and nine
  source-depth boundaries preserved both prior outputs, followed by recovery;
  `f5891242-b8b5-40c2-ae85-f7f8c2982f9d`. See the
  [binding gate](../../../bootstrap/tests/expression-binding/README.md).

These transfer checks qualify the supporting ownership-transfer contract.
Managed text and precise collection require their separate acceptance gates.
