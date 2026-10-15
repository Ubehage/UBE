# UBE version and compatibility identities

**Status:** Compiler v3 RP1 compatibility baseline

UBE versions several independent contracts. A compiler generation, language
version, project format, intrinsic ABI, and source-library release are not the
same version and must never be inferred from one another.

## Version fields

| Contract | RP1 identity | Compatibility rule |
|---|---|---|
| Compiler generation | `3` | Identifies the preserved compiler source architecture. |
| Compiler preview | `RP1` | Identifies a verified development capability set; it is not a language version. |
| Language | `1.0` | Source semantics follow the frozen UBE 1.0 specification. |
| Project format | `UBE-Project 1` | Readers reject unsupported format integers. |
| Core package | `UBECore` | Canonical compiler-selected core-library package and source qualifier. |
| Intrinsic ABI | `ube-intrinsic-abi-1` | The major identifier must match exactly. No intrinsic is assumed by name alone. |
| Core library | `0.1.0-rp1` | Semantic version for the RP1 project boundary; it exposes no public API yet. |

RP1 records these identities in its generated build manifest. Later compiled
library artifacts must additionally record the target triple, data layout,
object format, compiler identity, public-interface hash, and hashes of every
linked intrinsic or platform object.

## Library dependency compatibility

UBE uses both semantic versions and exact public-interface hashes:

- semantic versions describe the library author's compatibility promise;
- a canonical SHA-256 public-interface hash identifies the exact exported
  declarations, calling contracts, type layouts, and required intrinsic ABI;
- source-project references are reanalyzed and rebuilt, so their interface
  hash is produced as part of that build; and
- a compiled dependency is accepted only when its declared semantic-version
  requirement is satisfied, its public-interface hash matches the interface
  used to compile the consumer, its intrinsic ABI major is exact, and its
  target/ABI metadata is compatible.

The canonical interface serialization and compiled-library container remain
future implementation work. Until they are frozen, UBE 1.0 consumes library
references from source `.UBE` manifests and must not invent or trust a native
binary package format.

## Change rules

- Adding or removing a public declaration changes the interface hash.
- Changing a public signature, layout, calling convention, ownership rule, or
  failure contract changes the interface hash and normally requires a semantic
  version change.
- Compiler-internal changes do not change the language or library version
  unless they change a documented contract.
- A preview may use only the exact source-library slice recorded by its build.
- Metadata that is absent, malformed, unsupported, or contradictory is a
  controlled diagnostic, never a reason to guess compatibility.
