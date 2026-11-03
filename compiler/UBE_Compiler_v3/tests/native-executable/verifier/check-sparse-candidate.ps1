param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$root = (Resolve-Path -LiteralPath $OutputDirectory).Path
$exe = Join-Path $root 'sparse-candidate.exe'
$source = Join-Path $PSScriptRoot 'sparse-candidate.c'
& $Clang --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode $source -o $exe
if ($LASTEXITCODE -ne 0) { throw 'Sparse-candidate probe compilation failed' }
$candidate = Join-Path $root (([guid]::NewGuid().ToString('N')) + '.bin')
$output = @(& $exe $candidate); $status = $LASTEXITCODE
if ($status -ne 0 -or $output.Count -ne 1 -or $output[0] -notmatch '^logical=(\d+) allocated=(\d+)$') { throw "Sparse observation failed: $status $output" }
$logical = [long]$Matches[1]; $allocated = [long]$Matches[2]
if ($logical -ne 33554432 -or $allocated -lt 0 -or $allocated -ge $logical -or [IO.File]::Exists($candidate)) { throw 'Sparse lengths or cleanup failed' }
Write-Output "Sparse candidate: logical=$logical allocated=$allocated; temporary file removed."
