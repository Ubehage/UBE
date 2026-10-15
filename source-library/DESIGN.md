# UBE source-library design

**Status:** repository boundary approved; concrete public API pending

## Boundary

The source library is a separate UBE project at the repository root, defined
by a checked-in `.UBE` manifest once implementation begins.
Compiler v3 may depend on a deliberately small library subset while it is being
built, but library source stays here and is built as a separate input.

Dependency direction is:

```text
compiler source -> frozen library declarations -> source-library modules
                                              -> minimal compiler intrinsics
                                              -> runtime target adapters
```

The source library must not depend on compiler implementation modules. The
compiler may know the versioned declarations and intrinsic contracts required
to build the selected library, but it must not contain hidden replacements for
ordinary library procedures.

## Planned layout

```text
source-library/
|-- AGENTS.md
|-- README.md
|-- DESIGN.md
|-- ROADMAP.md
|-- src/
|   |-- portable/       OS-independent UBE modules
|   `-- platform/       Explicit target adapters
`-- tests/              API, failure, ownership, and portability tests
```

Subdirectories are created when their first real module or test is introduced.
The project manifest and canonical package name wait for the corresponding
language-architecture decision; temporary names must not become public by
accident.

Implementation is divided into modules with names that state their functional
responsibility, such as `Memory.bas`, `Strings.bas`, `Files.bas`, or
`Threading.bas`. A module contains closely related declarations and operations;
unrelated helpers are split into the module that owns their behavior. Its
filename, `UBE_Name`, manifest entry, tests, and documentation use consistent
terminology.

Every library declaration is documented in the source near its definition.
Comments state what it does and the behavior callers need to know. Complex
algorithms also carry short rationale comments at the relevant steps, including
why an unusual operation, ordering rule, portability adaptation, or cleanup
path is necessary. Comments supplement clear names and structure; they do not
repeat obvious statements line by line.

## Compiler-preview policy

Each Compiler v3 preview records the exact source-library subset it needs.
That subset is built alongside the compiler and must pass its own tests. A
preview may continue to be built by v2; self-hosting is an additional preserved
verification milestone once a preview can compile itself and its library
subset.

Preview completion requires:

- a stable compiler artifact built by the preceding trusted compiler;
- a recorded list of required library modules and intrinsic contracts;
- successful compiler and library tests for the implemented feature set;
- reproducible source, compiler, target, and artifact identities; and
- no unrecorded dependency on a later preview's library surface.

## Portability and resources

Portable modules use language-defined behavior only. Target-specific files,
clocks, processes, networking, native UI, and ABI operations live behind
explicit platform declarations and adapters.

Managed memory does not imply external-resource ownership. Each API that opens
or acquires a file, socket, process, native handle, or similar resource must
state who closes it and how failures preserve that obligation.
