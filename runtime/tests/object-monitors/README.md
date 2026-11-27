# Object monitor native gate

Run from the repository root:

```powershell
rtk proxy powershell -NoProfile -File runtime/tests/object-monitors/check.ps1
```

The gate compiles the production runtime and genuine managed kind-3 object
allocation at O0 and O2. Three executions per optimization level require exit
42 and empty stderr. Processes have a 30-second deadline; worker retry and
thread completion checks are bounded. Retained stdout/stderr and LLVM inputs
are printed under a unique temporary evidence directory.

Assertions cover controlled `Nothing` acquisition, rejected oversized creation
without output mutation, reentrant acquisition, retention after inner release,
object identity roots for the owner and waiting worker in a stopped snapshot,
collector rendezvous during contention, release/acquire memory visibility, and
preservation of each thread's incoming Err including the busy-wait path.
Structured retirement additionally checks that an unacquired target does not
decrement an existing monitor, a failed release retains both cleanup slots and
its error, and a successful release clears the slots without changing Err.
Dynamic nominal queries additionally require the exact class identifier,
successful Nothing/zero handling, controlled rejection of a genuine managed
value of the wrong kind, a zero failure payload, and preserved Err on success.

A negative control replaces the production decrement with an unconditional
zero depth in a temporary runtime copy. The same probe must return assertion
failure 1, demonstrating that it rejects premature reentrant release.

Sleep(1) is scheduling backoff, not a correctness assumption or a timing oracle.
Successful worker progress is communicated through atomic flags and the native
thread wait result.

Without `-ProgramIR`, the automatic collector callback deliberately performs no
collection. That mode proves the real begin/snapshot/root-enumeration/end gates,
rendezvous and precise root publication.

Pass `-ProgramIR <program.ll>` containing the actual emitted UBE collector to
exercise complete collection. The harness replaces only its native runtime with
the current canonical asset and enters through project initialization, which
installs the ordinary UBE collector. It adds a precisely described managed text
field to the object and asserts both object and text survive collection while
the monitor is held and a worker waits. After the worker completes and the final
object root is removed, a complete collection must remove both identities and
run the allocation-free native payload-cleanup callback exactly once. This
callback represents compiler-owned payload cleanup, not Class_Terminate.

Source-level class/SyncLock tests remain necessary for
compiler target evaluation, acquired flags, all outgoing cleanup edges, retained
enclosing locks, and compiler-generated root metadata. These tests do not
establish class lifecycle-hook, form/control, or unload support.
