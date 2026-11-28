# Checks actual seed token boundaries, independently of the limited seed expression backend.
param([string]$VB6='C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube seed suffix lexical '+[guid]::NewGuid())
$null=New-Item -ItemType Directory $artifacts
$sources=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../src'))
$vbp=@('Type=Exe',('Module=SuffixHost; '+(Join-Path $PSScriptRoot 'SuffixHost.bas')))
foreach($name in @('HostFiles','ProjectLoader','SourceLexer','SourceParser','SourceSemantics','NativeEscapes')){$vbp+='Module='+$name+'; '+(Join-Path $sources ($name+'.bas'))}
$vbp+=@('Startup="Sub Main"','Name="SuffixTests"','ExeName32="SuffixHost.exe"','CompilationType=0','BoundsCheck=1','OverflowCheck=1')
$project=Join-Path $artifacts 'Probe.vbp'
[IO.File]::WriteAllText($project,($vbp -join "`r`n")+"`r`n",[Text.Encoding]::ASCII)
$log=Join-Path $artifacts 'build.log'
$p=Start-Process $VB6 -ArgumentList ('/make "'+$project+'" /out "'+$log+'" /outdir "'+$artifacts+'"') -WindowStyle Hidden -PassThru
try{$null=$p.Handle;if(-not $p.WaitForExit(30000)){$p.Kill();throw 'Build deadline'};$p.Refresh();if($p.ExitCode -ne 0){throw "Build failed: $artifacts"}}finally{$p.Dispose()}
$p=Start-Process (Join-Path $artifacts 'SuffixHost.exe') -WindowStyle Hidden -PassThru
try{$null=$p.Handle;if(-not $p.WaitForExit(30000)){$p.Kill();throw 'Execution deadline'};$p.Refresh();if($p.ExitCode -ne 0){throw "Lexical assertion $($p.ExitCode) failed: $artifacts"}}finally{$p.Dispose()}
Write-Output "PASS: seed caret operator, longest numeric suffix and unchanged string contents. Evidence: $artifacts"
