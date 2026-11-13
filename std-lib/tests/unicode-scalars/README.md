# Unicode scalar codec gate

From the repository root:

```powershell
rtk proxy powershell -NoProfile -File std-lib/tests/unicode-scalars/check.ps1 -CompilerExe <compiler.exe>
```

Run once with the VB6 bootstrap and once with an actual UBE-written compiler
whose matching llvm assets are beside it. Each run compiles the same ordinary
portable Utf8 module and probe at O0/O2, requires deterministic repeated LLVM,
and executes 35 independently authored vector/malformed/bounds/publication
groups. Failure outputs and destination sentinels must remain unchanged;
old Err survives success and normal Boolean rejection. Nonzero lower bounds
produce the existing Err 9 behavior.

The probe then encodes and decodes all 1,112,064 Unicode scalar values,
excluding only surrogates, and writes canonical bytes through bounded file-I/O
chunks. A separate .NET UTF8Encoding oracle constructs the expected file;
comparison checks every byte, not just length or self-consistent round trips.
Changing the input scalar while keeping the expected vector must fail exactly
case 3. UTF-8 includes embedded zero and noncharacters; no locale or Unicode
normalization is involved.

Source ledgers, compiler hash, LLVM, native outputs and child logs are retained
under the printed temporary directory. This gate qualifies counted scalar
codecs, not builtin String storage or a garbage collector. Exact signature,
ownership and error rules are in [UNICODE-SCALARS.md](../../UNICODE-SCALARS.md).

Initial O0/O2 passes were recorded in `ube unicode scalars
0328aeaf-0877-48e1-aaef-ecaea25c9ec5` (bootstrap 79867c1f) and
`ube unicode scalars 81711ce1-1541-41eb-af89-b7dfc0106825` (actual UBE compiler).
After the final Mod grammar correction, the same gate passed again with
bootstrap cf7c9be7 in `ube unicode scalars f621e0e5-196e-4e61-9ac2-adfa0456a7da`
and the final UBE compiler in
`ube unicode scalars 93bbd1ea-ca54-4058-9257-dd3572c2800e`.
Final integrated build evidence is recorded in `compiler/Progress.md`.
