# Observes installed VB6 conversion details only; UBE's explicit invariant rules take precedence.
param([string]$VB6='C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE')
$ErrorActionPreference='Stop'
$folder=Join-Path ([IO.Path]::GetTempPath()) ('ube vb6 numeric observations '+[guid]::NewGuid())
$null=New-Item -ItemType Directory $folder
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'NumericProbe.bas') -Destination $folder
$project=Join-Path $folder 'Probe.vbp'
@('Type=Exe','Module=NumericProbe; NumericProbe.bas','Startup="Sub Main"','Name="NumericObservation"','ExeName32="NumericProbe.exe"','CompilationType=0','BoundsCheck=1','OverflowCheck=1') | Set-Content -LiteralPath $project -Encoding ASCII
$log=Join-Path $folder 'build.log'
$p=Start-Process $VB6 -ArgumentList "/make `"$project`" /out `"$log`" /outdir `"$folder`"" -PassThru -WindowStyle Hidden
try {$handle=$p.Handle;if(-not $p.WaitForExit(30000)){$p.Kill();throw 'VB6 build deadline'}} finally {$p.Dispose()}
if(-not(Test-Path -LiteralPath (Join-Path $folder 'NumericProbe.exe'))){Get-Content $log;throw 'VB6 build failed'}
$p=Start-Process (Join-Path $folder 'NumericProbe.exe') -PassThru -WindowStyle Hidden
try {$handle=$p.Handle;if(-not $p.WaitForExit(10000)){$p.Kill();throw 'VB6 probe deadline'}} finally {$p.Dispose()}
Get-Content -LiteralPath (Join-Path $folder 'observations.txt')
Write-Output "Evidence: $folder"
