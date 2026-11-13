# Exercises the production collector and a deterministic retirement during a scan.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$utf8=New-Object Text.UTF8Encoding($false)
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube pending retirement '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $artifacts
Write-Output "Evidence: $artifacts"
$script:sequence=0
# Bounds native subprocesses and retains their exit status and diagnostics.
function Run([string]$File,[string[]]$Arguments) {
 $script:sequence++;$prefix=Join-Path $artifacts ('process-'+$script:sequence)
 $options=@{FilePath=$File;WorkingDirectory=$artifacts;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' '}
 $p=Start-Process @options
 try{$handle=$p.Handle;if(-not $p.WaitForExit(60000)){$p.Kill();throw "Deadline: $prefix"};$p.Refresh();if($null -eq $p.ExitCode){throw "Missing exit status: $handle"};return [pscustomobject]@{Code=$p.ExitCode;Evidence=$prefix;Error=[IO.File]::ReadAllText($prefix+'.stderr')}}finally{$p.Dispose()}
}
$templates=[IO.File]::ReadAllText((Join-Path $root 'compiler/llvm/templates.json'))|ConvertFrom-Json
$prefix=($templates|Where-Object{$_.name -eq 'ContextPrefix'}).text
$prefix=$prefix.Replace('{0}','1').Replace('{1}','1').Replace('{2}','6848').Replace('{3}','856')
$prefix=$prefix.Substring(0,$prefix.IndexOf('define i1 @ube.context.dispose'))
$runtime=[IO.File]::ReadAllText((Join-Path $root 'compiler/llvm/windows-runtime.ll'))
$runtime=$runtime.Replace('define i1 @ube.target.release(', 'define i1 @ube.target.release.real(')
$marker="define internal i1 @ube.memory.collect.locked(ptr %ctx) {`r`nentry:"
if(-not $runtime.Contains($marker)){throw 'Collector instrumentation anchor missing'}
$runtime=$runtime.Replace($marker,$marker+"`r`n  %test.scan = atomicrmw add ptr @test.scans, i64 1 monotonic")
$probe=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'probe.ll'))
$llvm='C:\Program Files\LLVM\bin'
$def=Join-Path $root 'compiler/llvm/kernel32.def';$lib=Join-Path $artifacts 'kernel32.lib'
$result=Run (Join-Path $llvm 'llvm-dlltool.exe') @('-m','i386:x86-64','-d',$def,'-l',$lib)
if($result.Code -ne 0){throw "Imports failed: $($result.Evidence)"}
foreach($level in @('0','2')) {
 foreach($negative in @($false,$true)) {
  $text=$runtime
  if($negative) {
   $start=$text.IndexOf('define internal i1 @ube.memory.collect.locked(')
   $end=$text.IndexOf('define internal ptr @ube.memory.new.locked(', $start)
   $part=$text.Substring($start,$end-$start)
   $clear='  %acknowledged = atomicrmw xchg ptr %pending, i64 0 acq_rel'
   if(-not $part.Contains($clear)){throw 'Negative control anchor missing'}
   $part=$part.Replace($clear+"`r`n",'').Replace('  ret i1 %worked',$clear+"`r`n  ret i1 %worked")
   $text=$text.Substring(0,$start)+$part+$text.Substring($end)
  }
  $stem=Join-Path $artifacts ('pending-O'+$level+'-negative'+$negative)
  [IO.File]::WriteAllText(($stem+'.ll'),($prefix+$text+$probe),$utf8)
  $built=Run (Join-Path $llvm 'clang.exe') @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-O'+$level),($stem+'.ll'),$lib,'-o',($stem+'.exe'),'-Wl,/entry:main,/subsystem:console,/stack:8388608')
  if($built.Code -ne 0){throw "Build failed: $($built.Evidence) $($built.Error)"}
  $ran=Run ($stem+'.exe') @()
  $expected=0;if($negative){$expected=4}
  if($ran.Code -ne $expected){throw "Expected $expected, observed $($ran.Code): $($ran.Evidence)"}
  Write-Output "PASS O$level negative=$negative exit=$expected"
 }
}
Write-Output 'PASS: exact scan counts, last reference, missed retirement interleaving, failed release retry, forced quota scan, context reuse; clear-at-end negative control rejected.'
