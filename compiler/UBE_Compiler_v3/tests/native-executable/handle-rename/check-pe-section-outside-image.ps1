param(
    [Parameter(Mandatory=$true)][string] $Probe,
    [Parameter(Mandatory=$true)][string] $Executable,
    [Parameter(Mandatory=$true)][string] $OutputDirectory,
    [switch] $RequireRejected,
    [switch] $CrossEnd
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$executablePath = (Resolve-Path -LiteralPath $Executable).Path
$bytes = [IO.File]::ReadAllBytes($executablePath)
$pe = [BitConverter]::ToUInt32($bytes, 0x3c)
$optional = [int]$pe + 24
$entry = [BitConverter]::ToUInt32($bytes, $optional + 16)
$imageSize = [BitConverter]::ToUInt32($bytes, $optional + 56)
$sectionAlignment = [BitConverter]::ToUInt32($bytes, $optional + 32)
$count = [BitConverter]::ToUInt16($bytes, [int]$pe + 6)
$table = $optional + [BitConverter]::ToUInt16($bytes, [int]$pe + 20)
if ($sectionAlignment -eq 0 -or $imageSize % $sectionAlignment -ne 0) { throw 'Fixture has unsuitable image alignment' }
$changed = $false
for ($i = 0; $i -lt $count; $i++) {
    $section = $table + 40 * $i
    $rva = [BitConverter]::ToUInt32($bytes, $section + 12)
    $rawSize = [BitConverter]::ToUInt32($bytes, $section + 16)
    if ($rawSize -gt 0 -and -not ($entry -ge $rva -and [long]$entry - $rva -lt $rawSize)) {
        if ($CrossEnd) {
            if ($rva -ge $imageSize -or [long]$imageSize - $rva + 1 -gt [uint32]::MaxValue) { throw 'Fixture cannot support end mutation' }
            [BitConverter]::GetBytes([uint32]([long]$imageSize - $rva + 1)).CopyTo($bytes, $section + 8)
        } else {
            [BitConverter]::GetBytes($imageSize).CopyTo($bytes, $section + 12)
        }
        $changed = $true
        break
    }
}
if (-not $changed) { throw 'No non-entry section found' }
if ($CrossEnd) {
    if ([long]$rva + [BitConverter]::ToUInt32($bytes, $section + 8) -ne [long]$imageSize + 1) { throw 'Mutation did not cross the image end' }
} elseif ([BitConverter]::ToUInt32($bytes, $section + 12) -ne $imageSize) { throw 'Mutation did not place the section at the image end' }
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$mutated = Join-Path $directory 'section-outside-image.exe'
[IO.File]::WriteAllBytes($mutated, $bytes)
& $probePath $executablePath
if ($LASTEXITCODE -ne 0) { throw 'Probe rejected the original executable' }
& $probePath $mutated
if ($RequireRejected) {
    if ($LASTEXITCODE -ne 1) { throw 'Probe failed to reject the section outside the image' }
    Write-Output 'The experimental probe rejected the section outside the image and accepted the original.'
} else {
    if ($LASTEXITCODE -ne 0) { throw 'Probe rejected the adverse control; update the expected result' }
    Write-Output 'Adverse control: the experimental structural probe accepted a section outside the declared image.'
}
