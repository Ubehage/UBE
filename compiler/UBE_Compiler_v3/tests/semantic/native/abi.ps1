# Native bridges inspect intact UBE signatures/layouts before adding wrappers.
# Expected answers remain in the independently authored C fixtures.
function Get-FoundationDefinition([string]$Raw,$Project,[string]$Name,[string]$Return,[string]$Signature){
 $symbol=$Project.procedures[$Name];if(-not $symbol){throw "Missing foundation source declaration $Name"};$found=[regex]::Matches($Raw,'(?m)^define '+$Return+' @'+[regex]::Escape($symbol)+'\(([^\r\n]*)\) \{\r?$')
 if($found.Count -ne 1){throw "Missing intact foundation definition $Name"};$actual=(@($found[0].Groups[1].Value -split ', '|ForEach-Object {($_ -split ' ')[0]}) -join ',');if($actual -cne $Signature){throw "Foundation signature changed $Name"};return $symbol
}
function Assert-FoundationRecord([string]$Raw,$Project,[string]$Name,[string]$Fields){$type=$Project.types[$Name];if(-not $type -or [regex]::Matches($Raw,'(?m)^'+[regex]::Escape($type+' = type { '+$Fields+' }')+'\r?$').Count -ne 1){throw "Foundation layout changed $Name"};return $type}
function Add-FoundationBinding($Adapter,[string]$Raw,$Project,[string]$CName,[string]$Name,[string]$Return,[string]$Signature){
 $symbol=Get-FoundationDefinition $Raw $Project $Name $Return $Signature;$arguments=@();$parts=$Signature -split ',';for($i=0;$i -lt $parts.Count;++$i){$arguments+=$parts[$i]+' %a'+$i};$native=$Return;if($native -ceq 'i1'){$native='i32'}
 [void]$Adapter.AppendLine('define '+$native+' @'+$CName+'('+($arguments -join ', ')+") {`n %result = call "+$Return+' @'+$symbol+'('+($arguments -join ', ')+')')
 if($Return -ceq 'i1'){[void]$Adapter.AppendLine(" %status = zext i1 %result to i32`n ret i32 %status`n}")}else{[void]$Adapter.AppendLine(' ret '+$Return+" %result`n}")}
}
function Redirect-FoundationRuntime([string]$Raw,$Adapter,[object[]]$Bindings){
 foreach($b in $Bindings){if([regex]::Matches($Raw,'(?m)^declare '+$b[0]+' @'+$b[1]+'\('+[regex]::Escape($b[2])+'\)\r?$').Count -ne 1){throw "Foundation runtime signature changed $($b[1])"};$Raw=$Raw.Replace('call '+$b[0]+' @'+$b[1]+'(','call '+$b[0]+' @'+$b[3]+'(');[void]$Adapter.AppendLine('declare '+$b[0]+' @'+$b[3]+'('+$b[2]+')')};return $Raw
}
function Write-FoundationArenaAbi([string]$RawPath,[string]$Destination,$Project){
 $raw=[IO.File]::ReadAllText($RawPath);$adapter=New-Object Text.StringBuilder
 $record=Assert-FoundationRecord $raw $Project 'ArenaProbeRecord' 'i32, i32, i32, i32, i64, i32, i32, i32, i32, i32, i32'
 $null=Assert-FoundationRecord $raw $Project 'ArenaProbeResult' 'ptr, i32, i32, i64';$null=Assert-FoundationRecord $raw $Project 'ArenaProbeWork' 'i32, i32, i32, i32, i32'
 Add-FoundationBinding $adapter $raw $Project 'arena_build' 'TryBuildArenaProbe' 'i1' 'ptr,i32,i32,i32,i32,ptr,ptr,ptr'
 [void]$adapter.AppendLine('declare void @arena_event(i32)')
 foreach($hook in @(@('WriteArenaProbeRecord','ptr,ptr,ptr',1),@('ReadArenaProbeRecord','ptr,ptr,ptr',2),@('ArenaProbeTransition','ptr',3))){
  $symbol=Get-FoundationDefinition $raw $Project $hook[0] 'void' $hook[1];$body='arena_body_'+$symbol.Replace('.','_');$arguments=@();$parts=$hook[1] -split ',';for($i=0;$i -lt $parts.Count;++$i){$arguments+=$parts[$i]+' %a'+$i};$raw=$raw.Replace('define void @'+$symbol+'(','define void @'+$body+'(')
  [void]$adapter.AppendLine('define void @'+$symbol+'('+($arguments -join ', ')+") {`n call void @arena_event(i32 "+$hook[2]+")`n call void @"+$body+'('+($arguments -join ', ')+")`n ret void`n}")
 }
 $raw=Redirect-FoundationRuntime $raw $adapter @(@('i32','ube_value_try_resize','ptr, i32, ptr, i32','arena_resize'),@('i32','ube_value_assign','ptr, ptr, ptr','arena_assign'))
 $id=1000+[int]($record -replace '^%ube.type.','');if($raw -notmatch ('(?m)^@ube.value.'+$id+' = private constant %ube.value.layout ')){throw 'Arena scalar descriptor absent'}
 [void]$adapter.AppendLine("define i32 @arena_role(ptr %layout) {`n %record = icmp eq ptr %layout, @ube.value.$id`n %role = zext i1 %record to i32`n ret i32 %role`n}")
 if([regex]::Matches($raw,'(?m)^define i32 @main\(').Count -ne 1){throw 'Foundation executable Main differs'}
 [IO.File]::WriteAllText($Destination,$raw.Replace('define i32 @main(','define i32 @foundation_unused_main(')+"`n"+$adapter.ToString(),(New-Object Text.UTF8Encoding($false)))
 return [pscustomobject]@{recordBytes=48;resultBytes=24;scope='Intact UBE bodies; checked native signatures/layouts; test-only event/runtime bridges.'}
}
function Write-FoundationSharedAbi([string]$RawPath,[string]$Destination,$Project){
 $raw=[IO.File]::ReadAllText($RawPath);$adapter=New-Object Text.StringBuilder
 $null=Assert-FoundationRecord $raw $Project 'SharedProbeOwner' 'ptr, ptr, ptr, ptr, ptr, ptr, i32, i32, i64, i64, i32'
 $null=Assert-FoundationRecord $raw $Project 'SharedProbeWork' 'ptr, ptr, ptr, i64, i64, i64, i64, i32, i32, i32, i32, i32, i32, i32, i32'
 $null=Assert-FoundationRecord $raw $Project 'ByteKey' 'i32, i32, i32, i32'
 foreach($b in @(@('shared_make_owner','TryMakeSharedProbeOwner','i1','i32,i32,ptr,ptr'),@('shared_finish_owner','TryFinishSharedProbeOwner','i1','ptr,ptr'),@('shared_make_work','TryMakeSharedProbeWork','i1','ptr,i32,ptr,ptr'),@('shared_start','StartSharedProbeWork','i64','ptr'),@('shared_wait','WaitSharedProbeWork','i1','i64'),@('shared_stop','StopSharedProbeWork','i1','i64'))){Add-FoundationBinding $adapter $raw $Project $b[0] $b[1] $b[2] $b[3]}
 $worker=Get-FoundationDefinition $raw $Project 'ProcessSharedProbeWork' 'void' 'ptr,ptr';$match=[regex]::Match($raw,'(?ms)^define void @'+[regex]::Escape($worker)+'\(([^\r\n]*)\) \{.*?^\}');$argument=($match.Groups[1].Value -split ', ')[0] -replace '^ptr ',''
 if([regex]::Matches($match.Value,'(?m)^thread.body:\r?$').Count -ne 1 -or [regex]::Matches($match.Value,'(?m)^proc.exit:\r?$').Count -ne 1){throw 'Checked worker admission/cleanup boundaries required'}
 $body=[regex]::Replace($match.Value,'(?m)^thread.body:\r?$','thread.body:'+"`n %observer.ready = call i32 @shared_worker_begin(ptr $argument)`n %observer.run = icmp ne i32 %observer.ready, 0`n br i1 %observer.run, label %observer.body, label %proc.exit`nobserver.body:");$body=[regex]::Replace($body,'(?m)^proc.exit:\r?$','proc.exit:'+"`n call void @shared_worker_end()");$raw=$raw.Substring(0,$match.Index)+$body+$raw.Substring($match.Index+$match.Length);[void]$adapter.AppendLine("declare i32 @shared_worker_begin(ptr)`ndeclare void @shared_worker_end()")
 $comparison=Get-FoundationDefinition $raw $Project 'TryCompareByteKeyQuery' 'i1' 'ptr,ptr,ptr,i32,i32,i32,i32,i32,ptr,ptr,ptr,ptr,i1';$raw=$raw.Replace('define i1 @'+$comparison+'(','define i1 @shared_comparison_body(')
 [void]$adapter.AppendLine("declare void @shared_comparison()`ndefine i1 @"+$comparison+"(ptr %b, ptr %q, ptr %k, i32 %i, i32 %l, i32 %p, i32 %f, i32 %n, ptr %r, ptr %e, ptr %budget, ptr %cancelled, i1 %metered) {`n call void @shared_comparison()`n %ok = call i1 @shared_comparison_body(ptr %b, ptr %q, ptr %k, i32 %i, i32 %l, i32 %p, i32 %f, i32 %n, ptr %r, ptr %e, ptr %budget, ptr %cancelled, i1 %metered)`n ret i1 %ok`n}")
 $raw=Redirect-FoundationRuntime $raw $adapter @(@('i32','ube_value_assign','ptr, ptr, ptr','shared_assign'),@('i32','ube_value_try_resize','ptr, i32, ptr, i32','shared_resize'),@('ptr','ube_value_array_element','ptr, i32, ptr, ptr, ptr','shared_element'),@('i32','ube_value_copy_bytes','ptr, i32, ptr, i32, i32','shared_copy_bytes'),@('ptr','ube_thread_capture_allocate','i64, i64, ptr','shared_capture_allocate'),@('i32','ube_gc_write_barrier','ptr, ptr, ptr','shared_barrier'))
 if([regex]::Matches($raw,'(?m)^define i32 @main\(').Count -ne 1){throw 'Foundation executable Main differs'}
 [IO.File]::WriteAllText($Destination,$raw.Replace('define i32 @main(','define i32 @foundation_unused_main(')+"`n"+$adapter.ToString(),(New-Object Text.UTF8Encoding($false)))
 return [pscustomobject]@{ownerBytes=80;workBytes=88;keyBytes=16;scope='Actual admitted UBE worker body, original admission intact, private native observations/gates only.'}
}
