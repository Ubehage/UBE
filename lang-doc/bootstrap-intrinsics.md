# Bootstrap compiler intrinsic ABI

**ABI identity:** `ube-intrinsic-abi-1`  
**Initial host:** x86-64 Windows GNU

These declarations are a private bootstrap/compiler boundary. They are not
public UBE library functions. A compiler source that uses one must declare its
exact signature with `Intrinsic`; an unknown name or mismatched signature is a
compile-time error.

## Tool process boundary

```vb
Intrinsic Function CompilerRunTool( _
    ByVal ExecutablePath As String, _
    ByRef Arguments() As String, _
    ByVal ArgumentCount As Long) As Long
```

`CompilerRunTool` starts exactly `ExecutablePath` and waits for it to finish.
It does not invoke a command shell and does not parse or join command-line
text. `Arguments(0)` through `Arguments(ArgumentCount - 1)` become distinct
child arguments in that order. Standard input, output, and error are inherited
from the compiler process.

The initial boundary accepts at most 4096 child arguments. The return value is
the child's nonnegative exit code, or:

- `-1` for an invalid path, count, or argument array;
- `-2` when argument storage cannot be allocated or the process cannot start;
- `-3` when the platform result cannot be represented by `Long`.

The implementation waits synchronously and releases all temporary argument
storage and process resources before returning. The compiler remains
responsible for reporting a useful tool diagnostic and removing any partial
output artifact after every nonzero return.

The current implementation uses the Windows host process adapter. Other hosts
must implement the same declaration and observable contract behind their own
platform substrate; host behavior must not leak into target-independent IR.

## Compiler performance measurements

```vb
Intrinsic Function CompilerMonotonicMilliseconds() As Long
Intrinsic Function CompilerProcessCpuMilliseconds() As Long
Intrinsic Function CompilerPeakWorkingSetKilobytes() As Long
```

These compiler-private measurements support repeatable bootstrap performance
profiles. `CompilerMonotonicMilliseconds` returns elapsed host time from a
monotonic clock. `CompilerProcessCpuMilliseconds` returns the compiler
process's accumulated kernel and user CPU time. `CompilerPeakWorkingSetKilobytes`
returns the peak physical memory charged to the compiler process.

Each result is expressed as a nonnegative, whole-number count in the unit named
by the declaration and is bounded by the positive range of `Long`. A function
returns `-1` when its measurement is unavailable. The values are diagnostic
metadata only: they must not affect compiled program semantics or generated
target IR.

The initial implementations use Windows host timing and process-information
APIs. Other bootstrap hosts may provide equivalent monotonic and process-local
measurements behind the same declarations. These functions are not public UBE
language or runtime APIs.

## Compiler artifact cleanup

```vb
Intrinsic Function CompilerDeleteFile(ByVal Path As String) As Long
```

`CompilerDeleteFile` removes an intermediate or failed compiler artifact
without invoking a shell. It returns `0` when the path was removed or did not
exist, `-1` for an invalid path, and `-2` when the host rejected the removal.
Compiler code uses it before tool invocation and on every failed or abandoned
native-output path.

`WriteAllText(Path, Contents)` writes compiler output to a uniquely named
sibling temporary file, flushes and closes it, and atomically replaces `Path`.
It returns `0` on success, `73` when the path cannot be opened, or `74` when
writing, flushing, closing, or replacement fails. A failure removes the
temporary file and never exposes a partially written final artifact.
