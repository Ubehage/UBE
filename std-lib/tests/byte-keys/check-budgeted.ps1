param([Parameter(Mandatory=$true)][string]$ReportPath)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$previous=Get-Content -LiteralPath $ReportPath -Raw|ConvertFrom-Json
if(-not $previous.success){throw 'Passing current byte-key regression required'}
$selection=$previous.acceptedSelection;$run=Join-Path $root ('bootstrap/out/byte-key-budgets/'+[guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($run);$utf8=[Text.UTF8Encoding]::new($false)
$inputs=@((Get-ArtifactIdentity $ReportPath),(Get-ArtifactIdentity $PSCommandPath),(Get-ArtifactIdentity (Join-Path $PSScriptRoot 'budgeted.c')));$checks=@();$commands=@();$success=$false;$failure=$null
$inputs+=Get-ArtifactIdentity (Join-Path $root 'std-lib/tools/check-budgeted-byte-keys.ps1')
function Retain($Identity){$actual=Get-ArtifactIdentity $Identity.path;if($actual.sha256 -cne $Identity.sha256 -or $actual.bytes -ne $Identity.bytes){throw ('Input changed: '+$Identity.path)};$script:inputs+=@($actual);return $actual.path}
function Run([string]$File,[string[]]$Arguments,[int]$Timeout=90){$r=Invoke-BoundedProcess $File $Arguments $run $Timeout;$script:commands+=@($r);if($r.timedOut -or $r.exit -ne 0){throw ($r|ConvertTo-Json -Compress)};return $r}
try {
 foreach($input in $previous.inputs){$null=Retain $input};$runtime=Retain $previous.observer.object
 $cohort=Split-Path $ReportPath -Parent;$procedures=@{};$ordinal=0
 foreach($name in @('ByteKeys.bas','Entry.bas')){$identity=@($previous.artifacts|Where-Object {(Split-Path $_.path -Leaf) -ceq $name});if($identity.Count -ne 1){throw 'Unique captured source missing'};$path=Retain $identity[0];foreach($m in [regex]::Matches([IO.File]::ReadAllText($path),'(?m)^(?:(?:Public|Private|Friend) )?(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)')){$procedures[$m.Groups[1].Value]='ube.p'+$ordinal;++$ordinal}}
 function Definition([string]$Raw,[string]$Name,[string]$Signature){$symbol=$procedures[$Name];$match=[regex]::Matches($Raw,'(?m)^define i1 @'+[regex]::Escape($symbol)+'\(([^\r\n]*)\) \{\r?$');if($match.Count -ne 1){throw ('Missing intact definition: '+$Name)};$actual=(@($match[0].Groups[1].Value -split ', '|ForEach-Object {($_ -split ' ')[0]}) -join ',');if($actual -cne $Signature){throw ('Changed signature: '+$Name+' '+$actual)};return $symbol}
 $last=''
 foreach($record in @($previous.records|Where-Object {-not $_.negative})){
  $raw=[IO.File]::ReadAllText((Retain $record.raw));$ir=[IO.File]::ReadAllText((Retain $record.adapted));$adapter=[Text.StringBuilder]::new()
  if($raw -notmatch '(?m)^%ube.type.1 = type \{ i64, i64, i64, i64 \}\r?$'){throw 'ByteKeyBudget layout changed'}
  foreach($binding in @(@('key_order_budgeted','TryOrderByteKeysBudgeted','ptr,ptr,i32,i32,ptr,ptr,ptr,ptr'),@('key_find_budgeted','TryFindByteKeyRangeBudgeted','ptr,ptr,ptr,ptr,i32,i32,i32,ptr,ptr,ptr,ptr,ptr'))){$symbol=Definition $raw $binding[1] $binding[2];$parts=$binding[2] -split ',';$args=@();for($i=0;$i -lt $parts.Count;++$i){$args+=$parts[$i]+' %a'+$i};$null=$adapter.AppendLine('define i32 @'+$binding[0]+'('+($args -join ', ')+") {`n %ok = call i1 @"+$symbol+'('+($args -join ', ')+")`n %status = zext i1 %ok to i32`n ret i32 %status`n}")}
  $visit=Definition $raw 'TryVisitByteKeyWork' 'ptr,ptr,i1,i32,ptr';$ir=$ir.Replace('define i1 @'+$visit+'(','define i1 @byte_budget_visit_body(')
  $null=$adapter.AppendLine("declare void @budget_poll()`ndeclare void @budget_event(i32)`ndefine i1 @"+$visit+"(ptr %b, ptr %c, i1 %m, i32 %n, ptr %f) {`n br i1 %m, label %poll, label %invoke`npoll:`n call void @budget_poll()`n br label %invoke`ninvoke:`n %ok = call i1 @byte_budget_visit_body(ptr %b, ptr %c, i1 %m, i32 %n, ptr %f)`n %observe = and i1 %ok, %m`n br i1 %observe, label %observed, label %done`nobserved:`n call void @budget_event(i32 %n)`n br label %done`ndone:`n ret i1 %ok`n}")
  $null=$adapter.AppendLine("define i32 @budget_admit(ptr %b, ptr %c, i32 %n, ptr %f) {`n %ok = call i1 @"+$visit+"(ptr %b, ptr %c, i1 true, i32 %n, ptr %f)`n %status = zext i1 %ok to i32`n ret i32 %status`n}")
  $adapted=Join-Path $run ('stage'+$record.stage+'.ll');[IO.File]::WriteAllText($adapted,$ir+"`n"+$adapter.ToString(),$utf8)
  foreach($control in @('','OMIT_BUDGET_OBSERVATIONS')){
   $exe=Join-Path $run ('stage'+$record.stage+'-'+$control+'.exe');$arguments=@('--target=x86_64-w64-windows-gnu','-O2','-std=c11','-Wall','-Wextra','-Werror','-I',(Join-Path $root 'bootstrap/runtime'),'-I',$cohort,$adapted,(Join-Path $PSScriptRoot 'budgeted.c'),$runtime,$selection.unicodeRuntime.path,'-o',$exe);if($control){$arguments+='-D'+$control}
   $null=Run $selection.clang.path $arguments
   $r=Invoke-BoundedProcess $exe @() $run 90;$commands+=@($r)
   if($control){if($r.timedOut -or $r.exit -ne 1 -or $r.stderr -notmatch 'b.events==admitted_events'){throw 'Unobserved budget work not rejected'}}else{
    if($r.timedOut -or $r.exit -ne 0 -or $r.stderr -cne '' -or $r.stdout -notmatch '^PASS budgeted byte keys [1-9][0-9]* assertions;'){throw ($r|ConvertTo-Json -Compress)}
    if($last -and $last -cne $r.stdout){throw 'Budget oracle differs across compiler stages'};$last=$r.stdout
   }
   $checks+=@([pscustomobject]@{assertion='Budgeted ordering/cross-arena lookup and observed work';stage=$record.stage;control=$control;passed=$true;output=$r.stdout;error=$r.stderr})
  }
 }
 if($checks.Count -ne 4){throw 'Both stages and controls required'}
 foreach($input in $inputs){if((Get-ArtifactIdentity $input.path).sha256 -cne $input.sha256){throw ('Changed input: '+$input.path)}};$success=$true
}catch{$failure=$_.Exception.Message}
[pscustomobject]@{success=$success;failure=$failure;acceptedSelection=$selection;inputs=$inputs;checks=$checks;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Existing shared byte-key implementation: exact budgets, cross-arena lookup, cancellation at each admission, original-output preservation, allocation/root refusal and direct byte observations. No native compiler symbol inventory or binding qualification.'}|ConvertTo-Json -Depth 20|Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if(-not $success){throw $failure}
