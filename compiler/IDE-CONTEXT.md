# IDE execution context

Owner-approved direction: expose `IS_IN_IDE` as a global, read-only Boolean
compiler-supplied constant. It describes the program's IDE execution context,
not whether the compiler was launched from an editor, optimization is disabled,
or debug information is present. Normal standalone execution is False; execution
hosted by the UBE IDE is True. It must not be a writable shared compiler global:
the final compiler retains the value in each compilation's context.

This is planned UBE language support, not an implemented predefined identifier
in the current source binders. Integration with conditional compilation and the
IDE launch/debug protocol remains part of that implementation; an executable
must not silently retain True when launched outside its intended IDE context.

The VB6 bootstrap implements its host equivalent now. `BootstrapMain.Main`
resolves the value on each startup through a `Debug.Assert` helper; the assertion
always succeeds in the IDE and is omitted from built executables. A public
read-only `IS_IN_IDE` property exposes the cached value. The local `ExitProcess`
wrapper calls the Windows API, declared as `NativeExitProcess`, only outside
the IDE. Existing callers still exit Main immediately after the wrapper returns.
This is sequential VB6 host state, not the final compiler's concurrency design.

The focused native/IDE regression is in `../bootstrap/tests/host-ide/check.ps1`.
The test substitutes command input/output but retains actual Main, its helpers
and the remaining bootstrap modules. It checks all completion paths and includes
an isolated negative control that restores the old unconditional termination.
