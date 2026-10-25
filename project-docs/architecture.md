# Compiler and library architecture

**Status:** project direction for frozen UBE 1.0

UBE is intended to become self-hosting. The complete system is divided into
three layers with deliberately narrow boundaries.

## Compiler

The final compiler is written in UBE and produces 64-bit LLVM output. It owns
parsing, semantic analysis, optimization-independent lowering, diagnostics,
and object generation. Its source stays within a documented **UBE Bootstrap
Profile** so that rebuilding it never silently depends on every optional
language or runtime feature.

Normal builds begin with a plain-text `.UBE` project manifest; `.UBG` project
groups orchestrate multiple such builds. The project loader resolves the
ordered `.bas`, `.frm`, `.cls`, and `.ctl` source list and explicitly listed
`.UBR` binary sidecars before parsing. It validates paths, sizes, resource
container bounds, and duplicate inputs and reports controlled diagnostics for
every invalid build input. See
[`../lang-doc/project-files.md`](../lang-doc/project-files.md).

Bootstrapping proceeds in reproducible stages:

1. A small stage-zero compiler, written in an existing implementation language,
   builds the preserved Compiler v2.
2. Independently verified Compiler v2 stages compile the dedicated sequential
   Compiler v3 seed manifest and must emit byte-identical LLVM.
3. The linked seed compiles the production Compiler v3 manifest without using
   a pre-existing production binary.
4. The resulting production compiler rebuilds itself twice. Production stages
   one, two, and three must emit byte-identical LLVM, and normalized stage-two
   and stage-three objects must satisfy the documented comparison policy.

The seed stays inside the Compiler v2 Bootstrap Profile. Parallel-only modules
belong to the production manifest, keeping thread-aware implementation growth
out of the preserved transitional compiler.

Stage zero remains archived and buildable after self-hosting so the project can
always be rebuilt without trusting a pre-existing UBE binary.

The initial stage-zero host toolchain is GCC 16.2 for the C++ compiler and
runtime object, plus LLVM/Clang 23 for validating, optimizing, and linking the
generated LLVM IR for the x86-64 Windows GNU target. These versions are the
first verified baseline, not a permanent restriction on later supported hosts.

## Linked program substrate

UBE has no separate installed runtime, virtual machine, or runtime process.
Each native output contains the program-support code it needs. The linked
substrate contains only facilities that cannot reasonably be ordinary UBE:
process entry, allocation hooks, platform ABI adapters, unwinding primitives,
and the implementations behind declared compiler intrinsics. Its internal ABI
is versioned and kept small enough to audit, and unused support should be
removed during linking.

The linked support never owns a default error-dialog policy. Recoverable operations
return a neutral value and update thread-local error state; generated code
implements explicit `On Error` control flow when requested. Unrecoverable
conditions use a controlled, noninteractive failure path. No runtime failure
may expose a raw object address, corrupt state, or invoke an automatic message
box.

For an executable, the platform-specific process entry adapter invokes the
project's sole language-level `Main`. A `Sub Main()` produces exit code zero;
a `Function Main() As Long` supplies the process exit code. Optional startup
form loading is compiler-generated behavior on the `Main` startup path and does
not introduce another language-level entry point.

Complex datatype behavior should not be hidden in LLVM lowering merely because
it is performance-sensitive. Where useful, an operation can be implemented in
UBE using a few primitive intrinsics and marked `Inline` or `ForceInline`.

## Standard library

The standard library is separately compiled UBE source. Familiar names such as
`Mid$`, `Left$`, conversions, string algorithms, containers, file helpers, and
most datatype operations live here. They are not keywords and are not embedded
in the parser.

Selected compatibility built-ins deliberately accept broadly typed values and
perform specified conversions despite UBE's otherwise strict static typing.
Objects accepted by such APIs cross the boundary as opaque runtime handles,
never exposed pointers. This is an explicit library API contract rather than a
language-wide relaxation of type checking.

The intended repository layout, as implementation begins, is:

```text
compiler/       Self-hosting UBE compiler
bootstrap/      Stage-zero compiler and reproducible bootstrap scripts
runtime/        Minimal target and ABI substrate
source-library/ Standard source library written in UBE
docs/           Public offline language manual
lang-doc/       Normative language specification and grammar
project-docs/   Architecture and project-wide roadmaps
tests/          Syntax, semantics, conformance, and bootstrap tests
```

## Dependency and portability policy

UBE is designed to become a portable, self-contained native toolchain. The
compiler, runtime, standard library, debugger, IDE, documentation, build
orchestration, and release tools should use repository-owned UBE source and
platform facilities wherever practical. A supported checkout must not depend
on npm, Node.js build tooling, another JavaScript package manager, runtime CDNs,
or code downloaded during build or first use.

Files required to build, run, test, document, or debug UBE are checked into the
repository or generated deterministically from checked-in inputs by documented
UBE/bootstrap tools. Standards-based browser HTML, CSS, and JavaScript are
allowed when stored directly in the repository and used without a package
manager or remote runtime assets.

The current GCC, LLVM/Clang, MinGW-w64, and PowerShell requirements are explicit
stage-zero host prerequisites. They are temporary bootstrap boundaries, not a
general dependency model. Their versions and provenance must be recorded, and
the project should move toward portable toolchain bundles that contain the
verified prerequisites for each supported host until the self-hosting compiler
can replace them.

If a new third-party component is genuinely unavoidable, it requires explicit
owner approval. The repository must vendor the exact reviewed source or binary,
record its version, license, provenance, integrity hash, supported hosts, and
replacement/removal plan, and fail with a controlled diagnostic when the
component is absent or corrupt. Transitive downloads and undeclared system
dependencies are not permitted.

## Trust and reproducibility

The independent compiler, language, project-format, intrinsic-ABI, and
source-library identities and their compatibility rules are defined in
[`versioning.md`](versioning.md). Builds record these identities explicitly;
they are never inferred from one shared version number.

A bootstrap build records source hashes, compiler versions, LLVM version,
target triple, and all flags. Builds should be deterministic. If final native
binaries cannot initially compare byte-for-byte because of object metadata,
the project compares canonicalized LLVM IR and documents every ignored field.

Compiler intrinsics are declarations, not secret library substitutions. Each
intrinsic must document its signature, effects, target availability, and
fallback behavior. An unsupported intrinsic is a compile-time error rather
than an implicit external call.
