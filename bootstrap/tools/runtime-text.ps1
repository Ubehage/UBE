# Reproduces reviewed target runtime text directly from VB6 source statements.
param([switch]$Write)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$encoding = New-Object Text.UTF8Encoding($false, $true)
$constants = @{ MaximumArrayElements = '1048576' }

# Reads exactly one named procedure body; ambiguous or missing definitions fail.
function Read-Body([string]$Source, [string]$Name, [string]$Kind) {
    $pattern = '(?ms)^(?:Private|Public) ' + $Kind + ' ' + [regex]::Escape($Name) + '\([^\r\n]*\r?\n(.*?)^End ' + $Kind + '\s*$'
    $found = [regex]::Matches($Source, $pattern)
    if ($found.Count -ne 1) { throw "Expected exactly one $Name definition" }
    return $found[0].Groups[1].Value
}

# Evaluates only quoted VB literals, reviewed CStr constants and vbCrLf joins.
function Read-Expression([string]$Expression) {
    $result = New-Object Text.StringBuilder
    $position = 0
    while ($position -lt $Expression.Length) {
        $part = [regex]::Match($Expression.Substring($position), '^\s*(?:"((?:[^"]|"")*)"|CStr\(([A-Za-z][A-Za-z0-9]*)\)|(vbCrLf))\s*')
        if (-not $part.Success) { throw "Unknown runtime expression: $Expression" }
        if ($part.Groups[1].Success) { $null = $result.Append($part.Groups[1].Value.Replace('""','"')) }
        elseif ($part.Groups[2].Success) {
            $name = $part.Groups[2].Value
            if (-not $constants.ContainsKey($name)) { throw "Unreviewed runtime constant: $name" }
            $null = $result.Append($constants[$name])
        } else { $null = $result.Append([char]13).Append([char]10) }
        $position += $part.Length
        if ($position -eq $Expression.Length) { break }
        if ($Expression[$position] -ne '&') { throw "Unknown runtime operator: $Expression" }
        $position++
        if ($position -eq $Expression.Length) { throw 'Missing concatenation operand' }
    }
    return $result.ToString()
}

$emitter = [IO.File]::ReadAllText((Join-Path $root 'bootstrap/src/SourceEmitter.bas'), $encoding)
$files = [IO.File]::ReadAllText((Join-Path $root 'bootstrap/src/NativeFileRuntime.bas'), $encoding)
$constantSources = Get-ChildItem -LiteralPath (Join-Path $root 'bootstrap/src') -Filter '*.bas'
foreach ($name in $constants.Keys) {
    $declarations = @($constantSources | Select-String -Pattern ('^Public Const ' + $name + ' As Long = ([0-9]+)\s*$'))
    if ($declarations.Count -ne 1 -or $declarations[0].Matches[0].Groups[1].Value -ne $constants[$name]) { throw "Reviewed constant changed: $name" }
}
$output = New-Object Text.StringBuilder
$body = Read-Body $emitter 'EmitMemoryRuntime' 'Sub'
foreach ($line in ($body -split '\r?\n')) {
    if ($line.Trim().Length -eq 0 -or $line.TrimStart().StartsWith("'")) { continue }
    $statement = [regex]::Match($line, '^\s*Call AddLine\(State, (.*)\)\s*$')
    if (-not $statement.Success) { throw "Unknown memory runtime statement: $line" }
    $null = $output.Append((Read-Expression $statement.Groups[1].Value)).Append([char]13).Append([char]10)
}
$entry = Read-Body $files 'NativeFileIR' 'Function'
$parts = New-Object 'System.Collections.Generic.List[string]'
foreach ($line in ($entry -split '\r?\n')) {
    if ($line.Trim().Length -eq 0) { continue }
    $statement = [regex]::Match($line, '^\s*NativeFileIR = NativeFileIR & ([A-Za-z][A-Za-z0-9]*)\(\)\s*$')
    if (-not $statement.Success) { throw "Unknown file runtime composition: $line" }
    $parts.Add($statement.Groups[1].Value)
}
if (($parts -join ',') -ne 'FileTargetsAndRegistryIR,FileAcquisitionIR,FileTransferAndReleaseIR') { throw 'Unreviewed file runtime composition' }
foreach ($name in $parts) {
    $body = Read-Body $files $name 'Function'
    if ([regex]::Matches($body, '(?m)^\s*Dim Text As String\s*$').Count -ne 1 -or
        [regex]::Matches($body, ('(?m)^\s*' + $name + ' = Text\s*$')).Count -ne 1 -or
        $body.TrimEnd() -notmatch ([regex]::Escape($name) + ' = Text$')) {
        throw "Unreviewed file runtime accumulator/return: $name"
    }
    foreach ($line in ($body -split '\r?\n')) {
        if ($line.Trim().Length -eq 0 -or $line.TrimStart().StartsWith("'")) { continue }
        if ($line.Trim() -eq 'Dim Text As String' -or $line.Trim() -eq "$name = Text") { continue }
        $statement = [regex]::Match($line, '^\s*Text = Text & (.*)\s*$')
        if (-not $statement.Success) { throw "Unknown file runtime statement: $line" }
        $null = $output.Append((Read-Expression $statement.Groups[1].Value))
    }
}
$asset = Join-Path $root 'compiler/llvm/windows-runtime.ll'
$expected = $output.ToString()
if ($Write) { [IO.File]::WriteAllText($asset, $expected, $encoding) }
if (-not [IO.File]::Exists($asset) -or [IO.File]::ReadAllText($asset, $encoding) -cne $expected) { throw 'Runtime asset differs from reviewed source extraction; run -Write after reviewing changes' }
$runtimeBytes = $encoding.GetBytes($expected)
$runtimeSum = ($runtimeBytes | Measure-Object -Sum).Sum
$lowering = [IO.File]::ReadAllText((Join-Path $root 'compiler/src/NativeLowering.bas'), $encoding)
foreach ($entry in @(@('RuntimeLength', $runtimeBytes.Length), @('RuntimeByteSum', $runtimeSum))) {
    $match = [regex]::Match($lowering, ('(?m)^Private Const ' + $entry[0] + ' As Long = ([0-9]+)\s*$'))
    if (-not $match.Success -or [long]$match.Groups[1].Value -ne [long]$entry[1]) { throw "NativeLowering asset metadata mismatch: $($entry[0])" }
}
Write-Output "PASS runtime source parity: $($encoding.GetByteCount($expected)) bytes"
