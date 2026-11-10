# Scalar native lowering

This describes the bootstrap's internal lowering contract. The language
specification and error contract remain authoritative. Native acceptance is
recorded in `../compiler/Progress.md`; this document alone is not test evidence.

## Values and procedure calls

The emitter consumes the bound project, including declaration identities,
trusted support roles, selected types, checked constants and argument modes.
It does not assign behavior from procedure names. Syntax nodes retain their
original source spans; generated IR records source locations in comments.
Full debugger information is not yet qualified, including when a manifest
requests Line or Full information.

The private procedure ABI uses `{ i1, i64 }`: the first field is fresh success,
and the second is usable only when success is true. Long storage is represented
in signed i64 cells, with its signed-32-bit range enforced at typed operations
and conversions. Boolean cells use 0 and -1. Intermediate LongLong operations
retain signed-64-bit checks. The representation is not a foreign ABI or a
promise about future public type layouts.

Calls receive an explicit execution-context pointer, followed by value cells
or pointers for ByRef arguments. Arguments evaluate once in source order.
Direct ByRef arguments preserve their storage identity; grouped ByRef arguments
use converted temporary cells. A failure prevents remaining argument evaluation
and prevents entry into the callee. Earlier side effects remain observable.

The context owns the current error number, guarded call depth, module
initialization state and scalar module storage. Library tests supply their own
contexts; the single-thread executable entry owns one root context. This is
not qualification of native threads or full thread-local Err metadata.
Internal context-size and initialization helpers support the test harness;
ordinary Public procedures are not foreign exports.

## Error flow

Every potentially failing operation branches on its own fresh result. Err is
sticky information, not a success predicate. Trusted Raise records its number
and immediately returns FAIL from the containing procedure, bypassing that
procedure's handler. Clear resets the visible number without changing handler
state. Ordinary successful returns preserve the existing error number.
This scalar implementation uses Err 6 (Overflow) for checked integer arithmetic
and narrowing failures, and Err 28 for guarded call-depth refusal. These scoped
mappings do not define the complete future runtime error catalogue.

A caller failure edge abandons the entire containing statement. Assignment
stores occur only after successful evaluation and destination conversion.
The edge selects an enabled label handler unless that handler is already
active; otherwise execution continues at the next statement. An active handler
does not re-enter itself or automatically propagate a received failure.
Changing the error mode does not clear Err.

Procedure-owned storage begins neutral. A failed declaration initializer leaves
its established storage neutral. Module variables initialize in declaration
order, with the normal manifest schedule and initialization before access to
another module. Potential cross-module initialization cycles are rejected as
unsupported in this bounded profile; they are not redefined as language errors
or permitted to expose unfinished storage.

## Admission and host boundaries

Potentially failing compound-control headers remain unsupported until their
continuation target is defined. Lifecycle hooks and explicit Raise in the
executable root Main remain unsupported pending their failure-boundary
contracts. Ordinary handled failures within Main do not become process failure
because Err remains nonzero. Main's successful Long result becomes the process
result; a successful Sub Main produces zero.

Native call admission has a depth guard in the callee prologue, before its
source body runs, reporting Err 28 at 256 active source calls. This qualifies a
controlled recursion limit, not recovery from arbitrary OS stack exhaustion.
The driver reserves an 8 MiB native stack. Emission admits at most 128 scalar
frame cells (including four control cells), 64 parameters, 250,000 IR lines and
16 MiB of IR text. Aggregate frame/dispatcher scans and initializer dependency
visits each have a ten-million-step budget. These bounds report diagnostics;
an unavailable backend stack-probe helper produces a controlled build failure.

Admitted module initializers consume ordinary failures at declaration-statement
boundaries and return success. Thus module-ensure and project-initialization
helpers cannot transfer a fresh failure in this profile. This invariant does
not settle lifecycle-hook failures, which remain rejected. The launcher's
defensive unavailable branch returns host status 1, never a usable UBE result.

The build driver invokes the installed LLVM toolchain as a bounded hidden child
process and checks its fresh exit status and x64 PE output. It publishes through
replacement only after success, preserving any prior output on failed builds.
No VB6 runtime is linked into the generated executable. Library projects can
emit IR for internal tests; producing a public native library remains separate
work governed by the foreign ABI contract.

`--emit-llvm <project.UBE> <output.ll>` emits deterministic IR.
`--build <project.UBE> <output.exe> [--clang <path>]` invokes Clang/LLD.
The optional path overrides the installed Clang location. Neither command
downloads tools. The existing check, parse and analyze commands remain useful
independently of native emission.

The backend permits at most 64 KiB of tool diagnostics, 64 MiB of native output
and 30 seconds of compilation, with a bounded termination wait. A Windows Job
Object contains the backend process tree. Staging uses a fresh directory beside
the destination; input-file aliases are rejected, including existing hard links.
