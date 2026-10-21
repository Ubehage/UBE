# UBE — Work in Progress

**UBE** (Ube's Basic Experiment) is a new native, 64-bit programming language
and compiler inspired by classic Visual Basic 6.

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


## Frequently Asked Questions
<ul>
  <li><strong>Is UBE an attempt to create Visual Basic 7?</strong><br>
  <sub><strong>No. And it isn't trying to be.</strong><br>
  TwinBASIC is carrying the Visual Basic legacy forward, with a strong focus on compatibility with existing VB6 code.<br>
  UBE is a different experiment.<br>
  The idea behind UBE is simple: <i>What if we took a language designed for beginners and kept extending it until it could do virtually anything?</i><br>
  UBE takes inspiration from the simplicity, readability and accessibility of classic Visual Basic, but does not consider VB6-compatibility a design requirement.</sub></li>
  <br><li><strong>So, what exactly is UBE?</strong><br>
  <sub>UBE is an attempt to build a powerful, modern, general-purpose programming language around the original philosophy of BASIC: Programming should be understandable, approachable and enjoyable.<br>
  The goal is not to make a simpler language. It is to make advanced capabilities accessible through a simple language.<br>
  In other words, UBE aims to preserve VB's friendliness without preserving its historical limitations.</sub></li>
  <br><li><strong>What makes UBE different from Visual Basic 6?</strong><br>
  <sub>Several things. Both internally and in the language itself.<br>
  -<strong>A minimal compiler core.</strong> UBE's compiler is designed to understand only the essential building blocks of the language. Much of the higher-level functionality is implemented in a separate standard library.<br>
  -<strong>Extensible native types.</strong> UBE aims to allow developers to define their own native data types, including their memory representation and how values are initialized, accessed and destroyed.<br>
  -<strong>Modern compilation.</strong> UBE uses LLVM as its backend, allowing the compiler to target different architectures without requiring a separate code generator for each platform.<br>
  -<strong>String declaration, friendly conversions.</strong> Variables must be explicitly delcared and types are checked, but the runtime still supports convenient automatic conversions where they make sense.<br>
  -<strong>A different approach to runtime errors.</strong> Rather than interrupting execution for ordinary recoverable failures, UBE is design to return an invalid or default value and record error information for the programmer to inspect.</sub><br>
  <br><li><strong>Will UBE compile existing VB6 projects?</strong><br>
  <sub><strong>Yes. All valid VB6 code is intended to compile in UBE.</strong><br>
  UBE preserves VB6 syntax while deliberate reconsidering some of its underlying semantics, including error handling, type conversions, and other runtime behaviors.<br>
  This means existing VB6 code will compile without modification, but may behave different when executed.<br>
  <strong>If exact VB6 behavior is a requirement, TwinBASIC is likely the better choice for you.</strong></sub></li>
  <br><li><strong>Is UBE designed for beginners or experienced programmers?</strong><br>
  <sub><strong>Both.</strong><br>
  A beginner should be able to write a simple program without first understanding memory management, compiler architecture og complex type systems.<br>
  An experienced developer should be able to access those capabilities when needed.<br>
  Complexity is available, not mandatory.</sub></li>
  <br><li><strong>Is UBE ready for production use?</strong><br>
  <sub><strong>Not yet. UBE is under active development</strong></sub></li>
  <br><li><strong>Is UBE intended to replace Visual Basic, TwinBASIC or other programming languages?</strong><br>
  <sub><strong>No.</strong><br>
  UBE is not being developed to replace an existing language or win a popularity contest.</sub></li>
</ul>


## How UBE is being built
UBE is created by Ube, who defines the vision, product direction, and final
decisions. AI coding agents help turn that direction into specifications,
compiler code, tests, documentation, and project tooling.

The agents work inside repository-defined boundaries. Their work is reviewed
against the language specification, automated tests, preserved compiler
generations, and Ube's requirements. AI is used as an engineering tool; project
ownership and design authority remain with Ube.

## Project status

> **Current milestone:** Compiler v3 Release Preview 6 is complete. Development
> is moving into RP7: errors, threads, events, and component lifetime.

<ul>
  <li><strong>UBE 1.0</strong><br><sub>The language definition, grammar, compiler boundaries, and staged development plan are frozen.</sub></li>
  <li><strong>Compiler v2</strong><br><sub>The stable transitional compiler is self-hosting, supports multiple modules and cross-module references, and builds Compiler v3.</sub></li>
  <li><strong>Compiler v3 RP6</strong><br><sub>The self-hosting compiler now supports managed strings, arrays, recursive custom values, Variants, classes, interfaces, module lifecycle, referenced projects, tracing garbage collection, and the first frozen foreign-library ownership ABI.</sub></li>
  <li><strong>UBECore</strong><br><sub>The separate source-library project now contains documented modules for runtime intrinsics, conversions, strings, managed memory, Variants, and status helpers. Both compiler stages reproduce the exact seven-module slice.</sub></li>
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
v2 self-hosting chain, Compiler v3 RP6 and its complete inherited and managed
native corpora, the current `UBECore` source slice, collector probes, foreign
library ABI checks, and the conformance fixtures. See
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

## Community

Join the [UBE Discord](https://discord.gg/XZjSw6wxhR) to suggest ideas, report
bugs, and follow development.
