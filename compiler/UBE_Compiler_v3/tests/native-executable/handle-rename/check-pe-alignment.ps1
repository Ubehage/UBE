param(
    [Parameter(Mandatory=$true)][string] $Probe,
    [Parameter(Mandatory=$true)][string] $Executable,
    [Parameter(Mandatory=$true)][string] $OutputDirectory,
    [switch] $RequireRejected
)
$ErrorActionPreference = 'Stop'
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$bytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Executable).Path)
$pe = [BitConverter]::ToUInt32($bytes, 0x3c)
$optional = [int]$pe + 24
$entry = [BitConverter]::ToUInt32($bytes, $optional + 16)
$alignment = [BitConverter]::ToUInt32($bytes, $optional + 36)
$count = [BitConverter]::ToUInt16($bytes, [int]$pe + 6)
$table = $optional + [BitConverter]::ToUInt16($bytes, [int]$pe + 20)
if ($alignment -le 1) { throw 'Fixture does not have useful file alignment' }
$changed = $false
for ($i = 0; $i -lt $count; $i++) {
    $section = $table + 40 * $i
    $rva = [BitConverter]::ToUInt32($bytes, $section + 12)
    $size = [BitConverter]::ToUInt32($bytes, $section + 16)
    if ($entry -ge $rva -and [long]$entry - $rva -lt $size) {
        $raw = [BitConverter]::ToUInt32($bytes, $section + 20)
        if ($raw % $alignment -ne 0 -or $raw + 1 + $size -gt $bytes.Length) { throw 'Fixture cannot support this mutation' }
        [BitConverter]::GetBytes([uint32]($raw + 1)).CopyTo($bytes, $section + 20)
        $changed = $true
        break
    }
}
if (-not $changed) { throw 'Entry section not found' }
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$mutated = Join-Path $directory 'misaligned.exe'
[IO.File]::WriteAllBytes($mutated, $bytes)
& $probePath (Resolve-Path -LiteralPath $Executable).Path
if ($LASTEXITCODE -ne 0) { throw 'Probe rejected the original executable' }
& $probePath $mutated
if ($RequireRejected) {
    if ($LASTEXITCODE -ne 1) { throw 'Probe did not reject the misaligned adverse control' }
    Write-Output 'The experimental structural check rejected the misaligned section and accepted the original.'
} else {
    if ($LASTEXITCODE -ne 0) { throw 'Probe rejected the misaligned adverse control; update the expected result' }
    Write-Output 'Adverse control: the experimental structural check accepted an entry section with a misaligned raw offset.'
}
