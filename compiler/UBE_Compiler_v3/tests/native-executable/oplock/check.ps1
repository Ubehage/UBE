param([Parameter(Mandatory = $true)][string] $Probe, [Parameter(Mandatory = $true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$root = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($root) | Out-Null
$directory = Join-Path $root ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
[IO.File]::WriteAllText((Join-Path $directory 'destination.bin'), 'sentinel')
& $probePath $directory
if ($LASTEXITCODE -ne 0) { throw "Oplock probe failed: $LASTEXITCODE" }
$moved = Join-Path $directory 'moved.bin'
if (-not [IO.File]::Exists($moved) -or [IO.File]::ReadAllText($moved) -cne 'sentinel' -or [IO.File]::Exists((Join-Path $directory 'destination.bin'))) { throw 'Wrong moved-file result' }
Write-Output "Passed focused oplock observation: $directory"
