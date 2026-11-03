param([Parameter(Mandatory = $true)][string] $Probe, [Parameter(Mandatory = $true)][string] $OutputDirectory, [switch] $Native)
$ErrorActionPreference = 'Stop'
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$root = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($root) | Out-Null
$directory = Join-Path $root ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$control = Join-Path $directory 'control'
[IO.Directory]::CreateDirectory($control) | Out-Null
[IO.File]::WriteAllText((Join-Path $control 'destination.bin'), 'old')
[IO.File]::WriteAllText((Join-Path $control 'candidate.bin'), 'new')
$controlMode = if ($Native) { 'native-unlocked' } else { 'unlocked' }
& $probePath $control $controlMode
if ($LASTEXITCODE -ne 0 -or [IO.File]::ReadAllText((Join-Path $control 'destination.bin')) -cne 'new') { throw 'Unlocked control failed' }
[IO.File]::WriteAllText((Join-Path $directory 'destination.bin'), 'old')
[IO.File]::WriteAllText((Join-Path $directory 'candidate.bin'), 'new')
$ErrorActionPreference = 'Continue'
$arguments = @($directory)
if ($Native) { $arguments += 'native' }
$output = @(& $probePath @arguments 2>&1 | ForEach-Object { "$_" })
$status = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($status -ne 1 -or ($output -join "`n") -cne 'break=258 early=0 finish=0 result=5') { throw "Unexpected own-commit observation: $status $output" }
if ([IO.File]::ReadAllText((Join-Path $directory 'destination.bin')) -cne 'old' -or [IO.File]::ReadAllText((Join-Path $directory 'candidate.bin')) -cne 'new') { throw 'Wrong preserved files' }
Write-Output "Observed unlocked success and locked same-process access denial: $directory"
