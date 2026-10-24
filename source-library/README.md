# UBE source library

This directory is reserved for the standard source library compiled and linked
with UBE programs. It is separate from `compiler/`: compiler generations use
the library, but do not own its source.

The library will contain ordinary UBE implementations of strings,
conversions, collections, files, dates, mathematics, threading helpers, and
other reusable facilities. Small compiler intrinsics may support operations
that cannot be expressed portably in ordinary UBE, but the public operations
remain declared library APIs rather than parser keywords.

UBE has no separately installed runtime or virtual machine. A build links the
library modules and minimal program support it needs into its native output.

## Current status

The canonical core package identity is `UBECore`. Its checked-in project is
[`UBECore.UBE`](UBECore.UBE), and its semantic preview version is
`0.1.0-rp8`. Compiler v3 RP8 builds a 16-module portable slice containing core
identity and intrinsic declarations, conversions, strings, managed memory,
Variants, errors, threads, sequentially consistent atomic wrappers,
`ThreadEvent`, `Semaphore`, FIFO `MessageQueue`, and synchronization helpers.
The RP8 public API fixture also verifies the exposed Variant predicates,
conversions, string operations, and atomic wrappers. The preserved v2-built
and self-built v3 compilers emit identical LLVM and objects for this exact
slice.

Future code is divided into meaningfully named functional modules. A preview
may use only the exact module slice recorded by its verified build.

See [DESIGN.md](DESIGN.md) for boundaries, [ROADMAP.md](ROADMAP.md) for the
resumable implementation plan, and
[`../project-docs/versioning.md`](../project-docs/versioning.md) for version
and compatibility identities.
