# Unicode and scalar-cursor evidence

Status on 2026-10-30: the unchanged maintained gate passes all eight Unicode/
cursor assertions against the final current-source bootstrap cohort. The
complete bootstrap gate passes 501 assertions. This qualifies the bounded
library slice below, not a complete compiler or library release.

## Implemented scope

`src/portable/Unicode.bas` contains ordinary UBE implementations of
`IsUnicodeLetter` and `SimpleFoldUnicode`: Unicode 18.0.0 categories
Lu/Ll/Lt/Lm/Lo and default simple C/S folding. The offline generator emits
balanced binary decisions with at most four range tests in a leaf. It uses
694 letter ranges and 219 constant-delta stride ranges for 1,533 fold mappings.
There is no runtime table initialization, mutable shared state or new intrinsic.

`src/portable/Utf8Cursor.bas` implements `TryReadSourceScalar` by borrowing one
immutable byte array and calling the existing incremental decoder. It retains
no reference and returns zero scalar/width on malformed, truncated, EOF or
out-of-range reads. Compiler source-document and token types do not enter the
library. Exact APIs, invalid-scalar behavior, ownership, output-aliasing rules
and thread-safety requirements are in `UNICODE-CONTRACT.md`.

## Official data and offline provenance

The exact received bytes under `data/unicode/18.0.0/` came from bounded HTTPS
downloads from Unicode.org on 2026-10-30. `provenance.json` records the URLs,
retrieval time, byte counts and SHA-256 identities. The versioned ReadMe states
that the directory contains final Unicode 18.0.0 data. Unicode License V3 is
retained alongside the raw files and covers the derived tables.

| File | Bytes | SHA-256 |
|---|---:|---|
| CaseFolding.txt | 88,776 | `A004797658A457BEC4DC11683E39F69249EA3B595B752DBEA6721C4C9F587B0D` |
| DerivedGeneralCategory.txt | 282,143 | `D6B151D2D40EE9B1876D26F417980F45FFAE47B6055CCF7203CB31F07A030F94` |
| ReadMe.txt | 729 | `B0EA442F29DEE90584AACD3665A6E1CE87FFC917A4D31F34E1916D2D6F7F9205` |
| LICENSE.txt | 1,995 | `E7A93B009565CFCE55919A381437AC4DB883E9DA2126FA28B91D12732BC53D96` |

`tools/generate-unicode.ps1` verifies those recorded identities before reading
the data. Regeneration and the maintained acceptance gate do not use the
network, host Unicode tables or locale casing. Builds require no new dependency.

## Current-source qualification

`rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1` passed 501
assertions and retained the current-source cohort under
`bootstrap/out/v2/4eb76c64ed774a1a9fb38b38155b71ef/`. Its Unicode subgate ran
the unchanged maintained `std-lib/tools/check-unicode.ps1` with source/artifact
identity checks enabled. All eight grouped Unicode/cursor assertions passed,
including the exhaustive independent oracles described below, four native
executions and raw LLVM identity through both accepted stages.

| Artifact within the final cohort | SHA-256 |
|---|---|
| manifest.json | `5A1C0A9D2A9DA40AAAA1FC45B0AF259003AFC362572B26AC207884C607EF0726` |
| source-manifest.json | `DB5DFA468B3F043580ABA90FA28AA28019DDC8062B3104F59473B85E3C85EF8F` |
| ube-stage2-v2.exe | `25392B89D16B8BF80E25F53D10EA0F3407C4AECC81BEF6114FB740B5F9D43A60` |

The formal Unicode report is
`bootstrap/out/unicode/12201ca30b0d49f6b763e7fa8fb87d85/report.json`, SHA-256
`B194033F37A0826D58D2BF640C76082B761B1D9FB8D8BC2A1EFA61E83E21FEDD`.
Both raw LLVM artifacts have SHA-256
`D3774DC4168DAF3CEBE8B63DC3AA7BD9FB1FDD31DC6533BD5059A6F378C4F6AA`.

| Stage | Runtime | Elapsed ms | Max comparisons per letter/fold pair | Main-thread feed calls | Measured allocation requests | Measured copied payload bytes |
|---|---|---:|---:|---:|---:|---:|
| 1 | accepted | 1,055 | 33 | 4,522,488 | not instrumented | not instrumented |
| 1 | instrumented | 959 | 33 | 4,522,488 | 0 | 0 |
| 2 | accepted | 1,048 | 33 | 4,522,488 | not instrumented | not instrumented |
| 2 | instrumented | 961 | 33 | 4,522,488 | 0 | 0 |

The allocation/copy counters cover measured helper calls; input construction
and fixture storage remain outside them. Elapsed times are observations, not
throughput promises. The compiler's separate qualified scanner report proves
its intact UBECore Reference and token/envelope behavior; see
`../compiler/UBE_Compiler_v3/SCANNER-EVIDENCE.md`.

## Historical diagnostic procedure and observed results

The maintained standalone acceptance command is:

```text
rtk proxy powershell -NoProfile -File std-lib/tools/check-unicode.ps1 -SelectionPath <final-current-source-selection>
```

During implementation, the existing accepted-source manifest no longer matched
the authorized working sources, including the nonreserved ByteBuffer parameter
rename. The unchanged maintained gate correctly stopped at that mismatch.
Development therefore used the explicitly temporary command
`rtk proxy powershell -NoProfile -File bootstrap/out/run-unicode-diagnostic.ps1`.
That runner copied the maintained procedure under `bootstrap/out/`, bypassing
the stale accepted-source cohort equality and final aggregate input equality
checks. Tool artifact identities and native oracles remained checked. Its
`success: true` result records a diagnostic pass, not current-source
qualification; its report schema did not separately label that distinction.

The final diagnostic report is
`bootstrap/out/unicode/17e114be40e441a083c905599a36b7fb/report.json`, SHA-256
`2E3A56D982EEB29645183E1F74CA346086BF7626E9FCE9413553FAADDFA445C4`.
It records eight passing grouped assertions, including four native executions:
two pinned compiler stages, each with the accepted runtime and an independently
instrumented runtime. The tool cohort used
`bootstrap/out/v2/50edfbded639485bb287e2541b428ff2/`; its stage-one executable
hash was `A7D41A9D528EC518CACBD1137FA6E2A2F37DE28635C8F7972432A18AED6C34F2`
and stage-two executable hash was
`C15F4C29EF54DCB9A3922CAB27D114989CB3618DDDC188DE967A5BBC96FD4E6C`.
These are historical diagnostic tool identities, not the final source cohort.

The procedure checked:

- Exact official file identities and final-version markers; independent raw
  arrays equal the bootstrap letter/fold headers at all 1,114,112 codepoints.
  The headers were comparison subjects, never the Unicode implementation oracle.
- Byte-identical offline regeneration of the checked-in UBE lookup module.
- Native letter/fold results for every codepoint, including surrogates, and
  explicit negative/oversized Long inputs. The C oracle separately parsed the
  original raw UCD files at execution time.
- Cursor results for every Unicode scalar, every one-byte and two-byte sequence,
  50,000 deterministic four-byte samples, and explicit malformed/truncated,
  surrogate, overlong, oversized and offset-boundary cases. A separate mask and
  shortest-length decoder supplied expected results. Failures had neutral
  outputs; source bytes and seeded Err values remained unchanged.
- Four simultaneous native workers using shared immutable expectation arrays
  and UTF-8 bytes, private scalar state and distinct seeded Err values.
  Explicit managed-root removal and collection restored baseline live bytes.
- Exact production module envelopes/bodies in byte-identical test copies;
  test-only LLVM ABI/observation bridges; byte-identical raw LLVM through both
  stages, SHA-256
  `D3774DC4168DAF3CEBE8B63DC3AA7BD9FB1FDD31DC6533BD5059A6F378C4F6AA`.

Each native execution observed a maximum of 33 comparisons per combined
letter/fold pair and 4,522,488 main-thread decoder-feed calls in the exercised
workload. Every scalar read used exactly its returned byte width in feed calls;
failure probes used at most four. Instrumented runtime allocation sites recorded
zero requests while helper calls were measured, and the executed payload-copy
hook recorded zero copied bytes. Input array setup and native fixture storage
are outside those helper-call allocation/copy measurements. Native elapsed times
were 1,154 through 1,283 ms for this diagnostic run; they are observations, not a
throughput promise. Detailed counters and sampled working sets remain in the
report. `tests/unicode/ORACLES.md` describes the independent expectations.

## Limits

The qualified library slice establishes neither a complete compiler nor a
release, parser, conditional evaluator, literal conversion, normalization,
full/locale-specific folding or UBE worker scheduler. Standalone native shared-
library packaging remains outside this slice. No archived library implementation
or old generated header was accepted as an independent semantic authority.
