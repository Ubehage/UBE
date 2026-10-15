# UBE language definition

This directory contains UBE's normative and internal language documents:

- [language-spec.md](language-spec.md) is the frozen UBE 1.0 lexical and
  semantic specification targeted by Compiler v3.
- [grammar/ube.ebnf](grammar/ube.ebnf) is the frozen core grammar.
- [grammar/conditional-compilation.ebnf](grammar/conditional-compilation.ebnf)
  defines the directive pre-pass whose selected output is parsed by the core
  grammar.
- [project-files.md](project-files.md) defines native project and resource
  formats.
- [bootstrap-profile.md](bootstrap-profile.md) records the subset used to
  bootstrap the UBE-written compiler.
- [v3-language-definition.md](v3-language-definition.md) consolidates the
  approved expanded UBE 1.0 semantics and examples for Compiler v3.
- [v3-closure-audit.md](v3-closure-audit.md) tracks the remaining language and
  grammar decisions that must close before the UBE 1.0 candidate is frozen.
- [deferred-questions.md](deferred-questions.md) preserves choices that cannot
  inherit VB behavior without conflicting with portability or approved object
  semantics.
- [conversion-table.md](conversion-table.md) freezes UBE 1.0 implicit
  conversion relationships and failure behavior for Compiler v3.
- [managed-memory.md](managed-memory.md) defines precise roots, safe points,
  barriers, collection, finalization, and low-memory behavior.
- [foreign-abi.md](foreign-abi.md) defines generated exports, stable statuses,
  opaque ownership handles, and foreign-library validation.
- [threading.md](threading.md) defines shared access, happens-before ordering,
  synchronization classes, cancellation, limits, and orderly shutdown.
- [grammar/ube-v3-delta.md](grammar/ube-v3-delta.md) preserves the audit record
  for approved syntax changes incorporated into the frozen UBE 1.0 EBNF.
- [grammar/fixtures/](grammar/fixtures/README.md) contains the dependency-free
  source fixture corpus and its machine-readable expected outcomes.
- [tools/validate-grammar.ps1](tools/validate-grammar.ps1) checks the EBNF for
  duplicate definitions, undefined nonterminals, reachability, delimiter
  imbalance, and required productions/literals in both normative grammars.

The public language manual lives in [`../docs/`](../docs/README.md). Project
architecture and development roadmaps live in
[`../project-docs/`](../project-docs/README.md).
