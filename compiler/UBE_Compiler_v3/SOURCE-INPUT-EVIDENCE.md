# Source-input qualification

Historical source-input snapshot: the 470-check cohort below remains preserved.
The subsequent scanner/Unicode consumer reruns its foundation gates and expands
production CLI coverage in the current 501-check qualification. Use
[`SCANNER-EVIDENCE.md`](SCANNER-EVIDENCE.md) for the current selection, exact
identities and supported recognition limits; later source renames/manifest
changes deliberately mean the old cohort is not the current source set.

The active goal implements the next item in `Roadmap.md`. Its acceptance contract
is `SOURCE-INPUT-CONTRACT.md`; independent expectations precede execution in
`tests/source-input/ORACLES.md`. The combined current-source qualification passed
470 acceptance checks. Earlier exploratory reports are diagnostic history;
the selected build and exact evidence below establish this result.

## Delivered boundary

- Complete native `Main.bas`, `SourceInput.bas` and `SourceFile.bas`, built by
  `UBE_Compiler_v3.UBE` against the actual `../../std-lib/UBECore.UBE` Reference.
- Strict incremental UTF-8 and LF/CRLF policy over owned ByteBuffer bytes,
  independent exact snapshots, zero-based original byte/scalar offsets and
  one-based line/scalar columns. Initial BOM remains in storage; embedded zeroes
  and original normalization/newlines remain unchanged.
- Recoverable bounded byte-file reading and Unicode command arguments in
  UBECore's explicit host primitive boundary. No ordinary file/text algorithm
  was imported from an archived compiler or library.
- Bounded v2 direct source references, envelope/identity/Startup validation,
  conservative Public-only package boundaries and explicit unsupported cases.
- Explicit entry-admission status and initialized caller failure records prevent
  managed-root capacity failure from becoming accidental process success.

## Maintained acceptance

Run from the repository root:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1
```

The gate builds current seed/runtime, both v2 stages and the LLVM fixed point,
then retains every earlier library proof and adds source-reference, byte-file,
source-input and entry-admission regressions. A new `current.json` is published
only after all assertions and immutable input/artifact comparisons pass.

The source consumer gate is
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-source-input.ps1`.
It checks complete unchanged source, both stages, actual declared references,
independent native values/positions, every split of its boundary vectors,
snapshot independence, stale Err, allocation/I/O/cleanup failures, observed file
mutation, Unicode CLI, private native workers and executed allocation/copy costs.

## Accepted build and provenance

The accepted run is `bootstrap/out/v2/50edfbded639485bb287e2541b428ff2/`.
It inventories 242 source/fixture/contract inputs and 11 child proofs. The
immutable core manifest has 136 checks; the final manifest has 470. The single
recorded build took 166125 ms; that observation is not a full compiler benchmark.

| Identity | SHA-256 |
|---|---|
| Final `manifest.json` | `D6F484A8B725410F43AB3C9EE5292744E8E78CB7868DB4396AA88E92884897AA` |
| Immutable `source-manifest.json` | `340106F0BF5A1CBF35F4D54F37884B94DE5965D5424257DA8DCDA9C3EE86C0F1` |
| Selected `ube-stage2-v2.exe` | `C15F4C29EF54DCB9A3922CAB27D114989CB3618DDDC188DE967A5BBC96FD4E6C` |
| `bootstrap_runtime.o` | `F354F653A3819161B616FDCA3B342C4CD37C68708DFE924704836116FE98C4E2` |
| Helper-built `bootstrap/out/v3/ube.exe` | `B0B513BED4495B339D26601776815F93BD3E9FF895C01C16BD8E1C6F906DD3A8` |

The final JSON records complete tool versions, target/flags, commands, source
hashes and artifacts. Stage-one and stage-two outputs are compared as raw LLVM;
stage-two self-compilation reaches an exact LLVM fixed point. The source-only
chain uses no restored or archived compiler executable. Its shared-library
reference route uses the actual declared library manifests and complete source,
not stripped bodies or replacement production manifests.

| Gate | Report checks |
|---|---:|
| Core seed/runtime/v1/v2/fixed point | 136 |
| Native scalar values | 66 |
| Ordinary records | 8 |
| Managed substrate | 8 |
| Compiled managed values | 52 |
| UTF-8 decoder | 8 |
| ByteBuffer functions | 13 |
| ByteBuffer costs/ownership | 5 |
| Direct source references/envelopes | 91 |
| Executable entry admission | 6 |
| Byte-file primitives | 4 |
| Source consumer | 73 |
| **Total** | **470** |

New child report paths below are relative to `bootstrap/out/`; their hashes and
all inherited child reports are pinned in the final manifest:

- `source-reference/5189cd61cfca4671b802e72734b95228/report.json`
- `entry-admission/d08d8719c95742268ab777e219882c81/report.json`
- `file-bytes/c7e39edd452542a19eee94b8238f2f1b/report.json`
- `source-input/19415a03a5fe4285a844e6b93193c0b8/report.json`

The source-consumer report contains 5716 exact-runtime and 100233 instrumented
native assertions per stage: 211898 executed CHECKs across four native test
executables, including repeated byte comparisons, not that many distinct cases.
The byte-file native probe separately passes 927 assertions. The predefined
vectors test every two-way split, including UTF-8/BOM/CRLF boundaries, rather
than claiming all possible partitions or exhaustive source programs.

Allocation, publication and file faults assert complete prior document bytes
and all metadata remain intact. Actual file shrink/growth occurs after the size
query and before the first read. Dual memory/close failure preserves the primary
classification, reports cleanup's Err and retains explicit token ownership.
Stepwise reader tests cancel by closing before the first read and after one byte
of a longer file; stale-token reads make no further OS call. Managed early-return
scope tests are separate. Neither the whole-file helper nor CLI exposes a
cancellation request interface yet.

## Measured costs

There are 32 observations: two stages, direct intake and file loading, at byte
sizes 0, 1, 31, 4095, 4096, 4097, 16384 and 65536. Tests instrument executed Feed
calls, allocator requests, actual growth/append/snapshot stores, OS read calls
and native scratch publication. Direct cost measurement starts after input
provisioning and Begin, with runtime bookkeeping already available. File loading
includes open/read/close/publication, with its counted path prepared beforehand.
Cost fixtures are ASCII; UTF-8 correctness uses independent mixed-scalar vectors.

At 65536 bytes both stages observe:

| Observation | Direct intake | Complete file load |
|---|---:|---:|
| UTF-8 Feed calls | 65536 | 65536 |
| Growth payload copies | 61440 | included below |
| Append payload copies | 65536 | included below |
| Snapshot payload copies | 131072 | included below |
| Total payload copied bytes | 258048 | 323584 |
| Allocation requests | 8 | 12 |
| Requested allocation bytes | 259064 | 328990 |
| Requested calloc zero-initialization bytes | 259064 | 263336 |
| OS read calls | 0 | 17 |
| OS bytes returned / scratch bytes published | 0 | 65536 / 65536 |

Direct growth copies are less than 2N, appended bytes exactly N, snapshots at
most 2N and total payload copies less than 5N for N > 0. File scratch publication
adds N, giving less than 6N for the tested complete loads. Zero input copies
zero payload bytes, although file loading still needs fixed native scratch.
Each reader owns one 65536-byte native scratch allocation. Path handling and
allocation headers explain additional requested memory; these are not payload
copy counts. Requested calloc bytes are not a measurement of physical zeroing.

The instrumented test processes sampled peak working sets of 5197824 and
4898816 bytes, including the C harness/runtime. Sampling is not allocator live
memory and may miss short-lived peaks. Direct 65536-byte intake was observed at
12925.8 and 13268.6 microseconds in this run; these are individual warm
observations, not a throughput promise or comparison with a full compiler.
Four native workers each run 16 rounds with private state and immutable shared
256-byte input. Tests explicitly assert zero residual roots, GC payloads and
file handles at their cleanup gates.

## Additional checks and diagnostic history

`rtk proxy powershell -NoProfile -File bootstrap/tests/v2_usage_tests.ps1` passed
native output, invalid-constant rejection, prior-output preservation, successful
replacement and a synthetic changed-C-header identity rejection. The isolated
synthetic selection never replaces the real accepted selection. The helper now
checks every gate-inventoried input, including C headers and semantic contracts;
unrelated prose is not inventoried.
Report: `bootstrap/out/v2-usage/fdfd334238ea46e492f9bcc1e7fb6734/report.json`.

The real consumer was built with:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/compile-v2.ps1 -Source compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE -Output bootstrap/out/v3/ube.exe
```

Its compile record is
`bootstrap/out/v2/compilations/fbf43d2a72354066968a8fa2dcfe42f4/compile.json`.
The executable is 187392 bytes. Running `--check` on its own Main.bas returns
exactly `error UBE1012: source checking is not implemented` and exit 1, with
empty stderr. That is successful ingestion followed by the deliberate checking
boundary, not compiler-program success. CLI tests assert no output files are
created or resized in the isolated working directory; they do not claim hashes
of every unrelated pre-existing file were compared.

Pre-fix diagnostic evidence remains below `bootstrap/out/`:

- `root-capacity-review/report.json`: actual 1048576-root exhaustion returned
  neutral Main 0 and unchanged Try outputs through both earlier accepted stages.
- `source-reference/52cbc464bd854105924150e9f295e3ae/before-fix-regressions.json`:
  small short-line/EOF fixtures reproduced runtime index/slice termination.
- `native-envelope-bom/df0a88045322409db0881880d6f6da9a/before.json`: both earlier
  stages rejected valid initial BOMs in native source/project headers.

The final gates cover each corrected case, preserve established native/managed
binding diagnostics and include ordinary type/procedure source-boundary errors.
Local `bootstrap/out/source-evidence-audit.json` rechecks 2228 unique source,
tool, report and artifact identities against current disk bytes, all 470 checks,
the 11 proof cohorts, 32 measurements and helper-built native behavior.

Retained structural checks also passed:

- `rtk proxy powershell -NoProfile -File compiler/archived/verify.ps1`:
  367 original/archive files, 13 recorded relocation changes, 9 preview hashes,
  28 previous library files, 7 manifests/139 inputs and 21 historical scripts.
- `rtk proxy powershell -NoProfile -File std-lib/tools/check-inventory.ps1`:
  710 catalog rows, 175 runtime names, 73 historical hooks and 52 link targets.
- `rtk proxy powershell -NoProfile -File lang-doc/grammar/fixtures/validate-fixtures.ps1`:
  202 core/19 conditional productions and 12 fixtures in four categories.
- `rtk proxy powershell -NoProfile -File docs/assets/tools/validate-docs.ps1`:
  265 HTML files, after the public documentation changes.
- `rtk proxy powershell -NoProfile -File std-lib/tools/check-native-example.ps1`:
  four public-example assertions, retaining the documented bare-body scope;
  report `bootstrap/out/native-example/1343243810794eb390ac70e6c82ca0b1/report.json`.
- `rtk proxy powershell -NoProfile -File bootstrap/out/audit-source-handoff.ps1`:
  PowerShell/JSON syntax, local Markdown links, production manifest targets,
  unchanged protected instructions and tracked whitespace. This local audit is
  separate from native qualification; it is not a browser/accessibility test.

## Supported limits

This is a source-ingestion consumer, not a usable language compiler. `--check`
returns a controlled unavailable-check diagnostic after successful ingestion;
it never reports a source program as checked or emits a compiled program.
Native/legacy input envelope interpretation, tokenization and semantic checking
remain future v3 work. Bootstrap validation of the compiler's own native build
inputs is a separate, bounded prerequisite.

The driver limits source bytes to 16777216 and uses reads of at most 4096 bytes.
Zero-based compiler arrays are qualified; arbitrary array lower bounds are not.
The length/probe policy detects observed shrink/growth, not all concurrent edits
or an atomic filesystem snapshot. A real failed close preserves explicit token
ownership for retry; final process exit delegates unreleased process resources
to OS teardown. Neither such failure nor reported failure after actual release
is described as successful close.

V2 accepts up to 16 independent direct Public-only source library references,
256 sources per package, no nested dependencies or package/module qualification,
and globally unique procedure/type declarations. Standalone shared-library
output, full package lookup and foreign ABI remain unqualified. Exact restrictions
are in `../UBE_Compiler_v2/tests/source-reference/CONTRACT.md`.

The host adapter currently targets Windows x86-64. Its narrow C exception and
removal condition are in `../../std-lib/FILE-BYTES-CONTRACT.md`. Counted byte
storage is qualified; builtin String lifecycle is separate. Diagnostics still
use existing bootstrap String formatting, whose extreme host-heap failure may
use the existing controlled runtime fatal path. No new String implementation
or general recoverability proof is implied.

Four native C callers qualify private input instances and immutable sharing,
not UBE CallNew or compiler scheduling. Allocation measurements are actual
requested bytes, not physical zero stores or total RSS; process memory is
reported separately. Byte-identical LLVM is checked; executable binary
reproducibility is not claimed.

## Next handoff

Define the scanner and native/legacy source-envelope acceptance around these
exact SourceDocument snapshots, including synthetic final NEWLINE behavior,
tokens and independent diagnostic oracles. Implement only that next consumer's
actual library needs; no archived phase interface or scheduler is inherited.
