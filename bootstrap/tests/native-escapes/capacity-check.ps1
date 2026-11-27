param([string]$VB6='C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf=New-Object Text.UTF8Encoding($false,$true)
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube escape capacity '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
Write-Output "Evidence: $evidence"
function Run([string]$File,[string[]]$Arguments,[string]$Name){
 $options=@{FilePath=$File;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=(Join-Path $evidence ($Name+'.stdout'));RedirectStandardError=(Join-Path $evidence ($Name+'.stderr'))}
 if($Arguments.Count){$options.ArgumentList=($Arguments|ForEach-Object{if($_ -match '\s'){'"'+$_+'"'}else{$_}}) -join ' '}
 $p=Start-Process @options
 try{$null=$p.Handle;if(-not $p.WaitForExit(60000)){$p.Kill();throw "Deadline $Name"};$p.Refresh();return [pscustomobject]@{Code=$p.ExitCode;Out=[IO.File]::ReadAllText($options.RedirectStandardOutput);Error=[IO.File]::ReadAllText($options.RedirectStandardError)}}finally{$p.Dispose()}
}
$modules=@('HostFiles','ProjectLoader','SourceLexer','SourceParser','SourceSemantics','NativeEscapes')
foreach($module in $modules){Copy-Item -LiteralPath (Join-Path $root ('src/'+$module+'.bas')) -Destination $evidence}
$runtime=[IO.File]::ReadAllText((Join-Path $evidence 'NativeEscapes.bas'))
$probe=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'CapacityProbe.bas'))
foreach($control in @(0,1,2)){
 $candidate=$runtime;$body=$probe
 if($control -eq 1){$candidate=$candidate.Replace('If Not ValidInput(Parsed, Bound, NodeCount, SymbolCount) Then','If NodeCount > 131072 Or Not ValidInput(Parsed, Bound, NodeCount, SymbolCount) Then');if($candidate -ceq $runtime){throw 'Old-cap control missing'}}
 if($control -eq 2){$body=$body.Replace('Facts(Count - 1).OwnerIdentity <> 3','Facts(Count - 1).OwnerIdentity <> 4');if($body -ceq $probe){throw 'Ownership control missing'}}
 [IO.File]::WriteAllText((Join-Path $evidence 'NativeEscapes.bas'),$candidate,$utf)
 [IO.File]::WriteAllText((Join-Path $evidence 'CapacityProbe.bas'),$body,$utf)
 $lines=@('Type=Exe','Module=EscapeCapacityProbe; CapacityProbe.bas')
 foreach($module in $modules){$lines+='Module='+$module+'; '+$module+'.bas'}
 $name='capacity'+$control
 $lines+=@('Startup="Sub Main"','Name="EscapeCapacityTests"',('ExeName32="'+$name+'.exe"'),'CompilationType=0','BoundsCheck=1','OverflowCheck=1')
 $project=Join-Path $evidence ($name+'.vbp');[IO.File]::WriteAllText($project,($lines -join "`r`n")+"`r`n",$utf)
 $r=Run $VB6 @('/make',$project,'/out',(Join-Path $evidence ($name+'-build.log')),'/outdir',$evidence) ($name+'-build')
 if($r.Code -ne 0 -or -not(Test-Path -LiteralPath (Join-Path $evidence ($name+'.exe')))){throw "VB6 build failed $name"}
 $r=Run (Join-Path $evidence ($name+'.exe')) @() ($name+'-run')
 if($control -eq 0){if($r.Code -ne 0 -or $r.Error.Length -ne 0 -or $r.Out.Trim() -cne 'PASS: escape capacity, retained ownership, rejection and retry'){throw "Capacity assertions failed $($r.Code) $($r.Out) $($r.Error)"}}
 else{if($r.Code -ne 1 -or $r.Error -notmatch 'FAIL: escape capacity'){throw "Negative control did not reject $name"}}
 Write-Output "PASS $name exit=$($r.Code)"
}
[IO.File]::WriteAllText((Join-Path $evidence 'NativeEscapes.bas'),$runtime,$utf)
[IO.File]::WriteAllText((Join-Path $evidence 'CapacityProbe.bas'),$probe,$utf)
$seed=Join-Path $evidence 'seed'
$null=New-Item -ItemType Directory -Path $seed
Copy-Item -LiteralPath (Join-Path $root 'UBE-Bootstrap.vbp') -Destination $seed
Copy-Item -LiteralPath (Join-Path $root 'src') -Destination $seed -Recurse
$runtimeFolder=Join-Path $evidence 'runtime/bootstrap'
$null=New-Item -ItemType Directory -Path $runtimeFolder -Force
foreach($name in @('NativeThreadRuntime.bas','NativeManagedRuntime.bas','NativeObjectRuntime.bas')){Copy-Item -LiteralPath (Join-Path $root ('../runtime/bootstrap/'+$name)) -Destination $runtimeFolder}
$r=Run $VB6 @('/make',(Join-Path $seed 'UBE-Bootstrap.vbp'),'/out',(Join-Path $seed 'build.log'),'/outdir',$seed) 'seed-build'
$exe=Join-Path $seed 'UBE-Bootstrap.exe'
if($r.Code -ne 0 -or -not(Test-Path -LiteralPath $exe)){throw 'Fresh seed build failed'}
Write-Output "PASS fresh seed $exe SHA256=$((Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash)"
