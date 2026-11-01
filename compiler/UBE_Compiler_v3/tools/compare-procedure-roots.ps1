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
$run=Join-Path $root ('bootstrap/out/procedure-roots/'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $run -Force
$raw=[IO.File]::ReadAllText($entry[0].path)
$rootExpressions=@{}
foreach($m in [regex]::Matches($raw,'(?m)^@ube.roots.(\d+) = private constant \[(\d+) x i64\] \[([^\r\n]*)\]\r?$')){
 $items=@($m.Groups[3].Value -split ', (?=i64 )')
 if($items.Count -ne [int]$m.Groups[2].Value){throw 'Original precise-root list shape differs'}
 $rootExpressions[$m.Groups[1].Value]=$items
}
$script:frameGlobals=[Text.StringBuilder]::new();$script:frameRows=@();$script:frameIndex=0
$transform=[Text.RegularExpressions.MatchEvaluator]{param($match)
 $body=$match.Value
 $allocations=@{}
 foreach($a in [regex]::Matches($body,'(?m)^  (%[^ ]+) = alloca ([^,\r\n]+)(?:, align \d+)?\r?$')){
  $allocations[$a.Groups[1].Value]=[pscustomobject]@{type=$a.Groups[2].Value;offset=$a.Index;text=$a.Value}
 }
 $admissions=@([regex]::Matches($body,'(?m)^  (%root.status.([^ ]+)) = call i32 @ube_value_root_enter\(ptr (%root.[^,]+), ptr (%[^,]+), ptr @ube.value.(\d+)\)\r?$'))
 if($admissions.Count -eq 0){return $body}
 $private=@($admissions | Where-Object {$allocations.ContainsKey($_.Groups[4].Value)})
 if($private.Count -lt 2){return $body}
 $addresses=@($private | ForEach-Object {$_.Groups[4].Value})
 if(@($addresses | Sort-Object -Unique).Count -ne $addresses.Count){throw 'A private value has duplicate roots'}
 $firstAdmission=$admissions[0].Index
 $frame='%ube.procedure.roots.'+$script:frameIndex
 $symbol='@ube.procedure.roots.'+$script:frameIndex
 $fieldTypes=@();$fields=@();$roots=@();$removed=@()
 $fieldIndex=0
 foreach($a in $private){
  $address=$a.Groups[4].Value;$layout=$a.Groups[5].Value;$slot=$a.Groups[3].Value
  $allocation=$allocations[$address]
  if($allocation.offset -ge $firstAdmission){throw 'Private root value is allocated after admission'}
  $prefix=$body.Substring($allocation.offset,$firstAdmission-$allocation.offset)
  if($prefix -notmatch ('(?m)^  store [^\r\n]+, ptr '+[regex]::Escape($address)+'(?:, align \d+)?\r?$')){throw ('Private value is not initialized before admission: '+$address)}
  if(-not $rootExpressions.ContainsKey($layout) -or $rootExpressions[$layout].Count -eq 0){throw 'Scalar-only/missing root layout in managed frame'}
  $fieldTypes+=$allocation.type
  $offset='ptrtoint (ptr getelementptr ('+$frame+', ptr null, i32 0, i32 '+$fieldIndex+') to i64)'
  $fields+='%ube.value.field { i64 '+$offset+', ptr @ube.value.'+$layout+' }'
  foreach($r in $rootExpressions[$layout]){
   if(-not $r.StartsWith('i64 ')){throw 'Unexpected precise-root offset expression'}
   $roots+='i64 add (i64 '+$offset+', '+$r+')'
  }
  $body=$body.Replace($allocation.text,'  '+$address+' = getelementptr '+$frame+', ptr %procedure.values, i32 0, i32 '+$fieldIndex)
  $body=$body.Replace($a.Value,'  '+$a.Groups[1].Value+' = add i32 0, 1')
  $leave='  call i32 @ube_gc_root_leave(ptr '+$slot+')'
  if([regex]::Matches($body,'(?m)^'+[regex]::Escape($leave)+'\r?$').Count -ne 1){throw 'Private root lacks exactly one cleanup'}
  $body=$body.Replace($leave,'  ; grouped private root cleanup')
  $removed+=$slot;++$fieldIndex
 }
 [void]$script:frameGlobals.AppendLine($frame+' = type { '+($fieldTypes -join ', ')+' }')
 [void]$script:frameGlobals.AppendLine($symbol+'.fields = private constant ['+$fields.Count+' x %ube.value.field] ['+($fields -join ', ')+']')
 [void]$script:frameGlobals.AppendLine($symbol+'.offsets = private constant ['+$roots.Count+' x i64] ['+($roots -join ', ')+']')
 [void]$script:frameGlobals.AppendLine($symbol+'.layout = private constant %ube.value.layout { i64 ptrtoint (ptr getelementptr ('+$frame+', ptr null, i32 1) to i64), i32 2, i32 '+$fields.Count+', ptr '+$symbol+'.fields, i64 '+$roots.Count+', ptr '+$symbol+'.offsets }')
 $prologue="entry:`n  %procedure.values = alloca $frame, align 8`n  %procedure.root = alloca [32 x i8], align 8`n  store [32 x i8] zeroinitializer, ptr %procedure.root, align 8"
 if([regex]::Matches($body,'(?m)^entry:\r?$').Count -ne 1){throw 'Unique procedure entry required'}
 $body=[regex]::Replace($body,'(?m)^entry:\r?$',$prologue)
 # Registration follows all original initialization, before the first original admission.
 $first=$admissions[0].Value
 $firstNow=$first
 if($removed -contains $admissions[0].Groups[3].Value){$firstNow='  '+$admissions[0].Groups[1].Value+' = add i32 0, 1'}
 $enter="  %procedure.status = call i32 @ube_value_root_enter(ptr %procedure.root, ptr %procedure.values, ptr $symbol.layout)`n  %procedure.ok = icmp ne i32 %procedure.status, 0`n  br i1 %procedure.ok, label %procedure.ready, label %proc.exit`nprocedure.ready:`n"
 if([regex]::Matches($body,[regex]::Escape($firstNow)).Count -ne 1){throw 'Unique first admission required'}
 $body=$body.Replace($firstNow,$enter+$firstNow)
 # Existing functions have one common return/cleanup exit; keep the grouped root
 # registered through all original cleanup and managed return publication.
 $returns=@([regex]::Matches($body,'(?m)^  ret [^\r\n]+\r?$'))
 if($returns.Count -ne 1 -or $body -notmatch '(?m)^proc.exit:\r?$'){throw 'Unique common procedure exit required'}
 $body=$body.Replace($returns[0].Value,"  call i32 @ube_gc_root_leave(ptr %procedure.root)`n"+$returns[0].Value)
 $script:frameRows+=[pscustomobject]@{frame=$frame;privateValues=$private.Count;pointerSlots=$roots.Count;externalRoots=($admissions.Count-$private.Count)}
 ++$script:frameIndex
 return $body
}
$candidate=[regex]::Replace($raw,'(?ms)^define [^\r\n]+\r?\n.*?^\}',$transform)
if($frameIndex -eq 0){throw 'No private procedure roots grouped'}
$firstDefinition=[regex]::Match($candidate,'(?m)^define ').Index
if($firstDefinition -le 0){throw 'Missing first LLVM definition'}
$candidate=$candidate.Insert($firstDefinition,$frameGlobals.ToString()+"`n")
$candidatePath=Join-Path $run 'procedure.ll'
[IO.File]::WriteAllText($candidatePath,$candidate,[Text.UTF8Encoding]::new($false))
$pins=@($prior.inputs)+@($prior.artifacts)+@((Get-ArtifactIdentity $RootCostReport),(Get-ArtifactIdentity $PSCommandPath),(Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/PROCEDURE-ROOT-PROBE.md')),(Get-ArtifactIdentity $candidatePath))
$exe=Join-Path $run 'diagnostic.exe';$link=$null;$rows=@();$success=$false;$failure=$null
try{
 $arguments=@($prior.link.arguments | ForEach-Object {if($_ -ceq $entry[0].path){$candidatePath}elseif($_ -ceq (Join-Path $priorRun 'diagnostic.exe')){$exe}else{$_}})
 if(@($arguments | Where-Object {$_ -ceq $candidatePath}).Count -ne 1 -or $arguments[-1] -cne $exe){throw 'Exact link argument substitution failed'}
 $link=Invoke-BoundedProcess $prior.link.file $arguments $root 180
 if($link.timedOut -or $link.exit -ne 0){throw ('Diagnostic link failed: '+$link.stdout+$link.stderr)}
 foreach($jobs in @(1,2,4)){
  $trial=Invoke-BoundedProcess $exe @((Join-Path $priorRun 'focused.inputs'),(Join-Path $priorRun 'focused.expected'),([string]$jobs),'1','0') $root 600
  Write-Output $trial.stdout
  if($trial.timedOut -or $trial.exit -ne 0){throw ('Procedure root diagnostic failed: '+$trial.stderr)}
  $parsed=@($trial.stdout -split "`n" | Where-Object {$_} | ForEach-Object {$_ | ConvertFrom-Json})
  if($parsed.Count -ne 2){throw 'Expected cost and result rows'}
  $original=@($prior.rows | Where-Object jobs -EQ $jobs)[0]
  $cost=$parsed[0];$result=$parsed[1]
  if($cost.enters -ge $original.cost.enters -or $cost.enters -ne $cost.leaves -or $cost.enters -le 0 -or $cost.jobs -ne $jobs -or -not $result.completeResults -or -not $result.cleanup){throw 'Reduced-registration/root-balance/complete-result assertions failed'}
  $rows+=[pscustomobject]@{jobs=$jobs;original=$original;cost=$cost;result=$result;process=$trial}
 }
 foreach($pin in $pins){$now=Get-ArtifactIdentity $pin.path;if($now.sha256 -cne $pin.sha256 -or $now.bytes -ne $pin.bytes){throw 'Comparison input changed'}}
 $success=$true
}catch{$failure=$_.Exception.Message;throw}finally{
 $report=Join-Path $run 'report.json'
 [pscustomobject]@{schema='ube-procedure-root-comparison-1';success=$success;productionQualified=$false;performanceAccepted=$false;failure=$failure;frames=$frameRows;inputs=$pins;link=$link;rows=$rows;artifacts=@(Get-ChildItem -LiteralPath $run -File | Where-Object Name -NE 'report.json' | ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Experimental grouping of private managed stack slots through existing precise-root API; unchanged runtime/ABI and actual UBE work. Instrumented diagnostic, not production acceptance.'} | ConvertTo-Json -Depth 22 | Set-Content -LiteralPath $report -Encoding UTF8
 Write-Output ('Evidence: '+$report)
}
