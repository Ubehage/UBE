# Source parsing acceptance gate

The 2026-11-13 CallNew grammar qualification passed 44 cases, including a
distinct expression/statement node, qualified targets, optional zero-argument
parentheses, and invalid argument syntax. Evidence:
`ube source parsing 1c6f2745-7d9c-480d-8824-e1681a438dfe`.
This qualifies syntax only; native worker execution remains guarded.

The runner builds the VB6 bootstrap or accepts `-BootstrapExe` for an existing
build. Hidden child processes have a 30-second deadline and retained handles.
Fixtures, build logs, stdout and stderr remain in the printed temporary directory.

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/source-parsing/check.ps1
```

This gate qualifies lexical and syntactic structure only. It does not claim
name binding, type checking, execution, failure semantics, native compilation,
or self-hosting.

`--parse` must print the project and ordered module summaries followed by
`PARSE OK`. `--dump-ast` additionally exposes deterministic NODE records with
kind, text, tree links, module, type/modifiers and UTF-16 source spans. The gate
asserts left-associative addition, addition/comparison/And precedence, ordered
call arguments and parameter modes, then/else branch ownership, exact literal
spans that slice back to source text, complete acyclic tree reachability, and
identical output on repeat runs. NODE fields decode `\\`, `\p`, `\r`, `\n`;
bracketed identifiers exercise pipes, backslashes and doubled closing brackets.

Positive inputs cover multiple modules, explicitly typed scalar declarations,
Boolean literals, Functions/Subs, calls, single-line and block If, labels/GoTo,
Exit, the three admitted On Error forms, Err calls/member access, and explicit
line continuation, bracketed reserved names, numeric labels, Rem comment
positions, keyword members, ElseIf and nearest-Else structure, all six
comparisons, signed hex/octal literals with Long suffixes, and Option Explicit
On. The checked-in `failure-flow/SourceOracle.bas` is loaded
unchanged and all eight public checks must appear in the AST; none are executed.
The checked-in multi-module Demo also preserves Program/Arithmetic order and
the `Arithmetic.Answer()` member/call tree; this does not assert name binding.

Negative inputs cover lexical truncation/invalid characters, malformed syntax,
required keyword spacing, reserved declaration names, Option Explicit Off,
unsupported constructs, a failure in the second module, and token-length,
token-count, aggregate-token, nesting and project-node limits. Sixty nested
groups and approximately 250,000 aggregate tokens must still pass. Each
rejection must return exit 1 with the
expected category/location and no PARSE OK. A failed AST dump must publish no
partial NODE records. One fail-fast diagnostic is sufficient; a later valid
process must succeed. This does not qualify editor-style multi-error recovery.

The 2026-11-13 node-capacity regression passed39 cases with the host at
`C:\Users\Ubehage\AppData\Local\Temp\ube source parsing 03d40ecc-0bae-45e3-b426-228d589ea920\build\UBE-Bootstrap.exe`.
The gate retains90,013 nodes, accepts exactly131,072 including the host's project
root, refuses131,073, and recovers. Run with `check.ps1 -BootstrapExe <host>`.
Evidence: `C:\Users\Ubehage\AppData\Local\Temp\ube source parsing cc880f3a-2c12-482a-9a23-6b6e2ecf8f0a`.
