# Named native relocation target evidence

The named-target prerequisite of First checked native executable passes its
focused two-stage and retained-artifact gates. This qualifies target anchors,
not relocation values or complete instruction correspondence. The full native
executable goal remains active.

## Exact commands and results

Run from the repository root:

~~~powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check.ps1 -DiagnosticOnly
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-named-relocations.ps1 -ReaderReport bootstrap/out/native-objects/a6816c4e94884b8585834609f04d3429/report.json -BindingReport bootstrap/out/native-extent-bindings/1ee39e22ed974005bec0d08bcd718b3f/report.json
~~~

Both commands passed on their first qualification runs.

| Gate | Report under bootstrap/out | Groups | Commands | Summed child milliseconds |
| --- | --- | ---: | ---: | ---: |
| Component readers | native-objects/a6816c4e94884b8585834609f04d3429/report.json | 70 | 143 | 436815 |
| Named target associations | native-named-relocations/0c9070fbe2e5457f861dfccc5faeaa0d/report.json | 736 | 736 | 31100 |

The component gate passed 27,276,878 assertions per stage, including its existing
binary, symbol, inventory, data, retention, unwind, instruction, function-index,
leaf and leaf-binding cases. Seven new synthetic configurations distinguish
defined external/static data, defined functions, undefined data/functions and
zero-filled data. Object and image target offsets deliberately differ.
Twenty-seven malformed/unsupported/ambiguous target cases, eight owner-state
changes per configuration, exact/one-below observed byte/event budgets, every
cancellation admission, no-allocation/no-copy/Err preservation, full root-pressure
refusal and unchanged old outputs pass. Two deliberately corrupted output bridges
(address and section) are rejected in each stage. No numeric cap changed.

The actual gate compares all 144 qualified generated objects with their linked
images. Independent SDK-offset symbol and section decoding supplies image anchor
fields without using production lookup output or patched instruction bytes.
There are 288 positive unit comparisons, including 64 empty-code-relocation
comparisons, 11,392 named target observations and 32 explicit unsupported-target
rejections through the two readers. This is 5,696 named references and 16 anonymous
references in the object corpus, each observed twice. An incorrect expected RVA
and removal of a required linked target produce 448 rejected controls. Generated
and mutated images are inspected as bytes; this gate does not execute them.

The 89 component input records and 383 actual-gate input records are rechecked by
their respective gates. A final SHA-256 audit of all 254 distinct captured paths
also found no changes. git diff --check passed (line-ending notices only).
Historical object/image identities are retained from the
passing extent-binding report; historical source inputs are not represented as
a current full-source bootstrap pass. DiagnosticOnly uses the existing pinned
bootstrap tools while compiling the current reader sources.

## Identities and ownership

NativeRelocations.bas is 3,755 bytes, SHA-256
0031C9E747321A01D623BF8DDCDBB95B9A8BB70B7E8DF174F5A57357572264F0.
Both raw component LLVM files are 1,552,959 bytes, SHA-256
6B8AB8EDCB60A606ADF6BE4C5BB8AEC09D1012339C9D26D892D080D08B77E792.

The accepted bootstrap selection remains df15817344774026bebebfd1e9ae8eaf.
Exact source, tool, executable, transport and object/image hashes are recorded in
the reports. NativeRelocations is registered after NativeBindings in the production
manifest and included in the maintained component gate, already registered by the
full bootstrap. The full bootstrap was not rerun for this isolated prerequisite.

NATIVE-RELOCATION-IMPLEMENTATION.md specifies borrowing, atomic publication,
bounded lookup work, cancellation and supported inputs. This adds no owned array,
shared mutable state, compiler stage, external inspector or host primitive.
Source consistency during production builds remains the owner's responsibility.

## Anonymous-data diagnosis and remaining work

The 16 anonymous references occur in eight O0 private error-support objects,
two per object, to their STATIC .rdata section-definition symbol. LLD's retained
image symbol table has no corresponding named definition. The resolver deliberately
rejects these rows even if a same-named section exists elsewhere.

bootstrap/out/native-anonymous-constant-diagnostic.json records exact object/image
identities, object section bytes, references and image occurrences. Each affected
object's complete read-only section is 31 bytes: the two stack-error strings.
Each corresponding image has exactly one identical contiguous sequence in an
initialized read-only data section, at file offset 22664 / RVA 29320. This focused
byte-search observation is a lead for independent constant-contribution mapping,
not a production mapping implementation or an acceptance gate. A production
consumer still needs explicit bounded search/ownership and ambiguous, missing,
mutated, overlapping and permission-failure tests; it must not infer identity
merely by inverting the same fixup being checked.

Next qualify anonymous constant contributions and relocation value/instruction
comparisons. Pointer-cell contents, import/TLS meaning, full unwind/stack/reserve,
startup/API/refusal closure, debug validation, build ownership/tool launch, held-file
identity and publication remain mandatory. Named target resolution establishes
none of those properties. No native-executable completion is claimed.
