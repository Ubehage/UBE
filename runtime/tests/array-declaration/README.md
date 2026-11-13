# Captured dynamic array declaration reset

This regression covers `NativeStorage.NeutralStorage` resetting an existing
dynamic array at a repeated local declaration. The descriptor can already be
shared through an ordinary ByRef CallNew capture. The synchronized clear is the
complete reset; raw empty-descriptor initialization is valid only before the
descriptor is published.

`Probe.bas` executes one dynamic `Dim` twice. The first iteration captures the
array in a real worker. On the second iteration a test-only wrapper calls the
real runtime clear, then releases that worker and waits for it to resize the
same array and install 42 and 99. This puts the worker's update after the clear
unlocks but before the declaration continuation. The wrapper calls an ordinary
source helper; there is no production hook or new primitive.

The source asserts length two and both values after the forced interleaving,
then explicitly resizes to zero and checks ordinary release. The native bridge
requires fresh source success, completed thread drain, an empty resource
registry, successful context disposal and zero tracked native allocations.
Exit bits are 1 for source outcome/value failure, 2 for cleanup failure, and 4
for retained native allocations. Disposal does not forcibly free live-reference
blocks, so it cannot mask an overwritten descriptor's leaked payload reference.

Reproduce with an unfixed actual compiler:

```powershell
rtk proxy powershell -NoProfile -File runtime/tests/array-declaration/check.ps1 -CompilerExe <unfixed-UBE.exe> -ExpectedExit 7
```

Qualify current compiler source through the existing actual UBE lowering driver:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/native-lowering/check.ps1 -BootstrapExe <qualified-bootstrap> -ArrayDeclarationOnly
```

The narrow selector uses the existing Emit-Project implementation. It emits
ThreadPrimitives followed by Probe through production UBE frontend/lowering
code, then passes the output to `check.ps1 -LoweredIR <path>`. Both the old and
fixed outputs are independently compiled and executed at O0 and O2. Every
external process has a deadline and retained evidence.

On 2026-11-13, the unfixed generation-2 compiler from
`ube compiler rebuild ee02eff8-ab8e-476f-83e3-5f7d9e2e0e0f` failed all three
assertion groups (exit 7) at O0/O2. Evidence:
`ube array declaration 2bfb23cc-8b58-461b-91e4-18dfd8e92e85`.
The fixed production UBE source passed with exit 0 at both levels, through
`ube native lowering 3387577d-5766-45d3-bb03-07747fafd178`; native evidence:
`ube array declaration 5007f770-e164-4309-a274-a07bd4ff0c1b`.

Qualified source SHA256 values:

- NativeStorage.bas: `7DA0AA6FD43DC2DE9039311574B77660A7DF32589881D8F6D7759C32EC4F8FA6`
- Probe.bas: `A4A0722D25E46E5817F176FEF1E1B7285602111541A8C2CE0411E1FAD0EE8A57`

The production correction adds only the early successful return for an
unbounded array when ReleaseExisting is true. Unpublished descriptor
initialization and fixed-array handling remain unchanged. This is a targeted
interleaving regression, not a claim that all array schedules are exhausted.
