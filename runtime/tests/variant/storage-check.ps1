# Runs the actual ordinary UBE collector with current boxed storage primitives.
param([Parameter(Mandatory=$true)][string]$ProgramIR)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube variant storage check '+[guid]::NewGuid())
$null=New-Item -ItemType Directory $evidence
$utf8=[Text.UTF8Encoding]::new($false)
Write-Output "Evidence: $evidence"
$program=[IO.File]::ReadAllText($ProgramIR)
if($program -notmatch 'call i1 @ube.managed.install\(ptr %ctx, ptr @ube.proc.\d+\)'){throw 'Missing compiler-bound ordinary UBE collector'}
$runtime=[IO.File]::ReadAllText((Join-Path $repo 'compiler/llvm/windows-runtime.ll'))
$start='%ube.block = type'
$end='define internal void @ube.managed.temps.clear'
$first=$program.IndexOf($start);$last=$program.IndexOf($end,$first)
if($first -lt 0 -or $last -lt $first -or -not $runtime.StartsWith($start)){throw 'Missing exact runtime boundaries'}
$program=$program.Substring(0,$first)+$runtime+$program.Substring($last)
[IO.File]::WriteAllText((Join-Path $evidence 'runtime-program.ll'),$program,$utf8)
$program=$program.Replace('define ptr @ube.target.allocate(i64 %bytes)','define ptr @variant.target.allocate(i64 %bytes)')
$program=$program.Replace('define i1 @ube.target.release(ptr %block)','define i1 @variant.target.release(ptr %block)')
$probe=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'storage-probe.ll'))
$script:sequence=0
function Run([string]$File,[string[]]$Arguments,[int]$Expected=0) {
 $script:sequence++;$prefix=Join-Path $evidence ('process-'+$script:sequence)
 $quoted=($Arguments|ForEach-Object {'"'+$_+'"'}) -join ' '
 $p=Start-Process -FilePath $File -ArgumentList $quoted -WindowStyle Hidden -PassThru -RedirectStandardOutput ($prefix+'.stdout') -RedirectStandardError ($prefix+'.stderr')
 try{$handle=$p.Handle;if(-not $p.WaitForExit(60000)){$p.Kill();throw "Deadline $prefix"};$p.Refresh();if($p.ExitCode -ne $Expected){throw "Expected $Expected, got $($p.ExitCode): $prefix"}}finally{$p.Dispose()}
}
$lib=Join-Path $evidence 'kernel32.lib'
Run 'C:\Program Files\LLVM\bin\llvm-dlltool.exe' @('-m','i386:x86-64','-d',(Join-Path $repo 'compiler/llvm/kernel32.def'),'-l',$lib)
foreach($level in @('O0','O2')) {
 foreach($negative in @('none','scalar','reference')) {
  $assertions=$probe
  if($negative -eq 'scalar'){$assertions=$assertions.Replace('%expected.scalar = icmp eq i64 %scalar.value, -123','%expected.scalar = icmp eq i64 %scalar.value, -124')}
  if($negative -eq 'reference'){$assertions=$assertions.Replace('%reference.expected = icmp eq i64 %reference.value, %object.id','%reference.expected = icmp ne i64 %reference.value, %object.id')}
  $stem=Join-Path $evidence ($level+'-negative'+$negative)
  [IO.File]::WriteAllText(($stem+'.ll'),$program+$assertions,$utf8)
  Run 'C:\Program Files\LLVM\bin\clang.exe' @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-'+$level),($stem+'.ll'),$lib,'-o',($stem+'.exe'),'-Wl,/entry:variantmain,/subsystem:console,/stack:8388608')
  $expected=0;if($negative -eq 'scalar'){$expected=1};if($negative -eq 'reference'){$expected=15}
  Run ($stem+'.exe') @('variant-storage') $expected
  Write-Output "PASS $level boxed storage, exact edges, allocation rollback, cleanup and disposal negative=$negative"
 }
}
