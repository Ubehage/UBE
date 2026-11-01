param(
 [Parameter(Mandatory=$true)][string]$ProcedureRootReport,
 [Parameter(Mandatory=$true)][string]$CollectionReport
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$prior=Get-Content -LiteralPath $ProcedureRootReport -Raw | ConvertFrom-Json
$collections=Get-Content -LiteralPath $CollectionReport -Raw | ConvertFrom-Json
if(-not $prior.success -or $prior.schema -cne 'ube-procedure-root-comparison-1'){throw 'Successful procedure-root comparison required'}
if(-not $collections.success -or $collections.observation -cne 'collections'){throw 'Successful managed-collection observation required'}
$identities=@($prior.inputs)+@($prior.artifacts)+@($collections.inputs)+@($collections.artifacts)
foreach($pin in $identities){$now=Get-ArtifactIdentity $pin.path;if($now.sha256 -cne $pin.sha256 -or $now.bytes -ne $pin.bytes){throw ('Experimental input changed: '+$pin.path)}}
$entry=@($prior.artifacts | Where-Object {$_.path -like '*procedure.ll'})
if($entry.Count -ne 1){throw 'Unique private-frame LLVM required'}
$run=Join-Path $root ('bootstrap/out/borrowed-roots/'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $run -Force
$raw=[IO.File]::ReadAllText($entry[0].path)
$script:removedRoots=0
$transform=[Text.RegularExpressions.MatchEvaluator]{param($match)
 $body=$match.Value
 $calls=@([regex]::Matches($body,'(?m)^  (%root.status.arg.(\d+)) = call i32 @ube_value_root_enter\(ptr (%root.arg.\d+), ptr (%arg.\d+), ptr @ube.value.(\d+)\)\r?$'))
 foreach($call in $calls){
  $id=$call.Groups[2].Value;$slot=$call.Groups[3].Value;$address=$call.Groups[4].Value
  $signature=($body -split "`n")[0]
  if($slot -cne ('%root.arg.'+$id) -or $address -cne ('%arg.'+$id) -or $signature -notmatch ('(?:\(|, )ptr '+[regex]::Escape($address)+'(?:,|\))')){throw 'ByRef parameter/root identity mismatch'}
  if($body -match ('(?m)^  '+[regex]::Escape($address)+' = alloca ')){throw 'Caller root unexpectedly aliases a private slot'}
  $leave='  call i32 @ube_gc_root_leave(ptr '+$slot+')'
  if([regex]::Matches($body,'(?m)^'+[regex]::Escape($leave)+'\r?$').Count -ne 1){throw 'Borrowed parameter lacks unique cleanup'}
  $body=$body.Replace($call.Value,'  '+$call.Groups[1].Value+' = add i32 0, 1').Replace($leave,'  ; caller retains the ByRef argument owner and storage')
  ++$script:removedRoots
 }
 return $body
}
$candidate=[regex]::Replace($raw,'(?ms)^define [^\r\n]+\r?\n.*?^\}',$transform)
if($removedRoots -ne 180){throw 'Frozen bounded ByRef parameter count changed; review the input before adapting'}
$candidatePath=Join-Path $run 'borrowed.ll';[IO.File]::WriteAllText($candidatePath,$candidate,[Text.UTF8Encoding]::new($false))
$pins=$identities+@((Get-ArtifactIdentity $ProcedureRootReport),(Get-ArtifactIdentity $CollectionReport),(Get-ArtifactIdentity $PSCommandPath),(Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/BORROWED-ROOT-PROBE.md')),(Get-ArtifactIdentity $candidatePath))
$success=$false;$failure=$null;$builds=@();$rows=@()
try{
 foreach($mode in @('ordinary','collections')){
  $source=$prior;if($mode -ceq 'collections'){$source=$collections}
  $exe=Join-Path $run ($mode+'.exe')
  $oldExe=@($source.artifacts | Where-Object {$_.path -like '*.exe'})
  if($oldExe.Count -ne 1){throw 'Unique source diagnostic executable required'}
  $arguments=@($source.link.arguments | ForEach-Object {if($_ -ceq $entry[0].path){$candidatePath}elseif($_ -ceq $oldExe[0].path){$exe}else{$_}})
  if(@($arguments | Where-Object {$_ -ceq $candidatePath}).Count -ne 1 -or $arguments[-1] -cne $exe){throw 'Exact link substitution failed'}
  $link=Invoke-BoundedProcess $source.link.file $arguments $root 180
  if($link.timedOut -or $link.exit -ne 0){throw ('Borrowed-root link failed: '+$link.stdout+$link.stderr)}
  $builds+=[pscustomobject]@{mode=$mode;link=$link;exe=(Get-ArtifactIdentity $exe)}
  foreach($jobs in @(1,2,4)){
   # Original native arguments retain the exact frozen input/reference bytes.
   $arguments=@($prior.rows[0].process.arguments)
   $arguments[2]=[string]$jobs
   $trial=Invoke-BoundedProcess $exe $arguments $root 600
   Write-Output ($mode+': '+$trial.stdout)
   if($trial.timedOut -or $trial.exit -ne 0){throw ('Borrowed-root UBE work failed: '+$trial.stderr)}
   $parsed=@($trial.stdout -split "`n" | Where-Object {$_} | ForEach-Object {$_ | ConvertFrom-Json})
   $cost=$parsed[-2];$result=$parsed[-1]
   if($cost.enters -ne $cost.leaves -or $cost.enters -le 0 -or $cost.enters -ge $prior.rows[0].cost.enters -or -not $result.completeResults -or -not $result.cleanup){throw 'Root reduction/balance/complete-result/cleanup assertions failed'}
   if($mode -ceq 'collections' -and ($parsed.Count -ne 3 -or $parsed[0].collections -ne 692 -or $parsed[0].collectionFailures -ne 0)){throw 'Exact successful collection count/zero failures not retained'}
   $rows+=[pscustomobject]@{mode=$mode;jobs=$jobs;cost=$cost;result=$result;collections=$(if($mode -ceq 'collections'){$parsed[0].collections}else{0});process=$trial}
  }
 }
 foreach($pin in $pins){$now=Get-ArtifactIdentity $pin.path;if($now.sha256 -cne $pin.sha256 -or $now.bytes -ne $pin.bytes){throw 'Borrowed-root experiment input changed'}}
 $success=$true
}catch{$failure=$_.Exception.Message;throw}finally{
 $report=Join-Path $run 'report.json'
 [pscustomobject]@{schema='ube-borrowed-root-comparison-1';success=$success;productionQualified=$false;performanceAccepted=$false;failure=$failure;omittedDuplicateBorrowedRoots=$removedRoots;inputs=$pins;builds=$builds;rows=$rows;artifacts=@(Get-ChildItem -LiteralPath $run -File | Where-Object Name -NE 'report.json' | ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Experimental omission of redundant callee ByRef registrations under the caller-rooted ABI; same actual UBE work, private roots, runtime and complete references. Ordinary and allocation-collection diagnostics only.'} | ConvertTo-Json -Depth 22 | Set-Content -LiteralPath $report -Encoding UTF8
 Write-Output ('Evidence: '+$report)
}
