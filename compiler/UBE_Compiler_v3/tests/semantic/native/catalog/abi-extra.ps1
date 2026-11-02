function Add-CatalogObservationBindings([string]$Raw,$Mapping){
 $adapter=New-Object Text.StringBuilder
 foreach($hook in @(@('TryReadCatalogSyntax','i1','ptr,i32,i32,ptr,ptr',1),@('ReadSyntaxNode','void','ptr,ptr',2),@('TryEncodeUtf8Scalar','i1','i32,ptr,ptr,ptr,ptr,ptr',3))){
  $symbol=Get-FoundationDefinition $Raw $Mapping $hook[0] $hook[1] $hook[2];$body='catalog_observed_'+$symbol.Replace('.','_');$Raw=$Raw.Replace('define '+$hook[1]+' @'+$symbol+'(','define '+$hook[1]+' @'+$body+'(')
  $arguments=@();$parts=$hook[2] -split ',';for($i=0;$i -lt $parts.Count;++$i){$arguments+=$parts[$i]+' %a'+$i}
  [void]$adapter.AppendLine('define '+$hook[1]+' @'+$symbol+'('+($arguments -join ', ')+") {`n call void @catalog_observe(i32 "+$hook[3]+')')
  if($hook[1] -ceq 'void'){[void]$adapter.AppendLine(' call void @'+$body+'('+($arguments -join ', ')+")`n ret void`n}")}
  else{[void]$adapter.AppendLine(' %observed_result = call '+$hook[1]+' @'+$body+'('+($arguments -join ', ')+")`n ret "+$hook[1]+" %observed_result`n}")}
 }
 [void]$adapter.AppendLine('declare void @catalog_observe(i32)')
 return $Raw+"`n"+$adapter.ToString()
}
