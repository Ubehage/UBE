param([Parameter(Mandatory=$true)][string]$BootstrapExe,[string]$LoweredIR='', [int]$ExerciseSymbol=0, [string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$utf8=New-Object Text.UTF8Encoding($false,$true)
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube worker faults '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $artifacts
$script:sequence=0
Write-Output "Evidence: $artifacts"
# Bounds every native process and retains exact output and exit status.
function Run([string]$File,[string[]]$Arguments){
 $script:sequence++;$prefix=Join-Path $artifacts ('process-'+$script:sequence)
 $quoted=($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' '
 $options=@{FilePath=$File;WorkingDirectory=$artifacts;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=$quoted}
 $p=Start-Process @options
 try{$handle=$p.Handle;if(-not $p.WaitForExit(60000)){$p.Kill();$null=$p.WaitForExit(5000);throw "Deadline: $prefix"};$p.Refresh();return [pscustomobject]@{Code=$p.ExitCode;Out=[IO.File]::ReadAllText($prefix+'.stdout',$utf8);Error=[IO.File]::ReadAllText($prefix+'.stderr',$utf8);Evidence=$prefix}}finally{$p.Dispose()}
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Faults.bas') -Destination (Join-Path $artifacts 'Faults.bas')
Copy-Item -LiteralPath (Join-Path $root 'std-lib/src/portable/ThreadPrimitives.bas') -Destination (Join-Path $artifacts 'ThreadPrimitives.bas')
$manifest=Join-Path $artifacts 'faults.UBE'
[IO.File]::WriteAllText($manifest,"UBE-Project 1`r`nName = `"CaptureFaults`"`r`nKind = `"Library`"`r`nSource = `"ThreadPrimitives.bas`"`r`nSource = `"Faults.bas`"`r`n",$utf8)
$bound=Run $BootstrapExe @('--dump-bound',$manifest)
if($bound.Code -ne 0){throw "Binding failed: $($bound.Evidence) $($bound.Error)"}
$symbol=[regex]::Match($bound.Out,'(?m)^SYMBOL ([0-9]+)\|function\|Exercise\|')
if(-not $symbol.Success){throw 'Missing Exercise identity'}
if($ExerciseSymbol -eq 0){$ExerciseSymbol=[int]$symbol.Groups[1].Value}
if(-not $LoweredIR){
 $LoweredIR=Join-Path $artifacts 'faults.ll'
 $emit=Run $BootstrapExe @('--emit-llvm',$manifest,$LoweredIR)
 if($emit.Code -ne 0){throw "Emission failed: $($emit.Evidence) $($emit.Error)"}
}
$source=[IO.File]::ReadAllText($LoweredIR,$utf8)
if(-not $source.Contains('@ube.proc.'+$ExerciseSymbol+'(ptr %ctx)')){throw 'Lowered corpus does not match the supplied qualified source identity'}
$source=$source.Replace('define ptr @ube.target.allocate(', 'define ptr @ube.target.allocate.real(').Replace('define i1 @ube.target.release(', 'define i1 @ube.target.release.real(').Replace('define ptr @ube.target.thread.start(', 'define ptr @ube.target.thread.start.real(')
$probe=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'faults.ll'),$utf8).Replace('EXERCISE',[string]$ExerciseSymbol)
$library=Join-Path $artifacts 'kernel32.lib'
$imports=Run (Join-Path ([IO.Path]::GetDirectoryName($Clang)) 'llvm-dlltool.exe') @('-m','i386:x86-64','-d',(Join-Path $root 'compiler/llvm/kernel32.def'),'-l',$library)
if($imports.Code -ne 0){throw "Import generation failed: $($imports.Evidence)"}
$baseline=0
foreach($level in @('O0','O2')){
 $ir=Join-Path $artifacts ($level+'.ll');$exe=Join-Path $artifacts ($level+'.exe')
 [IO.File]::WriteAllText($ir,($source+"`r`n"+$probe),$utf8)
 $build=Run $Clang @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-'+$level),$ir,$library,'-o',$exe,'-Wl,/entry:main,/subsystem:console,/stack:8388608')
 if($build.Code -ne 0){throw "Native build failed: $($build.Evidence) $($build.Error)"}
 $result=Run $exe @()
 if($result.Code -lt 8 -or $result.Code -ge 64 -or $result.Out -ne '' -or $result.Error -ne ''){throw "Fault matrix failed exit $($result.Code): $($result.Evidence)"}
 if($baseline -ne 0 -and $result.Code -ne $baseline){throw 'Optimization changed allocation-site coverage'}
 $baseline=$result.Code
 Write-Output "PASS $level`: $baseline allocation sites each fail both target attempts, native startup failure, recovery after every fault and zero live allocations"
}
