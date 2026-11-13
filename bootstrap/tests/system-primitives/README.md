# Counted system input and standard streams

These gates qualify the two OS dependencies used by the runnable compiler's
command driver. Command parsing and diagnostic-progress loops remain ordinary
UBE library code. They do not establish a complete driver or self-hosting.

`System.TryReadCommandLine(ByRef Destination() As Byte, ByRef Count As Long,
ByRef Failure As Long) As Boolean` copies the raw command line as strict UTF-8,
without its terminator, into caller-provided array capacity. Windows UTF-16
input is bounded to 32,766 nonterminator code units; UTF-8 output is bounded
to 131,072 bytes. The first byte goes to the array's logical lower bound.
Insufficient capacity, invalid Unicode, failed conversion, allocation failure
and exhausted quota preserve every destination byte and the old Count.
Success sets Failure to zero and preserves sticky Err. Parsing is not a target
primitive.

`System.TryWriteStandard(ByVal Stream As Long, ByRef Source() As Byte,
ByVal Start As Long, ByVal Count As Long, ByRef Written As Long,
ByRef Failure As Long) As Boolean` writes a relative byte span to stdout (1)
or stderr (2), in chunks of at most 65,536 bytes. It returns usable Boolean
status rather than FAIL. Written is zeroed after output-alias validation;
valid OS-reported partial progress is published even if the write reports
failure, matching the existing File.TryWrite contract. Impossible progress is
rejected without publishing it. A zero-length write still validates the
stream and inherited handle. Neither primitive closes inherited handles.

Both reject overlapping scalar outputs and outputs overlapping their byte
array descriptor or payload before mutation. Failure codes are 1 for invalid
request/capacity/Unicode, 3 for allocation, 5 for failed command-line conversion
or acquisition, and 15 for failed stream output. Err is 5, 7 or 57 respectively;
an invalid output alias records Err 5 without writing an aliased Failure cell.
Command-line conversion uses 131,072 bytes of scratch charged as 135,168 bytes;
stream packing uses 65,536 bytes charged as 69,632 bytes. Scratch uses the
existing caller-context allocator/retry/quota and is dropped on every exit.
Disposal assertions establish cleanup for the tested cases; these sequential
gates do not establish final-compiler concurrency.

Run the source gate, which builds the VB6 bootstrap if omitted:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/system-primitives/check.ps1 -BootstrapExe <binary>
rtk proxy powershell -NoProfile -File bootstrap/tests/system-primitives/fault-check.ps1 -BootstrapExe <binary>
```

The source gate checks actual O0/O2 native execution, exact raw Unicode and
quoted command-line bytes, stdout/stderr separation, nonzero lower bounds,
empty/insufficient capacity, aliases, range refusal and sticky error behavior.
The fault gate checks 18 cases at both optimization levels: valid command-line
conversion, invalid surrogate, null input, failed second conversion,
allocation and retry, quota refusal, output aliases, zero/short/impossible/
failed-progress writes, absent standard handle, write allocation and retry,
and ordinary StandardStreams loops across the 65,536-byte boundary.
Every fault case asserts result, byte/count preservation or confirmed progress,
Failure, Err, expected allocation/write call count, successful context disposal
and zero remaining live blocks. Only named target wrappers are replaced.

The native-lowering gate separately compiles the same source probe through the
UBE frontend and emitter, executes both optimization levels, and requires the
changed-source negative control to return exact exit 3. The semantic-storage
gate includes exact new role identities and rejected result/mode/element types.
The formatter gate checks every current catalog entry and generated-byte parity.

The reviewed import set gains only GetCommandLineW, GetStdHandle and
WideCharToMultiByte from kernel32. NativeMemory.ps1 and the production VB6
backend include these in their LLVM-generated import archives. Runtime source
parity remains enforced by bootstrap/tools/runtime-text.ps1; no new external
runtime or dependency is introduced.

Recorded focused evidence (2026-11-13):

- Binary: `C:\Users\Ubehage\AppData\Local\Temp\ube system primitives 74f4f9c9-eb02-4e20-a63e-871e3d04c435\build\UBE-Bootstrap.exe`.
- Source gate passed O0/O2: `ube system primitives c31b8269-3968-446c-bd6b-1bd9f7e704c5` under the same Temp directory.
- All 36 fault cases passed: `ube system primitives 496bb53c-1e66-4bd2-8af5-78756be305b3`.
- Broader UBE emitter and semantic gate status belongs in compiler/Progress.md.
