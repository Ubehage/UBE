# Independent source witnesses are resolved without invoking any UBE compiler.
# Logical fixture kinds map explicitly to the internal parser's comparison IDs.
function Write-NativeParserOracles([string]$FixtureDirectory,[string]$Destination){
    $utf8=New-Object Text.UTF8Encoding($false,$true)
    $kinds=@{Name=1;Literal=2;Group=3;Positive=4;Negative=5;Not=6;Power=7;Multiply=8;Divide=9;IntegerDivide=10;Modulo=11;Add=12;Subtract=13;Concat=14;Equal=15;NotEqual=16;Less=17;LessEqual=18;Greater=19;GreaterEqual=20;Like=21;Is=22;IsNot=23;And=24;AndAlso=25;Or=26;OrElse=27;Xor=28;Eqv=29;Imp=30;AddressOf=31;New=32;LeadingMember=33;Member=34;Bang=35;NamedArgument=36;TypeOfIs=37;Call=38;CallNew=39;Assign=40;LetAssign=41;SetAssign=42;CallStatement=43;CallKeyword=44;Module=45;Block=46;Parameters=47;StatementList=48;Print=49;Header=50;Option=51;Attribute=52;Field=53;VariableDecl=54;ConstantDecl=55;Parameter=56;ResultType=57;EndMarker=58;Exit=59;Label=60;Goto=61;Return=62;RecordType=63;NativeType=64;Procedure=65;IntrinsicProcedure=66;IfLine=67;IfBlock=68;ElseIf=69;Else=70;While=71;With=72;Omitted=73;TypeName=74}
    $diagnostics=@{ExpectedExpression=101;ExpectedToken=102;UnexpectedToken=103;ExpectedIdentifier=104;InvalidCallSyntax=105;UnterminatedBlock=106;UnexpectedTerminator=107}
    $kinds.LSetAssign=75;$kinds.RSetAssign=76
    $entries=@{expression=1;statement=2;unit=3}
    $text=New-Object Text.StringBuilder
    $rows=New-Object 'System.Collections.Generic.List[string]'
    $cases=New-Object 'System.Collections.Generic.List[object]'
    $counts=@{syntax=0;reject=0;deferred=0}
    function Resolve-Span([string]$Source,$Witness){
        if($Witness.PSObject.Properties['at'] -and $Witness.at -ceq 'eof'){return @($utf8.GetByteCount($Source),$utf8.GetByteCount($Source))}
        $occurrence=0;if($Witness.PSObject.Properties['occurrence']){$occurrence=[int]$Witness.occurrence}
        $at=-1
        for($index=0;$index -le $occurrence;++$index){$at=$Source.IndexOf([string]$Witness.text,$at+1,[StringComparison]::Ordinal);if($at -lt 0){throw "Missing independent parser witness $($Witness.id)"}}
        $first=$utf8.GetByteCount($Source.Substring(0,$at));$last=$first+$utf8.GetByteCount([string]$Witness.text)
        if($Witness.PSObject.Properties['at']){if($Witness.at -ceq 'start'){$last=$first}elseif($Witness.at -ceq 'end'){$first=$last}else{throw 'Unknown witness boundary'}}
        return @($first,$last)
    }
    function Emit-Shape($Shape){
        if(-not $kinds.ContainsKey([string]$Shape[0])){throw 'Unknown independent logical kind'}
        $children=New-Object 'System.Collections.Generic.List[int]'
        for($child=2;$child -lt $Shape.Count;++$child){$children.Add((Emit-Shape $Shape[$child]))}
        $span=$spans[[string]$Shape[1]];$id=$nodes.Count
        $nodes.Add([pscustomobject]@{kind=$kinds[[string]$Shape[0]];first=$span[0];last=$span[1];children=$children.ToArray()})
        return $id
    }
    $frozenCount=0
    foreach($file in @('expressions.json','statements.json','units.json','native/complex-unit.json','native/additional-cases.json','native/versions.json')){
        $definition=Get-Content -LiteralPath (Join-Path $FixtureDirectory $file) -Raw -Encoding UTF8|ConvertFrom-Json
        $isFrozen=-not $file.StartsWith('native/')
        if(($isFrozen -and $definition.schema -cne 'ube-parser-cases-1') -or (-not $isFrozen -and $definition.schema -cne 'ube-parser-native-cases-1')){throw 'Wrong parser fixture schema'}
        foreach($case in $definition.cases){
            $index=$cases.Count;$bytes=$utf8.GetBytes([string]$case.source)
            $payload='0';if($bytes.Length){$payload=$bytes -join ','}
            [void]$text.AppendLine("static const uint8_t source_$index[] = {$payload};")
            $spans=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
            foreach($witness in $case.witnesses){$spans.Add([string]$witness.id,(Resolve-Span $case.source $witness))}
            $nodes=New-Object 'System.Collections.Generic.List[object]'
            $root=-1;$nodePointer='NULL';$expected='{0,0,0}';$outcome=0;$checkFailureSpan=0
            switch -CaseSensitive ($case.outcome){
                'syntax'{
                    $root=Emit-Shape $case.shape
                    $links=New-Object 'int[]' $nodes.Count;for($i=0;$i -lt $links.Length;++$i){$links[$i]=-1}
                    foreach($node in $nodes){for($i=1;$i -lt $node.children.Count;++$i){$links[$node.children[$i-1]]=$node.children[$i]}}
                    $initializers=New-Object 'System.Collections.Generic.List[string]'
                    for($i=0;$i -lt $nodes.Count;++$i){$node=$nodes[$i];$first=-1;if($node.children.Count){$first=$node.children[0]};$initializers.Add('{'+$node.kind+','+$node.first+','+$node.last+','+$first+','+$links[$i]+','+$node.children.Count+'}')}
                    [void]$text.AppendLine("static const struct syntax_node nodes_$index[] = {$(($initializers.ToArray()) -join ',')};")
                    $nodePointer='nodes_'+$index;$outcome=1
                }
                'reject'{$span=$spans[[string]$case.diagnostic.witness];$expected='{'+$diagnostics[[string]$case.diagnostic.kind]+','+$span[0]+','+$span[1]+'}'}
                'deferred'{$expected='{3,0,0}';if($case.PSObject.Properties['deferredWitness']){$span=$spans[[string]$case.deferredWitness];$expected='{3,'+$span[0]+','+$span[1]+'}';$checkFailureSpan=1}}
                default{throw 'Unknown frozen parser outcome'}
            }
            ++$counts[[string]$case.outcome]
            if($isFrozen){++$frozenCount}
            $rows.Add('{"'+$case.name+'",source_'+$index+','+$bytes.Length+','+$entries[[string]$case.entry]+','+$outcome+','+$nodePointer+','+$nodes.Count+','+$root+','+$expected+','+$checkFailureSpan+'}')
            $cases.Add([pscustomobject]@{name=$case.name;entry=$case.entry;outcome=$case.outcome;sourceBytes=$bytes.Length;nodeCount=$nodes.Count})
        }
    }
    [void]$text.AppendLine('static const struct parser_case parser_cases[] = {'+($rows -join ",`n")+'};')
    [IO.File]::WriteAllText($Destination,$text.ToString(),$utf8)
    return [pscustomobject]@{caseCount=$cases.Count;frozenCaseCount=$frozenCount;supplementalCaseCount=$cases.Count-$frozenCount;syntax=$counts.syntax;reject=$counts.reject;deferred=$counts.deferred;cases=$cases.ToArray()}
}
