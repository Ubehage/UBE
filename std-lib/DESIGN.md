# UBECore design boundary

## Starting point

The owner chose a fresh standard library on 2026-10-30. The previous library
is archived intact. Its code, APIs, intrinsic inventory, and verification claims
are not inherited by this project. Frozen UBE language semantics remain the
authority.

The owner also approved proving library-defined native datatype mechanisms
early and investigating the smallest existing stage-zero/v2 bootstrap route.
The collaborating fresh compiler is
[`../compiler/UBE_Compiler_v3/`](../compiler/UBE_Compiler_v3/README.md).
Its previous namesake and v4 are archived. Compiler-recognized machine/storage
primitives and type-definition mechanisms must be separated from ordinary
library type behavior. This approval does not choose new syntax, layouts,
intrinsic signatures, or public APIs; those require explicit contracts and
focused proof before implementation.

## Dependency direction

Compiler and application code consume documented UBECore APIs. UBECore contains
ordinary reusable UBE algorithms and depends only on the language and explicit,
minimal substrate contracts. It never depends on a compiler implementation.
Compiler-specific orchestration remains in the compiler or compiler support.

The first checked-in module is an empty manifest anchor. Select and test the
bootstrap tool and required language subset before implementing the first API.
Existing compiler artifacts can be tools for that bounded work without becoming
semantic authorities or prerequisites to repairing an entire compiler.

## Ownership and costs

Each facility specifies whether data is owned, borrowed for a call, copied, or
shared immutably. Mutable instances have one owner unless their API explicitly
supports synchronized sharing. Independent instances must not interfere.

Text APIs distinguish UTF-8 bytes, Unicode scalar values, and source positions.
Builders and storage facilities need measured growth and copying behavior.
Bounds alone do not establish efficient algorithms. Representation and API
choices remain open until their contracts and focused evidence are recorded.

Allocation, managed roots, errors, atomics, and native threads need tested
substrate contracts before an API relies on them. A wrapper does not establish
the correctness or cost of its underlying primitive.

## Portability and evidence

Portable algorithms use language-defined behavior. OS declarations and constants
belong in separate platform libraries when first required. Host and target are
independent. External-resource ownership is explicit and independent of GC.

Every implemented capability needs independent expected results, success and
rejection cases, meaningful boundaries and failures, and ownership/cleanup
checks. Concurrency and performance claims additionally require direct tests
and measurements of the relevant behavior. Publish public API documentation
only after its declaration and semantics are established; mark verification
limits explicitly.

Only the library slice required by the next concrete consumer is implemented.
The full standard library and compiler architecture are not prerequisites for
the first useful, independently tested facility.
