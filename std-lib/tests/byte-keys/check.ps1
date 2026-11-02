param([string]$SelectionPath='')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
. (Join-Path $root 'std-lib/tests/byte-keys/observer.ps1')
if(-not $SelectionPath){$SelectionPath=Join-Path $root 'bootstrap/out/v2/current.json'}
$Kind='byte-keys'
$run=Join-Path $root ('bootstrap/out/'+$Kind+'/'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $run -Force
$utf8=New-Object Text.UTF8Encoding($false)
$selection=$null;$observer=$null;$commands=@();$records=@();$hashes=@();$inputs=@();$checks=@();$success=$false;$failure=$null;$sources=@()
try {
 $inputs+=Get-ArtifactIdentity $SelectionPath
 $selection=Get-VerifiedBootstrapSelection $SelectionPath
 foreach($property in $selection.PSObject.Properties){if($property.Name -cne 'schema'){$inputs+=$property.Value}}
 $inputs+=Get-ArtifactIdentity (Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe')
 foreach($path in @($PSCommandPath,(Join-Path $root ('std-lib/tools/check-'+$Kind+'.ps1')),(Join-Path $root 'bootstrap/tools/verification.ps1'),(Join-Path $root 'std-lib/tests/byte-keys/observer.ps1'))){$inputs+=Get-ArtifactIdentity $path}
 $names=@('ByteKeys.bas','Entry.bas');$contracts=@('BYTE-KEY-CONTRACT.md');$fixture=@('Entry.bas','probe.c','observation.h','failures.h','ORACLES.md')
 if($Kind -ceq 'scalar-storage'){$names=@('StorageCapacity.bas','Utf8Encoding.bas','Entry.bas');$contracts=@('STORAGE-CAPACITY-CONTRACT.md','UTF8-ENCODING-CONTRACT.md');$fixture=@('Entry.bas','probe.c','observation.h','ORACLES.md')}
 foreach($name in $contracts){$inputs+=Get-ArtifactIdentity (Join-Path $root ('std-lib/'+$name))}
 foreach($name in $names){$source=Join-Path $root ('std-lib/src/portable/'+$name);if($name -ceq 'Entry.bas'){$source=Join-Path $PSScriptRoot $name};$inputs+=Get-ArtifactIdentity $source;[IO.File]::Copy($source,(Join-Path $run $name));$sources+=Join-Path $run $name}
 foreach($name in $fixture){$source=Join-Path $PSScriptRoot $name;$inputs+=Get-ArtifactIdentity $source;if($name -cne 'Entry.bas'){[IO.File]::Copy($source,(Join-Path $run $name))}}
 [IO.File]::Copy($PSCommandPath,(Join-Path $run 'runner.ps1'))
 $observer=New-StorageObservedRuntime $root $selection (Join-Path $run 'observer')
 $inputs+=@($observer.inputs);$inputs+=@($observer.object,$observer.report);$checks+=@($observer.checks);$commands+=@($observer.commands)
 $manifest=Join-Path $run 'StorageProbe.UBE';$text="UBE-Project 1`nName = `"StorageProbe`"`nKind = `"Exe`"`nStartup = `"Main`"`n"
 foreach($name in $names){$text+='Source = "'+$name+"`"`n"};[IO.File]::WriteAllText($manifest,$text,$utf8)
$procedures=@{};$index=0;foreach($source in $sources){foreach($match in [regex]::Matches([IO.File]::ReadAllText($source),'(?m)^(?:(?:Public|Private|Friend) )?(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)\b')){$name=$match.Groups[1].Value;if($procedures.ContainsKey($name)){throw 'Duplicate byte key ABI name'};$procedures[$name]='ube.p'+$index;$index++}}
function Definition([string]$Raw,[string]$Name,[string]$Return,[string]$Arguments){$symbol=$procedures[$Name];if(-not $symbol){throw "Missing byte key declaration $Name"};$found=[regex]::Matches($Raw,'(?m)^define '+$Return+' @'+[regex]::Escape($symbol)+'\(([^\r\n]*)\) \{\r?$');if($found.Count -ne 1){throw "Absent exact byte key definition $Name"};$actual=(@($found[0].Groups[1].Value -split ', '|ForEach-Object {($_ -split ' ')[0]}) -join ',');if($actual -cne $Arguments){throw "Byte key ABI differs $Name : $actual"};return $symbol}
$stages=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)

for($stage=0;$stage -lt 2;++$stage){
 $stem=Join-Path $run ('stage'+($stage+1));$ir=$stem+'.ll';$adapted=$stem+'-adapted.ll';$compile=Invoke-BoundedProcess $stages[$stage] @($manifest,$ir) $root 60;$commands+=@($compile);if($compile.timedOut -or $compile.exit -ne 0){throw "Byte key emission failed: $($compile.stdout)$($compile.stderr)"};$raw=[IO.File]::ReadAllText($ir);$hashes+=(Get-ArtifactIdentity $ir).sha256;$adapter=New-Object Text.StringBuilder
 if([regex]::Matches($raw,'(?m)^%ube.type.0 = type \{ i32, i32, i32, i32 \}\r?$').Count -ne 1){throw 'ByteKey native record layout mismatch'}
 foreach($binding in @(@('key_order','TryOrderByteKeys','ptr,ptr,i32,i32,ptr,ptr'),@('key_find','TryFindByteKeyRange','ptr,ptr,ptr,i32,i32,i32,ptr,ptr,ptr'))){$symbol=Definition $raw $binding[1] 'i1' $binding[2];$parts=$binding[2]-split ',';$args=@();for($a=0;$a -lt $parts.Count;++$a){$args+=$parts[$a]+' %a'+$a};[void]$adapter.AppendLine('define i32 @'+$binding[0]+'('+($args -join ', ')+") {`n %ok = call i1 @"+$symbol+'('+($args -join ', ')+")`n %status = zext i1 %ok to i32`n ret i32 %status`n}")}
 [void]$adapter.AppendLine("define ptr @byte_key_layout() {`n ret ptr @ube.value.1000`n}`ndeclare void @byte_key_event(i32)")
 foreach($hook in @(@('TryReadByteKeyByte','i1','ptr,i32,ptr',1),@('WriteByteKeyOrder','void','ptr,i32',2),@('TryCompareByteKeys','i1','ptr,ptr,i32,i32,ptr',3),@('TryCompareByteKeyQuery','i1','ptr,ptr,i32,i32,i32,i32,i32,ptr,ptr',3),@('TryCompareByteKeySpans','i1','ptr,i32,i32,i32,i32,ptr',4))){$symbol=Definition $raw $hook[0] $hook[1] $hook[2];$body='byte_key_body_'+$symbol.Replace('.','_');$raw=[regex]::Replace($raw,'(?m)^define '+$hook[1]+' @'+[regex]::Escape($symbol)+'\(','define '+$hook[1]+' @'+$body+'(');$parts=$hook[2]-split ',';$args=@();for($a=0;$a -lt $parts.Count;++$a){$args+=$parts[$a]+' %h'+$a};[void]$adapter.AppendLine('define '+$hook[1]+' @'+$symbol+'('+($args -join ', ')+") {`n call void @byte_key_event(i32 "+$hook[3]+')');$call='call '+$hook[1]+' @'+$body+'('+($args -join ', ')+')';if($hook[1] -ceq 'void'){[void]$adapter.AppendLine(' '+$call+"`n ret void`n}")}else{[void]$adapter.AppendLine(' %ok = '+$call+"`n ret i1 %ok`n}")}}
 foreach($redirect in @(@('i32','ube_value_try_resize','ptr, i32, ptr, i32','byte_key_resize'),@('i32','ube_value_assign','ptr, ptr, ptr','byte_key_assign'),@('ptr','ube_value_array_element','ptr, i32, ptr, ptr, ptr','byte_key_element'))){if([regex]::Matches($raw,'(?m)^declare '+$redirect[0]+' @'+$redirect[1]+'\('+[regex]::Escape($redirect[2])+'\)\r?$').Count -ne 1){throw 'Byte key runtime observer ABI mismatch'};$raw=$raw.Replace('call '+$redirect[0]+' @'+$redirect[1]+'(','call '+$redirect[0]+' @'+$redirect[3]+'(');[void]$adapter.AppendLine('declare '+$redirect[0]+' @'+$redirect[3]+'('+$redirect[2]+')')}
 [void]$adapter.AppendLine("define i32 @byte_key_role(ptr %layout) {`nentry:");$roles=@(@('ube.value.7',1),@('ube.value.1000',2),@('ube.value.2',3));for($r=0;$r -lt $roles.Count;++$r){if($raw -notmatch ('(?m)^@'+[regex]::Escape($roles[$r][0])+' = private constant %ube.value.layout ')){throw 'Missing byte key immutable layout'};[void]$adapter.AppendLine(" %same$r = icmp eq ptr %layout, @"+$roles[$r][0]+"`n br i1 %same$r, label %role$r, label %next$r`nrole${r}:`n ret i32 "+$roles[$r][1]+"`nnext${r}:")};[void]$adapter.AppendLine(" ret i32 0`n}")
 if([regex]::Matches($raw,'(?m)^define i32 @main\(').Count -ne 1){throw 'Byte key proof Main mismatch'};[IO.File]::WriteAllText($adapted,$raw.Replace('define i32 @main(','define i32 @byte_key_unused_main(')+"`n"+$adapter.ToString(),$utf8)
 foreach($control in @('','EXPECTED','COUNTER','COPY','HEAP')){$negative=$control -cne '';$suffix='native';$defines=@();if($negative){$suffix='negative-'+$control.ToLowerInvariant();$defines=@('-DNEGATIVE_ORDER_'+$control)};$exe=$stem+'-'+$suffix+'.exe';$link=Invoke-BoundedProcess $selection.clang.path (@('--target=x86_64-w64-windows-gnu','-O2','-I',(Join-Path $root 'bootstrap/runtime'),'-I',$run,'-x','ir',$adapted,'-x','c',(Join-Path $run 'probe.c'),'-std=c11','-Wall','-Wextra','-Werror')+$defines+@('-x','none',$observer.object.path,$selection.unicodeRuntime.path,'-o',$exe)) $root 90;$commands+=@($link);if($link.timedOut -or $link.exit -ne 0){throw "Byte key link failed: $($link.stderr)"};$arguments=@();if($negative){$arguments=@('--suite','fixtures')};$native=Invoke-BoundedProcess $exe $arguments $root 300;$commands+=@($native);$records+=@([pscustomobject]@{stage=$stage+1;negative=$negative;control=$control;raw=(Get-ArtifactIdentity $ir);adapted=(Get-ArtifactIdentity $adapted);native=$native});if($negative){if($native.timedOut -or $native.exit -ne 1 -or -not $native.stderr.Contains('byte key assertion')){throw 'Byte key native corruption control failed'}}else{if($native.timedOut -or $native.exit -ne 0 -or $native.stderr -cne '' -or $native.stdout -notmatch 'PASS byte key native assertions:[0-9]+\n$'){throw "Byte key native oracle failed: $($native|ConvertTo-Json -Compress)"}}}
 };if($hashes[0] -cne $hashes[1]){throw 'Byte key raw LLVM differs'};foreach($id in $inputs){if((Get-ArtifactIdentity $id.path).sha256 -cne $id.sha256){throw 'Byte key source input changed'}};$positive=@($records|Where-Object {-not $_.negative})
if($positive.Count -ne 2 -or $positive[0].native.stdout -cne $positive[1].native.stdout){throw 'Complete native result/counter streams differ'}
foreach($record in $positive){
 $expectedAssertions=2097949;$expectedRows=5;if($Kind -ceq 'byte-keys'){$expectedAssertions=4827069;$expectedRows=90}
 if($record.native.stdout -notmatch ('assertions:'+$expectedAssertions+'\n$')){throw 'Native assertion count changed'}
 if(([regex]::Matches($record.native.stdout,'(?m)^\{')).Count -ne $expectedRows){throw 'Native observation row count changed'}
 $checks+=[pscustomobject]@{assertion=('stage'+$record.stage+' independent outputs, domains, budgets, resource bounds, full registry and storage failures');passed=$true}
}
foreach($record in @($records|Where-Object negative)){$checks+=[pscustomobject]@{assertion=('stage'+$record.stage+' rejected '+$record.control+' corruption');passed=$true}}
$checks+=[pscustomobject]@{assertion='Both source-built stages emitted identical LLVM and native observations';passed=$true}
foreach($id in $inputs){if((Get-ArtifactIdentity $id.path).sha256 -cne $id.sha256){throw 'Gate input changed'}}
$success=$true}catch{$failure=$_.Exception.Message}

finally {
 [pscustomobject]@{success=$success;failure=$failure;acceptedSelection=$selection;inputs=$inputs;checks=$checks;records=$records;commands=$commands;observer=$observer;artifacts=@(Get-ChildItem -LiteralPath $run -File -Recurse|Where-Object Name -CNE 'report.json'|ForEach-Object{Get-ArtifactIdentity $_.FullName});limits='Actual maintained ordinary-UBE modules, two verified source-built compiler stages; native hand-authored expectations and deterministic functional/resource/failure controls. Runtime hooks exist only in private generated test artifacts. Byte-key queries require immutable sorted builder output and caller-owned distinct outputs. No compiler naming/scope policy is provided.'}|ConvertTo-Json -Depth 30|Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
 Write-Output "Evidence: $run/report.json"
}
if(-not $success){throw $failure}
foreach($record in $records|Where-Object {-not $_.negative}){Write-Output "Stage$($record.stage): $(([regex]::Matches($record.native.stdout,'PASS [^\n]+'))[0].Value)"}