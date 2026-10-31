# Every native entry checks the intact UBE definition's signature and layout.
# Wrappers and observation redirects live only in separate generated test LLVM.
function Write-NativeParserAbi([string]$RawPath,[string]$Destination,[string[]]$Sources){
    $raw=[IO.File]::ReadAllText($RawPath);$procedures=@{};$types=@{};$procedureIndex=0;$typeIndex=0
    foreach($source in $Sources){
        $text=[IO.File]::ReadAllText($source)
        foreach($match in [regex]::Matches($text,'(?m)^(?:(?:Public|Private|Friend) )?(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)\b')){
            $name=$match.Groups[1].Value;if($procedures.ContainsKey($name)){throw "Duplicate parser ABI name $name"};$procedures[$name]='ube.p'+$procedureIndex;++$procedureIndex
        }
        foreach($match in [regex]::Matches($text,'(?m)^Type ([A-Za-z_][A-Za-z_0-9]*)\b')){$types[$match.Groups[1].Value]='%ube.type.'+$typeIndex;++$typeIndex}
    }
    function Definition([string]$Name,[string]$Return,[string]$Arguments){
        $symbol=$procedures[$Name];if(-not $symbol){throw "Absent parser ABI declaration $Name"}
        $found=[regex]::Matches($raw,'(?m)^define '+$Return+' @'+[regex]::Escape($symbol)+'\(([^\r\n]*)\) \{\r?$')
        if($found.Count -ne 1){throw "Absent exact parser definition $Name"}
        $actual=@($found[0].Groups[1].Value -split ', '|ForEach-Object {($_ -split ' ')[0]}) -join ','
        if($actual -cne $Arguments){throw "Parser ABI mismatch $Name expected $Arguments actual $actual"}
        return $symbol
    }
    $records=@{SourcePosition='i32, i32, i32, i32';SourceDocument='ptr, i32, i32, i32';SourceFailure=('i32, '+$types.SourcePosition);SourceToken=('i32, '+$types.SourcePosition+', '+$types.SourcePosition);SyntaxNode='i32, i32, i32, i32, i32, i32';SyntaxResult='ptr, i32, i32, i32';SyntaxFailure='i32, i32, i32';SyntaxMetrics='i32, i32, i32, i32, i32';SyntaxExpressionFrame='i32, i32, i32, i32, i32, i32, i32, i32, i1, i1, i1, i1, i32';SyntaxControlFrame='i32, i32, i32, i32, i32, i32, i32, i1, i1, i1'}
    foreach($name in $records.Keys){if([regex]::Matches($raw,'(?m)^'+[regex]::Escape($types[$name]+' = type { '+$records[$name]+' }')+'\r?$').Count -ne 1){throw "Parser record mismatch $name"}}
    foreach($primitive in @(@(2,'i32'),@(7,'i8'))){
        $expected='@ube.value.'+$primitive[0]+' = private constant %ube.value.layout { i64 ptrtoint (ptr getelementptr ('+$primitive[1]+', ptr null, i32 1) to i64), i32 0, i32 0, ptr null, i64 0, ptr null }'
        if([regex]::Matches($raw,'(?m)^'+[regex]::Escape($expected)+'\r?$').Count -ne 1){throw 'Primitive scalar descriptor ABI mismatch'}
    }
    $adapter=New-Object Text.StringBuilder
    $bindings=@(@('parser_begin','BeginSourceInput','ptr,i32'),@('parser_append','AppendSourceInput','ptr,ptr,i32,i32,ptr'),@('parser_finish','TryFinishSourceInput','ptr,ptr,ptr'),@('parser_scan','TryScanSource','ptr,i32,i32,ptr,ptr'),@('parser_parse','TryParseSyntax','ptr,ptr,i32,i32,i32,i32,i32,ptr,ptr,ptr'),@('parser_source','TryParseSourceSyntax','ptr,i32,i32,i32,i32,i32,ptr,ptr,ptr'))
    foreach($binding in $bindings){
        $symbol=Definition $binding[1] 'i1' $binding[2];$parts=$binding[2] -split ',';$args=@();$calls=@()
        for($i=0;$i -lt $parts.Count;++$i){$args+=$parts[$i]+' %a'+$i;$calls+=$parts[$i]+' %a'+$i}
        [void]$adapter.AppendLine('define i32 @'+$binding[0]+'('+($args -join ', ')+") {`n %ok = call i1 @"+$symbol+'('+($calls -join ', ')+")`n %status = zext i1 %ok to i32`n ret i32 %status`n}")
    }
    if([regex]::Matches($raw,'(?m)^define i32 @main\(').Count -ne 1){throw 'Unexpected parser proof entry point'}
    $adapted=[regex]::Replace($raw,'(?m)^define i32 @main\(','define i32 @parser_unused_main(')
    [void]$adapter.AppendLine('declare void @parser_event(i32)')
    [void]$adapter.AppendLine('declare void @parser_node_live(i32)')
    [void]$adapter.AppendLine('declare void @parser_workspace_before(i32, ptr, ptr)')
    [void]$adapter.AppendLine('declare void @parser_workspace_after(i32, ptr, ptr, i32)')
    $hooks=@(@('CopyScannerToken','void','ptr,ptr',1),@('WriteSyntaxNode','void','ptr,ptr',2),@('ReadSyntaxNode','void','ptr,ptr',3),@('LinkSyntaxSibling','void','ptr,i32',4),@('SyntaxConsume','void','ptr,ptr',5),@('TrySyntaxAt','i1','ptr,ptr,ptr,ptr,ptr',6),@('TrySyntaxNewNode','i1','ptr,i32,i32,i32,ptr',7),@('TrySyntaxAttach','i1','ptr,i32,i32,ptr',8))
    foreach($hook in $hooks){
        $symbol=Definition $hook[0] $hook[1] $hook[2];$parts=$hook[2] -split ',';$args=@();$calls=@()
        for($i=0;$i -lt $parts.Count;++$i){$args+=$parts[$i]+' %a'+$i;$calls+=$parts[$i]+' %a'+$i}
        $body='parser_body_'+$symbol.Replace('.','_')
        $adapted=[regex]::Replace($adapted,'(?m)^define '+$hook[1]+' @'+[regex]::Escape($symbol)+'\(','define '+$hook[1]+' @'+$body+'(')
        [void]$adapter.AppendLine('define '+$hook[1]+' @'+$symbol+'('+($args -join ', ')+") {`n call void @parser_event(i32 "+$hook[3]+')')
        $call='call '+$hook[1]+' @'+$body+'('+($calls -join ', ')+')'
        if($hook[1] -ceq 'void'){[void]$adapter.AppendLine(' '+$call);[void]$adapter.AppendLine(' ret void')}else{
            [void]$adapter.AppendLine(' %result = '+$call)
            if($hook[0] -ceq 'TrySyntaxNewNode'){
                if($raw -notmatch ('(?m)^'+[regex]::Escape($types.SyntaxState)+' = type \{ ptr, i32, ')){throw 'SyntaxState Pending/Count prefix differs from checked observation ABI'}
                [void]$adapter.AppendLine(' %countslot = getelementptr '+$types.SyntaxState+', ptr %a0, i32 0, i32 1')
                [void]$adapter.AppendLine(' %count = load i32, ptr %countslot')
                [void]$adapter.AppendLine(' %validcount = select i1 %result, i32 %count, i32 0')
                [void]$adapter.AppendLine(' call void @parser_node_live(i32 %validcount)')
            }
            [void]$adapter.AppendLine(' ret '+$hook[1]+' %result')
        }
        [void]$adapter.AppendLine('}')
    }
    foreach($workspace in @(@('TrySyntaxPushExpression','ptr,ptr,ptr,i32,i32,i1,i1',6),@('TryGrammarPush','ptr,ptr,ptr,ptr',7))){
        $symbol=Definition $workspace[0] 'i1' $workspace[1];$parts=$workspace[1] -split ',';$args=@();$calls=@()
        for($i=0;$i -lt $parts.Count;++$i){$args+=$parts[$i]+' %a'+$i;$calls+=$parts[$i]+' %a'+$i}
        $body='parser_body_'+$symbol.Replace('.','_');$adapted=[regex]::Replace($adapted,'(?m)^define i1 @'+[regex]::Escape($symbol)+'\(','define i1 @'+$body+'(')
        [void]$adapter.AppendLine('define i1 @'+$symbol+'('+($args -join ', ')+") {`n call void @parser_workspace_before(i32 "+$workspace[2]+", ptr %a0, ptr %a1)`n %result = call i1 @"+$body+'('+($calls -join ', ')+")`n %ok = zext i1 %result to i32`n call void @parser_workspace_after(i32 "+$workspace[2]+", ptr %a0, ptr %a1, i32 %ok)`n ret i1 %result`n}")
    }
    foreach($binding in @(@('i32','ube_value_try_resize','ptr, i32, ptr, i32','parser_runtime_resize'),@('i32','ube_value_assign','ptr, ptr, ptr','parser_runtime_assign'),@('ptr','ube_value_array_element','ptr, i32, ptr, ptr, ptr','parser_runtime_element'))){
        if([regex]::Matches($raw,'(?m)^declare '+$binding[0]+' @'+$binding[1]+'\('+[regex]::Escape($binding[2])+'\)\r?$').Count -ne 1){throw "Parser runtime ABI mismatch $($binding[1])"}
        $adapted=$adapted.Replace('call '+$binding[0]+' @'+$binding[1]+'(','call '+$binding[0]+' @'+$binding[3]+'(')
        [void]$adapter.AppendLine('declare '+$binding[0]+' @'+$binding[3]+'('+$binding[2]+')')
    }
    $layoutNames=@('SourceInput','SourceDocument','SourceFailure','SourceToken','SyntaxNode','SyntaxResult','SyntaxFailure','SyntaxMetrics','SyntaxExpressionFrame','SyntaxControlFrame')
    [void]$adapter.AppendLine("define i64 @parser_layout(i32 %index) {`n switch i32 %index, label %invalid [")
    for($i=0;$i -lt $layoutNames.Count;++$i){[void]$adapter.AppendLine(" i32 $i, label %case$i")};[void]$adapter.AppendLine("]`ninvalid:`n ret i64 -1")
    for($i=0;$i -lt $layoutNames.Count;++$i){[void]$adapter.AppendLine("case${i}:`n ret i64 ptrtoint (ptr getelementptr ("+$types[$layoutNames[$i]]+", ptr null, i32 1) to i64)")};[void]$adapter.AppendLine('}')
    # The role observer classifies by compiler-owned immutable descriptor identity.
    $roles=@{SyntaxNode=2;SyntaxResult=3;SourceToken=4;SyntaxExpressionFrame=6;SyntaxControlFrame=7}
    $globals=@(@(1,'@ube.value.7'),@(5,'@ube.value.2'))
    foreach($name in $roles.Keys){$id=[int]($types[$name] -replace '^%ube.type.','');$globals+=,@($roles[$name],('@ube.value.'+(1000+$id)))}
    [void]$adapter.AppendLine("define i32 @parser_layout_role(ptr %layout) {`nentry:")
    for($i=0;$i -lt $globals.Count;++$i){$global=$globals[$i];if($raw -notmatch ('(?m)^'+[regex]::Escape($global[1])+' = private constant %ube.value.layout ')){throw 'Absent parser layout descriptor'};[void]$adapter.AppendLine(" %same$i = icmp eq ptr %layout, "+$global[1]);[void]$adapter.AppendLine(" br i1 %same$i, label %role$i, label %next$i`nrole${i}:`n ret i32 "+$global[0]+"`nnext${i}:")};[void]$adapter.AppendLine(" ret i32 0`n}")
    [IO.File]::WriteAllText($Destination,$adapted+"`n"+$adapter.ToString(),(New-Object Text.UTF8Encoding($false)))
    return [pscustomobject]@{procedureCount=$procedureIndex;types=$types;procedures=$procedures;recordNames=$layoutNames;scope='Intact UBE bodies; checked signatures/layouts; generated native wrappers and runtime observation redirects only.'}
}
