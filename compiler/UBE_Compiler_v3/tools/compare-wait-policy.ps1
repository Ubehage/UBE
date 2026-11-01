param(
 [Parameter(Mandatory=$true)][string]$RootCostReport,
 [Parameter(Mandatory=$true)][string]$BorrowedRootReport
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$original=Get-Content -LiteralPath $RootCostReport -Raw | ConvertFrom-Json
$borrowed=Get-Content -LiteralPath $BorrowedRootReport -Raw | ConvertFrom-Json
if(-not $original.success -or $original.schema -cne 'ube-root-cost-1' -or -not $borrowed.success -or $borrowed.schema -cne 'ube-borrowed-root-comparison-1'){throw 'Successful original and borrowed-root diagnostics required'}
$pins=@($original.inputs)+@($original.artifacts)+@($borrowed.inputs)+@($borrowed.artifacts)+@((Get-ArtifactIdentity $RootCostReport),(Get-ArtifactIdentity $BorrowedRootReport),(Get-ArtifactIdentity $PSCommandPath),(Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/WAIT-POLICY-PROBE.md')))
foreach($pin in $pins){$now=Get-ArtifactIdentity $pin.path;if($now.sha256 -cne $pin.sha256 -or $now.bytes -ne $pin.bytes){throw ('Wait-policy input changed: '+$pin.path)}}
$run=Join-Path $root ('bootstrap/out/wait-policy/'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $run -Force
$originalEntry=@($original.inputs | Where-Object {$_.path -like '*frontend-performance*entry.ll'})
$borrowedEntry=@($borrowed.artifacts | Where-Object {$_.path -like '*borrowed.ll'})
if($originalEntry.Count -ne 1 -or $borrowedEntry.Count -ne 1){throw 'Unique input LLVM entries required'}
$variants=@(
 [pscustomobject]@{name='original';entry=$originalEntry[0];link=$original.link;rows=$original.rows},
 [pscustomobject]@{name='borrowed';entry=$borrowedEntry[0];link=@($borrowed.builds | Where-Object mode -CEQ 'ordinary')[0].link;rows=@($borrowed.rows | Where-Object mode -CEQ 'ordinary')}
)
$success=$false;$failure=$null;$builds=@();$rows=@()
try{
 foreach($variant in $variants){
  $raw=[IO.File]::ReadAllText($variant.entry.path)
  $pattern='(?m)^(  (%r\d+) = sext i32 )0( to i64\r?\n  %r\d+ = call i32 @ube_thread_try_wait\(i64 %r\d+, i64 \2, ptr %[^\r\n]+\)\r?$)'
  if([regex]::Matches($raw,$pattern).Count -ne 1){throw 'Unique zero-timeout/wait operand required'}
  $candidate=[regex]::Replace($raw,$pattern,'${1}1${3}')
  $candidatePath=Join-Path $run ($variant.name+'.ll')
  [IO.File]::WriteAllText($candidatePath,$candidate,[Text.UTF8Encoding]::new($false))
  $pins+=Get-ArtifactIdentity $candidatePath
  $exe=Join-Path $run ($variant.name+'.exe')
  $oldExe=$variant.link.arguments[-1]
  $arguments=@($variant.link.arguments | ForEach-Object {if($_ -ceq $variant.entry.path){$candidatePath}elseif($_ -ceq $oldExe){$exe}else{$_}})
  if(@($arguments | Where-Object {$_ -ceq $candidatePath}).Count -ne 1 -or $arguments[-1] -cne $exe){throw 'Exact link substitution failed'}
  $link=Invoke-BoundedProcess $variant.link.file $arguments $root 180
  if($link.timedOut -or $link.exit -ne 0){throw ('Wait-policy link failed: '+$link.stdout+$link.stderr)}
  $builds+=[pscustomobject]@{variant=$variant.name;link=$link;exe=(Get-ArtifactIdentity $exe)}
  foreach($jobs in @(1,2,4)){
   $arguments=@($original.rows[0].process.arguments);$arguments[2]=[string]$jobs
   $trial=Invoke-BoundedProcess $exe $arguments $root 600
   Write-Output ($variant.name+': '+$trial.stdout)
   if($trial.timedOut -or $trial.exit -ne 0){throw ('Wait-policy UBE work failed: '+$trial.stderr)}
   $parsed=@($trial.stdout -split "`n" | Where-Object {$_} | ForEach-Object {$_ | ConvertFrom-Json})
   if($parsed.Count -ne 2){throw 'Expected root-cost and complete-result rows'}
   $cost=$parsed[0];$result=$parsed[1]
   if($cost.enters -ne $variant.rows[0].cost.enters -or $cost.enters -ne $cost.leaves -or -not $result.completeResults -or -not $result.cleanup){throw 'Same root work/balance/complete-result/cleanup assertions failed'}
   $rows+=[pscustomobject]@{variant=$variant.name;jobs=$jobs;cost=$cost;result=$result;process=$trial}
  }
 }
 foreach($pin in $pins){$now=Get-ArtifactIdentity $pin.path;if($now.sha256 -cne $pin.sha256 -or $now.bytes -ne $pin.bytes){throw 'Wait-policy input changed during measurement'}}
 $success=$true
}catch{$failure=$_.Exception.Message;throw}finally{
 $report=Join-Path $run 'report.json'
 [pscustomobject]@{schema='ube-wait-policy-comparison-1';success=$success;productionQualified=$false;performanceAccepted=$false;failure=$failure;inputs=$pins;builds=$builds;rows=$rows;artifacts=@(Get-ChildItem -LiteralPath $run -File | Where-Object Name -NE 'report.json' | ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='One timeout operand changed from zero to one through the existing Threads wait API; same actual UBE admission/body/publication/drain, instrumented diagnostic only.'} | ConvertTo-Json -Depth 22 | Set-Content -LiteralPath $report -Encoding UTF8
 Write-Output ('Evidence: '+$report)
}
