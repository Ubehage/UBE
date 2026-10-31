# UBE — Work in Progress

**UBE** is a new native, 64-bit programming language and compiler inspired by classic Visual Basic 6.

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
- Is UBE an attempt to create Visual Basic 7?<br>
  **No.**<br>
  TwinBASIC is carrying the Visual Basic legacy forward, with a strong focus on compatibility with existing VB6 code.<br>
  UBE is a different experiment.<br>
  The idea behind UBE is simple: <i>What if we took a language designed for beginners and kept extending it until it could do virtually anything?</i><br>
  UBE takes inspiration from the simplicity, readability and accessibility of classic Visual Basic, but does not consider VB6 Runtime-compatibility a design requirement.<br>
- So, what exactly is UBE?<br>
  UBE is an attempt to build a powerful, modern, general-purpose programming language around the original philosophy of BASIC: Programming should be understandable, approachable and enjoyable.<br>
  The goal is not to make a simpler language. It is to make advanced capabilities accessible through a simple language.<br>
  In other words, UBE aims to preserve VB's friendliness without preserving its historical limitations.<br>
- What makes UBE different from Visual Basic 6?<br>
  Several things, both internally and in the language itself.:
  - **A minimal compiler core.**<br>
    UBE's compiler is designed to understand only the essential building blocks of the language. Much of the higher-level functionality is implemented in a separate standard library.<br>
  - **Extensible native types.**<br>
    UBE aims to allow developers to define their own native data types, including their memory representation and how values are initialized, accessed and destroyed.<br>
  - **Modern compilation.**<br>
    UBE uses LLVM as its backend, allowing the compiler to target different architectures without requiring a separate code generator for each platform.<br>
  - **Strict declarations, friendly conversions.**<br>
    Variables must be explicitly declared and types are checked, but the runtime still supports convenient automatic conversions where they make sense.<br>
  - **A different approach to runtime errors.**<br>
    Rather than interrupting execution for ordinary recoverable failures, UBE is designed to return an invalid or default value and record error information for the programmer to inspect.<br>
- Will UBE compile existing VB6 projects?<br>
  **Yes. All valid VB6 code is intended to compile in UBE.**<br>
  UBE preserves VB6 syntax while deliberately reconsidering some of its underlying semantics, including error handling, type conversions, and other runtime behaviors.<br>
  This means existing VB6 code will compile without modification, but certain VB6 quirks may behave differently.<br>
  *If exact VB6 behavior is a requirement, TwinBASIC is likely the better choice for you.*
- Is UBE designed for beginners or experienced programmers?<br>
  **Both.**<br>
  A beginner should be able to write a simple program without first understanding memory management, compiler architecture or complex type systems.<br>
  An experienced developer should be able to access those capabilities when needed.<br>
  Complexity is available, not mandatory.<br>
- Is UBE ready for production use?<br>
  **Not yet.**<br>
  UBE is under active development.<br>
- Is UBE intended to replace Visual Basic, TwinBASIC or other programming languages?<br>
  **No.**<br>
  UBE is being developed just because I want to.<br>
  I am trying to realize an old dream.



## How UBE is being built
UBE is created by Ube, who defines the vision, product direction, and final
decisions. AI coding agents help turn that direction into specifications,
compiler code, tests, documentation, and project tooling.

The agents work inside repository-defined boundaries. Their work is reviewed
against the language specification, automated tests, preserved compiler
generations, and Ube's requirements. AI is used as an engineering tool; project
ownership and design authority remain with Ube.

## Project status

**Working native bootstrap, tested UBECore foundations, and qualified bounded
parallel source processing.**

Fresh Compiler v3 preserves original source bytes, scans them, and parses the
first bounded native MODULE grammar. Its compiler-owned `TryParseSources` runs
that work through actual UBE workers with budgets 1, 2 and 4, shared immutable
source owners, private results and deterministic complete publication. UBECore
supplies the reusable byte, Unicode, file and thread facilities.

Full grammar, semantic checking, code generation and project/jobs CLI integration
remain unfinished. Source-built v2 is still the bootstrap tool. Instrumented
four-worker execution was slower than one-worker execution; measured collector
contention is follow-up work, and no speedup is claimed.

**UBE is under active development and is not ready for production use.**

See the [workplan](Workplan.md), [development plan](project-docs/Development-Plan.md)
and [concurrency evidence](compiler/UBE_Compiler_v3/CONCURRENCY-EVIDENCE.md)
for the accepted gates, supported limits and proposed next work.

## First public-release goals

- Familiar Basic syntax with clearly defined modern behavior.
- Small, fast 64-bit native programs.
- Reliable compilation with support for multithreaded builds.
- A reusable, portable standard library.
- Clear diagnostics, debugging support, and complete offline documentation.

## Development builds

See the [build documentation](bootstrap/README.md) for prerequisites and
instructions for the preserved toolchain. The rebuilt Compiler v3 is not yet
available as a working release.

## Repository guide

- [docs/](docs/README.md) — public UBE language manual
- [lang-doc/](lang-doc/README.md) — normative language specification and grammar
- [project-docs/](project-docs/README.md) — architecture and development roadmap
- [compiler/](compiler/README.md) — active fresh v3 and preserved v1/v2
- [compiler/archived/](compiler/archived/README.md) — previous v3/v4 implementations and previews
- [std-lib/](std-lib/README.md) — fresh UBECore standard-library project
- [archive/](archive/README.md) — preserved previous library and integrity snapshot
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
