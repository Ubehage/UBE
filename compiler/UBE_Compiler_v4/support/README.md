# UBE Compiler v4 support package

`UBECompilerSupport` 0.1.0-v4t1 is the separately buildable, compiler-only
foundation approved by Task 1. It contains bounded and deterministic adapters
needed by the Task 2 session shell. It owns no parser, semantic, IR, backend,
or target policy and has no mutable module state.

The public declarations are the `Public` procedures in `src/`. Every buffer
mutation has one owner; independent calls are reentrant. File and process
resources remain owned by the private bootstrap ABI, which closes them before
returning. `PublishCompilerText` is atomic and removes its temporary file on
failure. Callers remove any older output before a build and publish only after
all validation succeeds.

The 13 private intrinsic declarations are frozen in `SupportIntrinsics.bas`.
String primitives remain intrinsic until ordinary UBE strings can implement
them; command, file, process, and measurement hooks remain platform-bound
compiler-support operations. No new intrinsic was added for Task 1.
