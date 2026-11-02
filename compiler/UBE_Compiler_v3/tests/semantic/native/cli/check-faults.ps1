param([Parameter(Mandatory=$true)][string]$RawPath,[switch]$BuildOnly,[int]$MaximumSites=0,[string]$SelectionPath='')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath($PSScriptRoot)
while(-not (Test-Path -LiteralPath (Join-Path $root 'bootstrap/tools/verification.ps1'))){$parent=Split-Path $root -Parent;if(-not $parent -or $parent -ceq $root){throw 'Repository root missing'};$root=$parent}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
. (Join-Path $root 'compiler/UBE_Compiler_v3/tests/semantic/native/observer.ps1')
if(-not $SelectionPath){$SelectionPath=Join-Path $root 'bootstrap/out/v2/current.json'}
$selection=Get-VerifiedBootstrapSelection $SelectionPath
$run=Join-Path $root ('bootstrap/out/semantic-cli-faults/'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $run -Force
$utf8=New-Object Text.UTF8Encoding($false,$true)
$inputs=@($RawPath,$PSCommandPath,(Join-Path $PSScriptRoot 'fault-probe.c'),(Join-Path $root 'compiler/UBE_Compiler_v3/tests/semantic/native/observer.ps1'))|ForEach-Object {Get-ArtifactIdentity $_}
$commands=New-Object 'System.Collections.Generic.List[object]'
$checks=New-Object 'System.Collections.Generic.List[object]'
$success=$false;$failure=$null
function Run-Recorded([string]$File,[string[]]$Arguments,[int]$Timeout=90){$r=Invoke-BoundedProcess $File $Arguments $run $Timeout;$commands.Add($r);return $r}
function Run-Cli([string[]]$Arguments,[int]$Allocation=0,[int]$Roots=-1,[int]$FileMode=0){
 $previous=@($env:UBE_SEMANTIC_CLI_ALLOC,$env:UBE_SEMANTIC_CLI_ROOTS,$env:UBE_SEMANTIC_CLI_FILE)
 try{
  $env:UBE_SEMANTIC_CLI_ALLOC=[string]$Allocation
  $env:UBE_SEMANTIC_CLI_FILE=[string]$FileMode
  if($Roots -ge 0){$env:UBE_SEMANTIC_CLI_ROOTS=[string]$Roots}else{Remove-Item Env:UBE_SEMANTIC_CLI_ROOTS -ErrorAction SilentlyContinue}
  return Run-Recorded $exe $Arguments 60
 }finally{
  $env:UBE_SEMANTIC_CLI_ALLOC=$previous[0];$env:UBE_SEMANTIC_CLI_ROOTS=$previous[1];$env:UBE_SEMANTIC_CLI_FILE=$previous[2]
 }
}
function Is-CliResourceFailure($Actual){
 $outputs=@(
  "error UBE1010: cannot read command argument`n",
  "error UBE1007: insufficient source storage`n",
  "error UBE1100: insufficient scanner storage`n",
  "error UBE1210: insufficient syntax storage`n",
  "error UBE1210: insufficient syntax storage (next lines: line, column, byte)`n1`n1`n0`n",
  "error UBE1310: insufficient project storage`n",
  "error UBE1428: insufficient semantic storage`n"
 )
 if($Actual.stdout -cnotin $outputs){return $false}
 $expectedExit=1;if($Actual.stdout -ceq "error UBE1010: cannot read command argument`n"){$expectedExit=2}
 return -not $Actual.timedOut -and $Actual.exit -eq $expectedExit -and $Actual.stdout -notmatch 'runtime error|fatal|not implemented' -and $Actual.stderr -match '^MEASURE CLI sites:[0-9]+ roots:0 heap:0 handles:0 fileAllocations:[0-9]+\n$'
}
try{
 $raw=[IO.File]::ReadAllText($RawPath)
 if([regex]::Matches($raw,'(?m)^define i32 @main\(i32 %argc, ptr %argv\) \{').Count -ne 1){throw 'Expected actual CLI platform entry'}
 $adapted=Join-Path $run 'cli-native.ll'
 [IO.File]::WriteAllText($adapted,$raw.Replace('define i32 @main(','define i32 @cli_actual_main('),$utf8)
 $observer=New-FoundationObservedRuntime $root $run $selection
 foreach($c in $observer.commands){$commands.Add($c)}
 $runtime=$observer.generated.path
 [IO.File]::WriteAllText($runtime,"#define UBE_FILE_TESTING`n"+[IO.File]::ReadAllText($runtime),$utf8)
 $object=Join-Path $run 'runtime.o'
 $r=Run-Recorded $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c11','-Wall','-Wextra','-Werror','-I',(Join-Path $root 'bootstrap/runtime'),'-include',(Join-Path $root 'std-lib/tests/managed-storage/copy-probe.h'),'-c',$runtime,'-o',$object)
 if($r.timedOut -or $r.exit -ne 0){throw "Observed CLI runtime failed:$($r.stderr)"}
 $exe=Join-Path $run 'ube.exe'
 $r=Run-Recorded $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c11','-Wall','-Wextra','-Werror','-x','ir',$adapted,'-x','c',(Join-Path $PSScriptRoot 'fault-probe.c'),'-x','none',$object,$selection.unicodeRuntime.path,'-o',$exe) 180
 if($r.timedOut -or $r.exit -ne 0){throw "Actual CLI fault probe failed:$($r.stderr)"}
 if(-not $BuildOnly){
  $source=Join-Path $run 'App.bas'
  [IO.File]::WriteAllText($source,"UBE SOURCE 1 MODULE`nAttribute UBE_Name = ""CliFaultApp""`nSub Main()`nDim x As Long = 1&`nEnd Sub`n",$utf8)
  $project=Join-Path $run 'App.UBE'
  [IO.File]::WriteAllText($project,"UBE-Project 1`nName = ""CliFaultApp""`nKind = ""Exe""`nStartup = ""Main""`nSource = ""App.bas""`n",$utf8)
  $fixturePins=@($source,$project,$exe)|ForEach-Object {Get-ArtifactIdentity $_}
  $beforeFiles=@(Get-ChildItem -LiteralPath $run -Recurse -File|Sort-Object FullName|ForEach-Object FullName)
  $fake=[pscustomobject]@{timedOut=$false;exit=1;stdout="partial`nerror UBE1428: insufficient semantic storage`n";stderr="MEASURE CLI sites:1 roots:0 heap:0 handles:0 fileAllocations:0`n"}
  if(Is-CliResourceFailure $fake){throw 'Partial-output control was accepted'}
  $fake.stdout="error UBE1428: insufficient semantic storage`nerror UBE1428: insufficient semantic storage`n"
  if(Is-CliResourceFailure $fake){throw 'Duplicate-output control was accepted'}
  $fake.stdout="error UBE1428: insufficient semantic storage`n";$fake.exit=0
  if(Is-CliResourceFailure $fake){throw 'Wrong-exit control was accepted'}
  $checks.Add([pscustomobject]@{kind='comparator';mode='controls';passed=$true;rejected=3})
  foreach($kind in @('source','project')){
   $arguments=@('--check',$source);if($kind -ceq 'project'){$arguments=@('--check',$project,'--jobs','1')}
   $control=Run-Cli $arguments
   if($control.timedOut -or $control.exit -ne 0 -or $control.stdout -cne '' -or $control.stderr -notmatch '^MEASURE CLI sites:([0-9]+) roots:0 heap:0 handles:0 fileAllocations:[0-9]+\n$'){throw "CLI resource control failed:$($control|ConvertTo-Json -Compress)"}
   $sites=[int]$Matches[1]
   if($sites -lt 10 -or $sites -gt 10000){throw 'Unexpected allocation-site inventory'}
   $checks.Add([pscustomobject]@{kind=$kind;mode='control';passed=$true;sites=$sites;actual=$control})
   $limit=$sites;if($MaximumSites -gt 0){$limit=[Math]::Min($limit,$MaximumSites)}
   for($site=1;$site -le $limit;$site++){
    $actual=Run-Cli $arguments $site
    $passed=Is-CliResourceFailure $actual
    $checks.Add([pscustomobject]@{kind=$kind;mode='allocation';site=$site;passed=$passed;actual=$actual})
    if(-not $passed){throw "CLI allocation failure $kind/site$site :$($actual|ConvertTo-Json -Compress)"}
   }
   foreach($available in @(0,1,2,8,16)){
    $actual=Run-Cli $arguments 0 $available
    $passed=Is-CliResourceFailure $actual
    $checks.Add([pscustomobject]@{kind=$kind;mode='roots';available=$available;passed=$passed;actual=$actual})
    if(-not $passed){throw "CLI full root-registry failure $kind/available$available :$($actual|ConvertTo-Json -Compress)"}
   }
   foreach($fileMode in @(2,5,6)){
    $actual=Run-Cli $arguments 0 -1 $fileMode
    $message='could not close source file';if($fileMode -eq 2){$message='could not read source file'}
    $line=6;if($fileMode -eq 2){$line=1}
    $expected="source($line,1): error UBE1008: $message`n"
    if($kind -ceq 'project'){$expected='"'+$project.Replace('\','/')+'"'+"`n"+$expected}
    $passed=-not $actual.timedOut -and $actual.exit -eq 1 -and $actual.stdout -ceq $expected -and $actual.stderr -match '^MEASURE CLI sites:[0-9]+ roots:0 heap:0 handles:0 fileAllocations:[0-9]+\n$'
    $checks.Add([pscustomobject]@{kind=$kind;mode='file';fileMode=$fileMode;passed=$passed;actual=$actual})
    if(-not $passed){throw "CLI retained file cleanup failure $kind/mode$fileMode :$($actual|ConvertTo-Json -Compress)"}
   }
  }
  $afterFiles=@(Get-ChildItem -LiteralPath $run -Recurse -File|Sort-Object FullName|ForEach-Object FullName)
  if(($beforeFiles -join "`n") -cne ($afterFiles -join "`n")){throw 'CLI resource failures created/removed an artifact'}
  foreach($pin in $fixturePins){$now=Get-ArtifactIdentity $pin.path;if($now.sha256 -cne $pin.sha256 -or $now.bytes -ne $pin.bytes){throw 'CLI resource failures changed fixture/program bytes'}}
 }
 foreach($input in $inputs){if((Get-ArtifactIdentity $input.path).sha256 -cne $input.sha256){throw 'Fault gate input changed'}}
 $success=$true
}catch{$failure=$_.Exception.Message}
finally{
 [pscustomobject]@{success=$success;failure=$failure;inputs=$inputs;checks=$checks.ToArray();commands=$commands.ToArray();scope='Actual CLI Main/dispatch, production runtime, persistent allocation denial and actual full-backed root pressure. Platform main renamed only; no semantic source bodies replaced. Whole-process no roots/managed heap/file-reader handles remain. File payload allocation counter is cumulative, not a live-byte claim. One compiled snapshot.'}|ConvertTo-Json -Depth 22|Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
 Write-Output ('Evidence: '+(Join-Path $run 'report.json'))
}
if(-not $success){throw $failure}
Write-Output ('PASS actual CLI resource checks:'+ $checks.Count)
