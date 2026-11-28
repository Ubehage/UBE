# Generated-program correctness and measurements; this does not benchmark compiler throughput.
param(
 [Parameter(Mandatory=$true)][string]$CompilerExe,
 [string]$Clang='C:\Program Files\LLVM\bin\clang.exe',
 [ValidateSet('Correctness','Measure')][string]$Mode='Correctness',
 [string]$PreparedDirectory='',
 [ValidateRange(1,9)][int]$Batch=3,
 [ValidateRange(3,20)][int]$Repetitions=5,
 [ValidateRange(1,3)][int]$Warmups=1
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf=[Text.UTF8Encoding]::new($false,$true)
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$CompilerExe=[IO.Path]::GetFullPath($CompilerExe)
$Clang=[IO.Path]::GetFullPath($Clang)
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube generated performance '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$records=New-Object Collections.Generic.List[object]
$sources=New-Object Collections.Generic.List[object]
$builds=New-Object Collections.Generic.List[object]
$assets=New-Object Collections.Generic.List[object]
$sequence=0
$success=$false
Write-Output "Evidence: $evidence"

function Require([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Hash([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Quote-Argument([string]$Value){
 if($Value.Length -gt 0 -and $Value -notmatch '[\s"]'){return $Value}
 $escaped=[regex]::Replace($Value,'(\\*)"','$1$1\"')
 $escaped=[regex]::Replace($escaped,'(\\+)$','$1$1')
 return '"'+$escaped+'"'
}
function Run-Process([string]$File,[string[]]$Arguments,[string]$Label,[int]$Timeout=60000){
 $script:sequence++
 $name=('{0:D4}-{1}' -f $script:sequence,$Label)
 $stdout=Join-Path $evidence ($name+'.stdout');$stderr=Join-Path $evidence ($name+'.stderr')
 $options=@{FilePath=$File;WorkingDirectory=$evidence;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=$stdout;RedirectStandardError=$stderr}
 if($Arguments.Count){$options.ArgumentList=(@($Arguments|ForEach-Object{Quote-Argument $_}) -join ' ')}
 $timer=[Diagnostics.Stopwatch]::StartNew()
 $p=Start-Process @options
 try{
  $null=$p.Handle
  if(-not $p.WaitForExit($Timeout)){$p.Kill();$null=$p.WaitForExit(5000);throw "Process deadline: $Label"}
  $timer.Stop();$p.Refresh()
  Require ($null -ne $p.ExitCode) "Missing exit status: $Label"
  $cpu=$null;$peak=$null;$memoryReason='OS counter unavailable after process exit'
  try{$cpu=$p.TotalProcessorTime.TotalMilliseconds}catch{}
  try{if($p.PeakWorkingSet64 -gt 0){$peak=$p.PeakWorkingSet64;$memoryReason='OS peak working-set counter'}}catch{}
  Require ((Get-Item -LiteralPath $stdout).Length -le 1048576 -and (Get-Item -LiteralPath $stderr).Length -le 1048576) "Oversized process log: $Label"
  return [pscustomobject]@{Code=$p.ExitCode;Out=[IO.File]::ReadAllText($stdout,$utf);Error=[IO.File]::ReadAllText($stderr,$utf);ProcessMs=$timer.Elapsed.TotalMilliseconds;CpuMs=$cpu;PeakWorkingSetBytes=$peak;MemoryObservation=$memoryReason;Stdout=$stdout;Stderr=$stderr}
 }finally{$timer.Stop();$p.Dispose()}
}

# Closed-form checksum oracles are independent of the fixture's loops and calls.
function Expected([string]$Case,[long]$Count,[long]$Seed){
 if($Count -eq 0){return [long]0}
 $tri=[decimal]$Count*($Count+1)/2
 switch($Case){
  'scalar' {$groups=[long][Math]::Floor($Count/7);$tail=$Count%7;return [long]($Seed*$tri+21*$groups+$tail*($tail+1)/2)}
  'array-record' {return [long](8128*$Seed+128*$Seed*$Count+379)}
  'managed' {return [long]($tri+$Seed*$Count)}
  'collection' {return [long]($tri+2*$Seed*$Count)}
  'workers' {return [long](2*$tri+2*$Seed*$Count)}
 }
 throw "Unknown case: $Case"
}
function Check-Result($Run,[string]$Case,[long]$Count,[long]$Seed){
 Require ($Run.Code -eq 0 -and $Run.Error.Length -eq 0) "Runtime failed: $Case exit=$($Run.Code), $($Run.Error)"
 Require ($Run.Out -match '^(-?[0-9]+),([0-9]+),([0-9]+),([0-9]+)\n$') "Malformed numeric result: $Case $($Run.Out)"
 $checksum=[long]$Matches[1];$inner=[long]$Matches[2];$actualCount=[long]$Matches[3];$actualSeed=[long]$Matches[4]
 Require ($actualCount -eq $Count -and $actualSeed -eq $Seed) "Runtime input/count mismatch: $Case"
 $expected=Expected $Case $Count $Seed
 Require ($checksum -eq $expected) "Checksum mismatch: $Case expected=$expected actual=$checksum count=$Count seed=$Seed"
 return [pscustomobject]@{Checksum=$checksum;WorkMs=$inner}
}
function Sample($Build,[string]$Phase,[int]$Trial,[int]$InputBatch,[int]$Seed){
 $run=Run-Process $Build.Executable @([string]$InputBatch,[string]$Seed) ($Phase+'-'+$Build.Case+'-o'+$Build.Optimization+'-'+$Trial)
 $count=[long]$InputBatch*$Build.IterationsPerBatch
 $checked=Check-Result $run $Build.Case $count $Seed
 $records.Add([pscustomobject]@{Case=$Build.Case;Optimization=$Build.Optimization;Phase=$Phase;Trial=$Trial;Batch=$InputBatch;Seed=$Seed;Iterations=$count;DeclaredWorkUnits=($count*$Build.UnitsPerIteration);Checksum=$checked.Checksum;WorkMs=$checked.WorkMs;ResolutionLimited=($checked.WorkMs -lt 10);ProcessMs=$run.ProcessMs;CpuMs=$run.CpuMs;PeakWorkingSetBytes=$run.PeakWorkingSetBytes;MemoryObservation=$run.MemoryObservation;ExecutableBytes=$Build.Bytes;ExecutableSHA256=$Build.SHA256;Stdout=$run.Stdout;Stderr=$run.Stderr})
}
function Copy-Source([string]$Original,[string]$Folder,[string]$Leaf){
 $path=Join-Path $Folder $Leaf
 Copy-Item -LiteralPath $Original -Destination $path
 $hash=Hash $Original
 Require ((Hash $path) -ceq $hash) "Copied source changed: $Original"
 $sources.Add([pscustomobject]@{Original=$Original;Snapshot=$path;SHA256=$hash})
}

$caseSpecs=@(
 [pscustomobject]@{Name='scalar';Iterations=2000000;Units=1;Class=$false;Threads=$false},
 [pscustomobject]@{Name='array-record';Iterations=100000;Units=128;Class=$false;Threads=$false},
 [pscustomobject]@{Name='managed';Iterations=2000;Units=1;Class=$true;Threads=$false},
 [pscustomobject]@{Name='collection';Iterations=20000;Units=2;Class=$true;Threads=$false},
 [pscustomobject]@{Name='workers';Iterations=20000;Units=2;Class=$true;Threads=$true}
)
$hostInfo=[ordered]@{OS=[Environment]::OSVersion.VersionString;Is64BitOS=[Environment]::Is64BitOperatingSystem;LogicalProcessors=[Environment]::ProcessorCount;Processor=[Environment]::GetEnvironmentVariable('PROCESSOR_IDENTIFIER');PowerShell=$PSVersionTable.PSVersion.ToString();StopwatchFrequency=[Diagnostics.Stopwatch]::Frequency;WorkClock='System.TryMonotonicMilliseconds; millisecond resolution';IdleEnvironmentConfirmedByHarness=$false}
$compilerHash='';$clangHash='';$prepared='';$versions=@{}
try{
 Require ([IO.File]::Exists($CompilerExe)) 'Compiler executable missing'
 Require ([IO.File]::Exists($Clang)) 'Clang executable missing'
 $compilerHash=Hash $CompilerExe;$clangHash=Hash $Clang
 $clangFolder=Split-Path -Parent $Clang
 foreach($tool in @($Clang,(Join-Path $clangFolder 'llvm-dlltool.exe'),(Join-Path $clangFolder 'lld-link.exe'))){
  Require ([IO.File]::Exists($tool)) "Tool missing: $tool"
  $version=Run-Process $tool @('--version') ('version-'+[IO.Path]::GetFileNameWithoutExtension($tool)) 10000
  $versions[[IO.Path]::GetFileName($tool)]=[pscustomobject]@{Path=$tool;SHA256=(Hash $tool);FileVersion=([Diagnostics.FileVersionInfo]::GetVersionInfo($tool).FileVersion);VersionQueryExitCode=$version.Code;VersionQuery=($version.Out+$version.Error).Trim()}
 }
 $compilerFolder=Split-Path -Parent $CompilerExe
 foreach($leaf in @('llvm/templates.bin','llvm/windows-runtime.ll','llvm/kernel32.def')){
  $path=Join-Path $compilerFolder $leaf;Require ([IO.File]::Exists($path)) "Compiler asset missing: $path"
  $assets.Add([pscustomobject]@{Path=$path;SHA256=(Hash $path)})
 }
 $support=Join-Path $compilerFolder 'support'
 Require (Test-Path -LiteralPath $support) 'Installed managed support missing'
 foreach($file in @(Get-ChildItem -LiteralPath $support -File -Recurse | Sort-Object FullName)){$assets.Add([pscustomobject]@{Path=$file.FullName;SHA256=(Hash $file.FullName)})}
 if($PreparedDirectory){
  $prepared=[IO.Path]::GetFullPath($PreparedDirectory)
  $ready=[IO.File]::ReadAllText((Join-Path $prepared 'prepared.json'),$utf)|ConvertFrom-Json
  Require ($ready.Schema -eq 1 -and $ready.CompilerSHA256 -ceq $compilerHash -and $ready.ClangSHA256 -ceq $clangHash) 'Prepared compiler/tool identity mismatch'
  Require ($ready.HarnessSHA256 -ceq (Hash $PSCommandPath)) 'Prepared harness differs from current harness'
  foreach($source in $ready.Sources){
   Require ((Hash $source.Original) -ceq $source.SHA256 -and (Hash $source.Snapshot) -ceq $source.SHA256) "Prepared source changed: $($source.Original)"
   $sources.Add($source)
  }
  foreach($asset in $ready.Assets){Require ((Hash $asset.Path) -ceq $asset.SHA256) "Prepared runtime asset changed: $($asset.Path)"}
  foreach($build in $ready.Builds){Require ((Hash $build.Executable) -ceq $build.SHA256 -and (Hash $build.Manifest) -ceq $build.ManifestSHA256) 'Prepared artifact changed';$builds.Add($build)}
  Require ($builds.Count -eq 10) 'Prepared corpus must contain five cases at both optimization levels'
 }else{
  $prepared=$evidence
  foreach($case in $caseSpecs){foreach($level in @('0','2')){
   $folder=Join-Path $evidence ($case.Name+'-o'+$level);$null=New-Item -ItemType Directory -Path $folder
   Copy-Source (Join-Path $PSScriptRoot 'Driver.bas') $folder 'Driver.bas'
   Copy-Source (Join-Path $PSScriptRoot ($case.Name+'.bas')) $folder 'Workload.bas'
   $leaves=@('Driver.bas','Workload.bas')
   if($case.Class){Copy-Source (Join-Path $PSScriptRoot 'Counter.cls') $folder 'Counter.cls';$leaves+='Counter.cls'}
   $library=@('portable/BufferPrimitives.bas','portable/FilePrimitives.bas','portable/SystemPrimitives.bas','portable/StandardStreams.bas','portable/ByteText.bas','portable/Utf8.bas','win-lib/WindowsArguments.bas')
   if($case.Threads){$library+='portable/ThreadPrimitives.bas'}
   foreach($relative in $library){$leaf=[IO.Path]::GetFileName($relative);Copy-Source (Join-Path $repo ('std-lib/src/'+$relative)) $folder $leaf;$leaves+=$leaf}
   $manifest=Join-Path $folder 'Benchmark.UBE';$exe=Join-Path $folder 'Benchmark.exe'
   $lines=@('UBE-Project 1','Name = "Benchmark"','Kind = "Exe"','Startup = "Main"',('Optimization = "'+$level+'"'),'DebugInformation = "None"')
   foreach($leaf in $leaves){$lines+='Source = "'+$leaf+'"'}
   [IO.File]::WriteAllLines($manifest,$lines,$utf)
   $run=Run-Process $CompilerExe @('--build',$manifest,$exe,'--clang',$Clang) ('build-'+$case.Name+'-o'+$level) 120000
   Require ($run.Code -eq 0 -and $run.Out -match '(?m)^BUILD OK\r?$' -and $run.Error.Length -eq 0) "Build failed: $($case.Name) O$level $($run.Out) $($run.Error)"
   $bytes=[IO.File]::ReadAllBytes($exe)
   Require ($bytes.Length -ge 90 -and $bytes[0] -eq 77 -and $bytes[1] -eq 90) 'Missing bounded DOS header'
   $offset=[BitConverter]::ToInt32($bytes,60)
   Require ($offset -ge 64 -and $offset -le $bytes.Length-26) 'Invalid PE offset'
   Require ([BitConverter]::ToUInt32($bytes,$offset) -eq 17744 -and [BitConverter]::ToUInt16($bytes,$offset+4) -eq 34404 -and [BitConverter]::ToUInt16($bytes,$offset+24) -eq 523) 'Expected native AMD64 PE32+ program'
   $builds.Add([pscustomobject]@{Case=$case.Name;Optimization=$level;IterationsPerBatch=$case.Iterations;UnitsPerIteration=$case.Units;Executable=$exe;SHA256=(Hash $exe);Bytes=$bytes.Length;Manifest=$manifest;ManifestSHA256=(Hash $manifest);BuildMs=$run.ProcessMs})
   Write-Output "BUILT $($case.Name) O$level"
  }}
 }
 foreach($build in $builds){
  Sample $build 'correctness-zero' 0 0 7
  Sample $build 'correctness' 1 1 3
  Sample $build 'correctness' 2 1 7
  $invalid=Run-Process $build.Executable @('1','0') ('reject-input-'+$build.Case+'-o'+$build.Optimization)
  Require ($invalid.Code -eq 2 -and $invalid.Out.Length -eq 0 -and $invalid.Error.Length -eq 0) 'Invalid-input control did not reject exactly'
  Write-Output "PASS $($build.Case) O$($build.Optimization): zero baseline, two independent checksums and input rejection"
 }
 foreach($source in $sources){Require ((Hash $source.Original) -ceq $source.SHA256 -and (Hash $source.Snapshot) -ceq $source.SHA256) "Source changed during run: $($source.Original)"}
 foreach($asset in $assets){Require ((Hash $asset.Path) -ceq $asset.SHA256) "Runtime asset changed during run: $($asset.Path)"}
 Require ((Hash $CompilerExe) -ceq $compilerHash -and (Hash $Clang) -ceq $clangHash) 'Compiler/tool changed during run'
 if(-not $PreparedDirectory){
  [IO.File]::WriteAllText((Join-Path $evidence 'prepared.json'),(@{Schema=1;CompilerSHA256=$compilerHash;ClangSHA256=$clangHash;HarnessSHA256=(Hash $PSCommandPath);Sources=$sources.ToArray();Assets=$assets.ToArray();Builds=$builds.ToArray()}|ConvertTo-Json -Depth 6),$utf)
 }
 if($Mode -eq 'Measure'){
  Write-Output 'MEASURE: caller must arrange an idle machine; this harness cannot establish machine isolation.'
  foreach($warmup in 1..$Warmups){foreach($build in $builds){Sample $build 'warmup' $warmup $Batch 7}}
  foreach($trial in 1..$Repetitions){
   $levels=@('0','2');$cases=@($caseSpecs.Name);$seed=3
   if(($trial%2) -eq 0){$levels=@('2','0');[array]::Reverse($cases);$seed=7}
   foreach($case in $cases){foreach($level in $levels){
    $build=@($builds|Where-Object{$_.Case -ceq $case -and $_.Optimization -ceq $level})
    Require ($build.Count -eq 1) 'Ambiguous prepared case'
    Sample $build[0] 'startup-baseline' $trial 0 $seed
    Sample $build[0] 'measurement' $trial $Batch $seed
   }}
   Write-Output "MEASURED repetition $trial/$Repetitions"
  }
 }
 $success=$true
}finally{
 $records.ToArray() | Export-Csv -LiteralPath (Join-Path $evidence 'results.csv') -NoTypeInformation -Encoding UTF8
 [IO.File]::WriteAllText((Join-Path $evidence 'report.json'),([ordered]@{Schema=1;Success=$success;Mode=$Mode;Compiler=$CompilerExe;CompilerSHA256=$compilerHash;ClangSHA256=$clangHash;Tools=$versions;PreparedDirectory=$prepared;Host=$hostInfo;Batch=$Batch;Repetitions=$Repetitions;Warmups=$Warmups;Builds=$builds.ToArray();Assets=$assets.ToArray();Sources=$sources.ToArray();Results=$records.ToArray()}|ConvertTo-Json -Depth 8),$utf)
}
Write-Output "PASS $Mode; evidence: $evidence"
