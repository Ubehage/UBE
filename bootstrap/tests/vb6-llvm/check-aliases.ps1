param([string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE')
$ErrorActionPreference = 'Stop'
# Builds but never runs the fixture, so no runtime dialog or filesystem query occurs.
$output = Join-Path ([IO.Path]::GetTempPath()) ('ube-vb6-aliases-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $output | Out-Null
$project = Join-Path $PSScriptRoot 'Aliases.vbp'
$log = Join-Path $output 'build.log'
$arguments = "/make `"$project`" /out `"$log`" /outdir `"$output`""
$process = Start-Process -FilePath $VB6 -ArgumentList $arguments -PassThru -WindowStyle Hidden
if (-not $process.WaitForExit(30000)) { $process.Kill(); throw 'VB6 build timed out.' }
$process.Refresh()
Get-Content -LiteralPath $log
if ($process.ExitCode -ne 0 -or -not (Test-Path (Join-Path $output 'AliasProbe.exe'))) { throw 'Alias compile probe failed.' }
Write-Output "PASS: VB6 accepts all 14 additional dollar spellings in Aliases.bas. Artifacts: $output"
