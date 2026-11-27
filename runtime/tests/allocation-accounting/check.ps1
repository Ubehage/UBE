# Asserts OS-pressure recovery and representation overflow without allocating giant payloads.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube allocation accounting '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
Write-Output "Evidence: $evidence"
$script:sequence=0
function Run([string]$File,[string[]]$Arguments,[int]$Expected=0) {
 $script:sequence++;$prefix=Join-Path $evidence ('process-'+$script:sequence)
 $quoted=($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' '
 $p=Start-Process -FilePath $File -ArgumentList $quoted -WindowStyle Hidden -PassThru -RedirectStandardOutput ($prefix+'.stdout') -RedirectStandardError ($prefix+'.stderr')
 try{$handle=$p.Handle;if(-not $p.WaitForExit(60000)){$p.Kill();throw "Deadline $prefix"};$p.Refresh();if($p.ExitCode -ne $Expected){throw "Expected $Expected, got $($p.ExitCode): $prefix"}}finally{$p.Dispose()}
}
$templates=Get-Content (Join-Path $root 'compiler/llvm/templates.json') -Raw|ConvertFrom-Json
$prefix=($templates|Where-Object{$_.name -eq 'ContextPrefix'}).text
$prefix=$prefix.Replace('{0}','1').Replace('{1}','1').Replace('{2}','6904').Replace('{3}','863')
$prefix=$prefix.Substring(0,$prefix.IndexOf('define i1 @ube.context.dispose'))
$runtime=[IO.File]::ReadAllText((Join-Path $root 'compiler/llvm/windows-runtime.ll'))
$runtime=$runtime.Replace('define ptr @ube.target.allocate(i64 %bytes)', 'define ptr @test.target.allocate(i64 %bytes)')
$probe=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'probe.ll'))
$lib=Join-Path $evidence 'kernel32.lib'
Run 'C:\Program Files\LLVM\bin\llvm-dlltool.exe' @('-m','i386:x86-64','-d',(Join-Path $root 'compiler/llvm/kernel32.def'),'-l',$lib)
foreach($level in @('O0','O2')) {
 foreach($negative in @($false,$true)) {
  $assertions=$probe
  if($negative){$assertions=$assertions.Replace('%twice = icmp eq i64 %calls, 2','%twice = icmp eq i64 %calls, 3')}
  $stem=Join-Path $evidence ($level+'-negative'+$negative)
  [IO.File]::WriteAllText(($stem+'.ll'),$prefix+$runtime+$assertions)
  Run 'C:\Program Files\LLVM\bin\clang.exe' @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-'+$level),($stem+'.ll'),$lib,'-o',($stem+'.exe'),'-Wl,/entry:main,/subsystem:console')
  $expected=0;if($negative){$expected=1}
  Run ($stem+'.exe') @('probe') $expected
  Write-Output "PASS $level allocation admission, overflow guards, destination preservation and recovery negative=$negative"
 }
}
