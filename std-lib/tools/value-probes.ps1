# Native execution adapter shared by ordinary-record and opaque-value tests.
function Invoke-ValueLayoutProbe {
    param([string]$Root, $Selection, [string]$RawIr, [string]$OutputStem,
        [string]$Adapter, [string]$PayloadType = 'i8', [int]$Size = 1,
        [int]$Alignment = 1, [int]$InitialErr = 77, [int]$FinalErr = 77,
        [string]$ExpectedStdout, [int]$ExpectedExit = 0, $CommandLog)
    $raw = [IO.File]::ReadAllText($RawIr)
    $pattern = '(?m)^(%ube\.type\.\d+) = type \{\s*' + [regex]::Escape($PayloadType) + '\s*\}'
    $types = [regex]::Matches($raw,$pattern)
    if ($types.Count -ne 1) { throw "Expected exactly one value type with $PayloadType payload" }
    $type = $types[0].Groups[1].Value
    if ([regex]::Matches($raw,'(?m)^define i32 @main\(').Count -ne 1) { throw 'Unrecognized generated entry wrapper' }
    $adapted = [regex]::Replace($raw,'(?m)^define i32 @main\(','define i32 @value_record_entry(')
    $adapted += @"

; Test-only target layout queries. Type and UBE procedure definitions are unchanged.
define i64 @value_record_size() {
  ret i64 ptrtoint (ptr getelementptr ($type, ptr null, i32 1) to i64)
}
define i64 @value_record_alignment() {
  ret i64 ptrtoint (ptr getelementptr ({ i8, $type }, ptr null, i32 0, i32 1) to i64)
}
"@
    $probeIr = $OutputStem + '-probe.ll'
    $exe = $OutputStem + '.exe'
    [IO.File]::WriteAllText($probeIr,$adapted,(New-Object Text.UTF8Encoding($false)))
    $link = Invoke-BoundedProcess $Selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2',
        '-x','ir',$probeIr,'-x','c',$Adapter,'-std=c17','-Wall','-Wextra','-Werror',
        "-DEXPECTED_SIZE=$Size","-DEXPECTED_ALIGNMENT=$Alignment","-DINITIAL_ERR=$InitialErr","-DFINAL_ERR=$FinalErr",
        '-x','none',$Selection.runtime.path,$Selection.unicodeRuntime.path,'-o',$exe) $Root 30
    $CommandLog.Add($link)
    if ($link.timedOut -or $link.exit -ne 0) { throw "Value probe link failed: $($link.stderr)" }
    $native = Invoke-BoundedProcess $exe @() $Root 15
    $CommandLog.Add($native)
    if ($native.timedOut -or $native.exit -ne $ExpectedExit -or $native.stdout -cne $ExpectedStdout -or $native.stderr -cne '') {
        throw "Value oracle failed: $($native | ConvertTo-Json -Compress -Depth 5)"
    }
    return $native
}
