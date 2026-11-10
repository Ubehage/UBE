# Source-sized storage acceptance gate

Run from the repository root:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File bootstrap/tests/source-storage/check.ps1 -BootstrapExe "path/to/UBE-Bootstrap.exe"
```

Omitting `-BootstrapExe` builds the VB6 bootstrap. The gate uses installed Clang/lld, bounded hidden children, AMD64 PE checks, and retained temporary evidence.

The 16 checks run at O0 and O2. Production source and allocation/copy logic remain unchanged; only named target wrappers are replaced with test observers.

- Patterned 4,097-, 65,536-, 65,537- and 1,048,576-byte files round-trip through ordinary FileBytes policy. Independent SHA-256 comparisons verify output; native call and confirmed-byte counts are asserted.
- Real short reads/writes capped at 32,767 bytes verify progress across chunks.
- Direct 65,537-byte requests are rejected before OS transfer. Complete 65,536-byte requests preserve a trailing sentinel. A large array copy remains independent after mutation.
- A 1,048,577-byte file is rejected before reading payload or replacing prior bytes, even when the caller requests a larger maximum.
- A 65,536-element array of 128-cell records requires 64 MiB of payload plus its header and is rejected before any target allocation. Excessive element counts likewise preserve old values; an admitted retry works.

Every case requires successful context disposal and zero live allocations and file handles. This gate does not qualify larger files, managed record fields, concurrent execution, or a frozen external array ABI.

The dynamic element and whole-source byte limit is 1,048,576. Native packing is bounded to 65,536 bytes; each open file owns a 65,536-byte scratch payload charged as 69,632 bytes including header/page rounding. Paths remain bounded to 4,096 UTF-8 bytes. The 64 MiB allocation budget, 128-cell native frame/record limits, and 65,536-cell fixed module context limit remain unchanged.

The final 16-check run passed with the rebuilt bootstrap. Evidence: `ube source storage 2d484b1d-fb3e-41ca-9eb0-e6c0cb074333` under the Windows temporary directory.
