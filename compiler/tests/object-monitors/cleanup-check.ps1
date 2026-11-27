param([Parameter(Mandatory=$true)][string]$ProgramIR,[switch]$RetirementFailure)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$utf=New-Object Text.UTF8Encoding($false,$true)
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube source monitor oracle '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
Write-Output "Evidence: $evidence"
$program=[IO.File]::ReadAllText($ProgramIR,$utf)
$pairs=@(
 @('define i1 @ube.object.create(','define i1 @oracle.object.create('),
 @('define {i1,i64} @ube.monitor.tryenter(','define {i1,i64} @oracle.monitor.tryenter('),
 @('define i1 @ube.monitor.retire(','define i1 @oracle.monitor.retire('),
 @('define i32 @main()','define i32 @oracle.source.main()')
)
if($RetirementFailure){$pairs=@(@('define i1 @ube.monitor.retire(','define i1 @retirement.actual('),@('define i32 @main()','define i32 @retirement.source.main()'))}
foreach($pair in $pairs){
 if([regex]::Matches($program,[regex]::Escape($pair[0])).Count -ne 1){throw "Ambiguous source monitor oracle boundary: $($pair[0])"}
 $program=$program.Replace($pair[0],$pair[1])
}
$oracleFile='cleanup-oracle.ll'
if($RetirementFailure){$oracleFile='retirement-failure.ll'}
$oracle=[IO.File]::ReadAllText((Join-Path $PSScriptRoot $oracleFile),$utf)
$script:sequence=0
function Run([string]$Exe,[string[]]$Arguments,[int]$Expected){
 $script:sequence++;$name='process-'+$script:sequence
 $stdout=Join-Path $evidence ($name+'.stdout');$stderr=Join-Path $evidence ($name+'.stderr')
 $options=@{FilePath=$Exe;WorkingDirectory=$evidence;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=$stdout;RedirectStandardError=$stderr}
 if($Arguments.Count){$options.ArgumentList=(@($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' ')}
 $p=Start-Process @options
 try{
  $null=$p.Handle
  if(-not $p.WaitForExit(30000)){$p.Kill();throw "Deadline: $name"}
  $p.Refresh();$errors=[IO.File]::ReadAllText($stderr)
  if($null -eq $p.ExitCode -or $p.ExitCode -ne $Expected -or $errors.Length){throw "Expected $Expected, got $($p.ExitCode): $name $errors"}
 }finally{$p.Dispose()}
}
$llvm='C:\Program Files\LLVM\bin'
$lib=Join-Path $evidence 'kernel32.lib'
Run (Join-Path $llvm 'llvm-dlltool.exe') @('-m','i386:x86-64','-d',(Join-Path $repo 'compiler/llvm/kernel32.def'),'-l',$lib) 0
foreach($level in @('0','2')){
 foreach($negative in @($false,$true)){
  $assertions=$oracle
  if($negative){
   $before='%outer.ok = icmp eq i64 %outer, 1'
   $after='%outer.ok = icmp eq i64 %outer, 2'
   if($RetirementFailure){$before='%terminal.once = icmp eq i64 %terminal, 1';$after='%terminal.once = icmp eq i64 %terminal, 2'}
   if([regex]::Matches($assertions,[regex]::Escape($before)).Count -ne 1){throw 'Missing cleanup observation control'}
   $assertions=$assertions.Replace($before,$after)
  }
  $name='cleanup-O'+$level+'-negative'+$negative
  $ir=Join-Path $evidence ($name+'.ll');$exe=Join-Path $evidence ($name+'.exe')
  [IO.File]::WriteAllText($ir,$program+"`n"+$assertions,$utf)
  Run (Join-Path $llvm 'clang.exe') @('--target=x86_64-pc-windows-msvc','-Wno-override-module','-fuse-ld=lld','-nostdlib',('-O'+$level),$ir,$lib,'-o',$exe,'-Wl,/entry:main,/subsystem:console,/stack:8388608') 0
  $expected=0;if($negative){$expected=99}
  Run $exe @() $expected
  Write-Output "PASS $name expected exit $expected"
 }
}
