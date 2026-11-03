param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$destination = Join-Path $directory 'destination.bin'
$candidate = Join-Path $directory 'candidate.bin'
[IO.File]::WriteAllText($destination, 'old')
[IO.File]::WriteAllText($candidate, 'new')
$result = @(& $probePath $destination $candidate 2>&1)
if ($LASTEXITCODE -ne 0 -or $result.Count -ne 2 -or $result[0] -ne 'locked replacement failed: 32' -or
    $result[1] -ne 'replacement after unlock succeeded') { throw "Unexpected replacement observations: $result" }
if ([IO.File]::ReadAllText($destination) -ne 'new' -or [IO.File]::Exists($candidate)) { throw 'Incorrect final files' }
Write-Output "ReplaceFileW blocked by protected destination; unlocked control passed: $directory"
