# UBE Compiler v3

UBE Compiler v3 is the first public-release compiler target. It is developed
and compiled with the preserved, self-hosting UBE Compiler v2.

Release Preview 2 is the current verified baseline. It is a v2-buildable,
13-module compiler front end with native and VB6-compatible source-envelope
validation, nested conditional compilation, complete UBE 1.0 tokenization,
stable byte and line locations, bounded recovery, and deterministic token
serialization. It validates and lexes the `UBECore` source-library project but
intentionally does not parse the resulting token stream yet.

The bootstrap harness builds RP2 with both preserved v2 stages, compares their
LLVM IR, links and executes the result, runs positive and controlled-failure
fixtures, and writes `bootstrap/out/v3-rp2-build-manifest.json` with the exact
compiler, source, library, target, tool, and artifact identities.

The RP2 commands are:

```text
ube-v3-rp2 <project.UBE> <target-triple>
ube-v3-rp2 --dump-tokens <project.UBE> <target-triple>
```

The first supported target description is `x86_64-w64-windows-gnu`. RP3 adds
the owned syntax representation and complete parser.

Authoritative inputs:

- [`../../lang-doc/v3-language-definition.md`](../../lang-doc/v3-language-definition.md)
  records the approved and frozen UBE 1.0 language contract.
- [`DESIGN.md`](DESIGN.md) defines the compiler/library/platform boundaries.
- [`ROADMAP.md`](ROADMAP.md) is the resumable implementation checklist.
- [`../UBE_Compiler_v2/V3_BOOTSTRAP_CONTRACT.md`](../UBE_Compiler_v2/V3_BOOTSTRAP_CONTRACT.md)
  defines the subset available while v2 builds the initial v3 compiler.

Generated IR, objects, executables, logs, and comparison artifacts belong in
`bootstrap/out/`, never in this directory.
