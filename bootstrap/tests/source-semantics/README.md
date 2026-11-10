# Source semantic acceptance gate

Run `rtk proxy powershell -NoProfile -File bootstrap/tests/source-semantics/check.ps1`.
Use `-BootstrapExe` to select an existing build. The runner retains bounded hidden
process output, generated fixtures and compiler logs in its printed temporary directory.

This gate checks symbol resolution, types, constants, calls and procedure-local
control flow. It does not qualify lowering, generated native execution or runtime
error behavior. Structural bound-record assertions accompany acceptance/rejection
checks.

`--analyze` must return exact ordered PROJECT/MODULE summaries and ANALYZE OK.
`--dump-bound` adds ENTRY, SYMBOL and BOUND evidence. Assertions check entry
identity, scoped declarations, signatures, qualified call targets, constant
values, direct ByRef aliases versus converted grouped temporaries, ByVal
conversions, trusted Err role identities, and deterministic repeated output.
The actual SourceOracle and checked-in Demo must analyze successfully; their
procedures are not executed.

Positive cases cover lexical shadowing, default and explicit passing modes,
Boolean/Long assignment conversion, exact decimal intermediates and signed
boundaries, scalar initializers, earlier constant dependencies, visibility,
module/package qualification, ordinary user declarations named Err/Raise,
procedure-local labels and both executable Main signatures.

Negative cases assert diagnostic category and source location for duplicates,
undeclared/ambiguous/inaccessible names, wrong arguments, nonwritable or
wrong-type direct ByRef, invalid expression/result contexts, constant failures,
overflow, invalid local label targets, illegal Main signatures and erroneous
trusted Err usage. Deferred semantic domains must produce E_UNSUPPORTED.
Failures must not publish partial symbol/binding records or ANALYZE OK.

The gate exercises independent semantic depth and symbol bounds and checks a
valid invocation after failures. It does not qualify editor multi-error
recovery, runtime execution, module initialization scheduling, or LLVM output.
