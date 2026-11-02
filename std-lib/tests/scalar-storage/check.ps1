param([string]$SelectionPath='')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
. (Join-Path $root 'std-lib/tests/byte-keys/observer.ps1')
if(-not $SelectionPath){$SelectionPath=Join-Path $root 'bootstrap/out/v2/current.json'}
$Kind='scalar-storage'
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
$procedures=@{};$index=0;foreach($source in $sources){foreach($match in [regex]::Matches([IO.File]::ReadAllText($source),'(?m)^(?:(?:Public|Private|Friend) )?(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)\b')){$name=$match.Groups[1].Value;if($procedures.ContainsKey($name)){throw 'Duplicate scalar API name'};$procedures[$name]='ube.p'+$index;$index++}}
function Definition([string]$Raw,[string]$Name,[string]$Return,[string]$Arguments){$symbol=$procedures[$Name];if(-not $symbol){throw "Missing scalar declaration $Name"};$found=[regex]::Matches($Raw,'(?m)^define '+$Return+' @'+[regex]::Escape($symbol)+'\(([^\r\n]*)\) \{\r?$');if($found.Count -ne 1){throw "Missing exact scalar definition $Name"};$actual=(@($found[0].Groups[1].Value -split ', '|ForEach-Object {($_ -split ' ')[0]}) -join ',');if($actual -cne $Arguments){throw "Scalar API signature differs $Name : $actual"};return $symbol}
$stages=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path);
for($stage=0;$stage -lt 2;++$stage){
 $stem=Join-Path $run ('stage'+($stage+1));$ir=$stem+'.ll';$adapted=$stem+'-adapted.ll';$compile=Invoke-BoundedProcess $stages[$stage] @($manifest,$ir) $root 60;$commands+=@($compile);if($compile.timedOut -or $compile.exit -ne 0){throw "Scalar source emission failed: $($compile.stdout)$($compile.stderr)"};$raw=[IO.File]::ReadAllText($ir);$hashes+=(Get-ArtifactIdentity $ir).sha256;$adapter=New-Object Text.StringBuilder
 foreach($binding in @(@('plan_capacity','TryGetStorageCapacity','i32,i32,i32,ptr'),@('encode_scalar','TryEncodeUtf8Scalar','i32,ptr,ptr,ptr,ptr,ptr'))){$symbol=Definition $raw $binding[1] 'i1' $binding[2];$parts=$binding[2]-split ',';$args=@();for($a=0;$a -lt $parts.Count;++$a){$args+=$parts[$a]+' %a'+$a};[void]$adapter.AppendLine('define i32 @'+$binding[0]+'('+($args -join ', ')+") {`n %ok = call i1 @"+$symbol+'('+($args -join ', ')+")`n %status = zext i1 %ok to i32`n ret i32 %status`n}")}
 $step=Definition $raw 'NextStorageCapacity' 'i32' 'i32,i32';$raw=$raw.Replace('define i32 @'+$step+'(','define i32 @capacity_step_body(');[void]$adapter.AppendLine("declare void @capacity_step()`ndefine i32 @"+$step+"(i32 %capacity, i32 %maximum) {`n call void @capacity_step()`n %value = call i32 @capacity_step_body(i32 %capacity, i32 %maximum)`n ret i32 %value`n}")
 foreach($width in @('i32','i64')){foreach($operation in @('add','sub','mul','div','mod','neg')){$arguments=$width+', '+$width;if($operation -ceq 'neg'){$arguments=$width};$symbol='ube_checked_'+$operation+'_'+$width;$replacement='scalar_checked_'+$operation+'_'+$width;if([regex]::Matches($raw,'(?m)^declare '+$width+' @'+$symbol+'\('+[regex]::Escape($arguments)+'\)\r?$').Count -ne 1){throw 'Scalar machine helper ABI changed'};$raw=$raw.Replace('call '+$width+' @'+$symbol+'(','call '+$width+' @'+$replacement+'(');[void]$adapter.AppendLine('declare '+$width+' @'+$replacement+'('+$arguments+')')}}
 if([regex]::Matches($raw,'(?m)^declare i64 @ube_checked_narrow_i64\(i64, i32, i32\)\r?$').Count -ne 1){throw 'Scalar narrowing ABI changed'};$raw=$raw.Replace('call i64 @ube_checked_narrow_i64(','call i64 @scalar_checked_narrow_i64(');[void]$adapter.AppendLine('declare i64 @scalar_checked_narrow_i64(i64, i32, i32)')
 if([regex]::Matches($raw,'(?m)^define i32 @main\(').Count -ne 1){throw 'Scalar proof entry mismatch'};[IO.File]::WriteAllText($adapted,$raw.Replace('define i32 @main(','define i32 @scalar_unused_main(')+"`n"+$adapter.ToString(),$utf8)
 foreach($control in @('','OUTPUT','COUNTER','SCALAR_COPY')){$negative=$control -cne '';$suffix='native';$defines=@();if($negative){$suffix='negative-'+$control.ToLowerInvariant();$define='NEGATIVE_CAPACITY_'+$control;if($control -ceq 'SCALAR_COPY'){$define='NEGATIVE_SCALAR_COPY'};$defines=@('-D'+$define)};$exe=$stem+'-'+$suffix+'.exe';$link=Invoke-BoundedProcess $selection.clang.path (@('--target=x86_64-w64-windows-gnu','-O2','-I',$run,'-x','ir',$adapted,'-x','c',(Join-Path $run 'probe.c'),'-std=c11','-Wall','-Wextra','-Werror')+$defines+@('-x','none',$observer.object.path,$selection.unicodeRuntime.path,'-o',$exe)) $root 90;$commands+=@($link);if($link.timedOut -or $link.exit -ne 0){throw "Scalar native link failed: $($link.stderr)"};$native=Invoke-BoundedProcess $exe @() $root 180;$commands+=@($native);$records+=@([pscustomobject]@{stage=$stage+1;negative=$negative;control=$control;raw=(Get-ArtifactIdentity $ir);adapted=(Get-ArtifactIdentity $adapted);native=$native});if($negative){if($native.timedOut -or $native.exit -ne 1 -or -not $native.stderr.Contains('capacity assertion')){throw 'Scalar corruption control failed'}}else{if($native.timedOut -or $native.exit -ne 0 -or $native.stderr -cne '' -or $native.stdout -notmatch 'PASS scalar storage native assertions:[0-9]+\n$'){throw "Scalar native oracle failed: $($native|ConvertTo-Json -Compress)"}}}
 };if($hashes[0] -cne $hashes[1]){throw 'Scalar raw LLVM differs across selected stages'};$positive=@($records|Where-Object {-not $_.negative});if($positive[0].native.stdout -cne $positive[1].native.stdout){throw 'Scalar complete native result/counter streams differ'};foreach($id in $inputs){if((Get-ArtifactIdentity $id.path).sha256 -cne $id.sha256){throw 'Scalar source input changed'}};$positive=@($records|Where-Object {-not $_.negative})
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