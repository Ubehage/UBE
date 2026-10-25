# Compiler v3 seed and production split

**Decision:** use a v2-buildable sequential seed compiler rather than adding a
compiler-private worker ABI or RP7 threading facilities to Compiler v2.

## Trust chain

The permanent Compiler v3 bootstrap chain is:

```text
stage zero -> preserved Compiler v2 -> sequential v3 seed
           -> v3 production stage one -> production stage two
           -> production stage three
```

Compiler v2 builds `UBE_Compiler_v3_seed.UBE` twice, through its independently
verified stage-one and stage-two executables. Their seed LLVM must be
byte-identical. The linked seed then builds `UBE_Compiler_v3.UBE` without using
a pre-existing production Compiler v3 binary. The resulting production
compiler rebuilds itself twice; production stage-two and stage-three LLVM and
normalized objects must satisfy the existing fixed-point policy.

The stable seed identity is `ube-v3-sequential-seed-1`. Its reproducible
identity record consists of that name, the seed-manifest SHA-256, its ordered
source hashes, the byte-identical v2-produced seed LLVM SHA-256, and the linked
seed executable SHA-256. The initial executor identity is
`ube-v3-sequential-executor-1`; it always records requested and effective job
counts of one.

## Dependency boundary

The seed manifest contains only source accepted by the preserved Compiler v2.
It identifies the sequential compiler used to emit production LLVM, is a
permanent clean-build input, and must remain v2-buildable.

During Phase 1 the seed and production manifests intentionally share the
existing sequential modules. Later parallel-only executor, worker, and
production-entry modules belong only to `UBE_Compiler_v3.UBE`. Shared modules
must remain valid Bootstrap Profile source and cannot depend on a
production-only module. If the production driver needs a worker-aware entry
point, it receives a separate production module; the seed's sequential entry
point is not replaced or taught threading syntax.

The seed may compile production-only modules because it implements the frozen
UBE 1.0 language. The seed itself does not use those facilities. This boundary
keeps ordinary language growth out of Compiler v2 and makes every added
production-only dependency visible as a manifest difference.

## Recorded execution metadata

`bootstrap/out/v3-beta1-build-manifest.json` records both manifests and their
hashes, the seed and production artifacts, executor identity, requested and
effective job counts, and the measured sequential phase timings. Timing fields
are evidence, not reproducibility inputs, and may vary between runs. Compiler
artifacts and semantic output remain subject to deterministic comparison.
