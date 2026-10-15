# UBE Compiler v2

UBE Compiler v2 is the transitional structured, self-hosting compiler. Its
architecture and bootstrap constraints are defined in `DESIGN.md`; status and
next actions are tracked in `../Progress.md` and `../Roadmap.md`.

V2 is self-hosting for its checked-in Bootstrap Profile source.
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
using this generation. Classes, project structures, and other advanced
language/product features are reserved for v3 unless they become strictly
necessary to build it. Once the transition gates in `BOOTSTRAP.md` pass, v2 is
preserved as a stable compiler generation.
The exact source and project subset available to the initial v3 implementation
is frozen in `V3_BOOTSTRAP_CONTRACT.md`.

Run its automated build and acceptance checks from the repository root:

```powershell
./bootstrap/build.ps1
```

Generated artifacts belong in `bootstrap/out/`, not in this directory.
