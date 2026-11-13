# UBE-written native lowering

Status: implemented and qualified for the admitted bootstrap profile. The
[whole-program and failure gates](tests/native-lowering/README.md) pass at O0/O2,
including code generation for the compiler/library source. Self-hosting,
concurrent execution and full source-level debugging remain separate gates.

## Existing behavior remains authoritative

LOWERING.md, SEMANTICS.md, AGGREGATES.md, DYNAMIC-STORAGE.md,
COUNTED-BUFFERS.md, FILE-IO.md and project-docs/Error-Handling.md govern the implementation.
The current qualified VB6 SourceEmitter and NativeFileRuntime provide concrete
behavior to compare, not a provider of replacement user-procedure IR. The
normative language and agreed error behavior outrank an accidental host bug.
Native acceptance must be based on executable assertions rather than stale
historical README scope.

The UBE emitter consumes freshly checked multi-module source identities,
expression types/constants/conversions/argument modes, validated primitive
roles and finite storage facts. Calls resolve by declaration identity. Each
compilation owns its scratch arrays, planner state and output counters. No
mutable global current project, procedure, source or output is permitted.

The existing private ABI remains `{ i1, i64 }` with an explicit execution
context. The success bit is fresh; sticky Err is never the success predicate.
Arguments and destinations evaluate once in source order. Exact typed overflow,
ByRef aliases/temporaries, indexed pins through later arguments and RHS work,
record snapshots, independent array replacement and cleanup paths must match
the admitted contracts. Handlers are invocation-local. Raise exits immediately;
ordinary received failure abandons the statement; failed conditions skip the
whole construct; failures in an active handler do not re-enter that handler.

## Public boundary and implementation ownership

`NativeLowering.TryEmit(Bytes, Tokens, Nodes, Modules, Counts, PackageName,
IsExecutable, Catalog, RuntimeText, Token, State, Diagnostic) As Boolean` is the
emission boundary. The project arrays use the existing `ProjectSyntax` records;
`State` is `NativeEmission.EmissionState` and `Diagnostic` is
`DeclarationBinder.BindingDiagnostic`. `IsExecutable` and the open output
`Token` are passed ByVal; the remaining arguments are ByRef. The caller supplies
the reviewed template catalog/runtime bytes and owns the private output token.

The boundary recomputes declarations, expressions, primitive roles and layouts
into private arrays, then plans and emits the project. It does not grant
authority to caller-supplied bound symbols or role numbers. A successful return
includes writer completion/flush, but does not close the token, compile LLVM,
publish a file or establish that the emitted program passed an acceptance gate.
On failure, the diagnostic and latched writer status remain actionable; a
partially written stage must be discarded by its owner. A close failure must
retain the owner so cleanup can be retried without losing the primary error.

The implementation is divided by lasting responsibility:

| Module | Responsibility |
| --- | --- |
| `NativePlanning` | Context offsets, frame admission, result identities, source-ordered scope links, pin slots and initialization dependencies. |
| `NativeEmission` | Per-compilation work budget, per-procedure SSA/block counters, source failure sites and fresh-status guards. |
| `NativeValues` | Checked scalar conversions, arithmetic and normalized Boolean results. |
| `NativeStorage` | Addresses, descriptor capture, pin lifetime, record snapshots and storage cleanup. |
| `NativeExpressions` | Ordered references, arguments, calls, operators and trusted Err operations. |
| `NativeControl` | Statements, labels, If/Do flow and whole-construct failure continuations. |
| `NativeFrames` | Signatures, entry allocations, invocation-local handlers, recursion guard, dispatch, returns and module initialization wrappers. |
| `NativeContext` / `NativeIntrinsics` | Project context/entry definitions and wrappers selected by validated primitive identity. |
| `LLVMWriter` / `LLVMFormat` / `LLVMTemplates` | Bounded streaming, numeric formatting and reviewed ASCII fragments. |

These helpers consume matching private facts from the boundary. They are not
independent validation interfaces for arbitrary externally assembled plans.
`BeginFunction` resets procedure counters and control state while preserving
the compilation work budget. Source labels use `b<node-id>`, `b0` is successful
return, and auxiliary labels start beyond the project node count. Per-node
failure arrays record the owning procedure and continuation, so failure routing
cannot be inferred from stale Err state. All runtime handler cells and grouped
ByRef temporaries are allocated in the invocation entry block.

Source-location comments identify module, node, line and column in generated
IR; compilation diagnostics retain original source coordinates. These comments
are not LLVM debug metadata and do not qualify source-level debugging.

## Measured output dependency

One current Byte array holds at most 1,048,576 elements, represented privately
as eight-byte cells. Retaining 16 MiB of text in one array would violate both
that bound and the 64 MiB allocation quota. This does not justify reducing the
existing IR limit. Instead LLVMWriter streams through a 65,536-byte buffer into
a caller-owned private staging token, using FileBytes.TryWriteByteRange. The
range helper handles partial progress without flushing after every fragment;
writer completion flushes once. ByteText formats exact signed decimal values,
including LongLong minimum, without a new String type or arithmetic operator.

LLVMWriter admits at most 16,777,216 bytes and 500,000 lines, counting
CRLF bytes and line-feed terminators. It checks a complete fragment before
consuming it and latches any failure. Its fragment input and scratch output
buffer must be separate caller-owned arrays. The writer never owns or closes
the token and never publishes a destination. Partial failed stages are not
usable output. The outer driver must close/discard them, preserve the primary
diagnostic, and publish only after complete emission and successful native
validation using the existing guarded staging/publication rules. Prior public
outputs must remain unchanged on any failure.

Fixed target support is retained in compiler/llvm/windows-runtime.ll. It is
reviewed runtime source, not a frozen output program or user-procedure oracle.
bootstrap/tools/runtime-text.ps1 checks exact parity against the existing
VB6 support emission statements and rejects unknown interpolations. UBE must
generate context definitions/helpers, module initialization, identity-bound
primitive wrappers, source procedures and entry code from the current facts.
The existing host remains independently buildable while this port is qualified.

## Native planning

NativePlanning consumes matching validated facts supplied privately by the
outer emitter. Its result arrays are scratch workspaces, not public trusted
inputs. Summary counts become valid only after complete planning. The outer
emission boundary owns complete validation and atomic final publication.

Plans retain module context offsets, frame-cell totals, pin capacity and result
identity. Per-node pin slots preserve original payload aliases. Dependency
analysis starts from module variable initializers, follows reachable source
calls and variable accesses, and rejects the existing unsupported cross-module
initialization cycles. Same-module recursion is bounded through visitation.
Both dependency visits and aggregate emission scans retain ten-million-step
budgets. Limits remain 128 frame cells including four handler-control cells,
64 parameters, 65,536 context storage cells and 256 active source calls.
Native frame temporaries, snapshot storage and borrow slots must be counted
before emission; finite logical layouts alone do not prove frame admission.

## Completion evidence

Build the actual UBE emitter with the existing host, then feed it source files
at native runtime. Compile its emitted IR at O0/O2 and execute independently
authored assertions. Host-produced user procedure bodies must never be inserted
into the new output. Compare observable results against the established host
where meaningful; exact IR text equality is not required for different valid
temporary numbering or implementation structure.

Cover actual compiler/library modules, multiple source modules, scalar widths
and overflow, calls/ByRef, If/Do flow, every admitted handler/failure case,
module initialization, finite records, arrays/copy/resize/pins, primitive status,
file progress/ownership, frame/parameter/output limits and recursive guards.
Use the current native, integer, failure-flow, aggregate, dynamic-storage,
counted-buffer and file-I/O fixtures and their independent expectations. Include
changed-input negative controls, malformed retained inputs, allocation/IO/depth
failures, previous-public-output preservation, deterministic output and isolated
contexts. Source diagnostics must retain original module and coordinates.

Final debugging support, concurrent execution and self-hosting remain separate
acceptance gates. Record exact commands, artifacts and limitations in
compiler/Progress.md before completion and the requested commit/push to main.
