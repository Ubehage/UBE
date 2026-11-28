# Debug capability reporting gate

Run `check.ps1 -CompilerExe <actual UBE.exe>` from PowerShell. The compiler's
adjacent LLVM assets must be present. The default gate checks both optimization
levels 0 and 2; `-ApiOptimization 2` limits only the API portion, and `-SkipApi`
explicitly omits it. Neither limited invocation establishes the default gate.

The command matrix covers omitted/default Full, explicit Full, Line and None for
ordinary and IDE-context LLVM emission and executable builds. Assertions cover
exact standard output, standard error and exit status, published outputs,
executable behavior, debug-mode-independent LLVM, and absence of claimed source
debug metadata. Failed compilation and refused publication must preserve earlier
files and must not acquire the success-only warning.

`Probe.bas` is packaged with the real compiler sources, replacing only the
command entry module. It calls the public compilation API and asserts unmet Full
metadata, silent None, metadata reset after reusing a failed request, isolation
between reports, and preservation of earlier successful output. It builds and
runs at both optimization levels without an added stack-probe implementation.
This also guards the formerly failing O0 full-source link: LLVM spill space in
`NativeThreads.TryEmitThunk`, `NativeExpressions.EmitCall`,
`NativeCompilation.TryEmit` and the original longer warning formatter required
an unavailable `__chkstk`. Argument classification and replay predicates now
live in small shared routines; the warning text is concise. Native frame planning
and the platform runtime contract are unchanged.

The script retains manifests, packaged source snapshots, process output and
executables in its printed temporary evidence directory. A passing run prints
its assertion count and the selected API scope. Compilation alone is not a pass.

The warning does not implement source-level debugging. Successful published
outputs requested with Full or Line report `W_DEBUG_UNAVAILABLE` on standard
error while preserving successful standard output and exit status. The API
reports `RequestDiagnostic.UnavailableDebugInformation` (0 None, 1 Line, 2 Full)
separately from failure fields and does not render a warning itself. Failed
requests reset this capability field to zero.
