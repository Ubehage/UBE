# Bounded byte-key indexing dependency - 2026-11-03

The native compiler's object-to-image symbol index needs sorted names and
cross-object lookup under its shared examined-byte/event budget. The existing
key-count cap alone cannot enforce those bounds: the independent eight-key
fixture examines 1,632 bytes while sorting only eight keys. The required change
extends the existing ByteKeys implementation; no second sorter, compiler naming
policy or independent worker mechanism is introduced.

`TryOrderByteKeysBudgeted` and `TryFindByteKeyRangeBudgeted` follow
[BYTE-KEY-CONTRACT.md](BYTE-KEY-CONTRACT.md). Original APIs retain their behavior.
The new lookup accepts a distinct immutable query arena, avoiding a concatenated
copy of object/image snapshots. The compiler-owned symbol inventory remains the
next consumer; these library gates do not implement or qualify it.

## Maintained gates

```powershell
rtk proxy powershell -NoProfile -File std-lib/tools/check-byte-keys.ps1 -DiagnosticOnly
rtk proxy powershell -NoProfile -File std-lib/tools/check-budgeted-byte-keys.ps1 -ReportPath bootstrap/out/byte-keys/d581599e9c194fc09201144400cbd1fb/report.json
```

The unchanged legacy suite passes 4,827,069 native assertions per stage,
90 observation rows per stage, all four original corruption controls and the
runtime observer audit. Report:
`bootstrap/out/byte-keys/d581599e9c194fc09201144400cbd1fb/report.json`;
20 groups, 24 commands, 60,986 ms summed command time. Both raw LLVM files are
80,452 bytes, SHA256
`8F94ACE9724200F5F575DE64D35414DD4FCB1FBBC1D15B1379C6B860A26AA299`.
Observed copying, allocation, work and root bounds retain their prior assertions.

The bounded suite passes 2,103,397 assertions per stage, including managed-root
capacity assertions. Report:
`bootstrap/out/byte-key-budgets/3ee6a94097e548c19912d8883bfe87e0/report.json`;
four groups and eight commands, 14,421 ms summed command time. Both instrumented
files have SHA256
`13AFD5E5E2016FA35F7ADDACD172FC49F8DC9A16AA8F2A493B0FE5C56AC33ABF`.

The reverse-order shared-prefix fixture sorts with exactly 1,632 observed byte
reads and 881 admitted events. A query from a separate arena uses 816 byte reads
and 416 events. Exact caps pass; one-below caps reject with the prior result
intact. Cancellation injected before every one of those admissions rejects
without publishing partial arrays/scalars. The gates also cover all four
allocation failure sites, full root capacity, empty/missing/cross-arena queries,
invalid budgets, maximum LongLong counters, preserved Err, input owners and
cleanup. Omitting budget-event observations is rejected through both stages.
Byte accounting is compared with actual instrumented array reads; event counts
are observed at admitted operation boundaries, not inferred from input size.

Initial bounded report `242b86e886e746ee9c04034698ea728d` had an incorrect test
expectation that a full-root lookup would consume no events. The focused native
diagnostic showed controlled failure5, unchanged scalar outputs, zero byte reads
and one already-admitted entry event. The contract retains admitted work on
failure; the expectation was corrected without changing production code. The
following passing report `b3365c940b4a4e1c9a2d2e38a4d88d62` predates capture of the
public wrapper in the final report above.

## Source and acceptance scope

ByteKeys.bas is 17,638 bytes, SHA256
`F49F8BAA1D1859C7466810821A4662ADADD7A16CA0FFCF08CE7EF262BCBAE346`.
Both gates use the hash-pinned source-built v2 cohort
`df15817344774026bebebfd1e9ae8eaf`. DiagnosticOnly is explicit and does not assert
a refreshed complete bootstrap. The bounded gate is registered immediately after
byte-keys in the full bootstrap and consumes that exact preceding report.
Private comparison observer signatures were updated in the semantic foundation
and whole-checker resource harnesses. The full current-source checker/resource
and frontend performance qualification remains required.

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-semantic-foundations.ps1 -DiagnosticOnly
```

The integrated arena and actual UBE worker/sharing suite passes 35 gate assertions
in `bootstrap/out/semantic-foundations/23c8a21b7b7a4b5d8020784f79499eb7/report.json`.
Both raw files are 993,369 bytes with SHA256
`1C182FDD5ECAD1EEA72F2517DE49674934AA65F87579A283391AA9C09D41759F`.
The diagnostic runner verifies both compiler artifact identities and captures
the current component source inputs. Its report explicitly leaves
sourceBuildCurrent and qualifiedFoundations false; integrated component success
does not replace the refreshed full-bootstrap gate.

Native binary readers were freshly rebuilt with the changed Core and pass
26 groups/55 commands in
`bootstrap/out/native-objects/fcea462e08aa452994b9e6fa3c9f8016/report.json`.
The generated-input comparison passes 224 groups/336 commands in
`bootstrap/out/native-object-inputs/00d02d40103d4cd28ca249bc223a8008/report.json`.
Commands are the object reader and check-generated commands in
`../compiler/UBE_Compiler_v3/NATIVE-OBJECT-EVIDENCE.md`, selecting these reports.
This retains the earlier header/name/symbol/relocation scope; it does not turn
raw decoding into validated identity membership or linked fixup proof.
