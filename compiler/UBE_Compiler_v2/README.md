# UBE Compiler v2

UBE Compiler v2 is the transitional structured, self-hosting compiler. Its
architecture and bootstrap constraints are defined in `DESIGN.md`. The current
repair goal and bounded acceptance contract are in `FOUNDATION-PLAN.md`;
current-source results and limits are in `FOUNDATION-VERIFICATION.md`.

The maintained source-only gate tests self-hosting for its Bootstrap Profile source.
Stage zero builds stage one; stage one emits and links stage two; stage two
emits byte-identical LLVM IR when compiling the same `Main.bas`. Both stages
run the same positive and negative conformance cases. See `BOOTSTRAP.md` for
the exact trust chain and remaining limits.

V2 is not the production compiler. It loads ordered multi-source `.UBE`
manifests, compiles their supported declarations as one program, and resolves
types and procedures across modules. It also accepts a direct `.bas` input for
bootstrap diagnostics. Language coverage remains the documented Bootstrap
Profile.

V3 is UBE's first public-release target and must be developed and compiled
using this generation. The owner approved extending v2 as necessary for
bootstrap, including managed array/record prerequisites for fresh UBECore.
This retains the existing compiler architecture, with complete public-language
coverage belonging to v3. Qualified bootstrap snapshots are preserved by exact
source/artifact identities.
The exact source and project subset available to the initial v3 implementation
is frozen in `V3_BOOTSTRAP_CONTRACT.md`.

Build and check the bounded v2 tool from the repository root, offline:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1
```

The accepted executable and provenance are selected by
`bootstrap/out/v2/current.json`. Each build has its own output directory and
retains a complete success/failure manifest. Backup executables are unnecessary.

To compile a supported source/project into an executable using that accepted
tool and runtime:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/compile-v2.ps1 -Source compiler/UBE_Compiler_v2/tests/foundation/byte-array.bas -Output bootstrap/out/byte-array.exe
```

The helper checks accepted artifact/source hashes, preserves an existing output
on compilation/link failure and publishes the new executable only on success.
Direct compiler invocation still takes `<source.bas|project.UBE> <output.ll>`.

The tested subset includes Byte/Integer storage, checked integer conversions,
ordinary records and one-dimensional arrays. Independent Byte-array and
array-containing record copies, ByVal parameters, results, precise roots,
collection and recoverable allocation failures now pass focused tests through
both stages. Indices/counts remain signed Long in v2. Native-type syntax is
qualified separately for opaque Byte/Integer/Long values with explicit
Pack/Unpack bindings; see [the native proof](../../std-lib/tests/native-type/NATIVE-EVIDENCE.md).
The complete maintained gate now passes 501 grouped assertions, including ByteBuffer
functional/failure/cost/worker proofs, bounded direct Library references,
recoverable file input, source ingestion and scanner/Unicode native proofs.
Current identities are in
[scanner evidence](../UBE_Compiler_v3/SCANNER-EVIDENCE.md); the earlier
276-check managed snapshot is in [managed evidence](../../std-lib/MANAGED-STORAGE-EVIDENCE.md).
The full language, managed opaque representations and builtin String lifecycle
remain unqualified. Private bootstrap String operations keep their documented
limitations; Byte arrays preserve all byte values, including zero.

`bootstrap/build.ps1` is the historical full workflow, which also builds archived
compiler generations. It is not the bounded v2 command and recreates its entire
output directory. Generated artifacts belong in `bootstrap/out/`.
