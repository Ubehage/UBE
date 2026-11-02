# UBE project documentation

This directory contains internal project-level documentation:

- [architecture.md](architecture.md) describes compiler, runtime, standard
  library, debugger, IDE, and repository boundaries.
- [Roadmap.md](Roadmap.md) tracks the repository-wide development sequence.
- [Development-Plan.md](Development-Plan.md) preserves the fresh compiler/library
  execution order and ownership/naming boundaries. Bounded concurrency and
  project/parallel frontend input are qualified. The bounded semantic checker
  is qualified for its approved scalar/native MODULE scope. Exact current
  scope is in [SEMANTIC-EVIDENCE.md](../compiler/UBE_Compiler_v3/SEMANTIC-EVIDENCE.md);
  the next native-executable row still requires reviewed lowering/backend/tool
  contracts.

- [versioning.md](versioning.md) defines the independent compiler, language,
  project-format, intrinsic-ABI, and source-library compatibility identities.
- [Project-Vision.md](Project-Vision.md) preserves the original internal
  project brief and early design commitments that previously occupied the root
  README.

Normative language documents live in [`../lang-doc/`](../lang-doc/README.md),
and the public language manual lives in [`../docs/`](../docs/README.md).
