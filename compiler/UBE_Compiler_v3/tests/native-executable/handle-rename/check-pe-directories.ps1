param([Parameter(Mandatory=$true)][string] $Probe,
      [Parameter(Mandatory=$true)][string] $Executable,
      [Parameter(Mandatory=$true)][string] $OutputDirectory,
      [switch] $RequireRejected)
$ErrorActionPreference = 'Stop'
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$inputPath = (Resolve-Path -LiteralPath $Executable).Path
$bytes = [IO.File]::ReadAllBytes($inputPath)
$pe = [BitConverter]::ToUInt32($bytes, 0x3c)
$optionalSize = [BitConverter]::ToUInt16($bytes, [int]$pe + 20)
$optional = [int]$pe + 24
if ($optionalSize -lt 112 -or [BitConverter]::ToUInt16($bytes, $optional) -ne 0x20b) { throw 'Fixture is not PE32+' }
$capacity = [uint32][Math]::Floor(($optionalSize - 112) / 8)
$oldCount = [BitConverter]::ToUInt32($bytes, $optional + 108)
if ($oldCount -gt $capacity) { throw 'Original directory count is already invalid' }
[BitConverter]::GetBytes([uint32]($capacity + 1)).CopyTo($bytes, $optional + 108)
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$mutated = Join-Path $directory 'directory-overflow.exe'
[IO.File]::WriteAllBytes($mutated, $bytes)
& $probePath $inputPath
if ($LASTEXITCODE -ne 0) { throw 'Probe rejected original executable' }
& $probePath $mutated
if ($RequireRejected) {
    if ($LASTEXITCODE -ne 1) { throw 'Probe accepted excessive directory count' }
    Write-Output 'Directory-count mutation rejected and original accepted.'
} else {
    if ($LASTEXITCODE -ne 0) { throw 'Omitted-check control rejected mutation' }
    Write-Output 'Omitted-check control accepted excessive directory count.'
}
