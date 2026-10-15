# UBE Compiler v3

UBE Compiler v3 is the first public-release compiler target. It is developed
and compiled with the preserved, self-hosting UBE Compiler v2.

Release Preview 1 is the current verified baseline. It is a v2-buildable,
nine-module compiler shell with bounded diagnostics, UTF-8 source ownership,
`UBE-Project 1` validation, safe ordered source loading, centralized resource
limits, and separate host and target descriptions. It validates the `UBECore`
source-library project but intentionally does not parse UBE source yet.

The bootstrap harness builds RP1 with both preserved v2 stages, compares their
LLVM IR, links and executes the result, runs positive and controlled-failure
fixtures, and writes `bootstrap/out/v3-rp1-build-manifest.json` with the exact
compiler, source, library, target, tool, and artifact identities.

The RP1 diagnostic command is:

```text
ube-v3-rp1 <project.UBE> <target-triple>
```

The first supported target description is `x86_64-w64-windows-gnu`. RP2 adds
native source envelopes, complete tokenization, and conditional compilation.

Authoritative inputs:

- [`../../lang-doc/v3-language-definition.md`](../../lang-doc/v3-language-definition.md)
  records the approved and frozen UBE 1.0 language contract.
- [`DESIGN.md`](DESIGN.md) defines the compiler/library/platform boundaries.
- [`ROADMAP.md`](ROADMAP.md) is the resumable implementation checklist.
- [`../UBE_Compiler_v2/V3_BOOTSTRAP_CONTRACT.md`](../UBE_Compiler_v2/V3_BOOTSTRAP_CONTRACT.md)
  defines the subset available while v2 builds the initial v3 compiler.

Generated IR, objects, executables, logs, and comparison artifacts belong in
`bootstrap/out/`, never in this directory.
