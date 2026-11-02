# Test-only ABI mapping from the exact ordered project sources, with checked LLVM signatures.
function Get-SignedIntegerProjectInputs([string]$Project){
 $answer=New-Object Collections.Generic.List[string]
 $seen=@{}
 function Visit-SignedIntegerProject([string]$Path){
  $Path=[IO.Path]::GetFullPath($Path);if($seen.ContainsKey($Path)){return};$seen[$Path]=$true;$answer.Add($Path)
  $text=[IO.File]::ReadAllText($Path);$directory=Split-Path $Path -Parent
  foreach($match in [regex]::Matches($text,'(?m)^Source\s*=\s*"([^"]+)"\s*\r?$')){$answer.Add([IO.Path]::GetFullPath((Join-Path $directory $match.Groups[1].Value)))}
  foreach($match in [regex]::Matches($text,'(?m)^Reference\s*=\s*"([^"]+)"\s*\r?$')){Visit-SignedIntegerProject ([IO.Path]::GetFullPath((Join-Path $directory $match.Groups[1].Value)))}
 }
 Visit-SignedIntegerProject $Project
 return $answer.ToArray()
}
function New-SignedIntegerNativeAdapter([string]$Raw,[string[]]$Inputs){
 $procedures=@{};$ordinal=0;$mapping=@()
 foreach($source in $Inputs|Where-Object {[IO.Path]::GetExtension($_) -ceq '.bas'}){
  $text=[IO.File]::ReadAllText($source)
  foreach($match in [regex]::Matches($text,'(?im)^(?:(?:Public|Private|Friend)\s+)?(?:Intrinsic\s+)?(?:Function|Sub)\s+([A-Za-z_][A-Za-z_0-9]*)\s*\(')){
   $name=$match.Groups[1].Value;$symbol='ube.p'+$ordinal
   if($procedures.ContainsKey($name)){throw "Ambiguous procedure in native mapping: $name"}
   $procedures[$name]=$symbol;$mapping+=@([pscustomobject]@{source=$source;name=$name;symbol=$symbol});++$ordinal
  }
 }
 $adapter=New-Object Text.StringBuilder
 $bindings=@(@('numeric_decode','TryDecodeDecimalInteger','i1','ptr,i32,i32,i1,i64,i64,ptr,ptr'),@('numeric_evaluate','TryEvaluateInteger','i1','i32,i64,i64,i64,i64,ptr,ptr'),@('numeric_compare','CompareIntegers','i32','i64,i64'),@('numeric_read','TryReadDecimalIntegerByte','i1','ptr,i32,ptr'))
 foreach($binding in $bindings){
  $name=$binding[1];if(-not $procedures.ContainsKey($name)){throw "Missing numeric source procedure $name"};$symbol=$procedures[$name]
  $definitions=[regex]::Matches($Raw,'(?m)^define '+$binding[2]+' @'+[regex]::Escape($symbol)+'\(([^\r\n]*)\) \{\r?$')
  if($definitions.Count -ne 1){throw "Missing mapped numeric LLVM definition: $name/$symbol"}
  $actual=(@($definitions[0].Groups[1].Value -split ', '|ForEach-Object {($_ -split ' ')[0]}) -join ',')
  if($actual -cne $binding[3]){throw "Numeric native ABI changed: $name ($actual)"}
  $types=$binding[3] -split ',';$arguments=@();$calls=@()
  for($index=0;$index -lt $types.Count;++$index){$arguments+=($types[$index]+' %a'+$index);$calls+=($types[$index]+' %a'+$index)}
  if($binding[0] -ceq 'numeric_read'){
   $body='numeric_read_body_'+$symbol.Replace('.','_');$Raw=$Raw.Replace('define i1 @'+$symbol+'(','define i1 @'+$body+'(')
   [void]$adapter.AppendLine('declare void @numeric_read_event()')
   [void]$adapter.AppendLine('define i1 @'+$symbol+'('+($arguments -join ', ')+') {')
   [void]$adapter.AppendLine(' call void @numeric_read_event()')
   [void]$adapter.AppendLine(' %result = call i1 @'+$body+'('+($calls -join ', ')+')')
   [void]$adapter.AppendLine(" ret i1 %result`n}")
  }else{
   if($binding[0] -ceq 'numeric_decode'){$arguments[3]='i32 %a3';$calls[3]='i1 %negative'}
   [void]$adapter.AppendLine('define i32 @'+$binding[0]+'('+($arguments -join ', ')+') {')
   if($binding[0] -ceq 'numeric_decode'){[void]$adapter.AppendLine(' %negative = trunc i32 %a3 to i1')}
   [void]$adapter.AppendLine(' %result = call '+$binding[2]+' @'+$symbol+'('+($calls -join ', ')+')')
   if($binding[2] -ceq 'i1'){[void]$adapter.AppendLine(" %status = zext i1 %result to i32`n ret i32 %status`n}")}else{[void]$adapter.AppendLine(" ret i32 %result`n}")}
  }
 }
 if([regex]::Matches($Raw,'(?m)^define i32 @main\(').Count -ne 1){throw 'Native qualification entry changed'}
 $byte='@ube.value.7 = private constant %ube.value.layout { i64 ptrtoint (ptr getelementptr (i8, ptr null, i32 1) to i64), i32 0, i32 0, ptr null, i64 0, ptr null }'
 if([regex]::Matches($Raw,'(?m)^'+[regex]::Escape($byte)+'\r?$').Count -ne 1){throw 'Byte layout descriptor ABI changed'}
 $declaration='ptr, i32, ptr, ptr, ptr'
 if([regex]::Matches($Raw,'(?m)^declare ptr @ube_value_array_element\('+[regex]::Escape($declaration)+'\)\r?$').Count -ne 1){throw 'Managed byte element ABI changed'}
 $Raw=$Raw.Replace('call ptr @ube_value_array_element(','call ptr @numeric_runtime_element(')
 [void]$adapter.AppendLine('declare ptr @numeric_runtime_element('+$declaration+')')
 foreach($width in @('i32','i64')){foreach($operation in @('add','sub','mul','div','mod','neg')){
  $arguments=$width+', '+$width;if($operation -ceq 'neg'){$arguments=$width}
  $symbol='ube_checked_'+$operation+'_'+$width;$replacement='numeric_checked_'+$operation+'_'+$width
  if([regex]::Matches($Raw,'(?m)^declare '+$width+' @'+$symbol+'\('+[regex]::Escape($arguments)+'\)\r?$').Count -ne 1){throw 'Checked machine helper ABI changed'}
  $Raw=$Raw.Replace('call '+$width+' @'+$symbol+'(','call '+$width+' @'+$replacement+'(')
  [void]$adapter.AppendLine('declare '+$width+' @'+$replacement+'('+$arguments+')')
 }}
 [void]$adapter.AppendLine("define i32 @numeric_layout_role(ptr %layout) {`n %byte = icmp eq ptr %layout, @ube.value.7`n %role = zext i1 %byte to i32`n ret i32 %role`n}")
 return [pscustomobject]@{text=$Raw.Replace('define i32 @main(','define i32 @numeric_unused_main(')+"`n"+$adapter.ToString();mapping=$mapping;limits='Exact root and referenced source order determines procedure IDs. Every numeric signature, Byte descriptor, runtime element entry, and twelve checked machine helper declarations is checked before test-only redirection; original procedure bodies remain intact.'}
}
