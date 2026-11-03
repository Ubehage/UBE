param([Parameter(Mandatory=$true)][string] $Objdump,
      [Parameter(Mandatory=$true)][string] $Executable)
$ErrorActionPreference = 'Stop'
$exe = (Resolve-Path -LiteralPath $Executable).Path
$source = Join-Path $PSScriptRoot 'stack-guard-aware.c'
$lines = [IO.File]::ReadAllLines($source)
$expectedLines = @(for ($i=0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match '^__declspec\(noinline\) static int descend\(') { $i + 1 }
})
if ($expectedLines.Count -ne 1) { throw 'Source declaration is ambiguous' }
$debug = (& $Objdump --dwarf=info $exe) -join "`n"
if ($LASTEXITCODE -ne 0 -or $debug -notmatch 'DW_AT_name[^\n]*stack-guard-aware\.c') { throw 'Expected source information missing' }
$blocks = [regex]::Split($debug, '(?m)(?=^ <1><[0-9a-f]+>:)')
$matches = @($blocks | Where-Object { $_ -match 'DW_TAG_subprogram' -and $_ -match '(?m)DW_AT_name[^\n]*: descend\s*$' })
if ($matches.Count -ne 1) { throw 'Expected one descend subprogram' }
$low = [regex]::Match($matches[0], 'DW_AT_low_pc\s*:\s*0x([0-9a-fA-F]+)')
$line = [regex]::Match($matches[0], 'DW_AT_decl_line\s*:\s*(\d+)')
if (-not $low.Success -or -not $line.Success) { throw 'Subprogram location missing' }
$code = (& $Objdump -d $exe) -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'Disassembly failed' }
$symbol = [regex]::Match($code, '(?m)^([0-9a-fA-F]+) <descend>:')
if (-not $symbol.Success) { throw 'Linked descend symbol missing' }
$actualAddress = [Convert]::ToUInt64($low.Groups[1].Value,16)
$linkedAddress = [Convert]::ToUInt64($symbol.Groups[1].Value,16)
$actualLine = [int]$line.Groups[1].Value
function Same-Location($address, $lineNumber) { return $address -eq $linkedAddress -and $lineNumber -eq $expectedLines[0] }
if (-not (Same-Location $actualAddress $actualLine)) { throw 'Debug function location differs from source or linked code' }
if (Same-Location ($actualAddress + 1) $actualLine) { throw 'Wrong-address control was accepted' }
if (Same-Location $actualAddress ($actualLine + 1)) { throw 'Wrong-line control was accepted' }
Write-Output "Linked descend address and declaration line $actualLine matched; two controls rejected."
