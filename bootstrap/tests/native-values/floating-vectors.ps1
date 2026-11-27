# Adds independent exact-bit cases to the actual NativeValues emitter gate.
. (Join-Path $root 'std-lib/tests/floating-point/rational-oracle.ps1')
$script:floatingFirst=$vectors.Count
function Add-FloatSpec([int]$Operation,[int]$Source,[int]$Target,[bool]$Guard){
 $index=$specs.Count;$specs.Add(@($Operation,$Source,$Target,$(if($Guard){-1}else{0})));return $index
}
function Add-FloatVector([int]$Index,[string]$Left,[string]$Right,[string]$Expected,[int]$FailureCode=0){
 $vectors.Add(@($Index,$Left,$Right,($FailureCode -eq 0),$Expected,$FailureCode))
}
function Integer-Rounded($Value){
 $r=[Numerics.BigInteger]::Zero
 $q=[Numerics.BigInteger]::DivRem($Value.N,$Value.D,[ref]$r)
 if(2*$r -gt $Value.D -or (2*$r -eq $Value.D -and -not $q.IsEven)){$q+=[Numerics.BigInteger]::One}
 if($Value.Negative){$q=-$q};return $q
}
foreach($width in @(32,64)){
 $type=159;$p=53;$bias=1023;$maxfield=2047
 if($width -eq 32){$type=158;$p=24;$bias=127;$maxfield=255}
 $unit=P2 ($p-1);$one=$bias*$unit;$max=($maxfield-1)*$unit+$unit-1
 $half=($bias-1)*$unit;$halfUlp=($bias-$p)*$unit
 $pairs=@(@('0','0'),@((Encoding 0 $true $width),(Encoding 0 $true $width)),@('1',$half.ToString()),@('3',$half.ToString()),@($one.ToString(),$halfUlp.ToString()),@(($one+1).ToString(),$halfUlp.ToString()),@($unit.ToString(),(Encoding 1 $true $width)),@(($one+1).ToString(),(Encoding $one $true $width)),@($max.ToString(),'1'),@($max.ToString(),$max.ToString()),@('1','2'),@(($unit-1).ToString(),'1'),@($one.ToString(),'0'))
 $pairs+=,@(($one+1).ToString(),$one.ToString())
 $overflowHalf=RoundRational (P2 ($bias-$p)) 1 $false $width
 $pairs+=,@($max.ToString(),$overflowHalf)
 $pairs+=,@($max.ToString(),([Numerics.BigInteger]::Parse($overflowHalf)-1).ToString())
 $random=New-Object Random(70113)
 for($i=0;$i -lt 16;$i++){
  $a=$random.Next(0,$maxfield)*$unit+([Numerics.BigInteger]$random.Next(0,1000000)*($unit/1000000))
  $b=$random.Next(0,$maxfield)*$unit+([Numerics.BigInteger]$random.Next(0,1000000)*($unit/1000000))
  $pairs+=,@((Encoding $a ($i%2 -eq 0) $width),(Encoding $b ($i%3 -eq 0) $width))
 }
 foreach($operation in @(1,2,3,4)){
  $native=@{1=1;2=2;3=6;4=7}[$operation]
  $index=Add-FloatSpec $native $type 0 $true
  foreach($pair in $pairs){
   $failureCode=0;$expected='0'
   if($operation -eq 4 -and (Decode $pair[1] $width).N -eq 0){$failureCode=11}else{
    $expected=Expected $pair[0] $pair[1] $width $operation
    if((Decode $expected $width).Kind -ne 0){$failureCode=6}
   }
   Add-FloatVector $index $pair[0] $pair[1] $expected $failureCode
  }
 }
 $index=Add-FloatSpec 8 $type 0 $false
 foreach($bits in @('0',(Encoding 0 $true $width),'1',$one.ToString(),$max.ToString())){
  $value=Decode $bits $width
  $expected=RoundRational $value.N $value.D (-not $value.Negative) $width
  Add-FloatVector $index $bits '0' $expected
 }
 foreach($operator in @(15,22,18,19,20,21)){
  $index=Add-FloatSpec 9 $type $operator $false
  foreach($pair in $pairs){
   $a=Decode $pair[0] $width;$b=Decode $pair[1] $width
   $an=$a.N;$bn=$b.N;if($a.Negative){$an=-$an};if($b.Negative){$bn=-$bn}
   $order=[Numerics.BigInteger]::Compare($an*$b.D,$bn*$a.D)
   $yes=switch($operator){15{$order -eq 0};22{$order -ne 0};18{$order -lt 0};19{$order -gt 0};20{$order -le 0};21{$order -ge 0}}
   Add-FloatVector $index $pair[0] $pair[1] $(if($yes){'-1'}else{'0'})
  }
 }
 foreach($target in @(153,154,155,156,157,158,159)){
  $index=Add-FloatSpec 0 $type $target $true
  $values=@('0',(Encoding 0 $true $width),'1',(Encoding 1 $true $width),$max.ToString(),(Special 1 $false $width),(Special 1 $true $width),(Special 2 $false $width))
  foreach($integer in @(-1,1,255,256,32767,32768,2147483647,2147483648,'9223372036854775807','-9223372036854775808')){
   $n=[Numerics.BigInteger]::Parse([string]$integer)
   $values+=RoundRational ([Numerics.BigInteger]::Abs($n)) 1 ($n -lt 0) $width
  }
  foreach($twice in @(-7,-5,-3,-1,1,3,5,7,509,511,65533,65535)){
   $values+=RoundRational ([Numerics.BigInteger]::Abs($twice)) 2 ($twice -lt 0) $width
  }
  if($target -ge 154 -and $target -le 157){
   foreach($boundary in @($minimum[$target],$maximum[$target])){
    foreach($offset in @(-3,-1,0,1,3)){
     $twice=2*[Numerics.BigInteger]::Parse($boundary)+$offset
     $values+=RoundRational ([Numerics.BigInteger]::Abs($twice)) 2 ($twice -lt 0) $width
    }
   }
  }
  if($width -eq 64){
   # Exact narrowing midpoint, half/minimum Single subnormal, and just above Single max.
   foreach($pair in @(@(((P2 24)+1),(P2 24)),@(((P2 24)+3),(P2 24)),@([Numerics.BigInteger]::One,(P2 150)),@([Numerics.BigInteger]3,(P2 150)),@((((P2 24)-1)*(P2 104)+1),1))){$values+=RoundRational $pair[0] $pair[1] $false 64}
   $singleMax=Decode '2139095039' 32
   $wideMax=RoundRational $singleMax.N $singleMax.D $false 64
   $values+=$wideMax;$values+=([Numerics.BigInteger]::Parse($wideMax)+1).ToString()
  }
  foreach($bits in $values){
   $a=Decode $bits $width;$failureCode=0;$expected='0'
   if($a.Kind -ne 0){$failureCode=6}
   elseif($target -eq 153){if($a.N -ne 0){$expected='-1'}}
   elseif($target -le 157){
    $rounded=Integer-Rounded $a
    if($rounded -lt [Numerics.BigInteger]::Parse($minimum[$target]) -or $rounded -gt [Numerics.BigInteger]::Parse($maximum[$target])){$failureCode=6}else{$expected=$rounded.ToString()}
   }else{
    $destinationWidth=64;if($target -eq 158){$destinationWidth=32}
    $limit=Decode $(if($destinationWidth -eq 32){'2139095039'}else{'9218868437227405311'}) $destinationWidth
    if($a.N*$limit.D -gt $limit.N*$a.D){$failureCode=6}else{$expected=RoundRational $a.N $a.D $a.Negative $destinationWidth}
   }
   Add-FloatVector $index $bits '0' $expected $failureCode
  }
 }
 foreach($source in @(153,154,155,156,157)){
  $index=Add-FloatSpec 0 $source $type $false
  $values=@($minimum[$source],$maximum[$source],'0')
  if($source -ge 156){$values+=@('16777217','16777219','-16777217')}
  if($source -eq 157){$values+=@('9007199254740993','9007199254740995','-9007199254740993')}
  foreach($value in $values){$n=[Numerics.BigInteger]::Parse($value);Add-FloatVector $index $value '0' (RoundRational ([Numerics.BigInteger]::Abs($n)) 1 ($n -lt 0) $width)}
 }
}
