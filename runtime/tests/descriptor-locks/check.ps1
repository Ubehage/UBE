# Tests production descriptor stripes with actual threads, collisions and independent programs.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube descriptor locks '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $artifacts
Write-Output "Evidence: $artifacts"
$utf8=New-Object Text.UTF8Encoding($false)
$templates=[IO.File]::ReadAllText((Join-Path $root 'compiler/llvm/templates.json'))|ConvertFrom-Json
$prefix=($templates|Where-Object{$_.name -eq 'ContextPrefix'}).text
$prefix=$prefix.Replace('{0}','1').Replace('{1}','1').Replace('{2}','6848').Replace('{3}','856')
$prefix=$prefix.Substring(0,$prefix.IndexOf('define i1 @ube.context.dispose'))
$runtime=[IO.File]::ReadAllText((Join-Path $root 'compiler/llvm/windows-runtime.ll'))
$probe=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'probe.ll'))
$script:sequence=0
# Runs bounded native children and requires their independently specified exit status.
function Run([string]$File,[string[]]$Arguments,[int]$Expected=0) {
 $script:sequence++;$name=Join-Path $artifacts ('process-'+$script:sequence)
 $options=@{FilePath=$File;WorkingDirectory=$artifacts;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($name+'.stdout');RedirectStandardError=($name+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' '}
 $p=Start-Process @options
 try{$handle=$p.Handle;if(-not $p.WaitForExit(60000)){$p.Kill();throw "Deadline: $name"};$p.Refresh();if($p.ExitCode -ne $Expected){throw "Expected $Expected, got $($p.ExitCode): $name"}}finally{$p.Dispose()}
}
$llvm='C:\Program Files\LLVM\bin';$lib=Join-Path $artifacts 'kernel32.lib'
Run (Join-Path $llvm 'llvm-dlltool.exe') @('-m','i386:x86-64','-d',(Join-Path $root 'compiler/llvm/kernel32.def'),'-l',$lib)
foreach($level in @('O0','O2')) {
 foreach($negative in @($false,$true)) {
  $text=$runtime
  if($negative) {
   $pattern='(?ms)^define internal \{ i64, i64, ptr, ptr \} @ube\.array\.snapshot\([^\r\n]*\{\r?\n.*?^}\r?\n'
   $found=[regex]::Matches($text,$pattern)
   if($found.Count -ne 1){throw 'Missing snapshot negative-control anchor'}
   $old=$found[0].Value
   $changed=$old.Replace('@ube.array.lock(ptr %program, ptr %array)','@ube.program.storage.lock(ptr %program)').Replace('@ube.array.unlock(ptr %program, ptr %array)','@ube.program.storage.unlock(ptr %program)')
   $text=$text.Replace($old,$changed)
  }
  $stem=Join-Path $artifacts ($level+'-negative'+$negative)
  [IO.File]::WriteAllText(($stem+'.ll'),($prefix+$text+$probe),$utf8)
  Run (Join-Path $llvm 'clang.exe') @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-'+$level),($stem+'.ll'),$lib,'-o',($stem+'.exe'),'-Wl,/entry:main,/subsystem:console,/stack:8388608')
  $expected=0;if($negative){$expected=4}
  Run ($stem+'.exe') @() $expected
  Write-Output "PASS $level negative=$negative exit$expected"
 }
}
