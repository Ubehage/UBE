# Native semantic foundation gate

Run from the repository root:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-semantic-foundations.ps1 -RequireIntegrated
```

The default run requires ByteKeys, SignedIntegers, Utf8Encoding and StorageCapacity to be exact source inputs of the real UBECore Reference. The generated consumer includes the test classes, record arena, identifier cooking helper and entry points. It does not copy the generic Core modules into the consumer. The test arena calls `TryGetStorageCapacity`; the name helper delegates scalar encoding to `TryEncodeUtf8Scalar`.

Both accepted source-built compiler stages emit the same complete raw LLVM before test instrumentation. The native bridges check signatures and record layouts, preserve the original checked worker admission, and add observers only at defined test boundaries. Independent C expectations cover scalar arena contents, geometric storage/trim/publication, actual allocation and root failures, four actual UBE workers, retained immutable owners, bounded captures, zero source payload copies, signed-minimum decoding and checked arithmetic, scoped direct index queries, cleanup and safe unowned-borrow rejection. Deliberately corrupted values, counters, heap observations and source-copy behavior must be rejected.

`CONTRACT.md` freezes the arena and observer limits. `FINAL-SHAPE.md` supersedes its earlier worker shape with the final ByteKey record, direct order vector and partitioned lookups. Instrumentation observes all root counter mutations and both actual GC payload increment sites; it rejects changes to the full five-statement heap mutation inventory.

Each run writes `bootstrap/out/semantic-foundations/<id>/report.json`, including selection, manifest, source/tool identities, copied fixture/reference inputs, raw and adapted LLVM, generated private runtime, executables, commands, exact native output and assertions. `qualifiedFoundations` is true only for an intact, successful, integrated run of both suites. `-OnlySuite arena` and `-OnlySuite sharing` are focused diagnostics; `-RequireIntegrated:$false` with explicit module paths permits draft diagnostics and cannot qualify the final foundation. `-SelectionPath` and `-OutputRoot` select a cohort locator and separate evidence directory.

This gate qualifies components and immutable sharing. It does not qualify the semantic checker, compiler source-owner/catalog integration, a general scheduler or backend, and makes no speedup claim. Historical accepted793 evidence remains frozen under `bootstrap/out/shared-semantic-probes`; its reports are not the integrated Core result.
