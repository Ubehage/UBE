# Task 1 dependency and ownership freeze

Task 1 freezes the facilities required by the Task 2 session shell and Task 3
minimal vertical slice. The machine-readable companion is
`TASK1_DEPENDENCIES.json`. Anything marked deferred is not permission to copy a
replacement into compiler source.

| Facility | Owner for first slice | Decision |
|---|---|---|
| tokens, syntax, diagnostics, phase records, semantic IDs, IR, LLVM | compiler | Generation-local policy; never a library API. |
| byte length and empty-string predicates | UBECore 0.1.0-rp8 | Existing documented public declarations are sufficient; no new API. |
| bounded text accumulation | UBECompilerSupport 0.1.0-v4t1 | `AppendBoundedText`; one mutation owner per buffer. |
| portable relative paths | UBECompilerSupport 0.1.0-v4t1 | `NormalizeCompilerRelativePath`; lexical and host independent. |
| deterministic record fields | UBECompilerSupport 0.1.0-v4t1 | `AppendRecordField`; bounded canonical `key=value` lines. |
| arguments and measurements | UBECompilerSupport 0.1.0-v4t1 | Read-only adapters with no shared module state. |
| required control-file read, atomic publication, cleanup | UBECompilerSupport 0.1.0-v4t1 | Explicit status and ownership over the frozen bootstrap ABI. |
| separate-argument process execution | UBECompilerSupport 0.1.0-v4t1 | Waits and releases resources before returning. |
| Unicode decode/folding | UBECore, deferred to Task 4 | Task 2/3 fixtures are ASCII; no speculative surface. |
| growable collections and hash tables | UBECore, deferred to Task 6 | Native bounded arrays are sufficient for the first slice. |
| SHA-256 | compiler support, deferred to package work | Task runners hash evidence externally; compiler code must not invent SHA. |
| general JSON/binary serialization | UBECore, deferred | The first records need only the frozen line format. |
| parallel executor | compiler, deferred to Task 11 | Task 2 establishes the permanent sequential reference path first. |
| native file/process/clock/thread operations | platform/bootstrap ABI | Never exposed as language semantics or duplicated in compiler code. |

The support package has 13 private intrinsic declarations, all already present
in `ube-intrinsic-abi-1`; Task 1 adds zero intrinsic names. UBECore retains its
54 preserved private declarations and unchanged `0.1.0-rp8` public surface.
The support wrappers are retained while v4 bootstraps. String primitives can
move behind ordinary UBECore implementations once those implementations meet
the same tests. File, process, command-line, and measurement hooks remain
platform-bound compiler support and therefore have no portable UBE fallback.

`task1/run-task1.ps1` builds UBECore and UBECompilerSupport as independent
projects with the preserved v3 compiler, repeats and compares support LLVM,
builds three native fixtures, checks limits/rejections/portable paths, runs
reentrant calls on two UBE threads, and checks file/process cleanup. Generated
evidence belongs only under `bootstrap/out/v4-task1/`.

## Task 4 extension

Task 4 activates the previously deferred Unicode boundary. The compiler-support
package is now `0.2.0-v4t4` and exposes ordinary UBE wrappers for two additional
intrinsics already present in `ube-intrinsic-abi-1`: Unicode letter membership
and simple code-point folding. It also exposes the existing required-text read
operation to the load-once project/source phase. The package therefore has 15
private intrinsic declarations and still introduces zero new ABI names. The
Task 1 ownership decisions remain frozen; this section records the later,
verified extension instead of rewriting their historical scope.
