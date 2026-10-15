# UBE project vision and early design record

UBE is a 64-bit, LLVM-targeting language derived from classic Visual Basic 6.
Its source syntax is intended to accept classic VB6 source while giving new
features well-defined, modern semantics.

> **Visual Basic, but out of the Kindergarten.**

## Core language commitments

- UBE is always strictly and explicitly typed. `Option Explicit Off` cannot
  disable declaration checking.
- Recoverable runtime failures are noninteractive: they return a documented
  neutral value and set `Err` instead of showing an automatic message box or
  crashing the program. Programs can request explicit trapping with
  `On Error`.
- Familiar compatibility built-ins such as `Mid$` and `Len` deliberately
  accept documented values of multiple types, converting scalars as needed and
  receiving accepted objects as opaque handles. This library behavior does not
  weaken ordinary static typing.
- Every executable begins at exactly one `Sub Main()` or
  `Function Main() As Long`.

## AI-authored project

UBE is currently written entirely by AI agents under the direction of its
human project owner. This includes the implementation, tests, language and
architecture documents, grammar, and development roadmap. The owner supplies
the product vision, requirements, and design decisions and reviews the work as
the project develops.

The project is planned to open to human contributors and testers at the
**Public Developer Preview — Stage One** milestone. From that point onward,
individual contributions will be reviewed and credited normally, and this
statement will remain as a record of UBE's origin rather than implying that all
later work is AI-authored.

## Language definition

- [`../lang-doc/grammar/ube.ebnf`](../lang-doc/grammar/ube.ebnf) is the normative core grammar.
- [`../lang-doc/language-spec.md`](../lang-doc/language-spec.md) defines lexical rules,
  disambiguation, compatibility boundaries, and the initial type model.

The grammar deliberately does not enumerate intrinsic or library functions
(`Mid$`, `Left$`, and so on). They are ordinary callable names supplied by the
standard library.

## Projects and files

UBE source uses the classic `.bas`, `.frm`, `.cls`, and `.ctl` text formats.
Native project manifests are plain-text `<project-name>.UBE` files, and
plain-text project groups are `<projectgroup-name>.UBG` files. Binary designer
assets such as pictures and icons are kept out of those text files in a seperate file `.UBR`
resource sidecars, which the compiler validates and embeds in native output.
The formats and safety requirements are defined in
[`../lang-doc/project-files.md`](../lang-doc/project-files.md).

## Status

This repository contains language definition version 0.3, a C++ stage-zero
compiler, a minimal native runtime, and the first compiler implementation
written in UBE. Stage zero currently performs UTF-8 lexing, parsing, semantic
analysis, LLVM IR generation, and native x86-64 Windows linking for the evolving
Bootstrap Profile.

The preserved UBE Compiler v2 is intentionally narrow but self-hosting. Stage
zero builds it, it rebuilds itself through stage two with byte-identical
fixed-point LLVM, and both stages compile and run the checked-in multi-module
conformance project with cross-module type and procedure resolution. V2 is the
stable transitional compiler for developing and compiling v3; v3 is UBE's
first public-release target and will own the complete language and product
features.

See [`../bootstrap/README.md`](../bootstrap/README.md) for build instructions and the
current implementation boundary.
