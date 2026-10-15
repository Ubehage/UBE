# UBE — Work in Progress

**UBE** (Ube's Basic Experiment) is a new native, 64-bit programming language
and compiler inspired by classic Visual Basic 6.

UBE aims to retain the approachable syntax and productive workflow that made
classic Visual Basic popular, while providing explicit modern semantics,
native performance, lightweight program support linked into each executable,
and a fully 64-bit toolchain.

<p align="center">
  <img src="media/logo.png" alt="UBE — Ube's Basic Experiment. Visual Basic, but out of the Kindergarten." width="900">
</p>

<p align="center"><sub><em>Dreamed up by an idiot. Brought to life by AI.</em></sub></p>

## Vision

UBE keeps the readable syntax and direct workflow that made classic Basic easy
to learn and productive to use. It adds clearly defined modern behavior,
strict types, native threads, managed memory, portable libraries, and a fully
64-bit toolchain.

UBE programs should compile to small, fast native executables. The compiler and
standard library are intended to remain understandable, dependency-minimal,
and portable across supported operating systems.

The long-term goal is a complete native development system:

- the UBE language and optimizing compiler;
- a portable standard library written in UBE;
- source-level debugging;
- a responsive native IDE with the simplicity of the VB6 environment; and
- tools for building, testing, packaging, and maintaining UBE programs.

UBE does not use Tauri, Electron, or webview shells for its native tools.

## How UBE is being built

UBE is created by Ube, who defines the vision, product direction, and final
decisions. AI coding agents help turn that direction into specifications,
compiler code, tests, documentation, and project tooling.

The agents work inside repository-defined boundaries. Their work is reviewed
against the language specification, automated tests, preserved compiler
generations, and Ube's requirements. AI is used as an engineering tool; project
ownership and design authority remain with Ube.

## Project status

UBE is pre-release software and is not yet ready for production use.

The project has reached a verified self-hosting milestone. The preserved UBE
Compiler v2 can rebuild itself, compile ordered multi-module projects, and
resolve references between modules.

V2 is a stable transitional compiler used to build UBE Compiler v3. Version 3
is the first public-release target. Its UBE 1.0 language definition, compiler
boundaries, and staged development plan are now frozen.

Compiler v3 Release Preview 0 is complete. RP0 preserves the v2-buildable v3
scaffold and proves the generation boundary: both preserved v2 stages produce
byte-identical LLVM IR, the native scaffold links and runs, and the build
records reproducibility identities for its inputs and artifacts. RP0 is a
verified foundation, not yet a usable language compiler.

Development is moving into Release Preview 1, which replaces the placeholder
with a bounded multi-module compiler shell for diagnostics, source ownership,
project loading, and host/target configuration. Later previews add the full
front end, semantic analysis, verified IR, native output, managed memory,
objects, threading, events, and the separately built UBE source library.

The documentation website already provides an offline, browsable language
manual with an expandable A-Z reference. Planned behavior is labelled
separately from implemented and verified behavior.

## First public-release goals

- A stable UBE language definition and grammar.
- A self-hosting v3 compiler built with the preserved v2 compiler.
- Lightweight, optimized 64-bit native executables.
- A minimal compiler with runtime and standard-library functionality kept in a
  separate UBE source library.
- Multiple source modules with clear visibility and reference rules.
- Defined conversions, errors, lifetimes, garbage collection, and threading.
- Portable behavior with platform-specific features clearly identified.
- Complete offline language and library documentation.
- Useful diagnostics and the foundations required for source-level debugging.

## Building the current compiler

The current bootstrap build targets x86-64 Windows and requires PowerShell,
GCC/MinGW-w64, and LLVM/Clang. From the repository root, run:

```powershell
./bootstrap/build.ps1
```

The command builds and tests stage zero, preserved compiler generations, the
v2 self-hosting chain, the Compiler v3 RP0 scaffold, and the conformance
fixtures. See
[bootstrap/README.md](bootstrap/README.md) for prerequisites and details.

## Repository guide

- [docs/](docs/README.md) — public UBE language manual
- [lang-doc/](lang-doc/README.md) — normative language specification and grammar
- [project-docs/](project-docs/README.md) — architecture and development roadmap
- [compiler/](compiler/README.md) — preserved UBE compiler generations
- [source-library/](source-library/README.md) — separately built UBE source library
- [bootstrap/](bootstrap/README.md) — temporary stage-zero compiler and tests
- [Release-Requirements.md](Release-Requirements.md) — owner-defined release requirements
- [Workplan.md](Workplan.md) — current repository-wide work checkpoint

## License and credits

UBE is open-source software. See [LICENSE](LICENSE) for license terms and
[CONTRIBUTORS.md](CONTRIBUTORS.md) for project credits.

## Support development

UBE does not require payment and donations are strictly voluntary. If you want
to support further and faster development, you can donate through
[PayPal](https://www.paypal.me/Ubehage). Donations go directly toward continued
UBE development.
