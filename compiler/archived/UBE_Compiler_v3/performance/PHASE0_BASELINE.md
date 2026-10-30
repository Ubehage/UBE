# Beta 1 Phase 0 sequential baseline

Measured 2026-10-25 on the completed RP8 compiler plus the Phase 0
instrumentation and lookup repairs. This is a performance observation, not a
portable time limit or release promise.

## Measurement contract

- Host: Windows 10.0.26300 x64, AMD Ryzen 9 3950X (16 cores, 32 logical
  processors), 34,267,918,336 bytes physical memory.
- Compiler: self-built Compiler v3, SHA-256
  `A0C65CD948279CE27257C1022B3BFFA73F4E47EA9955F6130D437A92387F837F`.
- Target: `x86_64-w64-windows-gnu`; requested/effective jobs: `1`/`1`.
- Tools: LLVM/Clang 23.1.3 and MinGW-w64 GCC 16.2.0.
- Harness: `bootstrap/tools/measure-v3-performance.ps1`, three runs per
  workload. Every repetition had to emit the same LLVM SHA-256.
- Values below are field-wise medians. Wall-time runs for self-compilation were
  654,872 ms, 637,259 ms, and 640,351 ms. The complete raw record is generated
  as `bootstrap/out/v3-phase0-final-baseline.json`.

## Resource and size baseline

| Workload | Wall ms | CPU ms | Peak KiB | Sources | Tokens | Syntax nodes | Symbols | Expressions |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Compiler v3 self-build | 640,351 | 637,906 | 1,068,956 | 40 | 268,964 | 1,124,461 | 5,617 | 29,890 |
| UBECore | 4,771 | 4,734 | 64,792 | 16 | 5,703 | 15,807 | 296 | 267 |
| 32-source synthetic | 1,115 | 1,109 | 33,864 | 32 | 1,694 | 3,846 | 97 | 34 |
| 64-source synthetic | 2,229 | 2,203 | 46,296 | 64 | 3,358 | 7,590 | 193 | 66 |
| 128-source synthetic | 4,625 | 4,593 | 71,172 | 128 | 6,686 | 15,078 | 385 | 130 |
| 128-procedure synthetic | 3,571 | 3,562 | 72,560 | 1 | 4,528 | 11,905 | 258 | 130 |
| 256-procedure synthetic | 7,210 | 7,141 | 130,908 | 1 | 9,008 | 23,681 | 514 | 258 |
| 512-procedure synthetic | 14,935 | 14,906 | 267,364 | 1 | 17,968 | 47,233 | 1,026 | 514 |

## Median phase time

| Workload | Front end ms | Parse ms | Semantics ms | IR lower ms | IR verify ms | LLVM ms |
|---|---:|---:|---:|---:|---:|---:|
| Compiler v3 self-build | 42,424 | 37,849 | 154,161 | 110,302 | 108,214 | 184,393 |
| UBECore | 926 | 567 | 1,752 | 691 | 28 | 691 |
| 32-source synthetic | 259 | 119 | 371 | 120 | 2 | 176 |
| 64-source synthetic | 517 | 235 | 738 | 235 | 7 | 359 |
| 128-source synthetic | 1,027 | 468 | 1,492 | 473 | 20 | 782 |
| 128-procedure synthetic | 758 | 387 | 1,177 | 467 | 20 | 696 |
| 256-procedure synthetic | 1,520 | 768 | 2,365 | 940 | 65 | 1,450 |
| 512-procedure synthetic | 3,099 | 1,550 | 4,776 | 1,871 | 233 | 3,154 |

The 32/64/128-source and 128/256/512-procedure series now scale approximately
linearly. LLVM emission is the largest self-build phase; semantics, IR
lowering, and IR verification are also substantial. The source front end plus
parser accounts for about 80 seconds and remains the first parallel slice
because source files form the earliest safe independent work boundary.

## Bottleneck repairs

The initial 512-procedure run took 34,840 ms, including 7,644 ms in semantics
and 18,741 ms in IR lowering. Two avoidable lookup patterns caused the
superlinear curve:

1. duplicate-declaration checks linearly rescanned every prior declaration in
   the same scope;
2. repeated local names shared a global IR name bucket, and each lookup walked
   every same-named symbol merely to rule out unrelated owners and default
   forms.

The semantic pass now uses a bounded scope-and-folded-name hash index. IR
lowering now has stable owner-to-child and default-form indexes and searches
newest storage first. The final 512-procedure run is 14,935 ms, with 4,776 ms
in semantics and 1,871 ms in IR lowering. LLVM hashes remained identical
across every repetition.

## Input and output identities

| Workload | Input-set SHA-256 | LLVM SHA-256 |
|---|---|---|
| Compiler v3 | `987F0B55D4A65E5ED2A6C405ABB331E5CD87B8B6248FBD0FA28C75466450925A` | `2BEF942837A1C95B46F8EAFAE1D445665C7CC1FBE4E8C57A18AF3C8E35845687` |
| UBECore | `EC1D3D23F19E5DED886305AE38CE328970F0A313F21861842F6BA5D4112547EF` | `31E77BC5F66A0599C6BA05BD39F96FAE56B43FEB9F7F5D2781B0370F47152728` |
| 32 sources | `CF72549768E257F88959878A6EB9568C215A79549A525B93E2D70B93CAD727C7` | `6870A31B7434420A39D049FFA10191725E45E9194D3CBB0C011848936A4CAC37` |
| 64 sources | `8DB8CA8DF984967126E04ED350CDE1CA70E1D208DF310D9EEA70747011D6AABD` | `7142AC4A2E904A8B00140F02118BD529A1A2EFA2B8F99C7AEF3E29B1E47E2CE2` |
| 128 sources | `7C75B5CA2F7B7F0BC8256A29A446DCF5C04715847F754B981346CC72B42BDC48` | `B1614C5A8E029B44F8C5D8ECFE0491A25E9664A6F050AE03192AEE1B212DC81C` |
| 128 procedures | `A324BFE9627BA31FE5F8E72441823FD4DB8CF1CE61050FEB1EB721ADFB262D15` | `64D92831F2350E284A9981DAE4685327F1570B040F505CE65AEF25D4D7AD8CBF` |
| 256 procedures | `DB1B97C0589521F1F0D7822558C6C70C2FA15D415CE479A3D0763DDB77ECDE81` | `B62B873C9B8E28C76779503F9021B584B985DD7FE8AD2896FD88949170BC91CD` |
| 512 procedures | `A71D71A78E1242B69BFBDFCF4E490F717964DA599AA62201DBF8BE1133E6E1D4` | `62F1874065F9EB8EEFC428324B2D67A02824883CD2738D5A8CD0B0F0EC988A1D` |
