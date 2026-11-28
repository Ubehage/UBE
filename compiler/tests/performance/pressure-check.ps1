param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf=[Text.UTF8Encoding]::new($false,$true)
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube allocation pressure '+[guid]::NewGuid())
$null=New-Item -Type Directory $evidence
$records=New-Object Collections.Generic.List[object]
$passed=$false
Write-Output "Evidence: $evidence"
function Run($file,$arguments,$label,$timeout){
 $out=Join-Path $evidence ($label+'.stdout');$err=Join-Path $evidence ($label+'.stderr')
 $p=Start-Process -FilePath $file -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err
 try{$null=$p.Handle;if(-not $p.WaitForExit($timeout)){$p.Kill();$null=$p.WaitForExit(5000);throw "Deadline: $label"};$p.Refresh()
 return [pscustomobject]@{Code=$p.ExitCode;Out=[IO.File]::ReadAllText($out,$utf);Error=[IO.File]::ReadAllText($err,$utf)}
 }finally{$p.Dispose()}
}
try{
 foreach($level in @(0,2)){
  $dir=Join-Path $evidence "o$level";$null=New-Item -Type Directory $dir
  foreach($name in @('Driver.bas','Counter.cls')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $dir}
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'pressure.bas') -Destination (Join-Path $dir 'Workload.bas')
  $leaves=@('Driver.bas','Counter.cls','Workload.bas')
  foreach($relative in @('portable/BufferPrimitives.bas','portable/FilePrimitives.bas','portable/SystemPrimitives.bas','portable/StandardStreams.bas','portable/ThreadPrimitives.bas','portable/ByteText.bas','portable/Utf8.bas','win-lib/WindowsArguments.bas')){
   $leaf=[IO.Path]::GetFileName($relative);Copy-Item -LiteralPath (Join-Path $root ('std-lib/src/'+$relative)) -Destination $dir;$leaves+=$leaf
  }
  $manifest=Join-Path $dir 'Pressure.UBE';$exe=Join-Path $dir 'Pressure.exe'
  $lines=@('UBE-Project 1','Name = "Pressure"','Kind = "Exe"','Startup = "Main"',('Optimization = "'+$level+'"'),'DebugInformation = "None"')
  foreach($leaf in $leaves){$lines+='Source = "'+$leaf+'"'}
  [IO.File]::WriteAllLines($manifest,$lines,$utf)
  $ir=Join-Path $dir 'Pressure.ll'
  $build=Run $CompilerExe @('--emit-llvm',('"'+$manifest+'"'),('"'+$ir+'"')) "emit-o$level" 120000
  if($build.Code -ne 0 -or $build.Error.Length){throw "Emission failed: $($build.Out) $($build.Error)"}
  $program=[IO.File]::ReadAllText($ir,$utf)
  $hook='call { i1, i64 } @ube.thread.current(ptr %ctx)'
  if(-not $program.Contains($hook)){throw 'Missing observation hook'}
  $program=$program.Replace($hook,'call { i1, i64 } @pressure.observe(ptr %ctx)')
  [IO.File]::WriteAllText($ir,$program+"`r`n"+[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'pressure-observer.ll'),$utf),$utf)
  $lib=Join-Path $dir 'kernel32.lib'
  $imports=Run (Join-Path (Split-Path -Parent $Clang) 'llvm-dlltool.exe') @('-m','i386:x86-64','-d',('"'+(Join-Path $root 'compiler/llvm/kernel32.def')+'"'),'-l',('"'+$lib+'"')) "imports-o$level" 30000
  if($imports.Code -ne 0 -or $imports.Error.Length){throw 'Import library failed'}
  $build=Run $Clang @('--target=x86_64-pc-windows-msvc','-Wno-override-module','-fuse-ld=lld','-nostdlib',('-O'+$level),('"'+$ir+'"'),('"'+$lib+'"'),'-o',('"'+$exe+'"'),'-Wl,/entry:main,/subsystem:console,/stack:8388608') "build-o$level" 120000
  if($build.Code -ne 0 -or $build.Error.Length){throw "Native build failed: $($build.Error)"}
  foreach($batch in @(4,8)){foreach($seed in @(1,2,3)){
   $run=Run $exe @("$batch","$seed") "run-o$level-$batch-$seed" 30000
   if($run.Code -ne 0 -or $run.Error.Length -or $run.Out -notmatch '^([0-9]+),([0-9]+),([0-9]+),([0-9]+)\n$'){throw "Runtime failed: $($run.Code) $($run.Out) $($run.Error)"}
   $packed=[long]$Matches[1];$count=[long]$Matches[3];$actualSeed=[long]$Matches[4]
   $before=[long][Math]::Floor($packed/1000000000);$rest=$packed%1000000000
   $after=[long][Math]::Floor($rest/1000000);$rootsBefore=[long][Math]::Floor(($rest%1000000)/1000);$rootsAfter=$rest%1000
   $records.Add([pscustomobject]@{Optimization=$level;Iterations=$count;Seed=$seed;ConcurrentWorkers=($seed -eq 3);CollectEachIteration=($seed -eq 2);AllocationsBefore=$before;AllocationsAfter=$after;RootsBefore=$rootsBefore;RootsAfter=$rootsAfter;ExecutableSHA256=(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash})
   if($count -ne 128*$batch -or $actualSeed -ne $seed){throw 'Runtime input mismatch'}
   if($before -gt 512){throw "Unbounded retained garbage: $before allocations after $count iterations"}
   if($after -ne 4 -or $rootsBefore -ne $rootsAfter){throw 'Live allocation/root oracle failed'}
   if($seed -eq 2 -and $before -ne 4){throw 'Explicit collection control failed'}
  }}
 }
 if(@($records.RootsBefore|Select-Object -Unique).Count -ne 1){throw 'Root count grew with work'}
 $passed=$true
 Write-Output 'PASS 12 O0/O2 bounded-allocation, live-value, stable-root, preserved-Err, concurrent-worker and explicit-collection controls'
}finally{
 [IO.File]::WriteAllText((Join-Path $evidence 'report.json'),(@{Success=$passed;CompilerSHA256=(Get-FileHash -LiteralPath $CompilerExe -Algorithm SHA256).Hash;ClangSHA256=(Get-FileHash -LiteralPath $Clang -Algorithm SHA256).Hash;FixtureSHA256=(Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'pressure.bas') -Algorithm SHA256).Hash;ObserverSHA256=(Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'pressure-observer.ll') -Algorithm SHA256).Hash;Results=$records.ToArray()}|ConvertTo-Json -Depth 5),$utf)
}
