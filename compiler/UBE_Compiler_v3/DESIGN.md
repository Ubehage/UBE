# UBE Compiler v3 architecture

## Status

This is the architectural boundary for the v3 generation. V3 is UBE's first
public-release compiler target. The checked-in program is the verified,
v2-buildable RP5 compiler with complete lexical, preprocessing, owned syntax,
symbol, scope, type, semantic-validation, bounded typed-IR, IR-verification,
LLVM, debug-line, target-ABI, and native-tool handoff phases.

## Bootstrap boundary

V2 is the sole bootstrap compiler for the initial v3 implementation. Initial
v3 source stays within v2's frozen contract. V3 may accept and implement
language facilities that its own initial source does not yet use. No
pre-existing v3 binary is required.

The required chain is:

```text
stage zero -> preserved v2 -> initial v3 -> self-built v3
```

V1 and v2 remain preserved and verified after v3 becomes authoritative.

## Minimal compiler boundary

The compiler owns only behavior that must be known to translate a program:

- source/project validation;
- lexing and parsing;
- name and type resolution;
- implicit-conversion selection;
- lifetime, call, control-flow, and concurrency validation;
- target-independent typed IR and verification;
- LLVM lowering, debug metadata, and target ABI selection;
- dependency and linkage metadata for separately compiled libraries.

Algorithms expressible in UBE do not become compiler built-ins. Strings,
formatting, conversions, collections, threading helpers, error helpers, and
other public facilities live in a separately compiled, versioned UBE core
library. The compiler recognizes only the small intrinsic ABI needed for
irreducible operations.

The compiler emits managed-layout metadata, live-root information, safe points,
and barriers required by the UBE garbage collector. The collector algorithm is
runtime/library code rather than compiler code.

Garbage collection covers managed memory only. Compiler code explicitly closes
every file, pipe, process handle, lock, temporary artifact, and target-tool
resource it acquires on success and on every failure path. The compiler must
not rely on collection or process exit for externally visible cleanup.

The initial compiler-tool process adapter is the private, versioned
`CompilerRunTool` intrinsic documented in
[`../../lang-doc/bootstrap-intrinsics.md`](../../lang-doc/bootstrap-intrinsics.md).
It accepts an executable path and separate bounded arguments; compiler code
must not construct a shell command line.

## Linked program support and platform boundary

UBE has no separately installed runtime or VM. Required support is compiled and
linked into each produced native program. The public core and standard
libraries are primarily portable UBE source. A small platform substrate
implements facilities that necessarily cross an OS
or hardware boundary: process startup, virtual memory, thread creation, files,
clocks, message dispatch, atomics, and equivalent primitives.

Portable library APIs must not expose native handles accidentally. Explicit
platform modules may expose platform functionality by opt-in.

Host and target are independent compiler inputs. Target triples, data layouts,
calling conventions, object formats, linkers, runtime objects, and platform
library implementations are selected through target descriptions. Windows is
the first development host and target, not a semantic default.

## Planned compiler modules

The initial source remains v2-compatible and is split only through ordered
`.UBE` source entries:

1. driver and project loading;
2. source manager and diagnostics;
3. lexer and parser;
4. declarations, symbols, and type system;
5. semantic analysis and conversion planning;
6. ownership, managed-reference, and concurrency validation;
7. target-independent IR and verifier;
8. LLVM backend and debug information;
9. library metadata and linker handoff;
10. bootstrap comparison and conformance harness.

Each phase consumes validated records and returns controlled diagnostics.
Malformed source, project data, library metadata, target descriptions, and
external-tool failures must never produce an uncontrolled compiler crash.

## Reproducibility gate

RP5 satisfies the first complete v3 self-build gate: a clean v2-built compiler
builds itself and the current `UBECore` slice, the self-built compiler repeats
both builds, the documented deterministic comparisons pass, and both stages
agree on the positive and negative native corpus for the declared
`x86_64-w64-windows-gnu` target. Later previews must preserve this gate while
expanding toward the complete language and library.
