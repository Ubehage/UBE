# UBE Compiler v3

UBE Compiler v3 is the first public-release compiler target. It is developed
and compiled with the preserved, self-hosting UBE Compiler v2.

Release Preview 4 is the current verified baseline. It is a v2-buildable,
25-module compiler front end with the complete RP3 parser plus bounded package,
module, member, procedure, block, and label scopes; Unicode-folded symbols;
semantic type records; declaration and control-contract validation; expression
typing; and deterministic semantic serialization. It analyzes itself and the
`UBECore` source-library project while intentionally using no public library
APIs yet.

The bootstrap harness builds RP4 with both preserved v2 stages, compares their
LLVM IR, links and executes the result, runs positive and controlled-failure
fixtures, and writes `bootstrap/out/v3-rp4-build-manifest.json` with the exact
compiler, source, library, target, tool, and artifact identities.

The RP4 commands are:

```text
ube-v3-rp4 <project.UBE> <target-triple>
ube-v3-rp4 --dump-tokens <project.UBE> <target-triple>
ube-v3-rp4 --dump-syntax <project.UBE> <target-triple>
ube-v3-rp4 --dump-semantics <project.UBE> <target-triple>
```

The first supported target description is `x86_64-w64-windows-gnu`. RP5 adds
typed target-independent IR, verified LLVM lowering, and the first v3
self-build gate.

Authoritative inputs:

- [`../../lang-doc/v3-language-definition.md`](../../lang-doc/v3-language-definition.md)
  records the approved and frozen UBE 1.0 language contract.
- [`DESIGN.md`](DESIGN.md) defines the compiler/library/platform boundaries.
- [`ROADMAP.md`](ROADMAP.md) is the resumable implementation checklist.
- [`../UBE_Compiler_v2/V3_BOOTSTRAP_CONTRACT.md`](../UBE_Compiler_v2/V3_BOOTSTRAP_CONTRACT.md)
  defines the subset available while v2 builds the initial v3 compiler.

Generated IR, objects, logs, and intermediate executables belong in
`bootstrap/out/`, never in this directory. Each completed preview's final
verified executable is preserved separately in
[`../release-previews/`](../release-previews/README.md).
