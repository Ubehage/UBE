param([string]$CompilerExe='', [string]$LoweredIR='', [int]$ExpectedExit=0,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$utf8=New-Object Text.UTF8Encoding($false,$true)
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube array declaration '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $artifacts
$script:sequence=0
Write-Output "Evidence: $artifacts"
function Run([string]$File,[string[]]$Arguments){
 $script:sequence++;$prefix=Join-Path $artifacts ('process-'+$script:sequence)
 $quoted=($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' '
 $options=@{FilePath=$File;WorkingDirectory=$artifacts;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=$quoted}
 $p=Start-Process @options
 try{$handle=$p.Handle;if(-not $p.WaitForExit(60000)){$p.Kill();$null=$p.WaitForExit(5000);throw "Deadline: $prefix"};$p.Refresh();return [pscustomobject]@{Code=$p.ExitCode;Out=[IO.File]::ReadAllText($prefix+'.stdout',$utf8);Error=[IO.File]::ReadAllText($prefix+'.stderr',$utf8);Evidence=$prefix}}finally{$p.Dispose()}
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Probe.bas') -Destination (Join-Path $artifacts 'Probe.bas')
Copy-Item -LiteralPath (Join-Path $root 'std-lib/src/portable/ThreadPrimitives.bas') -Destination (Join-Path $artifacts 'ThreadPrimitives.bas')
$manifest=Join-Path $artifacts 'probe.UBE'
[IO.File]::WriteAllText($manifest,"UBE-Project 1`r`nName = `"ArrayDeclaration`"`r`nKind = `"Library`"`r`nSource = `"ThreadPrimitives.bas`"`r`nSource = `"Probe.bas`"`r`n",$utf8)
$lowered=$LoweredIR
if(-not $lowered){
 if(-not $CompilerExe){throw 'CompilerExe or LoweredIR is required'}
 $lowered=Join-Path $artifacts 'source.ll'
 $emission=Run $CompilerExe @('--emit-llvm',$manifest,$lowered)
 if($emission.Code -ne 0 -or $emission.Error -ne '' -or -not(Test-Path -LiteralPath $lowered)){throw "Emission failed: $($emission.Evidence) $($emission.Out) $($emission.Error)"}
}
$source=[IO.File]::ReadAllText($lowered,$utf8)
$probe=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'probe.ll'),$utf8)
# Discover actual lowerer identities through unique source return constants, not host numbering.
foreach($entry in @(@('INTERLEAVE','93017'),@('PROBE','93018'))){
 $matches=@([regex]::Matches($source,'(?ms)^define \{ i1, i64 \} @ube\.proc\.([0-9]+)\([^\r\n]*\) \{(.*?)^\}') | Where-Object{$_.Groups[2].Value -match ('\b'+$entry[1]+'\b')})
 if($matches.Count -ne 1){throw "Expected one source identity for $($entry[0])"}
 $probe=$probe.Replace($entry[0],$matches[0].Groups[1].Value)
}
foreach($anchor in @('define ptr @ube.target.allocate(','define i1 @ube.target.release(','define internal void @ube.array.clear(')){
 if(([regex]::Matches($source,[regex]::Escape($anchor))).Count -ne 1){throw "Missing unique wrapper: $anchor"}
}
$source=$source.Replace('define ptr @ube.target.allocate(','define ptr @ube.target.allocate.real(').Replace('define i1 @ube.target.release(','define i1 @ube.target.release.real(').Replace('define internal void @ube.array.clear(','define internal void @test.real.array.clear(')
$library=Join-Path $artifacts 'kernel32.lib'
$imports=Run (Join-Path ([IO.Path]::GetDirectoryName($Clang)) 'llvm-dlltool.exe') @('-m','i386:x86-64','-d',(Join-Path $root 'compiler/llvm/kernel32.def'),'-l',$library)
if($imports.Code -ne 0){throw "Imports failed: $($imports.Evidence)"}
foreach($level in @('O0','O2')){
 $ir=Join-Path $artifacts ($level+'.ll');$exe=Join-Path $artifacts ($level+'.exe')
 [IO.File]::WriteAllText($ir,($source+"`r`n"+$probe),$utf8)
 $build=Run $Clang @('--target=x86_64-pc-windows-msvc','-Wno-override-module','-fuse-ld=lld','-nostdlib',('-'+$level),$ir,$library,'-o',$exe,'-Wl,/entry:main,/subsystem:console,/stack:8388608')
 if($build.Code -ne 0){throw "Build failed: $($build.Evidence) $($build.Error)"}
 $result=Run $exe @()
 if($result.Code -ne $ExpectedExit -or $result.Out -ne '' -or $result.Error -ne ''){throw "Expected exit $ExpectedExit, observed $($result.Code): $($result.Evidence) $($result.Error)"}
 Write-Output "PASS $level expected exit $ExpectedExit (source values=bit1, cleanup=bit2, native allocations=bit4)"
}
