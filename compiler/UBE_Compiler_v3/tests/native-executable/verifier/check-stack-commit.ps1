param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $Readobj,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'stack-limits.c'
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$exe = Join-Path $OutputDirectory 'stack-committed.exe'
& $Clang --target=x86_64-w64-windows-gnu -std=c17 -O2 -Wall -Wextra -Werror $source -Xlinker --stack -Xlinker '262144,262144' -o $exe
if ($LASTEXITCODE -ne 0) { throw 'Stack commit test link failed' }
$headers = (& $Readobj --file-headers $exe) -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'Stack header inspection failed' }
function Check-Header([string] $text, [int] $reserve, [int] $commit) {
    $r = [regex]::Match($text, '(?m)^\s*SizeOfStackReserve:\s*(\d+)\s*$')
    $c = [regex]::Match($text, '(?m)^\s*SizeOfStackCommit:\s*(\d+)\s*$')
    return $r.Success -and $c.Success -and [long]$r.Groups[1].Value -eq $reserve -and [long]$c.Groups[1].Value -eq $commit
}
if (-not (Check-Header $headers 262144 262144) -or (Check-Header $headers 262143 262144)) { throw 'Stack header or wrong-value control failed' }
$observed = @(& (Resolve-Path -LiteralPath $exe).Path)
if ($LASTEXITCODE -ne 0 -or $observed.Count -ne 6 -or $observed[0] -ne 'main and worker local addresses lie within their reported bounds') { throw 'Stack commit executable failed' }
if ($observed[1] -notin @('main lower-bound page reserved','main lower-bound page guarded','main lower-bound page committed','main lower-bound page other')) { throw 'Unknown main-boundary state' }
if ($observed[2] -notmatch '^main regions reserved=\d+ committed=\d+ guarded=\d+ other=\d+$') { throw 'Invalid main region observation' }
Write-Output "Header reserve=262144 commit=262144; $($observed[1]); wrong-header control rejected."
Write-Output $observed[2]
if ($observed[5] -notmatch '^worker regions reserved=\d+ committed=\d+ guarded=\d+ other=\d+$') { throw 'Invalid worker region observation' }
Write-Output $observed[5]
