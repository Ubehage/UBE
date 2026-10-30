# VB6 and VBA runtime inventory

Status: coverage proposal for the fresh UBECore; reviewed against Microsoft
reference sources on 2026-10-30. No row claims an implemented or frozen new
UBECore API. Placement labels are planning classifications, not new package
or language decisions.

## Scope and reading rules

This list covers the shared VB6/VBA runtime function families, their published
String-returning forms, and statements that need runtime/library services.
VBA7 conversion additions and Macintosh/Office-for-Mac extensions are identified
separately. Desktop objects, controls, constants, language datatypes, and UBE
extensions belong in the companion inventories.

The Microsoft [function index][functions] and [statement index][statements]
provide the baseline. Their current editions cover VBA, including later
features; they are not evidence that every listed item existed in VB6.
Function-specific sources below support each entry. The VB6 resource rows use
Microsoft's explicit VB6 migration remarks, rather than treating the .NET
replacement signatures as VB6 or UBE signatures. No .NET implementation is
proposed.

In this document:

- **Portable library candidate** means a callable algorithm or value operation
  for review. Its UBE declaration and complete behavior remain to be specified.
- **Library + target adapter candidate** means an ordinary library API with
  unavoidable host services beneath it.
- **Compiler syntax + library service** means the parser/lowering owns the
  source form and delegates data/resource operations through a documented
  boundary. A syntax keyword is not automatically a public Function.
- **Compatibility review** means the name is included so it cannot be
  forgotten; adoption or rejection needs an explicit recorded decision.
- String-returning `$` rows record source spellings, not an instruction to
  create overloads. UBE type characters are not part of name identity.
  Only the published list is treated as direct evidence of the legacy
  Variant/String pairing. `ChrW$` and `Environ$` are retained review spellings
  pending a direct VB6/VBA typelib check; they are not newly promised exports.

All unmarked function/statement rows are VB6/shared-VBA coverage candidates.
The `CLngLng`/`CLngPtr` rows originate in VBA7. The final platform section is
not a VB6 baseline or a claim of portable VBA7 core support. Office application
object models, Access functions such as `Nz`/`DLookup`, and Excel worksheet
functions are outside this shared-runtime list.

## Required reconciliation with UBE

The [UBE core specification][ube-core], [conversion table][ube-conversions],
[threading contract][ube-threads], and [ABI contract][ube-abi] take precedence
over historical VB runtime behavior.

- UBE uses Unicode text and explicit byte/scalar distinctions. Legacy ANSI,
  UTF-16 code-unit, `B`, and `W` behavior requires an explicit compatibility
  contract; it cannot expose an incidental string representation.
- UBE Date is a Gregorian, timezone-neutral value with nanosecond resolution,
  not an implicitly numeric Automation serial. Date arithmetic, formatting,
  calendar options, and parsing need library contracts consistent with it.
- Default conversions are invariant and checked. Formatting APIs can offer
  explicit locale behavior without making ordinary conversions locale-dependent.
- Recoverable failure returns the documented neutral value and sets thread-local
  `Err`; success does not clear an older error. Explicit dialogs remain
  explicit calls, never an automatic error policy.
- `IsMissing` needs review because UBE requires typed optional parameters and
  explicit defaults. `CVErr`/`IsError` need an approved Variant error-payload
  contract. Historical `VarType` codes need mappings for UBE's additional types.
- `CallByName` and Automation activation do not establish general dynamic
  lookup or COM compatibility for ordinary UBE Object/Variant values.
- Random streams, `Dir` cursors, working directories, settings, clocks, and
  event pumping need explicit thread-safety and ownership rules.
- Array growth, copying, `Erase`, binary records, `LSet`, and substring writes
  must preserve managed-value ownership and the UBE failure guarantees.
- Raw-pointer functions cannot be implemented by returning opaque object
  handles as if they were memory addresses. Scoped foreign access is a separate
  ABI/substrate design decision.
- Host clock assignment is already [rejected in portable UBE 1.0][ube-deferred].
  `End` and debugger `Stop` also need the defined UBE lifetime/cleanup behavior.

## Conversions and numeric text

| Identifier | Kind | Purpose | Placement/status | Source(s) |
|---|---|---|---|---|
| `CBool` | Function | Convert to Boolean | Portable library candidate; contract pending | [MS conversions][conversions] |
| `CByte` | Function | Convert to Byte | Portable library candidate; contract pending | [MS conversions][conversions] |
| `CCur` | Function | Convert to Currency | Portable library candidate; contract pending | [MS conversions][conversions] |
| `CDate` | Function | Convert to Date | Portable library candidate; contract pending | [MS conversions][conversions] |
| `CDbl` | Function | Convert to Double | Portable library candidate; contract pending | [MS conversions][conversions] |
| `CDec` | Function | Produce a Decimal-valued result | Portable library candidate; contract pending | [MS conversions][conversions] |
| `CInt` | Function | Convert to Integer | Portable library candidate; contract pending | [MS conversions][conversions] |
| `CLng` | Function | Convert to Long | Portable library candidate; contract pending | [MS conversions][conversions] |
| `CLngLng` | VBA7 conversion function | Convert to a signed 64-bit integer | Compatibility candidate; map to UBE LongLong only through its checked conversion contract | [MS VBA7][vba7]; [MS conversions][conversions] |
| `CLngPtr` | VBA7 conversion function | Convert to the platform-sized LongPtr alias | Compatibility review; UBE defines IntPtr/UIntPtr, not LongPtr | [MS VBA7][vba7]; [MS conversions][conversions] |
| `CSng` | Function | Convert to Single | Portable library candidate; contract pending | [MS conversions][conversions] |
| `CStr` | Function | Convert to String | Portable library candidate; contract pending | [MS conversions][conversions] |
| `CVar` | Function | Box or convert to Variant | Portable library candidate; contract pending | [MS conversions][conversions] |
| `CVDate` | Legacy function | Legacy Date conversion spelling | Compatibility review; not an approved UBE API | [MS conversions][conversions] |
| `CVErr` | Function | Construct a Variant error payload | Compatibility review; not an approved UBE API | [MS][cverr-function] |
| `Str` | Function | Number to legacy text | Portable library candidate; contract pending | [MS][str-function] |
| `Str$` | String-returning form | Number to legacy text | Portable library candidate; contract pending | [MS][str-function]; [MS string forms][string-forms] |
| `Val` | Function | Parse legacy numeric text | Portable library candidate; contract pending | [MS][val-function] |
| `Hex` | Function | Format a hexadecimal numeral | Portable library candidate; contract pending | [MS][hex-function] |
| `Hex$` | String-returning form | Format a hexadecimal numeral | Portable library candidate; contract pending | [MS][hex-function]; [MS string forms][string-forms] |
| `Oct` | Function | Format an octal numeral | Portable library candidate; contract pending | [MS][oct-function] |
| `Oct$` | String-returning form | Format an octal numeral | Portable library candidate; contract pending | [MS][oct-function]; [MS string forms][string-forms] |

## Strings, characters and byte-oriented compatibility

| Identifier | Kind | Purpose | Placement/status | Source(s) |
|---|---|---|---|---|
| `Asc` | Function | Character code under legacy encoding | Portable library candidate; contract pending | [MS][asc-function] |
| `AscB` | Function | First stored byte | Compatibility review; not an approved UBE API | [MS][asc-function] |
| `AscW` | Function | Legacy Unicode character code | Compatibility review; not an approved UBE API | [MS][asc-function] |
| `Chr` | Function | Character from a legacy code | Portable library candidate; contract pending | [MS][chr-function] |
| `Chr$` | String-returning form | Character from a legacy code | Portable library candidate; contract pending | [MS][chr-function]; [MS string forms][string-forms] |
| `ChrB` | Function | One-byte character form | Compatibility review; not an approved UBE API | [MS][chr-function] |
| `ChrB$` | String-returning form | One-byte character form | Compatibility review; not an approved UBE API | [MS][chr-function]; [MS string forms][string-forms] |
| `ChrW` | Function | Legacy Unicode character form | Compatibility review; not an approved UBE API | [MS][chr-function] |
| `ChrW$` | String-returning form | Legacy Unicode character form | Compatibility review; not an approved UBE API | [MS][chr-function]; Exact VB6 string-form declaration still to confirm |
| `Len` | Function | Measure logical length or legacy record size | Portable library candidate; contract pending | [MS][len-function] |
| `LenB` | Function | Measure legacy byte/storage length | Compatibility review; not an approved UBE API | [MS][len-function] |
| `InStr` | Function | Search forward | Portable library candidate; contract pending | [MS][instr-function] |
| `InStrB` | Function | Search legacy byte positions | Compatibility review; not an approved UBE API | [MS][instr-function] |
| `InStrRev` | Function | Search backward | Portable library candidate; contract pending | [MS][instrrev-function] |
| `StrComp` | Function | Compare strings | Portable library candidate; contract pending | [MS][strcomp-function] |
| `StrConv` | Function | Case, width, script or encoding conversion | Compatibility review; not an approved UBE API | [MS][strconv-function] |
| `StrReverse` | Function | Reverse character order | Portable library candidate; contract pending | [MS][strreverse-function] |
| `Split` | Function | Divide text into string elements | Portable library candidate; contract pending | [MS][split-function] |
| `Join` | Function | Combine string elements with a separator | Portable library candidate; contract pending | [MS][join-function] |
| `Filter` | Function | Select matching array elements | Portable library candidate; contract pending | [MS][filter-function] |
| `Replace` | Function | Replace matching substrings | Portable library candidate; contract pending | [MS][replace-function] |
| `Left` | Function | Leading substring | Portable library candidate; contract pending | [MS][left-function] |
| `Left$` | String-returning form | Leading substring | Portable library candidate; contract pending | [MS][left-function]; [MS string forms][string-forms] |
| `LeftB` | Function | Legacy leading byte substring | Compatibility review; not an approved UBE API | [MS][left-function] |
| `LeftB$` | String-returning form | Legacy leading byte substring | Compatibility review; not an approved UBE API | [MS][left-function]; [MS string forms][string-forms] |
| `Right` | Function | Trailing substring | Portable library candidate; contract pending | [MS][right-function] |
| `Right$` | String-returning form | Trailing substring | Portable library candidate; contract pending | [MS][right-function]; [MS string forms][string-forms] |
| `RightB` | Function | Legacy trailing byte substring | Compatibility review; not an approved UBE API | [MS][right-function] |
| `RightB$` | String-returning form | Legacy trailing byte substring | Compatibility review; not an approved UBE API | [MS][right-function]; [MS string forms][string-forms] |
| `Mid` | Function | Substring at a position | Portable library candidate; contract pending | [MS][mid-function] |
| `Mid$` | String-returning form | Substring at a position | Portable library candidate; contract pending | [MS][mid-function]; [MS string forms][string-forms] |
| `MidB` | Function | Legacy substring at byte positions | Compatibility review; not an approved UBE API | [MS][mid-function] |
| `MidB$` | String-returning form | Legacy substring at byte positions | Compatibility review; not an approved UBE API | [MS][mid-function]; [MS string forms][string-forms] |
| `LCase` | Function | Lowercase mapping | Portable library candidate; contract pending | [MS][lcase-function] |
| `LCase$` | String-returning form | Lowercase mapping | Portable library candidate; contract pending | [MS][lcase-function]; [MS string forms][string-forms] |
| `UCase` | Function | Uppercase mapping | Portable library candidate; contract pending | [MS][ucase-function] |
| `UCase$` | String-returning form | Uppercase mapping | Portable library candidate; contract pending | [MS][ucase-function]; [MS string forms][string-forms] |
| `LTrim` | Function | Remove leading spaces | Portable library candidate; contract pending | [MS][ltrim-rtrim-and-trim-functions] |
| `LTrim$` | String-returning form | Remove leading spaces | Portable library candidate; contract pending | [MS][ltrim-rtrim-and-trim-functions]; [MS string forms][string-forms] |
| `RTrim` | Function | Remove trailing spaces | Portable library candidate; contract pending | [MS][ltrim-rtrim-and-trim-functions] |
| `RTrim$` | String-returning form | Remove trailing spaces | Portable library candidate; contract pending | [MS][ltrim-rtrim-and-trim-functions]; [MS string forms][string-forms] |
| `Trim` | Function | Remove leading and trailing spaces | Portable library candidate; contract pending | [MS][ltrim-rtrim-and-trim-functions] |
| `Trim$` | String-returning form | Remove leading and trailing spaces | Portable library candidate; contract pending | [MS][ltrim-rtrim-and-trim-functions]; [MS string forms][string-forms] |
| `Space` | Function | Construct spaces | Portable library candidate; contract pending | [MS][space-function] |
| `Space$` | String-returning form | Construct spaces | Portable library candidate; contract pending | [MS][space-function]; [MS string forms][string-forms] |
| `String` | Function | Construct repeated characters | Portable library candidate; contract pending | [MS][string-function] |
| `String$` | String-returning form | Construct repeated characters | Portable library candidate; contract pending | [MS][string-function]; [MS string forms][string-forms] |

## Formatting

| Identifier | Kind | Purpose | Placement/status | Source(s) |
|---|---|---|---|---|
| `Format` | Function | Apply a named or custom display format | Portable library candidate; contract pending | [MS][format-function-visual-basic-for-applications] |
| `Format$` | String-returning form | Apply a named or custom display format | Portable library candidate; contract pending | [MS][format-function-visual-basic-for-applications]; [MS string forms][string-forms] |
| `FormatCurrency` | Function | Format a currency display | Portable library candidate; contract pending | [MS][formatcurrency-function] |
| `FormatDateTime` | Function | Format a date/time display | Portable library candidate; contract pending | [MS][formatdatetime-function] |
| `FormatNumber` | Function | Format a numeric display | Portable library candidate; contract pending | [MS][formatnumber-function] |
| `FormatPercent` | Function | Format a percentage display | Portable library candidate; contract pending | [MS][formatpercent-function] |

## Mathematics and randomness

| Identifier | Kind | Purpose | Placement/status | Source(s) |
|---|---|---|---|---|
| `Abs` | Function | Absolute value | Portable library candidate; contract pending | [MS][abs-function] |
| `Atn` | Function | Inverse tangent | Portable library candidate; contract pending | [MS][atn-function] |
| `Cos` | Function | Cosine | Portable library candidate; contract pending | [MS][cos-function] |
| `Exp` | Function | Natural exponential | Portable library candidate; contract pending | [MS][exp-function] |
| `Fix` | Function | Integral part toward zero | Portable library candidate; contract pending | [MS][int-fix-functions] |
| `Int` | Function | Integer floor | Portable library candidate; contract pending | [MS][int-fix-functions] |
| `Log` | Function | Natural logarithm | Portable library candidate; contract pending | [MS][log-function] |
| `Rnd` | Function | Pseudorandom number | Portable library candidate; contract pending | [MS][rnd-function] |
| `Round` | Function | Round to requested decimal places | Portable library candidate; contract pending | [MS][round-function] |
| `Sgn` | Function | Sign classification | Portable library candidate; contract pending | [MS][sgn-function] |
| `Sin` | Function | Sine | Portable library candidate; contract pending | [MS][sin-function] |
| `Sqr` | Function | Square root | Portable library candidate; contract pending | [MS][sqr-function] |
| `Tan` | Function | Tangent | Portable library candidate; contract pending | [MS][tan-function] |
| `Randomize` | Legacy statement / UBE ordinary call | Seed or reset the legacy random stream | Ordinary library candidate; no dedicated UBE production; state/seed contract pending | [MS][randomize-statement]; [UBE syntax audit][ube-syntax-audit] |

## Dates and clocks

| Identifier | Kind | Purpose | Placement/status | Source(s) |
|---|---|---|---|---|
| `Date` | Function | Read the current calendar date | Library + target adapter candidate; contract pending | [MS][date-function] |
| `Date$` | String-returning form | Read the current date as legacy text | Library + target adapter candidate; contract pending | [MS][date-function]; [MS string forms][string-forms] |
| `Time` | Function | Read the current time of day | Library + target adapter candidate; contract pending | [MS][time-function] |
| `Time$` | String-returning form | Read the current time as legacy text | Library + target adapter candidate; contract pending | [MS][time-function]; [MS string forms][string-forms] |
| `Now` | Function | Read current date and time | Library + target adapter candidate; contract pending | [MS][now-function] |
| `Timer` | Function | Read the legacy time-of-day timer | Library + target adapter candidate; contract pending | [MS][timer-function] |
| `DateAdd` | Function | Add a calendar interval | Portable library candidate; contract pending | [MS][dateadd-function] |
| `DateDiff` | Function | Measure calendar interval boundaries | Portable library candidate; contract pending | [MS][datediff-function] |
| `DatePart` | Function | Extract a selected calendar component | Portable library candidate; contract pending | [MS][datepart-function] |
| `DateSerial` | Function | Construct a calendar date | Portable library candidate; contract pending | [MS][dateserial-function] |
| `DateValue` | Function | Parse the date portion | Portable library candidate; contract pending | [MS][datevalue-function] |
| `TimeSerial` | Function | Construct a clock time | Portable library candidate; contract pending | [MS][timeserial-function] |
| `TimeValue` | Function | Parse the time portion | Portable library candidate; contract pending | [MS][timevalue-function] |
| `Day` | Function | Extract day of month | Portable library candidate; contract pending | [MS][day-function] |
| `Month` | Function | Extract month number | Portable library candidate; contract pending | [MS][month-function] |
| `Year` | Function | Extract year | Portable library candidate; contract pending | [MS][year-function] |
| `Hour` | Function | Extract hour | Portable library candidate; contract pending | [MS][hour-function] |
| `Minute` | Function | Extract minute | Portable library candidate; contract pending | [MS][minute-function] |
| `Second` | Function | Extract second | Portable library candidate; contract pending | [MS][second-function] |
| `Weekday` | Function | Compute weekday number | Portable library candidate; contract pending | [MS][weekday-function] |
| `MonthName` | Function | Format a month name | Portable library candidate; contract pending | [MS][monthname-function] |
| `WeekdayName` | Function | Format a weekday name | Portable library candidate; contract pending | [MS][weekdayname-function] |
| `Date =` | Assignment statement | Set the host calendar date | Rejected in portable UBE 1.0; future explicit platform API only | [MS][date-statement]; [UBE decision][ube-deferred] |
| `Time =` | Assignment statement | Set the host clock time | Rejected in portable UBE 1.0; future explicit platform API only | [MS][time-statement]; [UBE decision][ube-deferred] |

## Financial calculations

| Identifier | Kind | Purpose | Placement/status | Source(s) |
|---|---|---|---|---|
| `DDB` | Function | Declining-balance depreciation | Portable library candidate; contract pending | [MS][ddb-function] |
| `FV` | Function | Future value | Portable library candidate; contract pending | [MS][fv-function] |
| `IPmt` | Function | Interest component of a payment | Portable library candidate; contract pending | [MS][ipmt-function] |
| `IRR` | Function | Internal rate of return | Portable library candidate; contract pending | [MS][irr-function] |
| `MIRR` | Function | Modified internal rate of return | Portable library candidate; contract pending | [MS][mirr-function] |
| `NPer` | Function | Number of payment periods | Portable library candidate; contract pending | [MS][nper-function] |
| `NPV` | Function | Net present value | Portable library candidate; contract pending | [MS][npv-function] |
| `Pmt` | Function | Periodic payment | Portable library candidate; contract pending | [MS][pmt-function] |
| `PPmt` | Function | Principal component of a payment | Portable library candidate; contract pending | [MS][ppmt-function] |
| `PV` | Function | Present value | Portable library candidate; contract pending | [MS][pv-function] |
| `Rate` | Function | Interest rate per period | Portable library candidate; contract pending | [MS][rate-function] |
| `SLN` | Function | Straight-line depreciation | Portable library candidate; contract pending | [MS][sln-function] |
| `SYD` | Function | Sum-of-years depreciation | Portable library candidate; contract pending | [MS][syd-function] |

## Arrays, inspection and value selection

| Identifier | Kind | Purpose | Placement/status | Source(s) |
|---|---|---|---|---|
| `Array` | Function | Construct a Variant array | Portable library candidate; contract pending | [MS][array-function] |
| `LBound` | Function | Read a dimension's lower bound | Portable library candidate; contract pending | [MS][lbound-function] |
| `UBound` | Function | Read a dimension's upper bound | Portable library candidate; contract pending | [MS][ubound-function] |
| `IsArray` | Function | Test an array payload | Portable library candidate; contract pending | [MS][isarray-function] |
| `IsDate` | Function | Test date convertibility | Portable library candidate; contract pending | [MS][isdate-function] |
| `IsEmpty` | Function | Test the Empty tag | Portable library candidate; contract pending | [MS][isempty-function] |
| `IsError` | Function | Test a legacy error payload | Compatibility review; not an approved UBE API | [MS][iserror-function] |
| `IsMissing` | Function | Test an omitted optional Variant argument | Compatibility review; not an approved UBE API | [MS][ismissing-function] |
| `IsNull` | Function | Test the Null tag | Portable library candidate; contract pending | [MS][isnull-function] |
| `IsNumeric` | Function | Test numeric convertibility | Portable library candidate; contract pending | [MS][isnumeric-function] |
| `IsObject` | Function | Test an object-compatible payload | Portable library candidate; contract pending | [MS][isobject-function] |
| `TypeName` | Function | Read a language type name | Portable library candidate; contract pending | [MS][typename-function] |
| `VarType` | Function | Read a legacy Variant type code | Portable library candidate; contract pending | [MS][vartype-function] |
| `Erase` | Statement | Reset fixed arrays or release dynamic array values | Compiler syntax + library service; UBE behavior takes precedence | [MS][erase-statement] |
| `ReDim` | Statement | Allocate or resize array bounds | Compiler syntax + library service; UBE behavior takes precedence | [MS][redim-statement] |
| `ReDim Preserve` | Statement modifier | Retain values inside new bounds | Compiler syntax + library service; UBE behavior takes precedence | [MS][redim-statement] |
| `Choose` | Function | Select an indexed supplied value | Portable library candidate; contract pending | [MS][choose-function] |
| `IIf` | Function | Select between eagerly evaluated values | Portable library candidate; contract pending | [MS][iif-function] |
| `Switch` | Function | Select from condition/value pairs | Portable library candidate; contract pending | [MS][switch-function] |
| `Partition` | Function | Describe the interval containing a number | Portable library candidate; contract pending | [MS][partition-function] |

## Errors, execution and debugger boundary

| Identifier | Kind | Purpose | Placement/status | Source(s) |
|---|---|---|---|---|
| `Error` | Function | Describe an error number | Portable library candidate; contract pending | [MS][error-function] |
| `Error$` | String-returning form | Describe an error number | Portable library candidate; contract pending | [MS][error-function]; [MS string forms][string-forms] |
| `Error` | Statement | Explicitly record or raise a language failure | Compiler syntax + library service; UBE behavior takes precedence | [MS][error-statement] |
| `Erl` | Legacy intrinsic | Read the numbered source location associated with an error | Compatibility review; not an approved UBE API; exact VB6 source-line contract needs primary confirmation | [MS lineage][erl-lineage] |
| `On Error` | Statement | Select procedure-local error handling | Compiler control flow; not an ordinary library function | [MS][on-error-statement]; [UBE errors][ube-core] |
| `Resume` | Statement | Continue from an active error handler | Compiler control flow; not an ordinary library function | [MS statements][statements]; [UBE errors][ube-core] |
| `End` | Statement | Terminate through the defined program lifecycle | Compiler + lifecycle substrate; shutdown contract required | [MS][end-statement] |
| `Stop` | Statement | Request a debugger stop | Compiler/debugger facility; production behavior needs a contract | [MS][stop-statement] |

## Files, directories and stream formatting

| Identifier | Kind | Purpose | Placement/status | Source(s) |
|---|---|---|---|---|
| `CurDir` | Function | Read the current working directory | Library + target adapter candidate; contract pending | [MS][curdir-function] |
| `CurDir$` | String-returning form | Read the current working directory | Library + target adapter candidate; contract pending | [MS][curdir-function]; [MS string forms][string-forms] |
| `Dir` | Function | Enumerate matching names | Library + target adapter candidate; contract pending | [MS][dir-function] |
| `Dir$` | String-returning form | Enumerate matching names | Library + target adapter candidate; contract pending | [MS][dir-function]; [MS string forms][string-forms] |
| `EOF` | Function | Test end of an open file | Library + target adapter candidate; contract pending | [MS][eof-function] |
| `FileAttr` | Function | Read legacy file-open attributes | Library + target adapter candidate; contract pending | [MS][fileattr-function] |
| `FileDateTime` | Function | Read a file timestamp | Library + target adapter candidate; contract pending | [MS][filedatetime-function] |
| `FileLen` | Function | Read a file's length | Library + target adapter candidate; contract pending | [MS][filelen-function] |
| `FreeFile` | Function | Allocate an unused legacy file number | Library + target adapter candidate; contract pending | [MS][freefile-function] |
| `GetAttr` | Function | Read file attributes | Library + target adapter candidate; contract pending | [MS][getattr-function] |
| `Input` | Function | Read a requested character count | Library + target adapter candidate; contract pending | [MS][input-function] |
| `Input$` | String-returning form | Read a requested character count | Library + target adapter candidate; contract pending | [MS][input-function]; [MS string forms][string-forms] |
| `InputB` | Function | Read a requested legacy byte count | Library + target adapter candidate; contract pending | [MS][input-function] |
| `InputB$` | String-returning form | Read a requested legacy byte count | Library + target adapter candidate; contract pending | [MS][input-function]; [MS string forms][string-forms] |
| `Loc` | Function | Read the legacy file position | Library + target adapter candidate; contract pending | [MS][loc-function] |
| `LOF` | Function | Read the length of an open file | Library + target adapter candidate; contract pending | [MS][lof-function] |
| `Seek` | Function | Read the current file position | Library + target adapter candidate; contract pending | [MS][seek-function] |
| `ChDir` | Statement | Change the current directory | Compiler syntax + library service; UBE behavior takes precedence | [MS][chdir-statement] |
| `ChDrive` | Statement | Change the current drive | Compiler syntax + library service; UBE behavior takes precedence | [MS][chdrive-statement] |
| `Close` | Statement | Flush and close file numbers | Compiler syntax + library service; UBE behavior takes precedence | [MS][close-statement] |
| `FileCopy` | Statement | Copy a file | Compiler syntax + library service; UBE behavior takes precedence | [MS][filecopy-statement] |
| `Get` | Statement | Read a binary or random-access record | Compiler syntax + library service; UBE behavior takes precedence | [MS][get-statement] |
| `Input #` | Statement | Parse sequential file fields | Compiler syntax + library service; UBE behavior takes precedence | [MS][inputstatement] |
| `Kill` | Statement | Delete matching files | Compiler syntax + library service; UBE behavior takes precedence | [MS][kill-statement] |
| `Line Input #` | Statement | Read one sequential text line | Compiler syntax + library service; UBE behavior takes precedence | [MS][line-inputstatement] |
| `Lock` | Statement | Acquire a file/record lock | Compiler syntax + library service; UBE behavior takes precedence | [MS][lock-unlock-statements] |
| `Unlock` | Statement | Release a file/record lock | Compiler syntax + library service; UBE behavior takes precedence | [MS][lock-unlock-statements] |
| `MkDir` | Statement | Create a directory | Compiler syntax + library service; UBE behavior takes precedence | [MS][mkdir-statement] |
| `Name` | Statement | Rename or move a file | Compiler syntax + library service; UBE behavior takes precedence | [MS][name-statement] |
| `Open` | Statement | Open a numbered file | Compiler syntax + library service; UBE behavior takes precedence | [MS][open-statement] |
| `Print #` | Statement | Write formatted sequential text | Compiler syntax + library service; UBE behavior takes precedence | [MS][printstatement] |
| `Print` | Statement | Write ordinary program output | Existing UBE compiler syntax + console/library service; distinct from Print # and object Print methods | [UBE grammar][ube-grammar] |
| `Put` | Statement | Write a binary or random-access record | Compiler syntax + library service; UBE behavior takes precedence | [MS][put-statement] |
| `Reset` | Legacy statement / UBE ordinary call | Close all legacy file numbers | Ordinary library + target adapter candidate; no dedicated UBE production; resource/state contract pending | [MS][reset-statement]; [UBE syntax audit][ube-syntax-audit] |
| `RmDir` | Statement | Remove a directory | Compiler syntax + library service; UBE behavior takes precedence | [MS][rmdir-statement] |
| `Seek` | Statement | Set a file position | Compiler syntax + library service; UBE behavior takes precedence | [MS][seek-statement] |
| `SetAttr` | Legacy statement / UBE ordinary call | Change file attributes | Ordinary library + target adapter candidate; no dedicated UBE production | [MS][setattr-statement]; [UBE syntax audit][ube-syntax-audit] |
| `Width #` | Statement | Set legacy output formatting width | Compiler syntax + library service; UBE behavior takes precedence | [MS][widthstatement] |
| `Write #` | Statement | Write delimited sequential values | Compiler syntax + library service; UBE behavior takes precedence | [MS][writestatement] |
| `Spc` | Print-context form | Emit a requested space count | Compiler syntax + library service; UBE behavior takes precedence | [MS][spc-function] |
| `Tab` | Print-context form | Advance to an output column | Compiler syntax + library service; UBE behavior takes precedence | [MS][tab-function] |

## Environment, settings, interaction and integration

| Identifier | Kind | Purpose | Placement/status | Source(s) |
|---|---|---|---|---|
| `Command` | Function | Read the legacy command-line tail | Library + target adapter candidate; contract pending | [MS][command-function] |
| `Command$` | String-returning form | Read the legacy command-line tail | Library + target adapter candidate; contract pending | [MS][command-function]; [MS string forms][string-forms] |
| `Environ` | Function | Read an environment entry | Library + target adapter candidate; contract pending | [MS][environ-function] |
| `Shell` | Function | Launch a host process | Library + target adapter candidate; contract pending | [MS][shell-function] |
| `GetSetting` | Function | Read an application setting | Library + target adapter candidate; contract pending | [MS][getsetting-function] |
| `GetAllSettings` | Function | Enumerate application settings | Library + target adapter candidate; contract pending | [MS][getallsettings-function] |
| `InputBox` | Function | Display an explicit text-input dialog | Library + target adapter candidate; contract pending | [MS][inputbox-function] |
| `MsgBox` | Function | Display an explicit message dialog | Library + target adapter candidate; contract pending | [MS][msgbox-function] |
| `DoEvents` | Function | Yield to host event processing | Compatibility review; not an approved UBE API | [MS][doevents-function] |
| `IMEStatus` | Function | Read input-method state | Compatibility review; not an approved UBE API | [MS][imestatus-function] |
| `CreateObject` | Function | Activate a registered Automation class | Compatibility review; not an approved UBE API | [MS][createobject-function] |
| `GetObject` | Function | Acquire an Automation object | Compatibility review; not an approved UBE API | [MS][getobject-function] |
| `CallByName` | Function | Invoke a member by runtime name | Compatibility review; not an approved UBE API | [MS][callbyname-function] |
| `RGB` | Function | Build a legacy RGB color value | Portable library candidate; contract pending | [MS][rgb-function] |
| `QBColor` | Function | Map a legacy palette index | Portable library candidate; contract pending | [MS][qbcolor-function] |
| `Environ$` | Legacy string spelling | Read an environment entry | Compatibility review; not an approved UBE API; exact VB6 spelling to confirm | [MS][environ-function] |
| `AppActivate` | Statement/service | Activate a host application window | Library + target adapter candidate; contract pending | [MS][appactivate-statement] |
| `Beep` | Statement/service | Request an explicit audible notification | Library + target adapter candidate; contract pending | [MS][beep-statement] |
| `DeleteSetting` | Statement/service | Remove stored application settings | Library + target adapter candidate; contract pending | [MS][deletesetting-statement] |
| `SaveSetting` | Statement/service | Write an application setting | Library + target adapter candidate; contract pending | [MS][savesetting-statement] |
| `SendKeys` | Statement/service | Inject host keyboard input | Library + target adapter candidate; contract pending | [MS][sendkeys-statement] |

## VB6-specific resources and undocumented address access

| Identifier | Kind | Purpose | Placement/status | Source(s) |
|---|---|---|---|---|
| `LoadPicture` | VB6 function | Read an image into a picture value | Graphics/framework candidate; image ownership, formats, failures and fresh return type need definition; do not import .NET replacement signatures | [MS VB6 lineage][loadpicture-lineage] |
| `SavePicture` | VB6 statement / UBE object statement | Write a picture to a file | Existing UBE syntax + graphics/file library service; format, ownership and failure behavior need definition | [MS VB6 usage][savepicture-usage]; [UBE grammar][ube-grammar] |
| `LoadResData` | VB6-specific function | Load embedded resource bytes | Compatibility review; not an approved UBE API; reconcile with .UBR and native picture/text contracts | [MS VB6 migration remarks][resources] |
| `LoadResPicture` | VB6-specific function | Load an embedded picture resource | Compatibility review; not an approved UBE API; reconcile with .UBR and native picture/text contracts | [MS VB6 migration remarks][resources] |
| `LoadResString` | VB6-specific function | Load an embedded text resource | Compatibility review; not an approved UBE API; reconcile with .UBR and native picture/text contracts | [MS VB6 migration remarks][resources] |
| `VarPtr` | Undocumented legacy intrinsic | Expose a variable-storage address | Unsafe compatibility review; never equate an opaque UBE handle with an address | [MS pointer lineage][pointer-lineage]; [UBE ABI][ube-abi] |
| `StrPtr` | Undocumented legacy intrinsic | Expose a string-storage address | Unsafe compatibility review; never equate an opaque UBE handle with an address | [MS pointer lineage][pointer-lineage]; [UBE ABI][ube-abi] |
| `ObjPtr` | Undocumented legacy intrinsic | Expose an object/interface address | Unsafe compatibility review; never equate an opaque UBE handle with an address | [MS pointer lineage][pointer-lineage]; [UBE ABI][ube-abi] |

## String-assignment syntax backed by library operations

| Identifier | Kind | Purpose | Placement/status | Source(s) |
|---|---|---|---|---|
| `Mid` | Assignment statement | Overwrite a substring in an assignment | Compiler syntax + library service; UBE behavior takes precedence; storage-copy compatibility needs review | [MS][mid-statement] |
| `Mid$` | Assignment statement | String-form substring assignment spelling | Compiler syntax + library service; UBE behavior takes precedence; storage-copy compatibility needs review | [MS][mid-statement] |
| `MidB` | Legacy assignment statement | Overwrite legacy byte positions | Syntax compatibility decision required: frozen UBE substring assignment admits Mid/Mid$, not MidB; byte/storage-copy contract also pending | [MS][mid-statement]; [UBE grammar][ube-grammar] |
| `LSet` | Assignment statement | Left-align text or perform legacy record assignment | Compiler syntax + library service; UBE behavior takes precedence; storage-copy compatibility needs review | [MS][lset-statement] |
| `RSet` | Assignment statement | Right-align text | Compiler syntax + library service; UBE behavior takes precedence; storage-copy compatibility needs review | [MS][rset-statement] |

## VBA platform extensions

| Identifier | Kind | Purpose | Placement/status | Source(s) |
|---|---|---|---|---|
| `MacID` | VBA Macintosh function | Encode a legacy four-character Macintosh identifier | Platform compatibility review; not portable core behavior | [MS MacID][macid-function] |
| `MacScript` | VBA Macintosh function | Execute legacy inline AppleScript | Deprecated Office-for-Mac compatibility review; no portable adoption | [MS MacScript][macscript-function]; [MS AppleScriptTask][applescript] |
| `AppleScriptTask` | Office 2016 for Mac extension | Call an external AppleScript handler | Platform/host extension candidate; separate from VBA7 core | [MS AppleScriptTask][applescript] |
| `GrantAccessToMultipleFiles` | Office 2016 for Mac extension | Request sandbox permission for listed files | Platform/host extension candidate; separate from VBA7 core | [MS file permissions][mac-files] |

## Coverage limits and source interpretation

This is a named runtime-surface inventory, not a reconstruction of every
export in `msvbvm60.dll`, every COM interface, or every VB6 IDE service.
Compiler implementation helpers are not public API obligations.

`Derived math` in Microsoft's index is an explanatory collection of formulas,
not an additional callable named `DerivedMath`. Pure declarations, control
flow, operators, attributes, and preprocessing are covered by the language
inventory rather than duplicated here as library procedures.

The `Erl` row retains a known historical name but flags the missing primary
VB6 source-line contract. Its linked .NET lineage documentation is not used
to assert a new UBE signature. Pointer lineage documentation confirms current
VBA names and pointer purpose; it does not turn undocumented VB6 behavior into
a frozen or safe UBE API. Exact legacy spellings and hidden members should be
checked against a lawful VB6/VBA type-library reference before a completeness
claim at that level.

Published `$` spellings are counted separately to make source acceptance
coverage visible. Ordinary function names and assignment statements with the
same spelling are separate rows because they have different source forms.
No production code or archived implementation was copied to produce this list.

## Sources

The reference links below are primary Microsoft documentation. Per-function
citations identify narrow source pages; prose and placement assessments are
UBE planning conclusions, not Microsoft implementation recommendations.

[functions]: https://learn.microsoft.com/en-us/office/vba/language/reference/functions-visual-basic-for-applications
[statements]: https://learn.microsoft.com/en-gb/office/vba/language/reference/statements
[conversions]: https://learn.microsoft.com/en-us/office/vba/language/concepts/getting-started/type-conversion-functions
[string-forms]: https://learn.microsoft.com/en-us/office/vba/language/concepts/getting-started/returning-strings-from-functions
[vba7]: https://learn.microsoft.com/en-us/office/vba/language/concepts/getting-started/64-bit-visual-basic-for-applications-overview
[pointer-lineage]: https://learn.microsoft.com/en-us/office/client-developer/shared/compatibility-between-the-32-bit-and-64-bit-versions-of-office
[resources]: https://learn.microsoft.com/en-us/dotnet/api/microsoft.visualbasic.compatibility.vb6.support.loadresdata?view=netframework-4.8.1
[erl-lineage]: https://learn.microsoft.com/en-us/dotnet/api/microsoft.visualbasic.information.erl
[applescript]: https://learn.microsoft.com/en-us/office/vba/office-mac/applescripttask
[mac-files]: https://learn.microsoft.com/en-us/office/vba/office-mac/grantaccesstomultiplefiles
[ube-core]: ../../lang-doc/language-spec.md
[ube-conversions]: ../../lang-doc/conversion-table.md
[ube-threads]: ../../lang-doc/threading.md
[ube-abi]: ../../lang-doc/foreign-abi.md
[ube-deferred]: ../../lang-doc/deferred-questions.md
[ube-grammar]: ../../lang-doc/grammar/ube.ebnf
[ube-syntax-audit]: ../../lang-doc/audits/legacy-syntax.md
[loadpicture-lineage]: https://learn.microsoft.com/en-us/troubleshoot/developer/visualstudio/csharp/language-compilers/copy-image-database-picturebox
[savepicture-usage]: https://learn.microsoft.com/en-us/archive/msdn-magazine/2003/december/web-q-a-virtual-directories-releasing-db-connections-and-more
[cverr-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/cverr-function
[str-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/str-function
[val-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/val-function
[hex-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/hex-function
[oct-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/oct-function
[asc-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/asc-function
[chr-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/chr-function
[len-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/len-function
[instr-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/instr-function
[instrrev-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/instrrev-function
[strcomp-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/strcomp-function
[strconv-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/strconv-function
[strreverse-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/strreverse-function
[split-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/split-function
[join-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/join-function
[filter-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/filter-function
[replace-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/replace-function
[left-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/left-function
[right-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/right-function
[mid-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/mid-function
[lcase-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/lcase-function
[ucase-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/ucase-function
[ltrim-rtrim-and-trim-functions]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/ltrim-rtrim-and-trim-functions
[space-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/space-function
[string-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/string-function
[format-function-visual-basic-for-applications]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/format-function-visual-basic-for-applications
[formatcurrency-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/formatcurrency-function
[formatdatetime-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/formatdatetime-function
[formatnumber-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/formatnumber-function
[formatpercent-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/formatpercent-function
[abs-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/abs-function
[atn-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/atn-function
[cos-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/cos-function
[exp-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/exp-function
[int-fix-functions]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/int-fix-functions
[log-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/log-function
[rnd-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/rnd-function
[round-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/round-function
[sgn-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/sgn-function
[sin-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/sin-function
[sqr-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/sqr-function
[tan-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/tan-function
[randomize-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/randomize-statement
[date-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/date-function
[time-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/time-function
[now-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/now-function
[timer-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/timer-function
[dateadd-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/dateadd-function
[datediff-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/datediff-function
[datepart-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/datepart-function
[dateserial-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/dateserial-function
[datevalue-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/datevalue-function
[timeserial-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/timeserial-function
[timevalue-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/timevalue-function
[day-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/day-function
[month-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/month-function
[year-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/year-function
[hour-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/hour-function
[minute-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/minute-function
[second-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/second-function
[weekday-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/weekday-function
[monthname-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/monthname-function
[weekdayname-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/weekdayname-function
[date-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/date-statement
[time-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/time-statement
[ddb-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/ddb-function
[fv-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/fv-function
[ipmt-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/ipmt-function
[irr-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/irr-function
[mirr-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/mirr-function
[nper-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/nper-function
[npv-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/npv-function
[pmt-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/pmt-function
[ppmt-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/ppmt-function
[pv-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/pv-function
[rate-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/rate-function
[sln-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/sln-function
[syd-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/syd-function
[array-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/array-function
[lbound-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/lbound-function
[ubound-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/ubound-function
[isarray-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/isarray-function
[isdate-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/isdate-function
[isempty-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/isempty-function
[iserror-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/iserror-function
[ismissing-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/ismissing-function
[isnull-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/isnull-function
[isnumeric-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/isnumeric-function
[isobject-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/isobject-function
[typename-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/typename-function
[vartype-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/vartype-function
[erase-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/erase-statement
[redim-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/redim-statement
[choose-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/choose-function
[iif-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/iif-function
[switch-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/switch-function
[partition-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/partition-function
[error-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/error-function
[error-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/error-statement
[on-error-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/on-error-statement
[end-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/end-statement
[stop-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/stop-statement
[curdir-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/curdir-function
[dir-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/dir-function
[eof-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/eof-function
[fileattr-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/fileattr-function
[filedatetime-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/filedatetime-function
[filelen-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/filelen-function
[freefile-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/freefile-function
[getattr-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/getattr-function
[input-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/input-function
[loc-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/loc-function
[lof-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/lof-function
[seek-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/seek-function
[chdir-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/chdir-statement
[chdrive-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/chdrive-statement
[close-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/close-statement
[filecopy-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/filecopy-statement
[get-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/get-statement
[inputstatement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/inputstatement
[kill-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/kill-statement
[line-inputstatement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/line-inputstatement
[lock-unlock-statements]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/lock-unlock-statements
[mkdir-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/mkdir-statement
[name-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/name-statement
[open-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/open-statement
[printstatement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/printstatement
[put-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/put-statement
[reset-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/reset-statement
[rmdir-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/rmdir-statement
[seek-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/seek-statement
[setattr-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/setattr-statement
[widthstatement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/widthstatement
[writestatement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/writestatement
[spc-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/spc-function
[tab-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/tab-function
[command-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/command-function
[environ-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/environ-function
[shell-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/shell-function
[getsetting-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/getsetting-function
[getallsettings-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/getallsettings-function
[inputbox-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/inputbox-function
[msgbox-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/msgbox-function
[doevents-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/doevents-function
[imestatus-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/imestatus-function
[createobject-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/createobject-function
[getobject-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/getobject-function
[callbyname-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/callbyname-function
[rgb-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/rgb-function
[qbcolor-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/qbcolor-function
[appactivate-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/appactivate-statement
[beep-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/beep-statement
[deletesetting-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/deletesetting-statement
[savesetting-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/savesetting-statement
[sendkeys-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/sendkeys-statement
[mid-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/mid-statement
[lset-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/lset-statement
[rset-statement]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/rset-statement
[macid-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/macid-function
[macscript-function]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/macscript-function
