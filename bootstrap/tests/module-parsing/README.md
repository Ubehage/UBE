# Actual UBE module parser gate

The 2026-11-13 CallNew grammar qualification passed 32 cases and 7,754
structural assertions at both O0 and O2. The changed-operator control failed
at assertion 429 as expected. Evidence:
`ube module parsing a4d82e4a-d41f-475b-82c6-05b97008ebb8`.
ThreadStartNode retains the ordinary Call target and optional argument list;
its value field distinguishes expression and ignored-identity statement forms.

Run `powershell -NoProfile -File bootstrap/tests/module-parsing/check.ps1 -BootstrapExe <UBE-Bootstrap.exe>`.
Omit `-BootstrapExe` to build the VB6 bootstrap. LLVM Clang and its sibling
llvm-dlltool are required. Children run hidden with deadlines; source, emitted
IR, executables, logs and numbered assertion evidence remain in a temporary
`ube module parsing <guid>` directory.

The gate compiles the checked-in SourceScanner, SyntaxTokens and SourceParser
together with portable UBECore and a thin observation module. Runtime file reads
feed the real scanner and parser. The same emitted library is used at O0/O2.
The parser's own source, SourceScanner, SyntaxTokens, Utf8, BufferPrimitives and
FileBytes are parsed as data; this is syntax acceptance, not self-compilation.

Assertions cover all-node reachability, parent/child/sibling consistency,
acyclic traversal, source-span bounds, independent retained module trees,
exact authored byte/UTF-16 positions, continued expressions, precedence and
left associativity, ordered call arguments, nearest inline Else, all five Do
forms, intrinsic metadata, implicit array lower bounds, malformed syntax and
failure/recovery without replacing old nodes. Forward, mutually referencing
and self-referencing Type spellings are retained as syntax; semantic layout
support is a separate responsibility. Empty input produces a syntax diagnostic.
Changing an on-disk addition into subtraction must fail the exact unchanged
operator assertion, rather than merely terminating abnormally.

The large test-only assertion driver uses a conventional Windows stack-page
probe at O0. A separate production-only O0/O2 assembly check requires that none
of the actual source procedures reference that helper. The probe is never added
to compiler output. `assertions.txt` maps each nonzero native return to its first
failed check; many entries check file-path setup and fresh result status.

The caller owns matching source bytes, tokens and nodes for each module. Node
IDs are one-based; storage uses ID minus one. Zero is the absent link. A failed
parse resets public count/root while preserving older node storage. Independent
output variables are required for that guarantee; ordinary ByRef aliasing is
not suppressed. Allocation/depth fault tests are in the companion allocation
gate, and keyword classification has its own token gate.

Syntax-depth checks accept 30 nested expression groups and 20 nested Do loops,
then reject 80 groups and 40 loops with limit code 4/reason 7. Negative/past-source
token spans, invalid token kinds and early EOF receive syntax code 2/reason 39;
all these failures reset count/root and preserve the prior tree storage.

Final acceptance: 27 source/diagnostic cases at both optimization levels,
including actual modules, plus the exact runtime-input negative control.
Both production-only assembly checks passed. Evidence:
`ube module parsing f152048d-87a9-4e2b-b79d-baa2ee3b88eb`, using the executable
in `ube project loading 4512f340-a4e4-4aaf-98c4-de2e5192b324/build`.

Run `allocation-check.ps1 -BootstrapExe <binary>` for the companion 26 native
checks at O0/O2. It fails each of three tree-growth allocations and final
publication (including allocator retries), verifies all 20 prior-node fields,
zero count/root, released temporaries, and successful retry with sticky Err.
Runtime-depth cases terminate under deadlines with complete or preserved output.
Evidence: `ube parser allocation 254cc188-7518-4d37-8687-ceeed368d2a9`.

Run `token-check.ps1 -BootstrapExe <binary>` for 929 keyword, symbol and name
tokens, decoded comparisons and boundaries. Four native groups passed, including
an exact changed-input negative control at O0/O2. Evidence:
`ube syntax tokens b1c6fa71-17d1-4473-abd6-60764bbc9829`.
