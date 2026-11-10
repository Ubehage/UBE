$ErrorActionPreference = 'Stop'
# Generates the callable-name ledger and checks coverage against independent indexes.
$root = Split-Path $PSScriptRoot -Parent
$runtime = Get-Content (Join-Path $root 'vb6-runtime-metadata.json') -Raw | ConvertFrom-Json
$objects = Get-Content (Join-Path $root 'vb6-objects-metadata.json') -Raw | ConvertFrom-Json
$rows = @{}
$subs = 'AppActivate Beep ChDir ChDrive DeleteSetting FileCopy Kill MkDir Randomize Reset RmDir SaveSetting SendKeys SetAttr Width Load Unload SavePicture' -split ' '
$platform = 'Command CurDir Dir Environ EOF FileAttr FileDateTime FileLen FreeFile GetAttr Loc LOF Seek Input InputB Date Time Now Timer Shell GetAllSettings GetSetting ChDir ChDrive FileCopy Kill MkDir Reset RmDir SetAttr SaveSetting DeleteSetting' -split ' '
$ui = 'AppActivate Beep DoEvents IMEStatus InputBox MsgBox SendKeys LoadPicture LoadResPicture SavePicture Load Unload' -split ' '
$decisions = 'CallByName CreateObject GetObject IsMissing CVErr IsError MacID MacScript Calendar VarPtr StrPtr ObjPtr' -split ' '
$metadata = 'Array LBound UBound Len LenB IsArray IsEmpty IsNull IsObject TypeName VarType Erl Err' -split ' '
foreach ($type in @($runtime.types | Where-Object kind -eq 'TKIND_MODULE') + @($objects.types | Where-Object type -eq 'VBGlobal')) {
    foreach ($member in $type.members) {
        $name = $member.name
        if ($name -match '^_B_(str|var)_(.+)$') {
            $name = $Matches[2]
            if ($Matches[1] -eq 'str') { $name += '$' }
        }
        if (-not $rows.ContainsKey($name)) { $rows[$name] = [pscustomobject]@{name=$name; group=$type.type; evidence='type library'; shape='Function'; owner='UBECore'; note='Define signature and edge cases before implementation.'} }
        $row = $rows[$name]
        $base = $name.TrimEnd('$')
        if ($base -in $subs) { $row.shape = 'Statement / Sub' }
        if ($member.kind -like '*PROPERTY*') { $row.shape = 'Property / accessor' }
        if ($base -in $platform) { $row.owner='UBECore + platform'; $row.note='Portable public contract; OS access behind target adapter.' }
        if ($base -in $ui) { $row.owner='UI/platform library'; $row.note='Framework service; not compiler algorithm. Package placement proposed.' }
        if ($base -in $metadata) { $row.owner='UBECore + compiler metadata'; $row.note='Compiler supplies type/storage/error metadata; library owns public operation.' }
        if ($base -in $decisions) { $row.owner='Decision required'; $row.note='VB6 behavior must not silently override frozen UBE semantics.' }
        if ($base -match '^(AscB|AscW|ChrB|ChrW|InStrB|LeftB|RightB|MidB|LenB|InputB|StrConv)$') { $row.note='Specify byte/Unicode/encoding behavior explicitly; do not expose host string layout.' }
        if ($base -in @('LoadResData','LoadResString')) { $row.note='Use the native UBR resource contract; VB6 RES is import compatibility.' }
        if ($base -in @('LoadPictureOld','LoadResStringOld')) { $row.owner='Historical ABI only'; $row.note='Hidden/restricted legacy entry; not an additional public source function.' }
        if ($base -in @('App','Screen','Clipboard','Printer','Forms','Printers','Licenses')) { $row.owner='Framework object'; $row.note='Global object/property, not a function. COM licensing requires separate decision.' }
    }
}
# Compiler-supplied calls do not all appear in the runtime type library.
foreach ($name in @('LBound','UBound','Spc','Tab')) {
    $rows[$name] = [pscustomobject]@{name=$name; group='Language call forms'; evidence='Microsoft function index'; shape='Function / special call'; owner='UBECore + compiler metadata'; note='Array-bound metadata or Print-format context; not general compiler algorithms.'}
}
# These String-returning spellings require direct VB6 compile evidence.
foreach ($name in @('Dir$','InputBox$','TypeName$','MonthName$','WeekdayName$','Replace$','StrReverse$','Join$','FormatCurrency$','FormatDateTime$','FormatNumber$','FormatPercent$','GetSetting$','CStr$')) {
    $rows[$name] = [pscustomobject]@{name=$name; group='String spellings'; evidence='VB6 compile probe'; shape='Function'; owner=$rows[$name.TrimEnd('$')].owner; note='String-returning source spelling; see alias probe.'}
}
$expected = 'Abs Array Asc Atn CallByName Choose Chr Command Cos CreateObject CurDir CVErr Date DateAdd DateDiff DatePart DateSerial DateValue Day DDB Dir DoEvents Environ EOF Error Exp FileAttr FileDateTime FileLen Filter Fix Format FormatCurrency FormatDateTime FormatNumber FormatPercent FreeFile FV GetAllSettings GetAttr GetObject GetSetting Hex Hour IIf IMEStatus Input InputBox InStr InStrRev Int IPmt IRR IsArray IsDate IsEmpty IsError IsMissing IsNull IsNumeric IsObject Join LBound LCase Left Len Loc LOF Log LTrim MacID MacScript Mid Minute MIRR Month MonthName MsgBox Now NPer NPV Oct Partition Pmt PPmt PV QBColor Rate Replace RGB Right Rnd Round RTrim Second Seek Sgn Shell Sin SLN Space Spc Split Sqr Str StrComp StrConv String StrReverse Switch SYD Tab Tan Time Timer TimeSerial TimeValue Trim TypeName UBound UCase Val VarType Weekday WeekdayName Year CBool CByte CCur CDate CDbl CDec CInt CLng CSng CStr CVar CVDate' -split ' '
$missing = @($expected | Where-Object { -not $rows.ContainsKey($_) })
if ($missing.Count) { throw "Reference functions missing: $($missing -join ', ')" }
$lines = @('# VB6 runtime name inventory', '', 'Generated by `tools/build-vb6-inventory.ps1`; edit classification rules there.', '',
'This is an inventory and proposed ownership ledger, not an implementation claim or approval of unresolved semantics. Every extracted runtime module member and VBGlobal member is represented, including hidden entries. Dollar variants have separate rows. Property accessors collapse by source name.', '',
'Sources and scope: [inventory guide](INVENTORY.md). Raw metadata records preserve original member names, accessor kinds, flags and parameter names; parameter names are not complete signatures.', '',
'| Name | VB6 group | Source form | UBE owner | Evidence | Boundary / remaining work |', '|---|---|---|---|---|---|')
foreach ($row in $rows.Values | Sort-Object name) { $lines += '| `' + $row.name + '` | ' + $row.group + ' | ' + $row.shape + ' | ' + $row.owner + ' | ' + $row.evidence + ' | ' + $row.note + ' |' }
$lines += @('', "Coverage: $($rows.Count) distinct source/metadata names; $($expected.Count) independently listed function names accounted for.")
$lines += @('', '## Owner-approved additions beyond VB6', '',
'These planned UBECore functions are separate from the VB6 coverage count. Approved 2026-11-10; see [contracts](INVENTORY.md#approved-additions-beyond-vb6).', '',
'| Function | Origin | UBE owner | Result | Status |', '|---|---|---|---|---|',
'| `CLngLng(expression)` | VBA7 | UBECore | `LongLong` | Approved; implementation pending |',
'| `CLngPtr(expression)` | VBA7 | UBECore | `IntPtr` | Approved; implementation pending |')
$lines | Set-Content (Join-Path $root 'VB6-RUNTIME-INVENTORY.md') -Encoding UTF8
Write-Output "PASS: $($rows.Count) names; all $($expected.Count) independent function-index/conversion names accounted for."
