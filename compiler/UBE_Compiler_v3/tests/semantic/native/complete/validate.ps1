param([string]$Definition=(Join-Path $PSScriptRoot 'complete.json'))
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Numerics
$utf8=New-Object Text.UTF8Encoding($false,$true)
$script:assertions=0
$root=[IO.Path]::GetFullPath($PSScriptRoot)
$sectionNames=@('sources','witnesses','regions','declarations','typeReferences','bindings','expressions','valueNodes','conversions','calls','statements','attributes','options')
function Assert-Fact([bool]$Value,[string]$Message){if(-not $Value){throw $Message};$script:assertions++}
function Fields($Object,[string[]]$Names,[string]$What){
 $actual=@($Object.PSObject.Properties|ForEach-Object Name)
 Assert-Fact ($actual.Count -eq $Names.Count) "$What exact field count"
 foreach($name in $Names){Assert-Fact ($actual -ccontains $name) "$What field $name"}
}
function Index-Records($Records,[string]$What){
 $map=New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
 foreach($record in $Records){Assert-Fact ($record.id -is [string] -and $record.id.Length -gt 0 -and -not $map.ContainsKey($record.id)) "$What unique nonempty identity";$map.Add($record.id,$record)}
 return ,$map
}
function Ref($Map,[string]$Id,[string]$What){Assert-Fact ($Id.Length -gt 0 -and $Map.ContainsKey($Id)) "$What reference $Id";return $Map[$Id]}
function Position([string]$Text,[int]$At){
 $scalar=0;$line=1;$column=1;$i=0
 while($i -lt $At){$value=[char]::ConvertToUtf32($Text,$i);if($value -gt 65535){$i+=2}else{$i++};$scalar++;if($value -eq 10){$line++;$column=1}else{$column++}}
 Assert-Fact ($i -eq $At) 'Witness boundary is a Unicode scalar boundary'
 return [pscustomobject]@{byte=$utf8.GetByteCount($Text.Substring(0,$At));scalar=$scalar;line=$line;column=$column}
}
function Resolve($Witness,$Sources){
 Fields $Witness @('id','source','text','within','occurrence','mode') 'Witness'
 Assert-Fact ($Witness.source -is [int] -and $Witness.source -ge 0 -and $Witness.source -lt $Sources.Count) 'Witness source identity'
 $text=[string]$Sources[$Witness.source].text;$start=0;$length=$text.Length
 if($Witness.within.Length){$start=$text.IndexOf($Witness.within,[StringComparison]::Ordinal);Assert-Fact ($start -ge 0 -and $text.IndexOf($Witness.within,$start+1,[StringComparison]::Ordinal) -lt 0) "Witness unique context $($Witness.id)";$length=$Witness.within.Length}
 Assert-Fact ($Witness.text.Length -gt 0 -and $Witness.occurrence -ge 0 -and $Witness.mode -cin @('span','start','end')) 'Witness text/mode domain'
 $area=$text.Substring($start,$length);$relative=-1;$next=0
 for($i=0;$i -le $Witness.occurrence;++$i){$relative=$area.IndexOf($Witness.text,$next,[StringComparison]::Ordinal);Assert-Fact ($relative -ge 0) "Witness occurrence $($Witness.id)";$next=$relative+1}
 $first=$start+$relative;$last=$first+$Witness.text.Length
 if($Witness.mode -ceq 'start'){$last=$first};if($Witness.mode -ceq 'end'){$first=$last}
 return [pscustomobject]@{id=$Witness.id;source=$Witness.source;first=(Position $text $first);last=(Position $text $last);text=$text.Substring($first,$last-$first)}
}
function Constant-Fits([string]$Type,[string]$Value){
 if($Value -eq ''){return}
 if($Type -ceq 'Boolean'){Assert-Fact ($Value -cin @('true','false')) 'Boolean constant is semantic truth, not exposed representation';return}
 $ranges=@{Byte=@('0','255');Integer=@('-32768','32767');Long=@('-2147483648','2147483647');LongLong=@('-9223372036854775808','9223372036854775807')}
 Assert-Fact ($ranges.ContainsKey($Type)) 'Only supported integer/Boolean constant payloads'
 $number=[System.Numerics.BigInteger]::Zero
 Assert-Fact ([System.Numerics.BigInteger]::TryParse($Value,[Globalization.NumberStyles]::AllowLeadingSign,[Globalization.CultureInfo]::InvariantCulture,[ref]$number)) 'Integer constant is an authored exact decimal'
 $minimum=[System.Numerics.BigInteger]::Parse($ranges[$Type][0],[Globalization.CultureInfo]::InvariantCulture);$maximum=[System.Numerics.BigInteger]::Parse($ranges[$Type][1],[Globalization.CultureInfo]::InvariantCulture)
 Assert-Fact ($number -ge $minimum -and $number -le $maximum) 'Integer constant fits its claimed selected type'
}
function List-Equal($Left,$Right,[string]$What){Assert-Fact ($Left.Count -eq $Right.Count) "$What count";for($i=0;$i -lt $Left.Count;++$i){Assert-Fact ([string]$Left[$i] -ceq [string]$Right[$i]) "$What order"}}
function Validate-Project($Case,$AllCases){
 Fields $Case (@('id','outcome','packages','entryPoint','failure','expectedCounts')+$sectionNames) 'Project'
 Assert-Fact ($Case.outcome -cin @('checked','error')) 'Project outcome domain'
 for($i=0;$i -lt $Case.sources.Count;++$i){$source=$Case.sources[$i];Fields $source @('id','package','module','file','text') 'Source';Assert-Fact ($source.id -eq $i) 'Canonical source order';Assert-Fact ($source.package -cin @('app','ubecore') -and $source.module.Length -gt 0) 'Source package/module';$file=[IO.Path]::GetFullPath((Join-Path $root $source.file));Assert-Fact ($file.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) 'Fixture source remains inside its directory';Assert-Fact ([IO.File]::ReadAllText($file,$utf8) -ceq $source.text) 'Original fixture source bytes decode exactly';Assert-Fact ($source.text.EndsWith("`n") -and -not $source.text.Contains("`r")) 'Original LF text remains explicit'}
 $resolved=New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
 foreach($witness in $Case.witnesses){Assert-Fact (-not $resolved.ContainsKey($witness.id)) 'Unique witness identity';$resolved.Add($witness.id,(Resolve $witness $Case.sources))}
 foreach($count in $Case.expectedCounts.PSObject.Properties){Assert-Fact ($Case.($count.Name).Count -eq $count.Value) "Hand-authored complete $($count.Name) count"}
 if($Case.outcome -ceq 'error'){
  Assert-Fact ($null -eq $Case.entryPoint -and $null -ne $Case.failure) 'Rejected result has only its failure disposition'
  Fields $Case.failure @('class','category','at','related','preserveResultFixture','newResult','newDeclarationsPublished','newFactsPublished','oldOwnersPreserved') 'Failure'
  Assert-Fact ($Case.failure.class -ceq 'DuplicateName' -and $Case.failure.category -ceq 'declaration') 'Independent rejected-case diagnostic class/category'
  $primary=Ref $resolved $Case.failure.at 'Failure witness';Assert-Fact ($Case.failure.related.Count -eq 1) 'DuplicateName has one earlier declaration relation'
  $related=Ref $resolved $Case.failure.related[0] 'Related witness';Assert-Fact ($primary.source -eq $related.source -and $primary.first.byte -gt $related.first.byte) 'Duplicate anchors the later name and relates the first'
  Assert-Fact ($null -eq $Case.failure.newResult -and $Case.failure.newDeclarationsPublished -eq 0 -and $Case.failure.newFactsPublished -eq 0 -and $Case.failure.oldOwnersPreserved) 'Rejection publishes no partial semantic result'
  $old=Ref $AllCases $Case.failure.preserveResultFixture 'Preserved fixture';Assert-Fact ($old.outcome -ceq 'checked' -and $old.sources[0].text -cne $Case.sources[0].text) 'Failure harness must seed a different complete graph and owners'
  return [pscustomobject]@{id=$Case.id;outcome=$Case.outcome;witnesses=@($resolved.Values);counts=$Case.expectedCounts}
 }
 Assert-Fact ($null -eq $Case.failure -and $null -ne $Case.entryPoint) 'Checked result has no diagnostic/deferred result'
 $decl=Index-Records $Case.declarations 'Declaration';$regions=Index-Records $Case.regions 'Region';$expr=Index-Records $Case.expressions 'Expression';$values=Index-Records $Case.valueNodes 'Value node';$bindings=Index-Records $Case.bindings 'Binding';$conversions=Index-Records $Case.conversions 'Conversion';$statements=Index-Records $Case.statements 'Statement';$calls=Index-Records $Case.calls 'Call'
 $types=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal);foreach($type in @('Void','Boolean','Byte','Integer','Long','LongLong')){$null=$types.Add($type)}
 foreach($item in $Case.declarations){if($item.kind -ceq 'native-type'){$null=$types.Add($item.type)}}
 $details=@{
  module=@('region','source','privateModule','headerAt');constant=@('writtenVisibility','initializer','valueRoot','constant','typeForm');
  function=@('writtenVisibility','parameters','region','resultNeutral','body','terminator','primitive','typeForm');sub=@('writtenVisibility','parameters','region','resultNeutral','body','terminator','primitive','typeForm');
  parameter=@('passing','writtenPassing','optional','default','defaultValue','typeForm','writable');local=@('initializer','valueRoot','neutral','establishedBeforeInitializer','survivesRuntimeInitializerFailure','typeForm','writable');
  'native-type'=@('writtenVisibility','representation','terminator','pack','unpack')
 }
 foreach($item in $Case.declarations){
  Fields $item @('id','kind','name','canonical','scope','type','visibility','nameAt','wholeAt','details') 'Declaration';Assert-Fact ($details.ContainsKey($item.kind) -and $types.Contains($item.type)) 'Declaration kind/type domain';Fields $item.details $details[$item.kind] 'Declaration details'
  $name=Ref $resolved $item.nameAt 'Declaration name';$whole=Ref $resolved $item.wholeAt 'Declaration span';Assert-Fact ($name.source -eq $whole.source -and $name.first.byte -ge $whole.first.byte -and $name.last.byte -le $whole.last.byte) 'Declaration name belongs to its full original span'
  if($item.kind -ceq 'module'){Assert-Fact ($item.scope -ceq ('package:'+$Case.sources[$name.source].package) -and $item.details.source -eq $name.source) 'Module uses admitted package/source identity';$null=Ref $resolved $item.details.headerAt 'Module header'}else{$null=Ref $regions $item.scope 'Declaration region'}
  if($item.kind -cin @('function','sub')){
   $null=Ref $regions $item.details.region 'Procedure region';$null=Ref $resolved $item.details.terminator 'Written terminator'
   foreach($parameter in $item.details.parameters){$parameterDecl=Ref $decl $parameter 'Parameter';Assert-Fact ($parameterDecl.kind -ceq 'parameter' -and $parameterDecl.scope -ceq $item.details.region) 'Signature parameter belongs to its procedure'}
   foreach($statement in $item.details.body){$null=Ref $statements $statement 'Body statement'}
   if($item.kind -ceq 'sub'){Assert-Fact ($item.type -ceq 'Void' -and $item.details.typeForm -ceq 'none') 'Sub has no scalar result type'}
  }
  if($item.kind -ceq 'parameter'){
   Assert-Fact ($item.details.passing -cin @('ByRef','ByVal') -and $item.details.writtenPassing -cin @('ByRef','ByVal','omitted') -and $item.details.writable) 'Parameter mode/storage contract'
   if($item.details.optional){$null=Ref $expr $item.details.default 'Optional default expression';$null=Ref $values $item.details.defaultValue 'Optional default value'}else{Assert-Fact ($item.details.default -ceq '' -and $item.details.defaultValue -ceq '') 'Required parameter has no default'}
  }
  if($item.kind -ceq 'local'){Assert-Fact ($item.details.establishedBeforeInitializer -and $item.details.survivesRuntimeInitializerFailure -and $item.details.writable) 'Local storage precedes and survives runtime initializer failure';$null=Ref $expr $item.details.initializer 'Initializer expression';$null=Ref $values $item.details.valueRoot 'Initializer value'}
  if($item.kind -ceq 'constant'){$null=Ref $expr $item.details.initializer 'Constant expression';$null=Ref $values $item.details.valueRoot 'Constant value';Constant-Fits $item.type $item.details.constant}
  if($item.kind -ceq 'native-type'){Assert-Fact ($item.type.StartsWith('native:') -and $item.details.representation -cin @('Byte','Integer','Long')) 'Nominal native representation';$null=Ref $decl $item.details.pack 'Explicit Pack declaration';$null=Ref $decl $item.details.unpack 'Explicit Unpack declaration';$null=Ref $resolved $item.details.terminator 'Native terminator'}
 }
 foreach($region in $Case.regions){Fields $region @('id','kind','owner','members','resultTarget') 'Region';$owner=Ref $decl $region.owner 'Region owner';Assert-Fact ($region.kind -cin @('module','procedure')) 'Region kind';$expected=@($Case.declarations|Where-Object {$_.scope -ceq $region.id}|ForEach-Object id);List-Equal @($region.members) $expected 'Complete region membership';if($region.resultTarget.Length){Assert-Fact ($region.resultTarget -ceq $owner.id -and $owner.kind -ceq 'function') 'Function result is special storage, not a duplicate member'}}
 foreach($reference in $Case.typeReferences){Fields $reference @('id','at','nameAt','owner','role','type','moduleBinding') 'Type reference';$site=Ref $resolved $reference.at 'Type span';$name=Ref $resolved $reference.nameAt 'Type name';$owner=Ref $decl $reference.owner 'Typed declaration';Assert-Fact ($types.Contains($reference.type) -and $name.source -eq $site.source -and $name.first.byte -ge $site.first.byte -and $name.last.byte -le $site.last.byte) 'Resolved type/name spans';if($reference.role -ceq 'representation'){Assert-Fact ($owner.kind -ceq 'native-type' -and $owner.details.representation -ceq $reference.type) 'Representation reference agrees with declaration'}else{Assert-Fact ($owner.type -ceq $reference.type) 'Type reference agrees with selected declaration type'};if($reference.moduleBinding.Length){$module=Ref $bindings $reference.moduleBinding 'Type qualifier binding';Assert-Fact ($module.role -ceq 'type-module-qualifier') 'Qualified type retains its module binding'}}
 foreach($binding in $Case.bindings){
  Fields $binding @('id','at','target','role','level') 'Binding';$site=Ref $resolved $binding.at 'Binding span';$target=Ref $decl $binding.target 'Binding declaration'
  $sourceProcedures=@($Case.declarations|Where-Object {$_.kind -cin @('function','sub')}|Where-Object {$span=$resolved[$_.wholeAt];$span.source -eq $site.source -and $span.first.byte -le $site.first.byte -and $span.last.byte -ge $site.last.byte})
  if($binding.level -ceq 'procedure'){Assert-Fact ($sourceProcedures.Count -eq 1 -and $target.scope -ceq $sourceProcedures[0].details.region) 'Procedure binding stays in its region'}
  if($binding.role -cin @('read','argument-storage','assignment-target')){Assert-Fact ($target.kind -cin @('local','parameter')) 'Writable/value binding target category'}
  if($binding.role -ceq 'constant-read'){Assert-Fact ($target.kind -ceq 'constant') 'Constant-use binding category'}
  if($binding.role -ceq 'result-storage'){Assert-Fact ($target.kind -ceq 'function' -and $sourceProcedures.Count -eq 1 -and $sourceProcedures[0].id -ceq $target.id) 'Result assignment selects current Function storage'}
  if($binding.role -ceq 'call-target'){Assert-Fact ($target.kind -cin @('function','sub')) 'Call target category'}
  if($binding.role -ceq 'named-parameter'){Assert-Fact ($target.kind -ceq 'parameter' -and $binding.level -ceq 'signature') 'Named argument selects a signature parameter'}
  if($binding.role -ceq 'attribute-target'){Assert-Fact ($sourceProcedures.Count -eq 1 -and $sourceProcedures[0].id -ceq $target.id) 'Primitive attribute targets its enclosing declaration'}
  if($binding.level -cin @('direct-reference','qualified-module')){Assert-Fact ($target.visibility -ceq 'public') 'Cross-reference binding enforces Public accessibility'}
 }
 foreach($expression in $Case.expressions){
  Fields $expression @('id','at','kind','type','integerContext','selection','operands','constant','binding','evaluation','folding') 'Expression';$null=Ref $resolved $expression.at 'Expression span';Assert-Fact ($types.Contains($expression.type)) 'Expression type domain';Constant-Fits $expression.type $expression.constant
  foreach($operand in $expression.operands){$child=Ref $expr $operand 'Expression';$parentSpan=$resolved[$expression.at];$childSpan=$resolved[$child.at];Assert-Fact ($childSpan.source -eq $parentSpan.source -and $childSpan.first.byte -ge $parentSpan.first.byte -and $childSpan.last.byte -le $parentSpan.last.byte -and $childSpan.last.byte-$childSpan.first.byte -lt $parentSpan.last.byte-$parentSpan.first.byte) "Source expression children are strictly contained, so the graph is acyclic: $($Case.id) $($expression.id) -> $($child.id)"}
  if($expression.binding.Length){$binding=Ref $bindings $expression.binding 'Expression binding';$target=Ref $decl $binding.target 'Expression target';Assert-Fact ($target.type -ceq $expression.type) 'Bound expression retains declared type'}
  if($expression.kind -ceq 'literal'){Assert-Fact ($expression.operands.Count -eq 0 -and $expression.constant.Length -gt 0) 'Literal has an authored exact value';if($expression.selection -ceq 'destination'){Assert-Fact ($expression.type -ceq $expression.integerContext) 'Destination literal type matches its context'}}
  if($expression.kind -ceq 'group'){Assert-Fact ($expression.operands.Count -eq 1 -and $expression.type -ceq $expr[$expression.operands[0]].type) 'Original Group preserves its typed operand'}
 }
 foreach($node in $Case.valueNodes){
  Fields $node @('id','origin','kind','type','operands','operation','binding','constant','checked','evaluation') 'Bound value';$origin=Ref $expr $node.origin 'Bound value origin';Assert-Fact ($node.type -ceq $origin.type) 'Bound value retains selected expression type';Constant-Fits $node.type $node.constant
  Assert-Fact ($node.kind -cin @('constant','read','storage','binary','call')) 'Bound value kind domain'
  foreach($operand in $node.operands){$child=Ref $values $operand 'Bound operand';$parentSpan=$resolved[$origin.at];$childSpan=$resolved[$expr[$child.origin].at];Assert-Fact ($childSpan.source -eq $parentSpan.source -and $childSpan.first.byte -ge $parentSpan.first.byte -and $childSpan.last.byte -le $parentSpan.last.byte -and $childSpan.last.byte-$childSpan.first.byte -lt $parentSpan.last.byte-$parentSpan.first.byte) 'Evaluated bound children are strictly contained, so the graph is acyclic'}
  if($node.binding.Length){$null=Ref $decl $node.binding 'Bound declaration'}
  if($node.kind -ceq 'constant'){Assert-Fact ($node.operands.Count -eq 0 -and $node.constant.Length -gt 0 -and $node.constant -ceq $origin.constant) 'Bound constant value matches source annotation'}
  if($origin.folding -ceq 'required-literal-arithmetic'){Assert-Fact ($node.kind -ceq 'constant' -and $node.operands.Count -eq 0 -and -not $node.checked) 'Required arithmetic is a bound constant'}
 }
 foreach($expression in $Case.expressions|Where-Object {$_.folding -ceq 'required-literal-arithmetic'}){$folded=@($Case.valueNodes|Where-Object {$_.origin -ceq $expression.id});Assert-Fact ($folded.Count -eq 1 -and $folded[0].kind -ceq 'constant' -and $folded[0].operands.Count -eq 0) 'Every required folded subtree has exactly one actual bound constant'}
 foreach($conversion in $Case.conversions){Fields $conversion @('id','at','placement','expression','target','from','to','mode','constantResult') 'Conversion';$null=Ref $resolved $conversion.at 'Conversion span';$expression=Ref $expr $conversion.expression 'Converted expression';Assert-Fact ($expression.type -ceq $conversion.from -and $types.Contains($conversion.to)) 'Conversion source/destination types';if($conversion.mode -ceq 'identity'){Assert-Fact ($conversion.from -ceq $conversion.to) 'Identity conversion preserves exact type'}else{Assert-Fact ($conversion.mode -ceq 'checked' -and $conversion.from -cne $conversion.to -and -not $conversion.from.StartsWith('native:') -and -not $conversion.to.StartsWith('native:')) 'Only supported checked numeric conversion'};Constant-Fits $conversion.to $conversion.constantResult;Assert-Fact ($decl.ContainsKey($conversion.target) -or $expr.ContainsKey($conversion.target) -or $statements.ContainsKey($conversion.target)) 'Conversion target reference'}
 foreach($call in $Case.calls){
  Fields $call @('id','at','expression','target','resultType','valueRoot','form','primitive','nativeType','moduleBinding','sourceSlotCount','evaluationOrder','arguments','parameterMap','discardResult') 'Call';$null=Ref $resolved $call.at 'Call span';$expression=Ref $expr $call.expression 'Call expression';$target=Ref $decl $call.target 'Callable declaration';$value=Ref $values $call.valueRoot 'Call bound value';Assert-Fact ($target.kind -cin @('function','sub') -and $target.type -ceq $call.resultType -and $expression.type -ceq $call.resultType -and $value.kind -ceq 'call' -and $value.binding -ceq $target.id -and $value.origin -ceq $expression.id) 'Complete call target/result identity'
  if($call.moduleBinding.Length){$module=Ref $bindings $call.moduleBinding 'Call qualifier binding';Assert-Fact ($module.role -ceq 'call-module-qualifier' -and $decl[$module.target].kind -ceq 'module' -and $regions[$target.scope].owner -ceq $module.target) 'Qualified call retains its exact module binding'}
  Assert-Fact ($call.arguments.Count -eq $target.details.parameters.Count -and $call.parameterMap.Count -eq $target.details.parameters.Count) 'Every signature parameter has one argument association'
  $seen=New-Object 'System.Collections.Generic.HashSet[int]';$written=New-Object 'System.Collections.Generic.List[int]'
  foreach($argument in $call.arguments){
   Fields $argument @('slot','at','nameAt','expression','value','parameter','parameterIndex','mode','conversion','defaultExpression','freshTemporary','discardWrites','origin') 'Call argument';$null=Ref $resolved $argument.at 'Argument span';$parameter=Ref $decl $argument.parameter 'Argument parameter';$null=Ref $values $argument.value 'Argument value';$conversion=Ref $conversions $argument.conversion 'Argument conversion';Assert-Fact ($argument.parameterIndex -ge 0 -and $argument.parameterIndex -lt $target.details.parameters.Count -and $target.details.parameters[$argument.parameterIndex] -ceq $parameter.id -and $seen.Add($argument.parameterIndex)) 'Exact unique source-to-parameter association';Assert-Fact ($call.parameterMap[$argument.parameterIndex] -eq $argument.slot) 'Parameter map agrees with source slots';Assert-Fact ($conversion.target -ceq $parameter.id -and $conversion.to -ceq $parameter.type) 'Argument conversion selects its own parameter context'
   if($argument.origin -ceq 'written'){
    Assert-Fact ($argument.slot -ge 0 -and $argument.slot -lt $call.sourceSlotCount) 'Written source-slot domain';$written.Add($argument.slot);$argExpr=Ref $expr $argument.expression 'Written argument expression';Assert-Fact ($argument.defaultExpression -ceq '') 'Written argument is not a default'
    if($argument.mode -ceq 'alias'){Assert-Fact ($parameter.details.passing -ceq 'ByRef' -and $argExpr.kind -ceq 'name' -and $argExpr.type -ceq $parameter.type -and -not $argument.freshTemporary -and -not $argument.discardWrites) 'Direct ByRef aliases writable exact-type storage'}
    elseif($argument.mode -ceq 'temporary'){Assert-Fact ($parameter.details.passing -ceq 'ByRef' -and $argExpr.kind -ceq 'group' -and $argument.freshTemporary -and $argument.discardWrites) 'Temporary requires original Group and discarded writes'}
    else{Assert-Fact ($argument.mode -ceq 'value' -and $parameter.details.passing -ceq 'ByVal') 'ByVal written argument mode'}
    if($argument.nameAt.Length){$site=Ref $resolved $argument.nameAt 'Named argument name';$matching=@($Case.bindings|Where-Object {$_.at -ceq $argument.nameAt -and $_.target -ceq $parameter.id -and $_.role -ceq 'named-parameter'});Assert-Fact ($matching.Count -eq 1) 'Named argument has its exact parameter binding'}
   }else{
    Assert-Fact ($argument.origin -cin @('missing','omitted') -and $parameter.details.optional -and $argument.expression -ceq '' -and $argument.defaultExpression -ceq $parameter.details.default) 'Missing/omitted optional uses declared constant default'
    if($argument.origin -ceq 'missing'){Assert-Fact ($argument.slot -eq -1) 'Missing optional has no written slot'}else{Assert-Fact ($argument.slot -ge 0 -and $argument.slot -lt $call.sourceSlotCount -and $resolved[$argument.at].first.byte -eq $resolved[$argument.at].last.byte) 'Omitted optional retains a written zero-width slot'}
    if($parameter.details.passing -ceq 'ByRef'){Assert-Fact ($argument.mode -ceq 'default-temporary' -and $argument.freshTemporary -and $argument.discardWrites) 'Omitted ByRef has a fresh initialized temporary'}else{Assert-Fact ($argument.mode -ceq 'default-value' -and -not $argument.freshTemporary) 'Missing ByVal supplies default value'}
   }
  }
  $ordered=@($written.ToArray()|Sort-Object);List-Equal @($call.evaluationOrder) $ordered 'Source evaluation order'
  if($call.primitive.Length){Assert-Fact ($target.details.primitive -ceq $call.primitive -and $call.nativeType.StartsWith('native:')) 'Primitive meaning comes from explicit declaration metadata'}
 }
 $statementVisited=New-Object 'System.Collections.Generic.HashSet[string]';$statementPending=New-Object 'System.Collections.Generic.Stack[string]'
 foreach($procedure in $Case.declarations|Where-Object {$_.kind -cin @('function','sub')}){foreach($statement in $procedure.details.body){$statementPending.Push($statement)}}
 while($statementPending.Count){$id=$statementPending.Pop();Assert-Fact ($statementVisited.Add($id)) 'Every statement is owned exactly once';$statement=Ref $statements $id 'Statement';Fields $statement @('id','at','kind','scope','details') 'Statement';$site=Ref $resolved $statement.at 'Statement span';$null=Ref $regions $statement.scope 'Statement region';$owners=@($Case.declarations|Where-Object {$_.kind -cin @('function','sub')}|Where-Object {$span=$resolved[$_.wholeAt];$span.source -eq $site.source -and $span.first.byte -le $site.first.byte -and $span.last.byte -ge $site.last.byte});Assert-Fact ($owners.Count -eq 1 -and $statement.scope -ceq $owners[0].details.region) 'If/While do not create a different procedure region'
  foreach($property in $statement.details.PSObject.Properties){switch($property.Name){
   {$_ -cin @('expression','condition','establishNeutralBefore')}{$null=Ref $expr $property.Value 'Statement expression'}
   value{$null=Ref $values $property.Value 'Statement value'}
   conversion{$null=Ref $conversions $property.Value 'Statement conversion'}
   {$_ -cin @('declaration','target','procedure')}{$null=Ref $decl $property.Value 'Statement declaration'}
   targetBinding{$null=Ref $bindings $property.Value 'Assignment binding'}
   call{$null=Ref $calls $property.Value 'Statement call'}
   {$_ -cin @('then','else','body')}{foreach($child in $property.Value){$statementPending.Push($child)}}
   loop{$loop=Ref $statements $property.Value 'Exit loop';Assert-Fact ($loop.kind -ceq 'while' -and $loop.scope -ceq $statement.scope) 'Exit While identifies its lexical loop'}
   writtenKind{Assert-Fact ($property.Value -cin @('While','Sub','Function')) 'Exit written-kind domain'}
   copySemantics{Assert-Fact ($property.Value -ceq 'independent-value-copy') 'Native copies retain semantic value independence'}
   default{throw "Unknown statement semantic field $($property.Name)"}
  }}
 }
 Assert-Fact ($statementVisited.Count -eq $Case.statements.Count) 'All statements are reachable from exactly one body'
 $valueRoots=New-Object 'System.Collections.Generic.List[string]'
 foreach($item in $Case.declarations){foreach($field in @('valueRoot','defaultValue')){if($item.details.PSObject.Properties.Name -ccontains $field -and $item.details.$field.Length){$valueRoots.Add($item.details.$field)}}}
 foreach($statement in $Case.statements){if($statement.details.PSObject.Properties.Name -ccontains 'value'){$valueRoots.Add($statement.details.value)}}
 foreach($call in $Case.calls){$valueRoots.Add($call.valueRoot);foreach($argument in $call.arguments){$valueRoots.Add($argument.value)}}
 $live=New-Object 'System.Collections.Generic.HashSet[string]';$pending=New-Object 'System.Collections.Generic.Stack[string]';foreach($id in $valueRoots){$pending.Push($id)}
 while($pending.Count){$id=$pending.Pop();if($live.Add($id)){$value=Ref $values $id 'Value root';foreach($child in $value.operands){$pending.Push($child)}}}
 Assert-Fact ($live.Count -eq $Case.valueNodes.Count) 'All value nodes are reachable'
 $expressionRoots=New-Object 'System.Collections.Generic.List[string]'
 foreach($item in $Case.declarations){foreach($field in @('initializer','default')){if($item.details.PSObject.Properties.Name -ccontains $field -and $item.details.$field.Length){$expressionRoots.Add($item.details.$field)}}}
 foreach($statement in $Case.statements){foreach($field in @('expression','condition')){if($statement.details.PSObject.Properties.Name -ccontains $field){$expressionRoots.Add($statement.details.$field)}}}
 foreach($call in $Case.calls){$expressionRoots.Add($call.expression);foreach($argument in $call.arguments){if($argument.expression.Length){$expressionRoots.Add($argument.expression)};if($argument.defaultExpression.Length){$expressionRoots.Add($argument.defaultExpression)}}}
 $expressionLive=New-Object 'System.Collections.Generic.HashSet[string]';$expressionPending=New-Object 'System.Collections.Generic.Stack[string]';foreach($id in $expressionRoots){$expressionPending.Push($id)}
 while($expressionPending.Count){$id=$expressionPending.Pop();if($expressionLive.Add($id)){$expression=Ref $expr $id 'Source expression root';foreach($child in $expression.operands){$expressionPending.Push($child)}}}
 Assert-Fact ($expressionLive.Count -eq $Case.expressions.Count) 'All source expression annotations are reachable'
 $bindingUses=New-Object 'System.Collections.Generic.HashSet[string]'
 foreach($expression in $Case.expressions){if($expression.binding.Length){$null=$bindingUses.Add($expression.binding)}}
 foreach($statement in $Case.statements){if($statement.details.PSObject.Properties.Name -ccontains 'targetBinding'){$null=$bindingUses.Add($statement.details.targetBinding)}}
 foreach($type in $Case.typeReferences){if($type.moduleBinding.Length){$null=$bindingUses.Add($type.moduleBinding)}}
 foreach($call in $Case.calls){if($call.moduleBinding.Length){$null=$bindingUses.Add($call.moduleBinding)};foreach($argument in $call.arguments){if($argument.nameAt.Length){foreach($binding in $Case.bindings|Where-Object {$_.at -ceq $argument.nameAt -and $_.target -ceq $argument.parameter -and $_.role -ceq 'named-parameter'}){$null=$bindingUses.Add($binding.id)}}}}
 foreach($attribute in $Case.attributes|Where-Object {$_.name -ceq 'UBE_Primitive'}){$span=$resolved[$attribute.at];$targets=@($Case.bindings|Where-Object {$_.target -ceq $attribute.target -and $_.role -ceq 'attribute-target'}|Where-Object {$at=$resolved[$_.at];$at.source -eq $span.source -and $at.first.byte -ge $span.first.byte -and $at.last.byte -le $span.last.byte});Assert-Fact ($targets.Count -eq 1) 'Every primitive metadata target has exactly one retained binding';$null=$bindingUses.Add($targets[0].id)}
 Assert-Fact ($bindingUses.Count -eq $Case.bindings.Count) 'All binding records are used, including qualifiers and metadata'
 foreach($attribute in $Case.attributes){Fields $attribute @('id','at','target','name','value','valueAt') 'Attribute';$null=Ref $resolved $attribute.at 'Attribute span';$null=Ref $resolved $attribute.valueAt 'Attribute value span';$target=Ref $decl $attribute.target 'Attribute target';Assert-Fact ($attribute.name -cin @('UBE_Name','UBE_Primitive')) 'Known metadata domain';if($attribute.name -ceq 'UBE_Primitive'){Assert-Fact ($target.details.primitive -ceq $attribute.value) 'Explicit primitive binding agrees with declaration'}}
 foreach($option in $Case.options){Fields $option @('id','at','kind','value') 'Option';$null=Ref $resolved $option.at 'Option span';Assert-Fact (($option.kind -ceq 'Explicit' -and $option.value -ceq 'On') -or ($option.kind -ceq 'Compare' -and $option.value -ceq 'Binary') -or ($option.kind -ceq 'Base' -and $option.value -ceq '0')) 'Authored option semantic value'}
 Fields $Case.entryPoint @('declaration','kind','resultType','parameterCount','package') 'Entry point';$entry=Ref $decl $Case.entryPoint.declaration 'Entry declaration';Assert-Fact ($entry.visibility -ceq 'public' -and $entry.name -ceq 'Main' -and $entry.details.parameters.Count -eq 0 -and $Case.entryPoint.parameterCount -eq 0 -and $Case.entryPoint.package -ceq 'app' -and (($entry.kind -ceq 'function' -and $entry.type -ceq 'Long' -and $Case.entryPoint.kind -ceq 'Function') -or ($entry.kind -ceq 'sub' -and $entry.type -ceq 'Void' -and $Case.entryPoint.kind -ceq 'Sub'))) 'Exactly selected valid root entry signature'
 return [pscustomobject]@{id=$Case.id;outcome=$Case.outcome;witnesses=@($resolved.Values);counts=$Case.expectedCounts}
}

$data=[IO.File]::ReadAllText($Definition,$utf8)|ConvertFrom-Json
Fields $data @('schema','definitionOnly','semanticImplemented','builtinTypes','projects') 'Definition'
Assert-Fact ($data.schema -ceq 'ube-complete-semantic-oracles-draft-1' -and $data.definitionOnly -and -not $data.semanticImplemented) 'Definition-only scope is explicit'
List-Equal @($data.builtinTypes) @('Void','Boolean','Byte','Integer','Long','LongLong') 'Bounded builtin type universe'
Assert-Fact ($data.projects.Count -eq 4) 'Four independently authored integration fixtures'
$cases=Index-Records $data.projects 'Project';$resolvedCases=@();foreach($case in $data.projects){$resolvedCases+=@(Validate-Project $case $cases)}
$positiveAssertions=$script:assertions
$controls=@(
 @{name='binding-region';fragment='Procedure binding stays';change={param($x)$x.projects[0].bindings[1].target='self'}},
 @{name='literal-type';fragment='Destination literal type';change={param($x)$x.projects[0].expressions[5].type='Long'}},
 @{name='constant-value';fragment='Bound constant value matches';change={param($x)$x.projects[0].valueNodes[4].constant='30001'}},
 @{name='ByRef-group';fragment='Temporary requires original Group';change={param($x)$x.projects[2].calls[0].arguments[0].mode='temporary';$x.projects[2].calls[0].arguments[0].freshTemporary=$true;$x.projects[2].calls[0].arguments[0].discardWrites=$true}},
 @{name='parameter-map';fragment='Parameter map';change={param($x)$x.projects[2].calls[1].parameterMap=@(0,1)}},
 @{name='evaluation-order';fragment='Source evaluation order';change={param($x)$x.projects[2].calls[1].evaluationOrder=@(1,0)}},
 @{name='extra-value';fragment='Hand-authored complete valueNodes count';change={param($x)$extra=($x.projects[0].valueNodes[0]|ConvertTo-Json -Depth 10)|ConvertFrom-Json;$extra.id='v.extra';$x.projects[0].valueNodes+=@($extra)}},
 @{name='missing-expression';fragment='Hand-authored complete expressions count';change={param($x)$x.projects[0].expressions=@($x.projects[0].expressions|Where-Object {$_.id -cne 'small.right'})}},
 @{name='folded-operation';fragment='Required arithmetic is a bound constant';change={param($x)$x.projects[0].valueNodes[4].kind='binary';$x.projects[0].valueNodes[4].operation='-';$x.projects[0].valueNodes[4].operands=@()}},
 @{name='conversion';fragment='Identity conversion';change={param($x)$x.projects[0].conversions[6].mode='identity'}},
 @{name='span';fragment='Witness occurrence';change={param($x)($x.projects[0].witnesses|Where-Object {$_.id -ceq 'small-right'}).occurrence=1}},
 @{name='source-order';fragment='Canonical source order';change={param($x)$x.projects[1].sources=@($x.projects[1].sources[1],$x.projects[1].sources[0])}},
 @{name='related-span';fragment='one earlier declaration';change={param($x)$x.projects[3].failure.related=@('first-name','duplicate-name')}}
)
$rejected=@()
foreach($control in $controls){$copy=($data|ConvertTo-Json -Depth 80)|ConvertFrom-Json;& $control.change $copy;$copyMap=Index-Records $copy.projects 'Mutated project';$reason='';try{foreach($case in $copy.projects){$null=Validate-Project $case $copyMap}}catch{$reason=$_.Exception.Message};Assert-Fact ($reason.Contains($control.fragment)) "Negative control $($control.name) must reach its intended guard, got: $reason";$rejected+=@([pscustomobject]@{name=$control.name;reason=$reason;rejected=$true})}
$directory=Split-Path $Definition -Parent
$report=[ordered]@{schema='ube-complete-semantic-definition-check-1';success=$true;definitionOnly=$true;semanticImplemented=$false;positiveAssertions=$positiveAssertions;negativeControls=$rejected;projects=$resolvedCases;limits='Source anchors, exact schemas, authored inventory counts, reference/type/call/fold consistency and corruption controls only. This does not execute UBE, derive expression answers, prove semantic completeness from a parser, qualify a checker, or establish runtime behavior.'}
[IO.File]::WriteAllText((Join-Path $directory 'resolved.json'),($report|ConvertTo-Json -Depth 80)+"`n",$utf8)
Write-Output "PASS complete definition only: $positiveAssertions assertions; $($controls.Count) intended corruption guards. Evidence: $(Join-Path $directory 'resolved.json')"
