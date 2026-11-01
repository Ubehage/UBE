# Bounded project CLI and diagnostic contract

Frozen before project CLI/loader implementation. This implements the existing
[project-input contract](PROJECT-INPUT-CONTRACT.md); it changes no source syntax,
project-file language, identifier folding or worker ownership. The source-only
CLI's existing exact process oracles remain acceptance requirements.

## Invocation and exit status

Accept `--check <project.UBE>` and `--check <project.UBE> --jobs N`. Extension
matching is ASCII case-insensitive; option spelling/order is exact. Default
budget is one. N is a nonempty ASCII decimal digit sequence with numeric value
1..4; leading zeroes are allowed. Signs, whitespace, fractions, overflow,
repeated/unknown options and missing values are usage failures. No environment
worker default or implicit source/library search is added. `--jobs` applies only
to project input. Both budgets 1 and 4 invoke the same `TryParseSources` operation.

Exit 2 is usage or command-argument transport failure. Exit 1 is any rejected,
unsupported, cancelled or otherwise unfinished check. Even complete project
syntax acceptance prints exactly `error UBE1012: source checking is not
implemented` plus LF once, returns 1, and creates no output artifact. Semantic
checking and executable production are outside this deliverable. Exit 0 is not
introduced as an apparent successful build.

Keep all existing source-only usage/error lines byte-identical. When a project
argument is present but its jobs/options are invalid, print exactly:

```text
usage: ube --check <project.UBE> [--jobs N] (N: 1..4)
```

Otherwise retain the existing usage line. Failed counted command-argument
transport retains `error UBE1010: cannot read command argument`.

## Project diagnostics

The following codes/messages describe compiler policy, not library failures.
Every primary project diagnostic prints one header line:
`error CODE: MESSAGE (next lines: path, line, column, byte)`.
Follow it with the owning manifest/input path, then original one-based line,
one-based scalar column and zero-based byte offset, each on its own line. Use
LF separators. Retained metadata also contains the exclusive end witness;
the CLI does not fabricate a source range or label a byte offset as a column.

| Code | Exact MESSAGE | Witness/disposition |
| --- | --- | --- |
| UBE1300 | missing or malformed project header | First meaningful line; bad version token when present |
| UBE1301 | project format version is not implemented | Valid unsupported version's digits |
| UBE1302 | malformed project entry | First malformed separator/value/trailing token boundary; exact NUL byte anywhere in manifest text |
| UBE1303 | unknown project key | Key |
| UBE1304 | duplicate scalar project key | Second key |
| UBE1305 | missing required project key | EOF |
| UBE1306 | invalid project value | Original value span |
| UBE1307 | project input facility is not implemented | Valid unsupported facility/path form's declaration |
| UBE1308 | invalid project path | Declaration value, or invocation position 1:1:0 |
| UBE1309 | project resource limit exceeded | Declaration/input whose admission exceeds the bound |
| UBE1310 | insufficient project storage | Current owning input/declaration, or 1:1:0 before intake |
| UBE1311 | cannot read project input | Owning path/declaration; retains exact lower-level failure |
| UBE1312 | duplicate project source path | Later declaration, including an opened-file alias within a package |
| UBE1313 | invalid project reference | Self, repeated reference or referenced executable |
| UBE1314 | project reference cycle | Edge whose opened identity reaches an ancestor manifest |
| UBE1315 | duplicate package identity | Referenced package's Name value |
| UBE1316 | duplicate source identity in package | Later source's existing UBE_Name witness |
| UBE1317 | project input was cancelled | Current intake position, or 1:1:0 before intake |
| UBE1318 | cannot start source worker | Canonical source's retained path and admission position |
| UBE1319 | cannot wait for source worker | Retained owning source, or root path when source-independent |
| UBE1320 | invalid project input request | Root invocation position 1:1:0 |

Project resource/admission failures are not syntax errors. Valid CLASS/FORM/
CONTROL, legacy input and other parser-deferred families retain the existing
source syntax/deferred code. UTF-8/newline/read failures retain their existing
SourceFailure classification; add the associated input path, without changing
the independent two-argument source CLI's output. Body failures retain the exact
existing scanner/parser diagnostic, preceded by the canonical source path line.

The path line quotes the entire UTF-8 path. Escape ASCII quote and backslash as
`\"` and `\\`; ASCII controls and DEL use uppercase `\xHH`. Preserve every other
UTF-8 byte, including non-ASCII filename spelling. The path is metadata display,
not source text conversion, Unicode normalization, a new String facility or a
host path comparator. A focused exact-output/failure probe must establish the
existing bootstrap formatting route before relying on it. No new output host
binding is authorized by this contract.

The focused existing-bootstrap prototype in
`bootstrap/out/project-display/386f937d1a4849cdbcbd3356457a7b96/report.json`
(SHA-256 `28F7B401D538D1E7B211528F939D25B0DEE8E9A290445956A5F63BAD7634BF19`)
passes exact Unicode/quote/backslash/control/NUL/DEL output, empty input,
over-limit rejection with old result retention and equal raw LLVM through both
previous accepted stages. It constructs independent per-byte display pieces and
joins once, using existing bounded String bootstrap primitives for metadata
display only. It is development evidence, not full String semantics or a
formatter allocation/root-failure proof.

The maintained `ProjectDisplay.bas` component now supplies that bounded path
display under PROJECT-DISPLAY-CONTRACT.md. Its actual allocator/root/concurrency
regression passes through both tools, including the retained pre-fix bootstrap
String allocation crash. PROJECT-INPUT-EVIDENCE.md records exact commands and
scope. Complete-message diagnostic preparation and the initial CLI process/fault
gates now pass through both tools; PROJECT-INPUT-EVIDENCE.md records the exact
current proof and the still-pending source/performance qualification.

If diagnostic preparation cannot enter managed code or finish its bounded
formatting, use the allocation-free fallback line:
`error UBE1310: insufficient project storage` plus LF. Do not publish a partial
path/coordinate diagnostic. Retain the original primary structured failure for
callers; a formatter failure must not overwrite it.

## Ordering and cleanup

Validate each complete manifest's transport/header/entries and required metadata
before opening its declared sources. Within a version-one manifest, transport
validation precedes structural/schema validation; only a structurally valid
manifest reaches capability rejection. An earlier valid unsupported facility
therefore does not hide a later malformed entry or a missing required field.
Choose structural failures by original declaration position. Resolve equal-position failures in the
order transport, malformed structure/value, then unsupported capability. Missing
required fields use EOF; use Name, Kind, Startup, Source order when several are
missing at that same position. Library Startup/StartupForm is an invalid
combination, rather than accepting it as an unsupported executable capability.
Detect that combination regardless of whether Kind precedes StartupForm. A valid
unsupported header version is rejected at its version digits without claiming to
validate that future version's body as version-one syntax.

Canonical intake is root manifest, root sources in Source order, direct-library
manifest, then its sources in Source order. It produces the existing root-first
source IDs. Within a manifest's declarations, normalization/resource failures
use declaration order. Source/module duplicate identity is package-local;
manifest identities are compared across the dependency graph. A source's opened
identity is not used as its compiler SourceId or as a package name.

Before rejecting a library's further Reference as unsupported, recognize an
opened identity naming itself/an ancestor as self/cycle. This bounded check
does not recursively load a third compilation package or expose its declarations.
No physical tree-containment claim is added. Sources with retained leading
parents are rejected under the adopted strict-relative containment rule; a path
that leaves and re-enters its root does not become a supported form through
host-specific case assumptions.

All discovery/intake validation precedes body worker admission. After admission,
source failures use the smallest canonical source ID, preserving the existing
infrastructure/cancellation/drain rules. A secondary close/release failure keeps
the original primary result and explicit live token for retry. If final CLI
cleanup still fails, append exactly `error UBE1321: could not release project
input; operating system cleanup is required` plus LF and return 1. Never discard
an owned live token or report a clean completion while a worker is undrained.

## Independent acceptance additions

Freeze exact process cases before production CLI changes: both invocation forms,
uppercase extension, all budgets, leading-zero budget, every invalid numeric/
option form, source-only jobs rejection, absent arguments, non-ASCII/quoted path,
every diagnostic above, BOM/CRLF coordinates, source/body error association,
once-only UBE1012, no artifact, true formatter/root failure and retained close
failure. Retain the existing 217 strict CLI and 41 local process oracles; changed
capability cases must be explicitly identified, never silently removed.

The contract defines the requirements; executed loader/CLI evidence is recorded
separately in PROJECT-INPUT-EVIDENCE.md. Passing those development cases does not
complete source-cohort or parallel-performance qualification.
