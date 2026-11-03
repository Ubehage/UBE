param([Parameter(Mandatory = $true)][string] $Probe)
$ErrorActionPreference = 'Stop'
$path = (Resolve-Path -LiteralPath $Probe).Path
& $path
if ($LASTEXITCODE -ne 0) { throw "Argument round trip failed: $LASTEXITCODE" }
& $path wrong
if ($LASTEXITCODE -ne 0) { throw "Wrong-argument control failed: $LASTEXITCODE" }
Write-Output 'Passed argument round trip and wrong-argument control.'
