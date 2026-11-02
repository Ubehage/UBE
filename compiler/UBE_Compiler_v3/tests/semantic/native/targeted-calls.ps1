# Independent argument/call/evaluation projections of authored semantic fixtures.
# Candidate rows supply observations and identity indexes, never expected values.
function Get-TCallProperty($Object,[string]$Name,$Default=$null){
 if($null -eq $Object){return $Default};$property=$Object.PSObject.Properties[$Name];if($null -eq $property){return $Default};return $property.Value
}
function Add-TCallCheck($State,[bool]$Condition,[string]$Message){
 ++$State.assertions;if(-not $Condition){$State.errors.Add($State.label+': '+$Message)}
}
function Get-TCallSyntax($Actual,[int]$Source,[int]$Id){
 $property=$Actual.PSObject.Properties['sourceSyntax'];$rows=$null
 if($null -ne $property){$all=$property.Value;if($Source -ge 0 -and $Source -lt $all.Count){$rows=$all[$Source]}}
 elseif($Source -eq 0){$rows=Get-TCallProperty $Actual 'syntax'}
 if($null -eq $rows -or $Id -lt 0 -or $Id -ge $rows.Count){return $null};return ,$rows[$Id]
}
function Get-TCallSpan($Actual,[int]$Source,[int]$Syntax){
 $row=Get-TCallSyntax $Actual $Source $Syntax;if($null -eq $row){return $null};return @($Source,[int]$row[1],[int]$row[2])
}
function Test-TCallSpan($Left,$Right){
 return $null -ne $Left -and $null -ne $Right -and @($Left).Count -eq 3 -and @($Right).Count -eq 3 -and ($Left -join ',') -ceq ($Right -join ',')
}
function Test-TCallInside($Small,$Large){
 return $null -ne $Small -and $null -ne $Large -and $Small[0] -eq $Large[0] -and $Small[1] -ge $Large[1] -and $Small[2] -le $Large[2]
}
function Get-TCallArenas($Actual){
 [pscustomobject]@{pool='catalog';facts=@(Get-TCallProperty $Actual 'catalogFacts' @());values=@(Get-TCallProperty $Actual 'catalogValues' @())}
 $modules=Get-TCallProperty $Actual 'modules'
 if($null -ne $modules -and @($modules).Count -gt 0){foreach($module in $modules){[pscustomobject]@{pool=('body:'+[string]$module.source);facts=@($module.facts);values=@($module.values)}}}
 else{[pscustomobject]@{pool='body:0';facts=@(Get-TCallProperty $Actual 'facts' @());values=@(Get-TCallProperty $Actual 'values' @())}}
}
function Get-TCallFactViews($Actual){
 foreach($arena in (Get-TCallArenas $Actual)){for($index=0;$index -lt $arena.facts.Count;++$index){[pscustomobject]@{pool=$arena.pool;index=$index;row=$arena.facts[$index];arena=$arena}}}
}
function Get-TCallNodeViews($Actual){
 foreach($arena in (Get-TCallArenas $Actual)){for($index=0;$index -lt $arena.values.Count;++$index){[pscustomobject]@{pool=$arena.pool;index=$index;row=$arena.values[$index];arena=$arena}}}
}
function Get-TCallDeclarationsAt($Actual,$Span){
 $rows=Get-TCallProperty $Actual 'declarations' @();$names=Get-TCallProperty $Actual 'names' @()
 for($index=0;$index -lt $rows.Count;++$index){$decl=$rows[$index];if($decl[3] -lt 0 -or $decl[3] -ge $names.Count){continue};$name=$names[$decl[3]]
  if($name[0] -ne $Span[0] -or $name[2] -ne $Span[1]){continue};$end=[int]$name[3];$syntax=Get-TCallSyntax $Actual $name[0] $name[1]
  if($end -eq $Span[2] -or ($null -ne $syntax -and $syntax[2] -eq $Span[2])){$index}
 }
}
function Get-TCallChildren($Actual,$View,$State){
 $children=New-Object Collections.Generic.List[object];$seen=@{};$id=[int]$View.row[6];$values=$View.arena.values
 while($id -ge 0){if($id -ge $values.Count -or $seen.ContainsKey($id)){Add-TCallCheck $State $false 'invalid child chain';break};$seen[$id]=$true;$children.Add([pscustomobject]@{pool=$View.pool;index=$id;row=$values[$id];arena=$View.arena});$id=[int]$values[$id][7]}
 Add-TCallCheck $State ($children.Count -eq $View.row[8]) 'materialized child count differs from chain'
 return $children.ToArray()
}
function Get-TCallCallAt($Actual,$Span,$State,$Facts,$Nodes){
 $calls=@($Facts|Where-Object {$_.row[2] -eq 5 -and (Test-TCallSpan (Get-TCallSpan $Actual $_.row[0] $_.row[1]) $Span)})
 Add-TCallCheck $State ($calls.Count -eq 1) 'call observation missing/ambiguous';if($calls.Count -ne 1){return $null};$call=$calls[0];$decls=$Actual.declarations
 $valid=$call.row[5] -ge 0 -and $call.row[5] -lt $decls.Count;Add-TCallCheck $State $valid 'invalid call target';if(-not $valid){return $null};$decl=$decls[$call.row[5]]
 Add-TCallCheck $State ($decl[0] -in @(5,6) -and $call.row[3] -eq $decl[5]) 'call target/result type does not match procedure'
 $arguments=@($Facts|Where-Object {$_.pool -ceq $call.pool -and $_.row[2] -eq 6 -and $_.row[6] -eq $call.index}|Sort-Object { $_.row[10] })
 Add-TCallCheck $State ($arguments.Count -eq $decl[8] -and $call.row[7] -eq $arguments.Count) 'argument map is incomplete or extra'
 $written=New-Object Collections.Generic.List[int]
 for($p=0;$p -lt $arguments.Count;++$p){$argument=$arguments[$p];$parameterId=[int]$decl[7]+$p;$valid=$parameterId -ge 0 -and $parameterId -lt $decls.Count
  Add-TCallCheck $State ($valid -and $argument.index -eq $call.row[6]+$p -and $argument.row[10] -eq $p -and $argument.row[5] -eq $parameterId) 'parameter order/target or contiguous argument map differs'
  if($valid){$parameter=$decls[$parameterId];Add-TCallCheck $State ($parameter[0] -eq 4 -and $parameter[4] -eq $call.row[5] -and $parameter[9] -eq $p -and $argument.row[3] -eq $parameter[5]) 'argument does not match its declared parameter'}
  if($argument.row[9] -ge 0){$written.Add([int]$argument.row[9])}
 }
 $ordered=@($written|Sort-Object);$complete=$ordered.Count -eq $call.row[9];for($p=0;$p -lt $ordered.Count;++$p){if($ordered[$p] -ne $p){$complete=$false}}
 Add-TCallCheck $State $complete 'written source slots are missing, duplicate or invented'
 if($arguments.Count -eq 0){Add-TCallCheck $State ($call.row[6] -eq -1) 'zero arguments must have absent first-argument index'}
 $bound=@($Nodes|Where-Object {$_.pool -ceq $call.pool -and $_.row[2] -eq 6 -and $_.row[10] -eq $call.index -and $_.row[0] -eq $call.row[0] -and $_.row[1] -eq $call.row[1]})
 Add-TCallCheck $State ($bound.Count -eq 1) 'live call node missing/ambiguous';if($bound.Count -ne 1){return $null}
 Add-TCallCheck $State ($bound[0].row[5] -eq $call.row[5] -and $bound[0].row[3] -eq $call.row[3]) 'call value target/type differs'
 $children=@(Get-TCallChildren $Actual $bound[0] $State);Add-TCallCheck $State ($children.Count -eq $arguments.Count) 'call does not materialize exactly one child per argument'
 return [pscustomobject]@{fact=$call;declaration=$decl;arguments=$arguments;node=$bound[0];children=$children}
}
function Test-TCallMode($Actual,$Call,$Argument,[string]$Mode,[int]$Type,$Span,$State,$Facts){
 $row=$Argument.row;$decls=$Actual.declarations;$valid=$row[5] -ge 0 -and $row[5] -lt $decls.Count;Add-TCallCheck $State $valid 'argument target outside declarations';if(-not $valid){return};$parameter=$decls[$row[5]]
 $modes=@{value=0;alias=1;temporary=2;'default-temporary'=3;'default-value'=3};if(-not $modes.ContainsKey($Mode)){Add-TCallCheck $State $false ('unsupported authored argument mode '+$Mode);return}
 Add-TCallCheck $State (($row[8] -band 3) -eq $modes[$Mode] -and $row[3] -eq $Type -and $parameter[5] -eq $Type) 'argument mode/type differs'
 if($Mode -eq 'value' -or $Mode -eq 'default-value'){Add-TCallCheck $State (($parameter[6] -band 4) -ne 0) 'ByVal argument bound to ByRef parameter'}else{Add-TCallCheck $State (($parameter[6] -band 4) -eq 0) 'ByRef argument bound to ByVal parameter'}
 if($Mode -like 'default-*'){
  Add-TCallCheck $State (($parameter[6] -band 8) -ne 0 -and $parameter[11] -ne 0 -and $row[7] -eq -1) 'default is not a prepared optional constant'
 }else{
  $sourceSpan=Get-TCallSpan $Actual $row[0] $row[7];Add-TCallCheck $State (Test-TCallSpan $sourceSpan $Span) 'written argument expression span differs'
  $expression=@($Facts|Where-Object {$_.pool -ceq $Argument.pool -and $_.row[2] -eq 1 -and $_.row[0] -eq $row[0] -and $_.row[1] -eq $row[7]})
  Add-TCallCheck $State ($expression.Count -eq 1) 'argument expression typing missing/ambiguous'
  if($expression.Count -eq 1){
   if($Mode -eq 'alias'){Add-TCallCheck $State ($expression[0].row[3] -eq $Type -and ($expression[0].row[8] -band 2) -ne 0 -and ($expression[0].row[8] -band 4) -eq 0) 'alias is not direct writable exact-type storage'
    $bindings=@($Facts|Where-Object {$_.pool -ceq $Argument.pool -and $_.row[2] -eq 2 -and $_.row[6] -eq 10 -and $_.row[5] -eq $expression[0].row[5] -and (Test-TCallInside (Get-TCallSpan $Actual $_.row[0] $_.row[1]) $Span)})
    Add-TCallCheck $State ($bindings.Count -eq 1) 'alias argument-storage binding missing/ambiguous'
   }
   if($Mode -eq 'temporary'){Add-TCallCheck $State (($expression[0].row[8] -band 4) -ne 0) 'forced temporary lost individual grouping'
    $aliases=@($Facts|Where-Object {$_.pool -ceq $Argument.pool -and $_.row[2] -eq 2 -and $_.row[6] -eq 10 -and (Test-TCallInside (Get-TCallSpan $Actual $_.row[0] $_.row[1]) $Span)})
    Add-TCallCheck $State ($aliases.Count -eq 0) 'forced temporary still aliases caller storage'
   }
  }
 }
 $conversionSyntax=[int]$row[7];if($conversionSyntax -lt 0){$conversionSyntax=[int]$row[1]}
 $conversions=@($Facts|Where-Object {$_.pool -ceq $Argument.pool -and $_.row[2] -eq 3 -and $_.row[0] -eq $row[0] -and $_.row[1] -eq $conversionSyntax -and $_.row[5] -eq $row[5] -and $_.row[9] -eq $row[10] -and $_.row[7] -in @(6,9,10)})
 Add-TCallCheck $State ($conversions.Count -eq 1 -and $conversions[0].row[3] -eq $Type) 'argument conversion edge missing/ambiguous'
 if($Mode -eq 'alias' -and $conversions.Count -eq 1){Add-TCallCheck $State ($conversions[0].row[6] -eq $Type -and ($conversions[0].row[8] -band 1) -eq 0) 'alias contains a nonidentity conversion'}
}

function Compare-TargetedCallFacts($Case,$Actual,[scriptblock]$ResolveWitness){
 $state=[pscustomobject]@{errors=(New-Object Collections.Generic.List[string]);assertions=0;label=[string]$Case.id}
 $items=@($Case.expected.facts|Where-Object {$_.kind -in @('argument','call','evaluation')});$handled=0
 if($items.Count -eq 0){return [pscustomobject]@{errors=@();assertions=0;handled=0}}
 Add-TCallCheck $state ([bool](Get-TCallProperty $Actual 'ok' $false)) 'successful native observations required';if(-not (Get-TCallProperty $Actual 'ok' $false)){return [pscustomobject]@{errors=$state.errors.ToArray();assertions=$state.assertions;handled=$items.Count}}
 $facts=@(Get-TCallFactViews $Actual);$nodes=@(Get-TCallNodeViews $Actual);$types=@{Void=0;Boolean=1;Byte=2;Integer=3;Long=4;LongLong=5}
 foreach($expected in $items){++$handled;$state.label=[string]$Case.id+'/'+$expected.kind+'@'+$expected.at
  try{$span=@(& $ResolveWitness $Case $expected.at)}catch{Add-TCallCheck $state $false ('invalid independent witness: '+$_.Exception.Message);continue}
  if($expected.kind -eq 'argument'){
   if(-not $types.ContainsKey($expected.type)){Add-TCallCheck $state $false 'unknown authored argument type';continue};$type=$types[$expected.type]
   if($expected.value -in @('zero-slots','default-temporary','omitted-first-default')){
    $call=Get-TCallCallAt $Actual $span $state $facts $nodes;if($null -eq $call){continue}
    if($expected.value -eq 'zero-slots'){Add-TCallCheck $state ($call.fact.row[9] -eq 0 -and $call.fact.row[7] -eq 0 -and $call.declaration[8] -eq 0 -and $call.fact.row[3] -eq $type -and $call.children.Count -eq 0) 'zero slots were replaced by an omitted/default slot'}
    if($expected.value -eq 'default-temporary'){
     $default=@($call.arguments|Where-Object {($_.row[8] -band 3) -eq 3});Add-TCallCheck $state ($default.Count -eq 1) 'fresh default argument missing/ambiguous'
     if($default.Count -eq 1){Test-TCallMode $Actual $call $default[0] 'default-temporary' $type $span $state $facts;Add-TCallCheck $state ($default[0].row[9] -eq -1 -and ($default[0].row[8] -band 16) -ne 0 -and ($default[0].row[8] -band 8) -eq 0) 'missing default confused with written omitted slot'}
    }
    if($expected.value -eq 'omitted-first-default'){
     Add-TCallCheck $state ($call.arguments.Count -eq 2 -and $call.fact.row[9] -eq 2) 'omitted list source slots not preserved'
     if($call.arguments.Count -eq 2){$first=$call.arguments[0];Add-TCallCheck $state (($first.row[8] -band 3) -eq 3 -and ($first.row[8] -band 8) -ne 0 -and ($first.row[8] -band 16) -eq 0 -and $first.row[9] -eq 0 -and $first.row[3] -eq $type -and $first.row[7] -eq -1) 'first explicit omitted/default mapping differs';$omitted=Get-TCallSyntax $Actual $first.row[0] $first.row[1];Add-TCallCheck $state ($null -ne $omitted -and $omitted[0] -eq 73 -and $omitted[1] -eq $omitted[2]) 'omitted source slot lost its zero-width syntax';Add-TCallCheck $state ($call.arguments[1].row[9] -eq 1 -and ($call.arguments[1].row[8] -band 3) -eq 0) 'second written argument moved or changed mode'}
    }
   }else{
    $arguments=@($facts|Where-Object {$_.row[2] -eq 6 -and (Test-TCallSpan (Get-TCallSpan $Actual $_.row[0] $_.row[7]) $span)})
    Add-TCallCheck $state ($arguments.Count -eq 1) 'argument observation missing/ambiguous';if($arguments.Count -ne 1){continue};$argument=$arguments[0]
    $callFact=@($facts|Where-Object {$_.pool -ceq $argument.pool -and $_.index -eq $argument.row[6] -and $_.row[2] -eq 5});Add-TCallCheck $state ($callFact.Count -eq 1) 'argument has no owning call'
    if($callFact.Count -eq 1){$call=Get-TCallCallAt $Actual (Get-TCallSpan $Actual $callFact[0].row[0] $callFact[0].row[1]) $state $facts $nodes;if($null -ne $call){Test-TCallMode $Actual $call $argument $expected.value $type $span $state $facts}}
   }
  }elseif($expected.kind -eq 'call'){
   $call=Get-TCallCallAt $Actual $span $state $facts $nodes;if($null -eq $call){continue}
   $target=@($Case.declarations|Where-Object id -CEQ $expected.target);Add-TCallCheck $state ($target.Count -eq 1) 'authored call target absent/ambiguous'
   if($target.Count -eq 1){$targetSpan=@(& $ResolveWitness $Case $target[0].at);$ids=@(Get-TCallDeclarationsAt $Actual $targetSpan);Add-TCallCheck $state ($ids.Count -eq 1 -and $call.fact.row[5] -eq $ids[0]) 'call bound another declaration'}
   $written=@($expected.arguments);Add-TCallCheck $state ($call.fact.row[9] -eq $written.Count) 'written call arity differs'
   for($slot=0;$slot -lt $written.Count;++$slot){$item=$written[$slot];$itemSpan=@(& $ResolveWitness $Case $item.at);$matches=@($call.arguments|Where-Object {Test-TCallSpan (Get-TCallSpan $Actual $_.row[0] $_.row[7]) $itemSpan});Add-TCallCheck $state ($matches.Count -eq 1) 'authored call argument missing/ambiguous';if($matches.Count -ne 1){continue};$argument=$matches[0]
    Add-TCallCheck $state ($argument.row[9] -eq $slot -and $argument.row[10] -eq [int]$item.parameter) 'source-slot-to-parameter map changed'
    $type=$null;if($target.Count -eq 1 -and $item.parameter -ge 0 -and $item.parameter -lt $target[0].parameters.Count){$type=$types[[string]$target[0].parameters[$item.parameter]]};Add-TCallCheck $state ($null -ne $type) 'authored parameter type unavailable';if($null -ne $type){Test-TCallMode $Actual $call $argument $item.mode $type $itemSpan $state $facts}
   }
  }else{
   switch($expected.value){
    {$_ -in @('left-to-right','checked-runtime','conditional-right','eager-right')} {
     $operations=@($nodes|Where-Object {$_.row[2] -in @(4,5,6) -and (Test-TCallSpan (Get-TCallSpan $Actual $_.row[0] $_.row[1]) $span)})
     Add-TCallCheck $state ($operations.Count -eq 1) 'execution operation missing/ambiguous';if($operations.Count -ne 1){break};$op=$operations[0];$children=@(Get-TCallChildren $Actual $op $state)
     if($expected.value -eq 'checked-runtime'){Add-TCallCheck $state (($op.row[9] -band 1) -ne 0) 'runtime arithmetic lost its checked operation';$typed=@($facts|Where-Object {$_.pool -ceq $op.pool -and $_.row[2] -eq 1 -and $_.row[0] -eq $op.row[0] -and $_.row[1] -eq $op.row[1]});Add-TCallCheck $state ($typed.Count -eq 1 -and ($typed[0].row[8] -band 128) -ne 0 -and ($typed[0].row[8] -band 1) -eq 0) 'runtime checked expression was folded or lost its check metadata'}
     if($expected.value -in @('conditional-right','eager-right')){$conditional=$expected.value -eq 'conditional-right';Add-TCallCheck $state ($op.row[2] -eq 5 -and $children.Count -eq 2 -and (($op.row[9] -band 2) -ne 0) -eq $conditional) 'right evaluation mode differs'}
     $previous=$null;foreach($child in $children){$childSpan=Get-TCallSpan $Actual $child.row[0] $child.row[1];Add-TCallCheck $state (Test-TCallInside $childSpan $span) 'evaluation child is outside its original expression';if($null -ne $previous){Add-TCallCheck $state ($previous[0] -eq $childSpan[0] -and $previous[2] -le $childSpan[1]) 'execution children reordered/repeated'};$previous=$childSpan}
     if($op.row[2] -eq 5){Add-TCallCheck $state ($children.Count -eq 2) 'binary expression did not evaluate both inputs exactly once'}
    }
    'discard-result' {$call=Get-TCallCallAt $Actual $span $state $facts $nodes;if($null -ne $call){Add-TCallCheck $state ($call.declaration[0] -eq 6 -and $call.fact.row[3] -ne 0 -and ($call.fact.row[8] -band 1) -ne 0 -and ($call.node.row[9] -band 4) -ne 0) 'Function result was not explicitly discarded'}}
    'compile-time-folded' {$known=@($facts|Where-Object {$_.row[2] -eq 1 -and ($_.row[8] -band 1) -ne 0 -and (Test-TCallSpan (Get-TCallSpan $Actual $_.row[0] $_.row[1]) $span)});$leaves=@($nodes|Where-Object {Test-TCallSpan (Get-TCallSpan $Actual $_.row[0] $_.row[1]) $span});Add-TCallCheck $state ($known.Count -eq 1 -and $leaves.Count -eq 1) 'folded expression has no unique typed/materialized constant';if($known.Count -eq 1 -and $leaves.Count -eq 1){Add-TCallCheck $state ($leaves[0].row[2] -in @(1,2) -and $leaves[0].row[6] -eq -1 -and $leaves[0].row[8] -eq 0 -and $leaves[0].row[3] -eq $known[0].row[3] -and $leaves[0].row[4] -eq $known[0].row[4]) 'literal fold retains arithmetic children or changes type/value'}}
    {$_ -in @('storage-before-initializer','storage-survives-failure')} {$ids=@(Get-TCallDeclarationsAt $Actual $span);Add-TCallCheck $state ($ids.Count -eq 1) 'storage declaration missing/ambiguous';if($ids.Count -eq 1){$storage=@($nodes|Where-Object {$_.row[2] -eq 103 -and $_.row[5] -eq $ids[0]});Add-TCallCheck $state ($storage.Count -eq 1 -and ($storage[0].row[9] -band 1) -ne 0) 'neutral storage is not established before initialization';if($expected.value -eq 'storage-survives-failure' -and $storage.Count -eq 1){Add-TCallCheck $state (($storage[0].row[9] -band 2) -ne 0) 'storage is removed after initializer failure'}}}
    'independent-value-copy' {$copies=@($nodes|Where-Object {$_.row[2] -eq 104 -and (Test-TCallSpan (Get-TCallSpan $Actual $_.row[0] $_.row[1]) $span)});Add-TCallCheck $state ($copies.Count -eq 1) 'native value copy missing/ambiguous';if($copies.Count -eq 1){$copy=$copies[0];$children=@(Get-TCallChildren $Actual $copy $state);Add-TCallCheck $state ($copy.row[3] -ge 6 -and $children.Count -eq 1 -and $copy.row[5] -ne $children[0].row[5] -and $children[0].row[2] -eq 3 -and $children[0].row[3] -eq $copy.row[3]) 'copy aliases storage or changes nominal identity';$conversion=@($facts|Where-Object {$_.pool -ceq $copy.pool -and $_.index -eq $copy.row[10] -and $_.row[2] -eq 3});Add-TCallCheck $state ($conversion.Count -eq 1 -and $conversion[0].row[3] -eq $copy.row[3] -and $conversion[0].row[6] -eq $copy.row[3] -and ($conversion[0].row[8] -band 1) -eq 0) 'native copy is not an explicit identity value conversion'}}
    default {Add-TCallCheck $state $false ('unhandled authored evaluation '+$expected.value)}
   }
  }
 }
 return [pscustomobject]@{errors=$state.errors.ToArray();assertions=$state.assertions;handled=$handled}
}
