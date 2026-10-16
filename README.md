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

> **Current milestone:** Compiler v3 Release Preview 4 is complete. Development
> is moving into RP5: typed IR, native lowering, and v3 self-hosting.

<ul>
  <li><strong>UBE 1.0</strong><br><sub>The language definition, grammar, compiler boundaries, and staged development plan are frozen.</sub></li>
  <li><strong>Compiler v2</strong><br><sub>The stable transitional compiler is self-hosting, supports multiple modules and cross-module references, and builds Compiler v3.</sub></li>
  <li><strong>Compiler v3 RP4</strong><br><sub>The verified 25-module front end adds bounded scopes, Unicode-folded symbols, semantic types, expression typing, stable diagnostics, and declaration, entry-point, call, label, and control-flow checks to the complete RP3 parser.</sub></li>
  <li><strong>UBECore</strong><br><sub>The separate source-library project has its permanent package identity and is analyzed by RP4. No public library APIs are required by the compiler yet.</sub></li>
  <li><strong>Documentation</strong><br><sub>The offline manual and expandable A-Z language reference are available, with planned behavior distinguished from verified behavior.</sub></li>
</ul>

UBE remains pre-release software and is not yet ready for production use.

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
v2 self-hosting chain, Compiler v3 RP4 and its complete front-end corpus,
the `UBECore` project boundary, and the conformance fixtures. See
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

UBE is free and open-source. Donations are appreciated, and will help progress
faster. You can support the project through
[PayPal](https://www.paypal.me/Ubehage).
