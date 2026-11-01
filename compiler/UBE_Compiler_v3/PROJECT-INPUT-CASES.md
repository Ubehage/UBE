# Independent project-input expectations

Status: definition cases for review; no production project loader has passed
these cases. Manifest grammar comes from `lang-doc/project-files.md` and the
project-reference audit, not bootstrap output. Exact CLI codes and ordering are
frozen in PROJECT-DIAGNOSTICS.md. Names below describe dispositions,
not new production identifiers.

## Manifest cases

Use these exact UTF-8 lines as the common executable, with LF after every line:

```text
UBE-Project 1
Name = "App"
Kind = "Exe"
Startup = "Main"
Source = "src/Main.bas"
```

Accepted manifest metadata is Name `App`, Kind Exe, Startup Main, one Source
spelled `src/Main.bas`, Optimization 2 and DebugInformation Full. Declaration
order and original document bytes are retained. The source value is line 5,
columns 11..23 excluding the quotes (one-based, last exclusive), bytes 67..79
(zero-based, last exclusive). These offsets are hand-specified, not inferred
from a loader result. Verify their consistency before using them as an oracle.

Each row changes only the indicated common lines. A failure witnesses the first
listed offending header/key/value in original coordinates. Missing-field failure
uses EOF; it must not invent a nonexistent source span.

| Case | Change | Expected disposition |
| --- | --- | --- |
| Ordinary executable | None | Accept the metadata above; source work still pending |
| Header BOM | Prepend EF BB BF | Accept; every later byte offset increases by 3, scalar positions do not |
| CRLF | Replace every LF with CRLF | Accept; source-value first byte increases by 4, line/column unchanged |
| Comments/blanks | Prepend blank, then `  ' comment`, then a tab-only line | Accept; the first meaningful line is still the header |
| Key case | Replace `Name` by `nAmE`, `Source` by `sOuRcE` | Accept; preserve value spelling |
| Horizontal spacing | Replace line 2 by `  Name<TAB>=<TAB>"App"  ` | Accept; preserve original positions |
| Missing header | Delete line 1 | Malformed header at original first meaningful line |
| Future header | Replace line 1 by `UBE-Project 2` | Unsupported format version, digit at line 1 column 13 |
| Malformed version | Replace line 1 by `UBE-Project x` | Malformed header, `x` at line 1 column 13 |
| Late header | Insert `Name = "Early"` before line 1 | Malformed header at the inserted Name; do not search onward |
| Unquoted value | Replace line 2 by `Name = App` | Malformed value at `App` |
| Missing equals | Replace line 2 by `Name "App"` | Malformed entry at the missing separator boundary |
| Unterminated value | Replace line 2 by `Name = "App` | Malformed value at end of line |
| Trailing text | Replace line 2 by `Name = "App" junk` | Malformed entry at `junk` |
| Inline comment | Replace line 2 by `Name = "App" ' note` | Malformed entry; no inline-comment extension |
| Escaped quote | Replace line 5 by `Source = "src/A""B.bas"` | Lexically decoded value `src/A"B.bas`; later host path disposition separate |
| Unknown key | Append `Mystery = "x"` | Unknown key at Mystery |
| Duplicate name | Append `NAME = "Other"` | Duplicate scalar at second Name, regardless of equal/different value |
| Duplicate kind | Append `kind = "Exe"` | Duplicate scalar at second Kind |
| Duplicate startup | Append `Startup = "Main"` | Duplicate scalar at second Startup |
| Missing name | Delete line 2 | Missing required Name at EOF |
| Missing kind | Delete line 3 | Missing required Kind at EOF |
| Missing startup | Delete line 4 | Missing required Startup at EOF for Exe |
| Missing sources | Delete line 5 | Missing required Source at EOF |
| Wrong startup | Replace line 4 by `Startup = "Other"` | Invalid executable Startup value |
| Unknown kind | Replace line 3 by `Kind = "Widget"` | Invalid Kind value |
| Library metadata | Replace Kind by Library and delete Startup | Valid library metadata; unsupported as this consumer's root |
| Library startup form | Same library plus `StartupForm = "Window"` | Invalid Library/StartupForm combination, not accepted unsupported metadata |
| Explicit settings | Append Optimization 3 and DebugInformation Line | Accept and retain 3/Line; no code-generation claim |
| Size setting | Append `Optimization = "Size"` | Accept and retain Size |
| Invalid optimization | Append `Optimization = "4"` | Invalid setting value |
| Invalid debug setting | Append `DebugInformation = "Verbose"` | Invalid setting value |
| Duplicate setting | Append two Optimization entries | Duplicate scalar at the second entry |
| Known resource | Append `Resource = "src/App.UBR"` | Known valid facility outside the bounded consumer; explicit unsupported outcome |
| Known startup form | Append `StartupForm = "Window"` | Known facility outside bounded MODULE consumer; explicit unsupported outcome |
| Known binary reference | Append a well-formed LibraryReference triple | Known facility outside bounded source-reference consumer; explicit unsupported outcome |
| Zero scalar | Place byte 00 in a value | Controlled input/path/name failure with original byte witness; never truncation |
| Invalid UTF-8 | Place FF in a value | Existing source-input UTF-8 failure before manifest interpretation |
| Bare CR | End one line with CR without LF | Existing source-input newline failure with original witness |
| Name folding | Name `[App]` and a referenced package named `app` | Duplicate package identity after established bracket decoding/simple folding |
| Unicode name | Name `Æther` | Valid identifier, retained spelling and established Unicode simple-fold identity |
| Invalid name | Name `Two Words` without identifier brackets | Invalid package identifier |

## Path and graph cases

Use an invocation directory `C:/work`, root manifest `app/App.UBE`, root Name
App, and library manifest `core/UBECore.UBE`, Name UBECore, Kind Library. Both
packages otherwise have the required ordinary metadata and existing native
MODULE sources. No host/environment search is permitted.

| Root or library declaration | Expected result |
| --- | --- |
| Root Sources `src/B.bas`, `src/A.bas` | Root source IDs 0=B, 1=A; no alphabetical sort |
| Root Reference `../core/UBECore.UBE`, library Sources `Z.bas`, `A.bas` | Packages 0=App, 1=UBECore; source IDs root B=0, A=1, core Z=2, A=3 |
| Library Reference absent | Valid direct dependency; both packages retained with original manifests |
| Source `src/./Main.bas` | Normalize inside owning package to `src/Main.bas` |
| Source `src/nested/../Main.bas` | Same normalized source identity as `src/Main.bas` |
| Both of those Source spellings | Duplicate normalized source error at later declaration |
| Source `../outside.bas` | Source-tree escape; no worker admitted |
| Source `C:/outside.bas` | Absolute Source error; no worker admitted |
| Source `C:relative.bas` | Drive-relative Source error; no per-drive lookup |
| Reference `../core/UBECore.UBE` | Legal sibling reference; its Sources resolve against core, not app |
| Reference `C:/work/core/UBECore.UBE` | Absolute Reference error |
| Reference `../app/App.UBE` | Self-reference error |
| Two References with normalized identical paths | Duplicate reference error at later declaration |
| Referenced manifest Kind Exe | Invalid reference target kind |
| Referenced library Name Other | Valid general-library facility, explicitly unsupported by bounded UBECore consumer |
| Library points back to root | Cycle error, not successful truncated discovery |
| Library references a third library | Explicit unsupported transitive dependency; never silently drop it |
| App named `ubecore` while referring to UBECore | Folded package collision |
| Two source envelopes named `ModuleA` and `modulea` in App | Folded duplicate source identity within package |
| One ModuleA in App and one modulea in UBECore | Distinct package-qualified source identities |
| Missing root/reference/source | Controlled owning-path diagnostic, never empty success |
| CLASS/FORM/CONTROL listed as a source | Recognize envelope and explicitly defer unsupported body grammar |
| Envelope/extension mismatch | Existing controlled mismatch diagnostic with original source witness |
| Source format version 2 | Existing unsupported-format diagnostic |

The owner adopted the lexical/opened-file identity route. Within a package,
different physical files in a case-sensitive host directory remain distinct;
aliases/hard links identifying the same opened file diagnose at the later
declaration. Junctions/symlinks may lead outside the lexical source tree; no
physical containment is claimed. A Source spelling which leaves then re-enters
its root remains unsupported under the strict-relative rule. An identity-query
failure still closes or retains its explicit token for retry, preserving the
primary failure. These cases require actual host fixtures, not simulated path
case-fold comparisons.

## Exact diagnostic anchors

These use the common ASCII LF manifest above and the exact header/messages in
PROJECT-DIAGNOSTICS.md. All intervals are original zero-based bytes, last
exclusive. Missing fields use an empty EOF interval. CLI path quoting and the
three numeric lines follow that separate frozen contract; no production reader
has supplied these expectations.

| Case | Change | Expected code and first witness |
| --- | --- | --- |
| Diagnostic future version | Header version 2 | UBE1301, bytes 12..13, line 1 column 13 |
| Diagnostic unknown key | Append `Mystery = "x"` | UBE1303, bytes 81..88, line 6 column 1 |
| Diagnostic duplicate name | Append `NAME = "Other"` | UBE1304, bytes 81..85, line 6 column 1 |
| Diagnostic unquoted value | Line 2 `Name = App` | UBE1302, bytes 21..24, line 2 column 8 |
| Diagnostic unterminated value | Line 2 `Name = "App` | UBE1302, empty bytes 25..25 at EOL, line 2 column 12 |
| Diagnostic trailing text | Line 2 `Name = "App" junk` | UBE1302, bytes 27..31, line 2 column 14 |
| Diagnostic missing name | Delete line 2 | UBE1305, empty bytes 68..68 at EOF, line 5 column 1 |
| Diagnostic missing startup | Delete line 4 | UBE1305, empty bytes 64..64 at EOF, line 5 column 1 |
| Diagnostic missing sources | Delete line 5 | UBE1305, empty bytes 57..57 at EOF, line 5 column 1 |
| Unsupported facility before malformed entry | Append Resource then an unquoted Name value | Structural UBE1302 precedes capability rejection |
| Unsupported facility with missing field | Delete Name and append Resource | UBE1305 at EOF; the manifest is not structurally valid |
| Library kind after startup form | Valid Library metadata with StartupForm before Kind | UBE1306 at StartupForm, independent of scalar-key order |

For an appended key, an initial BOM increases byte offsets by 3 and preserves
line/column; CRLF increases the appended line's first byte from 81 to 86.
Malformed UTF-8/newlines keep their existing transport witness. A NUL inside a
quoted value is a malformed project entry at that original zero byte, rather
than a truncated value. A doubled quote is valid manifest decoding; a decoded
quote inside a path is separately rejected as an invalid host path.

## Publication, ordering and resource expectations

- Discovery failure admits zero source workers and retains the complete old
  project result. Earlier manifest/discovery error wins in declaration order.
- Accepted work at budgets 1/2/4 has identical complete metadata, source bytes,
  tokens, nodes, metrics and diagnostic positions. Worker IDs/completion order
  may differ. Earliest body error is the lowest canonical failing source ID.
- Cancellation before discovery publishes nothing; during intake it closes or
  retains its explicit close owner; during work it stops admission and drains.
- A start/wait/storage/root/close failure preserves the earlier primary failure
  and all older published metadata/documents/graphs. No partial vector escapes.
- Root/reference manifests and all source/path metadata have explicit bounds,
  checked aggregate sums and independently tested exact-limit/one-over cases.
- A successful syntax-only project still receives the existing nonzero semantic
  checking unavailable outcome, once. It creates no executable artifact.
- Independent simultaneous project requests share no mutable manifest/path/work
  state and each respects its one bounded worker budget.

These are acceptance obligations. They remain unverified until a native UBE
project consumer and its independent tests execute them.
