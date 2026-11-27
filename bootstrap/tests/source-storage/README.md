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
- Injected OS allocation failures preserve prior record and Byte arrays. Retry succeeds, including a Byte array above the former 1,048,576-element ceiling.

Every case requires successful context disposal and zero live allocations and file handles. This gate does not qualify larger files, managed record fields, concurrent execution, or a frozen external array ABI.

Dynamic element counts use their checked Long representation; storage availability
is determined by system resources. Native packing uses 65,536-byte chunks and
each open file owns a scratch payload whose header and page rounding are included
in accounting. This gate does not claim removal of unrelated compiler or path
representation limits.

The final 16-check run passed with the rebuilt bootstrap. Evidence: `ube source storage 2d484b1d-fb3e-41ca-9eb0-e6c0cb074333` under the Windows temporary directory.
