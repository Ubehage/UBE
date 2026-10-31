# Independent Unicode and scalar-cursor expectations

`check-unicode.ps1` first checks exact official raw file bytes/hashes and Unicode
18 final-version markers. It parses the raw data into full codepoint arrays and
compares all 1,114,112 positions against the clean bootstrap header tables.
These tables are comparison subjects, never the oracle used to generate UBE.
It regenerates `Unicode.bas` offline and requires byte identity.

The native C oracle separately reads the original UCD text at execution time.
Its fixed-size expectation arrays contain categories Lu/Ll/Lt/Lm/Lo and exactly
the C/S mappings. Both accepted stages compile byte-identical copies of intact
UBE modules with their envelopes preserved. Test-only LLVM
bridges check exact procedure signatures, convert Boolean for C, and append
counter calls without replacing production branches or arithmetic.

Assertions cover letter/fold behavior at every codepoint, negative and oversized
Long values, and UTF-8 cursor decoding for every scalar. An independent mask/
shortest-length decoder checks every single byte and two-byte sequence, 50,000
deterministic four-byte samples, truncated/overlong/surrogate/oversized examples,
negative offsets, EOF and Long-max offsets. Failure outputs must be zero; input
bytes and a seeded Err value must be unchanged.

Instrumented lookup comparisons are checked per all-codepoint pair of calls;
actual decoder-feed calls must equal the returned width on every scalar and be
at most four on failure. An independently compiled runtime intercepts its real
malloc/calloc/realloc sites and executed payload-copy hook while calls are
measured and requires zero requests and zero copied payload bytes.
The accepted runtime is also executed. Four simultaneous workers compare shared
immutable raw-data expectation arrays and UTF-8 bytes with independent calls and independent
Err values. The sole managed byte array has an explicit native root; removing
the root and collecting must restore the baseline live managed allocation size.
Raw LLVM must be byte-identical between stages, and all proof inputs must retain
their recorded hashes through completion.

These assertions do not qualify Unicode normalization, full or locale-specific
folding, scanner tokenization, compiler-wide concurrency, or language semantics
beyond the helper contracts.
