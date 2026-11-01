# Test oracle: deletion is legal only for a slot with no actual value/address use.
function Get-ValueSlots([string]$Body,[string]$Kind){
 return @([regex]::Matches($Body,('(?m)^  %'+$Kind+'\.(\d+) = alloca [^\r\n]+'))|ForEach-Object {$_.Groups[1].Value})
}
function Remove-UnusedValueSlots([string]$Body,[string[]]$Removed){
 $drop=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
 foreach($id in $Removed){
  foreach($kind in @('value','scratch')){
   $slot='%'+$kind+'.'+$id;$escaped=[regex]::Escape($slot)
   $uses=@($Body -split "`n"|Where-Object {$_ -match ($escaped+'(?![A-Za-z0-9_.])')})
   if(@($uses|Where-Object {$_ -match ('^  '+$escaped+' = alloca ')}).Count -ne 1){throw 'Missing matched value/scratch allocation'}
   foreach($line in $uses){
    if($line -match ('^  '+$escaped+' = alloca ') -or $line -match ('^  store .+ zeroinitializer, ptr '+$escaped+'(?:, align \d+)?$') -or ($kind -ceq 'value' -and $line -match ('@ube_value_root_enter\(ptr %root\.value\.'+$id+', ptr '+$escaped+', ptr @ube.value.'))){$null=$drop.Add($line)}else{throw ('Omitted slot has a real value/address use: '+$slot+' '+$line)}
   }
  }
  $rootId=[regex]::Escape($id)
  foreach($line in @($Body -split "`n")){
   if($line -match ('^  %root\.value\.'+$rootId+' = alloca \[32 x i8\], align 8$') -or
      $line -match ('^  store \[32 x i8\] zeroinitializer, ptr %root\.value\.'+$rootId+', align 8$') -or
      $line -match ('^  %root\.ok\.value\.'+$rootId+' = icmp ne i32 %root.status.value\.'+$rootId+', 0$') -or
      $line -match ('^  br i1 %root\.ok\.value\.'+$rootId+', label %root.ready.value\.'+$rootId+', label %proc.exit$') -or
      $line -match ('^root\.ready\.value\.'+$rootId+':$') -or
      $line -match ('^  call i32 @ube_gc_root_leave\(ptr %root\.value\.'+$rootId+'\)$')){$null=$drop.Add($line)}
  }
 }
 return (@($Body -split "`n"|Where-Object {-not $drop.Contains($_)}) -join "`n")
}
function Compare-ValueSlotFootprint([string]$Eager,[string]$Current){
 $old=$Eager.Replace("`r`n","`n");$new=$Current.Replace("`r`n","`n")
 $pattern='(?ms)^define [^\n]+\n.*?^\}'
 $oldDefinitions=@([regex]::Matches($old,$pattern));$newDefinitions=@([regex]::Matches($new,$pattern))
 if($oldDefinitions.Count -ne $newDefinitions.Count -or [regex]::Replace($old,$pattern,'') -cne [regex]::Replace($new,$pattern,'')){throw 'Global/native layouts/signatures differ'}
 $details=@();$total=0
 for($index=0;$index -lt $oldDefinitions.Count;++$index){
  $a=$oldDefinitions[$index].Value;$b=$newDefinitions[$index].Value
  $oldSlots=Get-ValueSlots $a 'value';$newSlots=Get-ValueSlots $b 'value';$removed=@($oldSlots|Where-Object {$_ -notin $newSlots})
  if(@($newSlots|Where-Object {$_ -notin $oldSlots}).Count){throw 'Unexpected new value slot'}
  foreach($id in $removed){if($id -in (Get-ValueSlots $b 'scratch') -or $b -match ('%(?:value|scratch)\.'+[regex]::Escape($id)+'(?![A-Za-z0-9_.])')){throw 'Omitted slot partially allocated or referenced'}}
  if((Remove-UnusedValueSlots $a $removed) -cne $b){throw ('Genuine materialization/ByRef/borrow/copy/cleanup differs in function '+$index)}
  $total+=$removed.Count
  if($removed.Count){$details+=[pscustomobject]@{header=($a -split "`n")[0];omittedNodes=$removed}}
 }
 return [pscustomobject]@{procedures=$oldDefinitions.Count;omittedValueSlots=$total;omittedScratchSlots=$total;details=$details}
}
