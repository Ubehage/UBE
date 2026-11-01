param([Parameter(Mandatory=$true)][string]$RootCostReport)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$prior=Get-Content -LiteralPath $RootCostReport -Raw | ConvertFrom-Json
if(-not $prior.success -or $prior.schema -cne 'ube-root-cost-1' -or $prior.rows.Count -ne 3){throw 'Successful root-cost diagnostic required'}
foreach($pin in @($prior.inputs)+@($prior.artifacts)){
 $now=Get-ArtifactIdentity $pin.path
 if($now.sha256 -cne $pin.sha256 -or $now.bytes -ne $pin.bytes){throw ('Diagnostic source/artifact changed: '+$pin.path)}
}
$priorRun=Split-Path ([IO.Path]::GetFullPath($RootCostReport)) -Parent
$entry=@($prior.inputs | Where-Object {$_.path -like '*frontend-performance*entry.ll'})
if($entry.Count -ne 1){throw 'Unique original LLVM entry required'}
$run=Join-Path $root ('bootstrap/out/root-cleanup/'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $run -Force
$raw=[IO.File]::ReadAllText($entry[0].path)
$pattern='(?m)^(?:  call i32 @ube_gc_root_leave\(ptr %root\.[^)]+\)\r?\n)+'
$script:changedBlocks=0;$script:changedCalls=0
$reverse=[Text.RegularExpressions.MatchEvaluator]{param($match)
 $lines=@([regex]::Matches($match.Value,'[^\r\n]+\r?\n') | ForEach-Object Value)
 if($lines.Count -gt 1){++$script:changedBlocks;$script:changedCalls+=$lines.Count}
 [array]::Reverse($lines);return ($lines -join '')
}
$candidate=[regex]::Replace($raw,$pattern,$reverse)
$blocks=$changedBlocks;$calls=$changedCalls
if($blocks -lt 1 -or $calls -lt 2 -or [regex]::Replace($candidate,$pattern,$reverse) -cne $raw){throw 'Exact reversible cleanup-only permutation failed'}
$candidatePath=Join-Path $run 'cleanup.ll'
[IO.File]::WriteAllText($candidatePath,$candidate,[Text.UTF8Encoding]::new($false))
$pins=@($prior.inputs)+@($prior.artifacts)+@((Get-ArtifactIdentity $RootCostReport),(Get-ArtifactIdentity $PSCommandPath),(Get-ArtifactIdentity $candidatePath))
$exe=Join-Path $run 'diagnostic.exe';$link=$null;$rows=@();$success=$false;$failure=$null
try{
 $arguments=@($prior.link.arguments | ForEach-Object {if($_ -ceq $entry[0].path){$candidatePath}elseif($_ -ceq (Join-Path $priorRun 'diagnostic.exe')){$exe}else{$_}})
 if(@($arguments | Where-Object {$_ -ceq $candidatePath}).Count -ne 1 -or $arguments[-1] -cne $exe){throw 'Exact link argument substitution failed'}
 $link=Invoke-BoundedProcess $prior.link.file $arguments $root 180
 if($link.timedOut -or $link.exit -ne 0){throw ('Diagnostic link failed: '+$link.stdout+$link.stderr)}
 foreach($jobs in @(1,2,4)){
  $trial=Invoke-BoundedProcess $exe @((Join-Path $priorRun 'focused.inputs'),(Join-Path $priorRun 'focused.expected'),([string]$jobs),'1','0') $root 600
  Write-Output $trial.stdout
  if($trial.timedOut -or $trial.exit -ne 0){throw ('Cleanup permutation diagnostic failed: '+$trial.stderr)}
  $parsed=@($trial.stdout -split "`n" | Where-Object {$_} | ForEach-Object {$_ | ConvertFrom-Json})
  if($parsed.Count -ne 2){throw 'Expected cost and result rows'}
  $original=@($prior.rows | Where-Object jobs -EQ $jobs)[0]
  $cost=$parsed[0];$result=$parsed[1]
  if($cost.enters -ne $original.cost.enters -or $cost.leaves -ne $original.cost.leaves -or $cost.jobs -ne $jobs -or -not $result.completeResults -or -not $result.cleanup){throw 'Same-work/root-balance/complete-result assertions failed'}
  $rows+=[pscustomobject]@{jobs=$jobs;original=$original;cost=$cost;result=$result;process=$trial}
 }
 foreach($pin in $pins){$now=Get-ArtifactIdentity $pin.path;if($now.sha256 -cne $pin.sha256 -or $now.bytes -ne $pin.bytes){throw 'Comparison input changed'}}
 $success=$true
}catch{$failure=$_.Exception.Message;throw}finally{
 $report=Join-Path $run 'report.json'
 [pscustomobject]@{schema='ube-root-cleanup-comparison-1';success=$success;productionQualified=$false;performanceAccepted=$false;failure=$failure;changedCleanupBlocks=$blocks;permutedCalls=$calls;inputs=$pins;link=$link;rows=$rows;artifacts=@(Get-ChildItem -LiteralPath $run -File | Where-Object Name -NE 'report.json' | ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Experimental LLVM cleanup-call permutation only; same actual UBE worker bodies, ABI, runtime and complete expected results. Instrumented diagnostic, not production acceptance.'} | ConvertTo-Json -Depth 22 | Set-Content -LiteralPath $report -Encoding UTF8
 Write-Output ('Evidence: '+$report)
}
