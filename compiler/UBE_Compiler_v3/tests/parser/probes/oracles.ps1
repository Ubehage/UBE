# Independent serialization of the frozen manually-authored logical shapes.
# Source is not parsed. Node identities are postorder construction identities.
function Write-ParserProbeOracles([string]$FixtureDirectory,[string]$Destination){
    $utf8=New-Object Text.UTF8Encoding($false,$true)
    $kindFile=Get-Content (Join-Path $FixtureDirectory 'probes/kinds.json') -Raw -Encoding UTF8|ConvertFrom-Json
    if($kindFile.schema -cne 'ube-parser-probe-kinds-1'){throw 'Wrong test command kind schema'}
    $kinds=[Collections.Generic.Dictionary[string,int]]::new([StringComparer]::Ordinal)
    $used=[Collections.Generic.HashSet[int]]::new()
    foreach($property in $kindFile.kinds.PSObject.Properties){if(-not $used.Add([int]$property.Value)){throw 'Duplicate test command kind'};$kinds.Add($property.Name,[int]$property.Value)}
    $text=New-Object Text.StringBuilder;$rows=New-Object 'System.Collections.Generic.List[string]';$index=0
    $selected=Get-Content (Join-Path $FixtureDirectory 'probes/traversal-oracles.json') -Raw -Encoding UTF8|ConvertFrom-Json
    $syntaxNames=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal);foreach($name in $selected.syntaxCases){if(-not $syntaxNames.Add([string]$name)){throw 'Duplicate selected expression'}}
    $lookup=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal);$expressionDefinitions=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    function Bytes([string]$Source){$bytes=$utf8.GetBytes($Source);if($bytes.Length -eq 0){return '0'};return (($bytes|ForEach-Object {$_.ToString()}) -join ',')}
    function Span([string]$Source,$Witness){
        if($Witness.PSObject.Properties['at'] -and $Witness.at -ceq 'eof'){return @($utf8.GetByteCount($Source),$utf8.GetByteCount($Source))}
        $occurrence=0;if($Witness.PSObject.Properties['occurrence']){$occurrence=[int]$Witness.occurrence};$at=-1
        for($i=0;$i -le $occurrence;++$i){$at=$Source.IndexOf([string]$Witness.text,$at+1,[StringComparison]::Ordinal);if($at -lt 0){throw 'Missing frozen witness'}}
        $first=$utf8.GetByteCount($Source.Substring(0,$at));$last=$first+$utf8.GetByteCount([string]$Witness.text)
        if($Witness.PSObject.Properties['at']){if($Witness.at -ceq 'start'){$last=$first}elseif($Witness.at -ceq 'end'){$first=$last}}
        return @($first,$last)
    }
    function Emit($Shape){
        $children=New-Object 'System.Collections.Generic.List[int]'
        for($i=2;$i -lt $Shape.Count;++$i){$children.Add((Emit $Shape[$i]))}
        $span=$spans[[string]$Shape[1]];$id=$nodes.Count
        $nodes.Add([pscustomobject]@{kind=$kinds[[string]$Shape[0]];first=$span[0];last=$span[1];children=$children.ToArray()})
        return $id
    }
    foreach($file in @('expressions','statements','units')){
        $suite=Get-Content (Join-Path $FixtureDirectory ($file+'.json')) -Raw -Encoding UTF8|ConvertFrom-Json
        foreach($case in $suite.cases){
            if($file -ceq 'expressions'){$expressionDefinitions.Add([string]$case.name,$case)}
            if($case.outcome -cne 'syntax'){continue}
            $spans=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
            foreach($witness in $case.witnesses){$spans.Add([string]$witness.id,(Span $case.source $witness))}
            $nodes=New-Object 'System.Collections.Generic.List[object]';$rootId=Emit $case.shape
            $commands=New-Object 'System.Collections.Generic.List[string]';$linked=New-Object 'System.Collections.Generic.List[string]';$edged=New-Object 'System.Collections.Generic.List[string]';$edges=New-Object 'System.Collections.Generic.List[int]'
            $next=New-Object 'int[]' $nodes.Count;for($i=0;$i -lt $next.Length;++$i){$next[$i]=-1}
            foreach($node in $nodes){for($i=1;$i -lt $node.children.Count;++$i){$next[$node.children[$i-1]]=$node.children[$i]}}
            $eligible=$syntaxNames.Contains([string]$case.name)
            for($i=0;$i -lt $nodes.Count;++$i){
                $node=$nodes[$i];$n=$node.children.Count;$first=-1;$edgeFirst=-1
                if($n){$first=$node.children[0];$edgeFirst=$edges.Count;foreach($child in $node.children){$edges.Add($child)}}
                $commands.Add('{'+$node.kind+','+$node.first+','+$node.last+','+$n+'}')
                $linked.Add('{'+$node.kind+','+$node.first+','+$node.last+','+$first+','+$next[$i]+','+$n+'}')
                $edged.Add('{'+$node.kind+','+$node.first+','+$node.last+','+$edgeFirst+','+$n+'}')
                if($eligible -and $node.kind -gt 30){throw 'Selected expression exceeds probe vocabulary'}
            }
            [void]$text.AppendLine("static const uint8_t fixture_source_$index[] = {$(Bytes ([string]$case.source))};")
            [void]$text.AppendLine("static const struct command fixture_commands_$index[] = {$($commands -join ',')};")
            [void]$text.AppendLine("static const struct linked_node fixture_linked_$index[] = {$($linked -join ',')};")
            [void]$text.AppendLine("static const struct edge_node fixture_edged_$index[] = {$($edged -join ',')};")
            $edgeText='0';if($edges.Count){$edgeText=$edges -join ','}
            [void]$text.AppendLine("static const int32_t fixture_edges_$index[] = {$edgeText};")
            $flag=0;if($eligible){$flag=1}
            $rows.Add('{"'+$case.name+'",fixture_source_'+$index+','+$utf8.GetByteCount([string]$case.source)+',fixture_commands_'+$index+','+$nodes.Count+',fixture_linked_'+$index+',fixture_edged_'+$index+',fixture_edges_'+$index+','+$edges.Count+','+$rootId+','+$flag+'}')
            $lookup.Add([string]$case.name,[pscustomobject]@{index=$index;count=$nodes.Count})
            ++$index
        }
    }
    [void]$text.AppendLine('static const struct fixture fixtures[] = {'+($rows -join ",`n")+'};')
    $expressionRows=New-Object 'System.Collections.Generic.List[string]'
    foreach($name in $selected.syntaxCases){$found=$lookup[[string]$name];$expressionRows.Add('{"'+$name+'",fixture_source_'+$found.index+','+$utf8.GetByteCount([string]$expressionDefinitions[[string]$name].source)+',fixture_commands_'+$found.index+','+$found.count+',{0,0,0}}')}
    $diagnostics=@{ExpectedExpression=101;ExpectedToken=102;UnexpectedToken=103;ExpectedIdentifier=104}
    $extraIndex=0
    $others=@();foreach($name in $selected.rejectCases){$case=$expressionDefinitions[[string]$name];if($case.outcome -cne 'reject'){throw 'Selected rejection is not a frozen rejection'};$others+=$case};$others+=@($selected.extraCases)
    foreach($case in $others){
        $spans=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal);foreach($witness in $case.witnesses){$spans.Add([string]$witness.id,(Span $case.source $witness))}
        [void]$text.AppendLine("static const uint8_t expression_source_$extraIndex[] = {$(Bytes ([string]$case.source))};")
        $count=0;$commandPointer='NULL';$failure='{0,0,0}'
        if($case.PSObject.Properties['shape']){
            $nodes=New-Object 'System.Collections.Generic.List[object]';$null=Emit $case.shape;$commands=New-Object 'System.Collections.Generic.List[string]'
            foreach($node in $nodes){$commands.Add('{'+$node.kind+','+$node.first+','+$node.last+','+$node.children.Count+'}')}
            [void]$text.AppendLine("static const struct command expression_commands_$extraIndex[] = {$($commands -join ',')};");$commandPointer='expression_commands_'+$extraIndex;$count=$nodes.Count
        }else{$span=$spans[[string]$case.diagnostic.witness];$failure='{'+$diagnostics[[string]$case.diagnostic.kind]+','+$span[0]+','+$span[1]+'}'}
        $expressionRows.Add('{"'+$case.name+'",expression_source_'+$extraIndex+','+$utf8.GetByteCount([string]$case.source)+','+$commandPointer+','+$count+','+$failure+'}');++$extraIndex
    }
    [void]$text.AppendLine('static const struct expression_case expression_cases[] = {'+($expressionRows -join ",`n")+'};')
    $negative=Get-Content (Join-Path $FixtureDirectory 'probes/storage-negative-oracles.json') -Raw -Encoding UTF8|ConvertFrom-Json
    if($negative.schema -cne 'ube-syntax-storage-negative-oracles-1'){throw 'Wrong storage domain oracle schema'}
    $negativeRows=New-Object 'System.Collections.Generic.List[string]';$i=0
    foreach($case in $negative.cases){
        [void]$text.AppendLine("static const uint8_t negative_source_$i[] = {$(Bytes ([string]$case.source))};")
        $commands=@();foreach($command in $case.commands){$commands+=('{'+$command.kind+','+$command.first+','+$command.last+','+$command.children+'}')};if($commands.Count -eq 0){$commands=@('{0,0,0,0}')}
        [void]$text.AppendLine('static const struct command negative_commands_'+$i+'[] = {'+($commands -join ',')+'};')
        $negativeRows.Add('{"'+$case.name+'",negative_source_'+$i+','+$utf8.GetByteCount([string]$case.source)+',negative_commands_'+$i+','+$case.commands.Count+','+$case.maximumNodes+','+$case.maximumEdges+','+$case.maximumPending+',{'+$case.expectedFailure.kind+','+$case.expectedFailure.index+'}}');++$i
    }
    [void]$text.AppendLine('static const struct storage_case storage_cases[] = {'+($negativeRows -join ",`n")+'};')
    [IO.File]::WriteAllText($Destination,$text.ToString(),$utf8)
    return [pscustomobject]@{syntaxTrees=$index;kinds=$kinds.Count;expressionCases=$expressionRows.Count;storageCases=$negativeRows.Count}
}
