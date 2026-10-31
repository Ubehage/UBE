# Test-only signature/layout checked adapters. Complete UBE definitions remain
# intact in raw IR; observation changes only separate generated test IR.
function Write-ParserProbeAbi([string]$RawPath,[string]$Destination,[string[]]$Sources,[string]$Mode){
    $raw=[IO.File]::ReadAllText($RawPath);$procedures=@{};$types=@{};$pi=0;$ti=0
    foreach($source in $Sources){
        $text=[IO.File]::ReadAllText($source)
        foreach($match in [regex]::Matches($text,'(?m)^(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)\b')){
            $name=$match.Groups[1].Value;if($procedures.ContainsKey($name)){throw "Duplicate ABI procedure $name"};$procedures[$name]='ube.p'+$pi;++$pi
        }
        foreach($match in [regex]::Matches($text,'(?m)^Type ([A-Za-z_][A-Za-z_0-9]*)\b')){$types[$match.Groups[1].Value]='%ube.type.'+$ti;++$ti}
    }
    function Definition([string]$Name,[string]$Return,[string]$Arguments){
        $symbol=$procedures[$Name];if(-not $symbol){throw "Absent procedure $Name"}
        $matches=[regex]::Matches($raw,'(?m)^define '+$Return+' @'+[regex]::Escape($symbol)+'\(([^\r\n]*)\) \{\r?$')
        if($matches.Count -ne 1){throw "Absent exact definition $Name"}
        $actual=@($matches[0].Groups[1].Value -split ', '|ForEach-Object {($_ -split ' ')[0]}) -join ','
        if($actual -cne $Arguments){throw "ABI mismatch $Name expected $Arguments actual $actual"}
        return $symbol
    }
    $adapter=New-Object Text.StringBuilder
    [void]$adapter.AppendLine('declare void @parser_probe_event(i32)')
    [void]$adapter.AppendLine('declare void @parser_probe_request(i32, ptr, i32)')
    [void]$adapter.AppendLine('declare void @parser_probe_push_request(i32, ptr)')
    [void]$adapter.AppendLine('declare i32 @parser_probe_resize(ptr, i32, ptr, i32)')
    [void]$adapter.AppendLine('declare i32 @parser_probe_assign(ptr, ptr, ptr)')
    [void]$adapter.AppendLine('declare ptr @parser_probe_element(ptr, i32, ptr, ptr, ptr)')
    $bindings=@(
        @('probe_begin','BeginSourceInput','ptr,i32'),@('probe_append','AppendSourceInput','ptr,ptr,i32,i32,ptr'),@('probe_finish','TryFinishSourceInput','ptr,ptr,ptr'),
        @('probe_build_linked','TryBuildLinkedSyntax','ptr,i32,ptr,i32,i32,i32,ptr,ptr'),@('probe_build_edge','TryBuildEdgeSyntax','ptr,i32,ptr,i32,i32,i32,ptr,ptr'),
        @('probe_project_linked','TryProjectLinkedSyntax','ptr,i32,ptr,ptr'),@('probe_project_edge','TryProjectEdgeSyntax','ptr,i32,ptr,ptr'))
    if($Mode -ceq 'traversal'){$bindings+=@(@('probe_scan','TryScanSource','ptr,i32,i32,ptr,ptr'),@('probe_stack','TryTraverseStack','ptr,ptr,i32,i32,ptr,ptr,ptr'),@('probe_recursive','TryTraverseRecursive','ptr,ptr,i32,i32,ptr,ptr,ptr'))}
    foreach($binding in $bindings){
        $symbol=Definition $binding[1] 'i1' $binding[2];$parts=$binding[2] -split ',';$args=@();$calls=@()
        for($i=0;$i -lt $parts.Count;++$i){$args+=$parts[$i]+' %a'+$i;$calls+=$parts[$i]+' %a'+$i}
        [void]$adapter.AppendLine('define i32 @'+$binding[0]+'('+($args -join ', ')+") {`n %ok = call i1 @"+$symbol+'('+($calls -join ', ')+")`n %status = zext i1 %ok to i32`n ret i32 %status`n}")
    }
    $records=@{SourcePosition='i32, i32, i32, i32';SourceDocument='ptr, i32, i32, i32';SourceFailure=('i32, '+$types.SourcePosition);SyntaxCommand='i32, i32, i32, i32';SyntaxProbeFailure='i32, i32';LinkedSyntaxNode='i32, i32, i32, i32, i32, i32';EdgeSyntaxNode='i32, i32, i32, i32, i32';LinkedSyntaxResult='ptr, i32, i32, i32';EdgeSyntaxResult='ptr, ptr, i32, i32, i32, i32';SyntaxWalkFrame='i32, i32, i32, i32, i32, i32, i32, i32';SyntaxCommandBuilder='ptr, i32, i32'}
    if($Mode -ceq 'traversal'){$records.SourceToken='i32, '+$types.SourcePosition+', '+$types.SourcePosition;$records.TraversalFailure='i32, i32, i32';$records.TraversalMetrics='i32, i32, i32, i32';$records.TraversalOperator='i32, i32, i32, i32';$records.TraversalSpan='i32, i32'}
    foreach($name in $records.Keys){if([regex]::Matches($raw,'(?m)^'+[regex]::Escape($types[$name]+' = type { '+$records[$name]+' }')+'\r?$').Count -ne 1){throw "Record mismatch $name"}}
    foreach($primitive in @(@(2,'i32'),@(7,'i8'))){
        $expected='@ube.value.'+$primitive[0]+' = private constant %ube.value.layout { i64 ptrtoint (ptr getelementptr ('+$primitive[1]+', ptr null, i32 1) to i64), i32 0, i32 0, ptr null, i64 0, ptr null }'
        if([regex]::Matches($raw,'(?m)^'+[regex]::Escape($expected)+'\r?$').Count -ne 1){throw 'Primitive scalar descriptor ABI mismatch'}
    }
    if([regex]::Matches($raw,'(?m)^define i32 @main\(').Count -ne 1){throw 'Unexpected main wrapper'}
    $adapted=[regex]::Replace($raw,'(?m)^define i32 @main\(','define i32 @parser_probe_unused_main(')
    $hooks=@(
        @('ReadSyntaxCommand','void','ptr,ptr',1),@('WriteSyntaxCommand','void','ptr,ptr',2),@('ReadLinkedSyntaxNode','void','ptr,ptr',3),@('WriteLinkedSyntaxNode','void','ptr,ptr',4),@('ReadEdgeSyntaxNode','void','ptr,ptr',5),@('WriteEdgeSyntaxNode','void','ptr,ptr',6),
        @('LinkLinkedSyntaxSibling','void','ptr,i32',7),@('StoreSyntaxEdge','void','ptr,i32',8),@('ReadSyntaxEdge','void','ptr,ptr',9),@('ReadLinkedSyntaxChild','void','ptr,ptr',10),@('ReadSyntaxIndex','void','ptr,ptr',11),@('StoreSyntaxIndex','void','ptr,i32',12),
        @('ReadSyntaxFrame','void','ptr,ptr',13),@('WriteSyntaxFrame','void','ptr,ptr',14),@('ValidateLinkedSyntaxNode','i1','ptr,i32,i32',15),@('ValidateEdgeSyntaxNode','i1','ptr,i32,i32,i32',16),@('InitializeLinkedSyntaxFrame','void','ptr,i32,ptr',17),@('InitializeEdgeSyntaxFrame','void','ptr,i32,ptr',18),
        @('TryReserveSyntaxLongs','i1','ptr,i32,i32,ptr',0),@('TryReserveLinkedSyntaxNodes','i1','ptr,i32,i32,ptr',0),@('TryReserveEdgeSyntaxNodes','i1','ptr,i32,i32,ptr',0),@('TryReserveSyntaxFrames','i1','ptr,i32,i32,ptr',0))
    if($Mode -ceq 'traversal'){$hooks+=@(@('TryReadTraversalToken','i1','ptr,i32,i32,ptr,ptr',19),@('TryEmitTraversalCommand','i1','ptr,i32,ptr,i32,ptr,ptr',20),@('TryPushTraversalOperator','i1','ptr,ptr,i32,ptr,ptr',0),@('TryPushTraversalSpan','i1','ptr,ptr,i32,ptr,ptr',0))}
    foreach($hook in $hooks){
        $symbol=Definition $hook[0] $hook[1] $hook[2];$parts=$hook[2] -split ',';$args=@();$calls=@()
        for($i=0;$i -lt $parts.Count;++$i){$args+=$parts[$i]+' %a'+$i;$calls+=$parts[$i]+' %a'+$i}
        $body='parser_probe_body_'+$symbol.Replace('.','_')
        $adapted=[regex]::Replace($adapted,'(?m)^define '+$hook[1]+' @'+[regex]::Escape($symbol)+'\(','define '+$hook[1]+' @'+$body+'(')
        [void]$adapter.AppendLine('define '+$hook[1]+' @'+$symbol+'('+($args -join ', ')+') {')
        if($hook[3] -gt 0){[void]$adapter.AppendLine(' call void @parser_probe_event(i32 '+$hook[3]+')')}
        $role=0;switch($hook[0]){'TryReserveSyntaxLongs'{$role=1};'TryReserveLinkedSyntaxNodes'{$role=3};'TryReserveEdgeSyntaxNodes'{$role=4};'TryReserveSyntaxFrames'{$role=5}}
        if($role){[void]$adapter.AppendLine(' call void @parser_probe_request(i32 '+$role+', ptr %a0, i32 %a1)')}
        if($hook[0] -ceq 'TryPushTraversalOperator'){[void]$adapter.AppendLine(' call void @parser_probe_push_request(i32 6, ptr %a1)')}
        if($hook[0] -ceq 'TryPushTraversalSpan'){[void]$adapter.AppendLine(' call void @parser_probe_push_request(i32 7, ptr %a1)')}
        $call='call '+$hook[1]+' @'+$body+'('+($calls -join ', ')+')'
        if($hook[1] -ceq 'void'){[void]$adapter.AppendLine(' '+$call);[void]$adapter.AppendLine(' ret void')}else{[void]$adapter.AppendLine(' %result = '+$call);[void]$adapter.AppendLine(' ret '+$hook[1]+' %result')}
        [void]$adapter.AppendLine('}')
    }
    foreach($binding in @(@('i32','ube_value_try_resize','ptr, i32, ptr, i32','parser_probe_resize'),@('i32','ube_value_assign','ptr, ptr, ptr','parser_probe_assign'),@('ptr','ube_value_array_element','ptr, i32, ptr, ptr, ptr','parser_probe_element'))){
        if([regex]::Matches($raw,'(?m)^declare '+$binding[0]+' @'+$binding[1]+'\('+[regex]::Escape($binding[2])+'\)\r?$').Count -ne 1){throw "Runtime ABI mismatch $($binding[1])"}
        $adapted=$adapted.Replace('call '+$binding[0]+' @'+$binding[1]+'(','call '+$binding[0]+' @'+$binding[3]+'(')
    }
    $layoutNames=@('SourceInput','SourceDocument','SourceFailure','SyntaxCommand','SyntaxProbeFailure','LinkedSyntaxNode','EdgeSyntaxNode','LinkedSyntaxResult','EdgeSyntaxResult','SyntaxWalkFrame','SyntaxCommandBuilder')
    if($Mode -ceq 'traversal'){$layoutNames+=@('SourceToken','TraversalFailure','TraversalMetrics','TraversalOperator','TraversalSpan')}
    [void]$adapter.AppendLine("define i64 @parser_probe_layout(i32 %index) {`n switch i32 %index, label %invalid [")
    for($i=0;$i -lt $layoutNames.Count;++$i){[void]$adapter.AppendLine(" i32 $i, label %case$i")};[void]$adapter.AppendLine("]`ninvalid:`n ret i64 -1")
    for($i=0;$i -lt $layoutNames.Count;++$i){[void]$adapter.AppendLine("case${i}:`n ret i64 ptrtoint (ptr getelementptr ("+$types[$layoutNames[$i]]+", ptr null, i32 1) to i64)")};[void]$adapter.AppendLine('}')
    $roles=@{SyntaxCommand=2;LinkedSyntaxNode=3;EdgeSyntaxNode=4;SyntaxWalkFrame=5;LinkedSyntaxResult=8;EdgeSyntaxResult=9}
    if($Mode -ceq 'traversal'){$roles.TraversalOperator=6;$roles.TraversalSpan=7;$roles.SourceToken=10}
    $globals=@(@(1,'@ube.value.2'),@(11,'@ube.value.7'))
    foreach($name in $roles.Keys){$id=[int]($types[$name] -replace '^%ube.type.','');$globals+=,@($roles[$name],('@ube.value.'+(1000+$id)))}
    [void]$adapter.AppendLine("define i32 @parser_probe_role(ptr %layout) {`nentry:")
    for($i=0;$i -lt $globals.Count;++$i){
        $g=$globals[$i];if($raw -notmatch ('(?m)^'+[regex]::Escape($g[1])+' = private constant %ube.value.layout ')){throw "Absent checked layout role $($g[1])"}
        [void]$adapter.AppendLine(" %same$i = icmp eq ptr %layout, "+$g[1]);[void]$adapter.AppendLine(" br i1 %same$i, label %role$i, label %next$i`nrole${i}:`n ret i32 "+$g[0]+"`nnext${i}:")
    }
    [void]$adapter.AppendLine(" ret i32 0`n}")
    [IO.File]::WriteAllText($Destination,$adapted+"`n"+$adapter.ToString(),(New-Object Text.UTF8Encoding($false)))
    return [pscustomobject]@{mode=$Mode;procedureCount=$pi;types=$types;procedures=$procedures;recordNames=$layoutNames;hookCount=$hooks.Count}
}
