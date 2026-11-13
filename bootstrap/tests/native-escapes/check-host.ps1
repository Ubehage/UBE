param(
    [Parameter(Mandatory=$true)][string]$FixtureProject,
    [string]$VB6='C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE'
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf8=New-Object Text.UTF8Encoding($false,$true)
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube host escapes '+[guid]::NewGuid())
$null=New-Item -ItemType Directory $artifacts
Write-Output "Artifacts retained: $artifacts"
$sources=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../src'))
$vbp=@('Type=Exe',('Module=EscapeHostProbe; '+(Join-Path $PSScriptRoot 'HostProbe.bas')))
foreach($name in @('HostFiles','ProjectLoader','SourceLexer','SourceParser','SourceSemantics','NativeEscapes')){$vbp+='Module='+$name+'; '+(Join-Path $sources ($name+'.bas'))}
$vbp+=@('Startup="Sub Main"','Name="EscapeHostTests"','ExeName32="EscapeHostProbe.exe"','CompilationType=0','BoundsCheck=1','OverflowCheck=1')
$project=Join-Path $artifacts 'Probe.vbp'
[IO.File]::WriteAllText($project,($vbp -join "`r`n")+"`r`n",$utf8)
$log=Join-Path $artifacts 'build.log'
$process=Start-Process -FilePath $VB6 -ArgumentList ('/make "'+$project+'" /out "'+$log+'" /outdir "'+$artifacts+'"') -WindowStyle Hidden -PassThru
try{$handle=$process.Handle;if(-not $process.WaitForExit(30000)){$process.Kill();throw 'Host probe build timeout'};$process.Refresh();$code=$process.ExitCode}finally{$process.Dispose()}
if(Test-Path -LiteralPath $log){Get-Content -LiteralPath $log}
$exe=Join-Path $artifacts 'EscapeHostProbe.exe'
if($code -ne 0 -or -not(Test-Path -LiteralPath $exe)){throw 'Host probe build failed'}
$stdout=Join-Path $artifacts 'probe.stdout';$stderr=Join-Path $artifacts 'probe.stderr'
$process=Start-Process -FilePath $exe -ArgumentList ('"'+[IO.Path]::GetFullPath($FixtureProject)+'"') -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
try{$handle=$process.Handle;if(-not $process.WaitForExit(30000)){$process.Kill();throw 'Host probe execution timeout'};$process.Refresh();$code=$process.ExitCode}finally{$process.Dispose()}
$out=[IO.File]::ReadAllText($stdout,$utf8);$err=[IO.File]::ReadAllText($stderr,$utf8)
if($code -ne 0 -or $err.Length -ne 0 -or $out.Trim() -cne 'PASS: host escape ownership, bounded rejection and retry'){throw "Host escape assertions failed: $out $err"}
Write-Output $out.Trim()
