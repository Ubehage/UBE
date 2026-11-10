# UBE project vision and early design record

UBE is a 64-bit, LLVM-targeting language derived from classic Visual Basic 6.
Its source syntax is intended to accept classic VB6 source while giving new
features well-defined, modern semantics.

> **Visual Basic, but out of the Kindergarten.**

## Core language commitments

- UBE is always strictly and explicitly typed. `Option Explicit Off` cannot
  disable declaration checking.
- Recoverable language failures report fresh FAIL and set Err without an
  automatic dialog. The caller skips the failed statement by default or enters
  its enabled handler. Err.Raise immediately exits the raising procedure;
  user-owned resource cleanup must happen before raising. See
  `../lang-doc/error-handling.md` for the approved contract.
- Familiar compatibility built-ins such as `Mid$` and `Len` deliberately
  accept documented values of multiple types, converting scalars as needed and
  receiving accepted objects as opaque handles. This library behavior does not
  weaken ordinary static typing.
- Every executable begins at exactly one `Sub Main()` or
  `Function Main() As Long`.


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

The owner authorized an implementation restart on 2026-11-10. Earlier compiler
and library implementations are removed from this working tree. Their former
verification claims do not establish support in the current checkout.

The UBE 1.0 contracts, including the owner's subsequent explicit decisions,
remain the target. VB6 is the selected bootstrap host and LLVM is the native
backend. The development plan begins with contract reconciliation and focused
failure-flow acceptance before source-compiler implementation grows.

See [`../bootstrap/README.md`](../bootstrap/README.md) for build instructions and the
current implementation boundary.
