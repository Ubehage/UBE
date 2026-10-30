# Fresh UBE Compiler v3 instructions

Read `README.md`, `DESIGN.md`, `Roadmap.md`, `Progress.md`, and the root
workplan before changing this project. The owner explicitly reused the v3
name on 2026-10-30 after archiving the previous v3/v4 implementations.

- This is a fresh implementation. Do not copy archived compiler modules,
  support implementations, layouts, hidden APIs or milestone machinery.
- Build reusable facilities in `../../std-lib/` under its contributor rules.
  The compiler owns language policy and irreducible mechanisms, not ordinary
  string, collection, conversion, file or concurrency algorithms.
- Prove the bounded bootstrap subset and library-defined native datatype
  mechanism before broad compiler scaffolding. Approval of the direction
  does not choose new syntax, layouts, hooks, intrinsic signatures or APIs.
- Follow the frozen UBE semantics. Propose and obtain the required decision
  before a mechanism changes observable language behavior.
- Every mutable arena/instance has an explicit owner. Shared inputs are
  immutable or follow an approved synchronization contract. Workers receive
  bounded work and private outputs; never restart whole compilations per task
  or create independent worker pools that escape the shared budget.
- Keep stable identities and merges independent of worker completion order.
  Measure actual work and copying before parallelizing a phase.
- Return controlled failures. Every crash fix needs a small synthetic
  regression; no compiler build is proof of correctness on its own.
- State allocation, copying, lifetime, failure, reentrancy and thread-safety
  contracts before using a facility. Release external resources on every path.
- Existing bootstrap tools are temporary executables used only for the tested
  subset. Preserve their source/artifact identities and unsupported boundaries.
- Add a production manifest only when its prerequisites are proven; name it
  `UBE_Compiler_v3.UBE` and use `Main.bas` when implementation starts.
- Keep generated output separate from source and from historical artifacts.
  No executable from the archive is a release of this compiler.
- Keep roadmap/progress evidence current. No new dependencies, language
  features, architectures or intrinsic sets are approved implicitly.
