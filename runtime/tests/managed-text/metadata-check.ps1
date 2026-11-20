# Qualifies production native metadata mechanics independently of pending collection.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube managed metadata '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $artifacts
Write-Output "Evidence: $artifacts"
$utf8=New-Object Text.UTF8Encoding($false,$true)
& (Join-Path $root 'bootstrap/tools/runtime-text.ps1')
$templates=Get-Content (Join-Path $root 'compiler/llvm/templates.json') -Raw | ConvertFrom-Json
$prefix=($templates|Where-Object{$_.name -eq 'ContextPrefix'}).text
$prefix=$prefix.Replace('{0}','1').Replace('{1}','1').Replace('{2}','6904').Replace('{3}','863')
$prefix=$prefix.Substring(0,$prefix.IndexOf('define i1 @ube.context.dispose'))
$probe=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'metadata-probe.ll'))
$runtime=[IO.File]::ReadAllText((Join-Path $root 'compiler/llvm/windows-runtime.ll'))
$script:sequence=0
function Run([string]$File,[string[]]$Arguments,[int]$Expected=0) {
 $script:sequence++;$name=Join-Path $artifacts ('process-'+$script:sequence)
 $options=@{FilePath=$File;WorkingDirectory=$artifacts;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($name+'.stdout');RedirectStandardError=($name+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' '}
 $p=Start-Process @options
 try{$handle=$p.Handle;if(-not $p.WaitForExit(60000)){$p.Kill();throw "Deadline: $name"};$p.Refresh();if($p.ExitCode -ne $Expected){throw "Expected $Expected, got $($p.ExitCode): $name"}}finally{$p.Dispose()}
}
$lib=Join-Path $artifacts 'kernel32.lib'
Run 'C:\Program Files\LLVM\bin\llvm-dlltool.exe' @('-m','i386:x86-64','-d',(Join-Path $root 'compiler/llvm/kernel32.def'),'-l',$lib)
foreach($level in @('O0','O2')) {
 foreach($negative in @($false,$true)) {
  $text=$runtime
  if($negative){$text=$text.Replace('store i64 -1, ptr %fresh, align 8','store i64 0, ptr %fresh, align 8')}
  $stem=Join-Path $artifacts ($level+'-negative'+$negative)
  [IO.File]::WriteAllText(($stem+'.ll'),($prefix+$text+$probe),$utf8)
  Run 'C:\Program Files\LLVM\bin\clang.exe' @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-'+$level),($stem+'.ll'),$lib,'-o',($stem+'.exe'),'-Wl,/entry:main,/subsystem:console,/stack:8388608')
  $expected=0;if($negative){$expected=1}
  Run ($stem+'.exe') @() $expected
  Write-Output "PASS $level metadata snapshot, mark, frame assertions negative=$negative"
 }
}
$stem=Join-Path $artifacts 'O0-missing-metadata-list-guard'
$unguarded=$runtime.Replace('%shape = and i1 %counts.valid, %lists.valid','%shape = and i1 %counts.valid, true')
if($unguarded -eq $runtime){throw 'Metadata guard negative control did not mutate runtime'}
[IO.File]::WriteAllText(($stem+'.ll'),($prefix+$unguarded+$probe),$utf8)
Run 'C:\Program Files\LLVM\bin\clang.exe' @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib','-O0',($stem+'.ll'),$lib,'-o',($stem+'.exe'),'-Wl,/entry:main,/subsystem:console,/stack:8388608')
Run ($stem+'.exe') @() -1073741819
Write-Output 'PASS null metadata-list regression: controlled rejection with guard; access violation without guard'
