$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$run = Join-Path $root ('bootstrap/out/v2-usage/' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$shell = (Get-Process -Id $PID).Path
$helper = Join-Path $root 'bootstrap/compile-v2.ps1'
$source = Join-Path $root 'compiler/UBE_Compiler_v2/tests/foundation/byte-array.bas'
$exe = Join-Path $run 'byte-array.exe'
$commands = @()
$success = $false
try {
    $compile = Invoke-BoundedProcess $shell @('-NoProfile','-File',$helper,'-Source',$source,'-Output',$exe) $root 30
    $commands += $compile
    if ($compile.timedOut -or $compile.exit -ne 0 -or -not (Test-Path -LiteralPath $exe)) { throw ($compile | ConvertTo-Json -Depth 5) }
    $native = Invoke-BoundedProcess $exe @() $root
    $commands += $native
    if ($native.timedOut -or $native.exit -ne 0 -or $native.stdout -cne "65`n0`n255`n128`n0`n" -or $native.stderr -cne '') { throw 'Compile-helper native oracle failed' }
    $before = (Get-ArtifactIdentity $exe).sha256
    $bad = Join-Path $root 'compiler/UBE_Compiler_v2/tests/foundation/constant-byte-overflow.bas'
    $rejected = Invoke-BoundedProcess $shell @('-NoProfile','-File',$helper,'-Source',$bad,'-Output',$exe) $root 30
    $commands += $rejected
    if ($rejected.timedOut -or $rejected.exit -ne 1 -or ($rejected.stdout + $rejected.stderr) -notmatch 'constant is outside') { throw 'Compile-helper rejection oracle failed' }
    if ((Get-ArtifactIdentity $exe).sha256 -cne $before) { throw 'Rejected compile changed the prior executable' }
    # Replace an existing output on a second successful compile as well.
    $again = Invoke-BoundedProcess $shell @('-NoProfile','-File',$helper,'-Source',$source,'-Output',$exe) $root 30
    $commands += $again
    if ($again.timedOut -or $again.exit -ne 0) { throw 'Successful executable replacement failed' }
    $native = Invoke-BoundedProcess $exe @() $root
    $commands += $native
    if ($native.exit -ne 0 -or $native.stdout -cne "65`n0`n255`n128`n0`n" -or $native.stderr -cne '') { throw 'Replaced executable oracle failed' }
    # Isolated synthetic selection: a changed C header must reject before any
    # compiler execution or output publication. The real selection is untouched.
    $fixture = Join-Path $run 'header-identity'
    $fixtureBootstrap = Join-Path $fixture 'bootstrap'
    $fixtureCurrent = Join-Path $fixtureBootstrap 'out/v2'
    New-Item -ItemType Directory -Path $fixtureCurrent -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $fixtureBootstrap 'tools') -Force | Out-Null
    [IO.File]::Copy($helper,(Join-Path $fixtureBootstrap 'compile-v2.ps1'))
    [IO.File]::Copy((Join-Path $root 'bootstrap/tools/verification.ps1'),(Join-Path $fixtureBootstrap 'tools/verification.ps1'))
    $header = Join-Path $fixture 'storage.h'
    [IO.File]::WriteAllText($header,'original header')
    $real = Get-Content -LiteralPath (Join-Path $root 'bootstrap/out/v2/current.json') -Raw | ConvertFrom-Json
    $synthetic = Join-Path $fixtureCurrent 'manifest.json'
    [pscustomobject]@{success=$true;inputs=@((Get-ArtifactIdentity $header))} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $synthetic -Encoding UTF8
    $real.manifest = Get-ArtifactIdentity $synthetic
    $real | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $fixtureCurrent 'current.json') -Encoding UTF8
    [IO.File]::WriteAllText($header,'changed header')
    $before = (Get-ArtifactIdentity $exe).sha256
    $rejected = Invoke-BoundedProcess $shell @('-NoProfile','-File',(Join-Path $fixtureBootstrap 'compile-v2.ps1'),'-Source',$source,'-Output',$exe) $root 30
    $commands += $rejected
    if ($rejected.timedOut -or $rejected.exit -ne 1 -or ($rejected.stdout+$rejected.stderr) -notmatch 'Source changed since the v2 gate:.*storage\.h') { throw 'Changed C header bypassed accepted input identity' }
    if ((Get-ArtifactIdentity $exe).sha256 -cne $before) { throw 'Header rejection changed the existing executable' }
    $success = $true
    Write-Output 'Compile helper passed: exact byte-array native output, controlled invalid-constant rejection, prior executable preserved and successful replacement.'
} finally {
    [pscustomobject]@{ success = $success; commands = $commands } | ConvertTo-Json -Depth 9 |
        Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
    Write-Output (Join-Path $run 'report.json')
}
