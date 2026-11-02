# Independent projections of the maintained authored fact observations.
function Get-TargetedSyntaxAt($actual,$span){
 $rows=$actual.syntax;if(@($actual.PSObject.Properties.Name) -contains 'sourceSyntax'){$rows=$actual.sourceSyntax[$span[0]]}
 $ids=New-Object Collections.Generic.List[int];for($i=0;$i -lt $rows.Count;$i++){if($rows[$i][1] -eq $span[1] -and $rows[$i][2] -eq $span[2]){$ids.Add($i)}};return $ids.ToArray()
}
function Get-TargetedDeclarationsAt($actual,$span){
 $rows=$actual.syntax;if(@($actual.PSObject.Properties.Name) -contains 'sourceSyntax'){$rows=$actual.sourceSyntax[$span[0]]}
 $ids=New-Object Collections.Generic.List[int];for($i=0;$i -lt $actual.declarations.Count;$i++){$d=$actual.declarations[$i];$n=$actual.names[$d[3]];if($n[0] -eq $span[0] -and $n[2] -eq $span[1] -and ($n[3] -eq $span[2] -or ($n[1] -ge 0 -and $rows[$n[1]][2] -eq $span[2]))){$ids.Add($i)}};return $ids.ToArray()
}
function Get-TargetedBindingSyntaxAt($actual,$span){
 $rows=$actual.syntax;if(@($actual.PSObject.Properties.Name) -contains 'sourceSyntax'){$rows=$actual.sourceSyntax[$span[0]]};$ids=New-Object 'Collections.Generic.HashSet[int]'
 foreach($syntaxId in (Get-TargetedSyntaxAt $actual $span)){$current=$syntaxId;for($depth=0;$depth -lt 256 -and $current -ge 0;$depth++){$node=$rows[$current];if($node[0] -eq 1){[void]$ids.Add($current);break};if($node[0] -in @(38,43,44)){$current=$node[3];continue};if($node[0] -eq 34 -and $node[3] -ge 0){$current=$rows[$node[3]][4];continue};break}}
 return @($ids|ForEach-Object {$_})
}
function Test-TargetedGraph($actual){
 $errors=New-Object Collections.Generic.List[string]
 $bodyModules=@([pscustomobject]@{source=0;root=$actual.root;facts=$actual.facts;values=$actual.values});if(@($actual.PSObject.Properties.Name) -contains 'modules'){$bodyModules=@($actual.modules)}
 $arenas=@(@{name='catalog';values=$actual.catalogValues;roots=@($actual.catalogFacts|Where-Object {$_[2] -eq 9}|ForEach-Object {$_[6]})});foreach($item in $bodyModules){$arenas+=@{name=('body'+$item.source);values=$item.values;roots=@($item.root)}}
 foreach($arena in $arenas){
  $values=$arena.values;$seen=@{};$pending=New-Object Collections.Generic.Stack[int];foreach($root in $arena.roots){$pending.Push($root)}
  while($pending.Count -gt 0){$id=$pending.Pop();if($id -lt 0 -or $id -ge $values.Count){$errors.Add("$($arena.name) invalid root/child $id");continue};if($seen.ContainsKey($id)){$errors.Add("$($arena.name) repeated node $id");continue};$seen[$id]=$true;$n=$values[$id]
   $rows=$actual.syntax;if(@($actual.PSObject.Properties.Name) -contains 'sourceSyntax'){if($n[0] -lt 0 -or $n[0] -ge $actual.sourceSyntax.Count){$errors.Add('invalid value source');continue};$rows=$actual.sourceSyntax[$n[0]]}
   if($n.Count -ne 11 -or $n[1] -lt 0 -or $n[1] -ge $rows.Count){$errors.Add("$($arena.name) invalid node record $id")}
   $child=$n[6];$siblings=@{};$count=0;while($child -ge 0){if($child -ge $values.Count -or $siblings.ContainsKey($child)){$errors.Add("$($arena.name) invalid sibling chain $id");break};$siblings[$child]=$true;$pending.Push($child);++$count;$child=$values[$child][7]};if($count -ne $n[8]){$errors.Add("$($arena.name) wrong child count $id")}
  }
  if($seen.Count -ne $values.Count){$errors.Add("$($arena.name) orphan value nodes")}
 }
 $factArenas=@(@{records=$actual.catalogFacts});foreach($item in $bodyModules){$factArenas+=@{records=$item.facts}}
 foreach($factArena in $factArenas){
  $keys=@{}
  foreach($f in $factArena.records){$rows=$actual.syntax;if(@($actual.PSObject.Properties.Name) -contains 'sourceSyntax'){if($f[0] -lt 0 -or $f[0] -ge $actual.sourceSyntax.Count){$errors.Add('invalid fact source');continue};$rows=$actual.sourceSyntax[$f[0]]};if($f.Count -ne 11 -or $f[1] -lt 0 -or $f[1] -ge $rows.Count -or $f[2] -lt 1 -or $f[2] -gt 9){$errors.Add('invalid semantic fact record');continue}
   $key=($f[0..2] -join ',');switch($f[2]){2{$key+=','+$f[6]}3{$key+=','+($f[5,7,9] -join ',')}4{$key+=','+$f[6]}6{$key+=','+($f[6,9,10] -join ',')}8{$key+=','+($f[5,6] -join ',')}9{$key+=','+$f[5]}}
   if($keys.ContainsKey($key)){$errors.Add("duplicate/conflicting semantic fact $key")};$keys[$key]=$true
  }
 }
 return $errors.ToArray()
}
function Compare-TargetedFacts($case,$actual){
 $errors=New-Object Collections.Generic.List[string];$assertions=0;$unsupported=New-Object Collections.Generic.List[string]
 foreach($itemError in (Test-TargetedGraph $actual)){$errors.Add($itemError)}
 $facts=@($actual.catalogFacts);$allValues=@($actual.catalogValues);$bodyModules=@([pscustomobject]@{source=0;root=$actual.root;facts=$actual.facts;values=$actual.values});if(@($actual.PSObject.Properties.Name) -contains 'modules'){$bodyModules=@($actual.modules)};foreach($item in $bodyModules){$facts+=@($item.facts);$allValues+=@($item.values)};$typeIds=@{Void=0;Boolean=1;Byte=2;Integer=3;Long=4;LongLong=5}
 foreach($decl in $case.declarations){$span=Resolve-Witness $case $decl.at;$ids=@(Get-TargetedDeclarationsAt $actual $span);if($ids.Count -ne 1){$errors.Add("declaration $($decl.id) missing/ambiguous");continue};$expectedKind=@{variable=2;constant=3;parameter=4;procedure=0;'native-type'=7;native=7}[$decl.kind];$observed=$actual.declarations[$ids[0]];if($expectedKind -eq 0){if($observed[0] -notin @(5,6)){$errors.Add("declaration $($decl.id) wrong procedure kind")}}elseif($null -ne $expectedKind -and $observed[0] -ne $expectedKind){$errors.Add("declaration $($decl.id) wrong kind")};if($typeIds.ContainsKey($decl.type) -and $observed[5] -ne $typeIds[$decl.type]){$errors.Add("declaration $($decl.id) wrong type")};++$assertions}
 foreach($expected in $case.expected.facts){
  $span=Resolve-Witness $case $expected.at;$syntax=@(Get-TargetedSyntaxAt $actual $span);$at=@($facts|Where-Object {$_[0] -eq $span[0] -and $syntax -contains $_[1]});$ok=$false;$handled=$true
  switch($expected.kind){
   'type' {$types=New-Object Collections.Generic.List[int];foreach($f in $at){if($f[2] -eq 1){$types.Add($f[3])};if($f[2] -eq 2 -and $f[5] -ge 0){$types.Add($actual.declarations[$f[5]][5])}};foreach($id in (Get-TargetedDeclarationsAt $actual $span)){$types.Add($actual.declarations[$id][5])};$ok=$types.Count -gt 0 -and @($types|Where-Object {$_ -ne $typeIds[$expected.type]}).Count -eq 0}
   'binding' {$target=@($case.declarations|Where-Object id -CEQ $expected.target);if($target.Count -eq 1){$targetIds=@(Get-TargetedDeclarationsAt $actual (Resolve-Witness $case $target[0].at));$names=@(Get-TargetedBindingSyntaxAt $actual $span);$bindings=@($facts|Where-Object {$_[0] -eq $span[0] -and $names -contains $_[1] -and $_[2] -eq 2});$ok=$targetIds.Count -eq 1 -and $bindings.Count -eq 1 -and $bindings[0][5] -eq $targetIds[0]}}
   'constant' {$value=if($expected.value -eq 'True'){1L}elseif($expected.value -eq 'False'){0L}else{[long]::Parse($expected.value,[Globalization.CultureInfo]::InvariantCulture)};$known=@($at|Where-Object {((($_[2] -eq 1) -and (($_[8] -band 1) -ne 0)) -or (($_[2] -eq 3) -and (($_[8] -band 2) -ne 0))) -and ($_[3] -eq $typeIds[$expected.type])});$ok=$known.Count -gt 0 -and @($known|Where-Object {$_[4] -ne $value}).Count -eq 0
    $materialized=@($allValues|Where-Object {$_[0] -eq $span[0] -and $syntax -contains $_[1]})
    # Constant facts in this corpus observe materialized subtrees, never merely annotations.
    if($materialized.Count -eq 0){$ok=$false};foreach($n in $materialized){if($n[2] -notin @(1,2) -or $n[6] -ne -1 -or $n[8] -ne 0){$ok=$false};$matching=@($at|Where-Object {$_[2] -eq 1 -and $_[3] -eq $n[3] -and $_[4] -eq $n[4] -and ($_[8] -band 1) -ne 0});if($matching.Count -ne 1){$ok=$false}}
   }
   'conversion' {$conversions=@($at|Where-Object {$_[2] -eq 3 -and $_[3] -eq $typeIds[$expected.type]});$flag=if($expected.value -eq 'checked'){1}else{0};$ok=$conversions.Count -gt 0 -and @($conversions|Where-Object {($_[8] -band 1) -ne $flag}).Count -eq 0}
   'option' {$mode=@{explicit=@(1,1);'compare-text'=@(2,1);'base-one'=@(3,1)}[$expected.value];$options=@($at|Where-Object {$_[2] -eq 7});$ok=$options.Count -eq 1 -and $options[0][6] -eq $mode[0] -and $options[0][7] -eq $mode[1]}
   'metadata' {$metadata=@($at|Where-Object {$_[2] -eq 8});$ok=$metadata.Count -eq 1 -and $metadata[0][6] -eq 0 -and $metadata[0][7] -eq 0}
   'primitive' {$role=if($expected.value -eq 'Value.Pack'){1}else{2};$attributes=@($at|Where-Object {$_[2] -eq 8});$ok=$attributes.Count -eq 1 -and $attributes[0][6] -eq 2 -and $attributes[0][7] -eq $role -and $actual.declarations[$attributes[0][5]][12] -eq $role}
   'representation' {$references=@($at|Where-Object {$_[2] -eq 4});$ok=$references.Count -eq 1 -and $references[0][3] -eq $typeIds[$expected.type];if($ok){$owner=$actual.declarations[$references[0][6]];$ok=$owner[0] -eq 7 -and $owner[12] -eq $typeIds[$expected.type]}}
   'control' {$ownModule=@($bodyModules|Where-Object source -EQ $span[0])[0];$nodes=@($ownModule.values|Where-Object {$syntax -contains $_[1] -and $_[2] -eq 108});$ok=$nodes.Count -eq 1 -and $nodes[0][9] -eq 3 -and $nodes[0][5] -ge 0 -and $ownModule.values[$nodes[0][5]][2] -eq 107}
   'result' {$ids=@(Get-TargetedDeclarationsAt $actual $span);$ok=$ids.Count -eq 1 -and $actual.declarations[$ids[0]][0] -eq 6 -and $actual.declarations[$ids[0]][5] -eq $typeIds[$expected.type];if($ok){$bodies=@($allValues|Where-Object {$_[2] -eq 101 -and $_[5] -eq $ids[0]});$ok=$bodies.Count -eq 1 -and $bodies[0][4] -eq 0}}
   default {$handled=$false;$unsupported.Add($expected.kind)}
  }
  if($handled){++$assertions;if(-not $ok){$errors.Add("$($expected.kind) at $($expected.at) mismatch")}}
 }
 if(Get-Command Compare-TargetedCallFacts -ErrorAction SilentlyContinue){$callResult=Compare-TargetedCallFacts $case $actual {param($c,$id) Resolve-Witness $c $id};foreach($itemError in $callResult.errors){$errors.Add($itemError)};$assertions+=$callResult.assertions;$remaining=@($unsupported|Where-Object {$_ -notin @('argument','call','evaluation')});$unsupported.Clear();foreach($item in $remaining){$unsupported.Add($item)}}
 return [pscustomobject]@{errors=$errors.ToArray();assertions=$assertions;unsupported=$unsupported.ToArray()}
}
