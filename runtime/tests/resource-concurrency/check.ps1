param([Parameter(Mandatory=$true)][string]$BootstrapExe,[string]$LoweredIR='', [int]$ProbeSymbol=0, [string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$utf8=New-Object Text.UTF8Encoding($false,$true)
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube resource concurrency '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $artifacts
$script:sequence=0
Write-Output "Evidence: $artifacts"
function Run([string]$File,[string[]]$Arguments){
 $script:sequence++;$prefix=Join-Path $artifacts ('process-'+$script:sequence)
 $quoted=($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' '
 $options=@{FilePath=$File;WorkingDirectory=$artifacts;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=$quoted}
 $p=Start-Process @options
 try{$handle=$p.Handle;if(-not $p.WaitForExit(60000)){$p.Kill();$null=$p.WaitForExit(5000);throw "Deadline: $prefix"};$p.Refresh();$result=[pscustomobject]@{Code=$p.ExitCode;Out=[IO.File]::ReadAllText($prefix+'.stdout',$utf8);Error=[IO.File]::ReadAllText($prefix+'.stderr',$utf8);Evidence=$prefix}}finally{$p.Dispose()}
 if($result.Code -ne 0 -or $result.Error -ne ''){throw "Failed exit $($result.Code): $prefix $($result.Error)"}
 return $result
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Owners.bas') -Destination (Join-Path $artifacts 'Owners.bas')
foreach($name in @('FilePrimitives','ThreadPrimitives')){Copy-Item -LiteralPath (Join-Path $root ('std-lib/src/portable/'+$name+'.bas')) -Destination (Join-Path $artifacts ($name+'.bas'))}
$manifest=Join-Path $artifacts 'owners.UBE'
[IO.File]::WriteAllText($manifest,"UBE-Project 1`r`nName = `"ResourceOwners`"`r`nKind = `"Library`"`r`nSource = `"ThreadPrimitives.bas`"`r`nSource = `"FilePrimitives.bas`"`r`nSource = `"Owners.bas`"`r`n",$utf8)
$bound=Run $BootstrapExe @('--dump-bound',$manifest)
$probe=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'probe.ll'),$utf8)
$symbol=[regex]::Match($bound.Out,'(?m)^SYMBOL ([0-9]+)\|function\|Probe\|')
if(-not $symbol.Success){throw 'Missing Probe identity'}
if($ProbeSymbol -eq 0){$ProbeSymbol=[int]$symbol.Groups[1].Value}
$probe=$probe.Replace('PROBE',[string]$ProbeSymbol)
if(-not $LoweredIR){
 $LoweredIR=Join-Path $artifacts 'owners.ll'
 $null=Run $BootstrapExe @('--emit-llvm',$manifest,$LoweredIR)
}
$source=[IO.File]::ReadAllText($LoweredIR,$utf8)
$source=$source.Replace('define ptr @ube.target.allocate(', 'define ptr @ube.target.allocate.real(').Replace('define i1 @ube.target.release(', 'define i1 @ube.target.release.real(')
$library=Join-Path $artifacts 'kernel32.lib'
$null=Run (Join-Path ([IO.Path]::GetDirectoryName($Clang)) 'llvm-dlltool.exe') @('-m','i386:x86-64','-d',(Join-Path $root 'compiler/llvm/kernel32.def'),'-l',$library)
foreach($level in @('O0','O2')){
 $ir=Join-Path $artifacts ($level+'.ll');$exe=Join-Path $artifacts ($level+'.exe')
 [IO.File]::WriteAllText($ir,($source+"`r`n"+$probe),$utf8)
 $null=Run $Clang @('--target=x86_64-pc-windows-msvc','-Wno-override-module','-fuse-ld=lld','-nostdlib',('-'+$level),$ir,$library,'-o',$exe,'-Wl,/entry:main,/subsystem:console,/stack:8388608')
 $result=Run $exe @()
 if($result.Out -ne ''){throw 'Unexpected native output'}
 if(@(Get-ChildItem -LiteralPath $artifacts -Filter '*.bin').Count -ne 0){throw 'Source cleanup left a test file'}
 Write-Output "PASS $level`: four schedules, eight workers, 128 files and 256 unique tokens per schedule; exact bytes, same-owner Busy, empty registry and zero allocations after disposal"
}
